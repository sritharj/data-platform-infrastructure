###############################################################################
# KMS Module — Encryption keys for S3, Redshift, Secrets Manager, CloudWatch
###############################################################################

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "main" {
  description             = "CMK for ${var.project} data ingestion pipeline"
  deletion_window_in_days = var.key_deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RootAccountFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowS3Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project}-cmk"
  })
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project}-pipeline"
  target_key_id = aws_kms_key.main.key_id
}
