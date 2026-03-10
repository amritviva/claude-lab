# 21 — HA, FT & DR: Emergency Resilience

> **One-liner:** HA is more hospitals so the system stays up, FT is backup generators so there's zero downtime, and DR is evacuation blueprints so you can rebuild after catastrophe.

---

## ELI10

Imagine your country has three ways to deal with emergencies. **High Availability (HA)** means building multiple hospitals — if one closes, patients go to another. There might be a short wait while the ambulance redirects, but care continues. **Fault Tolerance (FT)** means every hospital has a backup generator — when power goes out, the lights stay on instantly. Zero interruption. **Disaster Recovery (DR)** means having evacuation blueprints stored in another city — if a hurricane destroys everything, you can rebuild the entire hospital system using those blueprints. HA keeps things running, FT prevents any flicker, and DR helps you come back from the worst.

---

## The Concept

### HA vs FT vs DR — The Critical Distinction

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  HIGH AVAILABILITY (HA)                                              │
│  "More hospitals"                                                    │
│                                                                      │
│  Goal: System stays UP despite component failures                    │
│  Accepts: Brief interruption during failover                        │
│  Example: RDS Multi-AZ (30-60 second failover)                     │
│  Cost: Moderate (run redundant resources)                            │
│                                                                      │
│  ─────────────────────────────────────────────────────               │
│                                                                      │
│  FAULT TOLERANCE (FT)                                                │
│  "Backup generators"                                                 │
│                                                                      │
│  Goal: ZERO downtime, ZERO data loss during failure                 │
│  Accepts: Nothing — no interruption allowed                          │
│  Example: S3 (data replicated across 3+ AZs, always accessible)    │
│  Cost: Higher (active-active, full redundancy)                      │
│                                                                      │
│  ─────────────────────────────────────────────────────               │
│                                                                      │
│  DISASTER RECOVERY (DR)                                              │
│  "Evacuation blueprints"                                             │
│                                                                      │
│  Goal: Recover after catastrophic failure                            │
│  Accepts: Downtime during recovery (RTO)                            │
│  Accepts: Some data loss (RPO)                                      │
│  Example: Cross-region S3 replication + CloudFormation templates     │
│  Cost: Varies (from cheap backups to expensive multi-site)          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

KEY EXAM FACT:
  HA ≠ FT!
  HA = "we'll be back shortly" (seconds to minutes)
  FT = "you'll never know anything happened" (zero interruption)
  DR = "we can rebuild" (minutes to hours)
```

### RPO and RTO — The Two Critical Metrics

```
                    Disaster
                    Strikes
                       │
  ◄────── RPO ────────►│◄──────── RTO ──────────►
                        │
  Last good             │              System fully
  backup/snapshot       │              operational again
                        │
  ┌─────────────────────┼──────────────────────────┐
  │   DATA LOSS ZONE    │    DOWNTIME ZONE          │
  │   (what you lose)   │    (how long recovery)    │
  └─────────────────────┴──────────────────────────┘

  RPO = Recovery Point Objective
        "How much data can we afford to lose?"
        RPO = 1 hour → you lose at most 1 hour of data
        RPO = 0 → zero data loss (synchronous replication)

  RTO = Recovery Time Objective
        "How fast must we be back up?"
        RTO = 4 hours → must be running within 4 hours
        RTO = 0 → instant failover (fault tolerant)
```

---

## The Four DR Strategies

```
    Cost ──────────────────────────────────────────────────→
    Low $$                                            High $$$$$

    RTO ───────────────────────────────────────────────────→
    Hours                                            Seconds

┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  BACKUP &    │ │  PILOT       │ │  WARM        │ │  MULTI-SITE  │
│  RESTORE     │ │  LIGHT       │ │  STANDBY     │ │  ACTIVE/     │
│              │ │              │ │              │ │  ACTIVE      │
│  Blueprints  │ │  Skeleton    │ │  Smaller     │ │  Full copy   │
│  in storage  │ │  crew on     │ │  version     │ │  everywhere  │
│              │ │  standby     │ │  always       │ │              │
│  RTO: hours  │ │  RTO: 10s    │ │  running     │ │  RTO: near   │
│  RPO: hours  │ │  of minutes  │ │              │ │  zero        │
│              │ │  RPO: minutes│ │  RTO: minutes│ │  RPO: near   │
│  Cheapest    │ │              │ │  RPO: seconds│ │  zero        │
│              │ │              │ │              │ │              │
│              │ │              │ │              │ │  Most        │
│              │ │              │ │              │ │  expensive   │
└──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
```

### Strategy 1: Backup & Restore

```
Normal Operations:                     Disaster Recovery:
┌───────────────────┐                 ┌───────────────────┐
│  Production        │                 │  Restore from      │
│  Region A          │                 │  backups in         │
│                    │                 │  Region B           │
│  Daily backups ───→│── S3 CRR ──→   │                    │
│  RDS snapshots ───→│── Copy ────→   │  Launch new infra  │
│  AMI copies ──────→│── Copy ────→   │  from CloudFormation│
│                    │                 │  Restore DB from    │
│                    │                 │  snapshot            │
└───────────────────┘                 └───────────────────┘

Cost: Very low (just storage for backups)
RTO: Hours (restore DB, launch instances, configure)
RPO: Hours (depends on backup frequency)

Best for: Non-critical environments, cost-sensitive workloads
```

### Strategy 2: Pilot Light

```
Normal Operations:                     Disaster Recovery:
┌───────────────────┐                 ┌───────────────────┐
│  Production        │                 │  DR Region          │
│  Region A          │                 │                    │
│  (Full fleet)      │                 │  RDS read replica  │
│                    │  Replication    │  (already running!) │
│  EC2 fleet ───────→│                 │                    │
│  RDS primary ─────→│── Async ──────→│  ── Promote to     │
│  App servers ─────→│  replication   │     primary         │
│                    │                 │  ── Launch EC2      │
│                    │                 │     fleet           │
│                    │                 │  ── Switch DNS      │
└───────────────────┘                 └───────────────────┘

Cost: Low-moderate (only core DB running in DR)
RTO: 10s of minutes (scale up compute, switch DNS)
RPO: Minutes (depends on replication lag)

"Pilot light" = the minimum core that must stay lit.
Like a gas stove's pilot light — tiny flame, turn up when needed.
```

### Strategy 3: Warm Standby

```
Normal Operations:                     Disaster Recovery:
┌───────────────────┐                 ┌───────────────────┐
│  Production        │                 │  DR Region          │
│  Region A          │                 │  (Smaller copy)     │
│                    │                 │                    │
│  10 EC2 instances  │  Replication   │  2 EC2 instances   │
│  RDS primary       │── Sync/Async ─→│  RDS replica       │
│  Full ALB          │                 │  Small ALB          │
│                    │                 │                    │
│                    │  On disaster:   │  Scale UP to full   │
│                    │ ──────────────→ │  10 EC2 instances   │
│                    │                 │  Promote RDS        │
│                    │                 │  Switch DNS          │
└───────────────────┘                 └───────────────────┘

Cost: Moderate (running smaller fleet 24/7)
RTO: Minutes (just scale up, already running)
RPO: Seconds to minutes (continuous replication)

"Warm standby" = scaled-down production clone, always running.
```

### Strategy 4: Multi-Site Active/Active

```
┌───────────────────┐                 ┌───────────────────┐
│  Region A          │                 │  Region B          │
│  (Full production) │                 │  (Full production) │
│                    │                 │                    │
│  10 EC2 instances  │◄── Sync/Async─→│  10 EC2 instances  │
│  RDS primary       │  replication   │  RDS primary       │
│  Full ALB          │                 │  Full ALB          │
│                    │                 │                    │
│  Route 53: 50%     │                 │  Route 53: 50%     │
│  traffic           │                 │  traffic           │
└───────────────────┘                 └───────────────────┘

