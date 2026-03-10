# Architecture Scenarios 3: Cost Optimization & Hybrid/Migration

> 10 multi-service architecture scenarios for SAA-C03, DVA-C02, SOA-C02.
> Country analogy throughout. Every scenario = a story inside your AWS Country.

---

## Scenario 1: Reducing Compute Costs with Mixed Purchase Models

### The Scenario

A media processing company runs batch video transcoding 24/7 with unpredictable spikes. Their baseline is 20 instances but peaks hit 80. They're spending $45,000/month on all On-Demand EC2 and the CFO wants a 60% reduction without sacrificing throughput.

### Architecture Diagram

```
                         ┌─────────────────────────────────────────────┐
                         │              Auto Scaling Group             │
                         │          (Mixed Instances Policy)           │
                         │                                             │
                         │  ┌───────────────────────────────────────┐  │
                         │  │  BASE CAPACITY (always on)            │  │
                         │  │                                       │  │
                         │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ │  │
                         │  │  │Reserved │ │Reserved │ │Reserved │ │  │
                         │  │  │Instance │ │Instance │ │Instance │ │  │
                         │  │  │(1yr/3yr)│ │(1yr/3yr)│ │(1yr/3yr)│ │  │
                         │  │  │  ...x20 │ │         │ │         │ │  │
                         │  │  └─────────┘ └─────────┘ └─────────┘ │  │
                         │  └───────────────────────────────────────┘  │
                         │                                             │
                         │  ┌───────────────────────────────────────┐  │
                         │  │  BURST CAPACITY (on demand)           │  │
                         │  │                                       │  │
                         │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ │  │
                         │  │  │  Spot   │ │  Spot   │ │  Spot   │ │  │
                         │  │  │Instance │ │Instance │ │Instance │ │  │
                         │  │  │(70-90%  │ │(diverse │ │(fallback│ │  │
                         │  │  │discount)│ │ types)  │ │  to OD) │ │  │
                         │  │  │  ...x60 │ │         │ │         │ │  │
                         │  │  └─────────┘ └─────────┘ └─────────┘ │  │
                         │  └───────────────────────────────────────┘  │
                         └─────────────┬───────────────────────────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    │                  │                  │
                    ▼                  ▼                  ▼
              ┌──────────┐     ┌────────────┐     ┌────────────┐
              │   SQS    │     │  S3 Input  │     │ S3 Output  │
              │  Queue   │     │  Bucket    │     │  Bucket    │
              │(job buff)│     │ (raw video)│     │(transcoded)│
              └──────────┘     └────────────┘     └────────────┘
                    │
                    ▼
              ┌──────────────┐
              │  Savings     │
              │  Plans       │
              │ (Compute SP  │
              │  covers any  │
              │  instance)   │
              └──────────────┘
```

### Why This Architecture

- **Reserved Instances for baseline**: 20 instances run 24/7 = predictable. 1-year or 3-year RI gives 40-72% discount
- **Spot for burst**: Video transcoding is fault-tolerant (can retry failed jobs). Spot gives 70-90% off. SQS buffers jobs so interrupted work just re-queues
- **Mixed Instances Policy in ASG**: Spread across multiple instance types (c5.xlarge, c5a.xlarge, m5.xlarge) so if one Spot pool is drained, others are available
- **Savings Plans as safety net**: Compute Savings Plans cover any instance family/region/OS, catching whatever Reserved doesn't cover
- **On-Demand fallback**: ASG's mixed policy falls back to On-Demand if Spot capacity is unavailable, ensuring throughput never drops

### Country Analogy

Your country's army needs soldiers. **20 permanent soldiers** are on long-term contracts (Reserved) -- cheap because they committed for years. When a war surge hits, you hire **60 mercenaries** (Spot) at 70% discount -- they might leave on short notice, but your **job board** (SQS) keeps track of unfinished missions so someone else picks it up. The **Savings Plans** is like a bulk discount card for hiring any type of soldier anywhere in the country. The ASG is the **general** who decides how many soldiers are on duty based on the battlefield (CloudWatch metrics).

### Exam Question

**A company processes video files from an SQS queue using EC2 instances. They need 20 instances continuously and up to 60 more during peak hours. Processing is fault-tolerant. Which approach minimizes cost?**

A) Purchase 80 Reserved Instances to cover peak capacity
B) Use On-Demand instances with ASG scaling between 20-80
C) Use Reserved Instances for baseline of 20, Spot Instances with ASG mixed instances policy for burst, SQS for job buffering
D) Use all Spot Instances in a single instance type with ASG

**Correct: C**

- **A is wrong**: You'd pay for 80 RIs but only use 60 of them most of the time. Massive waste.
- **B is wrong**: On-Demand is the most expensive option. No discounts at all.
- **D is wrong**: Single instance type = single Spot pool. If that pool runs out, you get zero capacity. Also, 100% Spot for baseline is risky even with SQS.

### Which Exam Tests This

**SAA-C03** (primary) -- cost optimization pillar, compute purchase options.
**SOA-C02** (secondary) -- managing ASG mixed instance policies, Spot interruption handling.

### Key Trap

Don't confuse **Savings Plans** with **Reserved Instances**. Savings Plans commit to a $/hour spend (flexible across instance types). RIs commit to a specific instance type. The exam loves mixing these up. Also: Spot + SQS is a classic pairing -- if the question mentions "fault-tolerant" or "can be interrupted," Spot is almost always the answer.

---

## Scenario 2: Storage Tiering with S3 Lifecycle Policies

### The Scenario

A healthcare company stores patient imaging data (X-rays, MRIs). New images are accessed frequently for 30 days, occasionally for 90 days, rarely for 1 year, and must be retained for 7 years for compliance. They have 500 TB and growing 10 TB/month. Storage costs are $12,000/month.

### Architecture Diagram

```
     Upload                      S3 Lifecycle Rules (automatic)
       │
       ▼
  ┌──────────┐    30 days    ┌──────────────┐   90 days   ┌───────────┐
  │    S3    │──────────────▶│     S3       │────────────▶│    S3     │
  │ Standard │               │ Standard-IA  │             │  Glacier  │
  │          │               │              │             │ Flexible  │
  │$0.023/GB │               │ $0.0125/GB   │             │$0.0036/GB │
  │          │               │ (46% cheaper)│             │(84% cheap)│
  └──────────┘               └──────────────┘             └─────┬─────┘
                                                                │
                                                           365 days
                                                                │
                                                                ▼
                                                        ┌──────────────┐
                                                        │  S3 Glacier  │
                                                        │ Deep Archive │
                                                        │              │
                                                        │ $0.00099/GB  │
                                                        │ (96% cheaper)│
                                                        │              │
                                                        │ 7yr retain   │
                                                        │ (Object Lock)│
                                                        └──────────────┘

  ┌──────────────────────────────────────────────────────────────────┐
  │              FOR UNKNOWN ACCESS PATTERNS:                       │
  │                                                                  │
  │  ┌──────────────────────┐                                        │
  │  │  S3 Intelligent-     │  Monitors access & auto-moves objects  │
  │  │  Tiering             │  between Frequent and Infrequent tiers │
  │  │                      │  Small monthly monitoring fee/object    │
  │  │  No retrieval fees   │  No lifecycle rules needed             │
  │  │  Auto-optimizes      │  Best when pattern is UNPREDICTABLE    │
  │  └──────────────────────┘                                        │
  └──────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────┐
  │  COMPLIANCE LAYER:                                               │
  │  • S3 Object Lock (Compliance mode) — nobody can delete, not    │
  │    even root account                                             │
  │  • S3 Versioning — required for Object Lock                      │
  │  • Bucket policy — deny s3:DeleteObject                          │
  └──────────────────────────────────────────────────────────────────┘
```

### Why This Architecture

- **Lifecycle rules automate transitions**: No human intervention. Objects move through tiers automatically based on age
- **Standard-IA for 30-90 days**: Cheaper storage, but you pay per retrieval. Perfect for "occasionally accessed"
- **Glacier Flexible for 90-365 days**: 84% cheaper. Retrieval takes minutes to hours. Acceptable for rare access
- **Deep Archive for long-term**: 96% cheaper than Standard. 12-48 hour retrieval. Compliance data you hope you never need
- **Object Lock in Compliance mode**: Even the root account cannot delete objects. Required for HIPAA/legal retention

### Country Analogy

Your country has a **chain of warehouses**. New shipments go to the **city warehouse** (Standard) -- quick access, expensive rent. After 30 days, they move to the **suburban warehouse** (Standard-IA) -- cheaper rent, small fee to retrieve. After 90 days, they go to the **underground bunker** (Glacier) -- very cheap, takes hours to dig out. After a year, they go to the **deep mountain vault** (Deep Archive) -- almost free storage, takes a day to retrieve. The **Intelligent-Tiering** warehouse is a smart facility with robots that automatically shuffle boxes between floors based on how often people ask for them. **Object Lock** is the government seal -- once stamped, nobody can destroy the records, not even the president.

