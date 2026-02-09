variable "project" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "redshift_endpoint" {
  description = "Redshift endpoint for Airflow connection"
  type        = string
  default     = "pending"
}

variable "redshift_database" {
  description = "Redshift database name"
  type        = string
  default     = "warehouse"
}

variable "enable_rotation" {
  type    = bool
  default = false
}

variable "rotation_lambda_arn" {
  type    = string
  default = ""
}

variable "rotation_days" {
  type    = number
  default = 90
}

variable "tags" {
  type    = map(string)
  default = {}
}