Route 53 distributes traffic to BOTH regions simultaneously.
If Region A fails, Route 53 sends 100% to Region B.
No failover needed — B is already handling production traffic.

Cost: Highest (full infrastructure in both regions)
RTO: Near-zero (already serving traffic)
RPO: Near-zero (synchronous or near-synchronous replication)

Best for: Mission-critical applications (banking, healthcare, trading)
```

---

## Key AWS Services for Each Pattern

### Multi-AZ (High Availability Within a Region)

```
┌────────────────────────────────────────────────────────────────┐
│                  MULTI-AZ SERVICES                              │
│                                                                  │
│  Service              Multi-AZ Behavior                         │
│  ──────────────────   ──────────────────────────────────────    │
│  RDS Multi-AZ         Synchronous standby, auto-failover        │
│                       (30-60 sec). Standby = NOT readable.      │
│                                                                  │
│  Aurora               Up to 15 read replicas across 3 AZs.     │
│                       Auto-failover in < 30 seconds.            │
│                       Multi-AZ by default.                       │
│                                                                  │
│  ElastiCache          Redis cluster mode: shards across AZs.   │
│                       Multi-AZ with auto-failover.              │
│                                                                  │
│  EFS                  Multi-AZ by default (replicated across    │
│                       AZs automatically).                        │
│                                                                  │
│  S3                   Multi-AZ by default (3+ AZs).             │
│                       11 nines durability.                       │
│                                                                  │
│  DynamoDB             Multi-AZ by default (3 AZs).              │
│                       Synchronous replication.                   │
│                                                                  │
│  ALB/NLB              Cross-zone load balancing across AZs.     │
│                                                                  │
│  EC2 Auto Scaling     Spread instances across multiple AZs.     │
│                       If one AZ goes down, ASG launches in       │
│                       remaining AZs.                             │
└────────────────────────────────────────────────────────────────┘
```

### Multi-Region (Disaster Recovery)

```
┌────────────────────────────────────────────────────────────────┐
│                  MULTI-REGION SERVICES                           │
│                                                                  │
│  Service              Multi-Region Feature                      │
│  ──────────────────   ──────────────────────────────────────    │
│  Route 53             Failover routing policy.                  │
│                       Health checks → auto-switch to DR region. │
│                                                                  │
│  S3 CRR               Cross-Region Replication.                 │
│                       Async replication to another region.       │
│                                                                  │
│  RDS Cross-Region     Read replicas in other regions.           │
│  Read Replica         Promote to primary for DR.                │
│                       (Async replication — some data lag)        │
│                                                                  │
│  Aurora Global DB     1-second replication lag.                  │
│                       Up to 5 secondary regions.                 │
│                       Promote secondary in < 1 minute.          │
│                                                                  │
│  DynamoDB Global      Active-active across regions.              │
│  Tables               Replication < 1 second.                   │
│                       Write to any region.                       │
│                                                                  │
│  CloudFormation       Deploy same template in DR region.         │
│  StackSets            Identical infrastructure across regions.   │
│                                                                  │
│  KMS Multi-Region     Same encryption key across regions         │
│  Keys                 (needed for encrypted cross-region data).  │
│                                                                  │
│  CloudFront           Global CDN (inherently multi-region).      │
│                                                                  │
│  Global Accelerator   Route to optimal region via AWS backbone.  │
└────────────────────────────────────────────────────────────────┘
```

---

## Route 53 Failover

```
                    Route 53
                    (DNS Traffic Cop)
                        │
                        │ Health Check
                        │ (every 30s or 10s)
                        │
            ┌───────────┴───────────┐
            │                       │
      PRIMARY (Healthy?)      SECONDARY (DR)
      Region A                Region B
            │                       │
      ┌─────┴─────┐          ┌─────┴─────┐
      │   ALB     │          │   ALB     │
      │  Healthy  │          │  Standby  │
      └───────────┘          └───────────┘

  If Primary fails health check (3 consecutive failures):
  Route 53 automatically switches DNS to Secondary.
  TTL determines how fast clients switch (set low for fast failover).
