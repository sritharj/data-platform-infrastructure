output "event_rule_arn" {
  value = aws_cloudwatch_event_rule.s3_raw_landing.arn
}

output "lambda_function_arn" {
  value = aws_lambda_function.mwaa_trigger.arn
}
