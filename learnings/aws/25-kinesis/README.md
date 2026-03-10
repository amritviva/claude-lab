# Kinesis — River of Data

> **Kinesis is a river system for real-time streaming data. Data Streams is the main river with channels (shards). Firehose is the delivery truck that picks up data and drops it at a warehouse. Analytics is a processing plant on the river bank.**

---

## ELI10

Imagine a massive river flowing through the country. Water (data) constantly pours in from thousands of streams — app clicks, IoT sensors, log files. The river has channels (shards) — each channel can carry a certain amount of water. Data Streams is the main river where you put boats (consumers) to read the water as it flows. Firehose is a delivery truck parked by the river — it scoops up water and drives it to a storage warehouse (S3, Redshift). Analytics is a processing plant on the riverbank — it filters the water while it's flowing, without storing it first.

---

## The Concept

### Kinesis Family — The River System

```
┌─────────────────────────────────────────────────────────────────┐
│                    KINESIS FAMILY                                 │
│                                                                   │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────────┐ │
│  │ Data Streams   │  │ Firehose       │  │ Data Analytics     │ │
│  │ (Main River)   │  │ (Delivery Truck│  │ (Processing Plant) │ │
│  │                │  │                │  │                    │ │
│  │ Real-time      │  │ Near-real-time │  │ SQL on streaming   │ │
│  │ You manage     │  │ Fully managed  │  │ data               │ │
│  │ consumers      │  │ auto-delivery  │  │                    │ │
│  │                │  │ to S3/Redshift │  │ Input: stream      │ │
│  │ Retention:     │  │ /OpenSearch    │  │ Output: stream     │ │
│  │ 24hr - 365 day │  │               │  │ or destination     │ │
│  └────────────────┘  └────────────────┘  └────────────────────┘ │
│                                                                   │
│  ┌────────────────┐                                              │
│  │ Video Streams  │                                              │
│  │ (Video River)  │                                              │
│  │ ML/Video proc  │                                              │
│  └────────────────┘                                              │
└─────────────────────────────────────────────────────────────────┘
```

### Kinesis Data Streams — The Main River

```
   Producers                    Shards (Channels)              Consumers
   (Data Sources)               (1MB/s in, 2MB/s out each)     (Readers)

   ┌──────────┐                 ┌──────────────────┐           ┌──────────┐
   │ App Logs │──┐              │  Shard 1         │      ┌──>│ Lambda   │
   └──────────┘  │              │  Keys: A-M       │──────┤   └──────────┘
                 │   Partition  │  1 MB/s write     │      │
   ┌──────────┐  ├──  Key   ──>│  2 MB/s read      │      │   ┌──────────┐
   │ IoT Data │──┤   routing   └──────────────────┘      ├──>│ EC2 App  │
   └──────────┘  │              ┌──────────────────┐      │   └──────────┘
                 │              │  Shard 2         │      │
   ┌──────────┐  │              │  Keys: N-Z       │──────┘   ┌──────────┐
   │ Clicks   │──┘              │  1 MB/s write     │     ┌──>│ Firehose │
   └──────────┘                 │  2 MB/s read      │─────┘   └──────────┘
                                └──────────────────┘
```

| Concept | Analogy | Detail |
|---------|---------|--------|
| **Shard** | River channel | Unit of capacity: 1 MB/s in, 2 MB/s out, 1000 records/s in |
| **Partition Key** | Sorting hat | Determines which shard a record goes to (MD5 hash) |
| **Sequence Number** | Timestamp stamp | Unique ID per record within a shard |
| **Data Record** | Drop of water | Blob up to 1 MB |
| **Retention** | How long water stays | 24 hours (default), up to 365 days |
| **Producer** | Water source | Puts data in (SDK, KPL, Kinesis Agent) |
| **Consumer** | Boat on the river | Reads data out (SDK, KCL, Lambda) |

### Enhanced Fan-Out

```
WITHOUT Enhanced Fan-Out (Shared Throughput):
┌──────────┐
│ Shard 1  │──── 2 MB/s shared ────┬── Consumer A (gets ~1 MB/s)
│          │                        └── Consumer B (gets ~1 MB/s)
└──────────┘    (polling, 200ms latency)

WITH Enhanced Fan-Out (Dedicated Throughput):
┌──────────┐
│ Shard 1  │──── 2 MB/s dedicated ──── Consumer A (gets 2 MB/s)
│          │──── 2 MB/s dedicated ──── Consumer B (gets 2 MB/s)
└──────────┘    (push via HTTP/2, ~70ms latency)

• Up to 20 enhanced fan-out consumers per stream
• Each gets DEDICATED 2 MB/s per shard
• Data is PUSHED (not polled) — lower latency
• Costs more but essential for multiple consumers
```

