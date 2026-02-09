variable "project" {
  type = string
}

variable "database_name" {
  type    = string
  default = "warehouse"
}

variable "admin_username" {
  type    = string
  default = "admin"
}

variable "admin_password" {
  description = "Redshift admin password (use tfvars or secrets, never commit)"
  type        = string
  sensitive   = true
}

variable "redshift_role_arn" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "base_rpu" {
  description = "Base RPU capacity (min 8)"
  type        = number
  default     = 8
}

variable "max_rpu" {
  description = "Max RPU capacity for auto-scaling"
  type        = number
  default     = 32
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "bootstrap_schemas" {
  description = "Run schema bootstrap via Data API on first apply"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
