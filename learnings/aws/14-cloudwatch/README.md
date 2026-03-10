# 14 — CloudWatch: The Ministry of Intelligence & Surveillance

> **One-liner:** CloudWatch is your country's intelligence agency — it watches everything, archives everything, and sounds the alarm when something looks wrong.

---

## ELI10

Imagine a country has a Ministry of Intelligence with cameras, microphones, and spies everywhere. Every road, building, and factory is being watched. The cameras record numbers — how many cars on the highway (CPU), how full the warehouse is (disk), how many people enter the building (requests). All these recordings get filed away in police archives (logs). When something dangerous happens — like a highway getting jammed — an alarm goes off and the ministry sends out a response team. The war room has big screens showing everything happening across the country in real time.

---

## The Concept

### Metrics = Surveillance Data

Metrics are the numbers CloudWatch collects about your resources. Think of them as surveillance feeds — constantly measuring what's happening.

```
┌─────────────────────────────────────────────────────────────┐
│                   MINISTRY OF INTELLIGENCE                   │
│                       (CloudWatch)                            │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Surveillance │  │   Police     │  │   Alert      │      │
│  │  Data         │  │   Archives   │  │   System     │      │
│  │  (Metrics)    │  │   (Logs)     │  │   (Alarms)   │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │               │
│  ┌──────┴───────┐  ┌──────┴───────┐  ┌──────┴───────┐      │
│  │  War Room    │  │  Log Search  │  │  Intelligence │      │
│  │  Screens     │  │  Engine      │  │  Briefings    │      │
│  │ (Dashboards) │  │ (Insights)   │  │ (EventBridge) │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

**Namespaces** = Which ministry department collected the data.
- `AWS/EC2` = Road traffic surveillance
- `AWS/RDS` = Database security cameras
- `AWS/Lambda` = Contractor activity monitors
- `Custom/MyApp` = Your own private security cameras

**Dimensions** = Tags that identify WHICH specific thing is being watched.
- `InstanceId=i-12345` = Camera on Highway 12345
- `FunctionName=processOrder` = The camera watching the order desk

**Statistics** = How you summarize the footage — Average, Sum, Min, Max, p99, SampleCount.

**Period** = How often you review the footage (minimum 1 second for high-res, 60 seconds standard).

### Custom Metrics = Your Own Spy Network

When the built-in cameras aren't enough, you deploy your own via `PutMetricData` API:

```
aws cloudwatch put-metric-data \
  --namespace "MyApp/Orders" \
  --metric-name "OrdersProcessed" \
  --value 42 \
  --unit Count
```

**High-resolution custom metrics** = Real-time spy cameras (1-second granularity). Costs more but catches problems faster.

**Embedded Metric Format (EMF)** = Sneak metric data inside your log entries. Instead of calling PutMetricData separately, you embed structured JSON in your logs and CloudWatch automatically extracts metrics from them. Perfect for Lambda where you want metrics without extra API calls.

```json
{
  "_aws": {
    "Timestamp": 1234567890,
    "CloudWatchMetrics": [{
      "Namespace": "MyApp",
      "Dimensions": [["Service"]],
      "Metrics": [{"Name": "ProcessingTime", "Unit": "Milliseconds"}]
    }]
  },
  "Service": "OrderProcessor",
  "ProcessingTime": 245
}
```

### CloudWatch Agent = Field Agents Deployed on EC2

The default CloudWatch cameras only see the OUTSIDE of your EC2 instances (CPU, network, disk I/O, status checks). They can't see inside — no memory usage, no disk space, no application logs.

**CloudWatch Agent** = Field agents you deploy INSIDE the building to report from within.

```
┌─────────────── EC2 Instance ───────────────────┐
│                                                  │
│  ┌────────────────────────────────┐             │
│  │    CloudWatch Agent            │             │
│  │    (Field Agent Inside)        │             │
│  │                                │             │
│  │  Reports:                      │             │
│  │  - Memory utilization  ────────┼──→ CloudWatch
│  │  - Disk space (% used) ────────┼──→  Metrics
│  │  - Application logs    ────────┼──→  Logs
│  │  - Custom StatsD metrics ──────┼──→  Metrics
│  └────────────────────────────────┘             │
│                                                  │
│  DEFAULT (no agent):                             │
│  - CPU, Network, Disk I/O ────────────→ CloudWatch
│  - Status checks          ────────────→  Metrics
│  (Hypervisor-level only)                         │
└──────────────────────────────────────────────────┘
```

**Installation:**
1. Install the agent package on EC2 (or use SSM Run Command)
2. Configure via `amazon-cloudwatch-agent.json` (wizard: `amazon-cloudwatch-agent-config-wizard`)
3. Store config in SSM Parameter Store for reuse across instances
4. Start the agent

**Key fact:** Memory and disk space percentage are NOT default metrics. You NEED the agent.

### Logs = Police Archives

```
Log Group          = Case file cabinet (e.g., /aws/lambda/processOrder)
  └─ Log Stream    = Individual case file (e.g., one Lambda instance)
       └─ Log Event = Single page in the case file (one log line + timestamp)
