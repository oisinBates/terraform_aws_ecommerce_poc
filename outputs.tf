# Lambda & API Gateway output. Adapted from https://github.com/aws-samples/serverless-patterns/blob/main/apigw-lambda-dynamodb-terraform/outputs.tf

output "apigwy_url" {
  description = "URL for API Gateway stage"

  value = aws_apigatewayv2_stage.default.invoke_url
}

output "lambda_log_group" {
  description = "Name of the CloudWatch logs group for the lambda function"

  value = aws_cloudwatch_log_group.lambda_logs.id
}

output "apigwy_log_group" {
  description = "Name of the CloudWatch logs group for the lambda function"

  value = aws_cloudwatch_log_group.api_gw.id
}

# RDS output. Adapted from https://github.com/hashicorp/learn-terraform-rds/blob/main/outputs.tf
output "rds_hostname" {
  description = "RDS instance hostname"
  value       = aws_db_instance.education.address
  # sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.education.port
  # sensitive   = true
}