### Exam Question

**A company must store regulatory data for 7 years. Data is accessed frequently for the first month, then rarely. They need to ensure data cannot be deleted by anyone, including the root user. Which solution meets these requirements at the LOWEST cost?**

A) S3 Standard with a bucket policy denying delete actions and lifecycle rules to transition to Glacier Deep Archive after 30 days
B) S3 Standard with lifecycle rules (Standard → Standard-IA at 30 days → Glacier at 90 days → Deep Archive at 365 days) and S3 Object Lock in Compliance mode
C) S3 Intelligent-Tiering with S3 Object Lock in Governance mode
D) S3 One Zone-IA with lifecycle to Glacier and MFA Delete enabled

**Correct: B**

- **A is wrong**: Bucket policies can be changed by root/admin. Not truly immutable. Also jumping straight to Deep Archive at 30 days wastes money if data is still occasionally accessed in months 2-3.
- **C is wrong**: Governance mode allows users with special permissions to delete objects. Only Compliance mode prevents root from deleting. Also Intelligent-Tiering is for unknown patterns -- here the pattern IS known.
- **D is wrong**: One Zone-IA stores in a single AZ. If the AZ fails, data is lost. Unacceptable for regulatory compliance. MFA Delete adds friction but doesn't prevent root from deleting.

### Which Exam Tests This

**SAA-C03** (primary) -- storage class selection, lifecycle policies, cost optimization.
**SOA-C02** (secondary) -- implementing lifecycle rules, monitoring transition metrics.

### Key Trap

**Governance mode vs Compliance mode for Object Lock.** Governance = privileged users CAN override. Compliance = NOBODY can override, not even root. The exam will use words like "no one, including administrators" which means Compliance mode. Also: S3 Intelligent-Tiering is NOT the answer when access patterns ARE known -- it's for when they're unpredictable.

---

## Scenario 3: Serverless Cost Optimization vs Always-On EC2

### The Scenario

A startup runs an API for a mobile app. Traffic is bursty -- 100 requests/second during peak (2 hours/day), near zero overnight and weekends. They're running 4x m5.large EC2 instances 24/7 behind an ALB, costing $800/month. Most of the time, 3 of the 4 instances sit idle.

### Architecture Diagram

```
 BEFORE (always-on):                    AFTER (serverless):

 ┌──────────┐                          ┌──────────────┐
 │  Mobile  │                          │    Mobile    │
 │   App    │                          │     App      │
 └────┬─────┘                          └──────┬───────┘
      │                                       │
      ▼                                       ▼
 ┌──────────┐                          ┌──────────────┐
 │   ALB    │                          │ API Gateway  │
 │($18/mo + │                          │              │
 │ LCU cost)│                          │ • REST API   │
 └────┬─────┘                          │ • Caching    │◄─── Cache: $15/mo
      │                                │   (0.5 GB)   │     (saves Lambda
      ├────┬────┬────┐                 │ • Throttling │      invocations)
      ▼    ▼    ▼    ▼                 │ • API Keys   │
 ┌────┐┌────┐┌────┐┌────┐             └──────┬───────┘
 │EC2 ││EC2 ││EC2 ││EC2 │                    │
 │idle││idle││idle││busy│                    ▼
 │ 😴 ││ 😴 ││ 😴 ││ 🏃 │             ┌──────────────┐
 └────┘└────┘└────┘└────┘             │   Lambda     │
      │                                │              │
      ▼                                │ • 128-512 MB │
 ┌──────────┐                          │ • Auto-scale │
 │   RDS    │                          │ • Pay per ms │
 │(always on│                          │ • 0 cost     │
 │ $140/mo) │                          │   when idle  │
 └──────────┘                          └──────┬───────┘
                                              │
 Cost: ~$800/mo                               ▼
 Utilization: ~15%                     ┌──────────────┐
                                       │  DynamoDB    │
                                       │  On-Demand   │
                                       │              │
                                       │ • Pay per    │
                                       │   request    │
                                       │ • 0 cost     │
                                       │   when idle  │
                                       └──────────────┘
                                              │
                                              ▼
                                       ┌──────────────┐
                                       │  CloudFront  │
                                       │ (static +    │
                                       │  API cache)  │
                                       └──────────────┘

                                       Cost: ~$50-120/mo
                                       Utilization: 100%
                                       (pay only for use)
```

### Why This Architecture

- **API Gateway replaces ALB**: Built-in throttling, API keys, request validation. Caching at the gateway layer means many requests never hit Lambda at all
- **Lambda replaces EC2**: Zero cost when idle. Automatic scaling to thousands of concurrent requests. No servers to patch
- **DynamoDB On-Demand replaces RDS**: No idle cost. Pay per read/write. Perfect for unpredictable traffic patterns
- **CloudFront caches responses**: Reduces API Gateway + Lambda invocations for repeated requests (user profiles, product listings)
- **API Gateway caching**: Stage-level cache ($15/mo for 0.5 GB) prevents redundant Lambda invocations for identical requests within TTL

### Country Analogy

The old army had **4 permanent soldiers** (EC2) standing guard 24/7, even when nobody visited. You paid their salary whether they worked or not. The new system uses a **magic kitchen** (Lambda) -- chefs only appear when an order arrives, cook instantly, then vanish. No orders = no cost. The **API Gateway** is the front desk that takes orders and remembers repeat orders (caching) so the kitchen doesn't re-cook the same meal. **DynamoDB On-Demand** is a warehouse that charges per box retrieved, not per square foot of floor space. **CloudFront** is the post office network that keeps copies of popular items at every local branch.

### Exam Question

**A startup's mobile API has highly variable traffic with long idle periods. They currently run EC2 instances behind an ALB with an RDS database. They want to minimize costs while maintaining low latency during traffic spikes. Which architecture achieves this?**

A) Use smaller EC2 instances with ASG (min=1, max=10) and Aurora Serverless
B) API Gateway with Lambda and DynamoDB On-Demand, plus CloudFront for caching
C) Use Spot Instances behind the ALB with RDS read replicas
D) API Gateway with Lambda and RDS Proxy to the existing RDS database

**Correct: B**

- **A is wrong**: Even min=1 EC2 means you always pay for 1 instance. Aurora Serverless helps but still has minimum capacity charges. Better than current but not cheapest.
- **C is wrong**: Spot Instances can be interrupted (bad for API serving). RDS read replicas add cost, not reduce it. Doesn't address the core "paying for idle" problem.
- **D is wrong**: Keeping RDS means you still pay $140/mo for an always-on database even during zero-traffic periods. RDS Proxy adds more cost. DynamoDB On-Demand with zero idle cost is better for this pattern.

### Which Exam Tests This

**SAA-C03** (primary) -- serverless architecture, cost optimization.
**DVA-C02** (secondary) -- Lambda configuration, API Gateway caching, DynamoDB capacity modes.

### Key Trap

**API Gateway caching is NOT the same as CloudFront caching.** API Gateway cache is per-stage, costs money ($15-$250/mo), and caches at the API layer. CloudFront caches at the edge (CDN layer). You can use both together. Also: DynamoDB On-Demand vs Provisioned -- On-Demand is cheaper for unpredictable/spiky workloads, Provisioned is cheaper for steady traffic. The exam will describe the traffic pattern to hint which mode.

---

## Scenario 4: Database Cost Optimization with Aurora Serverless and Caching

### The Scenario

An e-commerce platform has a MySQL database handling product catalog reads (90% of queries), order writes (10%), and a reporting dashboard. Traffic varies from 50 connections at night to 2,000 during flash sales. They run a db.r5.2xlarge ($1,200/mo) that's oversized 80% of the time but necessary for peak.

### Architecture Diagram

```
                              ┌──────────────────────┐
                              │     Application      │
                              │       Layer          │
                              └──────────┬───────────┘
                                         │
                    ┌────────────────────┼────────────────────┐
                    │                    │                    │
                    ▼                    ▼                    ▼
           ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
           │ ElastiCache  │    │    Aurora     │    │    Aurora     │
           │   Redis      │    │  Serverless  │    │    Reader     │
           │              │    │    v2        │    │  (dedicated)   │
           │ HOT READS:   │    │              │    │               │
           │ • Product    │    │  WRITES:     │    │  REPORTING:   │
           │   catalog    │    │ • Orders     │    │ • Dashboard   │
           │ • Categories │    │ • Inventory  │    │ • Analytics   │
           │ • Prices     │    │ • Users      │    │ • CSV exports │
           │              │    │              │    │               │
           │ Cache-aside  │    │ Auto-scales  │    │ Isolated from │
           │ pattern      │    │ 0.5 - 128    │    │ production    │
           │              │    │ ACUs         │    │ reads/writes  │
           │ TTL: 5 min   │    │              │    │               │
           │ Hit rate: 95%│    │ Pay per ACU- │    │ Can be smaller│
           │              │    │ second       │    │ instance class│
           └──────┬───────┘    └──────┬───────┘    └──────┬───────┘
                  │                    │                    │
                  │              ┌─────┴─────┐             │
                  │              │  Aurora    │             │
                  │              │ Storage    │◄────────────┘
                  │              │ (shared)   │
                  │              │ Auto-grow  │
                  │              │ $0.10/GB   │
                  │              └────────────┘
                  │
                  ▼
          Cache Miss? ──▶ Read from Aurora ──▶ Store in Cache

   ┌──────────────────────────────────────────────────────────────┐
   │  COST BREAKDOWN:                                             │
   │                                                               │
   │  Before: db.r5.2xlarge = $1,200/mo (always on, oversized)   │
   │                                                               │
   │  After:                                                       │
   │    Aurora Serverless v2:  ~$200-400/mo (scales with demand)  │
   │    ElastiCache (t3.med):  ~$50/mo  (offloads 90% reads)     │
   │    Reader for reporting:  ~$100/mo  (small, isolated)        │
   │    Total:                 ~$350-550/mo  (55-70% savings)     │
   └──────────────────────────────────────────────────────────────┘
```

