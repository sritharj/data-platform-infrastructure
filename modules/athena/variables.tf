variable "project" {
  type = string
}

variable "athena_results_bucket_name" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "raw_database_name" {
  type = string
}

variable "curated_database_name" {
  type = string
}

variable "iceberg_database_name" {
  type = string
}

variable "bytes_scanned_limit" {
  description = "Per-query byte scan limit (cost control). Default 1GB."
  type        = number
  default     = 1073741824
}

variable "force_destroy" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
