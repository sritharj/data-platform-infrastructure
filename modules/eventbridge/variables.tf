variable "project" {
  type = string
}

variable "data_lake_bucket_name" {
  type = string
}

variable "lambda_role_arn" {
  type = string
}

variable "mwaa_environment_name" {
  type = string
}

variable "trigger_dag_id" {
  description = "DAG ID to trigger on S3 event"
  type        = string
  default     = "ingestion_pipeline"
}

variable "kms_key_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
