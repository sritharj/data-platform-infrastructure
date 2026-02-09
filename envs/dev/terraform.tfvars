###############################################################################
# terraform.tfvars — Dev Environment (copy to terraform.tfvars and edit)
###############################################################################

project     = "dataingestion"
environment = "dev"
aws_region  = "us-east-1"
cost_center = "data-engineering"

# Networking
vpc_cidr = "10.0.0.0/16"
az_count = 2

# S3 Lifecycle
raw_to_ia_days             = 30
raw_to_glacier_days        = 90
raw_expiration_days        = 365
quarantine_expiration_days = 90

# MWAA
airflow_version            = "2.9.2"
mwaa_environment_class     = "mw1.small"
mwaa_max_workers           = 5
mwaa_min_workers           = 1
mwaa_webserver_access_mode = "PUBLIC_ONLY"
mwaa_log_level             = "INFO"

# Glue
glue_crawler_schedule        = ""    # On-demand; set "cron(0 */6 * * ? *)" for every 6hrs
create_example_iceberg_table = false

# Lake Formation (disabled by default)
enable_lake_formation = false
lf_admin_principals   = []

# Athena
athena_bytes_scanned_limit = 1073741824  # 1 GB

# Redshift Serverless
redshift_database          = "warehouse"
redshift_admin_username    = "admin"
redshift_admin_password    = "CHANGE_ME_use_TF_VAR_or_secrets"  # ← CHANGE THIS
redshift_base_rpu          = 8
redshift_max_rpu           = 32
redshift_bootstrap_schemas = false

# EventBridge (optional event-driven trigger)
enable_event_driven_trigger = false
event_trigger_dag_id        = "ingestion_pipeline"

# Alerting
alert_email                      = ""  # Set to receive alarm emails
min_expected_rows_per_hour       = 1
quarantine_threshold             = 10
freshness_sla_evaluation_periods = 4
