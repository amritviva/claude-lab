# X-Ray — Detective / Surveillance Drone

> **X-Ray is a detective who follows one request through every department it visits. The trace is the full investigation report, segments are chapters (one per service), subsegments are paragraphs (downstream calls), and the service map is the investigation board showing all connections.**

---

## ELI10

Imagine a detective following one person as they walk through a huge government building. The person enters the front desk (API Gateway), gets sent to the records department (Lambda), who then calls the filing cabinet (DynamoDB) and the mail room (SQS). The detective writes a report: "Front desk took 2ms, records department took 150ms, filing cabinet took 50ms, mail room took 30ms." The detective pins this report on an investigation board (service map) that shows how all departments connect. If one department is slow, you can see it immediately. That's X-Ray.

---

## The Concept

### X-Ray — Distributed Tracing Service

```
┌──────────────────────────────────────────────────────────────┐
│                         X-RAY                                 │
│                                                               │
│  Request Flow:                                                │
│  Client → API Gateway → Lambda → DynamoDB                     │
│                            │                                  │
│                            └──→ SQS → Worker Lambda           │
│                                                               │
│  X-Ray Trace (investigation report):                          │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Trace ID: 1-581cf771-a006649127e371903a2de979            │ │
│  │ Duration: 232ms                                          │ │
│  │                                                          │ │
│  │ ┌──── API Gateway (Segment) ────── 5ms ──────┐          │ │
│  │ │                                              │          │ │
│  │ ├──── Lambda (Segment) ────────── 150ms ──────┤          │ │
│  │ │   ├── DynamoDB (Subsegment) ── 50ms         │          │ │
│  │ │   └── SQS (Subsegment) ─────── 27ms         │          │ │
│  │ │                                              │          │ │
│  │ └──── Worker Lambda (Segment) ── 50ms ────────┘          │ │
│  │     └── DynamoDB (Subsegment) ── 35ms                    │ │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

### Core Concepts

| Concept | Analogy | Detail |
|---------|---------|--------|
| **Trace** | Full investigation report | End-to-end journey of one request through all services |
| **Segment** | Chapter | One service's contribution to the trace (Lambda, API GW) |
| **Subsegment** | Paragraph | Downstream call from a segment (DynamoDB, HTTP, SQL) |
| **Service Map** | Investigation board | Visual graph of all services and their connections |
| **Trace ID** | Case number | Unique ID propagated across services via HTTP header `X-Amzn-Trace-Id` |
| **Annotations** | Indexed sticky notes | Key-value pairs you add to segments. SEARCHABLE/FILTERABLE. |
| **Metadata** | Non-indexed notes | Extra data attached to segments. NOT searchable. |
| **Sampling** | Which cases to investigate | Rules about which requests to trace (not all — too expensive) |

### Segments and Subsegments — Deep Dive

```
┌──────────────────────────────────────────────────────────┐
│                    SEGMENT (Lambda)                        │
│                                                            │
│  Service: processOrder Lambda                              │
│  Duration: 150ms                                           │
│  Status: 200                                               │
│  Annotations:                                              │
│    customer_type: "premium"    ← SEARCHABLE                │
│    order_id: "ORD-123"        ← SEARCHABLE                │
│  Metadata:                                                 │
│    order_details: {...}        ← NOT searchable            │
│                                                            │
│  ┌── Subsegment: DynamoDB GetItem ──── 50ms ────┐        │
│  │   Table: Orders                                │        │
│  │   Operation: GetItem                           │        │
│  │   Status: 200                                  │        │
│  └────────────────────────────────────────────────┘        │
│                                                            │
│  ┌── Subsegment: SQS SendMessage ──── 27ms ─────┐        │
│  │   Queue: order-notifications                   │        │
│  │   Operation: SendMessage                       │        │
│  │   Status: 200                                  │        │
│  └────────────────────────────────────────────────┘        │
│                                                            │
│  ┌── Subsegment: External HTTP ──── 73ms ────────┐        │
│  │   URL: https://payment-api.example.com/charge  │        │
│  │   Method: POST                                 │        │
│  │   Status: 200                                  │        │
│  └────────────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────────┘
```

### Service Map — The Investigation Board

```
                    ┌──────────────┐
                    │   Client     │
                    └──────┬───────┘
                           │
                    ┌──────v───────┐
                    │ API Gateway  │──── avg: 5ms
                    └──────┬───────┘     error: 0.1%
                           │
                    ┌──────v───────┐
                    │   Lambda     │──── avg: 150ms
                    │ processOrder │     error: 2.3%
                    └──┬───────┬───┘
                       │       │
              ┌────────v──┐ ┌──v────────┐
              │ DynamoDB  │ │   SQS     │
              │ Orders    │ │ notif-q   │
              │ avg: 50ms │ │ avg: 27ms │
              │ err: 0%   │ │ err: 0%   │
              └───────────┘ └─────┬─────┘
                                  │
                           ┌──────v───────┐
                           │   Lambda     │
                           │ sendNotif    │
                           │ avg: 50ms    │
                           └──────────────┘

