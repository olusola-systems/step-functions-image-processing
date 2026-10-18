import boto3


rekognition = boto3.client("rekognition")


def lambda_handler(event, context):
    bucket = event["bucket"]
    object_key = event["objectKey"]

    print(f"Analyzing image: {object_key}")

    result = rekognition.detect_labels(
        Image={
            "S3Object": {
                "Bucket": bucket,
                "Name": object_key
            }
        },
        MaxLabels=10,
        MinConfidence=80
    )

    labels = [
        {
            "Name": label["Name"],
            "Confidence": round(label["Confidence"], 2)
        }
        for label in result.get("Labels", [])
    ]

    return {
        "bucket": bucket,
        "objectKey": object_key,
        "imageId": event.get("imageId", object_key),
        "labels": labels,
        "status": "ANALYZED"
    }