### Why This Architecture

- **Aurora Serverless v2 for variable workload**: Scales from 0.5 to 128 ACUs in seconds. Pay per ACU-second. No more paying for peak capacity 24/7
- **ElastiCache Redis for hot reads**: 95% of product catalog reads hit cache (sub-millisecond). Reduces database load by 90%, meaning Aurora needs fewer ACUs
- **Read replica for reporting**: Dashboard queries are heavy (full table scans, aggregations). Isolating them to a reader prevents impact on production writes
- **Cache-aside pattern**: Application checks cache first, reads from DB on miss, writes result to cache. Simple and effective
- **TTL on cache entries**: 5-minute TTL ensures prices/inventory are eventually consistent without manual cache invalidation

### Country Analogy

Your country's main **kitchen** (RDS) was a massive permanent facility built to handle the busiest day of the year -- but 80% of the time, most ovens sat cold. New plan: replace it with a **magic kitchen** (Aurora Serverless v2) that grows and shrinks with demand. Build a **quick-service counter** (ElastiCache) at the front -- 90% of customers want the same popular dishes, so you keep those ready-made in a hot display. No need to cook from scratch each time. For the **bean-counters** (reporting dashboard) who run complex inventory audits, give them their own small kitchen (read replica) so they don't slow down the lunch rush.

### Exam Question

**An e-commerce application experiences highly variable database traffic. Product catalog queries make up 90% of database reads. Flash sales cause 40x traffic spikes. A reporting dashboard runs complex queries. How should a solutions architect minimize database costs while maintaining performance?**

A) Use Aurora Provisioned with the largest instance class and add read replicas during sales
B) Use Aurora Serverless v2 for writes, ElastiCache for product catalog reads, and a read replica for reporting
C) Use DynamoDB with DAX for caching and DynamoDB Streams for reporting
D) Use Aurora Serverless v2 for everything including reporting queries

**Correct: B**

- **A is wrong**: Provisioned = fixed cost. "Largest instance class" is the opposite of cost optimization. Adding read replicas reactively during sales is slow (takes minutes to provision).
- **C is wrong**: Migrating from MySQL to DynamoDB is a major redesign (not just cost optimization). E-commerce with complex product relationships and transactions suits relational databases better.
- **D is wrong**: Reporting queries (full scans, aggregations) on the same Serverless instance will spike ACUs and increase cost. Also slows down production workload. Isolating reporting to a reader is standard practice.

### Which Exam Tests This

**SAA-C03** (primary) -- database selection, caching strategies, cost optimization.
**SOA-C02** (secondary) -- ElastiCache monitoring, Aurora ACU scaling metrics.

### Key Trap

**Aurora Serverless v2 does NOT scale to zero.** Minimum is 0.5 ACU (about $43/mo). If you need true zero-cost-when-idle, you need Aurora Serverless v1 (which CAN pause to 0 but has a 25-second cold start). The exam distinguishes between v1 and v2 carefully. Also: ElastiCache is NOT a database replacement -- it's a cache. Data can be evicted. Always have the database as the source of truth.

---

## Scenario 5: Network Cost Optimization with VPC Endpoints and CloudFront

### The Scenario

A data analytics company processes files in S3, writes results to DynamoDB, and serves dashboards via an API. Their EC2 instances in private subnets access S3 and DynamoDB through a NAT Gateway, costing $1,500/month in NAT Gateway data processing fees alone. They also serve 2 TB/month of dashboard API responses.

### Architecture Diagram

```
   BEFORE (expensive):                 AFTER (optimized):

   ┌─────────────┐                    ┌─────────────┐
   │  Private     │                    │  Private     │
   │  Subnet      │                    │  Subnet      │
   │  ┌────────┐  │                    │  ┌────────┐  │
   │  │  EC2   │  │                    │  │  EC2   │  │
   │  └───┬────┘  │                    │  └───┬────┘  │
   │      │       │                    │      │       │
   └──────┼───────┘                    └──────┼───────┘
          │                                   │
          ▼                              ┌────┴────────────────────┐
   ┌──────────────┐                     │                          │
   │  NAT Gateway │                     ├─────────┐    ┌──────────┤
   │              │                     │         │    │          │
   │ $0.045/GB   │                     │         ▼    ▼          │
   │ processed    │                     │   ┌────────┐ ┌───────┐ │
   │              │                     │   │Gateway │ │Gateway│ │
   │ $1,500/mo!  │                     │   │Endpoint│ │Endpt  │ │
   └──────┬───────┘                     │   │(S3)   │ │(Dynamo│ │
          │                             │   │       │ │  DB)  │ │
          ▼                             │   │ FREE! │ │ FREE! │ │
   ┌──────────────┐                     │   └───┬───┘ └───┬───┘ │
   │   Internet   │                     │       │         │     │
   │   Gateway    │                     │       ▼         ▼     │
   └──────┬───────┘                     │    ┌─────┐  ┌──────┐  │
          │                             │    │ S3  │  │Dynamo│  │
          ├──────┐                      │    │     │  │  DB  │  │
          ▼      ▼                      │    └─────┘  └──────┘  │
       ┌────┐ ┌──────┐                 │                        │
       │ S3 │ │Dynamo│                 │  NAT GW only for:      │
       │    │ │  DB  │                 │  external API calls     │
       └────┘ └──────┘                 │  (small traffic)       │
                                        └────────┬──────────────┘
                                                 │
          ┌──────────────────────────────────────┘
          │
   ┌──────┴──────────────────────────────────────────────┐
   │  API serving layer:                                  │
   │                                                      │
   │  ┌───────────┐    ┌──────────┐    ┌──────────────┐  │
   │  │CloudFront │───▶│   ALB    │───▶│  EC2 / API   │  │
   │  │           │    │(regional)│    │              │  │
   │  │ Caches    │    └──────────┘    └──────────────┘  │
   │  │ responses │                                      │
   │  │ 2TB→200GB │    Data transfer OUT savings:        │
   │  │ origin    │    Before: 2TB x $0.09  = $180/mo   │
   │  │ requests  │    After:  2TB x $0.085 = $170/mo   │
   │  │           │    + 90% cache hit = only 200GB      │
   │  │           │      from origin = massive savings   │
   │  └───────────┘                                      │
   └─────────────────────────────────────────────────────┘

   ┌─────────────────────────────────────────────────────┐
   │  ALSO: Same-AZ placement                            │
   │                                                      │
   │  EC2 ←→ RDS in SAME AZ = free data transfer         │
   │  EC2 ←→ RDS in DIFF AZ = $0.01/GB each way          │
   │                                                      │
   │  PrivateLink (Interface Endpoints):                  │
   │  For other AWS services (SQS, SNS, KMS, etc.)       │
   │  $0.01/GB vs $0.045/GB through NAT = 78% savings    │
   │  BUT: $7.20/mo per endpoint per AZ (fixed cost)      │
   │  Only worth it if traffic > ~200 GB/mo               │
   └─────────────────────────────────────────────────────┘
```

### Why This Architecture

- **Gateway Endpoints for S3 and DynamoDB are FREE**: No data processing charges, no hourly charges. Traffic stays on AWS backbone. This alone eliminates most of the $1,500/mo NAT bill
- **NAT Gateway only for external traffic**: Keep NAT for internet-bound traffic (external APIs, software updates). S3/DynamoDB traffic bypasses it entirely
- **CloudFront for API responses**: 90% cache hit ratio means 2 TB of client requests generates only 200 GB of origin traffic. Lower data transfer cost + faster for users
- **Same-AZ placement for EC2-to-RDS**: Cross-AZ data transfer costs $0.01/GB each way. Placing compute and database in the same AZ eliminates this (use Multi-AZ RDS for HA, but the app connects to primary in its AZ)
- **Interface Endpoints (PrivateLink) for high-traffic services**: SQS, KMS, SNS -- $0.01/GB through PrivateLink vs $0.045/GB through NAT. Worth it when traffic exceeds ~200 GB/month

### Country Analogy

