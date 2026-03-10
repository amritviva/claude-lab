# SAA-C03 Solutions Architect Associate -- Gotchas & Ace Sheet

> **The Country Analogy:** You're the **city planner** of AWS-land. Your job is to design
> resilient, cost-effective infrastructure for the citizens (users). Every question asks:
> "What's the best blueprint for this city district?"

---

## Exam Profile

| Detail | Value |
|--------|-------|
| Code | SAA-C03 |
| Questions | 65 (50 scored + 15 unscored) |
| Time | 130 minutes (~2 min/question) |
| Passing | 720 / 1000 |
| Format | Multiple choice + multiple response |
| Cost | $150 USD |

---

## Domain Breakdown

| # | Domain | Weight | What It ACTUALLY Tests |
|---|--------|--------|----------------------|
| 1 | Secure Architectures | 30% | IAM policies, encryption at rest/transit, VPC network isolation, multi-account strategy, least privilege. "Who's allowed through the border?" |
| 2 | Resilient Architectures | 26% | Multi-AZ, Auto Scaling, decoupling with SQS/SNS, backup/restore, disaster recovery strategies (Pilot Light, Warm Standby, Active-Active). "What happens when a city district floods?" |
| 3 | High-Performing Architectures | 24% | Right compute/storage/DB for the workload, caching strategies, read replicas, CloudFront, Global Accelerator. "How do you handle rush hour?" |
| 4 | Cost-Optimized Architectures | 20% | Right-sizing, Reserved vs Spot vs On-Demand, storage tiering, data transfer costs, S3 lifecycle policies. "How do you run the city on budget?" |

---

## Top 30 SAA Gotchas

These are the traps that separate 700 from 800. Read each one carefully.

### Gotcha 1: "Most Cost-Effective" != Cheapest

"Most cost-effective" means **cheapest option that actually meets ALL requirements**. If the question says "high availability" and the cheapest option is single-AZ, that answer is WRONG even though it's cheaper. Cost-effective = works + affordable.

### Gotcha 2: "Least Operational Overhead" = Managed/Serverless

When they say "least operational overhead," they're telling you to pick the AWS-managed option. Self-managed EC2 < RDS < Aurora Serverless. Lambda < ECS on EC2 < ECS on Fargate. Always pick the option where AWS does more work.

### Gotcha 3: ACM Certificates for CloudFront MUST Be in us-east-1

CloudFront is a global service, but its SSL certificates from ACM **must** be created in `us-east-1` (N. Virginia). This is a favourite trick question. For ALB/NLB, the cert must be in the same region as the load balancer.

### Gotcha 4: S3 Glacier Retrieval Times

| Tier | Time | Cost |
|------|------|------|
| Expedited | 1-5 minutes | $$$ |
| Standard | 3-5 hours | $$ |
| Bulk | 5-12 hours | $ |

Glacier Deep Archive: Standard = 12 hours, Bulk = 48 hours. If the question says "within minutes," only Expedited works. If it says "within hours," Standard is fine.

### Gotcha 5: Multi-AZ RDS != Read Replicas

They test this constantly:
- **Multi-AZ** = high availability (failover). Standby is NOT readable. Like having a backup power plant that only kicks in during a blackout.
- **Read Replicas** = scaling reads. Can be in different regions. Used for read-heavy workloads. Like building branch libraries so not everyone crowds the main one.

You can have BOTH. Multi-AZ for HA + Read Replicas for performance.

### Gotcha 6: NACLs Are Stateless, Security Groups Are Stateful

- **NACLs** (Network ACLs) = border checkpoints. Stateless -- you need BOTH inbound AND outbound rules. If you allow inbound port 80, you must also allow outbound ephemeral ports (1024-65535) for the response.
- **Security Groups** = building security. Stateful -- if inbound is allowed, the return traffic is automatically allowed.

Think: NACL = "papers please, both ways." SG = "if I let you in, I'll let your reply out."

### Gotcha 7: VPC Peering Is NOT Transitive

