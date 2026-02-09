# AWS Data Ingestion Pipeline — Terraform Infrastructure

Complete Terraform infrastructure for a 4-flow data ingestion pipeline on AWS.

## Architecture Flows

| Flow | Path | Purpose |
|------|------|---------|
| **A** | External API → MWAA → S3 `raw/` | Scheduled/event-driven extraction |
| **B** | S3 `curated/` → Glue Catalog → Athena | SQL-on-S3 analytics |
| **C** | S3 `raw/` → MWAA DAG → Redshift | Warehouse loading (COPY + merge) |
| **D** | S3 `iceberg/` → Glue Catalog → Iceberg | Open table format lakehouse |

## Project Structure

```
terraform/
├── modules/
│   ├── vpc/              # VPC, subnets, NAT, IGW, VPC endpoints
│   ├── kms/              # Encryption keys
│   ├── s3/               # Data lake buckets, lifecycle, versioning
│   ├── iam/              # All IAM roles and policies
│   ├── secrets/          # Secrets Manager for API keys
│   ├── mwaa/             # Managed Airflow environment
│   ├── glue/             # Glue Data Catalog, databases, crawlers
│   ├── lakeformation/    # Lake Formation governance (optional)
│   ├── athena/           # Athena workgroup + named queries
│   ├── redshift/         # Redshift Serverless namespace/workgroup
│   ├── dynamodb/         # Load ledger table
│   ├── eventbridge/      # S3 event → Lambda → MWAA trigger
│   └── cloudwatch/       # Log groups, metric alarms, dashboard
├── envs/
│   └── dev/              # Dev environment root module
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── terraform.tfvars
│       └── backend.tf
└── dags/                 # Sample MWAA DAG files
    └── example_ingestion_dag.py
```

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured with appropriate credentials
- An AWS account with permissions to create all resources

## 🚀 Deployment Options

### Option 1: GitHub Actions CI/CD (Recommended)

Automated deployments from GitHub with OIDC authentication:

📘 **[Quick Start Guide](QUICKSTART.md)** - 5-step setup in ~20 minutes

📚 **[Detailed Setup Guide](GITHUB_AWS_SETUP.md)** - Complete documentation

**What you get:**
- ✅ Automated `terraform plan` on pull requests
- ✅ Automated `terraform apply` on merge to main
- ✅ No long-lived AWS credentials (uses OIDC)
- ✅ Terraform state stored in S3 with locking

### Option 2: Local Deployment

Manual deployment from your local machine:

```bash
# 1. Set up remote backend (one-time)
cd bootstrap
terraform init && terraform apply

# 2. Deploy infrastructure
cd ../envs/dev
cp terraform.tfvars.example terraform.tfvars   # edit with your values
terraform init
terraform plan
terraform apply
```

## Post-Deploy Steps

1. Upload DAGs to the MWAA S3 bucket: `aws s3 sync dags/ s3://<mwaa-bucket>/dags/`
2. Store API credentials in Secrets Manager (see outputs)
3. Verify MWAA web UI is accessible
4. Run the Glue Crawler to bootstrap catalog metadata
5. Test Athena queries against the curated/iceberg databases

## Cost Considerations

- MWAA `mw1.small` ≈ $0.49/hr (~$350/mo)
- Redshift Serverless bills per RPU-hour (starts at 8 RPU)
- NAT Gateway ≈ $0.045/hr + data processing
- Athena billed per TB scanned (use Parquet + partitions to minimize)
- S3 lifecycle rules transition raw data to IA/Glacier after configurable retention