```

**Route 53 health check types:**
- **Endpoint health check** — checks a specific endpoint (URL, IP, port)
- **Calculated health check** — combines results from multiple health checks (AND/OR)
- **CloudWatch alarm health check** — uses a CloudWatch alarm state

---

## RDS Multi-AZ vs Read Replica for DR

```
┌─────────────────────────────────┬──────────────────────────────────┐
│     RDS MULTI-AZ                │     RDS READ REPLICA             │
│     (HA within region)          │     (DR across regions)           │
│                                 │                                    │
│  Purpose: Automatic failover    │  Purpose: Scale reads + DR         │
│  Replication: Synchronous       │  Replication: Asynchronous         │
│  Standby: NOT readable          │  Replica: IS readable              │
│  Failover: Automatic (30-60s)   │  Promotion: Manual (minutes)      │
│  Regions: Same region only      │  Regions: Same or cross-region    │
│  Data loss: None (sync)         │  Data loss: Possible (async lag)  │
│                                 │                                    │
│  Use for: HA in production      │  Use for: DR + read scaling       │
└─────────────────────────────────┴──────────────────────────────────┘

Common pattern:
  Multi-AZ (HA) + Cross-Region Read Replica (DR)
  = Best of both worlds
```

---

## Decision Matrix: Which Strategy?

```
┌──────────────────┬───────────┬───────────┬───────────┬──────────────┐
│ Factor            │ Backup &  │ Pilot     │ Warm      │ Multi-Site   │
│                   │ Restore   │ Light     │ Standby   │ Active/Active│
├──────────────────┼───────────┼───────────┼───────────┼──────────────┤
│ RTO               │ Hours     │ 10s min   │ Minutes   │ Near-zero    │
│ RPO               │ Hours     │ Minutes   │ Seconds   │ Near-zero    │
│ Cost              │ $         │ $$        │ $$$       │ $$$$         │
│ Complexity        │ Low       │ Medium    │ High      │ Very High    │
│ DB running in DR? │ No        │ Yes (min) │ Yes       │ Yes (full)   │
│ Compute in DR?    │ No        │ No        │ Yes (min) │ Yes (full)   │
│ Auto failover?    │ No        │ No/Partial│ Partial   │ Yes          │
│ Handles traffic?  │ No        │ No        │ Can       │ Yes          │
├──────────────────┼───────────┼───────────┼───────────┼──────────────┤
│ Use case          │ Dev/test  │ Business  │ Business  │ Mission      │
│                   │ Non-crit  │ apps      │ critical  │ critical     │
└──────────────────┴───────────┴───────────┴───────────┴──────────────┘
```

### Pilot Light vs Warm Standby — The Exam Trap

```
PILOT LIGHT:
  ✓ Core DB running in DR
  ✗ No compute running in DR
  → On failover: Launch EC2/ECS, configure, switch DNS

WARM STANDBY:
  ✓ Core DB running in DR
  ✓ Compute running (but scaled down)
  → On failover: Scale UP compute, promote DB, switch DNS

Key difference: Is COMPUTE running in DR?
  Pilot Light = NO (just the database pilot flame)
  Warm Standby = YES (small but functional fleet)
```

---

## Architecture: Full DR Setup

```
┌──── Region A (Primary) ──────────────┐    ┌──── Region B (DR) ──────────────┐
│                                       │    │                                  │
│  Route 53 ─── Health Check ──────────┼───→│  Route 53 (failover record)     │
│       │                               │    │       │                          │
│  CloudFront                           │    │  CloudFront                      │
│       │                               │    │       │                          │
│  ALB ─── ASG (10 instances)          │    │  ALB ─── ASG (2 instances)      │
│       │                               │    │       │     (warm standby)       │
│  Aurora Primary ─── Replication ─────┼───→│  Aurora Secondary               │
│       │              (< 1 second)     │    │       │                          │
│  S3 Bucket ──── CRR ────────────────┼───→│  S3 Bucket (replica)            │
│                                       │    │                                  │
│  DynamoDB ──── Global Tables ────────┼───→│  DynamoDB (replica)             │
│                                       │    │                                  │
│  CloudFormation templates ───────────┼───→│  Same templates (StackSets)     │
│                                       │    │                                  │
└───────────────────────────────────────┘    └──────────────────────────────────┘

