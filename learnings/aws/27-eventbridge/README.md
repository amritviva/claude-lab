# EventBridge — Event Bus / News Wire Service

> **EventBridge is the country's news wire service. Events are news stories, event buses are news channels, rules are filters ("only show me sports news"), and targets are subscribers who act on the news.**

---

## ELI10

Imagine a news wire service that every government department (AWS service), company (SaaS partner), and citizen (your apps) can publish news to. The service has different channels — a default channel for government news, custom channels for your organization, and partner channels for companies like Zendesk or Shopify. You set up filters: "When the weather department reports a storm in Sydney, text me and activate the emergency shelter." The news wire routes matching stories to the right subscribers automatically. You can even archive all stories and replay them later to see what happened.

---

## The Concept

### EventBridge Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        EVENTBRIDGE                                │
│                                                                    │
│  SOURCES                  EVENT BUSES            TARGETS           │
│  (Publishers)             (Channels)             (Subscribers)     │
│                                                                    │
│  ┌──────────┐            ┌──────────┐           ┌──────────┐     │
│  │ AWS      │──┐         │ Default  │──Rules──>│ Lambda   │     │
│  │ Services │  │         │ Bus      │          │          │     │
│  └──────────┘  │         └──────────┘           └──────────┘     │
│                │                                                   │
│  ┌──────────┐  ├────────>┌──────────┐           ┌──────────┐     │
│  │ Custom   │──┤         │ Custom   │──Rules──>│ SQS      │     │
│  │ Apps     │  │         │ Bus      │          │          │     │
│  └──────────┘  │         └──────────┘           └──────────┘     │
│                │                                                   │
│  ┌──────────┐  │         ┌──────────┐           ┌──────────┐     │
│  │ SaaS     │──┘         │ Partner  │──Rules──>│ Step     │     │
│  │ Partners │            │ Bus      │          │ Functions│     │
│  └──────────┘            └──────────┘           └──────────┘     │
│                                                                    │
└──────────────────────────────────────────────────────────────────┘
```

### Core Components

| Component | Analogy | Detail |
|-----------|---------|--------|
| **Event** | News story | JSON object with source, detail-type, detail, time, etc. |
| **Event Bus** | News channel | Default (AWS events), Custom (your events), Partner (SaaS) |
| **Rule** | News filter | Pattern that matches events, routes to targets |
| **Target** | Subscriber | AWS service that receives matching events (up to 5 per rule) |
| **Schema Registry** | News format catalog | Stores event schemas for discovery and code generation |
| **Scheduler** | Cron job service | Time-based event generation (replaces CW Events cron) |
| **Archive** | News archive | Store events for replay |
| **Pipes** | Direct wire | Point-to-point: source → filter → enrich → target |

### Event Structure

```json
{
  "version": "0",
  "id": "a1b2c3d4-5678-90ab-cdef-1234567890ab",
  "source": "custom.orders",
  "detail-type": "Order Placed",
  "account": "123456789012",
  "time": "2026-03-11T10:30:00Z",
  "region": "ap-southeast-2",
  "resources": [],
  "detail": {
    "orderId": "ORD-001",
    "customerId": "CUST-123",
    "total": 149.99,
    "status": "NEW"
  }
}
```

### Event Pattern Matching — The Filter Rules

```json
// Match EC2 instance state changes to "stopped"
{
  "source": ["aws.ec2"],
  "detail-type": ["EC2 Instance State-change Notification"],
  "detail": {
    "state": ["stopped"]
  }
}

// Match orders over $100 from Sydney
{
  "source": ["custom.orders"],
  "detail-type": ["Order Placed"],
  "detail": {
    "total": [{ "numeric": [">", 100] }],
    "city": ["Sydney"]
  }
}

// Content-based filtering operators:
// "prefix": "2026"          ← starts with
// "suffix": ".png"          ← ends with
// "anything-but": "test"    ← NOT this value
// "numeric": [">", 100]     ← numeric comparison
// "exists": true/false      ← field exists or doesn't
// "cidr": "10.0.0.0/8"     ← IP range matching
```

### EventBridge Scheduler

```
┌────────────────────────────────────────────────────────┐
│              EVENTBRIDGE SCHEDULER                       │
│        (Replaces CloudWatch Events cron)                 │
│                                                          │
│  One-time schedule:                                      │
│  "Run this Lambda at 2026-03-15 09:00 UTC"               │
│                                                          │
│  Rate-based:                                             │
│  "Run every 5 minutes"  → rate(5 minutes)                │
│                                                          │
│  Cron-based:                                             │
│  "Run at 9am every weekday"                              │
│  → cron(0 9 ? * MON-FRI *)                               │
│                                                          │
│  Features over CloudWatch Events:                        │
│  • Time zone support (no UTC-only limitation)            │
│  • One-time schedules                                    │
│  • Flexible time windows                                 │
│  • Up to 1 million schedules per account                 │
│  • Dead-letter queue for failed invocations              │
│  • Universal target (any AWS service)                    │
└────────────────────────────────────────────────────────┘
```

### Archive & Replay

```
┌──────────┐      ┌──────────┐      ┌──────────┐
│ Events   │─────>│ Archive  │─────>│ Replay   │
│ (live)   │      │ (stored) │      │ (re-emit)│
│          │      │          │      │          │
│          │      │ Filter:  │      │ Select:  │
│          │      │ By event │      │ Time     │
│          │      │ pattern  │      │ range    │
│          │      │          │      │          │
│          │      │ Retention│      │ Replayed │
│          │      │ Indefinite│     │ events go│
│          │      │ or X days│      │ to same  │
│          │      │          │      │ bus      │
└──────────┘      └──────────┘      └──────────┘

