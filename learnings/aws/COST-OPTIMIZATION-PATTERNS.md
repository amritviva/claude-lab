# Cost Optimization Patterns — The Money-Saver's Playbook

> **Country Analogy:** The Treasury Department. Every ministry, department, and agency must justify its budget. The Treasury doesn't care how cool your project is — if there's a cheaper way to get the same result, you use it. Wasting taxpayer money (AWS bill) is a fireable offence.

---

## The Golden Rule

**"Most cost-effective" = the CHEAPEST option that MEETS ALL requirements.**

Not just cheapest. Not just meets requirements. BOTH.

The exam loves traps where:
- Option A is cheapest but violates a requirement (e.g., durability, availability, compliance)
- Option B costs more but is the ONLY one that satisfies every stated constraint

**Read the question twice.** Circle every requirement. Then find the cheapest option that checks ALL boxes.

---

## 1. Compute Cost Patterns

### The EC2 Pricing Ladder (cheapest → most expensive for steady workloads)

```
CHEAPEST for steady workloads
─────────────────────────────────────────────────
│  Spot Instances           │ Up to 90% off      │  ⚠️ Can be interrupted
│  Reserved (3yr, All Up)   │ Up to 72% off      │  Locked in
│  Reserved (1yr, All Up)   │ Up to 40% off      │  Locked in
│  Reserved (1yr, No Up)    │ Up to 36% off      │  No upfront, still locked
│  Savings Plans            │ Up to 72% off      │  Flexible across instance types
│  On-Demand                │ Full price          │  No commitment
─────────────────────────────────────────────────
MOST EXPENSIVE (but most flexible)
```

### Reserved Instances — The Lease Analogy

Think of it like leasing office space for the country's departments:

| Payment Option | Discount | Analogy |
|---|---|---|
| All Upfront (1yr) | ~40% off | Pay full year's rent day one |
| Partial Upfront (1yr) | ~35% off | Pay half now, half monthly |
| No Upfront (1yr) | ~36% off | Monthly payments, but you signed a 1-year lease |
| All Upfront (3yr) | ~72% off | Pay 3 years rent day one — massive discount |

**Exam trap:** "No Upfront Reserved" still saves money vs On-Demand. You're committing to the term, not paying upfront.

### Savings Plans vs Reserved Instances

| Feature | Reserved Instances | Savings Plans |
|---|---|---|
| Locked to | Specific instance type + region | $/hour commitment (flexible) |
| Flexibility | Can't change instance family | Can change instance family, size, OS, region |
| Best for | You KNOW exactly what you'll run | You know you'll spend $X/hr but workloads shift |
| Discount | Up to 72% | Up to 72% |

**Exam rule:** If the question says "flexibility to change instance types" → Savings Plans. If it says "known steady workload on specific instance" → Reserved.

### Spot Instances — When YES vs When NO

**YES (Spot is the answer):**
- Batch processing jobs
- Big data / EMR clusters
- CI/CD build servers
- Stateless web servers behind a load balancer
- Image/video rendering
- Scientific computing
- Any workload that can handle interruption

**NO (Spot is NOT the answer):**
- Databases (stateful — data loss on termination)
- Single-instance applications (no failover)
- Anything with "high availability" as a requirement
- Long-running stateful jobs that can't checkpoint
- Compliance workloads requiring guaranteed uptime

**Key number:** Spot gives you a **2-minute warning** before termination.

### Spot Fleet Strategies

| Strategy | What It Does | When to Use |
|---|---|---|
| `lowestPrice` | Pick cheapest pool | Pure cost savings, don't care about diversity |
| `diversified` | Spread across pools | Reduce interruption risk |
| `capacityOptimized` | Pick pool with most spare capacity | Lowest chance of interruption |

### Lambda Pricing

```
Cost = (Number of requests × $0.20 per 1M) + (GB-seconds × $0.0000166667)

Free Tier (per month, FOREVER — not just 12 months):
  - 1,000,000 requests
  - 400,000 GB-seconds
```

**When Lambda beats EC2:**
- Sporadic, unpredictable traffic (pay nothing when idle)
- < 15 minutes execution time per invocation
- < 10,000 concurrent executions needed

**When EC2 beats Lambda:**
- Steady, high-volume traffic (Lambda per-request cost adds up)
- Long-running processes (> 15 min)
- Need GPU or specialized hardware