If VPC-A peers with VPC-B, and VPC-B peers with VPC-C, VPC-A **cannot** reach VPC-C through B. You need a direct peering connection or use Transit Gateway. Transit Gateway = the country's central train station -- everything connects through it.

### Gotcha 8: Aurora vs RDS Replica Limits

- **Aurora**: up to 15 read replicas, auto-scaling, single shared storage volume
- **RDS**: up to 5 read replicas, each with its own storage

If the question mentions "15 read replicas" or "auto-scaling replicas," it's Aurora.

### Gotcha 9: EBS io2 Block Express = 256,000 IOPS

When the question says "highest possible IOPS" or "mission-critical database needing maximum performance":
- gp3: up to 16,000 IOPS
- io1: up to 64,000 IOPS
- io2: up to 64,000 IOPS
- **io2 Block Express**: up to **256,000 IOPS** (Nitro instances only)
- Instance Store: potentially millions of IOPS but ephemeral

### Gotcha 10: Route 53 Alias Records vs CNAME

- **Alias**: works at **zone apex** (naked domain: `example.com`), free, AWS-native
- **CNAME**: does NOT work at zone apex, costs money per query

If the question mentions "zone apex" or "naked domain," the answer is Alias record.

### Gotcha 11: S3 Transfer Acceleration vs CloudFront

- **Transfer Acceleration**: optimises **uploads** to S3 using edge locations
- **CloudFront**: optimises **downloads** from S3 (caching at edge)

Upload question = Transfer Acceleration. Download question = CloudFront.

### Gotcha 12: NAT Gateway vs NAT Instance

- **NAT Gateway**: managed, scales automatically, HA within AZ, no security groups
- **NAT Instance**: self-managed EC2, manual scaling, must disable source/dest check

Exam almost always wants NAT Gateway (least operational overhead). NAT Instance only if they specifically say "lowest cost" for tiny workloads.

### Gotcha 13: Direct Connect Is NOT Encrypted by Default

Direct Connect provides a **private** connection but it's NOT encrypted. For encryption over DX:
- Use a **VPN connection over Direct Connect** (IPsec)
- Or use **MACsec** (Layer 2 encryption, only on dedicated connections)

If question says "private AND encrypted," DX alone is wrong. DX + VPN is the answer.

### Gotcha 14: Global Accelerator vs CloudFront

- **CloudFront**: HTTP/HTTPS content caching at edge locations. Think CDN.
- **Global Accelerator**: TCP/UDP traffic routing to optimal endpoint via AWS backbone. No caching. Think "fast lane on the highway."

Non-HTTP protocol? Global Accelerator. Gaming, IoT, VoIP? Global Accelerator. Static website? CloudFront.

### Gotcha 15: EFS Is Linux Only

- **EFS** (Elastic File System): NFS protocol, Linux only. Shared across instances.
- **FSx for Windows**: SMB protocol, Windows. Active Directory integration.
- **FSx for Lustre**: high-performance computing (HPC), ML training.

Windows in the question = FSx for Windows. HPC/ML = FSx for Lustre. Everything else = EFS.

### Gotcha 16: S3 Consistency Model

S3 now provides **strong read-after-write consistency** for all operations (PUTs and DELETEs). This changed in 2020. Old exam tips about "eventual consistency for overwrite PUTs" are outdated. But the exam may still test that you know it's strongly consistent.

### Gotcha 17: Kinesis vs SQS for Streaming

- **Kinesis**: real-time streaming, multiple consumers read same data, data retained 24hr-365 days, ordering within shard
- **SQS**: message queue, one consumer per message (unless SNS fan-out), no replay

"Real-time analytics" or "multiple consumers" = Kinesis. "Decouple microservices" or "one-time processing" = SQS.

### Gotcha 18: S3 Bucket Policies vs IAM Policies

- **IAM Policy**: attached to user/role. "What can this person do?"
- **Bucket Policy**: attached to bucket. "Who can access this bucket?"
- **Cross-account access**: need BOTH -- bucket policy allows + IAM policy allows
- **Same account**: either one granting access is enough (unless explicit deny)

