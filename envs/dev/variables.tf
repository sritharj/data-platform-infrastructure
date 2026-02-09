###############################################################################
# Variables — Dev Environment
###############################################################################

# ---- General ----------------------------------------------------------------
variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cost_center" {
  description = "Cost allocation tag"
  type        = string
  default     = "data-engineering"
}

# ---- Networking -------------------------------------------------------------
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of AZs (min 2 for MWAA)"
  type        = number
  default     = 2
}

# ---- S3 Lifecycle -----------------------------------------------------------
variable "raw_to_ia_days" {
  type    = number
  default = 30
}

variable "raw_to_glacier_days" {
  type    = number
  default = 90
}

variable "raw_expiration_days" {
  type    = number
  default = 365
}

variable "quarantine_expiration_days" {
  type    = number
  default = 90
}

# ---- MWAA -------------------------------------------------------------------
variable "airflow_version" {
  type    = string
  default = "2.9.2"
}

variable "mwaa_environment_class" {
  description = "mw1.small | mw1.medium | mw1.large"
  type        = string
  default     = "mw1.small"
}

variable "mwaa_max_workers" {
  type    = number
  default = 5
}

variable "mwaa_min_workers" {
  type    = number
  default = 1
}

variable "mwaa_webserver_access_mode" {
  description = "PUBLIC_ONLY or PRIVATE_ONLY"
  type        = string
  default     = "PUBLIC_ONLY"
}

variable "mwaa_log_level" {
  type    = string
  default = "INFO"
}

# ---- Glue -------------------------------------------------------------------
variable "glue_crawler_schedule" {
  description = "Cron for Glue crawlers (empty = on-demand)"
  type        = string
  default     = ""
}

variable "create_example_iceberg_table" {
  type    = bool
  default = false
}

# ---- Lake Formation ---------------------------------------------------------
variable "enable_lake_formation" {
  type    = bool
  default = false
}

variable "lf_admin_principals" {
  type    = list(string)
  default = []
}

# ---- Athena -----------------------------------------------------------------
variable "athena_bytes_scanned_limit" {
  description = "Per-query byte scan limit (default 1 GB)"
  type        = number
  default     = 1073741824
}

# ---- Redshift ---------------------------------------------------------------
variable "redshift_database" {
  type    = string
  default = "warehouse"
}

variable "redshift_admin_username" {
  type    = string
  default = "admin"
}

variable "redshift_admin_password" {
  description = "Redshift admin password — set via TF_VAR or tfvars, never commit"
  type        = string
  sensitive   = true
}

variable "redshift_base_rpu" {
  type    = number
  default = 8
}

variable "redshift_max_rpu" {
  type    = number
  default = 32
}

variable "redshift_bootstrap_schemas" {
  description = "Run schema bootstrap on first apply"
  type        = bool
  default     = false
}

# ---- EventBridge (optional) -------------------------------------------------
variable "enable_event_driven_trigger" {
  description = "Deploy S3 event → Lambda → MWAA trigger"
  type        = bool
  default     = false
}

variable "event_trigger_dag_id" {
  type    = string
  default = "ingestion_pipeline"
}

# ---- CloudWatch / Alerting --------------------------------------------------
variable "alert_email" {
  description = "Email for SNS alarm notifications"
  type        = string
  default     = ""
}

variable "min_expected_rows_per_hour" {
  type    = number
  default = 1
}

variable "quarantine_threshold" {
  type    = number
  default = 10
}

variable "freshness_sla_evaluation_periods" {
  description = "Hours without ingestion before SLA alarm fires"
  type        = number
  default     = 4
}
