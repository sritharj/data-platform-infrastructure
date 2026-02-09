###############################################################################
# Outputs — Dev Environment
###############################################################################

# ---- S3 --------------------------------------------------------------------
output "data_lake_bucket" {
  value = module.s3.data_lake_bucket_name
}

output "mwaa_dags_bucket" {
  value = module.s3.mwaa_dags_bucket_name
}

output "athena_results_bucket" {
  value = module.s3.athena_results_bucket_name
}

# ---- MWAA -------------------------------------------------------------------
output "mwaa_webserver_url" {
  value = module.mwaa.mwaa_webserver_url
}

output "mwaa_environment_name" {
  value = module.mwaa.mwaa_environment_name
}

# ---- Redshift ---------------------------------------------------------------
output "redshift_workgroup" {
  value = module.redshift.workgroup_name
}

output "redshift_endpoint" {
  value     = module.redshift.workgroup_endpoint
  sensitive = true
}

# ---- Glue -------------------------------------------------------------------
output "glue_databases" {
  value = {
    raw     = module.glue.raw_database_name
    curated = module.glue.curated_database_name
    iceberg = module.glue.iceberg_database_name
  }
}

# ---- Athena -----------------------------------------------------------------
output "athena_workgroup" {
  value = module.athena.workgroup_name
}

# ---- Networking -------------------------------------------------------------
output "vpc_id" {
  value = module.vpc.vpc_id
}

# ---- Secrets ----------------------------------------------------------------
output "api_credentials_secret_arn" {
  value = module.secrets.api_credentials_secret_arn
}

# ---- Observability ----------------------------------------------------------
output "cloudwatch_dashboard_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards/dashboard/${var.project}-pipeline"
}

output "sns_alerts_topic_arn" {
  value = module.cloudwatch.sns_topic_arn
}
