variable "project" {
  type = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for SSE-KMS encryption"
  type        = string
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete non-empty buckets"
  type        = bool
  default     = false
}

variable "enable_eventbridge_notifications" {
  description = "Enable S3 → EventBridge notifications for event-driven triggering"
  type        = bool
  default     = false
}

variable "raw_to_ia_days" {
  description = "Days before raw/ transitions to Infrequent Access"
  type        = number
  default     = 30
}

variable "raw_to_glacier_days" {
  description = "Days before raw/ transitions to Glacier"
  type        = number
  default     = 90
}

variable "raw_expiration_days" {
  description = "Days before raw/ objects expire"
  type        = number
  default     = 365
}

variable "quarantine_expiration_days" {
  description = "Days before quarantine/ objects expire"
  type        = number
  default     = 90
}

variable "tags" {
  type    = map(string)
  default = {}
}
