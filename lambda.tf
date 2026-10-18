data "archive_file" "validate_image" {
  type        = "zip"
  source_file = "${path.module}/lambda/validate_image.py"
  output_path = "${path.module}/validate_image.zip"
}

data "archive_file" "analyze_image" {
  type        = "zip"
  source_file = "${path.module}/lambda/analyze_image.py"
  output_path = "${path.module}/analyze_image.zip"
}

data "archive_file" "save_results" {
  type        = "zip"
  source_file = "${path.module}/lambda/save_results.py"
  output_path = "${path.module}/save_results.zip"
}

# --------------------------------------------------
# Validation Lambda IAM Role
# --------------------------------------------------

resource "aws_iam_role" "validate_image" {
  name = "${var.project_name}-validate-image-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "validate_image_logs" {
  role       = aws_iam_role.validate_image.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --------------------------------------------------
# Analysis Lambda IAM Role
# --------------------------------------------------

resource "aws_iam_role" "analyze_image" {
  name = "${var.project_name}-analyze-image-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "analyze_image_logs" {
  role       = aws_iam_role.analyze_image.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "analyze_image_permissions" {
  name = "${var.project_name}-analyze-image-policy"
  role = aws_iam_role.analyze_image.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["rekognition:DetectLabels"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.images.arn}/*"
      }
    ]
  })
}

# --------------------------------------------------
# Save Results Lambda IAM Role
# --------------------------------------------------

resource "aws_iam_role" "save_results" {
  name = "${var.project_name}-save-results-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "save_results_logs" {
  role       = aws_iam_role.save_results.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "save_results_permissions" {
  name = "${var.project_name}-save-results-policy"
  role = aws_iam_role.save_results.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.image_results.arn
      }
    ]
  })
}

# --------------------------------------------------
# Validation Lambda Function
# --------------------------------------------------

resource "aws_lambda_function" "validate_image" {
  function_name = "${var.project_name}-validate-image"
  role          = aws_iam_role.validate_image.arn
  handler       = "validate_image.lambda_handler"
  runtime       = "python3.12"

  filename         = data.archive_file.validate_image.output_path
  source_code_hash = data.archive_file.validate_image.output_base64sha256

  depends_on = [
    aws_iam_role_policy_attachment.validate_image_logs
  ]

  tags = {
    Project = var.project_name
  }
}

# --------------------------------------------------
# Analysis Lambda Function
# --------------------------------------------------

resource "aws_lambda_function" "analyze_image" {
  function_name = "${var.project_name}-analyze-image"
  role          = aws_iam_role.analyze_image.arn
  handler       = "analyze_image.lambda_handler"
  runtime       = "python3.12"

  filename         = data.archive_file.analyze_image.output_path
  source_code_hash = data.archive_file.analyze_image.output_base64sha256

  depends_on = [
    aws_iam_role_policy_attachment.analyze_image_logs,
    aws_iam_role_policy.analyze_image_permissions
  ]

  tags = {
    Project = var.project_name
  }
}

# --------------------------------------------------
# Save Results Lambda Function
# --------------------------------------------------

resource "aws_lambda_function" "save_results" {
  function_name = "${var.project_name}-save-results"
  role          = aws_iam_role.save_results.arn
  handler       = "save_results.lambda_handler"
  runtime       = "python3.12"

  filename         = data.archive_file.save_results.output_path
  source_code_hash = data.archive_file.save_results.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.image_results.name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.save_results_logs,
    aws_iam_role_policy.save_results_permissions
  ]

  tags = {
    Project = var.project_name
  }
}
