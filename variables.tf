# Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources."

  type    = string
  default = "eu-west-1"
}

variable "s3_bucket_prefix" {
  description = "S3 bucket prefix"
  type = string
  default = "apigw-lambda-ddb"
  
}

variable "dynamodb_products_table" {
  description = "ddb table name"
  type = string
  default = "Products"
  
}

variable "dynamodb_orders_table" {
  description = "ddb table name"
  type = string
  default = "Orders"
  
}

variable "lambda_name" {
  description = "name of the lambda function"
  type = string
  default = "pattern-products-post"
  
}

variable "lambda_get_request_name" {
  description = "name of the lambda function"
  type = string
  default = "pattern-products-get"
  
}

variable "apigw_name" {
  description = "name of the api gwy"
  type = string
  default = "apigw-http-lambda"
  
}

variable "lambda_log_retention" {
  description = "lambda log retention in days"
  type = number
  default = 7
}

variable "apigw_log_retention" {
  description = "api gwy log retention in days"
  type = number
  default = 7
}

# RDS variables set via 'secret.tfvars'

variable "rds_username" {
  description = "Database administrator username"
  type        = string
  sensitive   = true
}

variable "rds_password" {
  description = "RDS root user password"
  sensitive   = true
}
