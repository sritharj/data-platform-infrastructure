output "sns_topic_arn" {
  value = aws_sns_topic.pipeline_alerts.arn
}

output "dashboard_name" {
  value = aws_cloudwatch_dashboard.pipeline.dashboard_name
}
