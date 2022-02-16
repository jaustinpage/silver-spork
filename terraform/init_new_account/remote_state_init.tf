terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.1.0"
    }
  }
  required_version = ">=0.14.9"
}

provider "aws" {
  profile = "austininterview"
  region  = "us-east-2"
}

provider "aws" {
  profile = "austininterview"
  region  = "us-east-2"
  alias   = "remote_state_primary"
}

provider "aws" {
  profile = "austininterview"
  region  = "us-west-2"
  alias   = "remote_state_replica"
}

variable "tags" {
  description = "A mapping of tags to assign to resources."
  default = {
    Terraform = "true"
  }
}

#---------------------------------------------------------------------------------------------------
# IAM Policy
# See below for permissions necessary to run Terraform.
# https://www.terraform.io/docs/backends/types/s3.html#example-configuration
#---------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "terraform" {
  provider    = aws.remote_state_primary
  name_prefix = "terraform"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "${aws_s3_bucket.state.arn}"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "${aws_s3_bucket.state.arn}/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "${aws_dynamodb_table.lock.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:ListKeys"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:GenerateDataKey"
      ],
      "Resource": "${aws_kms_key.this.arn}"
    }
  ]
}
POLICY
}


#---------------------------------------------------------------------------------------------------
# DynamoDB Table for State Locking
#---------------------------------------------------------------------------------------------------
resource "aws_kms_key" "dynamodb_kms" {
  provider            = aws.remote_state_primary
  enable_key_rotation = true
}

resource "aws_dynamodb_table" "lock" {
  provider     = aws.remote_state_primary
  name         = "tf-remote-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_kms.arn
  }

}

#---------------------------------------------------------------------------------------------------
# KMS Key to Encrypt S3 Bucket
#---------------------------------------------------------------------------------------------------
resource "aws_kms_key" "this" {
  provider                = aws.remote_state_primary
  description             = "The key used to encrypt the remote state bucket."
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = var.tags
}

resource "aws_kms_key" "replica" {
  provider = aws.remote_state_replica

  description             = "The key used to encrypt the remote state bucket."
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = var.tags
}

#---------------------------------------------------------------------------------------------------
# IAM Role for Replication
# https://docs.aws.amazon.com/AmazonS3/latest/dev/crr-replication-config-for-kms-objects.html
#---------------------------------------------------------------------------------------------------
resource "aws_iam_role" "replication" {
  provider = aws.remote_state_primary

  name_prefix = "tf-remote-state-replication-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
POLICY

  tags = var.tags
}

