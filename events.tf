resource "aws_iam_role" "eventbridge_start_workflow" {
  name = "${var.project_name}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy" "eventbridge_start_workflow" {
  name = "${var.project_name}-start-workflow-policy"
  role = aws_iam_role.eventbridge_start_workflow.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["states:StartExecution"]
        Resource = aws_sfn_state_machine.image_processing.arn
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "image_uploaded" {
  name        = "${var.project_name}-image-uploaded"
  description = "Start image processing when an object is created in the S3 image bucket"

  event_pattern = jsonencode({
    source        = ["aws.s3"]
    "detail-type" = ["Object Created"]

    detail = {
      bucket = {
        name = [aws_s3_bucket.images.bucket]
      }
    }
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_cloudwatch_event_target" "start_workflow" {
  rule      = aws_cloudwatch_event_rule.image_uploaded.name
  target_id = "StartImageProcessingWorkflow"
  arn       = aws_sfn_state_machine.image_processing.arn
  role_arn  = aws_iam_role.eventbridge_start_workflow.arn

  input_transformer {
    input_paths = {
      bucket    = "$.detail.bucket.name"
      objectKey = "$.detail.object.key"
    }

    input_template = "{\"bucket\": <bucket>, \"objectKey\": <objectKey>, \"imageId\": <objectKey>}"
  }
}

resource "aws_s3_bucket_notification" "images" {
  bucket      = aws_s3_bucket.images.id
  eventbridge = true
}
