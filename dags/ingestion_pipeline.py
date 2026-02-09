"""
Example MWAA DAG — Data Ingestion Pipeline
Covers Flow A (API → S3), Flow C (S3 → Redshift), and Flow D (S3 → Iceberg).

Upload to: s3://<mwaa-dags-bucket>/dags/ingestion_pipeline.py
"""

from datetime import datetime, timedelta
import json
import gzip
import hashlib

from airflow import DAG
from airflow.decorators import task
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from airflow.providers.amazon.aws.hooks.secrets_manager import SecretsManagerHook
from airflow.providers.amazon.aws.hooks.redshift_data import RedshiftDataHook

# ---------------------------------------------------------------------------
# Configuration — update these after terraform apply
# ---------------------------------------------------------------------------
PROJECT = "dataingestion"
DATA_LAKE_BUCKET = f"{PROJECT}-data-lake"  # Append account ID
REDSHIFT_WORKGROUP = f"{PROJECT}-wg"
REDSHIFT_DATABASE = "warehouse"
API_SECRET_NAME = f"{PROJECT}/api-credentials"
SOURCE_NAME = "example_api"

default_args = {
    "owner": "data-engineering",
    "depends_on_past": False,
    "retries": 3,
    "retry_delay": timedelta(minutes=5),
    "retry_exponential_backoff": True,
    "execution_timeout": timedelta(hours=1),
}

