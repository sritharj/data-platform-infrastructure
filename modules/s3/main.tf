###############################################################################
# S3 Module — Data lake buckets with zone prefixes, lifecycle, encryption
###############################################################################

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# Data Lake Bucket (raw/, curated/, iceberg/, quarantine/, tmp/)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "data_lake" {
  bucket        = "${var.project}-data-lake-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name = "${var.project}-data-lake"
  })
}

resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rules: transition raw to IA, then Glacier; expire tmp
resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    id     = "raw-to-ia"
    status = "Enabled"

    filter {
      prefix = "raw/"
    }

    transition {
      days          = var.raw_to_ia_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.raw_to_glacier_days
      storage_class = "GLACIER"
    }

    expiration {
      days = var.raw_expiration_days
    }
  }

  rule {
    id     = "quarantine-expiration"
    status = "Enabled"

    filter {
      prefix = "quarantine/"
    }

    expiration {
      days = var.quarantine_expiration_days
    }
  }

  rule {
    id     = "tmp-cleanup"
    status = "Enabled"

    filter {
      prefix = "tmp/"
    }

    expiration {
      days = 7
    }
  }

  rule {
    id     = "abort-multipart"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 3
    }
  }
}

# S3 event notification to EventBridge (for optional Flow A triggering)
resource "aws_s3_bucket_notification" "data_lake" {
  count  = var.enable_eventbridge_notifications ? 1 : 0
  bucket = aws_s3_bucket.data_lake.id

  eventbridge = true
}

# Create zone prefixes as empty objects (helps with console visibility)
resource "aws_s3_object" "zone_prefixes" {
  for_each = toset(["raw/", "curated/", "iceberg/", "quarantine/", "tmp/"])

  bucket  = aws_s3_bucket.data_lake.id
  key     = each.value
  content = ""
}

# -----------------------------------------------------------------------------
# MWAA DAGs Bucket
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "mwaa_dags" {
  bucket        = "${var.project}-mwaa-dags-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name = "${var.project}-mwaa-dags"
  })
}

resource "aws_s3_bucket_versioning" "mwaa_dags" {
  bucket = aws_s3_bucket.mwaa_dags.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mwaa_dags" {
  bucket = aws_s3_bucket.mwaa_dags.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "mwaa_dags" {
  bucket = aws_s3_bucket.mwaa_dags.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create DAGs and plugins prefixes
resource "aws_s3_object" "mwaa_prefixes" {
  for_each = toset(["dags/", "plugins/", "requirements/"])

  bucket  = aws_s3_bucket.mwaa_dags.id
  key     = each.value
  content = ""
}

# -----------------------------------------------------------------------------
# Athena Query Results Bucket
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "athena_results" {
  bucket        = "${var.project}-athena-results-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name = "${var.project}-athena-results"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "expire-query-results"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }
  }
}
