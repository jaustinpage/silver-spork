#!/usr/bin/env python3
import base64
import json
import logging
import os
import time

import arrow
import boto3
import click
import docker

from botocore.exceptions import ClientError
from git import Repo


class EcrImageScanTimeout(Exception):
    pass


class EcrGetImageIdTimeout(Exception):
    pass


class MultipleImagesWithTag(Exception):
    pass


class EcrScanFoundVulnerabilities(Exception):
    pass


class ECR(object):
    def __init__(self, image_name, git_repo=None, region='us-east-2'):
        self.image_name = image_name
        self.region = region
        self.git_repo = Repo(git_repo)
        self._login_ecr()

    def _login_ecr(self):
        self.ecr_client = boto3.client('ecr', region_name=self.region)

        try:
            self.ecr_repo = self.ecr_client.describe_repositories(repositoryNames=[self.image_name])['repositories'][0]
        except ClientError as e:
            if e.response['Error']['Code'] == 'RepositoryNotFoundException':
                self.ecr_repo = self.ecr_client.create_repository(repositoryName=self.image_name)['repository']
            else:
                raise e

        auth = self.ecr_client.get_authorization_token(registryIds=[self.ecr_repo['registryId']])
        username, password = base64.b64decode(auth['authorizationData'][0]['authorizationToken']).decode().split(':')

        self.docker_client = docker.from_env()
        self.docker_client.ping()
        self.docker_client.login(username=username,
                                 password=password,
                                 registry=self.ecr_repo['repositoryUri'])

    def _image_string(self, commit_hash):
        registry_id = self.ecr_repo['registryId']
        return f"{registry_id}.dkr.ecr.{self.region}.amazonaws.com/{self.image_name}:{commit_hash}"

    #  merge_commit
    #    |      \
    #    |    branch_commit
    #    |       |
    #    |    branch_commit'
    #    |       |
    #    |    branch_commit''
    #    |      /
    #  base_commit

    @staticmethod
    def _check_commit_is_merge(merge_commit):
        if len(merge_commit.parents) == 2:
            return
        raise ValueError('Commit is not a merge commit (must have exactly 2 parents)')

    @staticmethod
    def _check_branch_is_same(merge_commit, branch_commit):
        if not merge_commit.diff(branch_commit):
            return
        raise ValueError('Similar commit not found')

    def _check_merged_branch_up_to_date(self, base_commit, branch_commit):
        if self.git_repo.is_ancestor(base_commit, branch_commit):
            return
        raise ValueError('Merged branch commits not based on last base branch commit')

    def __get_image_id_call(self, tag, timeout=900, retry_after=5):
        images = self.ecr_client.batch_get_image(
                repositoryName=self.ecr_repo['repositoryName'],
                imageIds=[{'imageTag': tag}]
                )
        if len(images['images']) > 1:
            raise MultipleImagesWithTag('There are multiple images with the tag specified')
        try:
            return images['images'][0]['imageId']
        except IndexError:
            return False

    def _wait_image_id(self, tag, timeout=900, retry_after=5):
        end_time = arrow.utcnow().shift(seconds=timeout)
        while arrow.utcnow() < end_time:
            image_id = self.__get_image_id_call(tag)
            if image_id:
                return image_id
            time.sleep(retry_after)
        else:
            raise EcrGetImageIdTimeout('Could not find the image for the tag specified')

    def _get_image_id(self, tag, timeout=900, retry_after=5):
        return self._wait_image_id(tag, timeout, retry_after)

    def _start_image_scan_call(self, tag):
        image_id = self._get_image_id(tag)
        try:
            self.ecr_client.start_image_scan(
                        registryId=self.ecr_repo['registryId'],
                        repositoryName=self.ecr_repo['repositoryName'],
                        imageId=image_id
                        )
        except self.ecr_client.exceptions.LimitExceededException:
            pass

    def _get_image_scan_call(self, tag):
        image_id = self._get_image_id(tag)
        try:
            scan_results = self.ecr_client.describe_image_scan_findings(
                    registryId=self.ecr_repo['registryId'],
                    repositoryName=self.ecr_repo['repositoryName'],
                    imageId=image_id
                    )

            if scan_results['imageScanStatus']['status'] == 'COMPLETE':
                return scan_results['imageScanFindings']
        except self.ecr_client.exceptions.ScanNotFoundException:
            self._start_image_scan_call(tag)
        return False

    def _wait_image_scan(self, tag, timeout=900, retry_after=5):
        end_time = arrow.utcnow().shift(seconds=timeout)
        while arrow.utcnow() < end_time:
            scan_results = self._get_image_scan_call(tag)
            if scan_results:
                return scan_results
            print(".", end="", flush=True)
            time.sleep(retry_after)
        else:
            raise EcrImageScanTimeout('Image scanning results are taking too long')

    def _get_image_scan(self, tag, timeout=900, retry_after=5):
        return self._wait_image_scan(tag, timeout, retry_after)

    @staticmethod
    def _check_image_scan(scan_results):
        if scan_results['findings']:
            raise EcrScanFoundVulnerabilities()
        return False

    def pull(self, tag=None):
        if not tag:
            i = 0
            for commit in self.git_repo.head.commit.iter_parents():
                image_string = self._image_string(commit.hexsha)
                logging.info('Trying to pull %s', image_string)
                try:
                    image = self.docker_client.images.pull(image_string)
                    tag = commit.hexsha
                    break
                except docker.errors.NotFound as e:
                    if i < 30:
                        i += 1
                        pass
                    else:
                        raise e

        image = self.docker_client.images.pull(self._image_string(tag))
        image.tag(f'{self.image_name}:{tag}')
        image.tag(f'{self.image_name}:latest')
        return tag, image

    def push(self, tag=None, image=None):
        if not tag:
            tag = self.git_repo.head.commit.hexsha
        if not image:
            try:
                image = self.docker_client.images.get(self._image_string(tag))
            except docker.errors.ImageNotFound:
                try:
                    image = self.docker_client.images.get(f'{self.image_name}:{tag}')
                except docker.errors.ImageNotFound:
                    image = self.docker_client.images.get(self.image_name)

        image.tag(self._image_string(tag))
        self.docker_client.images.push(self._image_string(tag))
        self._start_image_scan_call(tag)

    def check_scan(self, tag=None, exit_code=False):
        if not tag:
            tag = self.git_repo.head.commit.hexsha

        scan_results = self._get_image_scan(tag, timeout=1200)
        print('ECR Scan results:')
        print(json.dumps(scan_results, indent=2, default=str))
        try:
            self._check_image_scan(scan_results)
        except EcrScanFoundVulnerabilities as e:
            if exit_code:
                raise e

    def tag_merge(self):
        merge_commit = self.git_repo.heads.main.commit

        self._check_commit_is_merge(merge_commit)
        branch_commit = merge_commit.parents[1]
        base_commit = merge_commit.parents[0]

        self._check_branch_is_same(merge_commit, branch_commit)

        self._check_merged_branch_up_to_date(base_commit, branch_commit)

        _, image = self.pull(tag=branch_commit.hexsha)
        self.push(tag=merge_commit.hexsha, image=image)
        self.push(tag="latest", image=image)


@click.group()
@click.option('--region',
              type=click.Choice(['us-east-1',
                                 'us-east-2',
                                 'us-west-1',
                                 'us-west-2']),
              default='us-east-2')
@click.option('--repo-path',
              required=False)
@click.option('--image',
              required=False,
              default='silver-spork')
@click.pass_context
def cli(ctx, region, repo_path, image):
    ctx.obj = ECR(image, repo_path, region)


@cli.command()
@click.argument('tag',
                required=False)
@click.pass_obj
def pull(ecr, tag):
    pulled_tag, _ = ecr.pull(tag=tag)
    print(pulled_tag)


@cli.command()
@click.argument('commit_hash',
                required=False,
                default=os.environ.get('GITHUB_SHA'))
@click.pass_obj
def push(ecr, commit_hash):
    ecr.push(tag=commit_hash)


@cli.command('tag')
@click.pass_obj
def _tag(ecr):
    ecr.tag_merge()


@cli.command()
@click.argument('tag',
                required=False)
@click.option('--exit-code', is_flag=True)
@click.pass_obj
def scan(ecr, tag, exit_code):
    ecr.check_scan(tag=tag, exit_code=exit_code)


if __name__ == "__main__":
    cli()
