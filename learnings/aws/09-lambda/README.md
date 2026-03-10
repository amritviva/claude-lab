# Lambda — The Magic Kitchen

> **In the AWS Country, Lambda is a magic kitchen.** It appears out of thin air when someone orders food, cooks the dish, then vanishes. You pay only for the seconds the stove was on. No rent, no lease, no empty kitchen sitting idle.

---

## ELI10

Imagine a kitchen that doesn't exist until someone places an order. The moment an order comes in — poof — a kitchen appears with a chef, pots, pans, and ingredients. The chef reads the recipe (your code), cooks the dish (runs the function), serves it, and then the kitchen disappears. If 1,000 orders come in at once, 1,000 kitchens appear simultaneously. You only pay for the time each stove was actually on. That's Lambda — the ultimate pay-per-use kitchen.

---

## The Concept

### Anatomy of a Lambda Function

```
┌─────────────────────────────────────────────────┐
│               LAMBDA FUNCTION                    │
│                                                  │
│  ┌──────────────┐   Event (the order slip)       │
│  │   Handler    │ ← "Here's what to cook"        │
│  │  (the recipe)│                                │
│  │              │   Context (kitchen info)        │
│  │  exports.    │ ← "Time left, memory, etc."    │
│  │  handler =   │                                │
│  │  async (     │   Response (the finished dish)  │
│  │    event,    │ → Return to the customer        │
│  │    context   │                                │
│  │  ) => {...}  │                                │
│  └──────────────┘                                │
│                                                  │
│  Runtime: Node.js, Python, Java, Go, .NET, Ruby  │
│  Memory: 128 MB → 10,240 MB (10 GB)             │
│  Timeout: 1 sec → 900 sec (15 min)              │
│  Package: ZIP (50 MB) or Container Image (10 GB) │
│  /tmp storage: 512 MB default, up to 10 GB       │
└─────────────────────────────────────────────────┘
```

**Analogy Mapping:**
| Kitchen Analogy | Lambda Concept |
|---|---|
| Order slip | Event (JSON payload) |
| Recipe | Handler function |
| Kitchen equipment | Execution context (container) |
| Cooking time | Duration (billed per ms) |
| Kitchen size | Memory allocation |
| Stove power | CPU (scales with memory) |
| Shared ingredient shelf | Layer |
| Kitchen setup time | Cold start |
| Reusing yesterday's setup | Warm start |
| Finished dish destination | Destination / return value |

---

### Cold Start vs Warm Start

**Cold Start = Setting up the kitchen from scratch**

When Lambda hasn't been invoked recently, AWS must:
1. Download your code package
2. Start a new execution environment (container)
3. Initialize the runtime (Node.js, Python, etc.)
4. Run your initialization code (outside the handler)

This adds **100-500ms** (or seconds for Java/VPC-attached functions).

**Warm Start = Kitchen already set up**

If another invocation comes soon, Lambda reuses the existing container. No setup — just run the handler. Near-zero overhead.

```
COLD START (first customer of the day):
┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐
│ Download   │→│ Start      │→│ Init code  │→│ Run handler│
│ code       │ │ container  │ │ (outside   │ │ (inside    │
│            │ │            │ │  handler)  │ │  handler)  │
└────────────┘ └────────────┘ └────────────┘ └────────────┘
  ~100-500ms total overhead        ↑               ↑
                              DB connections    Your logic
                              SDK clients       (this is what
                              Global vars       you're billed for)

WARM START (kitchen already set up):
┌────────────┐
│ Run handler│  ← Container reused, init code skipped
│ (inside    │
│  handler)  │
└────────────┘
  Near-zero overhead
```

**Cold start optimization tips:**
- Put initialization code OUTSIDE the handler (DB connections, SDK clients)
- Use smaller deployment packages
- Use Provisioned Concurrency (pre-warm kitchens)
- Avoid Java for latency-sensitive functions (long JVM startup)
- For VPC Lambda: ENI creation no longer causes cold starts (improved in 2019+)

---

### Memory and CPU: Linked Together

Lambda doesn't let you configure CPU directly. CPU power scales linearly with memory.

```
Memory (MB)  │  vCPU Equivalent
─────────────┼──────────────────
128          │  ~0.07 vCPU
512          │  ~0.29 vCPU
1,769        │  1 vCPU          ← MAGIC NUMBER (exam loves this)
3,538        │  2 vCPU
10,240       │  ~6 vCPU
```

**Key insight:** At 1,769 MB, you get exactly 1 full vCPU. Below this, your function is CPU-throttled even if it has enough memory.

**Exam tip:** If a function is CPU-bound (image processing, encryption), increasing memory increases CPU and makes it faster — potentially cheaper despite higher per-ms cost.

