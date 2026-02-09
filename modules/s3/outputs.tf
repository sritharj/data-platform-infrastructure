output "data_lake_bucket_name" {
  value = aws_s3_bucket.data_lake.id
}

output "data_lake_bucket_arn" {
  value = aws_s3_bucket.data_lake.arn
}

output "mwaa_dags_bucket_name" {
  value = aws_s3_bucket.mwaa_dags.id
}

output "mwaa_dags_bucket_arn" {
  value = aws_s3_bucket.mwaa_dags.arn
}

output "athena_results_bucket_name" {
  value = aws_s3_bucket.athena_results.id
}

output "athena_results_bucket_arn" {
  value = aws_s3_bucket.athena_results.arn
}