Previously, every time soldiers (EC2) needed to access the warehouse (S3) or buildings (DynamoDB), they had to exit through the **toll gate** (NAT Gateway) and drive on the public highway -- paying toll fees per truckload. New plan: build **private tunnels** (Gateway Endpoints) directly from the army base to the warehouse and buildings. Tunnels are free to use and traffic never leaves the base. The toll gate stays open only for when soldiers need to contact foreign countries (external APIs). For the country's postal service (CloudFront), popular letters are pre-copied to every local post office so the central sorting facility handles 90% less mail.

### Exam Question

**EC2 instances in a private subnet access S3 and DynamoDB through a NAT Gateway, incurring $1,500/month in data processing charges. How should a solutions architect reduce these costs?**

A) Move EC2 instances to a public subnet and access S3/DynamoDB directly via the internet gateway
B) Create VPC Gateway Endpoints for S3 and DynamoDB, and update route tables
C) Create VPC Interface Endpoints (PrivateLink) for S3 and DynamoDB
D) Use S3 Transfer Acceleration and DynamoDB Accelerator (DAX) to reduce data transfer

**Correct: B**

- **A is wrong**: Moving to public subnets is a security downgrade. EC2 gets public IPs, exposed to the internet. Never trade security for cost.
- **C is wrong**: Interface Endpoints (PrivateLink) for S3 cost $7.20/AZ/month + $0.01/GB. Gateway Endpoints are FREE. For S3 and DynamoDB specifically, Gateway Endpoints are always the right answer.
- **D is wrong**: S3 Transfer Acceleration speeds up uploads over long distances. DAX is a DynamoDB cache. Neither addresses NAT Gateway costs. Completely different problem.

### Which Exam Tests This

**SAA-C03** (primary) -- VPC endpoints, data transfer costs, network architecture.
**SOA-C02** (secondary) -- monitoring NAT Gateway costs, configuring endpoints.
**DVA-C02** (occasional) -- SDK configuration to use VPC endpoints.

### Key Trap

**Gateway Endpoints vs Interface Endpoints.** Only S3 and DynamoDB have Gateway Endpoints (free, route-table based). Everything else uses Interface Endpoints / PrivateLink (paid, ENI-based). The exam WILL test this distinction. If the question says "S3 or DynamoDB" + "reduce cost" = Gateway Endpoint. If it says "SQS, SNS, KMS, etc." = Interface Endpoint. Also: Gateway Endpoints only work within the same Region.

---

## Scenario 6: Hybrid Connectivity with Direct Connect, VPN Backup, and Transit Gateway

### The Scenario

A financial services company has 3 VPCs (Production, Development, Shared Services) and an on-premises data center. They need a dedicated, low-latency, high-bandwidth (10 Gbps) connection for trading data, with automatic failover. On-prem must reach all 3 VPCs. Regulatory requirements mandate that traffic must not traverse the public internet.

### Architecture Diagram

```
   ON-PREMISES DATA CENTER                          AWS CLOUD
   ┌─────────────────────┐
   │                     │
   │  ┌───────────────┐  │    ┌─────────────────────────────────────────────┐
   │  │  Core Router  │──┼───▶│  Direct Connect Location                   │
   │  │               │  │    │  (co-location facility)                     │
   │  └───────┬───────┘  │    │                                             │
   │          │          │    │  ┌────────────────────────────────────────┐  │
   │          │          │    │  │  10 Gbps Dedicated Connection         │  │
   │          │          │    │  │  (PRIMARY — physical cross-connect)   │  │
   │          │          │    │  │                                        │  │
   │          │          │    │  │  ┌─────────────┐  ┌─────────────────┐ │  │
   │          │          │    │  │  │Private VIF  │  │Private VIF      │ │  │
   │          │          │    │  │  │(to Transit  │  │(backup to       │ │  │
   │          │          │    │  │  │ Gateway)    │  │ 2nd DX loc.)    │ │  │
   │          │          │    │  │  └──────┬──────┘  └────────┬────────┘ │  │
   │          │          │    │  └─────────┼──────────────────┼──────────┘  │
   │          │          │    └────────────┼──────────────────┼─────────────┘
   │          │          │                 │                  │
   │          │          │                 ▼                  │
   │  ┌───────┴───────┐  │    ┌────────────────────────┐     │
   │  │  VPN Gateway  │──┼───▶│    Transit Gateway     │◄────┘
   │  │  (backup)     │  │    │                        │
   │  │               │  │    │  Hub for ALL VPC       │
   │  │  Site-to-Site │  │    │  connectivity          │
   │  │  VPN over     │  │    │                        │
   │  │  internet     │  │    └────────┬───────────────┘
   │  │  (encrypted)  │  │             │
   │  └───────────────┘  │        ┌────┴────┬──────────┐
   │                     │        │         │          │
   │  Trading Servers    │        ▼         ▼          ▼
   │  File Servers       │  ┌──────────┐┌─────────┐┌──────────┐
   │  Active Directory   │  │Production││   Dev   ││ Shared   │
   │                     │  │  VPC     ││   VPC   ││ Services │
   └─────────────────────┘  │          ││         ││   VPC    │
                            │10.1.0.0/ ││10.2.0.0/││10.3.0.0/ │
                            │  16      ││  16     ││  16      │
                            │          ││         ││          │
                            │• Trading ││• Dev    ││• AD      │
                            │  engines ││  servers││  Connector│
                            │• RDS     ││• CI/CD  ││• DNS     │
                            │• S3 GW EP││         ││• Logging │
                            └──────────┘└─────────┘└──────────┘

   ┌─────────────────────────────────────────────────────────────┐
   │  FAILOVER PATH:                                             │
   │                                                              │
   │  Normal:  On-Prem ══DX══▶ Transit GW ──▶ VPCs              │
   │                    (10 Gbps, <5ms latency)                  │
   │                                                              │
   │  Failover: On-Prem ──VPN──▶ Transit GW ──▶ VPCs            │
   │                    (encrypted over internet, ~50ms)          │
   │                                                              │
   │  BGP routing: DX route has higher preference (shorter AS    │
   │  path). If DX goes down, BGP auto-switches to VPN path.    │
   │  No manual intervention.                                    │
   └─────────────────────────────────────────────────────────────┘
```

### Why This Architecture

- **Direct Connect (10 Gbps dedicated)**: Physical cross-connect provides consistent latency (<5ms), required for real-time trading. Traffic never touches the public internet
- **Site-to-Site VPN as backup**: If Direct Connect fails, traffic automatically routes over encrypted VPN tunnel through the internet. BGP handles the failover via route preference
- **Transit Gateway as the hub**: Without TGW, you'd need 3 separate VPN connections + 3 DX virtual interfaces (one per VPC). TGW centralizes: one DX attachment, one VPN attachment, routes to all VPCs
- **Private Virtual Interface (VIF)**: Connects DX to private AWS resources (VPCs via TGW). Not a public VIF (for AWS public services) or transit VIF
- **Second DX at different location for HA**: If the physical facility burns down, second DX at another co-location provides resilience. Both connect to same TGW

### Country Analogy

Your company is in a neighboring country and needs a dedicated highway to your AWS country. **Direct Connect** is a **private highway** -- 10 lanes wide, no traffic lights, guaranteed speed. It goes through a **border checkpoint** (DX location) but never uses public roads. The **Site-to-Site VPN** is a **backup dirt road through the mountains** -- slower and bumpier (internet), but encrypted (armored trucks) and always available. **Transit Gateway** is the **central roundabout** inside your AWS country -- instead of building 3 separate highways to Production Town, Dev Village, and Shared Services City, everything goes through one roundabout that routes traffic to the right destination. **BGP** is the **GPS navigation** that automatically re-routes when the highway is blocked.

### Exam Question

**A company has 3 VPCs and an on-premises data center. They need a dedicated 10 Gbps connection that doesn't traverse the public internet, with automatic failover, and on-premises systems must reach all 3 VPCs. Which architecture meets these requirements?**

A) Direct Connect with 3 private VIFs (one per VPC) and 3 Site-to-Site VPN connections as backup
B) Direct Connect with a transit VIF to Transit Gateway, Site-to-Site VPN to Transit Gateway as backup, all 3 VPCs attached to Transit Gateway
C) 3 Site-to-Site VPN connections (one per VPC) using AWS VPN CloudHub
D) Direct Connect with public VIF and VPC peering between all 3 VPCs

**Correct: B**

- **A is wrong**: Works but doesn't scale. 3 VIFs + 3 VPNs = operational complexity. Transit Gateway simplifies this to 1 DX attachment + 1 VPN attachment. Also, Direct Connect supports max 50 VIFs per connection -- but the management overhead is the issue.
- **C is wrong**: VPN-only doesn't meet "dedicated connection" or "doesn't traverse public internet" requirements. VPN always goes over the internet.
- **D is wrong**: Public VIF connects to AWS public endpoints (S3, DynamoDB public IPs), not to VPCs. VPC peering creates a full mesh (3 peering connections for 3 VPCs) and doesn't help with on-prem connectivity at all.

