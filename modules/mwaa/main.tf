###############################################################################
# MWAA Module — Amazon Managed Workflows for Apache Airflow
###############################################################################

resource "aws_mwaa_environment" "main" {
  name               = "${var.project}-mwaa"
  airflow_version    = var.airflow_version
  environment_class  = var.environment_class
  max_workers        = var.max_workers
  min_workers        = var.min_workers

  source_bucket_arn    = var.dags_bucket_arn
  dag_s3_path          = "dags/"
  plugins_s3_path      = var.plugins_s3_path
  requirements_s3_path = var.requirements_s3_path
  execution_role_arn   = var.execution_role_arn

  webserver_access_mode = var.webserver_access_mode

  network_configuration {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.security_group_id]
  }

  logging_configuration {
    dag_processing_logs {
      enabled   = true
      log_level = var.log_level
    }
    scheduler_logs {
      enabled   = true
      log_level = var.log_level
    }
    task_logs {
      enabled   = true
      log_level = var.log_level
    }
    webserver_logs {
      enabled   = true
      log_level = var.log_level
    }
    worker_logs {
      enabled   = true
      log_level = var.log_level
    }
  }

  # Airflow configuration overrides
  airflow_configuration_options = merge(
    {
      # Secrets Manager backend for connections/variables
      "secrets.backend"                          = "airflow.providers.amazon.aws.secrets.secrets_manager.SecretsManagerBackend"
      "secrets.backend_kwargs"                   = jsonencode({ connections_prefix = "${var.project}/airflow/connections", variables_prefix = "${var.project}/airflow/variables" })
      "core.default_timezone"                    = "utc"
      "core.load_default_connections"            = "false"
      "webserver.default_ui_timezone"            = "utc"
      "celery.worker_autoscale"                  = "${var.max_workers},${var.min_workers}"
      "core.dag_file_processor_timeout"          = "300"
      "scheduler.catchup_by_default"             = "false"
    },
    var.airflow_configuration_overrides
  )

  tags = merge(var.tags, {
    Name = "${var.project}-mwaa"
  })
}