### Gotcha 19: Lambda@Edge vs CloudFront Functions

- **CloudFront Functions**: lightweight (JS only), viewer request/response only, sub-millisecond, 10KB max
- **Lambda@Edge**: heavier (Node.js/Python), all 4 trigger points, up to 30s, 10MB max

Simple header manipulation = CloudFront Functions. Complex logic = Lambda@Edge.

### Gotcha 20: Placement Groups

- **Cluster**: all instances in same rack. Lowest latency. HPC. Single AZ.
- **Spread**: each instance on different hardware. Max 7 per AZ. Critical instances.
- **Partition**: groups of instances on different racks. Big distributed systems (HDFS, Cassandra).

### Gotcha 21: S3 Storage Class Transitions

S3 lifecycle rules can only transition **downward** in this order:
```
S3 Standard → S3 Standard-IA → S3 One Zone-IA → S3 Glacier Instant → S3 Glacier Flexible → S3 Glacier Deep Archive
```
Minimum 30 days before transitioning from Standard to IA classes. Objects < 128KB are never transitioned to IA (charged minimum 128KB).

### Gotcha 22: ElastiCache -- Redis vs Memcached

- **Redis**: persistence, replication, pub/sub, complex data types, Multi-AZ, backup/restore, single-threaded
- **Memcached**: simple key-value, multi-threaded, no persistence, no replication

"Session store with failover" = Redis. "Simple caching, multi-threaded" = Memcached. When in doubt, Redis.

### Gotcha 23: Cross-Region Replication (CRR) vs Same-Region Replication (SRR)

- **CRR**: compliance, lower latency access, cross-account replication
- **SRR**: log aggregation, live replication between prod/test accounts

Both require **versioning enabled** on source AND destination buckets.

### Gotcha 24: Auto Scaling Policies

- **Target Tracking**: "Keep CPU at 50%." Simplest. Exam loves this.
- **Step Scaling**: different actions at different alarm thresholds
- **Simple Scaling**: one action per alarm, has cooldown period (legacy)
- **Scheduled**: known traffic patterns (e.g., 9am spike every weekday)

"Maintain metric at X" = Target Tracking. "Different actions at different thresholds" = Step Scaling.

### Gotcha 25: AWS Organizations -- Consolidated Billing Gotchas

- Reserved Instances and Savings Plans are shared across the organization
- Volume discounts aggregate across all accounts
- **SCPs** restrict permissions but don't GRANT them
- SCPs affect all users including root in member accounts, but NOT the management account

### Gotcha 26: EventBridge vs SNS

- **SNS**: pub/sub, push notifications, SMS/email/HTTP, simple fan-out
- **EventBridge**: event bus with content-based filtering, schema registry, 3rd party sources, event replay

"React to AWS service events" = EventBridge. "Send notifications" = SNS. "Complex event routing with filtering" = EventBridge.

### Gotcha 27: VPC Endpoints -- Gateway vs Interface

- **Gateway Endpoint**: S3 and DynamoDB only. Free. Route table entry. Like a dedicated express lane in the country's highway system.
- **Interface Endpoint** (PrivateLink): all other services. Creates ENI in your subnet. Costs money per hour + data processed.

### Gotcha 28: Database Migration Service (DMS)

- DMS handles heterogeneous migrations (Oracle to Aurora, SQL Server to PostgreSQL)
- **Schema Conversion Tool (SCT)** converts the schema first
- DMS supports continuous replication (CDC -- Change Data Capture)
- Source database remains fully operational during migration (zero downtime)

### Gotcha 29: AWS Backup vs Native Snapshots

- **AWS Backup**: centralized, cross-service, cross-account, cross-region, policy-based
- **Native snapshots** (EBS, RDS): per-service, manual or scheduled

"Centralized backup across all services" = AWS Backup. Not just EBS snapshots.

### Gotcha 30: S3 Object Lock

- **Governance Mode**: users with special permissions can delete/overwrite
- **Compliance Mode**: NOBODY can delete, not even root, until retention expires
- **Legal Hold**: independent of retention period, on/off toggle

