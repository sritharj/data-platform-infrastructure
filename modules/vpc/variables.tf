variable "project" {
  description = "Project name prefix for all resources"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones (min 2 for MWAA)"
  type        = number
  default     = 2
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnet internet access"
  type        = bool
  default     = true
}

variable "interface_endpoint_services" {
  description = "List of AWS services for VPC Interface Endpoints (PrivateLink)"
  type        = list(string)
  default = [
    "secretsmanager",
    "logs",
    "monitoring",
    "sqs",
    "kms",
    "airflow.api",
    "airflow.env",
    "airflow.ops",
    "ecr.dkr",
    "ecr.api",
    "redshift-data"
  ]
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
