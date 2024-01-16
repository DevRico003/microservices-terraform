output "lambda_bucket_name" {
  description = "Name of the S3 bucket used to store function code."

  value = aws_s3_bucket.lambda_terraform_16_1_24.id
}

output "function_name" {
  description = "Name of the Lambda function."

  value = aws_lambda_function.microservice1.function_name
}

output "base_url" {
  description = "Base URL for API Gateway stage."

  value = aws_apigatewayv2_stage.lambda.invoke_url
}

output "function_name2" {
  description = "Name of the Lambda function."

  value = aws_lambda_function.microservice2.function_name
}

output "base_url2" {
  description = "Base URL for API Gateway stage."

  value = aws_apigatewayv2_stage.lambda2.invoke_url
}