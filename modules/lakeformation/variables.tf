variable "data_lake_bucket_arn" {
  type = string
}

variable "lf_admin_role_arn" {
  description = "Lake Formation admin role ARN (empty = use service-linked role)"
  type        = string
  default     = ""
}

variable "lf_admin_principals" {
  description = "List of IAM ARNs to designate as Lake Formation admins"
  type        = list(string)
  default     = []
}

variable "glue_crawler_role_arn" {
  type = string
}

variable "redshift_role_arn" {
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