### Which Exam Tests This

**SAA-C03** (primary) -- hybrid networking, Direct Connect, Transit Gateway.
**SOA-C02** (secondary) -- monitoring DX connections, failover testing, BGP route management.

### Key Trap

**Private VIF vs Transit VIF vs Public VIF.** Private VIF connects DX to a single VPC's VGW. Transit VIF connects DX to Transit Gateway (and thus all attached VPCs). Public VIF connects to AWS public service endpoints. The exam tests whether you know which VIF type to use. Also: **Direct Connect alone is NOT encrypted.** If you need encryption over DX, you must run a VPN tunnel on top of the DX connection (VPN over DX). The "dedicated connection" just means it's private and consistent -- not encrypted.

---

## Scenario 7: Database Migration with DMS, SCT, and Minimal Downtime Cutover

### The Scenario

A retail company is migrating from an on-premises Oracle database (2 TB, 500+ stored procedures) to Amazon Aurora PostgreSQL. They can tolerate a maximum of 30 minutes of downtime during cutover. The Oracle database uses features not available in PostgreSQL (Oracle-specific PL/SQL, materialized views with refresh groups).

### Architecture Diagram

```
   PHASE 1: SCHEMA CONVERSION (weeks before migration)
   ┌─────────────────────────────────────────────────────────┐
   │                                                          │
   │  ┌──────────────┐         ┌──────────────────────────┐  │
   │  │   Oracle DB  │────────▶│  Schema Conversion Tool  │  │
   │  │  (on-prem)   │         │       (SCT)              │  │
   │  │              │         │                          │  │
   │  │  • Tables    │         │  Converts:               │  │
   │  │  • Indexes   │         │  • DDL → PostgreSQL DDL  │  │
   │  │  • Views     │         │  • PL/SQL → PL/pgSQL     │  │
   │  │  • Stored    │         │  • Data types             │  │
   │  │    Procs     │         │                          │  │
   │  └──────────────┘         │  Flags:                   │  │
   │                           │  • Items it CAN'T auto-  │  │
   │                           │    convert (manual fix)   │  │
   │                           │  • Oracle-specific stuff  │  │
   │                           └────────────┬─────────────┘  │
   │                                        │                │
   │                                        ▼                │
   │                           ┌──────────────────────────┐  │
   │                           │  Aurora PostgreSQL       │  │
   │                           │  (empty, schema only)    │  │
   │                           └──────────────────────────┘  │
   └─────────────────────────────────────────────────────────┘

   PHASE 2: FULL LOAD + CDC (days/weeks)
   ┌─────────────────────────────────────────────────────────┐
   │                                                          │
   │  ┌──────────────┐    ┌──────────────┐    ┌───────────┐  │
   │  │   Oracle DB  │───▶│     DMS      │───▶│  Aurora   │  │
   │  │  (on-prem)   │    │  Replication │    │PostgreSQL │  │
   │  │              │    │  Instance    │    │           │  │
   │  │  Still       │    │              │    │  Multi-AZ │  │
   │  │  serving     │    │  1. Full Load│    │           │  │
   │  │  production  │    │     (bulk    │    │  Target   │  │
   │  │  traffic     │    │      copy)   │    │  catches  │  │
   │  │              │    │              │    │  up to    │  │
   │  │  Changes     │    │  2. CDC      │    │  source   │  │
   │  │  continue    │    │  (Change Data│    │           │  │
   │  │  happening   │    │   Capture -  │    │           │  │
   │  │              │    │   ongoing    │    │           │  │
   │  │              │    │   replication│    │           │  │
   │  └──────────────┘    │   of changes)│    └───────────┘  │
   │                      └──────────────┘                    │
   └─────────────────────────────────────────────────────────┘

   PHASE 3: CUTOVER (<30 min downtime)
   ┌─────────────────────────────────────────────────────────┐
   │                                                          │
   │  Step 1: Stop application writes to Oracle               │
   │          (app maintenance mode)                          │
   │                                                          │
   │  Step 2: Wait for DMS CDC to drain                       │
   │          (replication lag → 0)                            │
   │                                                          │
   │  Step 3: Verify data integrity                           │
   │          (DMS validation task / row counts / checksums)   │
   │                                                          │
   │  Step 4: Point application to Aurora PostgreSQL          │
   │          (DNS switch / connection string change)          │
   │                                                          │
   │  Step 5: Verify application works                        │
   │          (smoke tests)                                    │
   │                                                          │
   │  Step 6: Decommission Oracle (days later)                │
   │          (keep as rollback option for 1-2 weeks)          │
   │                                                          │
   │  Total downtime: ~15-30 minutes (steps 1-5)              │
   └─────────────────────────────────────────────────────────┘

   ┌─────────────────────────────────────────────────────────┐
   │  KEY COMPONENTS:                                         │
   │                                                          │
   │  SCT = Schema Conversion Tool (runs locally, one-time)   │
   │  DMS = Database Migration Service (runs in AWS, ongoing) │
   │  CDC = Change Data Capture (captures ongoing changes)     │
   │                                                          │
   │  This is a HETEROGENEOUS migration:                      │
   │  Oracle (source) → PostgreSQL (target) = different engines│
   │  Requires BOTH SCT (schema) + DMS (data)                 │
   │                                                          │
   │  HOMOGENEOUS would be:                                    │
   │  MySQL → Aurora MySQL = same engine family                │
   │  Only needs DMS (no SCT needed)                           │
   └─────────────────────────────────────────────────────────┘
```

### Why This Architecture

- **SCT first**: Oracle PL/SQL doesn't map 1:1 to PostgreSQL PL/pgSQL. SCT auto-converts what it can and flags what needs manual rewriting. Do this weeks in advance
- **DMS Full Load + CDC**: Full Load copies all 2 TB of data. CDC then keeps the target in sync by capturing ongoing changes from Oracle's redo logs. This means Oracle stays live during migration
- **Minimal downtime cutover**: Because CDC keeps target near-realtime, the actual switchover only requires draining the last few seconds of changes. 30-minute window is achievable
- **Multi-AZ Aurora target**: Production-grade from day one. If the primary AZ fails during cutover, Aurora fails over automatically
- **DMS validation task**: Compares source and target row-by-row to catch any data integrity issues before cutover

### Country Analogy

You're moving your entire government (Oracle) from one country to another (Aurora PostgreSQL). First, a **translator** (SCT) converts all your laws and procedures from the old country's language to the new one. Some laws translate perfectly; others need a lawyer to rewrite manually. Then, a **moving company** (DMS) starts shipping all the filing cabinets (Full Load). While the old government is still operating and creating new documents, a **courier service** (CDC) continuously shuttles new paperwork to the new country. On cutover day, you say "the old government office is closed for 30 minutes" -- the courier delivers the last batch, you verify nothing's missing, unlock the new office, and citizens now go there instead.

### Exam Question

**A company is migrating a 2 TB Oracle database with complex stored procedures to Aurora PostgreSQL. They require less than 30 minutes of downtime. Which approach should they use?**

A) Use AWS DMS with full load only, stop the Oracle database, then start the Aurora database
B) Use AWS SCT to convert the schema, then AWS DMS with full load and CDC for ongoing replication, and cutover when replication lag reaches zero
C) Export the Oracle database to S3 as CSV files, then import into Aurora PostgreSQL using the COPY command
D) Use AWS DMS for both schema conversion and data migration with full load and CDC

**Correct: B**

- **A is wrong**: Full load only means you must stop Oracle for the entire duration of the data copy (hours for 2 TB). That's way more than 30 minutes.
- **C is wrong**: CSV export/import doesn't handle schema conversion (stored procedures, data types). Also requires Oracle to be offline during export. No CDC capability.
- **D is wrong**: DMS does NOT convert stored procedures or complex schema objects. DMS handles data migration + basic table creation. SCT is required for heterogeneous schema conversion (Oracle-specific PL/SQL to PL/pgSQL).

### Which Exam Tests This

**SAA-C03** (primary) -- migration strategies, DMS + SCT, minimal downtime patterns.
**SOA-C02** (secondary) -- monitoring DMS replication tasks, validation, CloudWatch metrics for replication lag.
**DVA-C02** (occasional) -- understanding CDC for event-driven patterns.

### Key Trap

**DMS is for DATA. SCT is for SCHEMA.** DMS can create basic tables at the target, but it cannot convert stored procedures, triggers, or database-specific syntax. If the question mentions "stored procedures" or "heterogeneous migration" (different engine types), SCT is required. Also: **Homogeneous migrations (MySQL to Aurora MySQL) don't need SCT** -- just DMS. The exam tests whether you know when SCT is needed.

---

## Scenario 8: Lift-and-Shift to Containers (EC2 to ECS Fargate)

### The Scenario

A company runs 6 microservices on EC2 instances. Each service runs on its own t3.medium instance (6 total). They want to containerize for better resource utilization, faster deployments, and eliminate server management. They don't have Kubernetes expertise and want AWS to manage the infrastructure.

