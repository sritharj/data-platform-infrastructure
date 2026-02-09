###############################################################################
# Secrets Manager Module — API keys and Airflow connections
###############################################################################

resource "aws_secretsmanager_secret" "api_credentials" {
  name        = "${var.project}/api-credentials"
  description = "External API credentials for ${var.project} data ingestion"
  kms_key_id  = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.project}-api-credentials"
  })
}

# Placeholder value — update post-deploy with actual credentials
resource "aws_secretsmanager_secret_version" "api_credentials" {
  secret_id = aws_secretsmanager_secret.api_credentials.id
  secret_string = jsonencode({
    api_key    = "REPLACE_ME"
    api_secret = "REPLACE_ME"
    base_url   = "https://api.example.com"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Airflow connection secret (MWAA reads from secrets manager backend)
# Prefix: airflow/connections/ for MWAA secrets backend integration
resource "aws_secretsmanager_secret" "airflow_redshift_conn" {
  name        = "${var.project}/airflow/connections/redshift_default"
  description = "Airflow connection to Redshift for ${var.project}"
  kms_key_id  = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.project}-airflow-redshift-conn"
  })
}

resource "aws_secretsmanager_secret_version" "airflow_redshift_conn" {
  secret_id = aws_secretsmanager_secret.airflow_redshift_conn.id
  secret_string = jsonencode({
    conn_type = "redshift"
    host      = var.redshift_endpoint
    port      = 5439
    schema    = var.redshift_database
    login     = "admin"
    password  = "REPLACE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Enable automatic rotation schedule (optional)
resource "aws_secretsmanager_secret_rotation" "api_credentials" {
  count               = var.enable_rotation ? 1 : 0
  secret_id           = aws_secretsmanager_secret.api_credentials.id
  rotation_lambda_arn = var.rotation_lambda_arn

  rotation_rules {
    automatically_after_days = var.rotation_days
  }
}
