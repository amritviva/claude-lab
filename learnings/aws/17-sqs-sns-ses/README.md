# 17 — SQS, SNS & SES: The Country's Messaging Systems

> **One-liner:** SQS is the post office queue (messages wait to be processed), SNS is the PA system (broadcast to many listeners), and SES is the national email service.

---

## ELI10

Imagine three ways to send messages in a country. The **Post Office (SQS)** has a queue — you drop a letter in, and a worker picks it up when they're ready. If the worker is busy, the letter waits safely in the queue. Nobody loses any mail. The **PA System (SNS)** is a loudspeaker — when someone makes an announcement, EVERYONE subscribed to that channel hears it immediately: the police station, the hospital, the fire department, all at once. The **Email Service (SES)** is for formal correspondence — sending newsletters, receipts, and notifications to citizens' inboxes at massive scale.

---

## SQS — Simple Queue Service (The Post Office)

### How It Works

```
Producer                    SQS Queue                     Consumer
(Sender)                  (Post Office)                  (Worker)
   │                          │                              │
   │── SendMessage ──────────→│                              │
   │── SendMessage ──────────→│  Messages wait in queue      │
   │── SendMessage ──────────→│                              │
   │                          │                              │
   │                          │←── ReceiveMessage ───────────│
   │                          │    (Worker picks up message) │
   │                          │                              │
   │                          │←── DeleteMessage ────────────│
   │                          │    (Worker confirms done)    │
```

**Key principle:** The consumer must DELETE the message after processing. If they don't, it becomes visible again for another worker to try.

### Standard vs FIFO Queues

```
┌──────────────────────────────┐  ┌──────────────────────────────┐
│      STANDARD QUEUE          │  │        FIFO QUEUE             │
│      (Regular Mail)          │  │     (Registered Mail)         │
│                              │  │                               │
│  Delivery: At-least-once     │  │  Delivery: Exactly-once       │
│  Order: Best-effort          │  │  Order: Strict FIFO           │
│  (might arrive out of order) │  │  (guaranteed order)           │
│                              │  │                               │
│  Throughput: Nearly unlimited│  │  Throughput: 300 msg/s        │
│  (thousands/second)          │  │  (3,000 with batching)        │
│                              │  │  High-throughput mode: 70K/s  │
│  Duplicates: Possible        │  │  Duplicates: Never            │
│                              │  │                               │
│  Use: High volume, order     │  │  Use: Financial transactions, │
│  doesn't matter              │  │  commands, order processing   │
│                              │  │                               │
│  Name: any-name              │  │  Name: must end in .fifo      │
└──────────────────────────────┘  └──────────────────────────────┘
```

### FIFO Concepts

**Message Group ID:** Partitions messages into groups. Messages within the same group are strictly ordered. Different groups can be processed in parallel.

```
Queue: orders.fifo
  Group "user-123": Order1 → Order2 → Order3  (strict order)
  Group "user-456": OrderA → OrderB → OrderC  (strict order)

user-123's orders won't interfere with user-456's orders.
Processing is parallel BETWEEN groups, sequential WITHIN groups.
```

**Message Deduplication ID:** Prevents duplicate messages within a 5-minute window. Two methods:
1. Provide explicit dedup ID in SendMessage
2. Enable content-based deduplication (SHA-256 hash of body)

### Visibility Timeout = Processing Window

```
Message arrives       Consumer receives       Visibility Timeout
in queue              message                 expires
   │                     │                        │
   ▼                     ▼                        ▼
───────────────────────────────────────────────────────────────
   │    Visible    │      Invisible to others     │  Visible
   │   (waiting)   │    (being processed)         │  again!
                    │                              │
                    └── If not deleted by now ─────┘
                        message returns to queue
```

- **Default:** 30 seconds
- **Range:** 0 seconds to 12 hours
- **Per-message override:** `ChangeMessageVisibility` API
- **If processing takes longer than timeout:** Another consumer might pick up the same message (duplicate processing!)
- **Best practice:** Set visibility timeout to 6x the expected processing time

### Dead Letter Queue (DLQ) = Undeliverable Mail Office

