output "mwaa_execution_role_arn" {
  value = aws_iam_role.mwaa_execution.arn
}

output "redshift_role_arn" {
  value = aws_iam_role.redshift.arn
}

output "glue_crawler_role_arn" {
  value = aws_iam_role.glue_crawler.arn
}

output "lambda_trigger_role_arn" {
  value = var.create_eventbridge_role ? aws_iam_role.lambda_mwaa_trigger[0].arn : ""
}