"Regulatory compliance, immutable" = Compliance Mode. "Protect but allow admin override" = Governance Mode.

---

## "When They Say X, The Answer Is Y" Quick-Fire List

| When They Say... | The Answer Is... |
|------------------|-----------------|
| "Decouple components" | SQS (or SNS + SQS fan-out) |
| "Serverless" | Lambda + API Gateway + DynamoDB + S3 |
| "Least operational overhead" | Managed service (Fargate, Aurora Serverless, Lambda) |
| "Cost-effective archival" | S3 Glacier Deep Archive |
| "Sub-millisecond reads from database" | ElastiCache (Redis) or DynamoDB DAX |
| "Global users, low latency" | CloudFront + S3 (static) or Global Accelerator (dynamic) |
| "Shared file storage across EC2" | EFS (Linux) or FSx for Windows |
| "Temporary high-performance storage" | EC2 Instance Store |
| "Cross-region disaster recovery" | Pilot Light or Warm Standby (depends on RTO) |
| "Fully managed relational DB, Aurora compatible" | Aurora Serverless |
| "HIPAA / PCI / compliance" | Check encryption, VPC, CloudTrail, Config, Macie |
| "Petabyte-scale analytics" | Redshift |
| "Real-time data streaming" | Kinesis Data Streams |
| "Batch processing big data" | EMR (Hadoop/Spark) |
| "Container orchestration, least overhead" | ECS on Fargate |
| "Prevent accidental deletion" | S3 Versioning + MFA Delete, or Object Lock |
| "Private subnet needs internet" | NAT Gateway |
| "On-premises to AWS, private connection" | Direct Connect |
| "Millisecond response from DynamoDB" | DAX (DynamoDB Accelerator) |
| "Static website hosting" | S3 + CloudFront |
| "Restrict access to S3 from CloudFront only" | Origin Access Control (OAC) |
| "Run code on schedule" | EventBridge rule + Lambda |
| "Message ordering guaranteed" | SQS FIFO |
| "Multiple AWS accounts, centralized management" | AWS Organizations |
| "Centralized logging" | CloudWatch Logs + S3 (via Kinesis Firehose) |

---

## Well-Architected Framework -- 6 Pillars

Think of these as the **6 building codes** that every city plan must follow.

### 1. Operational Excellence (OPS)
The country's **operations manual**. How you run and monitor systems.
- Infrastructure as Code (CloudFormation, CDK)
- Automated deployments (CodePipeline, CodeDeploy)
- Observability (CloudWatch, X-Ray)
- Small, frequent, reversible changes
- Learn from operational failures

### 2. Security (SEC)
The country's **defense ministry**. Protect data, systems, and assets.
- Least privilege (IAM policies, SCPs)
- Encryption at rest and in transit
- Enable traceability (CloudTrail, Config)
- Automate security best practices
- Protect data in transit and at rest
- Prepare for security events (incident response)

### 3. Reliability (REL)
The country's **disaster preparedness**. Recover from failure, meet demand.
- Auto Scaling, Multi-AZ, Multi-Region
- Test recovery procedures
- Scale horizontally
- Stop guessing capacity
- Manage change through automation

### 4. Performance Efficiency (PERF)
The country's **transportation system**. Use resources efficiently.
- Right-size instances
- Use serverless where possible
- Go global in minutes (CloudFront, Global Accelerator)
- Experiment more often
- Use managed services to offload operational burden

### 5. Cost Optimization (COST)
The country's **budget office**. Avoid unnecessary spending.
- Pay only for what you use
- Reserved capacity for steady-state
- Spot for fault-tolerant workloads
- Measure efficiency (Cost Explorer, Budgets)
- Analyze and attribute expenditure

### 6. Sustainability (SUS)
The country's **green energy policy**. Minimize environmental impact.
- Understand your impact
- Maximize utilization
- Use managed/serverless (shared infrastructure is more efficient)
- Reduce downstream impact

---

## Architecture Decision Trees

### Which Storage?