Messages that fail processing repeatedly go to a DLQ:

```
Main Queue                           DLQ
┌────────┐                          ┌────────┐
│Message A│── Attempt 1: FAIL ──→   │        │
│         │── Attempt 2: FAIL ──→   │        │
│         │── Attempt 3: FAIL ──→   │Message A│  (maxReceiveCount = 3)
│         │   (max retries hit)     │        │
└────────┘                          └────────┘

Investigate manually or set up Lambda to process DLQ.
DLQ Redrive: move messages back to source queue after fixing the issue.
```

**maxReceiveCount:** How many times a message can be received before going to DLQ. Set on the source queue's redrive policy.

**Key rule:** DLQ for Standard queue must be Standard. DLQ for FIFO must be FIFO.

### Long Polling vs Short Polling

```
Short Polling (default):                Long Polling:
"Is there mail?" → "No"                "I'll wait at the counter"
"Is there mail?" → "No"                (waits up to 20 seconds)
"Is there mail?" → "Yes! Here."        "Here's your mail!"

Cost: Many empty API calls              Cost: Fewer API calls
Result: Higher cost, higher latency     Result: Lower cost, lower latency
```

- **Enable long polling:** Set `WaitTimeSeconds` = 1-20 seconds (on ReceiveMessage call or queue attribute)
- **Long polling = recommended** — reduces empty responses and API costs

### Delay Queues = Holding Period

Messages are invisible for a delay period after being sent:

- **Queue-level delay:** `DelaySeconds` = 0-900 seconds (15 minutes max)
- **Per-message delay:** `MessageTimer` (overrides queue setting, Standard only)
- Use case: "Process this order, but wait 5 minutes first" (cooling-off period)

### SQS + Lambda Integration

```
SQS Queue                      Lambda Function
    │                               │
    │── Event Source Mapping ───────→│
    │   (Lambda polls the queue)    │
    │                               │── Process batch
    │                               │── Return success/failure
    │                               │
    │   Batch size: 1-10,000        │
    │   Batch window: 0-300 sec     │
    │                               │
    │   Success: Messages deleted   │
    │   Failure: Messages return    │
    │   to queue after visibility   │
    │   timeout                     │
```

**Key facts for Lambda + SQS:**
- Lambda uses **long polling** automatically
- **Batch size:** 1-10 (FIFO), 1-10,000 (Standard)
- **Batch window:** Waits up to N seconds to fill a batch before invoking
- **Partial batch failure:** Use `ReportBatchItemFailures` to only retry failed messages
- Lambda scales up to **1,000 concurrent executions** for Standard queues (5 batches per shard initially, scales up)
- For FIFO: Lambda scales to the number of **message groups** (one Lambda per group)

---

## SNS — Simple Notification Service (The PA System)

### How It Works

```
Publisher                SNS Topic              Subscribers
(Announcer)            (PA Channel)           (Listeners)
    │                      │                       │
    │── Publish ──────────→│──→ SQS Queue 1       │
    │   message            │──→ SQS Queue 2       │
    │                      │──→ Lambda Function    │
    │                      │──→ HTTP/S Endpoint    │
    │                      │──→ Email              │
    │                      │──→ SMS                │
    │                      │──→ Kinesis Firehose   │
    │                      │──→ Mobile Push        │
    │                      │                       │
    └──────────────────────┘                       │
         Fan-out: ONE message → MANY destinations  │
```

### Fan-Out Pattern: SNS + SQS

The most important architectural pattern:

```
         ┌─── SQS Queue: order-processing
         │
SNS ─────┼─── SQS Queue: inventory-update
Topic    │
         ├─── SQS Queue: analytics
         │
         └─── SQS Queue: notification-service

One order event → processed by 4 independent services.
If inventory-update is slow, it doesn't affect order-processing.
Each queue has its own DLQ and processing speed.
```

**Why not just send to each queue directly?**
- SNS decouples the publisher from subscribers
- Adding a new subscriber = just subscribe to the topic (no publisher changes)
- Each subscriber processes independently (failure isolation)

### SNS FIFO Topics

