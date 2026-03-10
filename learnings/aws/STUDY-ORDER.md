# The Exact Reading Order to Ace All 3 AWS Associate Exams

> **Target:** SAA-C03 (Solutions Architect), DVA-C02 (Developer), SOA-C02 (SysOps Administrator)
> **Timeline:** 8 weeks
> **Base path:** `~/Desktop/mrt_repo/claude-lab/learnings/aws/`

---

## Recommended Exam Order

| Order | Exam | Code | Why This Order |
|---|---|---|---|
| 1st | Solutions Architect Associate | SAA-C03 | Broadest coverage — builds the mental map for ALL services. Every other exam builds on this. |
| 2nd | Developer Associate | DVA-C02 | Deepens Lambda, API Gateway, DynamoDB, CI/CD, SDK — things you already touched in SAA. |
| 3rd | SysOps Administrator Associate | SOA-C02 | Deepens CloudWatch, SSM, Config, automation — operational depth on services you already know. |

**Why this order matters:** SAA gives you the 30,000-foot country map. DVA zooms into the developer districts. SOA zooms into the operations center. Going SysOps before Developer would mean learning monitoring tools for services you haven't deeply understood yet.

---

## The 8-Week Plan

### Week 1: Foundation — Build the Country Map

The goal this week is to understand the landscape. No deep dives — just learn what each service IS and where it fits.

**Monday — The Country + Identity**
- Read: `00-the-country/` (the master analogy)
- Read: `01-iam/` (the passport office — identity is EVERYTHING)
- Key focus: Understand the country analogy, IAM users vs roles vs policies
- Time: ~90 min

