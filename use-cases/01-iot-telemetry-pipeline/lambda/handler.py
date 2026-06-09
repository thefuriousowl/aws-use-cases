"""
Lambda handler for IoT telemetry pipeline.
Receives messages from IoT Rule and writes to Timestream.
"""

import json
import os
import time

import boto3

# Initialize Timestream client
timestream = boto3.client("timestream-write")

# Read config from environment variables (set by Terraform)
DATABASE_NAME = os.environ["TIMESTREAM_DATABASE"]
TABLE_NAME = os.environ["TIMESTREAM_TABLE"]


def lambda_handler(event, context):
    """
    Process IoT message and write to Timestream.
    
    Event format from IoT Rule:
    {
        "temperature": 25.3,
        "humidity": 60,
        "device_id": "sensor-001"  # Added by IoT Rule SQL: topic(2)
    }
    """
    print(f"Received event: {json.dumps(event)}")
    
    # Extract device_id (added by IoT Rule SQL)
    device_id = event.get("device_id", "unknown")
    
    # Current time in milliseconds
    current_time = str(int(time.time() * 1000))
    
    # Build Timestream records
    # Dimensions = metadata for grouping (device_id)
    # Measures = actual values (temperature, humidity)
    dimensions = [
        {"Name": "device_id", "Value": device_id}
    ]
    
    records = []
    
    # Add temperature if present
    if "temperature" in event:
        records.append({
            "Dimensions": dimensions,
            "MeasureName": "temperature",
            "MeasureValue": str(event["temperature"]),
            "MeasureValueType": "DOUBLE",
            "Time": current_time,
            "TimeUnit": "MILLISECONDS"
        })
    
    # Add humidity if present
    if "humidity" in event:
        records.append({
            "Dimensions": dimensions,
            "MeasureName": "humidity",
            "MeasureValue": str(event["humidity"]),
            "MeasureValueType": "DOUBLE",
            "Time": current_time,
            "TimeUnit": "MILLISECONDS"
        })
    
    if not records:
        print("No valid measures found in event")
        return {"statusCode": 400, "body": "No valid measures"}
    
    # Write to Timestream
    try:
        response = timestream.write_records(
            DatabaseName=DATABASE_NAME,
            TableName=TABLE_NAME,
            Records=records
        )
        print(f"WriteRecords response: {response}")
        return {"statusCode": 200, "body": f"Wrote {len(records)} records"}
    except Exception as e:
        print(f"Error writing to Timestream: {e}")
        raise