---

### Layers: Shared Ingredient Shelf

Layers are ZIP archives of libraries, custom runtimes, or shared code. Instead of packing ingredients into every dish, put them on a shared shelf.

```
┌──────────────────────┐
│   Lambda Function     │
│                       │
│  Your code (handler)  │
│         │             │
│    ┌────┴─────┐       │
│    │ Layer 1  │ ← AWS SDK extensions     │
│    │ Layer 2  │ ← Shared utilities       │
│    │ Layer 3  │ ← ffmpeg binary          │
│    └──────────┘       │
│                       │
│  Max: 5 layers        │
│  Total unzipped: 250 MB (with function code) │
└──────────────────────┘
```

**Key facts:**
- Max **5 layers** per function
- Total unzipped size (code + all layers): **250 MB**
- Layers are versioned (immutable once published)
- Can share layers across functions and accounts
- AWS provides public layers (e.g., AWS Parameters and Secrets Extension)
- Layers extract to `/opt` directory

---

### Concurrency: How Many Kitchens at Once

```
┌──────────────────────────────────────────────────────┐
│                 REGION: us-east-1                      │
│                                                        │
│  Account-level concurrency limit: 1,000                │
│  ┌─────────────────────────────────────────────────┐   │
│  │                                                 │   │
│  │  Function A: Reserved = 100 ← guaranteed        │   │
│  │  Function B: Reserved = 200 ← guaranteed        │   │
│  │  Function C: Unreserved  ← shares remaining 700 │   │
│  │  Function D: Unreserved  ← shares remaining 700 │   │
│  │                                                 │   │
│  │  Unreserved pool: 1000 - 100 - 200 = 700       │   │
│  └─────────────────────────────────────────────────┘   │
│                                                        │
│  Provisioned Concurrency (warm kitchens):              │
│  Function A: 50 pre-warmed → no cold starts            │
│  (Costs $$$ — you pay for idle warm environments)      │
└──────────────────────────────────────────────────────┘
```

**Three types of concurrency:**

| Type | What It Does | Cost |
|---|---|---|
| **Unreserved** | Shared pool, first come first served | Normal Lambda pricing |
| **Reserved** | Guaranteed allocation (also caps the function) | Normal Lambda pricing |
| **Provisioned** | Pre-warmed execution environments | Extra cost for idle warm envs |

**Key facts:**
- Default limit: **1,000** concurrent executions per region (can request increase)
- Reserved concurrency = guarantee AND cap (throttles at that limit)
- Setting reserved to 0 = effectively disables the function
- Provisioned concurrency eliminates cold starts but costs money while idle
- Burst limit: 500-3,000 depending on region (immediate concurrency scaling)

---

### Destinations: Where to Send the Finished Dish

Instead of the function returning directly, route the result (or failure) to another service.

```
                    ┌─────────┐
           success  │  SQS    │
          ┌────────▶│  Queue  │
          │         └─────────┘
┌─────────┤
│ Lambda  │         ┌─────────┐
│ Function│ failure │  SNS    │
│         ├────────▶│  Topic  │
└─────────┘         └─────────┘
          │
          │         ┌─────────┐
          └────────▶│ Lambda  │
                    │ Function│  (another function)
                    └─────────┘
```

**Destination options:** SQS, SNS, Lambda, EventBridge
**Works with:** Asynchronous invocations only
**Preferred over DLQ:** Destinations provide success AND failure routing; DLQ only handles failures

---

### Dead Letter Queue (DLQ)

When an async Lambda invocation fails after all retries (default: 2 retries), the event goes to a DLQ.

- Supported targets: SQS queue or SNS topic
- Only for async invocations
- Must be configured per-function
- DLQ captures the EVENT (input), not the error
- **Destinations are the newer, more flexible replacement** — but DLQ still appears on exams

---

### Event Source Mappings

For stream/queue-based sources, Lambda uses event source mappings to poll the source.

```
┌───────────────┐     ┌───────────────┐     ┌──────────────┐
│  SQS Queue    │     │ Event Source   │     │   Lambda     │
│  Kinesis      │────▶│   Mapping     │────▶│   Function   │
│  DynamoDB     │     │ (Lambda polls) │     │              │
│  Streams      │     └───────────────┘     └──────────────┘
│  MSK / MQ     │
└───────────────┘
```

**Key behaviors by source:**

| Source | Batch Size | Concurrency | On Error |
|---|---|---|---|
| SQS (standard) | Up to 10,000 | Scales automatically | Failed messages return to queue |
| SQS (FIFO) | Up to 10 | 1 per message group | Blocks group until resolved |
| Kinesis | Up to 10,000 | 1 per shard (parallelization factor up to 10) | Retries until success or expiry |
| DynamoDB Streams | Up to 10,000 | 1 per shard | Retries until success or expiry |