### Kinesis Client Library (KCL)

```
┌─────────────────────────────────────────────┐
│              KCL (Kinesis Client Library)     │
│                                               │
│  • One KCL worker per shard (max)             │
│  • Uses DynamoDB table for checkpointing      │
│  • Handles shard splits/merges automatically  │
│  • Coordinates across multiple EC2 instances  │
│                                               │
│  Rule: # KCL instances <= # shards            │
│  (You can't have more workers than shards)    │
│                                               │
│  4 shards → max 4 KCL instances               │
│  4 shards, 2 instances → each handles 2 shards│
└─────────────────────────────────────────────┘
```

### Kinesis Data Firehose — The Delivery Truck

```
   Sources                  Firehose                      Destinations
                       (Buffer → Transform → Deliver)

   ┌──────────┐        ┌─────────────────────┐           ┌──────────┐
   │ Data     │        │  Buffer:             │           │ S3       │ ← Primary
   │ Streams  │──┐     │  • Size: 1-128 MB    │      ┌──>│          │
   └──────────┘  │     │  • Time: 0-900 sec   │      │   └──────────┘
                 │     │                       │      │
   ┌──────────┐  ├────>│  Transform (optional):│──────┤   ┌──────────┐
   │ Direct   │──┤     │  • Lambda function    │      ├──>│ Redshift │
   │ PUT      │  │     │  • Format conversion  │      │   └──────────┘
   └──────────┘  │     │  • (Parquet, ORC)     │      │
                 │     │                       │      │   ┌──────────┐
   ┌──────────┐  │     │  Compression:         │      ├──>│OpenSearch│
   │ CloudWatch│─┘     │  • GZIP, Snappy, etc  │      │   └──────────┘
   │ Logs     │        │                       │      │
   └──────────┘        └─────────────────────┘      │   ┌──────────┐
                                                      └──>│ Splunk   │
                                                          └──────────┘
                                                      + HTTP endpoints
                                                      + 3rd party (Datadog, etc.)
```

| Feature | Data Streams | Firehose |
|---------|-------------|----------|
| Latency | Real-time (~200ms) | Near-real-time (60s+ buffer) |
| Management | You manage consumers | Fully managed delivery |
| Shards | You provision and manage | No shards (auto-scales) |
| Scaling | Manual (shard split/merge) | Automatic |
| Data retention | 24h - 365 days | No retention (deliver and done) |
| Replay | Yes (re-read old data) | No (once delivered, gone) |
| Consumers | Multiple, custom | Pre-defined destinations |
| Cost model | Per shard-hour + PUT | Per GB ingested |
| Transform | Consumer code | Lambda (optional) |

### Kinesis Data Analytics

```
┌────────────────────────────────────────────────┐
│            Kinesis Data Analytics                │
│                                                  │
│  Input Stream ──> SQL / Apache Flink ──> Output  │
│  (Data Streams     (Real-time query)   (Stream   │
│   or Firehose)                          or dest) │
│                                                  │
│  Example SQL:                                    │
│  SELECT ticker, AVG(price) as avg_price          │
│  FROM "SOURCE_STREAM"                            │
│  GROUP BY ticker, STEP("SOURCE_STREAM".ROWTIME   │
│    BY INTERVAL '1' MINUTE)                       │
│                                                  │
│  Use cases:                                      │
│  • Real-time dashboards                          │
│  • Anomaly detection                             │
│  • Time-series aggregation                       │
└────────────────────────────────────────────────┘
```

### Kinesis vs SQS — When to Use Which

```
┌───────────────────────┬────────────────────────┐
│      KINESIS           │         SQS             │
├───────────────────────┼────────────────────────┤
│ Streaming (continuous) │ Messaging (discrete)    │
│ Ordered within shard   │ Best-effort / FIFO      │
│ Multiple consumers     │ Single consumer group   │
│ Replay data            │ Delete after processing │
│ Real-time analytics    │ Decouple services       │
│ High throughput        │ Variable throughput      │
│ You manage shards      │ Fully managed            │
│ Retain 24h - 365d     │ Retain 1min - 14 days   │
│                        │                          │
│ Use for:               │ Use for:                 │
│ • Log aggregation      │ • Job queues             │
│ • Clickstream          │ • Order processing       │
│ • IoT telemetry        │ • Async decoupling       │
│ • Real-time analytics  │ • Fan-out (with SNS)     │
└───────────────────────┴────────────────────────┘
```