```

**Log retention:** Default = **Never expire** (logs kept forever, costs accumulate). You must manually set retention (1 day to 10 years).

**Log destinations:**
- S3 (cheapest long-term archive — batch export, NOT real-time)
- Kinesis Data Firehose (near real-time export)
- Kinesis Data Streams (real-time streaming)
- Lambda (process/transform logs)
- OpenSearch (search and dashboards)

**Subscription Filters** = Automatic forwarding rules. "Anything matching pattern X, send to destination Y."

**Cross-account log delivery:** Use subscription filters to stream logs from Account A to a Kinesis stream or S3 bucket in Account B.

### Metric Filters = Search Patterns That Create Metrics

You tell CloudWatch: "Search the police archives for this pattern, and every time you find it, record a number."

Example: Search for `ERROR` in your application logs → creates a metric `ErrorCount` → attach an alarm to it.

```
Log Group (/app/server)
    │
    ├─ "INFO: Request processed in 45ms"     → no match
    ├─ "ERROR: Database connection failed"    → MATCH! ErrorCount += 1
    ├─ "INFO: Request processed in 32ms"      → no match
    ├─ "ERROR: Timeout after 30s"             → MATCH! ErrorCount += 1
    │
    └─→ Metric Filter: pattern = "ERROR"
         └─→ Custom Metric: ErrorCount = 2
              └─→ Alarm: if ErrorCount > 5 in 5 min → SNS notification
```

### Alarms = Alert System

An alarm watches a single metric and triggers actions based on thresholds.

**Three states:**
```
    ┌────────┐         ┌────────┐         ┌──────────────────┐
    │   OK   │ ──────→ │ ALARM  │ ──────→ │ INSUFFICIENT_DATA│
    │(green) │ ←────── │ (red)  │ ←────── │    (grey)        │
    └────────┘         └────────┘         └──────────────────┘
```

- **OK** = Everything normal
- **ALARM** = Threshold breached
- **INSUFFICIENT_DATA** = Not enough data to decide (also the INITIAL state)

**Evaluation:** `Period` x `Evaluation Periods` = how long before alarm triggers.
- Period = 60s, Evaluation Periods = 5 → must be breaching for 5 minutes straight.

**Datapoints to Alarm** = "M of N" — e.g., 3 of 5 periods must breach (avoids false alarms from blips).

**Alarm Actions:**
- **EC2 actions:** Stop, Terminate, Reboot, Recover
- **Auto Scaling:** Scale up/down
- **SNS:** Send notification (email, SMS, Lambda, SQS, HTTP)
- **Lambda:** (via SNS or EventBridge)

### Composite Alarms = Combined Intelligence

Combine multiple alarms with AND/OR logic:

```
Alarm: HighCPU (CPU > 80%)    ─┐
                                ├─ AND → Composite Alarm → SNS