```
SNS FIFO Topic ──→ SQS FIFO Queue 1
    │            ──→ SQS FIFO Queue 2
    │
    FIFO → FIFO only (can't mix with Standard queues)
    Supports: Message ordering + deduplication
    Throughput: 300 publishes/s (3,000 with batching)
```

### Message Filtering

Subscribers can filter which messages they receive:

```json
// Subscriber filter policy:
{
  "eventType": ["order_placed"],
  "region": ["ap-southeast-2", "us-east-1"]
}

// Only receives messages where:
// - eventType = "order_placed"  AND
// - region = "ap-southeast-2" or "us-east-1"
```

**Filter policy scope:**
- **MessageAttributes** (default) — filter on message attributes
- **MessageBody** — filter on the JSON message body content

Without filtering, subscribers receive ALL messages on the topic.

### SNS Key Features

- **Message size:** max 256 KB
- **Large messages:** Use SNS Extended Client Library (stores payload in S3)
- **Delivery retries:** Configurable retry policy for HTTP/S endpoints
- **Dead-letter queue:** SNS can send failed deliveries to an SQS DLQ
- **Encryption:** SSE using KMS
- **Access policies:** Resource-based policy on the topic (like S3 bucket policy)

---

## SES — Simple Email Service (National Email Service)

```
┌─────────────────────────────────────────────────┐
│                 Amazon SES                        │
│          (National Email Service)                 │
│                                                   │
│  SENDING:                                         │
│  ├── SMTP Interface (standard email protocol)    │
│  ├── SES API (SendEmail, SendRawEmail)           │
│  └── SES Console (test emails)                    │
│                                                   │
│  RECEIVING:                                       │
│  ├── Receive emails on your domain               │
│  ├── Process with Lambda, S3, SNS, WorkMail      │
│  └── Receipt rules (route incoming email)        │
│                                                   │
│  FEATURES:                                        │
│  ├── Templates (reusable email templates)        │
│  ├── Configuration Sets (tracking & events)      │
│  ├── Dedicated IPs (consistent sending reputation)│
│  └── Suppression List (don't email complainers)  │
└─────────────────────────────────────────────────┘
```

