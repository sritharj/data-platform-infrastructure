###############################################################################
# Athena Module — Workgroup with cost controls + example named queries
###############################################################################

resource "aws_athena_workgroup" "main" {
  name          = "${var.project}-workgroup"
  description   = "Primary workgroup for ${var.project} data lake queries"
  force_destroy = var.force_destroy

  configuration {
    enforce_workgroup_configuration = true
    publish_cloudwatch_metrics_enabled = true

    bytes_scanned_cutoff_per_query = var.bytes_scanned_limit

    result_configuration {
      output_location = "s3://${var.athena_results_bucket_name}/query-results/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = var.kms_key_arn
      }
    }

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project}-athena-workgroup"
  })
}

# Example named query: check raw zone data
resource "aws_athena_named_query" "check_raw_partitions" {
  name        = "${var.project}-check-raw-partitions"
  workgroup   = aws_athena_workgroup.main.name
  database    = var.raw_database_name
  description = "List partitions in the raw zone"
  query       = "SHOW PARTITIONS ${var.project}_raw.source_data;"
}

# Example named query: Iceberg table snapshot history
resource "aws_athena_named_query" "iceberg_snapshots" {
  name        = "${var.project}-iceberg-snapshots"
  workgroup   = aws_athena_workgroup.main.name
  database    = var.iceberg_database_name
  description = "View Iceberg table snapshot history (time travel)"
  query       = <<-SQL
    SELECT *
    FROM "${var.project}_iceberg"."example_events$snapshots"
    ORDER BY committed_at DESC
    LIMIT 20;
  SQL
}

# Example: query curated Parquet data
resource "aws_athena_named_query" "curated_sample" {
  name        = "${var.project}-curated-sample"
  workgroup   = aws_athena_workgroup.main.name
  database    = var.curated_database_name
  description = "Sample query against curated zone"
  query       = <<-SQL
    SELECT *
    FROM "${var.project}_curated"."events"
    WHERE dt = current_date - interval '1' day
    LIMIT 100;
  SQL
}
