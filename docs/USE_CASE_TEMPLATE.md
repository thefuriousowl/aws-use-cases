# UC[NN] — [Use Case Name]

> One-sentence summary: what this pattern does and when you'd reach for it.

**Services:** [List of AWS services used]  
**Pattern:** [e.g., "time-series ingestion", "async load levelling", "saga orchestration"]

---

## 1. Problem

_What business or technical problem does this solve?_

- State the requirement in plain terms (e.g., "Ingest 10,000 sensor readings/sec without data loss")
- Who has this problem? What breaks if you don't solve it?
- Keep it to 2-4 sentences — this is the "why we're here"

---

## 2. Why This Pattern

_Why these services and not alternatives?_

- Explain the key service choices and what they give you
- Compare to at least one alternative you *didn't* pick and why
- Example: "SQS over Kinesis because we need per-message delivery guarantees, not ordered streams"

---

## 3. How It Works

_Walk through the request/data flow step by step._

![Architecture Diagram](./diagrams/architecture.svg)

1. [First step — e.g., "Device publishes MQTT message to IoT Core"]
2. [Second step — e.g., "IoT Rule evaluates SQL and routes to Lambda"]
3. [Continue until data reaches its destination]

Include: protocols, triggers, what each component does, where state lives.

---

## 4. Trade-offs

_What do you give up? When would you NOT use this?_

| Trade-off | Implication |
|-----------|-------------|
| [e.g., "No ordering guarantee"] | [e.g., "Don't use if event sequence matters"] |
| [e.g., "Cold start latency"] | [e.g., "Not suitable for sub-100ms alerting"] |

Be honest. Every pattern has limits — showing you know them is the senior signal.

---

## 5. Cost

_What does it cost and what drives the bill?_

**Key cost drivers:**
- [e.g., "Lambda: invocations + duration (first 1M free)"]
- [e.g., "Timestream: writes + storage + queries"]

**Rough estimate:** $X/month at Y scale (state your assumptions)

**Teardown:** Always run `terraform destroy` when done. Watch for: [resources that bill while idle]

---

## Deploy & Test

```bash
cd terraform/
terraform init
terraform plan
terraform apply
