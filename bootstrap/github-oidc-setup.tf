###############################################################################
# GitHub OIDC Provider + IAM Role for GitHub Actions
# This allows GitHub Actions to assume an IAM role without long-lived credentials
###############################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
  # Example: "mycompany" or "myusername"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  # Example: "terraform-infrastructure"
}

variable "state_bucket_arn" {
  description = "ARN of the Terraform state S3 bucket"
  type        = string
  # Get this from the backend-setup outputs
}

variable "dynamodb_table_arn" {
  description = "ARN of the Terraform state lock DynamoDB table"
  type        = string
  # Get this from the backend-setup outputs
}

###############################################################################
# GitHub OIDC Provider
###############################################################################
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Name      = "GitHub OIDC Provider"
    ManagedBy = "terraform"
  }
}

###############################################################################
# IAM Role for GitHub Actions
###############################################################################
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      # This restricts the role to your specific repo
      # For more security, add :ref:refs/heads/main to restrict to main branch only
      values = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-terraform-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Name      = "GitHub Actions Terraform Role"
    ManagedBy = "terraform"
  }
}

###############################################################################
# IAM Policy for Terraform Operations
###############################################################################
data "aws_iam_policy_document" "terraform_permissions" {
  # Terraform state access
  statement {
    sid    = "TerraformStateAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      var.state_bucket_arn,
      "${var.state_bucket_arn}/*"
    ]
  }

  statement {
    sid    = "TerraformStateLocking"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]
    resources = [var.dynamodb_table_arn]
  }

  # Full admin access for Terraform to manage resources
  # In production, you should scope this down to specific services
  statement {
    sid    = "TerraformResourceManagement"
    effect = "Allow"
    actions = [
      "ec2:*",
      "vpc:*",
      "s3:*",
      "iam:*",
      "kms:*",
      "secretsmanager:*",
      "airflow:*",
      "glue:*",
      "lakeformation:*",
      "athena:*",
      "redshift:*",
      "redshift-serverless:*",
      "dynamodb:*",
      "events:*",
      "lambda:*",
      "logs:*",
      "cloudwatch:*",
      "sns:*",
      "sqs:*",
      "ecr:*",
      "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions_terraform" {
  name   = "terraform-permissions"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.terraform_permissions.json
}

###############################################################################
# Outputs
###############################################################################
output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "ARN of the IAM role for GitHub Actions to assume"
}

output "oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.github.arn
  description = "ARN of the GitHub OIDC provider"
}