### Fargate vs EC2 Launch Type (ECS/EKS)

| Factor | Fargate | EC2 Launch Type |
|---|---|---|
| Management | Zero (serverless) | You manage instances |
| Cost at scale | More expensive | Cheaper (especially with Reserved/Spot) |
| Cost for variable | Cheaper (pay per task) | Wasting money on idle capacity |
| Best for | Variable workloads, small teams | Large steady workloads, cost-sensitive |

**Exam rule:** "Minimize operational overhead" → Fargate. "Minimize cost at large scale" → EC2 launch type.

### Right-Sizing

The process:
1. Enable CloudWatch detailed monitoring (CPU, memory, network)
2. Look for instances consistently under 40% CPU utilization
3. Use AWS Compute Optimizer recommendations
4. Downgrade to smaller instance type
5. Monitor for 2 weeks, adjust if needed

**Graviton instances:** ARM-based processors, **40% better price-performance** than x86. If the question mentions "price-performance" and doesn't require x86 software compatibility → Graviton.

---

## 2. Storage Cost Patterns

### S3 Lifecycle Rules — The Filing System

Think of it as the country's document archive policy:

```
Day 0:   Document created → STANDARD (hot desk, instant access)
                              $0.023/GB/month

Day 30:  Moved to filing cabinet → STANDARD-IA (Infrequent Access)
                              $0.0125/GB/month
                              ⚠️ 128KB minimum charge, retrieval fee $0.01/GB

Day 90:  Moved to basement → GLACIER INSTANT RETRIEVAL
                              $0.004/GB/month
                              millisecond retrieval

Day 180: Moved to warehouse → GLACIER FLEXIBLE RETRIEVAL
                              $0.0036/GB/month
                              Minutes to 12 hours retrieval

Day 365: Moved to deep storage vault → GLACIER DEEP ARCHIVE
                              $0.00099/GB/month
                              12-48 hours retrieval
```

### S3 Tier Decision Tree

```
How often do you access it?
├── Multiple times per day → STANDARD
├── Once a month → STANDARD-IA
├── Unpredictable pattern → INTELLIGENT-TIERING
├── Once a quarter, need instant → GLACIER INSTANT RETRIEVAL
├── Once a year, can wait hours → GLACIER FLEXIBLE RETRIEVAL
└── Compliance archive, rarely ever → GLACIER DEEP ARCHIVE

Is the file smaller than 128KB?
├── YES → Keep in STANDARD (IA charges 128KB minimum anyway)
└── NO → Follow the tree above
```

### S3 Intelligent-Tiering

- Automatically moves objects between tiers based on access patterns
- Monitoring fee: **$0.0025 per 1,000 objects/month**
- No retrieval fees when it moves things around
- **Best for:** Unknown or changing access patterns
- **Exam trap:** Intelligent-Tiering has a per-object monitoring fee. For millions of small objects, this can be more expensive than just picking IA manually.

### EBS Volume Costs

| Volume Type | Cost | IOPS | When to Use |
|---|---|---|---|
| gp3 | $0.08/GB | 3,000 base (up to 16,000) | **DEFAULT CHOICE — always** |
| gp2 | $0.10/GB | 3 IOPS/GB (burst to 3,000) | **Legacy — never choose this** |
| io2 Block Express | $0.125/GB + $0.065/IOPS | Up to 256,000 | Databases needing guaranteed IOPS |
| st1 (HDD) | $0.045/GB | Throughput optimized | Big data, logs, sequential reads |
| sc1 (Cold HDD) | $0.015/GB | Lowest cost | Infrequent access, archives |

**Exam rule:** If gp2 and gp3 are both options → **always gp3** (cheaper AND better performance baseline).

**Common waste:** Unattached EBS volumes still cost money. The exam loves asking about cost reduction → "delete unattached EBS volumes" is almost always correct.

### EFS Cost Optimization

- EFS Lifecycle Policy: move files not accessed for 30/60/90 days to **IA tier** (up to 92% cheaper)
- EFS One Zone: 47% cheaper than Standard (but single-AZ — no HA)
- **Exam rule:** "Cost-effective file storage for infrequently accessed data" → EFS with lifecycle policy to IA

---

## 3. Database Cost Patterns

### RDS Cost Strategies

