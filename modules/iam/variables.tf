variable "project" {
  type = string
}

variable "data_lake_bucket_arn" {
  type = string
}

variable "mwaa_dags_bucket_arn" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "dynamodb_table_arn" {
  description = "DynamoDB load ledger table ARN (empty string if not used)"
  type        = string
  default     = ""
}

variable "create_eventbridge_role" {
  description = "Create the Lambda/EventBridge trigger role"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
