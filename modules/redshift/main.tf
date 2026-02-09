###############################################################################
# Redshift Module — Serverless namespace + workgroup
###############################################################################

# -----------------------------------------------------------------------------
# Redshift Serverless Namespace (logical container: database, users, schemas)
# -----------------------------------------------------------------------------
resource "aws_redshiftserverless_namespace" "main" {
  namespace_name = "${var.project}-ns"
  db_name        = var.database_name
  admin_username = var.admin_username
  admin_user_password = var.admin_password

  iam_roles         = [var.redshift_role_arn]
  default_iam_role_arn = var.redshift_role_arn

  kms_key_id = var.kms_key_arn

  log_exports = ["userlog", "connectionlog", "useractivitylog"]

  tags = merge(var.tags, {
    Name = "${var.project}-redshift-ns"
  })
}

# -----------------------------------------------------------------------------
# Redshift Serverless Workgroup (compute: RPU, networking)
# -----------------------------------------------------------------------------
resource "aws_redshiftserverless_workgroup" "main" {
  workgroup_name = "${var.project}-wg"
  namespace_name = aws_redshiftserverless_namespace.main.namespace_name

  base_capacity    = var.base_rpu
  max_capacity     = var.max_rpu

  publicly_accessible = false

  subnet_ids         = var.private_subnet_ids
  security_group_ids = [var.security_group_id]

  config_parameter {
    parameter_key   = "enable_case_sensitive_identifier"
    parameter_value = "true"
  }

  config_parameter {
    parameter_key   = "auto_mv"
    parameter_value = "true"
  }

  tags = merge(var.tags, {
    Name = "${var.project}-redshift-wg"
  })
}

# -----------------------------------------------------------------------------
# Bootstrap schemas and audit table via Redshift Data API
# (runs once; use lifecycle ignore to prevent re-execution)
# -----------------------------------------------------------------------------
resource "aws_redshiftserverless_custom_domain_association" "placeholder" {
  # This is a placeholder — Redshift schema creation is best done by the
  # MWAA DAG on first run, or via a null_resource provisioner.
  # See the example DAG for CREATE SCHEMA / CREATE TABLE statements.
  count = 0
}

# null_resource to bootstrap schemas (optional — remove if using DAGs)
resource "null_resource" "bootstrap_schemas" {
  count = var.bootstrap_schemas ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOF
      aws redshift-data execute-statement \
        --workgroup-name ${aws_redshiftserverless_workgroup.main.workgroup_name} \
        --database ${var.database_name} \
        --sql "
          CREATE SCHEMA IF NOT EXISTS staging;
          CREATE SCHEMA IF NOT EXISTS warehouse;
          CREATE SCHEMA IF NOT EXISTS audit;

          CREATE TABLE IF NOT EXISTS audit.load_audit (
            load_id         BIGINT IDENTITY(1,1),
            s3_key          VARCHAR(1024) NOT NULL,
            s3_version_id   VARCHAR(256),
            source_name     VARCHAR(256),
            ingest_ts       TIMESTAMP DEFAULT GETDATE(),
            status          VARCHAR(50) DEFAULT 'IN_PROGRESS',
            row_count       BIGINT,
            error_message   VARCHAR(4096),
            dag_run_id      VARCHAR(256),
            PRIMARY KEY (load_id)
          )
          DISTSTYLE AUTO
          SORTKEY (ingest_ts);
        "
    EOF
  }

  depends_on = [aws_redshiftserverless_workgroup.main]
}
