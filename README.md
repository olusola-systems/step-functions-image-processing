# Week 33 — Event-Driven Image Intelligence Pipeline with AWS Step Functions

## Project Overview

This project builds an event-driven, serverless image intelligence pipeline using AWS Step Functions to orchestrate a multi-stage workflow across AWS Lambda and Amazon Rekognition.

When an image is uploaded to Amazon S3, an Amazon EventBridge rule detects the ObjectCreated event and starts a Step Functions state machine. The state machine coordinates three Lambda functions — one to validate the uploaded image, one to analyze it with Amazon Rekognition, and one to store the results in Amazon DynamoDB.

The pipeline is fully serverless, provisioned with Terraform, and monitored through Amazon CloudWatch Logs and AWS Step Functions execution history.

---

## Architecture

![Week 33 Architecture](assets/architecture.png)

### Request Flow

```text
Image Upload
     │
     ▼
Amazon S3
(Image Bucket)
     │
ObjectCreated Event
     │
     ▼
Amazon EventBridge
(Event Rule)
     │
     ▼
AWS Step Functions
(State Machine)
     │
     ├──► Lambda: ValidateImage
     │
     ├──► Lambda: AnalyzeImage
     │         │
     │         ▼
     │    Amazon Rekognition
     │    DetectLabels
     │
     └──► Lambda: StoreResults
               │
               ▼
          Amazon DynamoDB
          (Image Intelligence)
               │
               ▼
          Amazon CloudWatch
          (Execution Logs)
```

---

## AWS Services and Technologies

- **Amazon S3** — Receives image uploads and generates ObjectCreated events
- **Amazon EventBridge** — Detects S3 events and triggers the Step Functions state machine
- **AWS Step Functions** — Orchestrates the multi-stage image processing workflow
- **AWS Lambda** — Executes validation, analysis, and result storage stages
- **Amazon Rekognition** — Analyzes image content and returns labels with confidence scores
- **Amazon DynamoDB** — Stores image analysis results with processing status
- **Amazon CloudWatch Logs** — Captures Lambda execution logs
- **AWS IAM** — Controls permissions for each service and Lambda function
- **Terraform** — Provisions and manages all infrastructure as code
- **Python 3.12** — Implements all Lambda function logic

---

## Step Functions State Machine

The state machine coordinates three sequential Lambda functions.

```json
{
  "Comment": "Image Intelligence Pipeline",
  "StartAt": "ValidateImage",
  "States": {
    "ValidateImage": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:REGION:ACCOUNT:function:validate-image",
      "Next": "AnalyzeImage",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "HandleError"
        }
      ]
    },
    "AnalyzeImage": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:REGION:ACCOUNT:function:analyze-image",
      "Next": "StoreResults",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "HandleError"
        }
      ]
    },
    "StoreResults": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:REGION:ACCOUNT:function:store-results",
      "End": true,
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "HandleError"
        }
      ]
    },
    "HandleError": {
      "Type": "Fail",
      "Error": "PipelineError",
      "Cause": "An error occurred during image processing"
    }
  }
}
```

---

## Lambda Functions

**ValidateImage**

Validates that the S3 event contains a valid object key and that the uploaded file is a supported image type. Passes the bucket name and object key to the next stage.

**AnalyzeImage**

Retrieves the image from S3 and sends it to Amazon Rekognition DetectLabels. Configured for a maximum of 10 labels at a minimum confidence threshold of 80%. Passes the detected labels to the next stage.

**StoreResults**

Receives the image metadata and Rekognition labels, converts floating-point confidence scores to Decimal values for DynamoDB compatibility, and writes the complete analysis record with a COMPLETED status to DynamoDB.

---

## Infrastructure as Code

Terraform provisions and manages all infrastructure including:

- S3 bucket with EventBridge notifications enabled
- EventBridge rule targeting the Step Functions state machine
- Step Functions state machine with the orchestration definition
- Three Lambda functions with individual IAM execution roles
- DynamoDB table for image intelligence results
- IAM roles and policies for EventBridge, Step Functions, Lambda, and Rekognition
- CloudWatch log groups for Lambda execution logging

---

## Deployment

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

---

## Testing and Validation

**Step 1 — Upload a test image**

```bash
aws s3 cp test-car.jpg s3://<your-bucket-name>/
```

**Step 2 — Verify Step Functions execution**

Navigate to AWS Step Functions → State Machines → Select the pipeline → Executions → Review the execution status and individual step results.

**Step 3 — Verify DynamoDB results**

