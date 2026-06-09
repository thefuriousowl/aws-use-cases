"""
Lambda handler for UC02 - Decoupled Edge Ingestion.
Receives messages from SQS and writes to DynamoDB.
"""

import json
import os
from datetime import datetime, timezone
from decimal import Decimal

import boto3

dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ["DYNAMODB_TABLE"]
table = dynamodb.Table(TABLE_NAME)


def lambda_handler(event, context):
    """
    Process SQS messages and write to DynamoDB.
    
    SQS delivers messages in batches (up to 10).
    Each record contains the original IoT message in 'body'.
    """
    print(f"Received {len(event['Records'])} messages")
    
    for record in event["Records"]:
        # Parse the message body (IoT Rule JSON)
        body = json.loads(record["body"])
        print(f"Processing: {body}")
        
        device_id = body.get("device_id", "unknown")
        
        # Use ISO timestamp for sort key (enables time-based queries)
        timestamp = datetime.now(timezone.utc).isoformat()
        
        # Write to DynamoDB
        # Using device_id + timestamp as composite key = idempotent
        # (same message twice = overwrites, not duplicates)
        # Convert floats to Decimal (DynamoDB doesn't accept Python floats)
        temp = body.get("temperature")
        humid = body.get("humidity")

        item = {
            "device_id": device_id,
            "timestamp": timestamp,
            "temperature": Decimal(str(temp)) if temp is not None else None,
            "humidity": Decimal(str(humid)) if humid is not None else None,
            "raw_message": json.loads(json.dumps(body), parse_float=Decimal),
        }
        
        # Remove None values
        item = {k: v for k, v in item.items() if v is not None}
        
        table.put_item(Item=item)
        print(f"Wrote item: device_id={device_id}, timestamp={timestamp}")
    
    return {"statusCode": 200, "body": f"Processed {len(event['Records'])} messages"}