On disaster:
1. Route 53 health check detects failure
2. DNS fails over to Region B
3. ASG scales from 2 → 10 instances
4. Aurora secondary promoted to primary
5. DynamoDB Global Tables already active-active
6. S3 replica already has data
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- DR strategy selection based on RTO/RPO requirements
- Pilot Light vs Warm Standby (THE exam trap)
- Route 53 failover routing with health checks
- Multi-AZ for HA, Multi-Region for DR
- Aurora Global Database for cross-region DR
- DynamoDB Global Tables for active-active
- S3 CRR for data replication
- Cost vs availability trade-offs

### DVA-C02 (Developer)
- Understanding RPO/RTO definitions
- Multi-AZ vs Read Replica behavior
- How failover works in RDS
- S3 Cross-Region Replication configuration
- DynamoDB Global Tables for multi-region writes

### SOA-C02 (SysOps)
- Route 53 health check configuration
- RDS Multi-AZ failover monitoring
- Auto Scaling across AZs
- DR testing procedures (game days)
- Backup configuration and restore procedures
- CloudFormation for DR infrastructure
- Monitoring failover with CloudWatch alarms

---

## Key Numbers

| Item | Value |
|------|-------|
| RDS Multi-AZ failover time | **30-60 seconds** |
| Aurora failover time | **< 30 seconds** |
| Aurora Global DB replication | **< 1 second** lag |
| Aurora Global DB promotion | **< 1 minute** |
| DynamoDB Global Tables replication | **< 1 second** |
| S3 CRR replication | **Minutes** (async, most objects in 15 min) |
| Route 53 health check interval | **30 seconds** (standard), **10 seconds** (fast) |
| Route 53 failover threshold | **3 consecutive failures** (default) |
| S3 durability | **99.999999999%** (11 nines) |
| S3 availability | **99.99%** (Standard), **99.5%** (Standard-IA) |
| EBS availability | **99.999%** (io2 Block Express) |
| RDS Multi-AZ replication | **Synchronous** (zero data loss) |
| RDS Read Replica replication | **Asynchronous** (seconds of lag) |

---

## Cheat Sheet

- **HA ≠ FT!** HA accepts brief interruption, FT accepts NONE
- **RPO** = how much data you can lose. **RTO** = how fast you recover.
- **4 DR strategies** (cheapest to most expensive): Backup & Restore → Pilot Light → Warm Standby → Multi-Site Active/Active
- **Pilot Light** = only DB running in DR. **Warm Standby** = DB + scaled-down compute running.
- **Multi-AZ** = HA within a region. **Multi-Region** = DR across regions.
- **RDS Multi-AZ** = synchronous, auto-failover, standby NOT readable
- **RDS Read Replica** = asynchronous, manual promotion, IS readable, can be cross-region
- **Aurora Global** = < 1 second replication, < 1 minute promotion, up to 5 DR regions
- **DynamoDB Global Tables** = active-active, write to any region, < 1 second replication
- **S3 CRR** = cross-region, asynchronous, requires versioning on both buckets
- **Route 53 failover** = health checks + failover routing policy. Set low TTL for fast failover.
- **Auto Scaling across AZs** = if AZ fails, ASG launches in remaining AZs
- **CloudFormation StackSets** = deploy identical infra across regions for DR
- **KMS Multi-Region Keys** = needed when encrypted data is replicated cross-region
- **DR testing** = "game days" — simulate failure, test recovery, measure actual RTO/RPO
- **Most services are Multi-AZ by default:** S3, DynamoDB, EFS, Aurora
- **EC2 is NOT Multi-AZ by default** — you must use ASG across AZs
- **EBS is single-AZ** — for HA, use EBS snapshots or EFS
- **Backup & Restore** is the only DR strategy with no running resources in DR region