Alarm: HighMemory (Mem > 90%) ─┘

Only fires when BOTH conditions are true.
Reduces alarm noise dramatically.
```

**Key use case:** Avoid pager fatigue. Instead of getting alerted for CPU spike alone, only alert when CPU is high AND memory is high AND request latency is high.

### Anomaly Detection = AI Watching for Unusual Patterns

CloudWatch uses ML to learn what "normal" looks like for a metric, then creates a band (expected range). If the metric goes outside the band, it's anomalous.

- Accounts for time-of-day patterns (traffic peaks at 9am)
- Accounts for day-of-week patterns (less traffic on weekends)
- You can exclude specific periods from training (deploy windows)

Use it in alarms: `ANOMALY_DETECTION_BAND(m1, 2)` = alert if metric goes 2 standard deviations outside normal.

### Dashboards = War Room Screens

- Visualize metrics, logs, and alarms on customizable screens
- **Cross-account dashboards:** See metrics from multiple AWS accounts on one screen (requires cross-account access setup in CloudWatch settings)
- **Cross-region dashboards:** Pull metrics from any region into a single dashboard
- Up to 3 dashboards free, then $3/month per dashboard
- Auto-refresh: 10s, 1m, 2m, 5m, 15m

### Logs Insights = Query Language for Archives

SQL-like query language to search and analyze logs:

```sql
fields @timestamp, @message
| filter @message like /ERROR/
| stats count(*) as errorCount by bin(5m)
| sort errorCount desc
| limit 20
```

Common commands: `fields`, `filter`, `stats`, `sort`, `limit`, `parse`, `display`.

**Key:** Logs Insights queries run against log groups, can query multiple log groups simultaneously, and results can be exported or added to dashboards.

### Metric Math = Calculated Surveillance

Combine metrics with math expressions:

```
METRICS("m1") = CPUUtilization
METRICS("m2") = NetworkIn

Expression: (m1 + m2) / 2    → Combined load metric
Expression: ANOMALY_DETECTION_BAND(m1, 2) → Anomaly band
Expression: FILL(m1, 0)      → Fill missing data with 0
```

Use metric math in alarms, dashboards, and API calls.

### Events / EventBridge = Intelligence Briefings

CloudWatch Events (now EventBridge) triggers actions based on state changes:

```
Event Source              →    Rule (Pattern Match)    →    Target
───────────────────          ─────────────────────         ──────────
EC2 state change              "state": "terminated"        Lambda
CodePipeline failed           "state": "FAILED"            SNS
Scheduled (cron)              rate(5 minutes)              Step Functions
API call (via CloudTrail)     "CreateBucket"               Lambda
```

**EventBridge is the evolution of CloudWatch Events.** Same underlying service, more features (custom event buses, schema registry, third-party integrations).

---

## Architecture: Full CloudWatch Ecosystem

```
┌──── EC2 (with Agent) ────┐    ┌──── Lambda ────┐    ┌──── RDS ────┐
│  CPU, Mem, Disk, Logs     │    │  Duration,      │    │  CPU, Conns, │
│  Custom StatsD            │    │  Errors, Logs   │    │  FreeStorage │
└───────────┬───────────────┘    └───────┬─────────┘    └──────┬──────┘
            │                            │                      │
            ▼                            ▼                      ▼
┌──────────────────────────────────────────────────────────────────────┐
│                         CloudWatch                                    │
│                                                                       │
│  ┌─────────┐  ┌─────────┐  ┌──────────┐  ┌───────────┐             │
│  │ Metrics  │  │  Logs   │  │  Alarms  │  │ Dashboards│             │
│  │ Store    │  │  Store  │  │          │  │           │             │
│  └────┬─────┘  └────┬────┘  └─────┬────┘  └───────────┘             │
│       │              │             │                                   │
│  Metric Math    Log Insights   Composite    Anomaly Detection         │
│  Metric Filter  Subscription   Alarms                                 │
│                 Filters                                                │
└───────┬──────────────┬─────────────┬─────────────────────────────────┘
        │              │             │
        ▼              ▼             ▼
   EventBridge      S3/Kinesis    SNS/Auto Scaling/Lambda
   (trigger)        (archive)     (respond)
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- Which metric requires CloudWatch Agent? (memory, disk space %)
- How to monitor across accounts? (cross-account dashboards, cross-account log delivery)
- Alarm → Auto Scaling for cost optimization
- Log retention and cost management
- When to use Logs Insights vs Athena (Insights for quick queries, Athena for S3-archived logs)