### Architecture Diagram

```
   BEFORE:                            AFTER:
   6x EC2 instances                   ECS Fargate (serverless containers)
   each at 15-30% CPU

   ┌────────────────────┐             ┌──────────────────────────────────────┐
   │  EC2 (t3.medium)   │             │              ALB                     │
   │  ┌──────────────┐  │             │  ┌──────┐ ┌──────┐ ┌──────────────┐ │
   │  │ User Service │  │             │  │ /api/│ │ /api/│ │  /api/       │ │
   │  └──────────────┘  │             │  │users │ │orders│ │  products    │ │
   │  EC2 (t3.medium)   │             │  └──┬───┘ └──┬───┘ └──────┬──────┘ │
   │  ┌──────────────┐  │             │     │        │             │        │
   │  │Order Service │  │             └─────┼────────┼─────────────┼────────┘
   │  └──────────────┘  │                   │        │             │
   │  EC2 (t3.medium)   │                   ▼        ▼             ▼
   │  ┌──────────────┐  │             ┌──────────────────────────────────────┐
   │  │Product Svc   │  │             │          ECS CLUSTER                 │
   │  └──────────────┘  │             │         (Fargate)                    │
   │  EC2 (t3.medium)   │             │                                      │
   │  ┌──────────────┐  │             │  ┌──────────┐  ┌──────────────────┐ │
   │  │Payment Svc   │  │             │  │ Service: │  │ Task Definition: │ │
   │  └──────────────┘  │             │  │ users    │  │ • Image from ECR │ │
   │  EC2 (t3.medium)   │             │  │ desired:3│  │ • CPU: 256       │ │
   │  ┌──────────────┐  │             │  │ running:3│  │ • Memory: 512    │ │
   │  │Notif. Svc    │  │             │  └──────────┘  │ • Env vars       │ │
   │  └──────────────┘  │             │  ┌──────────┐  │ • Port mapping   │ │
   │  EC2 (t3.medium)   │             │  │ Service: │  │ • Health check   │ │
   │  ┌──────────────┐  │             │  │ orders   │  │ • Log config     │ │
   │  │Search Svc    │  │             │  │ desired:2│  └──────────────────┘ │
   │  └──────────────┘  │             │  └──────────┘                       │
   └────────────────────┘             │  ┌──────────┐                       │
                                      │  │ Service: │  ┌──────────────────┐ │
   6x t3.medium = $240/mo            │  │ products │  │      ECR         │ │
   Most at 15% CPU                    │  │ desired:2│  │ (Container       │ │
                                      │  └──────────┘  │  Registry)       │ │
                                      │  ┌──────────┐  │                  │ │
                                      │  │...3 more │  │ • users:latest   │ │
                                      │  │ services │  │ • orders:v2.1    │ │
                                      │  └──────────┘  │ • products:v3.0  │ │
                                      │                │ • payment:v1.5   │ │
                                      └────────────────│ • notif:v2.0     │ │
                                                       │ • search:v4.2    │ │
                                                       └──────────────────┘ │

   ┌──────────────────────────────────────────────────────────────┐
   │  DEPLOYMENT PIPELINE:                                        │
   │                                                               │
   │  Code Push ──▶ CodeBuild ──▶ Docker Build ──▶ Push to ECR   │
   │                                                     │         │
   │                                                     ▼         │
   │                                              ECS Rolling      │
   │                                              Update           │
   │                                              (zero downtime)  │
   │                                                               │
   │  Auto Scaling:                                                │
   │  • Target tracking on CPU/Memory                              │
   │  • Scale per service independently                            │
   │  • Users: 2-10 tasks, Orders: 1-5 tasks                      │
   └──────────────────────────────────────────────────────────────┘

   ┌──────────────────────────────────────────────────────────────┐
   │  SUPPORTING SERVICES:                                        │
   │                                                               │
   │  ┌───────────────┐  ┌────────────┐  ┌──────────────────────┐│
   │  │ CloudWatch    │  │ Secrets    │  │ RDS (shared DB)      ││
   │  │ Container     │  │ Manager   │  │ (unchanged from       ││
   │  │ Insights      │  │ (DB creds)│  │  before)              ││
   │  └───────────────┘  └────────────┘  └──────────────────────┘│
   └──────────────────────────────────────────────────────────────┘
```

### Why This Architecture

- **ECS Fargate over EKS**: No Kubernetes expertise required. Fargate is "give me a container, you run it." AWS manages all underlying infrastructure. EKS needs K8s knowledge
- **ECR for container images**: Private Docker registry in AWS. Integrated with IAM, scans for vulnerabilities, lifecycle policies to clean old images
- **Per-service scaling**: Each microservice scales independently. User service might need 10 tasks during login peak while Search only needs 2. EC2-per-service can't do this efficiently
- **ALB path-based routing**: Single ALB routes /api/users, /api/orders, etc. to different ECS services. Each service is a target group
- **Right-sizing with Fargate**: Allocate exactly the CPU/memory each service needs (256 CPU + 512 MB for light services, 1024 CPU + 2048 MB for heavy ones). No wasted capacity

### Country Analogy

Before, each soldier (service) lived in their own full-sized barracks (EC2) -- even if they only used a corner of it. Now, you've built a **modular camp** (ECS Cluster) with **portable pods** (Fargate tasks). Each soldier gets a pod sized exactly for their needs -- small pod for the messenger (notification service), big pod for the quartermaster (order service). The **general** (ECS Service) ensures the right number of pods are always deployed. If more messengers are needed, he deploys more messenger pods. **ECR** is the equipment warehouse where each soldier's standard kit (Docker image) is stored and versioned. The **front gate** (ALB) reads the destination tag on each delivery and routes it to the right pod.

### Exam Question

**A company runs 6 microservices on individual EC2 instances at low utilization. They want to containerize for better efficiency and eliminate server management. The team has no Kubernetes experience. Which solution meets these requirements?**

A) Amazon EKS with EC2 worker nodes
B) Amazon ECS with Fargate launch type, ALB for routing, ECR for images
C) Amazon ECS with EC2 launch type and Auto Scaling
D) Deploy containers directly on EC2 instances using Docker Compose

**Correct: B**

- **A is wrong**: "No Kubernetes experience" eliminates EKS. EKS requires K8s knowledge for pod specs, services, ingress, etc.
- **C is wrong**: EC2 launch type means you still manage EC2 instances (patching, scaling the cluster, capacity planning). Doesn't "eliminate server management."
- **D is wrong**: Docker Compose on EC2 is a development tool, not production orchestration. No auto-scaling, no health-check replacement, no rolling deployments, still managing EC2.

### Which Exam Tests This

**SAA-C03** (primary) -- container service selection, migration to managed services.
**DVA-C02** (primary) -- ECS task definitions, ECR, deployment strategies, CI/CD integration.
**SOA-C02** (secondary) -- Container Insights monitoring, ECS service auto-scaling.

### Key Trap

**ECS vs EKS -- the exam always hints.** "No Kubernetes experience" = ECS. "Already using Kubernetes" or "multi-cloud" = EKS. **Fargate vs EC2 launch type** -- "eliminate server management" or "serverless" = Fargate. "Need GPU" or "need custom AMI" or "need persistent storage on host" = EC2 launch type. Also: ECS Fargate tasks in the SAME service can be in different AZs for HA -- this is automatic.

---

## Scenario 9: On-Premises REST API to Serverless

### The Scenario

A company runs a REST API on 3 on-premises servers (Node.js + Express + MySQL) handling employee management for 50 corporate clients. Each client authenticates with API keys. The servers are aging, maintenance is expensive, and they want to go fully serverless on AWS with no servers to manage. They also need to add OAuth2/JWT authentication.

### Architecture Diagram

