###############################################################################
# IAM Module — Roles and policies for all pipeline components
###############################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# =============================================================================
# MWAA Execution Role
# =============================================================================
resource "aws_iam_role" "mwaa_execution" {
  name = "${var.project}-mwaa-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "airflow.amazonaws.com",
            "airflow-env.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "mwaa_execution" {
  name = "${var.project}-mwaa-execution-policy"
  role = aws_iam_role.mwaa_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AirflowPublishMetrics"
        Effect = "Allow"
        Action = [
          "airflow:PublishMetrics"
        ]
        Resource = "arn:aws:airflow:${local.region}:${local.account_id}:environment/${var.project}-mwaa"
      },
      {
        Sid    = "S3DataLakeAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          var.data_lake_bucket_arn,
          "${var.data_lake_bucket_arn}/raw/*",
          "${var.data_lake_bucket_arn}/curated/*",
          "${var.data_lake_bucket_arn}/iceberg/*",
          "${var.data_lake_bucket_arn}/quarantine/*",
          "${var.data_lake_bucket_arn}/tmp/*"
        ]
      },
      {
        Sid    = "S3DagsBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          var.mwaa_dags_bucket_arn,
          "${var.mwaa_dags_bucket_arn}/*"
        ]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:GetLogRecord",
          "logs:GetLogGroupFields",
          "logs:GetQueryResults"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:log-group:airflow-${var.project}-mwaa-*"
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:ChangeMessageVisibility",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
          "sqs:SendMessage"
        ]
        Resource = "arn:aws:sqs:${local.region}:*:airflow-celery-*"
      },
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.project}/*"
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey*",
          "kms:Encrypt"
        ]
        Resource = var.kms_key_arn
      },
      {
        Sid    = "RedshiftDataAPI"
        Effect = "Allow"
        Action = [
          "redshift-data:ExecuteStatement",
          "redshift-data:BatchExecuteStatement",
          "redshift-data:GetStatementResult",
          "redshift-data:DescribeStatement",
          "redshift-data:ListStatements",
          "redshift-data:CancelStatement",
          "redshift-serverless:GetCredentials",
          "redshift-serverless:GetWorkgroup",
          "redshift-serverless:GetNamespace"
        ]
        Resource = "*"
      },
      {
        Sid    = "GlueCatalogAccess"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:BatchGetPartition",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:CreatePartition",
          "glue:BatchCreatePartition",
          "glue:UpdatePartition",
          "glue:DeletePartition"
        ]
        Resource = [
          "arn:aws:glue:${local.region}:${local.account_id}:catalog",
          "arn:aws:glue:${local.region}:${local.account_id}:database/${var.project}_*",
          "arn:aws:glue:${local.region}:${local.account_id}:table/${var.project}_*/*"
        ]
      },
      {
        Sid    = "DynamoDBLoadLedger"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = var.dynamodb_table_arn != "" ? [var.dynamodb_table_arn] : []
      }
    ]
  })
}

# =============================================================================
# Redshift Serverless Role (for COPY from S3 + Spectrum)
# =============================================================================
resource "aws_iam_role" "redshift" {
  name = "${var.project}-redshift"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "redshift" {
  name = "${var.project}-redshift-policy"
  role = aws_iam_role.redshift.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ReadForCopy"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = [
          var.data_lake_bucket_arn,
          "${var.data_lake_bucket_arn}/raw/*",
          "${var.data_lake_bucket_arn}/curated/*",
          "${var.data_lake_bucket_arn}/iceberg/*",
          "${var.data_lake_bucket_arn}/tmp/*"
        ]
      },
      {
        Sid    = "KMSForS3"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arn
      },
      {
        Sid    = "GlueCatalogForSpectrum"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:BatchGetPartition"
        ]
        Resource = [
          "arn:aws:glue:${local.region}:${local.account_id}:catalog",
          "arn:aws:glue:${local.region}:${local.account_id}:database/${var.project}_*",
          "arn:aws:glue:${local.region}:${local.account_id}:table/${var.project}_*/*"
        ]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# Glue Crawler Role
# =============================================================================
resource "aws_iam_role" "glue_crawler" {
  name = "${var.project}-glue-crawler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "glue_crawler_service" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_crawler_s3" {
  name = "${var.project}-glue-crawler-s3"
  role = aws_iam_role.glue_crawler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.data_lake_bucket_arn,
          "${var.data_lake_bucket_arn}/raw/*",
          "${var.data_lake_bucket_arn}/curated/*",
          "${var.data_lake_bucket_arn}/iceberg/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# =============================================================================
# EventBridge / Lambda Trigger Role (optional)
# =============================================================================
resource "aws_iam_role" "lambda_mwaa_trigger" {
  count = var.create_eventbridge_role ? 1 : 0
  name  = "${var.project}-lambda-mwaa-trigger"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "lambda_mwaa_trigger" {
  count = var.create_eventbridge_role ? 1 : 0
  name  = "${var.project}-lambda-mwaa-trigger-policy"
  role  = aws_iam_role.lambda_mwaa_trigger[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "airflow:CreateCliToken"
        ]
        Resource = "arn:aws:airflow:${local.region}:${local.account_id}:environment/${var.project}-mwaa"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:*"
      }
    ]
  })
}
