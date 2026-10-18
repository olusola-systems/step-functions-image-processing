import os
from datetime import datetime, timezone
from decimal import Decimal

import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def convert_floats_to_decimal(value):
    """Convert floats to Decimal for DynamoDB compatibility."""
    if isinstance(value, float):
        return Decimal(str(value))

    if isinstance(value, dict):
        return {
            key: convert_floats_to_decimal(item)
            for key, item in value.items()
        }

    if isinstance(value, list):
        return [convert_floats_to_decimal(item) for item in value]

    return value


def lambda_handler(event, context):
    labels = convert_floats_to_decimal(event.get("labels", []))

    item = {
        "imageId": event["imageId"],
        "bucket": event["bucket"],
        "objectKey": event["objectKey"],
        "analyzedAt": datetime.now(timezone.utc).isoformat(),
        "labels": labels,
        "status": "COMPLETED",
    }

    table.put_item(Item=item)

    print(f"Saved analysis results for: {item['imageId']}")

    return {
        "imageId": item["imageId"],
        "bucket": item["bucket"],
        "objectKey": item["objectKey"],
        "analyzedAt": item["analyzedAt"],
        "labelCount": len(labels),
        "status": "COMPLETED",
    }