| Workload Pattern | Best Strategy | Why |
|---|---|---|
| Steady 24/7 | RDS Reserved Instance | Up to 72% off On-Demand |
| Variable/spiky | Aurora Serverless v2 | Scales with demand, min 0.5 ACU |
| Dev/test | RDS Single-AZ + stop when not in use | No Multi-AZ overhead |
| Read-heavy | Read Replicas (up to 15 for Aurora) | Offload reads from primary |
| Repeated reads | ElastiCache in front of RDS | Sub-millisecond, reduces DB load |

### Read Replicas vs ElastiCache

```
Read Replica:
  - Full SQL query support
  - Slightly stale data (async replication lag)
  - Good for: reporting queries, analytics, read scaling
  - Still hitting a database (not free)

ElastiCache:
  - Key-value or simple lookups
  - Microsecond latency
  - Good for: session data, leaderboards, repeated identical queries
  - Results cached in memory (very fast, very cheap per read)
```

**Exam rule:** "Reduce database load for repeated identical queries" → ElastiCache. "Scale read capacity for diverse queries" → Read Replicas.

### DynamoDB Pricing Modes

| Mode | Cost Model | Best For |
|---|---|---|
| On-Demand | Pay per read/write | Unpredictable traffic, new tables, spiky workloads |
| Provisioned | Pay for RCU/WCU capacity | Steady, predictable traffic |
| Provisioned + Auto Scaling | Base capacity + auto-adjust | Mostly steady with occasional spikes |
| Provisioned + Reserved | Pre-pay capacity (1yr/3yr) | Known steady workload — cheapest option |

**Exam rule:** "Unknown traffic patterns" or "new application" → On-Demand. "Steady traffic, cost-sensitive" → Provisioned with auto-scaling.

### Aurora Serverless v2

- Scales in **0.5 ACU increments** (fine-grained)
- Minimum: 0.5 ACU (~$0.06/hour)
- Scales to zero-ish (0.5 ACU minimum, not truly zero)
- **Best for:** Dev/test environments, variable workloads, infrequent but heavy queries
- **Not best for:** Constant high throughput (provisioned Aurora is cheaper)

---

## 4. Network Cost Patterns

### The Data Transfer Cost Map

```
CHEAPEST ──────────────────────────────────── MOST EXPENSIVE

Same AZ         Cross-AZ        Cross-Region      Internet
FREE             $0.01/GB        $0.02/GB          $0.09/GB
(in → in)        (each way)      (each way)        (outbound)

Inbound from internet = FREE (AWS wants your data IN)
Outbound to internet = $0.09/GB (first 100GB/month free)
```

**Key numbers for the exam:**
- Same-AZ: **FREE**
- Cross-AZ: **$0.01/GB each direction** ($0.02 round trip)
- Cross-Region: **$0.02/GB**
- Internet outbound: **$0.09/GB** (first 100GB/month free)
- Internet inbound: **FREE**

### VPC Endpoints — The Money Saver

```
WITHOUT VPC Endpoint:
  EC2 → NAT Gateway → Internet → S3
  Cost: $0.045/GB (NAT Gateway processing) + $0.045/hour (NAT Gateway)

WITH VPC Gateway Endpoint:
  EC2 → VPC Endpoint → S3
  Cost: FREE (for S3 and DynamoDB Gateway Endpoints)
```

| Endpoint Type | Services | Cost | Exam Keyword |
|---|---|---|---|
| Gateway Endpoint | S3, DynamoDB only | **FREE** | "reduce NAT costs for S3/DynamoDB" |
| Interface Endpoint | Everything else (400+ services) | $0.01/hour + $0.01/GB | "private access to AWS services" |

**Exam rule:** If the question mentions reducing costs for S3 or DynamoDB access from VPC → **VPC Gateway Endpoint** (free, no NAT needed).

### NAT Gateway Costs

- **$0.045/hour** (~$32/month per AZ) + **$0.045/GB** processed
- Expensive for high-traffic workloads
- **Cost reduction strategies:**
  1. Use VPC Gateway Endpoints for S3/DynamoDB (free)
  2. Use VPC Interface Endpoints for other AWS services
  3. Put NAT Gateway in one AZ only (trade HA for cost in dev/test)
  4. Compress data before sending through NAT

### CloudFront Cost Savings

CloudFront caching reduces:
- API Gateway invocations (less Lambda cost)
- S3 GET requests
- Origin server load
- Data transfer costs (CloudFront → internet is cheaper than direct from origin)

