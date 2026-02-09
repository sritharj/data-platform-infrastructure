variable "project" {
  type = string
}

variable "airflow_version" {
  type    = string
  default = "2.9.2"
}

variable "environment_class" {
  description = "mw1.small | mw1.medium | mw1.large | mw1.xlarge | mw1.2xlarge"
  type        = string
  default     = "mw1.small"
}

variable "max_workers" {
  type    = number
  default = 5
}

variable "min_workers" {
  type    = number
  default = 1
}

variable "dags_bucket_arn" {
  type = string
}

variable "plugins_s3_path" {
  type    = string
  default = null
}

variable "requirements_s3_path" {
  type    = string
  default = null
}

variable "execution_role_arn" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "webserver_access_mode" {
  description = "PUBLIC_ONLY or PRIVATE_ONLY"
  type        = string
  default     = "PUBLIC_ONLY"
}

variable "log_level" {
  type    = string
  default = "INFO"
}

variable "airflow_configuration_overrides" {
  description = "Additional Airflow config overrides"
  type        = map(string)
  default     = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
