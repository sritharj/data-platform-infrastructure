output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (for MWAA, Redshift)"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "mwaa_security_group_id" {
  description = "Security group ID for MWAA"
  value       = aws_security_group.mwaa.id
}

output "redshift_security_group_id" {
  description = "Security group ID for Redshift"
  value       = aws_security_group.redshift.id
}

output "vpc_endpoint_s3_id" {
  description = "S3 VPC Gateway Endpoint ID"
  value       = aws_vpc_endpoint.s3.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}
