# Cost Tracking

Log every deployment here. **No row should be left without "Destroyed? = Yes" by end of session.**

| Date | Use Case | Key Billable Resources | Est. Cost | Destroyed? |
|------|----------|------------------------|-----------|------------|
| 2026-06-09 | UC02 — Decoupled Edge Ingestion | IoT Core, SQS (2 queues), Lambda, DynamoDB | $0 (Free Tier) | Yes |

---

## AWS Free Tier notes

Many services in this repo fit within the AWS Free Tier (12 months from account creation):

| Service | Free Tier Allowance |
|---------|---------------------|
| Lambda | 1M requests/month, 400,000 GB-seconds |
| DynamoDB | 25 GB storage, 25 WCU/RCU |
| S3 | 5 GB storage, 20,000 GET, 2,000 PUT |
| SQS | 1M requests/month |
| SNS | 1M publishes, 1,000 emails |
| IoT Core | 250,000 messages/month (first 12 months) |
| API Gateway | 1M REST API calls/month (first 12 months) |

**Watch out for:** NAT Gateway (~$32/month), RDS (~$12+/month), Kinesis (~$10+/month), ECS Fargate (per vCPU-hour). These bill while idle — always destroy promptly.
