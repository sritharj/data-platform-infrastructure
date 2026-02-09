variable "project" {
  type = string
}

variable "data_lake_bucket_name" {
  type = string
}

variable "glue_crawler_role_arn" {
  type = string
}

variable "crawler_schedule" {
  description = "Cron schedule for crawlers (empty string = on demand)"
  type        = string
  default     = ""
}

variable "use_lake_formation" {
  description = "Use Lake Formation credentials for Iceberg crawler"
  type        = bool
  default     = false
}

variable "create_example_iceberg_table" {
  description = "Create an example Iceberg table in the catalog"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