with DAG(
    dag_id="ingestion_pipeline",
    default_args=default_args,
    description="API extraction → S3 raw → Redshift warehouse",
    schedule="0 */4 * * *",
    start_date=datetime(2025, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=["ingestion", PROJECT],
) as dag:

    # -----------------------------------------------------------------------
    # FLOW A: Extract from API → S3 raw/
    # -----------------------------------------------------------------------
    @task
    def extract_api_data(**context):
        """Pull data from external API and land in S3 raw/ zone."""
        import requests

        logical_date = context["logical_date"].strftime("%Y-%m-%d")
        execution_ts = context["logical_date"].strftime("%Y%m%dT%H%M%S")

        secrets_hook = SecretsManagerHook()
        secret = json.loads(secrets_hook.get_secret_value(secret_id=API_SECRET_NAME))
        base_url = secret["base_url"]
        api_key = secret["api_key"]

        all_records = []
        page = 1

        while page <= 100:
            resp = requests.get(
                f"{base_url}/data",
                headers={"Authorization": f"Bearer {api_key}"},
                params={"page": page, "date": logical_date},
                timeout=30,
            )
            resp.raise_for_status()
            records = resp.json().get("results", [])
            if not records:
                break
            all_records.extend(records)
            page += 1

        if not all_records:
            return {"s3_key": None, "row_count": 0}

        payload = json.dumps(all_records, default=str)
        compressed = gzip.compress(payload.encode("utf-8"))

        params_hash = hashlib.md5(logical_date.encode()).hexdigest()[:8]
        s3_key = (
            f"raw/source={SOURCE_NAME}/dt={logical_date}/"
            f"{execution_ts}_{params_hash}.json.gz"
        )

        s3_hook = S3Hook()
        if s3_hook.check_for_key(key=s3_key, bucket_name=DATA_LAKE_BUCKET):
            return {"s3_key": s3_key, "row_count": len(all_records)}

        s3_hook.load_bytes(
            bytes_data=compressed,
            key=s3_key,
            bucket_name=DATA_LAKE_BUCKET,
            replace=False,
        )
        return {"s3_key": s3_key, "row_count": len(all_records)}

    # -----------------------------------------------------------------------
    # Validate raw data
    # -----------------------------------------------------------------------
    @task
    def validate_data(extract_result: dict, **context):
        """Basic validations; quarantine bad files."""
        s3_key = extract_result.get("s3_key")
        row_count = extract_result.get("row_count", 0)

        if s3_key is None:
            return {"status": "skip", "s3_key": None, "row_count": 0}

        s3_hook = S3Hook()

        # Size check
        metadata = s3_hook.head_object(key=s3_key, bucket_name=DATA_LAKE_BUCKET)
        size_bytes = metadata.get("ContentLength", 0)
        max_size = 500 * 1024 * 1024  # 500MB

        if size_bytes > max_size:
            quarantine_key = s3_key.replace("raw/", "quarantine/", 1)
            s3_hook.copy_object(
                source_bucket_name=DATA_LAKE_BUCKET,
                source_bucket_key=s3_key,
                dest_bucket_name=DATA_LAKE_BUCKET,
                dest_bucket_key=quarantine_key,
            )
            raise ValueError(f"File too large ({size_bytes} bytes): {s3_key}")

        if row_count == 0:
            raise ValueError(f"Zero rows extracted for {s3_key}")

        return {"status": "valid", "s3_key": s3_key, "row_count": row_count}

    # -----------------------------------------------------------------------
    # FLOW C: Load S3 → Redshift (COPY + Merge)
    # -----------------------------------------------------------------------
    @task
    def load_to_redshift(validation_result: dict, **context):
        """COPY from S3 to Redshift staging, then merge to target."""
        if validation_result.get("status") == "skip":
            return {"status": "skipped"}

        s3_key = validation_result["s3_key"]
        row_count = validation_result["row_count"]
        logical_date = context["logical_date"].strftime("%Y-%m-%d")
        dag_run_id = context["run_id"]

        redshift = RedshiftDataHook(
            region_name="us-east-1",
            workgroup_name=REDSHIFT_WORKGROUP,
            database=REDSHIFT_DATABASE,
        )

        # 1. Insert audit record
        redshift.execute_query(
            sql=f"""
                INSERT INTO audit.load_audit (s3_key, source_name, dag_run_id, status)
                VALUES ('{s3_key}', '{SOURCE_NAME}', '{dag_run_id}', 'IN_PROGRESS');
            """,
            poll_interval=5,
        )

        try:
            # 2. COPY to staging
            redshift.execute_query(
                sql=f"""
                    CREATE TEMP TABLE staging_events (LIKE warehouse.events);

                    COPY staging_events
                    FROM 's3://{DATA_LAKE_BUCKET}/{s3_key}'
                    IAM_ROLE default
                    FORMAT AS JSON 'auto'
                    GZIP
                    COMPUPDATE OFF
                    STATUPDATE OFF
                    TIMEFORMAT 'auto';
                """,
                poll_interval=5,
            )

            # 3. Merge / Upsert into target
            redshift.execute_query(
                sql=f"""
                    MERGE INTO warehouse.events AS target
                    USING staging_events AS source
                    ON target.event_id = source.event_id
                    WHEN MATCHED THEN
                        UPDATE SET
                            payload = source.payload,
                            updated_at = GETDATE()
                    WHEN NOT MATCHED THEN
                        INSERT VALUES (
                            source.event_id,
                            source.event_timestamp,
                            source.source,
                            source.payload,
                            GETDATE()
                        );
                """,
                poll_interval=5,
            )

            # 4. Update audit as success
            redshift.execute_query(
                sql=f"""
                    UPDATE audit.load_audit
                    SET status = 'SUCCESS', row_count = {row_count}
                    WHERE s3_key = '{s3_key}' AND dag_run_id = '{dag_run_id}';
                """,
                poll_interval=5,
            )

            return {"status": "success", "rows": row_count}

        except Exception as e:
            redshift.execute_query(
                sql=f"""
                    UPDATE audit.load_audit
                    SET status = 'FAILED', error_message = '{str(e)[:4000]}'
                    WHERE s3_key = '{s3_key}' AND dag_run_id = '{dag_run_id}';
                """,
                poll_interval=5,
            )
            raise

    # -----------------------------------------------------------------------
    # Publish custom CloudWatch metrics
    # -----------------------------------------------------------------------
    @task
    def publish_metrics(load_result: dict, **context):
        """Publish pipeline metrics to CloudWatch for alarming."""
        import boto3

        cw = boto3.client("cloudwatch")
        metrics = [
            {
                "MetricName": "IngestedRowCount",
                "Value": load_result.get("rows", 0),
                "Unit": "Count",
            },
            {
                "MetricName": "SuccessfulIngestionRuns",
                "Value": 1 if load_result.get("status") == "success" else 0,
                "Unit": "Count",
            },
        ]

        cw.put_metric_data(
            Namespace=f"{PROJECT}/Pipeline",
            MetricData=[
                {**m, "Timestamp": context["logical_date"]} for m in metrics
            ],
        )

    # -----------------------------------------------------------------------
    # DAG wiring
    # -----------------------------------------------------------------------
    extracted = extract_api_data()
    validated = validate_data(extracted)
    loaded = load_to_redshift(validated)
    publish_metrics(loaded)
