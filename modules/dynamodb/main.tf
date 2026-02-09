###############################################################################
# DynamoDB Module — Load ledger for idempotent ingestion tracking
###############################################################################

resource "aws_dynamodb_table" "load_ledger" {
  name         = "${var.project}-load-ledger"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "s3_key"
  range_key    = "version_id"

  attribute {
    name = "s3_key"
    type = "S"
  }

  attribute {
    name = "version_id"
    type = "S"
  }

  attribute {
    name = "ingest_date"
    type = "S"
  }

  # GSI to query by date for monitoring/backfill
  global_secondary_index {
    name            = "by-date"
    hash_key        = "ingest_date"
    range_key       = "s3_key"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = merge(var.tags, {
    Name = "${var.project}-load-ledger"
  })
}
