variable "project" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "key_deletion_window" {
  description = "Days before KMS key is permanently deleted"
  type        = number
  default     = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
