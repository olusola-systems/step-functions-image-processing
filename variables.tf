variable "aws_region" {
  description = "AWS region for the Week 33 deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "week33-step-functions-image-processing"
}

variable "image_bucket_name" {
  description = "Name of the S3 bucket used for image uploads"
  type        = string
  default     = "week33-step-functions-image-processing-images-sfp8317"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB image analysis results table"
  type        = string
  default     = "week33-step-functions-image-processing-results"
}
