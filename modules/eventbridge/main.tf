###############################################################################
# EventBridge Module — S3 event → Lambda → MWAA DAG trigger (optional)
###############################################################################

# -----------------------------------------------------------------------------
# EventBridge Rule: S3 object created in raw/ prefix
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "s3_raw_landing" {
  name        = "${var.project}-s3-raw-landing"
  description = "Trigger on new objects in S3 raw/ prefix"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = { name = [var.data_lake_bucket_name] }
      object = { key = [{ prefix = "raw/" }] }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.s3_raw_landing.name
  arn  = aws_lambda_function.mwaa_trigger.arn
}

# -----------------------------------------------------------------------------
# Lambda Function: Triggers MWAA DAG via CLI token
# -----------------------------------------------------------------------------
data "archive_file" "mwaa_trigger" {
  type        = "zip"
  output_path = "${path.module}/lambda_payload.zip"

  source {
    content  = <<-PYTHON
import json
import boto3
import requests
import base64
import os

def lambda_handler(event, context):
    """Trigger MWAA DAG run when new S3 object lands in raw/."""
    mwaa_env = os.environ['MWAA_ENV_NAME']
    dag_id = os.environ.get('DAG_ID', 'ingestion_pipeline')

    # Extract S3 key from EventBridge event
    s3_key = event.get('detail', {}).get('object', {}).get('key', '')
    bucket = event.get('detail', {}).get('bucket', {}).get('name', '')

    print(f"Triggered by: s3://{bucket}/{s3_key}")

    # Get MWAA CLI token
    client = boto3.client('mwaa')
    token_response = client.create_cli_token(Name=mwaa_env)
    cli_token = token_response['CliToken']
    web_server = f"https://{token_response['WebServerHostname']}"

    # Trigger DAG via REST API
    conf = json.dumps({"s3_key": s3_key, "bucket": bucket})
    raw_data = f"dags trigger {dag_id} --conf '{conf}'"

    response = requests.post(
        f"{web_server}/aws_mwaa/cli",
        headers={"Authorization": f"Bearer {cli_token}", "Content-Type": "text/plain"},
        data=raw_data,
        timeout=30
    )

    output = base64.b64decode(response.json().get('stdout', '')).decode('utf-8')
    print(f"MWAA response: {output}")

    return {"statusCode": 200, "body": output}
    PYTHON
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "mwaa_trigger" {
  function_name    = "${var.project}-mwaa-trigger"
  role             = var.lambda_role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 128
  filename         = data.archive_file.mwaa_trigger.output_path
  source_code_hash = data.archive_file.mwaa_trigger.output_base64sha256

  environment {
    variables = {
      MWAA_ENV_NAME = var.mwaa_environment_name
      DAG_ID        = var.trigger_dag_id
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project}-mwaa-trigger"
  })
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mwaa_trigger.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_raw_landing.arn
}

# Lambda log group
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.mwaa_trigger.function_name}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}