**Tuesday — Networking Foundations**
- Read: `02-vpc/` (the country's road network)
- Key focus: VPC, subnets (public/private), route tables, Internet Gateway, NAT Gateway
- Time: ~90 min

**Wednesday — Compute**
- Read: `03-ec2/` (the country's buildings)
- Read: `04-ebs/` (hard drives attached to buildings)
- Key focus: Instance types, pricing models (On-Demand, Reserved, Spot), EBS volume types
- Time: ~90 min

**Thursday — Storage**
- Read: `05-efs/` (shared file system)
- Read: `06-s3/` (the country's warehouse district)
- Key focus: S3 tiers, lifecycle policies, encryption, bucket policies vs ACLs
- Time: ~90 min

**Friday — Databases**
- Read: `07-rds/` (relational databases)
- Read: `08-dynamodb/` (NoSQL database)
- Key focus: RDS Multi-AZ vs Read Replicas, DynamoDB keys/indexes, capacity modes
- Time: ~90 min

**Weekend Task:**
- Take a free SAA-C03 practice quiz (20 questions) — don't study for it, just see where you stand
- Note which topics felt alien — that's your weak zone map
- Time: ~60 min

---

### Week 2: Compute & Storage Deep Dive

Now you know the landscape. This week, go DEEP on compute and storage — the two biggest exam domains.

**Monday — Serverless Compute**
- Read: `09-lambda/` (the country's on-demand workforce)
- Key focus: Invocation types (sync, async, event source), concurrency, 15-min timeout, layers
- Time: ~75 min

**Tuesday — API Layer**
- Read: `10-api-gateway/` (the country's reception desk)
- Key focus: REST vs HTTP API, stages, throttling, caching, Lambda integration types
- Time: ~75 min

**Wednesday — Load Balancing & Auto Scaling**
- Read: `11-elb-autoscaling/` (traffic management + elastic workforce)
- Key focus: ALB vs NLB vs CLB, target groups, health checks, scaling policies
- Time: ~90 min

**Thursday — Containers**
- Read: `23-ecs-containers/` (container ships)
- Key focus: ECS vs EKS, Fargate vs EC2 launch type, task definitions, service discovery
- Time: ~75 min

**Friday — Cost Optimization**
- Read: `COST-OPTIMIZATION-PATTERNS.md` (the treasury playbook)
- Key focus: The "When they say X, choose Y" table — memorize the top 15 patterns
- Time: ~90 min

**Weekend Task:**
- Practice quiz: 30 questions focused on EC2, S3, Lambda, ELB
- Hands-on: Create an S3 bucket with lifecycle policy + a Lambda function (free tier)
- Time: ~2 hours

---

### Week 3: Databases & Caching

Databases are ~15% of SAA-C03. This week makes you exam-ready on data stores.

**Monday — DynamoDB Deep Dive**
- Re-read: `08-dynamodb/` (focus on GSIs, LSIs, streams, DAX)
- Optional reference: `WALK-LIKE-DYNAMODB.md`, `VIVA-WALK-THROUGH-DYNAMO.md`
- Key focus: Partition key design, query vs scan, DynamoDB Streams, Global Tables
- Time: ~90 min

**Tuesday — Caching**
- Read: `24-elasticache/` (the country's speed layer)
- Key focus: Redis vs Memcached, caching strategies (lazy loading, write-through), session store
- Time: ~75 min

**Wednesday — Database Cost + Performance Patterns**
- Re-read: `COST-OPTIMIZATION-PATTERNS.md` — Database section only
- Key focus: Aurora Serverless v2, RDS Reserved, Read Replicas vs ElastiCache decision tree
- Time: ~60 min

**Thursday — Messaging & Decoupling**
- Read: `17-sqs-sns-ses/` (the country's postal service)
- Key focus: SQS Standard vs FIFO, dead-letter queues, SNS fan-out, SQS + Lambda
- Time: ~90 min

**Friday — Event-Driven Architecture**
- Read: `27-eventbridge/` (the country's event system)
- Read: `26-step-functions/` (the country's workflow coordinator)
- Key focus: EventBridge rules/targets, Step Functions state types, error handling
- Time: ~90 min

**Weekend Task:**
- Practice quiz: 30 questions on databases, caching, messaging
- Hands-on: Create a DynamoDB table + SQS queue + Lambda consumer (free tier)
- Time: ~2 hours

---

### Week 4: Networking & Content Delivery

Networking is where many candidates struggle. This week demystifies it.

**Monday — VPC Deep Dive**
- Re-read: `02-vpc/` (focus on: VPC peering, Transit Gateway, VPC endpoints, flow logs)
- Key focus: Security Groups vs NACLs, public vs private subnets, bastion hosts
- Time: ~90 min

**Tuesday — DNS & Routing**
- Read: `12-route53/` (the country's phone directory)
- Key focus: Record types (A, AAAA, CNAME, Alias), routing policies (simple, weighted, latency, failover, geolocation)
- Time: ~75 min

**Wednesday — Content Delivery**
- Read: `13-cloudfront/` (the country's delivery network)
- Key focus: Origins, behaviors, cache invalidation, OAC/OAI, signed URLs vs signed cookies
- Time: ~75 min

**Thursday — Hybrid Networking**
- Read: `30-direct-connect/` (the country's private highway to your on-premises)
- Key focus: Direct Connect vs Site-to-Site VPN, Direct Connect Gateway, public vs private VIF
- Time: ~75 min

**Friday — Network Cost Review**
- Re-read: `COST-OPTIMIZATION-PATTERNS.md` — Network section only
- Key focus: Data transfer costs, VPC Endpoints (Gateway = free for S3/DynamoDB), NAT Gateway costs
- Time: ~60 min

**Weekend Task:**
- Practice quiz: 30 questions on VPC, Route 53, CloudFront, connectivity
- Draw the VPC diagram from memory: VPC → Subnets → Route Tables → IGW/NAT → Security Groups/NACLs
- Time: ~2 hours

---

### Week 5: Security & Identity

Security is ~30% of SOA-C02 and ~25% of SAA-C03. This is a HIGH-YIELD week.

**Monday — IAM Deep Dive**
- Re-read: `01-iam/` (focus on: policy evaluation logic, permission boundaries, SCPs)
- Key focus: Explicit deny > explicit allow > implicit deny, cross-account roles, federation
- Time: ~90 min

**Tuesday — Encryption**
- Read: `19-kms-encryption/` (the country's classified documents department)
- Key focus: SSE-S3 vs SSE-KMS vs SSE-C, CMK vs AWS managed keys, envelope encryption, key rotation
- Time: ~90 min

**Wednesday — Authentication**
- Read: `18-cognito/` (the country's citizen ID system)
- Key focus: User Pools vs Identity Pools, JWT tokens, Cognito + API Gateway, federation
- Time: ~75 min

**Thursday — Logging & Monitoring for Security**
- Read: `20-cloudtrail/` (the country's CCTV system)
- Read: `29-waf-shield/` (the country's border defense)
- Key focus: CloudTrail events (management vs data), WAF rules, Shield Standard vs Advanced
- Time: ~90 min

**Friday — Well-Architected Security Pillar**
- Read: `WELL-ARCHITECTED-FRAMEWORK.md` — Security pillar section
- Key focus: Defense in depth, least privilege, encryption everywhere, traceability
- Time: ~60 min

**Weekend Task:**
- Practice quiz: 30 questions on IAM, KMS, CloudTrail, WAF, Cognito
- Hands-on: Create an IAM policy with least privilege for S3 read-only access
- Time: ~2 hours

---

### Week 6: DevOps & Automation

This week is critical for DVA-C02 and SOA-C02. SAA-C03 touches it lightly.

**Monday — CloudFormation**
- Read: `15-cloudformation/` (the country's city planner)
- Optional: `CDK-VERIFICATION-EXPLAINED.md`
- Key focus: Template anatomy, intrinsic functions (Ref, Fn::GetAtt, Fn::Join), stack updates, drift detection
- Time: ~90 min

**Tuesday — CI/CD Pipeline**
- Read: `31-cicd/` (the country's deployment pipeline)
- Key focus: CodeCommit → CodeBuild → CodeDeploy → CodePipeline, deployment strategies (rolling, blue/green, canary)
- Time: ~90 min

**Wednesday — Systems Manager & Config**
- Read: `32-systems-manager/` (the country's IT department)
- Read: `33-config/` (the country's compliance auditor)
- Key focus: SSM Parameter Store, Session Manager, Patch Manager, Run Command, Config Rules
- Time: ~90 min

**Thursday — Monitoring & Tracing**
- Read: `14-cloudwatch/` (the country's dashboard and alarm system)
- Read: `34-xray/` (the country's detective)
- Key focus: CloudWatch metrics/alarms/logs, custom metrics, X-Ray traces/segments/subsegments
- Time: ~90 min

**Friday — Parameters & Secrets**
- Read: `28-ssm-params-vault/` (the country's safe deposit boxes)
- Key focus: Parameter Store vs Secrets Manager, when to use which, encryption, rotation
- Time: ~60 min

**Weekend Task:**
- Practice quiz: 30 questions on CloudFormation, CI/CD, monitoring, automation
- Hands-on: Deploy a Lambda function using CloudFormation template
- Time: ~2 hours

---

### Week 7: Advanced Patterns & Architecture

This week ties everything together. Focus on SCENARIOS, not individual services.

**Monday — High Availability & Disaster Recovery**
- Read: `21-ha-ft-dr/` (the country's emergency preparedness)
- Key focus: Multi-AZ vs Multi-Region, DR strategies (Backup & Restore → Pilot Light → Warm Standby → Active-Active), RTO vs RPO
- Time: ~90 min

**Tuesday — Organizations & Multi-Account**
- Read: `16-organizations/` (the country's federal government)
- Key focus: SCPs, OUs, consolidated billing, cross-account access
- Time: ~75 min

**Wednesday — Data Streaming**
- Read: `25-kinesis/` (the country's real-time data highways)
- Key focus: Kinesis Data Streams vs Firehose vs Analytics, shard management, consumers
- Time: ~75 min

**Thursday — Well-Architected Framework (Full Review)**
- Read: `WELL-ARCHITECTED-FRAMEWORK.md` (all 6 pillars)
- Key focus: Know which pillar each design principle belongs to, cross-pillar overlaps
- Time: ~90 min

**Friday — ARNs & Service Integration Patterns**
- Read: `22-arn/` (the country's addressing system)
- Review: How services connect (Lambda + SQS, API Gateway + Lambda, EventBridge + Step Functions)
- Key focus: ARN format, resource-based vs identity-based policies, service integration patterns
- Time: ~75 min

**Weekend Task:**
- Full-length SAA-C03 practice exam (65 questions, 130 minutes)
- Review EVERY wrong answer — add weak topics to confidence tracker below
- Time: ~3 hours

---

### Week 8: Exam Drills & Review

This is the final push. No new material — only review, drill, and plug weak spots.

**Monday — Weak Spot Review**
- Look at your confidence tracker (bottom of this file)
- Re-read any topic rated 1-2
- Focus on: the specific services/concepts you got wrong in practice exams
- Time: ~2 hours

**Tuesday — Cost Optimization Speed Run**
- Re-read: `COST-OPTIMIZATION-PATTERNS.md`
- Focus on: "When they say X, choose Y" table — quiz yourself
- Time: ~90 min

**Wednesday — Full Practice Exam #2**
- Full-length SAA-C03 practice exam (different from Week 7's)
- Target: 80%+ correct
- Review wrong answers immediately
- Time: ~3 hours

**Thursday — Security + Networking Speed Run**
- Re-read: IAM, VPC, KMS, WAF sections
- Focus on: Security Groups vs NACLs, encryption at rest vs in transit, VPC Endpoints
- Time: ~2 hours

**Friday — Well-Architected + DR Speed Run**
- Re-read: `WELL-ARCHITECTED-FRAMEWORK.md`
- Re-read: `21-ha-ft-dr/`
- Focus on: 6 pillars, DR strategies, RTO/RPO
- Time: ~90 min

**Weekend — Final Mock Exam + Rest**
- Saturday AM: Final practice exam — target 85%+
- Saturday PM: Review wrong answers only
- Sunday: REST. Do not study. Let your brain consolidate.
- Time: ~3 hours Saturday, 0 hours Sunday

---

## Last 3 Days Before Each Exam

### Before SAA-C03 (Solutions Architect)

**Day -3 (3 days before):**
- Re-read: `COST-OPTIMIZATION-PATTERNS.md` (30% of questions involve cost)
- Re-read: `WELL-ARCHITECTED-FRAMEWORK.md` (appears directly in questions)
- Re-read: VPC section of `02-vpc/` (networking scenarios are common)

**Day -2 (2 days before):**
- Speed-read all "When they say X, choose Y" tables across your docs
- Review: DR strategies (Backup & Restore → Active-Active)
- Review: S3 tiers + lifecycle rules
- Review: RDS Multi-AZ vs Read Replicas

**Day -1 (day before):**
- Light review only — 1 hour max
- Re-read the key numbers: data transfer costs, S3 durability (11 nines), Lambda limits
- Get good sleep. Seriously.

### Before DVA-C02 (Developer)

**Day -3:** Lambda deep dive, API Gateway, DynamoDB (partition keys, GSIs, streams)
**Day -2:** CI/CD (CodePipeline, CodeDeploy strategies), X-Ray, SDK/CLI, CloudFormation
**Day -1:** SQS/SNS patterns, Cognito auth flow, Lambda concurrency + error handling. Light review. Sleep.

### Before SOA-C02 (SysOps Administrator)

**Day -3:** CloudWatch (metrics, alarms, logs, dashboards), SSM (Patch Manager, Run Command, Session Manager), Config rules
**Day -2:** Organizations + SCPs, CloudFormation (drift, stack policies, change sets), backup strategies
**Day -1:** Cost tools (Budgets, Cost Explorer, Trusted Advisor), networking troubleshooting. Light review. Sleep.

---

## If You Only Have 1 Hour Before the Exam

Read ONLY these, in this order:

1. **`COST-OPTIMIZATION-PATTERNS.md`** — "When they say X, choose Y" table (10 min)
2. **`WELL-ARCHITECTED-FRAMEWORK.md`** — Cross-Pillar Summary Table (5 min)
3. **Key numbers to memorize** (5 min):
   - S3: 11 nines durability, 5TB max object, 100 buckets soft limit
   - Lambda: 15 min timeout, 10GB memory, 1000 concurrent (default), 6MB sync payload
   - SQS: 256KB message, 14 days retention (default 4), visibility timeout 30s default
   - DynamoDB: 400KB max item, 1 RCU = 4KB strongly consistent, 1 WCU = 1KB
   - EBS: gp3 = 3,000 IOPS base, io2 = 64,000 IOPS, io2 Block Express = 256,000 IOPS
   - VPC: 5 VPCs per region (soft), 200 subnets per VPC
   - Data transfer: same-AZ free, cross-AZ $0.01/GB, internet out $0.09/GB
4. **DR strategies** (5 min): Backup & Restore < Pilot Light < Warm Standby < Active-Active
5. **Security mental model** (5 min): Explicit Deny > Explicit Allow > Implicit Deny
6. **Remaining 30 min:** Flip through any topic you're least confident on

---

## Exam Day Tips

### Time Management
- **SAA-C03:** 65 questions, 130 minutes = **2 minutes per question**
- **DVA-C02:** 65 questions, 130 minutes = **2 minutes per question**
- **SOA-C02:** 65 questions, 130 minutes = **2 minutes per question** (includes labs)
- First pass: answer everything you're confident on, **flag** uncertain ones
- Second pass: return to flagged questions with fresh eyes
- Never leave a question blank — no penalty for guessing

### Elimination Strategy
1. Read the question TWICE. Circle requirements (availability, cost, security, etc.)
2. Eliminate obviously wrong answers first (usually 1-2 are clearly wrong)
3. Between remaining options, ask: "Which one meets ALL stated requirements?"
4. If stuck between two: "Which is the AWS-recommended best practice?"
5. If STILL stuck: "Which uses more managed/serverless services?" (AWS loves managed services)

### Flagging Technique
- **Confident:** Answer and move on
- **70% sure:** Answer with your best guess, flag for review
- **No idea:** Eliminate what you can, guess, flag for review
- **Never** spend more than 3 minutes on a single question in the first pass

### Watch for These Exam Traps
- "MOST cost-effective" — cheapest that meets ALL requirements
- "LEAST operational overhead" — usually the managed/serverless option
- "MOST secure" — usually the most restrictive option
- "With MINIMAL changes" — they want the simplest fix, not a redesign
- "Company policy requires..." — this is a hard requirement, not optional
- Distractors: options that are real AWS services but solve a different problem

---

## Confidence Tracker

Rate yourself 1-5 after studying each topic. Focus your weak-spot review on anything rated 1-2.

```
1 = No idea, need to re-study from scratch
2 = Vaguely remember, would probably get exam questions wrong
3 = Understand the concept, might miss tricky questions
4 = Solid understanding, confident on most questions
5 = Could explain this to someone else, will ace these questions
```

### Compute
| Topic | Confidence (1-5) | Notes |
|---|---|---|
| EC2 instance types & pricing | | |
| EC2 placement groups | | |
| Auto Scaling (policies, lifecycle hooks) | | |
| Lambda (concurrency, layers, destinations) | | |
| ECS/EKS (Fargate vs EC2 launch type) | | |
| Elastic Beanstalk | | |
| Batch | | |

### Storage
| Topic | Confidence (1-5) | Notes |
|---|---|---|
| S3 (tiers, lifecycle, versioning) | | |
| S3 (security: bucket policies, ACLs, encryption) | | |
| S3 (replication, Transfer Acceleration) | | |
| EBS (volume types, snapshots, encryption) | | |
| EFS (performance modes, lifecycle) | | |
| Storage Gateway | | |
| FSx (Windows, Lustre) | | |

### Databases
| Topic | Confidence (1-5) | Notes |
|---|---|---|
| RDS (Multi-AZ, Read Replicas, backups) | | |
| Aurora (replication, Serverless, Global) | | |
| DynamoDB (keys, indexes, capacity modes) | | |
| DynamoDB (Streams, DAX, Global Tables) | | |
| ElastiCache (Redis vs Memcached) | | |
| Redshift (data warehouse) | | |
| DocumentDB, Neptune, QLDB | | |

### Networking
| Topic | Confidence (1-5) | Notes |
|---|---|---|
| VPC (subnets, route tables, gateways) | | |
| Security Groups vs NACLs | | |
| VPC Peering vs Transit Gateway | | |
| VPC Endpoints (Gateway vs Interface) | | |
| Route 53 (record types, routing policies) | | |
| CloudFront (origins, behaviors, signed URLs) | | |
| Direct Connect & VPN | | |
| Global Accelerator | | |

### Security
| Topic | Confidence (1-5) | Notes |
|---|---|---|
| IAM (policies, roles, federation) | | |
| IAM (permission boundaries, SCPs) | | |
| KMS (key types, envelope encryption) | | |
| CloudTrail (event types, log file integrity) | | |
| WAF & Shield | | |
| Cognito (User Pools vs Identity Pools) | | |
| Secrets Manager vs Parameter Store | | |
| GuardDuty, Inspector, Macie | | |

### Application Integration
| Topic | Confidence (1-5) | Notes |
|---|---|---|
| SQS (Standard vs FIFO, DLQ, visibility) | | |
| SNS (topics, subscriptions, fan-out) | | |
| EventBridge (rules, targets, event buses) | | |
| Step Functions (state types, error handling) | | |
| Kinesis (Streams vs Firehose vs Analytics) | | |
| API Gateway (REST vs HTTP, stages, auth) | | |

### Management & Governance
| Topic | Confidence (1-5) | Notes |
|---|---|---|
| CloudWatch (metrics, alarms, logs, dashboards) | | |
| CloudFormation (templates, stacks, drift) | | |
| Systems Manager (SSM) | | |
| AWS Config (rules, remediation) | | |
| Organizations (SCPs, OUs, billing) | | |
| Trusted Advisor | | |
| X-Ray (traces, segments, annotations) | | |

### Architecture Patterns
| Topic | Confidence (1-5) | Notes |
|---|---|---|
| Well-Architected Framework (6 pillars) | | |
| DR strategies (4 types + RTO/RPO) | | |
| Serverless architecture patterns | | |
| Microservices patterns | | |
| Cost optimization patterns | | |
| Multi-account strategy | | |
| Hybrid cloud (on-prem + AWS) | | |

---

## Progress Log

Track your weekly progress here.

| Week | Practice Exam Score | Weak Areas Identified | Action Taken |
|---|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |
| 6 | | | |
| 7 | | | |
| 8 | | | |
