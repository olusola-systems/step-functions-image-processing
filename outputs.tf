output "aws_region" {
  description = "AWS region hosting the workflow"
  value       = var.aws_region
}

output "image_bucket_name" {
  description = "S3 bucket used for image uploads"
  value       = aws_s3_bucket.images.bucket
}

output "dynamodb_table_name" {
  description = "DynamoDB table storing image analysis results"
  value       = aws_dynamodb_table.image_results.name
}

output "validate_image_function_name" {
  description = "Image validation Lambda function"
  value       = aws_lambda_function.validate_image.function_name
}

output "analyze_image_function_name" {
  description = "Image analysis Lambda function"
  value       = aws_lambda_function.analyze_image.function_name
}

output "save_results_function_name" {
  description = "Results storage Lambda function"
  value       = aws_lambda_function.save_results.function_name
}

output "state_machine_arn" {
  description = "Step Functions image processing state machine ARN"
  value       = aws_sfn_state_machine.image_processing.arn
}