Color-coded:
• Green = healthy (low error rate, fast)
• Yellow = degraded (moderate errors/latency)
• Red = error (high error rate or slow)
```

### Sampling Rules — Which Requests to Trace

```
┌──────────────────────────────────────────────────────────┐
│                   SAMPLING RULES                           │
│                                                            │
│  Default Rule:                                             │
│  • 1 request per second (reservoir)                        │
│  • + 5% of additional requests (fixed rate)                │
│                                                            │
│  Why not trace everything?                                 │
│  • Cost (each trace = data stored and analyzed)            │
│  • Performance overhead (instrumentation adds latency)     │
│  • Volume (millions of requests → millions of traces)      │
│                                                            │
│  Custom Sampling Rules:                                    │
│  ┌──────────────────────────────────────────────┐         │
│  │ Rule: "Payment traces"                        │         │
│  │ Priority: 100 (lower = higher priority)       │         │
│  │ Reservoir: 10/second                          │         │
│  │ Fixed rate: 0.50 (50%)                        │         │
│  │ Service: processPayment                       │         │
│  │ URL path: /api/payments/*                     │         │
│  │ HTTP method: POST                             │         │
│  │                                                │         │
│  │ → Traces 50% of payment requests              │         │
│  │   (important transactions get more visibility) │         │
│  └──────────────────────────────────────────────┘         │
│                                                            │
│  Sampling rules are applied at the service level            │
│  (not centrally) — each service evaluates rules locally     │
└──────────────────────────────────────────────────────────┘
```

### X-Ray Daemon — The Listening Device

```
┌──────────────────────────────────────────────────────────┐
│                   X-RAY DAEMON                             │
│                                                            │
│  EC2 / ECS (EC2 launch type):                              │
│  ┌──────────────────────────┐                              │
│  │ Your Application         │                              │
│  │ (X-Ray SDK integrated)   │                              │
│  │          │                │                              │
│  │          v                │                              │
│  │ X-Ray Daemon (UDP 2000)  │                              │
│  │          │                │                              │
│  │          v                │                              │
│  │ X-Ray API (sends traces) │                              │
│  └──────────────────────────┘                              │
│                                                            │
│  The daemon:                                               │
│  • Listens on UDP port 2000                                │
│  • Batches trace segments                                  │
│  • Sends to X-Ray API                                      │
│  • Runs as a background process                            │
│                                                            │
│  Lambda & API Gateway:                                     │
│  • Built-in X-Ray support (no daemon needed!)              │
│  • Just enable "active tracing" in settings                │
│  • Lambda: environment variable + permission               │
│  • API Gateway: enable tracing in stage settings           │
│                                                            │
│  ECS Fargate:                                              │
│  • Run X-Ray daemon as a sidecar container                 │
│  • Task definition includes daemon container               │
│                                                            │
│  Elastic Beanstalk:                                        │
│  • Built-in X-Ray support (toggle in config)               │
└──────────────────────────────────────────────────────────┘
```

### Annotations vs Metadata

```
┌────────────────────────┬──────────────────────────────┐
│      ANNOTATIONS        │         METADATA              │
├────────────────────────┼──────────────────────────────┤
│ Key-value pairs        │ Key-value pairs (any object) │
│ INDEXED                │ NOT indexed                   │
│ SEARCHABLE             │ NOT searchable                │
│ FILTERABLE             │ For informational purposes    │
│                         │                               │
│ Use for:                │ Use for:                      │
│ • customer_type:premium │ • Full request/response body  │
│ • order_id: ORD-123    │ • Debug information            │
│ • env: production      │ • Stack traces                 │
│                         │ • Large payloads               │
│                         │                               │
│ Max: 50 per segment    │ No size limit on value         │
│ String/Number/Boolean  │ Any serializable object        │
│                         │                               │
│ "Find all traces where │ "Look at the details of       │
│  customer_type=premium"│  this specific trace"          │
└────────────────────────┴──────────────────────────────┘
```

### Active vs Passive Tracing

```
Active Tracing:
• Service GENERATES the trace (creates Trace ID)
• Lambda/API Gateway: enable "Active Tracing"
• Means: "I will create traces and send them to X-Ray"
• Requires: xray:PutTraceSegments, xray:PutTelemetryRecords

Passive Tracing:
• Service RECEIVES traces from upstream
• Propagates the existing Trace ID
• Means: "If someone sends me a Trace ID, I'll add my data"
• Lower overhead (doesn't create new traces for untraced requests)
```

### X-Ray Groups and Insights

```
┌──────────────────────────────────────────────────────────┐
│  GROUPS:                                                   │
│  • Filter traces by expression                             │
│  • Example group: "responsetime > 5" (slow requests)       │
│  • CloudWatch alarm on group metrics                       │
│  • Notifications when group error rate increases           │
│                                                            │
│  INSIGHTS:                                                 │
│  • Automatically detect anomalies in trace data            │
│  • Identifies services with unusual error rates/latency    │
│  • Root cause analysis suggestions                         │
│  • Requires groups to be configured                        │
└──────────────────────────────────────────────────────────┘
```

### X-Ray vs CloudWatch

```
┌───────────────────────────┬────────────────────────────┐
│        X-Ray               │       CloudWatch            │
├───────────────────────────┼────────────────────────────┤
│ TRACING                   │ METRICS + LOGS              │
│                            │                             │
│ Follow one request        │ Monitor overall health       │
│ across services           │ of one service              │
│                            │                             │
│ "Why was this request     │ "What's the average         │
│  slow?"                   │  latency of this service?"  │
│                            │                             │
│ Root cause analysis       │ Threshold-based alerting     │
│ Service dependency map    │ Dashboard visualization      │
│ Per-request debugging     │ Aggregate metrics            │
│                            │                             │
│ Use TOGETHER:              │                             │
│ CloudWatch detects a       │                             │
│ problem (high latency      │                             │
│ alarm) → X-Ray traces      │                             │
│ tell you WHERE the         │                             │
│ latency is in the chain    │                             │
└───────────────────────────┴────────────────────────────┘
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- **When to use X-Ray** — distributed tracing for microservices, identifying bottlenecks
- **Service map** — visual dependency mapping
- **X-Ray vs CloudWatch** — tracing vs metrics/logs
- **Integration** — Lambda, API Gateway, ECS, Elastic Beanstalk

### DVA-C02 (Developer)
- **X-Ray SDK integration** — instrument code, add annotations/metadata
- **Sampling rules** — reservoir + fixed rate, custom rules
- **Annotations vs Metadata** — indexed/searchable vs not
- **Trace ID propagation** — `X-Amzn-Trace-Id` header
- **Subsegments** — instrument downstream calls (DynamoDB, HTTP, SQL)
- **Active vs Passive tracing** — who creates the trace

### SOA-C02 (SysOps)
- **X-Ray daemon setup** — EC2 (background process), ECS (sidecar container)
- **Service map analysis** — identify slow/erroring services
- **Groups and Insights** — anomaly detection, alerting
- **Sampling rules management** — balance visibility vs cost
- **IAM permissions** — `xray:PutTraceSegments`, `xray:PutTelemetryRecords`

---

## Key Numbers

| Fact | Value |
|------|-------|
| Default sampling | 1/second reservoir + 5% fixed rate |
| Trace ID header | `X-Amzn-Trace-Id` |
| Max annotations per segment | 50 |
| Trace retention | 30 days |
| Daemon UDP port | 2000 |
| Segment document max size | 64 KB |
| Trace max segments | No hard limit (practical: hundreds) |
| Sampling rule priority | Lower number = higher priority |
| X-Ray API batch limit | 5 trace segment documents per call |
| Insights detection | Requires X-Ray groups |

---

## Cheat Sheet

- **X-Ray = distributed tracing.** Follow one request across multiple services.
- **Trace** = end-to-end journey. **Segment** = one service. **Subsegment** = downstream call.
- **Service Map** = visual dependency graph. Color-coded for health (green/yellow/red).
- **Annotations** = indexed, searchable key-value pairs. Use for filtering traces (max 50/segment).
- **Metadata** = non-indexed extra info. Use for debug details, response bodies.
- **Sampling** = default 1/s + 5%. Custom rules for important endpoints (higher sample rate).
- **Daemon** = runs on EC2/ECS, listens on UDP 2000, batches and sends traces to X-Ray API.
- **Lambda/API Gateway** = built-in X-Ray support. Just toggle "active tracing" on. No daemon needed.
- **ECS Fargate** = X-Ray daemon runs as a sidecar container.
- **Trace ID** propagated via `X-Amzn-Trace-Id` HTTP header across services.
- **Active tracing** = service creates traces. **Passive** = service propagates existing traces.
- **X-Ray vs CloudWatch:** X-Ray traces individual requests. CloudWatch monitors aggregate metrics.
- **Use together:** CloudWatch alarm detects high latency → X-Ray shows which service is slow.
- **Groups** = filter traces by expression. Set CloudWatch alarms on group metrics.
- **Insights** = auto-detect anomalies. Requires groups configured.
- **IAM:** `xray:PutTraceSegments` (send traces), `xray:GetTraceSummaries` (read traces).
