module "label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  name       = var.name
  namespace  = var.namespace
  stage      = var.stage
  tags       = var.tags
  attributes = ["cluster"]
}


module "vpc" {
  source  = "cloudposse/vpc/aws"
  version = "0.28.1"

  cidr_block = var.vpc_cidr_block
  tags       = module.label.tags

  context = module.label.context
}

module "subnets" {
  source  = "cloudposse/dynamic-subnets/aws"
  version = "0.39.8"

  availability_zones   = var.availability_zones
  vpc_id               = module.vpc.vpc_id
  igw_id               = module.vpc.igw_id
  cidr_block           = module.vpc.vpc_cidr_block
  nat_gateway_enabled  = true
  nat_instance_enabled = false
  tags                 = module.label.tags

  context = module.label.context
}

module "eks_cluster" {
  source  = "cloudposse/eks-cluster/aws"
  version = "0.45.0"

  region                     = var.region
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.subnets.public_subnet_ids
  oidc_provider_enabled      = var.oidc_provider_enabled
  workers_role_arns          = []
  workers_security_group_ids = []

  context = module.label.context
}

# Ensure ordering of resource creation to eliminate the race conditions when applying the Kubernetes Auth ConfigMap.
# Do not create Node Group before the EKS cluster is created and the `aws-auth` Kubernetes ConfigMap is applied.
# Otherwise, EKS will create the ConfigMap first and add the managed node role ARNs to it,
# and the kubernetes provider will throw an error that the ConfigMap already exists (because it can't update the map, only create it).
# If we create the ConfigMap first (to add additional roles/users/accounts), EKS will just update it by adding the managed node role ARNs.
locals {
  cluster_name             = module.eks_cluster.eks_cluster_id
  kubernetes_config_map_id = module.eks_cluster.kubernetes_config_map_id
}

module "eks_node_group" {
  source  = "cloudposse/eks-node-group/aws"
  version = "0.27.3"

  subnet_ids        = module.subnets.public_subnet_ids
  instance_types    = var.instance_types
  desired_size      = var.desired_size
  min_size          = var.min_size
  max_size          = var.max_size
  cluster_name      = local.cluster_name
  kubernetes_labels = var.kubernetes_labels

  context = module.label.context
}

module "eks_fargate_profile" {
  source = "cloudposse/eks-fargate-profile/aws"

  subnet_ids                              = module.subnets.private_subnet_ids
  cluster_name                            = local.cluster_name
  kubernetes_namespace                    = var.kubernetes_namespace
  kubernetes_labels                       = var.kubernetes_labels
  iam_role_kubernetes_namespace_delimiter = var.iam_role_kubernetes_namespace_delimiter

  context = module.label.context
}