```
   BEFORE (on-premises):

   ┌─────────────────────────────────────────────┐
   │  ON-PREM DATA CENTER                        │
   │                                              │
   │  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
   │  │ Server 1 │ │ Server 2 │ │ Server 3 │    │
   │  │ Node.js  │ │ Node.js  │ │ Node.js  │    │
   │  │ Express  │ │ Express  │ │ Express  │    │
   │  └────┬─────┘ └────┬─────┘ └────┬─────┘    │
   │       └─────────────┼───────────┘            │
   │                     ▼                        │
   │              ┌──────────────┐                │
   │              │    MySQL     │                │
   │              │   (on-prem)  │                │
   │              └──────────────┘                │
   │                                              │
   │  Load Balancer (F5 / Nginx)                  │
   │  API Key auth (custom middleware)            │
   │  Cost: ~$3,000/mo (servers + license + ops)  │
   └─────────────────────────────────────────────┘

   AFTER (serverless on AWS):

   ┌─────────────────────────────────────────────────────────────┐
   │  CLIENTS (50 corporate apps)                                │
   │  Each gets: OAuth2 client_id + client_secret                │
   └──────────────────────┬──────────────────────────────────────┘
                          │
                          ▼
   ┌──────────────────────────────────────────────────────────────┐
   │                    COGNITO                                   │
   │                                                               │
   │  ┌───────────────┐    ┌────────────────────────────────────┐ │
   │  │  User Pool    │    │  App Clients (one per corp client) │ │
   │  │               │    │                                    │ │
   │  │  • OAuth2     │    │  • client_credentials grant type   │ │
   │  │  • JWT tokens │    │  • Scopes: read:employees,         │ │
   │  │  • Token      │    │            write:employees          │ │
   │  │    endpoint   │    │  • Rate limits per client           │ │
   │  └───────────────┘    └────────────────────────────────────┘ │
   └──────────────────────────┬───────────────────────────────────┘
                              │ JWT Token
                              ▼
   ┌──────────────────────────────────────────────────────────────┐
   │                  API GATEWAY (REST)                           │
   │                                                               │
   │  ┌─────────────────────────────────────────────────────────┐ │
   │  │  Cognito Authorizer (validates JWT automatically)       │ │
   │  └─────────────────────────────────────────────────────────┘ │
   │                                                               │
   │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐  │
   │  │GET       │  │POST      │  │PUT       │  │DELETE      │  │
   │  │/employees│  │/employees│  │/employees│  │/employees  │  │
   │  │          │  │          │  │/{id}     │  │/{id}       │  │
   │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └─────┬──────┘  │
   │       │              │             │               │         │
   │  ┌────┴──────────────┴─────────────┴───────────────┴──────┐ │
   │  │  Usage Plans + API Keys (throttling per client)        │ │
   │  │  Stage: prod (caching enabled, 0.5 GB)                 │ │
   │  │  WAF integration (IP filtering, rate limiting)         │ │
   │  └────────────────────────────────────────────────────────┘ │
   └─────────────────────────────┬────────────────────────────────┘
                                 │
                                 ▼
   ┌──────────────────────────────────────────────────────────────┐
   │                    LAMBDA FUNCTIONS                           │
   │                                                               │
   │  ┌────────────┐ ┌─────────────┐ ┌────────────┐ ┌──────────┐│
   │  │ getEmployees│ │createEmployee│ │updateEmployee│ │deletEmp ││
   │  │            │ │             │ │            │ │          ││
   │  │ Node.js 20│ │ Validates   │ │ Validates  │ │ Soft     ││
   │  │ 128 MB    │ │ input with  │ │ input      │ │ delete   ││
   │  │ 10s TO    │ │ schema      │ │            │ │          ││
   │  └─────┬──────┘ └──────┬──────┘ └─────┬──────┘ └─────┬────┘│
   │        └────────────────┼──────────────┼──────────────┘     │
   └─────────────────────────┼──────────────┼────────────────────┘
                             │              │
                             ▼              ▼
   ┌──────────────────────────────────────────────────────────────┐
   │                   DYNAMODB                                    │
   │                                                               │
   │  Table: Employees                                             │
   │  PK: clientId    SK: employeeId                               │
   │  GSI: email-index (for lookup by email)                       │
   │                                                               │
   │  Capacity: On-Demand (pay per request)                        │
   │  Encryption: AWS-managed KMS key                              │
   │  Point-in-time recovery: enabled                              │
   └──────────────────────────────────────────────────────────────┘
```

### Why This Architecture

- **Cognito for OAuth2/JWT**: Replaces custom API key middleware. Machine-to-machine auth via client_credentials grant. Each corporate client gets their own app client with specific scopes. Cognito issues and validates JWTs automatically
- **API Gateway + Cognito Authorizer**: JWT validation happens at the gateway layer -- invalid tokens never reach Lambda. Zero custom auth code
- **Lambda per operation**: Each CRUD operation is its own function. Independent scaling, independent error handling, independent deployment. One function failing doesn't take down the API
- **DynamoDB replaces MySQL**: No server to manage. On-Demand capacity = zero idle cost. clientId as partition key = natural multi-tenant isolation. Each client's data is partitioned separately
- **Usage Plans for per-client throttling**: Each corporate client gets a rate limit (1,000 req/sec) and quota (100,000 req/month). Built into API Gateway, no custom code

### Country Analogy

The old system was a **fortress** (on-prem) with 3 guards (servers) and a record room (MySQL). Every visitor had to show a simple badge (API key) at the gate. The new system replaces the fortress with a **government services portal**. **Cognito** is the **Ministry of Identity** -- it issues official ID cards (JWT tokens) with specific permissions (scopes). **API Gateway** is the **reception desk** that checks IDs before anyone enters. **Lambda** is the **magic kitchen** -- staff appear only when needed, each specialist handles one type of request. **DynamoDB** is the **filing system** where each corporate client has their own locked drawer (partition key = clientId). **Usage Plans** are the **appointment limits** -- each client can only book so many appointments per day.

### Exam Question

**A company is migrating an on-premises REST API (Node.js + MySQL) to AWS. The API serves 50 corporate clients with API key authentication. They want serverless infrastructure and need to add OAuth2/JWT authentication. Which architecture is most appropriate?**

A) EC2 instances behind ALB with Cognito User Pool, RDS MySQL, and custom JWT middleware in the application
B) API Gateway with Cognito Authorizer, Lambda functions, and DynamoDB with on-demand capacity
C) API Gateway with Lambda Authorizer (custom), Lambda functions, and Aurora Serverless
D) AppSync GraphQL API with Cognito, Lambda resolvers, and DynamoDB

**Correct: B**

- **A is wrong**: EC2 instances are not serverless. Custom JWT middleware = unnecessary code when Cognito Authorizer handles this natively.
- **C is wrong**: Lambda Authorizer (custom) means writing your own auth logic. Cognito Authorizer is built-in and handles JWT validation automatically. Also, Aurora Serverless still has minimum capacity charges -- DynamoDB On-Demand is truly zero-when-idle.
- **D is wrong**: AppSync is for GraphQL, not REST. The question specifies REST API. Migrating a REST API to GraphQL is a major redesign, not a migration.

### Which Exam Tests This

**SAA-C03** (primary) -- serverless architecture, migration patterns, authentication.
**DVA-C02** (primary) -- Cognito configuration, API Gateway authorizers, Lambda development.
**SOA-C02** (secondary) -- monitoring API Gateway usage plans, Lambda throttling.

### Key Trap

**Cognito Authorizer vs Lambda Authorizer.** Cognito Authorizer = built-in, validates Cognito-issued JWTs, zero code. Lambda Authorizer = custom function, you write the logic, useful for third-party tokens or complex auth. If the question mentions Cognito or AWS-managed auth, use Cognito Authorizer. If it mentions "third-party identity provider" or "custom authorization logic," use Lambda Authorizer. Also: API Gateway **Usage Plans** require **API Keys** for tracking -- but API Keys are NOT for authentication (Cognito handles that). They're for identification and throttling.

---

## Scenario 10: Hybrid DNS with Route 53 Resolver

### The Scenario

A company has migrated some workloads to AWS but keeps critical systems on-premises. On-prem servers need to resolve AWS private hosted zone names (e.g., db.internal.company.com pointing to an RDS instance). AWS resources need to resolve on-premises DNS names (e.g., ldap.corp.company.com pointing to an Active Directory server). Currently, DNS resolution is broken in both directions.

### Architecture Diagram

