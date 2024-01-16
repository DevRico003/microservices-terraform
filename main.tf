provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      hashicorp-learn = "lambda-api-gateway"
    }
  }
}

# Microservice 1

## S3 Bucket for Lambda Deployment Package for Microservice 1
resource "random_pet" "lambda_terraform_16_1_24" {
  prefix = "learn-terraform-functions"
  length = 4
}

resource "aws_s3_bucket" "lambda_terraform_16_1_24" {
  bucket = random_pet.lambda_terraform_16_1_24.id
}

## DynamoDB Table for Microservice 1
resource "aws_dynamodb_table" "microservice1_table" {
  name     = "microservice1"
  hash_key = "Name"

  attribute {
    name = "Name"
    type = "S"
  }

  billing_mode = "PAY_PER_REQUEST"
}


resource "aws_s3_bucket_ownership_controls" "lambda_terraform_16_1_24" {
  bucket = aws_s3_bucket.lambda_terraform_16_1_24.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "lambda_terraform_16_1_24" {
  depends_on = [aws_s3_bucket_ownership_controls.lambda_terraform_16_1_24]

  bucket = aws_s3_bucket.lambda_terraform_16_1_24.id
  acl    = "private"
}

# Create Lambda deployment package
data "archive_file" "lambda_microservice1" {
  type = "zip"

  source_dir  = "${path.module}/microservice1"
  output_path = "${path.module}/microservice1.zip"
}

resource "aws_s3_object" "lambda_microservice1" {
  bucket = aws_s3_bucket.lambda_terraform_16_1_24.id

  key    = "microservice1.zip"
  source = data.archive_file.lambda_microservice1.output_path

  etag = filemd5(data.archive_file.lambda_microservice1.output_path)
}

# Create Lambda function
resource "aws_lambda_function" "microservice1" {
  function_name = "microservice1"

  s3_bucket = aws_s3_bucket.lambda_terraform_16_1_24.id
  s3_key    = aws_s3_object.lambda_microservice1.key

  runtime = "nodejs18.x"
  handler = "microservice1.handler"

  source_code_hash = data.archive_file.lambda_microservice1.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_cloudwatch_log_group" "microservice1" {
  name = "/aws/lambda/${aws_lambda_function.microservice1.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

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

resource "aws_iam_role_policy_attachment" "dynamodb_full_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}





data "aws_iam_policy_document" "lambda_policy_microservice1" {
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
    ]
    resources = [
      aws_dynamodb_table.microservice1_table.arn,
    ]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

## API Gateway for Microservice 1
resource "aws_apigatewayv2_api" "microservice1_api" {
  name          = "Microservice1API"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.microservice1_api.id

  name        = "serverless_lambda_stage"
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
}

## API Gateway Integration for Microservice 1 Lambda
resource "aws_apigatewayv2_integration" "microservice1_integration" {
  api_id             = aws_apigatewayv2_api.microservice1_api.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.microservice1.invoke_arn
}

## API Gateway Route for GET /health Microservice 1
resource "aws_apigatewayv2_route" "microservice1_health_get" {
  api_id    = aws_apigatewayv2_api.microservice1_api.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.microservice1_integration.id}"
}

## API Gateway Route for POST /save Microservice 1
resource "aws_apigatewayv2_route" "microservice1_save_post" {
  api_id    = aws_apigatewayv2_api.microservice1_api.id
  route_key = "POST /save"
  target    = "integrations/${aws_apigatewayv2_integration.microservice1_integration.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.microservice1_api.name}"

  retention_in_days = 30
}

## Lambda Permission for API Gateway to Invoke Lambda Microservice 1
resource "aws_lambda_permission" "api_gw_lambda_microservice1" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.microservice1.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.microservice1_api.execution_arn}/*/*"
}



# Microservice 2

## S3 Bucket for Lambda Deployment Package for Microservice 1
# resource "random_pet" "lambda_terraform_16_1_24" {
#   prefix = "learn-terraform-functions"
#   length = 4
# }

# resource "aws_s3_bucket" "lambda_terraform_16_1_24" {
#   bucket = random_pet.lambda_terraform_16_1_24.id
# }

## DynamoDB Table for Microservice 2
resource "aws_dynamodb_table" "microservice2_table" {
  name     = "microservice2"
  hash_key = "Name"

  attribute {
    name = "Name"
    type = "S"
  }

  billing_mode = "PAY_PER_REQUEST"
}


# resource "aws_s3_bucket_ownership_controls" "lambda_terraform_16_1_24" {
#   bucket = aws_s3_bucket.lambda_terraform_16_1_24.id
#   rule {
#     object_ownership = "BucketOwnerPreferred"
#   }
# }

# resource "aws_s3_bucket_acl" "lambda_terraform_16_1_24" {
#   depends_on = [aws_s3_bucket_ownership_controls.lambda_terraform_16_1_24]

#   bucket = aws_s3_bucket.lambda_terraform_16_1_24.id
#   acl    = "private"
# }

# Create Lambda deployment package
data "archive_file" "lambda_microservice2" {
  type = "zip"

  source_dir  = "${path.module}/microservice2"
  output_path = "${path.module}/microservice2.zip"
}

resource "aws_s3_object" "lambda_microservice2" {
  bucket = aws_s3_bucket.lambda_terraform_16_1_24.id

  key    = "microservice2.zip"
  source = data.archive_file.lambda_microservice2.output_path

  etag = filemd5(data.archive_file.lambda_microservice2.output_path)
}

# Create Lambda function
resource "aws_lambda_function" "microservice2" {
  function_name = "microservice2"

  s3_bucket = aws_s3_bucket.lambda_terraform_16_1_24.id
  s3_key    = aws_s3_object.lambda_microservice2.key

  runtime = "nodejs18.x"
  handler = "microservice2.handler"

  source_code_hash = data.archive_file.lambda_microservice2.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_cloudwatch_log_group" "microservice2" {
  name = "/aws/lambda/${aws_lambda_function.microservice2.function_name}"

  retention_in_days = 30
}

# resource "aws_iam_role" "lambda_exec" {
#   name = "serverless_lambda"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Sid    = ""
#       Principal = {
#         Service = "lambda.amazonaws.com"
#       }
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "dynamodb_full_access" {
#   role       = aws_iam_role.lambda_exec.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
# }

# resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
#   role       = aws_iam_role.lambda_exec.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
# }





data "aws_iam_policy_document" "lambda_policy_microservice2" {
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
    ]
    resources = [
      aws_dynamodb_table.microservice2_table.arn,
    ]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

## API Gateway for Microservice 2
resource "aws_apigatewayv2_api" "microservice2_api" {
  name          = "Microservice1API"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda2" {
  api_id = aws_apigatewayv2_api.microservice2_api.id

  name        = "serverless_lambda_stage"
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
}

## API Gateway Integration for Microservice 2 Lambda
resource "aws_apigatewayv2_integration" "microservice2_integration" {
  api_id             = aws_apigatewayv2_api.microservice2_api.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.microservice2.invoke_arn
}

## API Gateway Route for GET /health Microservice 2
resource "aws_apigatewayv2_route" "microservice2_health_get" {
  api_id    = aws_apigatewayv2_api.microservice2_api.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.microservice2_integration.id}"
}

## API Gateway Route for POST /save Microservice 2
resource "aws_apigatewayv2_route" "microservice2_save_post" {
  api_id    = aws_apigatewayv2_api.microservice2_api.id
  route_key = "POST /save"
  target    = "integrations/${aws_apigatewayv2_integration.microservice2_integration.id}"
}

resource "aws_cloudwatch_log_group" "api_gw2" {
  name = "/aws/api_gw2/${aws_apigatewayv2_api.microservice2_api.name}"

  retention_in_days = 30
}

## Lambda Permission for API Gateway to Invoke Lambda Microservice 2
resource "aws_lambda_permission" "api_gw_lambda_microservice2" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.microservice2.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.microservice2_api.execution_arn}/*/*"
}