### Lambda Integration with Kinesis

```
┌──────────┐     ┌──────────────────────────────────┐
│ Kinesis  │     │ Lambda (Event Source Mapping)      │
│ Stream   │────>│                                    │
│          │     │ • Reads from shards automatically  │
│ Shard 1  │     │ • Batch size: 1-10,000 records     │
│ Shard 2  │     │ • Batch window: up to 300 seconds  │
│ Shard 3  │     │ • Parallel: 1-10 per shard         │
│          │     │ • Retry on failure (blocks shard)   │
│          │     │ • Bisect on error (split batch)     │
│          │     │ • Max retry attempts configurable   │
│          │     │ • On-failure destination (SQS/SNS)  │
└──────────┘     └──────────────────────────────────┘

CRITICAL: If Lambda fails processing a batch, it RETRIES
the same batch forever (blocks the shard) unless you configure:
• Maximum retry attempts
• Maximum record age
• Bisect batch on error
• On-failure destination
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- **Kinesis vs SQS** — streaming vs messaging (most common question type)
- **Data Streams vs Firehose** — real-time vs near-real-time, managed vs self-managed
- **Firehose destinations** — S3, Redshift, OpenSearch, Splunk, HTTP
- **Shard capacity planning** — 1MB/s in, 2MB/s out per shard
- **Enhanced fan-out** for multiple consumers

### DVA-C02 (Developer)
- **Partition key design** — avoid hot shards (like using user_id, not timestamp)
- **KPL (Kinesis Producer Library)** — batching, aggregation, retry
- **KCL** — DynamoDB checkpoint table, one worker per shard max
- **Lambda integration** — batch size, error handling, bisect on error
- **PutRecord vs PutRecords** — single vs batch API calls

### SOA-C02 (SysOps)
- **Shard management** — split (increase capacity), merge (decrease capacity)
- **Monitoring** — IncomingBytes, ReadProvisionedThroughputExceeded, IteratorAgeMilliseconds
- **IteratorAge** = how far behind consumers are. High = consumers can't keep up.
- **ProvisionedThroughputExceeded** = add more shards or use exponential backoff
- **Encryption** — server-side encryption with KMS

---

## Key Numbers

| Fact | Value |
|------|-------|
| Shard write capacity | 1 MB/s or 1,000 records/s |
| Shard read capacity (shared) | 2 MB/s |
| Shard read capacity (enhanced fan-out) | 2 MB/s PER consumer |
| Max record size | 1 MB |
| Default retention | 24 hours |
| Max retention | 365 days |
| Enhanced fan-out consumers per stream | Up to 20 |
| Firehose buffer size | 1 MB to 128 MB |
| Firehose buffer interval | 0 to 900 seconds |
| KCL instances per shard | 1 max |
| Lambda batch size for Kinesis | 1 to 10,000 records |
| Lambda parallelization per shard | 1 to 10 |
| PutRecords batch limit | 500 records per call |

---

## Cheat Sheet

- **Data Streams** = real-time, you manage shards and consumers, data retained
- **Firehose** = near-real-time, fully managed delivery to S3/Redshift/OpenSearch, no retention
- **Shard** = 1 MB/s in, 2 MB/s out, 1000 records/s in
- **Partition key** determines shard. Bad key = hot shard. Use high-cardinality keys (user_id, not date).
- **Enhanced fan-out** = dedicated 2 MB/s per consumer per shard, push model, lower latency
- **KCL** uses DynamoDB for checkpointing. Max KCL instances = number of shards.
- **Firehose** can transform with Lambda and convert to Parquet/ORC before delivery
- **Firehose has NO shards** — it auto-scales. You don't manage capacity.
- **Lambda + Kinesis:** blocks shard on error. Configure max retries + bisect batch on error.
- **IteratorAgeMilliseconds** = how far behind consumers are. High = add shards or optimize consumer.
- **ProvisionedThroughputExceeded** = shard is overwhelmed. Add shards or use exponential backoff.
- **Kinesis = streaming (ordered, replay, multiple consumers)**. SQS = messaging (decouple, process once).
- **Firehose can receive from Data Streams** or directly from producers (SDK, CloudWatch, IoT).
- **Video Streams** = for video ingestion and ML processing (Rekognition, SageMaker).
