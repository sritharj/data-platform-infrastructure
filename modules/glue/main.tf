###############################################################################
# Glue Module — Data Catalog databases, crawlers, Iceberg table config
###############################################################################

# -----------------------------------------------------------------------------
# Glue Databases
# -----------------------------------------------------------------------------
resource "aws_glue_catalog_database" "raw" {
  name        = "${var.project}_raw"
  description = "Raw landing zone tables"

  tags = var.tags
}

resource "aws_glue_catalog_database" "curated" {
  name        = "${var.project}_curated"
  description = "Curated analytics-ready tables (Parquet, partitioned)"

  tags = var.tags
}

resource "aws_glue_catalog_database" "iceberg" {
  name        = "${var.project}_iceberg"
  description = "Apache Iceberg managed tables"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Glue Crawler — Raw zone (schema discovery)
# -----------------------------------------------------------------------------
resource "aws_glue_crawler" "raw" {
  name          = "${var.project}-raw-crawler"
  database_name = aws_glue_catalog_database.raw.name
  role          = var.glue_crawler_role_arn
  schedule      = var.crawler_schedule

  s3_target {
    path = "s3://${var.data_lake_bucket_name}/raw/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
    }
  })

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Glue Crawler — Curated zone
# -----------------------------------------------------------------------------
resource "aws_glue_crawler" "curated" {
  name          = "${var.project}-curated-crawler"
  database_name = aws_glue_catalog_database.curated.name
  role          = var.glue_crawler_role_arn
  schedule      = var.crawler_schedule

  s3_target {
    path = "s3://${var.data_lake_bucket_name}/curated/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Glue Crawler — Iceberg zone (uses Iceberg classification)
# -----------------------------------------------------------------------------
resource "aws_glue_crawler" "iceberg" {
  name          = "${var.project}-iceberg-crawler"
  database_name = aws_glue_catalog_database.iceberg.name
  role          = var.glue_crawler_role_arn
  schedule      = var.crawler_schedule

  s3_target {
    path = "s3://${var.data_lake_bucket_name}/iceberg/"
  }

  lake_formation_configuration {
    use_lake_formation_credentials = var.use_lake_formation
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Example Iceberg table (DDL via Athena is more common, but this shows Glue)
# This is a template — real tables are typically created by DAGs or Athena DDL
# -----------------------------------------------------------------------------
resource "aws_glue_catalog_table" "iceberg_example" {
  count         = var.create_example_iceberg_table ? 1 : 0
  name          = "example_events"
  database_name = aws_glue_catalog_database.iceberg.name

  table_type = "EXTERNAL_TABLE"

  open_table_format_input {
    iceberg_input {
      metadata_operation = "CREATE"
      version            = "2"
    }
  }

  storage_descriptor {
    location = "s3://${var.data_lake_bucket_name}/iceberg/example_events/"

    columns {
      name = "event_id"
      type = "string"
    }
    columns {
      name = "event_timestamp"
      type = "timestamp"
    }
    columns {
      name = "source"
      type = "string"
    }
    columns {
      name = "payload"
      type = "string"
    }
    columns {
      name = "ingested_at"
      type = "timestamp"
    }
  }

  parameters = {
    "table_type"              = "ICEBERG"
    "metadata_location"       = "s3://${var.data_lake_bucket_name}/iceberg/example_events/metadata/"
    "classification"          = "parquet"
  }
}