Navigate to DynamoDB → Tables → Image Intelligence table → Explore Table Items → Confirm the analysis record exists with a COMPLETED status and populated labels.

**Step 4 — Review CloudWatch Logs**

Navigate to CloudWatch → Log Groups → Review logs for each Lambda function to confirm execution details.

---

## Challenges and Troubleshooting

**DynamoDB Decimal Serialization Error**

Problem: The StoreResults Lambda failed when writing Rekognition confidence scores to DynamoDB.

Cause: Amazon Rekognition returns confidence scores as Python floating-point numbers. Boto3's DynamoDB serializer does not support Python float values directly.

Resolution: Updated the StoreResults Lambda to recursively convert all floating-point values to Python Decimal objects before writing to DynamoDB. Redeployed the function with Terraform and confirmed successful execution.

---

**Identifying the Failing Lambda Through Execution History**

Problem: The Step Functions execution showed a failure but the generic error message did not identify which stage had failed or why.

Cause: The error occurred inside one of the three Lambda functions but the top-level execution view did not surface the underlying exception.

Resolution: Used the Step Functions execution history to trace the workflow step by step. Identified that the StoreResults stage had failed, retrieved the underlying exception from the execution event details, and confirmed it was the DynamoDB serialization error. This reinforced the value of using Step Functions execution history as the primary debugging tool for multi-stage workflows.

---

**IAM Permissions for Step Functions and EventBridge**

Problem: The initial deployment failed because Step Functions could not invoke the Lambda functions and EventBridge could not start the state machine.

Cause: The IAM roles for EventBridge and Step Functions were missing the permissions required to invoke their downstream resources.

Resolution: Added the required IAM policies — `lambda:InvokeFunction` for the Step Functions execution role and `states:StartExecution` for the EventBridge rule role. Redeployed with Terraform and confirmed the workflow executed successfully end to end.

---

## Lessons Learned

This project strengthened my understanding of event-driven architecture and how AWS services can work together to create a serverless image processing pipeline. Using Amazon S3 to receive image uploads, Amazon EventBridge to detect ObjectCreated events, and AWS Step Functions to orchestrate the processing workflow made each responsibility clear and independently manageable. Separating validation, image analysis, and result storage into individual Lambda functions made each stage easier to understand, test, and troubleshoot.

One of the main challenges was a DynamoDB serialization error caused by the floating-point confidence scores returned by Amazon Rekognition. Boto3's DynamoDB serializer does not support Python floating-point values directly, so I updated the StoreResults Lambda to recursively convert those values to Python Decimal objects before writing them to DynamoDB. After redeploying with Terraform, the workflow completed successfully and the image analysis results were stored with a COMPLETED status.

I also learned the importance of investigating workflow failures through AWS Step Functions execution history rather than relying on a generic failure message. By tracing the execution through each stage, I identified the specific Lambda function that failed and retrieved the underlying exception directly from the execution event details. This reinforced the value of detailed logging, structured error handling, and testing the complete integration between services rather than validating each component in isolation.

Finally, this project reinforced the benefits of managing cloud infrastructure with Terraform. I was able to update and redeploy the affected Lambda function and IAM policies without recreating the entire environment. Combining infrastructure as code with event-driven processing, orchestrated workflows, and persistent storage gave me practical experience building and troubleshooting a multi-service AWS workflow that reflects real production patterns.

---

## Security Considerations

- Each Lambda function has its own IAM execution role scoped to the permissions it requires
- Rekognition access is limited to the AnalyzeImage Lambda only
- DynamoDB write access is limited to the StoreResults Lambda only
- S3 read access is scoped to the image bucket
- No public API endpoints are exposed in this project

---

## Outcome

Successfully built and deployed an event-driven, serverless image intelligence pipeline orchestrated by AWS Step Functions. Uploaded images automatically trigger a multi-stage workflow that validates the image, analyzes it with Amazon Rekognition, and stores the labeled results in DynamoDB. The pipeline is fully managed with Terraform and observable through Step Functions execution history and CloudWatch Logs.

---

## Next Project

Week 34 — AWS Security Event Monitoring and Alerting

Week 34 shifts from serverless image processing into cloud security operations. The project will build an automated alerting system that detects selected IAM changes — such as creating or deleting an IAM user — and sends an email notification through Amazon SNS.

The architecture follows the AWS-documented CloudTrail → EventBridge → SNS pattern for monitoring IAM activity, building on the EventBridge and Terraform experience from Week 33 while introducing a practical cloud security and operations use case.
