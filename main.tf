# Lambda & DynamoDB & API Gateway config. Adapted from https://github.com/aws-samples/serverless-patterns/blob/main/apigw-lambda-dynamodb-terraform/main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.9.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "random_string" "random" {
  length           = 4
  special          = false
}

resource "aws_dynamodb_table" "products_table" {
  name           = var.dynamodb_products_table
  billing_mode   = "PAY_PER_REQUEST"

  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "orders_table" {
  name           = var.dynamodb_orders_table
  billing_mode   = "PAY_PER_REQUEST"

  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}


#========================================================================
// lambda setup
#========================================================================

resource "aws_s3_bucket" "lambda_bucket" {
  bucket_prefix = var.s3_bucket_prefix
  force_destroy = true
}

resource "aws_s3_bucket_acl" "private_bucket" {
  bucket = aws_s3_bucket.lambda_bucket.id
  acl    = "private"
}

data "archive_file" "lambda_zip" {
  type = "zip"

  source_dir  = "${path.module}/src/post_requests"
  output_path = "${path.module}/post_request_src.zip"
}

data "archive_file" "lambda_get_request_zip" {
  type = "zip"

  source_dir  = "${path.module}/src/get_requests"
  output_path = "${path.module}/get_request_src.zip"
}

resource "aws_s3_object" "this" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "post_request_src.zip"
  source = data.archive_file.lambda_zip.output_path

  etag = filemd5(data.archive_file.lambda_zip.output_path)
}

resource "aws_s3_object" "this_get" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "get_request_src.zip"
  source = data.archive_file.lambda_get_request_zip.output_path

  etag = filemd5(data.archive_file.lambda_get_request_zip.output_path)
}

//Define lambda function
resource "aws_lambda_function" "apigw_lambda_ddb" {
  function_name = "${var.lambda_name}-${random_string.random.id}"
  description = "serverlessland pattern"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.this.key

  runtime = "python3.8"
  handler = "app.lambda_handler"

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  
  depends_on = [aws_cloudwatch_log_group.lambda_logs]
  
}

resource "aws_lambda_function" "apigw_get_request_handler" {
  function_name = "${var.lambda_get_request_name}-${random_string.random.id}"
  description = "serverlessland pattern"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.this_get.key

  runtime = "python3.8"
  handler = "app.lambda_handler"
  # https://github.com/jetbridge/psycopg2-lambda-layer
  layers  = ["arn:aws:lambda:${var.aws_region}:898466741470:layer:psycopg2-py38:1"]

  source_code_hash = data.archive_file.lambda_get_request_zip.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
        rds_port = aws_db_instance.education.port
        rds_address = aws_db_instance.education.address
        rds_username = var.rds_username
        rds_region = var.aws_region
        rds_db_name = aws_db_instance.education.db_name
        rds_password = var.rds_password  
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_get_request_logs]
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name = "/aws/lambda/${var.lambda_name}-${random_string.random.id}"

  retention_in_days = var.lambda_log_retention
}

resource "aws_cloudwatch_log_group" "lambda_get_request_logs" {
  name = "/aws/lambda/${var.lambda_get_request_name}-${random_string.random.id}"

  retention_in_days = var.lambda_log_retention
}

resource "aws_iam_role" "lambda_exec" {
  name = "LambdaDdbPost"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}


resource "aws_iam_policy" "lambda_exec_role" {
  name = "lambda-tf-pattern-ddb-post"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchGetItem",
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:Scan",
                "dynamodb:UpdateItem"
            ],
            "Resource": [
              "arn:aws:dynamodb:*:*:table/${var.dynamodb_products_table}",
              "arn:aws:dynamodb:*:*:table/${var.dynamodb_orders_table}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_exec_role.arn
}

#========================================================================
// API Gateway section
#========================================================================

resource "aws_apigatewayv2_api" "http_lambda" {
  name          = "${var.apigw_name}-${random_string.random.id}"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.http_lambda.id

  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
  depends_on = [aws_cloudwatch_log_group.api_gw]
}

resource "aws_apigatewayv2_integration" "apigw_lambda" {
  api_id = aws_apigatewayv2_api.http_lambda.id

  integration_uri    = aws_lambda_function.apigw_lambda_ddb.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "post_products" {
  api_id = aws_apigatewayv2_api.http_lambda.id

  route_key = "POST /products"
  target    = "integrations/${aws_apigatewayv2_integration.apigw_lambda.id}"
}

resource "aws_apigatewayv2_route" "post_orders" {
  api_id = aws_apigatewayv2_api.http_lambda.id

  route_key = "POST /orders"
  target    = "integrations/${aws_apigatewayv2_integration.apigw_lambda.id}"
}

resource "aws_apigatewayv2_integration" "apigw_get_request_lambda" {
  api_id = aws_apigatewayv2_api.http_lambda.id

  integration_uri    = aws_lambda_function.apigw_get_request_handler.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "get_products" {
  api_id = aws_apigatewayv2_api.http_lambda.id

  route_key = "GET /products"
  target    = "integrations/${aws_apigatewayv2_integration.apigw_get_request_lambda.id}"
}

resource "aws_apigatewayv2_route" "get_product" {
  api_id = aws_apigatewayv2_api.http_lambda.id

  route_key = "GET /product/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.apigw_get_request_lambda.id}"
}

resource "aws_apigatewayv2_route" "get_orders" {
  api_id = aws_apigatewayv2_api.http_lambda.id

  route_key = "GET /orders"
  target    = "integrations/${aws_apigatewayv2_integration.apigw_get_request_lambda.id}"
}

resource "aws_apigatewayv2_route" "get_order" {
  api_id = aws_apigatewayv2_api.http_lambda.id

  route_key = "GET /order/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.apigw_get_request_lambda.id}"
}

resource "aws_apigatewayv2_route" "get_order_products" {
  api_id = aws_apigatewayv2_api.http_lambda.id

  route_key = "GET /order/{id}/products"
  target    = "integrations/${aws_apigatewayv2_integration.apigw_get_request_lambda.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${var.apigw_name}-${random_string.random.id}"

  retention_in_days = var.apigw_log_retention
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.apigw_lambda_ddb.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.http_lambda.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_get_request" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.apigw_get_request_handler.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.http_lambda.execution_arn}/*/*"
}



#######################################
############## RDS & VPC ##############
#######################################
# RDS & VPC config. Adapted from https://github.com/hashicorp/learn-terraform-rds/blob/main/main.tf
data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.77.0"

  name                 = "education"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_db_subnet_group" "education" {
  name       = "education"
  subnet_ids = module.vpc.public_subnets

  tags = {
    Name = "Education"
  }
}

resource "aws_security_group" "rds" {
  name   = "education_rds"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "education_rds"
  }
}

resource "aws_db_parameter_group" "education" {
  name   = "education"
  family = "postgres14"

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

resource "aws_db_instance" "education" {
  identifier             = "education"
  db_name                = "education"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "14.1"
  username               = var.rds_username
  password               = var.rds_password
  db_subnet_group_name   = aws_db_subnet_group.education.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.education.name
  publicly_accessible    = true
  skip_final_snapshot    = true
}
