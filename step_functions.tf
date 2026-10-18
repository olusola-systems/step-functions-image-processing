resource "aws_iam_role" "step_functions" {
  name = "${var.project_name}-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy" "step_functions_invoke_lambda" {
  name = "${var.project_name}-invoke-lambda-policy"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "lambda:InvokeFunction"
      ]
      Resource = [
        aws_lambda_function.validate_image.arn,
        aws_lambda_function.analyze_image.arn,
        aws_lambda_function.save_results.arn
      ]
    }]
  })
}

resource "aws_sfn_state_machine" "image_processing" {
  name     = "${var.project_name}-workflow"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment = "Validate, analyze, and store image intelligence results"
    StartAt = "ValidateImage"

    States = {
      ValidateImage = {
        Type     = "Task"
        Resource = aws_lambda_function.validate_image.arn
        Next     = "AnalyzeImage"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "ProcessingFailed"
        }]
      }

      AnalyzeImage = {
        Type     = "Task"
        Resource = aws_lambda_function.analyze_image.arn
        Retry = [{
          ErrorEquals = [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Next = "SaveResults"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "ProcessingFailed"
        }]
      }

      SaveResults = {
        Type     = "Task"
        Resource = aws_lambda_function.save_results.arn
        Retry = [{
          ErrorEquals = [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        End = true
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "ProcessingFailed"
        }]
      }

      ProcessingFailed = {
        Type  = "Fail"
        Error = "ImageProcessingFailed"
        Cause = "Image processing failed after the configured error handling"
      }
    }
  })

  tags = {
    Project = var.project_name
  }
}
