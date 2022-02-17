
variable "namespace" {
  default = "eg"
}

variable "stage" {
  default = "test"
}

variable "name" {

  default = "eks-fargate"
}

variable "tags" {
  default = {
    Terraform = "true"
  }
}


variable "region" {
  type        = string
  description = "AWS Region"
  default     = "us-east-2"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
  default     = ["us-east-2a", "us-east-2b"]
}

variable "vpc_cidr_block" {
  type        = string
  description = "VPC CIDR block"
  default     = "172.16.0.0/16"
}

variable "oidc_provider_enabled" {
  type        = bool
  default     = false
  description = "Create an IAM OIDC identity provider for the cluster, then you can create IAM roles to associate with a service account in the cluster, instead of using kiam or kube2iam. For more information, see https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html"
}

variable "kubernetes_namespace" {
  type        = string
  description = "Kubernetes namespace for selection"
  default     = "default"

}

variable "kubernetes_labels" {
  type        = map(string)
  description = "Key-value mapping of Kubernetes labels for selection"
  default     = {}
}

variable "desired_size" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 2
}

variable "max_size" {
  type        = number
  description = "The maximum size of the AutoScaling Group"
  default     = 3
}

variable "min_size" {
  type        = number
  description = "The minimum size of the AutoScaling Group"
  default     = 2
}

variable "disk_size" {
  type        = number
  description = "Disk size in GiB for worker nodes. Defaults to 20. Terraform will only perform drift detection if a configuration value is provided"
  default     = 20
}

variable "instance_types" {
  type        = list(string)
  description = "Set of instance types associated with the EKS Node Group. Defaults to [\"t3.medium\"]. Terraform will only perform drift detection if a configuration value is provided"
  default     = ["t3.small"]
}

variable "iam_role_kubernetes_namespace_delimiter" {
  type        = string
  description = "Delimiter for the Kubernetes namespace in the IAM Role name"
  default     = "@"
}
