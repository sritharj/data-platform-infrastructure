output "mwaa_arn" {
  value = aws_mwaa_environment.main.arn
}

output "mwaa_webserver_url" {
  value = aws_mwaa_environment.main.webserver_url
}

output "mwaa_environment_name" {
  value = aws_mwaa_environment.main.name
}
