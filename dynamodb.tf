resource "aws_dynamodb_table" "image_results" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "imageId"

  attribute {
    name = "imageId"
    type = "S"
  }

  tags = {
    Name    = var.dynamodb_table_name
    Project = var.project_name
  }
}
