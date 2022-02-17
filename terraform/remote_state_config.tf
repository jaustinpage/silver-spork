terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.1.0"
    }
  }
  required_version = ">= 0.14.9"
  backend "s3" {
    bucket         = "tf-remote-state20220216232002199100000002"
    key            = "core/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    kms_key_id     = "d61a57b3-2242-4e28-b3f2-d743c95db1ac"
    dynamodb_table = "tf-remote-state-lock"
  }
}

provider "aws" {
  profile = "austininterview"
  region  = "us-east-2"
}