**Key facts:**
- Starts in **sandbox mode** (can only send to verified email addresses)
- Must request **production access** to send to any recipient
- **Domain verification:** DKIM, SPF, DMARC for deliverability
- Use case: transactional emails, marketing campaigns, bulk notifications
- **NOT** for pub/sub messaging (that's SNS)

---

## SQS vs SNS Decision Tree

```
                    "I need to send a message"
                              │
                    ┌─────────┴─────────┐
                    │                     │
              One consumer?          Many consumers?
              (Point-to-point)       (Fan-out/Broadcast)
                    │                     │
                   SQS                   SNS
              (Post Office)          (PA System)
                    │                     │
              ┌─────┴─────┐         ┌─────┴─────┐
              │            │         │            │
          Order matters?   No    Need queuing    No queuing
              │                  after broadcast?  needed
             FIFO            SNS → SQS fan-out    SNS only
                          (Best of both worlds)
```

---

## Architecture: Event-Driven with SQS + SNS

```
┌──────────┐     ┌─────────┐     ┌──────────────────────────────────┐
│ API GW   │────→│ Lambda   │────→│         SNS Topic                │
│ /order   │     │ (create) │     │       "new-order"                │
└──────────┘     └─────────┘     └──────┬───────┬───────┬──────────┘
                                        │       │       │
                                        ▼       ▼       ▼
                                   ┌────────┐ ┌────┐ ┌──────────┐
                                   │SQS:    │ │SQS:│ │SQS:      │
                                   │payment │ │inv.│ │analytics │
                                   └───┬────┘ └──┬─┘ └────┬─────┘
                                       │         │        │
                                       ▼         ▼        ▼
                                   ┌────────┐ ┌────┐ ┌──────────┐
                                   │Lambda  │ │ECS │ │Lambda    │
                                   │process │ │svc │ │aggregate │
                                   │payment │ │    │ │          │
                                   └────────┘ └────┘ └──────────┘
                                       │
                                   ┌───▼────┐
                                   │DLQ:    │  (Failed payments
                                   │payment │   investigated here)
                                   │-errors │
                                   └────────┘
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- SNS + SQS fan-out pattern (THE most tested messaging pattern)
- Standard vs FIFO queue selection criteria
- Decoupling architectures — when to add SQS between components
- DLQ for error handling
- When to use SQS vs SNS vs EventBridge vs Kinesis

### DVA-C02 (Developer)
- SQS + Lambda event source mapping (batch size, batch window, partial failures)
- Visibility timeout tuning
- Long polling configuration
- Message deduplication (FIFO)
- Message group IDs for parallel processing
- SNS message filtering
- PutMetricData → SNS alarm → Lambda (event chains)

### SOA-C02 (SysOps)
- DLQ configuration and monitoring
- Queue depth metrics (ApproximateNumberOfMessagesVisible)
- Auto Scaling based on queue depth
- SQS access policies
- Encryption at rest (SSE-SQS or SSE-KMS)
- Monitoring: ApproximateAgeOfOldestMessage for processing delays
- SES sending quotas and sandbox limitations

---

## Key Numbers

| Item | Value |
|------|-------|
| **SQS** | |
| Message size max | **256 KB** (use Extended Client Library + S3 for larger) |
| Message retention | **1 minute to 14 days** (default: 4 days) |
| Visibility timeout | **0 seconds to 12 hours** (default: 30 seconds) |
| Long polling max wait | **20 seconds** |
| Delay queue max | **15 minutes** (900 seconds) |
| Standard throughput | **Nearly unlimited** |
| FIFO throughput | **300 msg/s** (3,000 with batching, 70,000 with high-throughput mode) |
| Inflight messages (Standard) | **120,000** |
| Inflight messages (FIFO) | **20,000** |
| Batch operations max | **10 messages** per batch |
| DLQ deduplication window | **5 minutes** (FIFO) |
| **SNS** | |
| Message size max | **256 KB** |
| Subscriptions per topic | **12,500,000** (soft limit) |
| Topics per account | **100,000** (soft limit) |
| SNS FIFO throughput | **300 msg/s** (3,000 with batching) |
| **SES** | |
| Sandbox sending limit | **200 emails/day**, 1 email/second |
| Production limit | **50,000 emails/day** (can increase) |

---

## Cheat Sheet

- **SQS = pull model** (consumer polls). **SNS = push model** (publisher pushes to subscribers)
- **Standard = at-least-once, unlimited throughput, possible duplicates**
- **FIFO = exactly-once, ordered, 300 msg/s (3K batched, 70K high-throughput)**
- **FIFO queue name must end in `.fifo`**
- **Message Group ID** = ordering within a group, parallelism between groups
- **Visibility Timeout** = processing window. Default 30s, max 12h
- **DLQ** = messages that fail maxReceiveCount times. Standard→Standard, FIFO→FIFO
- **DLQ Redrive** = move messages from DLQ back to source queue
- **Long Polling** = `WaitTimeSeconds` 1-20. Reduces costs, reduces empty responses
- **Delay Queue** = messages invisible for up to 15 minutes after send
- **Lambda + SQS**: Lambda polls automatically. Use `ReportBatchItemFailures` for partial failures
- **SNS + SQS Fan-out** = one event → multiple independent processors (THE pattern)
- **SNS FIFO → SQS FIFO only** (can't fan out to Standard queues from FIFO topic)
- **SNS Message Filtering** = subscribers only get messages matching their filter policy
- **256 KB max** for both SQS and SNS messages. Use S3 for larger payloads
- **SQS retention** = 1 min to 14 days (default 4 days). NOT infinite like CloudWatch Logs
- **SES sandbox** = must verify every recipient. Request production access to send freely
- **SQS is NOT real-time** — there's inherent polling latency. For real-time, use Kinesis
- **ApproximateNumberOfMessagesVisible** = queue depth metric for Auto Scaling triggers
- **SQS purge** = delete all messages (PurgeQueue API). Only once per 60 seconds
- **Temporary queues** = virtual queues for request-response patterns (lightweight, no API calls)
