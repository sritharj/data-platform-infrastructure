output "api_credentials_secret_arn" {
  value = aws_secretsmanager_secret.api_credentials.arn
}

output "airflow_redshift_conn_secret_arn" {
  value = aws_secretsmanager_secret.airflow_redshift_conn.arn
}
