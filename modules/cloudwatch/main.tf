###############################################################################
# CloudWatch Module — Log groups, metric alarms, dashboard
###############################################################################

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# SNS Topic for Alerts
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "pipeline_alerts" {
  name              = "${var.project}-pipeline-alerts"
  kms_master_key_id = var.kms_key_arn

  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.pipeline_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# -----------------------------------------------------------------------------
# MWAA DAG Failure Alarm
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "mwaa_dag_failure" {
  alarm_name          = "${var.project}-mwaa-dag-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "TaskInstanceFailures"
  namespace           = "AmazonMWAA"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "MWAA DAG task failures detected"
  alarm_actions       = [aws_sns_topic.pipeline_alerts.arn]
  ok_actions          = [aws_sns_topic.pipeline_alerts.arn]

  dimensions = {
    Function  = "TaskInstance"
    Environment = var.mwaa_environment_name
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Redshift Query Failure Alarm (via custom metric from DAG)
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "redshift_load_failures" {
  alarm_name          = "${var.project}-redshift-load-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RedshiftLoadFailures"
  namespace           = "${var.project}/Pipeline"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Redshift COPY/load failures detected"
  alarm_actions       = [aws_sns_topic.pipeline_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Row Count Anomaly Alarm (custom metric published by DAG)
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "row_count_anomaly" {
  alarm_name          = "${var.project}-row-count-anomaly"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "IngestedRowCount"
  namespace           = "${var.project}/Pipeline"
  period              = 3600
  statistic           = "Sum"
  threshold           = var.min_expected_rows_per_hour
  alarm_description   = "Row count below expected minimum — possible extraction failure"
  alarm_actions       = [aws_sns_topic.pipeline_alerts.arn]
  treat_missing_data  = "breaching"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Quarantine Growth Alarm
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "quarantine_growth" {
  alarm_name          = "${var.project}-quarantine-growth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "QuarantineFileCount"
  namespace           = "${var.project}/Pipeline"
  period              = 3600
  statistic           = "Sum"
  threshold           = var.quarantine_threshold
  alarm_description   = "Quarantine zone file count exceeding threshold"
  alarm_actions       = [aws_sns_topic.pipeline_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Freshness SLA Alarm (no data landed within expected window)
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "freshness_sla" {
  alarm_name          = "${var.project}-freshness-sla-breach"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.freshness_sla_evaluation_periods
  metric_name         = "SuccessfulIngestionRuns"
  namespace           = "${var.project}/Pipeline"
  period              = 3600
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "No successful ingestion run within SLA window"
  alarm_actions       = [aws_sns_topic.pipeline_alerts.arn]
  treat_missing_data  = "breaching"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# CloudWatch Dashboard
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "pipeline" {
  dashboard_name = "${var.project}-pipeline"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "MWAA DAG Task Status"
          metrics = [
            ["AmazonMWAA", "TaskInstanceFailures", "Function", "TaskInstance", "Environment", var.mwaa_environment_name, { stat = "Sum", color = "#d62728" }],
            ["AmazonMWAA", "TaskInstanceSuccesses", "Function", "TaskInstance", "Environment", var.mwaa_environment_name, { stat = "Sum", color = "#2ca02c" }]
          ]
          period = 300
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Ingested Row Counts"
          metrics = [
            ["${var.project}/Pipeline", "IngestedRowCount", { stat = "Sum", color = "#1f77b4" }]
          ]
          period = 3600
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Quarantine Files"
          metrics = [
            ["${var.project}/Pipeline", "QuarantineFileCount", { stat = "Sum", color = "#ff7f0e" }]
          ]
          period = 3600
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Redshift Load Status"
          metrics = [
            ["${var.project}/Pipeline", "RedshiftLoadFailures", { stat = "Sum", color = "#d62728" }],
            ["${var.project}/Pipeline", "RedshiftLoadSuccesses", { stat = "Sum", color = "#2ca02c" }]
          ]
          period = 300
          region = var.aws_region
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title  = "Recent MWAA Task Errors"
          query  = "SOURCE 'airflow-${var.mwaa_environment_name}-Task' | fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 50"
          region = var.aws_region
        }
      }
    ]
  })
}