```
Need block storage for EC2?
├── Yes: Persistent?
│   ├── Yes: High IOPS (>16K)?
│   │   ├── Yes → io2 Block Express (up to 256K IOPS)
│   │   └── No → gp3 (baseline 3K IOPS, up to 16K)
│   └── No → Instance Store (ephemeral, highest I/O)
└── No: Shared across instances?
    ├── Yes: Linux?
    │   ├── Yes → EFS
    │   └── No: Windows?
    │       ├── Yes → FSx for Windows
    │       └── HPC/ML → FSx for Lustre
    └── No: Object storage?
        └── Yes → S3
            ├── Frequent access → S3 Standard
            ├── Infrequent access → S3 Standard-IA
            ├── One AZ ok? → S3 One Zone-IA
            ├── Archive (minutes retrieval) → Glacier Instant Retrieval
            ├── Archive (hours retrieval) → Glacier Flexible Retrieval
            └── Archive (12+ hours ok) → Glacier Deep Archive
```

### Which Database?

```
Relational data?
├── Yes: Need Aurora features (15 replicas, auto-scaling storage)?
│   ├── Yes: Unpredictable workload?
│   │   ├── Yes → Aurora Serverless
│   │   └── No → Aurora Provisioned
│   └── No: Simple relational workload
│       └── RDS (MySQL, PostgreSQL, MariaDB, Oracle, SQL Server)
└── No: What kind of data?
    ├── Key-value / document → DynamoDB
    │   └── Need sub-ms reads? → DynamoDB + DAX
    ├── In-memory caching → ElastiCache
    │   ├── Persistence needed? → Redis
    │   └── Simple cache, multi-thread → Memcached
    ├── Graph data → Neptune
    ├── Time series → Timestream
    ├── Ledger / immutable → QLDB
    ├── Wide column (Cassandra) → Keyspaces
    └── Data warehouse / analytics → Redshift
```

### Which Compute?

```
Need a server running 24/7?
├── Yes: Need full OS control?
│   ├── Yes → EC2
│   │   ├── Steady-state → Reserved Instances or Savings Plans
│   │   ├── Fault-tolerant → Spot Instances
│   │   └── Short-term / unpredictable → On-Demand
│   └── No: Containerised?
│       ├── Yes: Manage cluster yourself?
│       │   ├── Yes → ECS on EC2 or EKS on EC2
│       │   └── No → ECS on Fargate or EKS on Fargate
│       └── No → consider Lambda or Lightsail
└── No: Event-driven / short-lived?
    ├── Yes: < 15 minutes?
    │   ├── Yes → Lambda
    │   └── No → Fargate task or Step Functions + Lambda
    └── No: Batch processing?
        └── Yes → AWS Batch
```

### Which Load Balancer?

```
What protocol?
├── HTTP/HTTPS (Layer 7)?
│   └── ALB (Application Load Balancer)
│       - Path-based routing (/api, /images)
│       - Host-based routing (api.example.com)
│       - Lambda targets
│       - WebSocket support
│       - Authentication (Cognito, OIDC)
├── TCP/UDP/TLS (Layer 4)?
│   └── NLB (Network Load Balancer)
│       - Ultra-low latency
│       - Static IP / Elastic IP
│       - Millions of requests/sec
│       - Preserve source IP
│       - VPN / Direct Connect targets
└── Traffic inspection (3rd party appliances)?
    └── GWLB (Gateway Load Balancer)
        - Firewalls, IDS/IPS
        - Layer 3 (IP packets)
        - GENEVE protocol
```

---

## Exam Day Quick Reminders

1. **Read the LAST sentence first** -- that's where the actual question is
2. **Eliminate obviously wrong answers** -- usually 2 are clearly wrong
3. **"Most" and "least" are your enemy** -- all options might work, pick the BEST fit
4. **Flag and move on** -- don't spend >3 min on any question
5. **No penalty for guessing** -- never leave a blank
6. **Time check**: by Q30 you should have ~65 min left
7. **AWS wants you to pick their managed services** -- when in doubt, go managed
