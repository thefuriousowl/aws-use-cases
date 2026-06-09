# AWS Use Cases — Architecture Patterns by Example

> A hands-on catalogue of AWS architecture patterns, each deployable with a single `terraform apply`.
> Built to demonstrate not just *that* a pattern works, but *why* it's chosen, *what* it trades off, and *what* it costs.

**Author:** Unnop Paripunnang — AWS Certified Solutions Architect (SAA-C03), CKA
**Background:** 3 years building production Industrial IoT platforms on Kubernetes. These use cases re-frame that real-world experience — telemetry ingestion, decoupling, safety-critical alerting, high availability — in AWS-native terms.

---

## How to read this repo

Every use case follows the same structure so you can compare patterns quickly:

```
NN-use-case-name/
├── README.md          # Problem → Solution → Architecture → Trade-offs → Cost
├── diagrams/          # Architecture diagram (rendered + source)
├── terraform/         # Deployable IaC — main.tf, variables.tf, outputs.tf, versions.tf
└── lambda/            # Application code where relevant
```

Each README answers five questions a Solutions Architect must always answer:

1. **What problem does this solve?** — the business / technical driver
2. **Why this pattern?** — why these services, not alternatives
3. **How does it work?** — request/data flow, component by component
4. **What are the trade-offs?** — what you give up, when *not* to use it
5. **What does it cost?** — rough monthly cost + how to tear it down

---

## Use case catalogue

### Tier 1 — IoT & Real-Time Data (domain specialty)

| # | Use case | Services | Pattern |
|---|----------|----------|---------|
| 01 | [IoT Telemetry Pipeline](./use-cases/01-iot-telemetry-pipeline) | IoT Core · Rules Engine · Lambda · Timestream · Grafana | Time-series ingestion |
| 02 | Decoupled Edge Ingestion | IoT Core · SQS · Lambda · DynamoDB | Buffering & decoupling |
| 03 | Real-Time Sensor Analytics | Kinesis · Lambda · S3 · Athena | Streaming + ad-hoc query |
| 04 | Safety-Critical Alerting | CloudWatch · SNS · Lambda | Threshold alerting |

### Tier 2 — Decoupling & Event-Driven

| # | Use case | Services | Pattern |
|---|----------|----------|---------|
| 05 | Request Buffering | API Gateway · SQS · Lambda · DynamoDB | Async load levelling |
| 06 | Event-Driven File Processing | S3 · Lambda | Trigger-on-upload |
| 07 | Workflow Orchestration | EventBridge · Step Functions · Lambda | Saga / orchestration |

### Tier 3 — Compute, HA & Networking

| # | Use case | Services | Pattern |
|---|----------|----------|---------|
| 08 | Scalable Web Tier | ALB · EC2 ASG · RDS Multi-AZ | Horizontal scaling + HA |
| 09 | Network Isolation | VPC · Private Subnet · NAT · Bastion | Secure networking |
| 10 | Containerised Microservices | ECS Fargate · ALB | Serverless containers |

### Tier 4 — Resilience & Observability

| # | Use case | Services | Pattern |
|---|----------|----------|---------|
| 11 | Multi-Region DR | Route 53 · S3 CRR · failover routing | Disaster recovery |
| 12 | Distributed Tracing | CloudWatch · X-Ray | Observability |

> Status legend: ✅ complete · 🚧 in progress · 📋 planned
> Currently complete: **0**. The rest follow the same template.

---

## Running any use case

**Prerequisites:** an AWS account, [Terraform](https://www.terraform.io/) `>= 1.5`, and AWS credentials configured (`aws configure`).

```bash
cd use-cases/01-iot-telemetry-pipeline/terraform
terraform init
terraform plan      # review what will be created
terraform apply     # provision
# ... try it out (each README has a test section) ...
terraform destroy   # ALWAYS tear down to avoid charges
```

> ⚠️ **Cost note:** these are learning deployments. Each README states rough cost and what to watch.
> Most fit comfortably in the AWS Free Tier if torn down promptly. Always run `terraform destroy` when done.


---

## Terraform state

This repo uses **remote state** stored in S3 with DynamoDB locking.

| Resource | Value |
|----------|-------|
| S3 bucket | `aws-use-cases-tfstate-596436429175` |
| DynamoDB table | `aws-use-cases-terraform-locks` |
| Region | `eu-west-1` |

Each use case configures its backend in `versions.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "aws-use-cases-tfstate-596436429175"
    key            = "use-cases/<nn-name>/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "aws-use-cases-terraform-locks"
    encrypt        = true
  }
}
```
**Why remote state?**

- State is stored durably in S3, not on a laptop that can crash
- Versioning allows recovery if state is corrupted
- DynamoDB locking prevents concurrent apply operations from corrupting state

---

## A note on the approach

I deliberately avoided copy-pasting reference architectures. Each pattern here maps to a problem
I've actually hit running safety-critical industrial monitoring — where a missed gas-leak alert or a
stalled telemetry pipeline has real-world consequences. The cloud services differ from my production
stack (EMQX, TimescaleDB, k3s, Redis Sentinel), but the *reasoning* — decouple failure domains, buffer
bursty ingestion, alert with sub-second latency, design for independent failure — is identical.

That reasoning is what these READMEs try to make visible.
