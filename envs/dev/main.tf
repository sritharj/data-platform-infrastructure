###############################################################################
# Root Module — Dev Environment
# Wires together all modules for the data ingestion pipeline
###############################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      CostCenter  = var.cost_center
    }
  }
}

locals {
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = var.cost_center
  }
}

# =============================================================================
# 1. KMS — Encryption key (used by everything)
# =============================================================================
module "kms" {
  source = "../../modules/kms"

  project    = var.project
  aws_region = var.aws_region
  tags       = local.tags
}

# =============================================================================
# 2. VPC — Networking foundation
# =============================================================================
module "vpc" {
  source = "../../modules/vpc"

  project    = var.project
  aws_region = var.aws_region
  vpc_cidr   = var.vpc_cidr
  az_count   = var.az_count
  tags       = local.tags

  enable_nat_gateway = true

  interface_endpoint_services = [
    "secretsmanager",
    "logs",
    "monitoring",
    "sqs",
    "kms",
    "airflow.api",
    "airflow.env",
    "airflow.ops",
    "ecr.dkr",
    "ecr.api",
    "redshift-data"
  ]
}

# =============================================================================
# 3. S3 — Data lake + MWAA DAGs + Athena results
# =============================================================================
module "s3" {
  source = "../../modules/s3"

  project     = var.project
  kms_key_arn = module.kms.key_arn
  tags        = local.tags

  force_destroy                   = var.environment == "dev" ? true : false
  enable_eventbridge_notifications = var.enable_event_driven_trigger

  raw_to_ia_days             = var.raw_to_ia_days
  raw_to_glacier_days        = var.raw_to_glacier_days
  raw_expiration_days        = var.raw_expiration_days
  quarantine_expiration_days = var.quarantine_expiration_days
}

# =============================================================================
# 4. DynamoDB — Load ledger (optional)
# =============================================================================
module "dynamodb" {
  source = "../../modules/dynamodb"

  project     = var.project
  kms_key_arn = module.kms.key_arn
  tags        = local.tags
}

# =============================================================================
# 5. IAM — All roles and policies
# =============================================================================
module "iam" {
  source = "../../modules/iam"

  project              = var.project
  data_lake_bucket_arn = module.s3.data_lake_bucket_arn
  mwaa_dags_bucket_arn = module.s3.mwaa_dags_bucket_arn
  kms_key_arn          = module.kms.key_arn
  dynamodb_table_arn   = module.dynamodb.table_arn
  tags                 = local.tags

  create_eventbridge_role = var.enable_event_driven_trigger
}

# =============================================================================
# 6. Secrets Manager — API keys + Airflow connections
# =============================================================================
module "secrets" {
  source = "../../modules/secrets"

  project     = var.project
  kms_key_arn = module.kms.key_arn
  tags        = local.tags

  redshift_endpoint = "pending"  # Updated after Redshift is created
  redshift_database = var.redshift_database
}

# =============================================================================
# 7. MWAA — Managed Airflow
# =============================================================================
module "mwaa" {
  source = "../../modules/mwaa"

  project            = var.project
  airflow_version    = var.airflow_version
  environment_class  = var.mwaa_environment_class
  max_workers        = var.mwaa_max_workers
  min_workers        = var.mwaa_min_workers
  dags_bucket_arn    = module.s3.mwaa_dags_bucket_arn
  execution_role_arn = module.iam.mwaa_execution_role_arn
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_id  = module.vpc.mwaa_security_group_id
  tags               = local.tags

  webserver_access_mode = var.mwaa_webserver_access_mode
  log_level             = var.mwaa_log_level
}

# =============================================================================
# 8. Glue — Data Catalog + Crawlers
# =============================================================================
module "glue" {
  source = "../../modules/glue"

  project               = var.project
  data_lake_bucket_name = module.s3.data_lake_bucket_name
  glue_crawler_role_arn = module.iam.glue_crawler_role_arn
  tags                  = local.tags

  crawler_schedule             = var.glue_crawler_schedule
  use_lake_formation           = var.enable_lake_formation
  create_example_iceberg_table = var.create_example_iceberg_table
}

# =============================================================================
# 9. Lake Formation — Optional governance
# =============================================================================
module "lakeformation" {
  count  = var.enable_lake_formation ? 1 : 0
  source = "../../modules/lakeformation"

  data_lake_bucket_arn  = module.s3.data_lake_bucket_arn
  glue_crawler_role_arn = module.iam.glue_crawler_role_arn
  redshift_role_arn     = module.iam.redshift_role_arn
  raw_database_name     = module.glue.raw_database_name
  curated_database_name = module.glue.curated_database_name
  iceberg_database_name = module.glue.iceberg_database_name
  lf_admin_principals   = var.lf_admin_principals
}

# =============================================================================
# 10. Athena — Workgroup + named queries
# =============================================================================
module "athena" {
  source = "../../modules/athena"

  project                    = var.project
  athena_results_bucket_name = module.s3.athena_results_bucket_name
  kms_key_arn                = module.kms.key_arn
  raw_database_name          = module.glue.raw_database_name
  curated_database_name      = module.glue.curated_database_name
  iceberg_database_name      = module.glue.iceberg_database_name
  tags                       = local.tags

  bytes_scanned_limit = var.athena_bytes_scanned_limit
  force_destroy       = var.environment == "dev" ? true : false
}

# =============================================================================
# 11. Redshift Serverless — Warehouse
# =============================================================================
module "redshift" {
  source = "../../modules/redshift"

  project            = var.project
  database_name      = var.redshift_database
  admin_username     = var.redshift_admin_username
  admin_password     = var.redshift_admin_password
  redshift_role_arn  = module.iam.redshift_role_arn
  kms_key_arn        = module.kms.key_arn
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_id  = module.vpc.redshift_security_group_id
  tags               = local.tags

  base_rpu          = var.redshift_base_rpu
  max_rpu           = var.redshift_max_rpu
  bootstrap_schemas = var.redshift_bootstrap_schemas
}

# =============================================================================
# 12. EventBridge + Lambda — Optional event-driven trigger
# =============================================================================
module "eventbridge" {
  count  = var.enable_event_driven_trigger ? 1 : 0
  source = "../../modules/eventbridge"

  project               = var.project
  data_lake_bucket_name = module.s3.data_lake_bucket_name
  lambda_role_arn       = module.iam.lambda_trigger_role_arn
  mwaa_environment_name = module.mwaa.mwaa_environment_name
  kms_key_arn           = module.kms.key_arn
  tags                  = local.tags

  trigger_dag_id = var.event_trigger_dag_id
}

# =============================================================================
# 13. CloudWatch — Observability + Alerting
# =============================================================================
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  project               = var.project
  aws_region            = var.aws_region
  kms_key_arn           = module.kms.key_arn
  mwaa_environment_name = module.mwaa.mwaa_environment_name
  tags                  = local.tags

  alert_email                      = var.alert_email
  min_expected_rows_per_hour       = var.min_expected_rows_per_hour
  quarantine_threshold             = var.quarantine_threshold
  freshness_sla_evaluation_periods = var.freshness_sla_evaluation_periods
}