**CloudFront data transfer:** $0.085/GB (cheaper than direct S3 → internet at $0.09/GB)

### S3 Transfer Acceleration vs CloudFront

| Feature | S3 Transfer Acceleration | CloudFront |
|---|---|---|
| Direction | **Uploads** to S3 | **Downloads** from S3 |
| How | Uses CloudFront edge locations | Caches at edge locations |
| Cost | $0.04-0.08/GB on top of transfer | Standard CloudFront pricing |
| When | Large file uploads from distant users | Static content delivery to many users |

---

## 5. "When They Say X, Choose Y" — Quick-Fire Cost Patterns

These are the patterns that show up again and again on the exam. Memorize them.

| When the question says... | Choose... | Why |
|---|---|---|
| "Most cost-effective compute for steady 24/7" | Reserved Instances or Savings Plans | Committed discount |
| "Cost-effective, can tolerate interruptions" | Spot Instances | Up to 90% off |
| "Unpredictable traffic, minimize cost" | Lambda or Auto Scaling with mixed instances | Pay for what you use |
| "Reduce S3 storage costs over time" | S3 Lifecycle Policy | Auto-tier to cheaper storage |
| "Unknown access patterns for S3" | S3 Intelligent-Tiering | Auto-optimizes |
| "Cost-effective block storage" | gp3 (never gp2) | Cheaper with better baseline |
| "Reduce NAT Gateway costs" | VPC Gateway Endpoint (S3/DynamoDB) | Free |
| "Minimize data transfer costs" | Same-AZ deployment or VPC Endpoints | Avoid cross-AZ/internet fees |
| "Cost-effective database for variable traffic" | Aurora Serverless v2 or DynamoDB On-Demand | Scales with demand |
| "Cost-effective database for steady traffic" | RDS Reserved Instance | Committed discount |
| "Reduce repeated database reads cost" | ElastiCache | Cache layer eliminates DB hits |
| "Minimize operational overhead AND cost" | Managed/serverless service (Lambda, Fargate, Aurora Serverless) | No servers to manage |
| "Archive data, rarely accessed" | S3 Glacier Deep Archive | $0.00099/GB/month |
| "Archive data, occasional fast retrieval" | S3 Glacier Instant Retrieval | Millisecond retrieval, cheap storage |
| "Right-size instances" | AWS Compute Optimizer + CloudWatch | Data-driven downsizing |
| "Reduce compute cost, ARM compatible" | Graviton instances | 40% better price-performance |
| "Spot but need some guaranteed capacity" | Spot Fleet with On-Demand base | Mix of Spot + On-Demand |
| "Multi-region, minimize transfer cost" | CloudFront + S3 Cross-Region Replication | Edge caching + local copies |
| "Dev/test database, minimize cost" | RDS Single-AZ, stop overnight | No Multi-AZ, stop = no compute charge |
| "Log storage, sequential access, cheap" | S3 or st1 (throughput HDD) | Cheapest for sequential |
| "Minimize Lambda cost" | Optimize memory (affects CPU too), reduce duration | Pay per GB-second |
| "Reduce API Gateway costs" | CloudFront caching in front | Fewer invocations |
| "Cost allocation & visibility" | AWS Cost Explorer + Cost Allocation Tags | Track spend by team/project |
| "Billing alerts" | AWS Budgets + CloudWatch Billing Alarms | Get warned before overspend |

---

## 6. Cost Comparison Tables

### Compute: Monthly Cost for a Steady Workload (~equivalent to m5.large 24/7)

| Option | Monthly Cost | Savings vs On-Demand | Commitment |
|---|---|---|---|
| On-Demand | ~$70 | 0% | None |
| 1yr No Upfront RI | ~$45 | ~36% | 1 year |
| 1yr All Upfront RI | ~$42 | ~40% | 1 year + cash |
| 3yr All Upfront RI | ~$20 | ~72% | 3 years + cash |
| Spot (avg) | ~$21 | ~70% | None (can be interrupted) |
| Savings Plan (1yr) | ~$42 | ~40% | 1 year $/hr |

### Storage: Cost per TB per Month