### DVA-C02 (Developer)
- Embedded Metric Format (EMF) — publish custom metrics from Lambda without PutMetricData
- PutMetricData API — custom metrics, high-resolution
- Metric filters — turn log patterns into metrics
- CloudWatch Agent configuration for custom metrics
- Logs Insights query syntax
- How to publish custom metrics from application code

### SOA-C02 (SysOps)
- CloudWatch Agent installation and troubleshooting
- SSM Parameter Store for agent config distribution
- Alarm configuration — evaluation periods, datapoints to alarm, actions
- Composite alarms to reduce noise
- Cross-account monitoring setup
- Dashboard creation and sharing
- Log retention policies
- Anomaly detection configuration

---

## Key Numbers

| Item | Value |
|------|-------|
| Basic monitoring interval | **5 minutes** (free) |
| Detailed monitoring interval | **1 minute** ($3.50/instance/month for first 10) |
| High-resolution custom metrics | **1 second** minimum period |
| Custom metrics per account | **Soft limit, can increase** |
| Metric retention: < 60s | **3 hours** |
| Metric retention: 60s (1 min) | **15 days** |
| Metric retention: 300s (5 min) | **63 days** |
| Metric retention: 3600s (1 hour) | **455 days** (15 months) |
| Log retention default | **Never expire** (must set manually) |
| Log event max size | **256 KB** |
| Dashboards free tier | **3 dashboards** |
| Dashboards cost | **$3/month** per dashboard after free tier |
| Alarm evaluation minimum period | **10 seconds** (high-res), **60 seconds** (standard) |
| PutMetricData max | **1000 metrics per API call** (with `MetricDatum` list) |
| PutMetricData values per datum | **Up to 150 values** (using `Values` + `Counts`) |
| Subscription filters per log group | **2** |
| Metric filter per log group | **100** |
| CloudWatch Agent config location | **SSM Parameter Store** (recommended) |

---

## Cheat Sheet

- **Memory/disk % NOT default** — need CloudWatch Agent
- **Log retention default = never expire** — set it or pay forever
- **Basic = 5 min, Detailed = 1 min, High-res = 1 sec**
- **Metric data resolution:** 1s stored 3h, 1m stored 15d, 5m stored 63d, 1h stored 455d
- **INSUFFICIENT_DATA** is the initial alarm state, not OK
- **Composite alarms** = AND/OR logic to reduce alarm noise
- **Metric filters** = turn log patterns into numeric metrics
- **EMF** = embed metrics in logs (great for Lambda, avoids PutMetricData call)
- **Subscription filters** = real-time log forwarding (max 2 per log group)
- **S3 export** = batch, not real-time. Use Kinesis Firehose for near-real-time
- **Anomaly detection** = ML-based, learns daily/weekly patterns
- **CloudWatch Agent config** = JSON file, store in SSM Parameter Store
- **Cross-account dashboards** = enabled via CloudWatch settings, needs org or account IDs
- **Namespace convention:** `AWS/ServiceName` for AWS, `Custom/YourApp` for custom
- **CloudWatch ≠ CloudTrail** — CloudWatch = performance monitoring, CloudTrail = API audit logging
- **Alarm actions can recover EC2** — move instance to new host hardware
- **Logs Insights** = serverless, pay per query, results in seconds
- **EventBridge** is the successor to CloudWatch Events — use EventBridge for new designs
