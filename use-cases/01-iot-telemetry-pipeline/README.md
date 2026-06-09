# UC01 — IoT Telemetry Pipeline

> Ingest time-series sensor data via MQTT and store it for time-range queries.

**Services:** IoT Core · IoT Rules · Lambda · Timestream
**Pattern:** Time-series ingestion

> **Status: BLOCKED** — AWS Timestream for LiveAnalytics requires account enablement.
> New accounts cannot create Timestream databases without contacting AWS support.
> Terraform code is complete and validated; deployment blocked by service restriction.
> See UC02 for a working alternative using DynamoDB.

---

## 1. Problem

IoT devices generate continuous streams of telemetry data — temperature, pressure, vibration readings — at high frequency. This data must be ingested reliably and stored in a format optimized for time-based queries ("average temperature last hour", "max pressure today").

Using REST APIs for this volume creates connection overhead and risks data loss during traffic spikes. A traditional relational database struggles with time-range queries at scale and lacks automatic data tiering for cost control.


## 2. Why This Pattern

**IoT Core over self-managed MQTT (EMQX, Mosquitto):**
- Fully managed — no broker clusters to provision, patch, or scale
- Built-in device authentication (X.509 certificates) and authorization
- Rules Engine routes messages to AWS services without custom code
- Trade-off: less control than self-hosted, pay-per-message pricing

**Timestream over DynamoDB/RDS:**
- Purpose-built for time-series: optimized for time-range queries and aggregations (AVG, MAX, MIN over time windows)
- Automatic data tiering: recent data in fast memory store, old data moves to cheaper magnetic store
- Built-in time-series functions (interpolation, smoothing)
- Trade-off: not suitable for relational queries or key-value lookups

**Lambda for transformation:**
- IoT Rule could write directly to Timestream, but Lambda allows schema transformation, validation, and enrichment
- Trade-off: adds latency (~100ms cold start) and another failure point
- Alternative: skip Lambda if your message format matches Timestream schema exactly


## 3. How It Works

![Architecture Diagram](./diagrams/architecture.png)

**Data flow:**

1. **IoT Device** publishes an MQTT message to IoT Core
   - Topic: `sensors/{device_id}/telemetry`
   - Payload: `{"temperature": 25.3, "humidity": 60, "device_id": "sensor-001"}`

2. **IoT Core** receives the message and evaluates it against the **IoT Rule**
   - Rule SQL: `SELECT * FROM 'sensors/+/telemetry'`
   - The `+` wildcard matches any device ID

3. **IoT Rule** triggers the **Lambda function** with the message payload

4. **Lambda** transforms the data into Timestream format:
   - Dimensions: `device_id` (metadata for grouping)
   - Measures: `temperature`, `humidity` (the actual values)
   - Timestamp: current time or from payload

5. **Lambda** writes the record to **Timestream**

6. **User/Dashboard** queries Timestream:
   ```sql
   SELECT AVG(temperature) 
   FROM "iot_db"."telemetry" 
   WHERE time > ago(1h)
   GROUP BY device_id


## 4. Trade-offs

| Trade-off | Implication |
|-----------|-------------|
| **Lambda cold starts** | Adds ~100-500ms latency on first invocation after idle. Not suitable if you need guaranteed sub-100ms end-to-end. |
| **No message buffering** | If Lambda or Timestream is down, messages are lost. For durability, add SQS between IoT Rule and Lambda (see UC02). |
| **Timestream query cost** | Queries are billed by data scanned. Frequent dashboard refreshes on large datasets can get expensive. |
| **Single region** | This setup doesn't replicate across regions. For DR, you'd need multi-region IoT Core endpoints and Timestream replication. |
| **IoT Core pricing** | ~$1 per million messages. Cheap at low volume, but scales linearly — 100M messages/month = $100. |

**When NOT to use this pattern:**
- You need guaranteed delivery → add SQS (UC02)
- You need sub-50ms alerting → skip Lambda, use IoT Rule direct action to SNS (UC04)
- You need complex joins across data sources → use a relational DB instead

---

## 5. Cost

**Key cost drivers:**

| Service | Pricing model | Estimate |
|---------|---------------|----------|
| IoT Core | ~$1 per 1M messages | Free tier: 250K messages/month (12 months) |
| Lambda | $0.20 per 1M invocations + duration | Free tier: 1M requests/month |
| Timestream | Writes: $0.50/1M records, Storage: $0.03/GB (magnetic) | No free tier |

**Rough estimate at 10,000 messages/day:**
- IoT Core: ~$0.30/month (within free tier first year)
- Lambda: ~$0 (well within free tier)
- Timestream: ~$0.15/month writes + storage
- **Total: < $1/month** if destroyed promptly

**Watch out for:**
- Timestream has no free tier — even idle databases incur storage costs
- Queries are billed by data scanned — avoid `SELECT *` on large time ranges

**Teardown:**
```bash
terraform destroy
```

## 6. Deploy & Test


```bash
cd terraform/
terraform init
terraform plan
terraform apply
```
**Test steps:**

**Publish a test message using AWS CLI:**

```bash
aws iot-data publish \
  --topic "sensors/test-device/telemetry" \
  --payload '{"temperature": 25.3, "humidity": 60}' \
  --region eu-west-1
```

**Query Timestream to verify:**


```bash
aws timestream-query query \
  --query-string "SELECT * FROM \"iot_db\".\"telemetry\" ORDER BY time DESC LIMIT 5" \
  --region eu-west-1
```

**Destroy:**

```bash
terraform destroy
```