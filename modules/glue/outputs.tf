output "raw_database_name" {
  value = aws_glue_catalog_database.raw.name
}

output "curated_database_name" {
  value = aws_glue_catalog_database.curated.name
}

output "iceberg_database_name" {
  value = aws_glue_catalog_database.iceberg.name
}

output "raw_crawler_name" {
  value = aws_glue_crawler.raw.name
}

output "curated_crawler_name" {
  value = aws_glue_crawler.curated.name
}

output "iceberg_crawler_name" {
  value = aws_glue_crawler.iceberg.name
}