Use cases:
• Replay events after fixing a bug in a consumer
• Test new rules against historical events
• Disaster recovery — replay events in a new region
```

### EventBridge Pipes — Point-to-Point

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Source   │───>│  Filter  │───>│  Enrich  │───>│  Target  │
│          │    │(optional)│    │(optional)│    │          │
│ SQS      │    │ Event    │    │ Lambda   │    │ Step     │
│ Kinesis  │    │ pattern  │    │ API GW   │    │ Functions│
│ DynamoDB │    │ matching │    │ Step Fn  │    │ Lambda   │
│ Streams  │    │          │    │          │    │ SQS/SNS  │
│ Kafka    │    │          │    │          │    │ Kinesis  │
│ MQ       │    │          │    │          │    │ etc.     │
└──────────┘    └──────────┘    └──────────┘    └──────────┘

Pipes vs Rules:
• Pipes = point-to-point (1 source → 1 target), with optional filtering + enrichment
• Rules = event pattern matching → up to 5 targets (fan-out)
• Pipes are for integration flows: "when DynamoDB changes, enrich with Lambda, send to SQS"
```

### EventBridge vs SNS

```
┌───────────────────────────┬──────────────────────────┐
│       EventBridge          │          SNS              │
├───────────────────────────┼──────────────────────────┤
│ Content-based filtering    │ Topic/attribute filter    │
│ Schema discovery           │ No schema support         │
│ Archive & replay           │ No archive                │
│ SaaS integrations          │ AWS services only         │
│ Scheduler built-in         │ No scheduler              │
│ Up to 5 targets per rule   │ Unlimited subscribers     │
│ JSON event matching        │ Message attributes        │
│                             │                           │
│ Use for:                    │ Use for:                  │
│ • Complex event routing     │ • Simple fan-out          │
│ • Cross-account events      │ • Mobile push (APNs, GCM)│
│ • SaaS integrations         │ • SMS notifications       │
│ • Scheduled tasks           │ • Email notifications     │
│ • Event-driven architecture │ • High-throughput pub/sub │
└───────────────────────────┴──────────────────────────┘
```

### Cross-Account & Cross-Region Events

```
Account A (us-east-1)          Account B (ap-southeast-2)
┌────────────────────┐         ┌────────────────────┐
│ Custom Event Bus   │         │ Custom Event Bus   │
│                     │  Rule   │                     │
│ Rule: forward to ──│────────>│ Rule: process      │
│ Account B's bus    │         │ locally             │
└────────────────────┘         └────────────────────┘

• Cross-account: target another account's event bus
• Cross-region: target event bus in another region
• Requires: resource policy on target bus allowing source account
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- **EventBridge vs SNS** — when to use structured routing vs simple fanout
- **Event-driven architecture** — decouple services with events
- **Cross-account/cross-region** events for multi-account setups
- **Scheduler** — replacing CloudWatch Events cron
- **Archive & Replay** — disaster recovery and debugging

### DVA-C02 (Developer)
- **Event pattern matching syntax** — content filtering, numeric comparisons, prefix/suffix
- **PutEvents API** — send custom events (max 10 entries per call)
- **Schema Registry** — discover event schemas, generate code bindings
- **Input transformers** — modify event before sending to target
- **Pipes** — source → filter → enrich → target pattern

### SOA-C02 (SysOps)
- **Monitoring** — FailedInvocations, ThrottledRules, InvocationsCreated
- **DLQ for rules** — failed target invocations go to SQS DLQ
- **Resource policies** — cross-account event bus access
- **Scheduler** — managing schedules at scale, flexible time windows
- **Troubleshooting** — events not matching rules (check pattern syntax)

---

## Key Numbers

| Fact | Value |
|------|-------|
| Targets per rule | Up to 5 |
| PutEvents entries per call | Up to 10 |
| Event size max | 256 KB |
| Rules per event bus | 300 (soft limit) |
| Event buses per account | 100 |
| Scheduler schedules per account | 1,000,000 |
| Scheduler max rate | 1 invocation/second per schedule |
| Archive retention | Indefinite or N days |
| Retry policy | Up to 185 retries over 24 hours |
| Invocation timeout | 24 hours (for async targets) |

---

## Cheat Sheet

- **EventBridge = serverless event bus.** Routes events from AWS, custom apps, SaaS to targets.
- **Default bus** = AWS service events (EC2, S3, etc.). **Custom bus** = your app events. **Partner bus** = SaaS.
- **Rules** = pattern matching filters. Up to 5 targets per rule.
- **Pattern matching** supports: exact, prefix, suffix, numeric, exists, anything-but, CIDR.
- **Scheduler** replaces CloudWatch Events cron. Supports time zones, one-time schedules, 1M schedules.
- **Archive & Replay** = store events, replay time ranges for debugging or DR.
- **Pipes** = point-to-point integration: source → filter → enrich → target.
- **EventBridge vs SNS:** EventBridge for structured routing + schema + archive. SNS for simple fan-out + SMS/email.
- **Cross-account:** send events to another account's bus (needs resource policy on target).
- **Max event size = 256 KB.** Same as Step Functions input/output limit.
- **PutEvents** = API to send custom events. Max 10 entries per call.
- **Input transformers** = modify/reshape event data before sending to target.
- **Schema Registry** = auto-discovers event schemas from your bus. Generates code bindings.
- **Retry policy** = EventBridge retries failed deliveries for up to 24 hours (185 attempts).
- **DLQ** = attach SQS DLQ to rules for undeliverable events.