**SQS + Lambda gotcha:**
- Lambda deletes messages from SQS after successful processing
- If function fails, message reappears after visibility timeout
- Set visibility timeout to **6x** your Lambda timeout (AWS recommendation)

---

### Versions and Aliases

**Version = Recipe snapshot** (immutable)
```
my-function:1  → code + config frozen at publish time
my-function:2  → newer version
my-function:$LATEST → mutable, always the newest
```

**Alias = Menu name** (mutable pointer)
```
my-function:prod  → points to version 2
my-function:dev   → points to $LATEST
my-function:beta  → weighted: 90% v2, 10% v3 (canary!)
```

**Alias traffic shifting:** Route a percentage of traffic to a new version (canary deployment). Like putting a new dish on the menu for 10% of customers before rolling it out to everyone.

---

### VPC Lambda: Lambda Inside Your Army Base

By default, Lambda runs in AWS's network — it has internet access but can't reach your VPC resources (RDS, ElastiCache, etc.).

**VPC-attached Lambda:**
- Attaches to your VPC subnets via ENI (Elastic Network Interface)
- CAN access VPC resources (private RDS, ElastiCache)
- CANNOT access internet (no public IP in private subnet)
- Needs **NAT Gateway** in a public subnet for internet access

```
┌─────────────────── YOUR VPC ───────────────────────┐
│                                                     │
│  ┌─── Public Subnet ───┐  ┌─── Private Subnet ──┐  │
│  │                      │  │                     │  │
│  │  ┌────────────┐      │  │  ┌──────────────┐   │  │
│  │  │ NAT Gateway│◄─────┼──┼──│    Lambda     │   │  │
│  │  └─────┬──────┘      │  │  │  (VPC mode)   │   │  │
│  │        │             │  │  └──────┬───────┘   │  │
│  │  ┌─────┴──────┐      │  │         │           │  │
│  │  │   IGW      │      │  │  ┌──────┴───────┐   │  │
│  │  └─────┬──────┘      │  │  │    RDS       │   │  │
│  │        │             │  │  │ (private)     │   │  │
│  └────────┼─────────────┘  │  └──────────────┘   │  │
│           │                └─────────────────────┘  │
└───────────┼─────────────────────────────────────────┘
            │
         Internet
```

**Key exam trap:** VPC Lambda loses internet access. If your function calls an external API or AWS services, you need:
- NAT Gateway (for internet) — costs money
- OR VPC Endpoints (for AWS services) — PrivateLink, stays within AWS network

---

### Lambda@Edge and CloudFront Functions

| Feature | Lambda@Edge | CloudFront Functions |
|---|---|---|
| Runtime | Node.js, Python | JavaScript only |
| Memory | Up to 128 MB (viewer) / 10 GB (origin) | 2 MB |
| Timeout | 5s (viewer) / 30s (origin) | 1 ms |
| Triggers | Viewer req/res, Origin req/res | Viewer req/res only |
| Network | Yes | No |
| Cost | Higher | 1/6th the cost |
| Use case | Complex processing | Header manipulation, URL rewrite |

---

### Container Images

Lambda supports container images up to **10 GB** from ECR.

- Must implement the Lambda Runtime API
- Base images provided by AWS for each runtime
- Alternative to ZIP deployment for large dependencies
- Same billing model (per-invocation + duration)

---

### Environment Variables

