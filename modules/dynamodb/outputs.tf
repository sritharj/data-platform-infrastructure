output "table_name" {
  value = aws_dynamodb_table.load_ledger.name
}

output "table_arn" {
  value = aws_dynamodb_table.load_ledger.arn
}
