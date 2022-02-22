# silver-spork

A service that returns the current time and a message

## Prerequisites

- Python 3.6+
- up to date pip
  ```shell
  # this needs to be done outside of a virtualenv, not inside
  pip install --upgrade pip
  ```
- tox
  ```shell
  pip install --upgrade tox
  ```
- terraform installed
- git
- Github account (for github actions and to clone the repo)
- AWS account (for deploying the service)
- optional: aws cli
- optional: yq
  ```shell
  wget https://github.com/mikefarah/yq/releases/download/v4.2.0/yq_linux_amd64.tar.gz -O - |  tar xz && sudo mv yq_li
nux_amd64 /usr/bin/yq
  ```
- optional: kubectl
  ```shell
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  ```

## Getting Started

These steps only need to be done once on a new aws account.

1. Create an aws account
1. Clone this repo into your own account
1. create a user in IAM with AdministratorAccess profile, and api keys
1. Save the api keys
1. configure aws access for your terminal (either using aws cli or environment variables)
1. cd into terraform/init_new_account
1. run `terraform init` 
1. run `terraform plan` and review the changes. This is going to get terraform remote state working on your new aws account.
1. run `terraform apply` to make the changes. at the end of the terraform run, save the "outputs", as we will need these to configure remote state for the main terraform config. NOTE: you may have to run apply multiple times to get it to finish. Seems to be a timing issue or dependency declaration that is missing.
1. Store the terraform.tfstate that is created by the account initialization in a safe place. You will need it again if you decide to tear down the environment. It is generally a bad idea to store it in version control, as it contains secrets for aws. 
1. cd into terraform/, edit remote_state_config.tf, and insert the values that you obtained when you initialized the remote state resources.


## Building and running the flask app
```shell
pip install --upgrade pip
pip install git+ssh://github.com/jaustinpage/silver-spork#egg=silver-spork
export FLASK_APP=silver_spork
python3 -m flask run 
```



# LEGACY INSTRUCTIONS BELOW - IGNORE

## Development Setup

Found a bug? Need a feature? Get set up for development on silver-spork here.

### Windows

#### Windows Development tools

- [PyCharm professional](https://www.jetbrains.com/pycharm/)

#### Windows Setup

1. Update pip
   ```shell
   pip install --upgrade pip
   ```
1. Install tox

```shell
# this needs to be done outside of a virtualenv, not inside
pip install --upgrade tox
```

1. Make a `Documents\github` folder
1. Clone this repo to `Documents\github\silver-spork` folder using git
1. Launch PyCharm
   1. go to `File -> Open...`
   1. Select `Documents\github\silver-spork` in the prompt
   1. Select Open project in `New Window`
   1. In the bottom-right corner of the screen, it says `No Interpreter`. Click on this
      box and select `Add Interpreter`
   1. In the Add Python Interpreter prompt, select `New Interpreter`, Location:
      `Documents\github\silver-spork\.venv`. Select `OK`
   1. Make a branch in git for your feature
   1. Fix the bug or add the feature
   1. Commit, push, let the repo owner know that there is a fix available

### Ubuntu (linux)

#### Ubuntu Development tools

- [PyCharm professional](https://www.jetbrains.com/pycharm/)

#### Ubuntu setup

In a terminal

```shell
# Install and git
sudo apt install git
# Install tox (this needs to be done outside of a virtualenv, not inside)
pip install --upgrade tox
mkdir -p ~/github
# Clone the repo
git clone ssh://github.com/jaustinpage/silver-spork ~/github/silver-spork
# change working directory to repo
cd ~/github/silver-spork
# Build the code
tox
```

At this point, I recommend using PyCharm to continue development.

1. Make a branch in git for your feature
1. Fix the bug or add the feature
1. Commit, push, let the repo owner know that there is a fix available

### A normal day of editing

1. `cd ~/github/silver-spork`
1. Make some edits
1. run `tox`, have failing tests
   1. fix some tests, and run `pytest`. Repeat until tests passing.
1. run `tox`, have linting errors
   1. Linting errors are a great way to learn how python works. Fix these. rerun `tox`.
      Repeat.
1. run `tox`, have code coverage errors. Increase the test coverage and rerun `tox`
1. Wheels are built, test the code manually, commit, and push for review.

##FAQ

### Common Lint Errors and how to fix them:

- `SC100` or `SC200`: If the flagged word is a false positive, add the word to anywhere
  `whitelist.txt` file. `tox` will automatically sort the file alphabetically the next
  time it is run.

##Repo/Library Management Tasks


### How to add a 3rd party (PyPi) runtime dependency

1. In `setup.cfg` find `[options]` and add dependency to `install_requires =`. For
   example to add `pandas` to your runtime dependencies, make the `[options]` secton
   look like this:
   ```shell
   # file: setup.cfg
   <... truncated ...>
   [options]
   <... truncated ...>
   install_requires =
       importlib-metadata; python_version<"3.6"
       pyscaffold>=4.0,<5.0a0
       pyscaffoldext-markdown
       pandas
   ```
1. Run `tox`. Package will automatically be installed.

### Advanced: Creating a new package version

remember to use [Semantic versioning](https://www.python.org/dev/peps/pep-0440/) (tldr:
use #.#.#, and only increment the last digit, unless you are changing the api call
signatures)

1. on the default branch run

   ```shell
   git pull --update
   git status  # Make sure current directory is clean
   git tag -r <version you want to tag> <version>
   git push
   ```

   For example, if you want the current tip to be version 0.0.2, then `git tag 0.0.2`.
   Then push the tag.


<!-- pyscaffold-notes -->

## Note

This project has been set up using PyScaffold 4.1.4. For details and usage information
on PyScaffold see https://pyscaffold.org/.

```
```