- Key-value pairs available to your function at runtime
- Max **4 KB** total for all environment variables
- Can encrypt with KMS (encrypted at rest, decrypted at invocation)
- For secrets: use Secrets Manager or Parameter Store (don't store plaintext secrets in env vars)
- AWS provides default env vars: `AWS_REGION`, `AWS_LAMBDA_FUNCTION_NAME`, `AWS_LAMBDA_FUNCTION_MEMORY_SIZE`, etc.

---

## Architecture Diagram: Lambda Ecosystem

```
                    SYNCHRONOUS                    ASYNCHRONOUS
                    (wait for response)            (fire and forget)
                    ┌──────────┐                   ┌──────────┐
                    │ API GW   │                   │ S3 Event │
                    │ ALB      │                   │ SNS      │
                    │ CloudFront│                  │ EventBridge│
                    │ Cognito  │                   │ SES      │
                    │ Alexa    │                   │ CloudWatch│
                    └────┬─────┘                   └────┬─────┘
                         │                              │
                         ▼                              ▼
                    ┌─────────────────────────────────────────┐
                    │              LAMBDA FUNCTION             │
                    │                                         │
                    │  Memory: 128 MB → 10 GB                 │
                    │  Timeout: 1s → 15 min                   │
                    │  /tmp: 512 MB → 10 GB                   │
                    │  Layers: up to 5                         │
                    │  Package: ZIP (50MB) / Container (10GB)  │
                    │                                         │
                    │  Concurrency: 1000/region (default)      │
                    │  Reserved | Provisioned                  │
                    └─────────────┬───────────────────────────┘
                                  │
                    EVENT SOURCE MAPPING
                    (Lambda polls)
                    ┌──────────┐
                    │ SQS      │
                    │ Kinesis  │
                    │ DynamoDB │
                    │ Streams  │
                    │ MSK      │
                    └──────────┘

                    DESTINATIONS (async only)
                    ┌──────────┐     ┌──────────┐
                    │ Success: │     │ Failure: │
                    │ SQS/SNS/ │     │ SQS/SNS/ │
                    │ Lambda/  │     │ Lambda/  │
                    │ EventBr  │     │ EventBr  │
                    └──────────┘     └──────────┘
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- Lambda + API Gateway (serverless architecture pattern)
- VPC Lambda + NAT Gateway for internet access
- Lambda concurrency limits and throttling
- Lambda vs EC2/ECS: when to use which
- Lambda + DynamoDB Streams for event-driven patterns
- Lambda@Edge vs CloudFront Functions
- Cold start mitigation (Provisioned Concurrency)

### DVA-C02 (Developer)
- Handler structure, event/context objects
- Environment variables and secrets management
- Versions and aliases (canary deployment with weighted alias)
- Layers (how to create, share, manage)
- DLQ vs Destinations (when to use which)
- Event source mapping configuration (batch size, error handling)
- /tmp storage for temporary files
- Deployment package size limits

### SOA-C02 (SysOps)
- Concurrency monitoring (CloudWatch ConcurrentExecutions metric)
- Throttling troubleshooting (ThrottleCount metric)
- Memory/duration tuning (use AWS Lambda Power Tuning)
- CloudWatch Logs integration (each invocation logged)
- X-Ray tracing for Lambda
- Reserved vs Provisioned concurrency configuration
- VPC configuration troubleshooting (ENI limits, subnet IPs)

---

## Key Numbers

| Metric | Value |
|---|---|
| Memory range | 128 MB — 10,240 MB (1 MB increments) |
| 1 vCPU equivalent | 1,769 MB memory |
| Max timeout | 900 seconds (15 minutes) |
| Default concurrency (per region) | 1,000 |
| Burst concurrency limit | 500—3,000 (region-dependent) |
| Max layers | 5 per function |
| Deployment package (ZIP) | 50 MB compressed, 250 MB unzipped |
| Container image | Up to 10 GB |
| /tmp storage | 512 MB default, up to 10,240 MB (10 GB) |
| Environment variables | 4 KB total |
| Max async retry attempts | 2 (total 3 invocations) |
| Async event age | Max 6 hours (configurable) |
| Event source mapping batch (SQS) | Up to 10,000 messages |
| Event source mapping batch (Kinesis) | Up to 10,000 records |
| Parallelization factor (Kinesis) | Up to 10 per shard |
| Lambda@Edge viewer timeout | 5 seconds |
| Lambda@Edge origin timeout | 30 seconds |
| CloudFront Functions timeout | 1 ms |
| SQS visibility timeout recommendation | 6x Lambda timeout |
| Cold start typical | 100—500 ms (more for Java/VPC) |

---

## Cheat Sheet

- Lambda = serverless compute. No servers. Pay per invocation + duration.
- Handler = your function. Event = input. Context = metadata.
- Cold start = new container setup (~100-500ms). Warm start = reuse.
- Memory 128MB-10GB. CPU scales with memory. 1,769 MB = 1 vCPU.
- Timeout max 15 minutes. If longer, use Step Functions or ECS.
- 1,000 concurrent executions per region (default). Request increase.
- Reserved = guaranteed + capped. Provisioned = pre-warmed (no cold starts).
- Layers = shared code packages. Max 5 layers. Total 250 MB unzipped.
- Versions are immutable. Aliases are mutable pointers. Weighted alias = canary.
- VPC Lambda: needs NAT Gateway for internet. Use VPC endpoints for AWS services.
- Event source mapping: Lambda polls SQS/Kinesis/DynamoDB Streams.
- SQS: set visibility timeout to 6x Lambda timeout.
- Destinations (success + failure) > DLQ (failure only). Async only.
- Lambda@Edge = full runtime at edge. CloudFront Functions = lightweight JS.
- /tmp = ephemeral storage. 512 MB default, up to 10 GB.
- Container images up to 10 GB (from ECR).
- Env vars: 4 KB total. Use Secrets Manager for secrets.
- Init code runs once per cold start — put DB connections outside handler.
