###############################################################################
# Lake Formation Module — Optional fine-grained access control
###############################################################################

# Register the data lake S3 location with Lake Formation
resource "aws_lakeformation_resource" "data_lake" {
  arn      = var.data_lake_bucket_arn
  role_arn = var.lf_admin_role_arn

  use_service_linked_role = var.lf_admin_role_arn == "" ? true : false
}

# Lake Formation settings — allow IAM-based access by default
# Tighten these as you mature your governance model
resource "aws_lakeformation_data_lake_settings" "main" {
  admins = var.lf_admin_principals

  create_database_default_permissions {
    principal   = "IAM_ALLOWED_PRINCIPALS"
    permissions = ["ALL"]
  }

  create_table_default_permissions {
    principal   = "IAM_ALLOWED_PRINCIPALS"
    permissions = ["ALL"]
  }
}

# Grant Glue crawler role access to databases
resource "aws_lakeformation_permissions" "glue_crawler_raw" {
  principal   = var.glue_crawler_role_arn
  permissions = ["ALL"]

  database {
    name = var.raw_database_name
  }
}

resource "aws_lakeformation_permissions" "glue_crawler_curated" {
  principal   = var.glue_crawler_role_arn
  permissions = ["ALL"]

  database {
    name = var.curated_database_name
  }
}

resource "aws_lakeformation_permissions" "glue_crawler_iceberg" {
  principal   = var.glue_crawler_role_arn
  permissions = ["ALL"]

  database {
    name = var.iceberg_database_name
  }
}

# Grant Redshift role access to read from Iceberg/curated databases
resource "aws_lakeformation_permissions" "redshift_iceberg" {
  principal   = var.redshift_role_arn
  permissions = ["SELECT", "DESCRIBE"]

  table {
    database_name = var.iceberg_database_name
    wildcard {}
  }
}