resource "aws_iam_policy" "replication" {
  provider    = aws.remote_state_primary
  name_prefix = "tf-remote-state-replication-policy"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetReplicationConfiguration",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.state.arn}"
      ]
    },
    {
      "Action": [
        "s3:GetObjectVersionForReplication",
        "s3:GetObjectVersionAcl"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.state.arn}/*"
      ]
    },
    {
      "Action": [
        "s3:ReplicateObject",
        "s3:ReplicateDelete"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.replica.arn}/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt"
      ],
      "Resource": "${aws_kms_key.this.arn}",
      "Condition": {
        "StringLike": {
          "kms:ViaService": "s3.${data.aws_region.state.name}.amazonaws.com",
          "kms:EncryptionContext:aws:s3:arn": [
            "${aws_s3_bucket.state.arn}/*"
          ]
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Encrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "${aws_kms_key.replica.arn}",
      "Condition": {
        "StringLike": {
          "kms:ViaService": "s3.${data.aws_region.replica.name}.amazonaws.com",
          "kms:EncryptionContext:aws:s3:arn": [
            "${aws_s3_bucket.replica.arn}/*"
          ]
        }
      }
    }
  ]
}
POLICY
}

resource "aws_iam_policy_attachment" "replication" {
  provider   = aws.remote_state_primary
  name       = "tf-iam-role-attachment-replication-configuration"
  roles      = [aws_iam_role.replication.name]
  policy_arn = aws_iam_policy.replication.arn
}

#---------------------------------------------------------------------------------------------------
# Bucket Policies
#---------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "state_force_ssl" {
  statement {
    sid     = "AllowSSLRequestsOnly"
    actions = ["s3:*"]
    effect  = "Deny"
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

data "aws_iam_policy_document" "replica_force_ssl" {
  statement {
    sid     = "AllowSSLRequestsOnly"
    actions = ["s3:*"]
    effect  = "Deny"
    resources = [
      aws_s3_bucket.replica.arn,
      "${aws_s3_bucket.replica.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}
#---------------------------------------------------------------------------------------------------
# Buckets
#---------------------------------------------------------------------------------------------------
data "aws_region" "state" {
}

data "aws_region" "replica" {
  provider = aws.remote_state_replica
}

resource "aws_s3_bucket" "replica" {
  provider = aws.remote_state_replica

  bucket_prefix = "tf-remote-state-replica"
  force_destroy = false
  tags          = var.tags
}

resource "aws_s3_bucket_versioning" "replica" {
  provider = aws.remote_state_replica
  bucket = aws_s3_bucket.replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "replica" {
  provider = aws.remote_state_replica
  bucket = aws_s3_bucket.replica.id
  rule {
    id     = "glacier"
    status = "Enabled"
    noncurrent_version_transition {
      noncurrent_days = 7
      storage_class   = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_logging" "replica" {
  provider = aws.remote_state_replica
  bucket        = aws_s3_bucket.replica.id
  target_bucket = aws_s3_bucket.log_replica.id
  target_prefix = "tf-remote-state-replica-logs/"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "replica" {
  provider = aws.remote_state_replica
  bucket = aws_s3_bucket.replica.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
  }
}

resource "aws_s3_bucket_policy" "state_force_ssl" {
  depends_on = [aws_s3_bucket_public_access_block.state]
  bucket     = aws_s3_bucket.state.id
  policy     = data.aws_iam_policy_document.state_force_ssl.json
}

resource "aws_s3_bucket_public_access_block" "replica" {
  provider = aws.remote_state_replica
  bucket   = aws_s3_bucket.replica.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "log" {
  bucket_prefix = "tf-remote-state-log"
  force_destroy = false
  tags          = var.tags
}

resource "aws_s3_bucket_acl" "log" {
  bucket = aws_s3_bucket.log.id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_versioning" "log" {
  bucket = aws_s3_bucket.log.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log" {
  bucket = aws_s3_bucket.log.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "log" {
  bucket = aws_s3_bucket.log.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "log_replica" {
  provider      = aws.remote_state_replica
  bucket_prefix = "tf-remote-state-log-replica"
  force_destroy = false
  tags          = var.tags
}

resource "aws_s3_bucket_versioning" "log_replica" {
  provider = aws.remote_state_replica
  bucket = aws_s3_bucket.log_replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_replica" {
  provider = aws.remote_state_replica
  bucket = aws_s3_bucket.log_replica.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
  }
}

resource "aws_s3_bucket_acl" "log_replica" {
  provider = aws.remote_state_replica
  bucket = aws_s3_bucket.log_replica.id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_public_access_block" "log_replica" {
  provider = aws.remote_state_replica
  bucket   = aws_s3_bucket.log_replica.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}



resource "aws_s3_bucket" "state" {
  bucket_prefix = "tf-remote-state"
  force_destroy = false

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_acl" "state" {
  bucket = aws_s3_bucket.state.id
  acl    = "private"
}

resource "aws_s3_bucket_logging" "state" {
  bucket        = aws_s3_bucket.state.id
  target_bucket = aws_s3_bucket.log.id
  target_prefix = "tf-remote-state-logs/"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    id     = "glacier"
    status = "Enabled"
    noncurrent_version_transition {
      noncurrent_days = 7
      storage_class   = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_replication_configuration" "state" {
  depends_on = [aws_s3_bucket_versioning.state]
  bucket     = aws_s3_bucket.state.id
  role       = aws_iam_role.replication.arn

  rule {
    id     = "replica_configuration"
    prefix = ""
    status = "Enabled"

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }

    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD"
      encryption_configuration {

        replica_kms_key_id = aws_kms_key.replica.arn
      }
    }
  }
}


resource "aws_s3_bucket_policy" "replica_force_ssl" {
  depends_on = [aws_s3_bucket_public_access_block.replica]
  provider   = aws.remote_state_replica
  bucket     = aws_s3_bucket.replica.id
  policy     = data.aws_iam_policy_document.replica_force_ssl.json
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "backend_s3_bucket" {
  description = "The s3 bucket for terraform remote state"
  value       = aws_s3_bucket.state.id
}

output "backend_s3_key" {
  description = "The key to use for s3 remote state"
  value       = "core/terraform.tfstate"
}

output "backend_s3_region" {
  description = "The region to use for s3 remote state"
  value       = data.aws_region.state.name
}


output "backend_s3_encrypt" {
  description = "Whether or not to use encryption for s3 remote state."
  value       = "true"
}

output "backend_s3_dynamodb_table" {
  description = "The dynamodb table to use for s3 remote state"
  value       = aws_dynamodb_table.lock.name
}

output "backend_s3_kms_key_id" {
  description = "The kms key to use for encrypting bucket remote state"
  value       = aws_kms_key.this.arn
}