```
   THE PROBLEM:
   ┌──────────────────┐              ┌──────────────────┐
   │   ON-PREMISES    │              │      AWS VPC     │
   │                  │              │                  │
   │  ldap.corp.      │  Can't       │  db.internal.   │
   │  company.com     │  resolve     │  company.com    │
   │  = 10.0.1.50     │◄──── X ────▶│  = 10.10.5.25   │
   │                  │  each other  │  (RDS private)  │
   │  Corp DNS:       │              │                  │
   │  10.0.1.10       │              │  VPC DNS:        │
   │                  │              │  AmazonProvided  │
   └──────────────────┘              └──────────────────┘

   THE SOLUTION:
   ┌─────────────────────────────────────────────────────────────────┐
   │                    ON-PREMISES                                  │
   │                                                                 │
   │  ┌──────────────────┐                                          │
   │  │  Corporate DNS   │                                          │
   │  │  Server          │                                          │
   │  │  10.0.1.10       │                                          │
   │  │                  │                                          │
   │  │  Conditional     │                                          │
   │  │  Forwarder:      │                                          │
   │  │  *.internal.     │──────────────────┐                       │
   │  │  company.com     │                  │                       │
   │  │  → forward to    │                  │                       │
   │  │  R53 Inbound     │                  │                       │
   │  │  Endpoint IPs    │                  │ DNS query for         │
   │  └───────┬──────────┘                  │ "db.internal.        │
   │          │                             │  company.com"         │
   │          │ Answers queries for         │                       │
   │          │ corp.company.com            │ (over DX / VPN)       │
   │          │ from R53 Outbound           │                       │
   │          │                             │                       │
   └──────────┼─────────────────────────────┼───────────────────────┘
              │                             │
              │                             │
   ═══════════╪═════════════════════════════╪═══ Direct Connect / VPN
              │                             │
              │                             │
   ┌──────────┼─────────────────────────────┼───────────────────────┐
   │     AWS  │VPC (10.10.0.0/16)           │                       │
   │          │                             │                       │
   │          │                             ▼                       │
   │          │                  ┌──────────────────────┐           │
   │          │                  │  Route 53 Resolver   │           │
   │          │                  │  INBOUND Endpoint    │           │
   │          │                  │                      │           │
   │          │                  │  ENIs in VPC:        │           │
   │          │                  │  10.10.1.100 (AZ-a)  │           │
   │          │                  │  10.10.2.100 (AZ-b)  │           │
   │          │                  │                      │           │
   │          │                  │  On-prem DNS sends   │           │
   │          │                  │  queries HERE        │           │
   │          │                  │  → resolves private  │           │
   │          │                  │    hosted zones      │           │
   │          │                  └──────────────────────┘           │
   │          │                                                     │
   │          ▼                                                     │
   │  ┌──────────────────────┐                                      │
   │  │  Route 53 Resolver   │                                      │
   │  │  OUTBOUND Endpoint   │                                      │
   │  │                      │                                      │
   │  │  ENIs in VPC:        │    ┌──────────────────────────────┐ │
   │  │  10.10.3.100 (AZ-a)  │    │  Resolver RULE:              │ │
   │  │  10.10.4.100 (AZ-b)  │◄───│                              │ │
   │  │                      │    │  IF query matches:           │ │
   │  │  Forwards queries    │    │    *.corp.company.com        │ │
   │  │  to on-prem DNS      │    │  THEN forward to:           │ │
   │  │  (10.0.1.10)         │    │    10.0.1.10 (corp DNS)     │ │
   │  └──────────────────────┘    │                              │ │
   │                              │  ELSE: use R53 as normal     │ │
   │                              └──────────────────────────────┘ │
   │                                                                │
   │  ┌──────────────────────┐    ┌──────────────────────────────┐ │
   │  │  Private Hosted Zone │    │  Resources:                  │ │
   │  │  internal.company.com│    │                              │ │
   │  │                      │    │  ┌──────┐  ┌─────┐ ┌──────┐ │ │
   │  │  db.internal.        │    │  │  RDS │  │ EC2 │ │ ECS  │ │ │
   │  │   company.com        │    │  │      │  │     │ │      │ │ │
   │  │   → 10.10.5.25      │    │  └──────┘  └─────┘ └──────┘ │ │
   │  │                      │    │                              │ │
   │  │  cache.internal.     │    └──────────────────────────────┘ │
   │  │   company.com        │                                     │
   │  │   → 10.10.6.30      │                                     │
   │  └──────────────────────┘                                     │
   └───────────────────────────────────────────────────────────────┘

   ┌─────────────────────────────────────────────────────────────────┐
   │  FLOW SUMMARY:                                                  │
   │                                                                  │
   │  ON-PREM → AWS:                                                  │
   │  1. On-prem app asks for db.internal.company.com                │
   │  2. Corp DNS sees conditional forwarder for *.internal.*        │
   │  3. Forwards to R53 Inbound Endpoint (10.10.1.100)              │
   │  4. R53 resolves from Private Hosted Zone → 10.10.5.25         │
   │  5. Answer returns to on-prem app                               │
   │                                                                  │
   │  AWS → ON-PREM:                                                  │
   │  1. EC2 instance asks for ldap.corp.company.com                 │
   │  2. VPC DNS (Route 53 Resolver) checks rules                   │
   │  3. Rule matches *.corp.company.com → forward to 10.0.1.10     │
   │  4. Outbound Endpoint sends query to corp DNS                   │
   │  5. Corp DNS answers → 10.0.1.50                               │
   │  6. Answer returns to EC2                                       │
   └─────────────────────────────────────────────────────────────────┘
```

### Why This Architecture

- **Inbound Endpoint**: Creates ENIs in your VPC that on-premises DNS can forward queries to. This is the "door" for on-prem to resolve AWS private hosted zone records
- **Outbound Endpoint + Resolver Rules**: When AWS resources need to resolve on-prem names, Resolver Rules define which domains to forward and to which on-prem DNS server. Outbound Endpoint sends the query
- **Conditional forwarding on both sides**: On-prem DNS forwards `*.internal.company.com` to AWS. AWS Resolver forwards `*.corp.company.com` to on-prem. Everything else resolves normally
- **ENIs in 2 AZs**: Both inbound and outbound endpoints get ENIs in at least 2 AZs for high availability. If one AZ fails, DNS still works
- **Private Hosted Zones stay private**: Records like `db.internal.company.com` are never exposed to the public internet. Only accessible via VPC DNS or through the Inbound Endpoint

### Country Analogy

Two countries (on-prem and AWS) have their own **phone directories** (DNS servers). Citizens in one country can't look up numbers in the other country's directory. The solution: build **embassy phone lines**. The **Inbound Endpoint** is the **AWS embassy in on-prem's country** -- when on-prem citizens need to find someone in AWS, they call the embassy, which looks up the number in the AWS directory. The **Outbound Endpoint** is the **on-prem embassy in AWS** -- when AWS citizens need to find someone on-prem, they call this embassy, which looks up the number in on-prem's directory. **Resolver Rules** are the **forwarding instructions** posted at each embassy: "If someone asks about corp.company.com, forward to on-prem directory." **Conditional forwarders** on the on-prem side say: "If someone asks about internal.company.com, forward to the AWS embassy."

### Exam Question

**A company has resources in AWS using a private hosted zone (internal.company.com) and on-premises servers that need to resolve these DNS names. AWS resources also need to resolve on-premises DNS names (corp.company.com). They are connected via Direct Connect. Which solution enables bidirectional DNS resolution?**

A) Create a Route 53 public hosted zone and use split-horizon DNS
B) Create Route 53 Resolver inbound endpoints for on-prem to AWS resolution, outbound endpoints with forwarding rules for AWS to on-prem resolution
C) Install a DNS server on an EC2 instance that forwards queries to both Route 53 and on-premises DNS
D) Use Route 53 Resolver outbound endpoints for both directions and configure on-premises DNS to query the outbound endpoint IPs

**Correct: B**

- **A is wrong**: Public hosted zone exposes records to the internet. The requirement is private DNS resolution. Split-horizon DNS is for serving different records to internal vs external queries, not for hybrid resolution.
- **C is wrong**: Running your own DNS server on EC2 works but is undifferentiated heavy lifting. You'd have to manage, patch, and make it highly available. Route 53 Resolver Endpoints are the managed solution for exactly this problem.
- **D is wrong**: Outbound endpoints SEND queries FROM AWS TO on-prem. They don't RECEIVE queries from on-prem. You need Inbound endpoints for on-prem-to-AWS direction.

### Which Exam Tests This

**SAA-C03** (primary) -- hybrid DNS, Route 53 Resolver, private hosted zones.
**SOA-C02** (secondary) -- configuring Resolver rules, monitoring DNS query logs, troubleshooting resolution failures.

### Key Trap

**Inbound vs Outbound -- the names are from AWS's perspective.** Inbound = queries coming INTO AWS (from on-prem). Outbound = queries going OUT of AWS (to on-prem). The exam may describe the flow from the on-prem perspective to confuse you. Also: **Route 53 Resolver Endpoints require a VPC** -- they create ENIs. You can't use them without a VPC. And: each endpoint needs IPs in at least 2 AZs for high availability. Each ENI costs $0.125/hour (~$90/month), so 4 ENIs (2 inbound + 2 outbound) = ~$360/month. This is a real cost to be aware of.

---

## Quick Reference: When to Use What

```
┌────────────────────────────┬───────────────────────────────────────┐
│  COST SCENARIO             │  KEY SERVICE COMBO                    │
├────────────────────────────┼───────────────────────────────────────┤
│  Reduce compute costs      │  RI + Spot + Savings Plans + ASG Mix │
│  Reduce storage costs      │  S3 Lifecycle + Intelligent-Tiering  │
│  Reduce always-on costs    │  Lambda + API GW + DynamoDB On-Demand│
│  Reduce database costs     │  Aurora Serverless v2 + ElastiCache  │
│  Reduce network costs      │  Gateway Endpoints + CloudFront      │
├────────────────────────────┼───────────────────────────────────────┤
│  HYBRID SCENARIO           │  KEY SERVICE COMBO                    │
├────────────────────────────┼───────────────────────────────────────┤
│  Dedicated connectivity    │  Direct Connect + VPN backup + TGW   │
│  Database migration        │  SCT (schema) + DMS (data + CDC)     │
│  Containerize apps         │  ECR + ECS Fargate + ALB             │
│  API to serverless         │  API GW + Cognito + Lambda + DynamoDB│
│  Hybrid DNS                │  R53 Resolver Inbound + Outbound     │
└────────────────────────────┴───────────────────────────────────────┘
```
