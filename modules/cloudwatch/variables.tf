variable "project" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "mwaa_environment_name" {
  type = string
}

variable "alert_email" {
  description = "Email address for SNS alarm notifications"
  type        = string
  default     = ""
}

variable "min_expected_rows_per_hour" {
  description = "Minimum expected rows per hour before alarming"
  type        = number
  default     = 1
}

variable "quarantine_threshold" {
  description = "Max quarantine files per hour before alarming"
  type        = number
  default     = 10
}

variable "freshness_sla_evaluation_periods" {
  description = "Number of 1hr periods without data before SLA breach alarm"
  type        = number
  default     = 4
}

variable "tags" {
  type    = map(string)
  default = {}
}
