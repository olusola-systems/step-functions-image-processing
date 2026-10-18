def lambda_handler(event, context):
    print("Received image validation event")

    bucket = event.get("bucket")
    object_key = event.get("objectKey")

    if not bucket or not object_key:
        raise ValueError("Both bucket and objectKey are required")

    if not object_key.lower().endswith((".jpg", ".jpeg", ".png")):
        raise ValueError("Unsupported image format")

    return {
        "bucket": bucket,
        "objectKey": object_key,
        "imageId": event.get("imageId", object_key),
        "status": "VALIDATED"
    }