| Storage Type | $/TB/month | Retrieval | Best For |
|---|---|---|---|
| S3 Standard | $23.00 | Instant, free | Hot data |
| S3 Standard-IA | $12.50 | Instant, $10/TB | Infrequent but needs fast access |
| S3 One Zone-IA | $10.00 | Instant, $10/TB | Non-critical infrequent data |
| S3 Glacier Instant | $4.00 | Instant, $30/TB | Quarterly access, fast retrieval |
| S3 Glacier Flexible | $3.60 | Minutes-12hrs, $30/TB | Annual access |
| S3 Deep Archive | $0.99 | 12-48hrs, $20/TB | Compliance archives |
| EBS gp3 | $80.00 | Instant (attached) | Boot volumes, databases |
| EBS st1 | $45.00 | Instant (attached) | Big data, logs |
| EFS Standard | $300.00 | Instant | Shared file system |
| EFS IA | $25.00 | Instant | Shared files, infrequent |

### Database: Relative Cost for Similar Workloads

| Option | Relative Cost | Management | Best For |
|---|---|---|---|
| RDS On-Demand | $$$$ | Medium | Quick setup, unknown duration |
| RDS Reserved (1yr) | $$$ | Medium | Steady production workloads |
| Aurora Provisioned | $$$$ | Low | High performance, Auto Scaling reads |
| Aurora Serverless v2 | $$ - $$$$ | Very Low | Variable workloads |
| DynamoDB On-Demand | $$ | Very Low | Unpredictable NoSQL |
| DynamoDB Provisioned | $ | Low | Steady NoSQL |
| ElastiCache | $$ | Low | Caching layer (reduces DB costs) |

---

## 7. Cost Tools & Services

| Tool | What It Does | Exam Keyword |
|---|---|---|
| AWS Cost Explorer | Visualize, forecast, analyze spend | "Analyze spending trends" |
| AWS Budgets | Set spending limits + alerts | "Alert when budget exceeded" |
| Cost Allocation Tags | Tag resources by team/project/env | "Track costs per department" |
| Trusted Advisor | Recommends cost savings (underutilized resources) | "Identify unused resources" |
| Compute Optimizer | Right-sizing recommendations | "Optimal instance type" |
| Savings Plans | Flexible committed discounts | "Flexible compute discount" |
| AWS Pricing Calculator | Estimate costs before deploying | "Estimate monthly cost" |
| Cost and Usage Report (CUR) | Most detailed billing data (to S3) | "Detailed billing analysis" |

---

## 8. Exam Traps — Cost Questions

1. **"Cheapest" without meeting requirements = WRONG ANSWER.** Always check requirements first.

2. **Spot for databases = WRONG.** Databases are stateful. Spot can terminate anytime.

3. **gp2 is never the right answer when gp3 is an option.** gp3 is cheaper AND has better baseline performance.

4. **"Serverless" doesn't always mean cheapest.** Lambda at massive scale can cost more than EC2. Fargate at steady high load costs more than EC2 launch type.

5. **Reserved Instances are NOT transferable across regions.** If the question says "multi-region" → Savings Plans (which are region-flexible).

6. **S3 IA has a minimum storage duration charge (30 days).** Storing a file for 1 day in IA still charges for 30 days. Don't move short-lived objects to IA.

7. **S3 Glacier retrieval is NOT instant** (except Glacier Instant Retrieval tier). If the question needs data "within minutes" → Glacier Instant Retrieval or Glacier Flexible with Expedited retrieval.

8. **NAT Gateway is per-AZ.** 3 AZs = 3 NAT Gateways = 3x the cost. For dev/test, one NAT Gateway is acceptable.

9. **Data transfer IN is free.** Only outbound costs money. Don't choose "reduce inbound transfer" — that's not a real cost.

10. **CloudFront can be cheaper than direct S3.** For popular content, CloudFront's per-GB price is lower than S3 direct transfer. Plus it caches, reducing S3 GET request costs.

---

## Summary Mental Model

```
COST OPTIMIZATION = The Treasury Department

Question: "How do we reduce the country's expenses?"

Step 1: Are we paying for things we're not using?
        → Delete unattached EBS, idle Load Balancers, unused Elastic IPs

Step 2: Are we paying full price when we could get a discount?
        → Reserved Instances, Savings Plans, Spot where possible

Step 3: Are we using the most expensive option when a cheaper one works?
        → gp3 over gp2, S3 lifecycle, right-size instances

Step 4: Are we paying for data transfer we could avoid?
        → VPC Endpoints, same-AZ placement, CloudFront caching

Step 5: Are we managing things we could let AWS manage?
        → Serverless (Lambda, Fargate, Aurora Serverless) = less ops cost
```
