# AWS Associate Exam Prep — Amrit's Country

> **Target:** Pass ALL 3 AWS Associate exams in 2 months
> **Exams:** SAA-C03 (Solutions Architect), DVA-C02 (Developer), SOA-C02 (SysOps)
> **Core Analogy:** AWS = A Country. Every service is a department, building, or role in that country.

---

## The Country — Amrit's AWS Mental Model

```
┌─────────────────────────────────────────────────────────────────────┐
│                        AWS = A COUNTRY                              │
│                                                                     │
│  Region        = Country (ap-southeast-2 = Australia)               │
│  AZ            = City (ap-southeast-2a = Sydney, 2b = Melbourne)    │
│  Edge Location = Corner shop / post office (300+ worldwide)         │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  VPC = Army Base / HQ (your private walled compound)        │   │
│  │                                                              │   │
│  │  Subnet (Public)  = Front gate division (internet-facing)    │   │
│  │  Subnet (Private) = Inner barracks (no direct internet)      │   │
│  │  IGW              = Border control (lets traffic in/out)     │   │
│  │  NAT Gateway      = Secure comms room (outbound only)        │   │
│  │  Security Group   = Bodyguard (stateful, per-instance)       │   │
│  │  NACL             = Fence guard (stateless, per-subnet)      │   │
│  │  Route Table      = Road signs (which traffic goes where)    │   │
│  │                                                              │   │
│  │  EC2      = Soldier (compute power, lives in a subnet)       │   │
│  │  EBS      = Backpack / Cabinet (block storage, same AZ)      │   │
│  │  EFS      = Shared filing cabinet (NFS, cross-AZ)            │   │
│  │  Lambda   = Magic kitchen (appears when needed, vanishes)    │   │
│  │  RDS      = Kitchen (managed database, chef = engine)        │   │
│  │  DynamoDB = Building (floors/rooms/shelves/folders)           │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  S3             = National warehouse (infinite storage, global)     │
│  Route 53       = Ministry of Foreign Affairs (DNS, global)        │
│  CloudFront     = Global post office network (CDN, edge)           │
│  IAM            = Government IDs & passports                       │
│  ARN            = National identity number (unique address)        │
│  Organizations  = United Nations (multi-account governance)        │
│  CloudFormation = Ministry of Infrastructure Planning (IaC)        │
│  CloudWatch     = Ministry of Intelligence & Surveillance          │
│  CloudTrail     = National auditor / whistleblower                 │
│  X-Ray          = Detective / surveillance drone                   │
│  KMS            = National locksmith (encryption keys)             │
│  WAF            = Border firewall (web application protection)     │
│  SQS            = Post office queue (message buffer)               │
│  SNS            = PA system / megaphone (pub/sub notifications)    │
│  Cognito        = Visa office (user auth & identity)               │
│  ElastiCache    = Speed cache (in-memory, Redis/Memcached)         │
│  Kinesis        = River of data (real-time streaming)              │
│  Step Functions = Workflow orchestrator (state machine)             │
│  EventBridge    = Event bus (event-driven routing)                 │
│  CodePipeline   = Assembly line (CI/CD)                            │
│  Systems Manager= Fleet commander (manage EC2 at scale)            │
│  Config         = Compliance inspector                             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Exam Differences — What Each Exam Cares About

| | SAA-C03 (Architect) | DVA-C02 (Developer) | SOA-C02 (SysOps) |
|-|-------|--------|--------|
| **Mindset** | "Design the best architecture" | "Build & deploy the code" | "Run, monitor & fix it" |
| **Analogy** | You're the **architect** drawing blueprints | You're the **builder** constructing it | You're the **building manager** keeping it running |
| **Heavy topics** | VPC, S3, HA/DR, Security, Cost | Lambda, API GW, DynamoDB, CI/CD, SDK | CloudWatch, CloudFormation, SSM, Troubleshooting |
| **Questions** | 65 Qs, 130 min, pass 720/1000 | 65 Qs, 130 min, pass 720/1000 | 65 Qs, 130 min, pass 720/1000 |

**Key insight:** ~60% of content overlaps. Learn the core once, then angle your thinking per exam.

---

## Folder Structure — One Folder Per Service

```
learnings/aws/
├── AWS-EXAM-README.md              ← YOU ARE HERE
├── WALK-LIKE-DYNAMODB.md           ← (existing) DynamoDB building analogy
├── VIVA-WALK-THROUGH-DYNAMO.md     ← (existing) DynamoDB with Viva data
├── CDK-VERIFICATION-EXPLAINED.md   ← (existing) CDK checklist
│
├── 00-the-country/                 ← Regions, AZs, Edge Locations
├── 01-iam/                         ← Government IDs, policies, roles, federation
├── 02-vpc/                         ← Army Base HQ, subnets, networking, peering
├── 03-ec2/                         ← Soldiers — instances, AMIs, placement groups
├── 04-ebs/                         ← Backpacks/Cabinets — volumes, snapshots, RAID
├── 05-efs/                         ← Shared filing cabinet — NFS, cross-AZ
├── 06-s3/                          ← National warehouse — storage classes, lifecycle
├── 07-rds/                         ← Kitchen — engines, Multi-AZ, Aurora, replicas
├── 08-dynamodb/                    ← Building — tables, GSI, LSI, streams
├── 09-lambda/                      ← Magic kitchen — execution, layers, destinations
├── 10-api-gateway/                 ← Reception desk — REST, HTTP, WebSocket
├── 11-elb-autoscaling/             ← Load balancers + scaling policies
├── 12-route53/                     ← Ministry of Foreign Affairs — DNS, routing
├── 13-cloudfront/                  ← Global post office — CDN, OAC, signed URLs
├── 14-cloudwatch/                  ← Ministry of Intelligence — metrics, logs, alarms
├── 15-cloudformation/              ← Ministry of Infrastructure — stacks, templates
├── 16-organizations/               ← United Nations — SCPs, OUs, consolidated billing
├── 17-sqs-sns-ses/                 ← Messaging — queues, pub/sub, email
├── 18-cognito/                     ← Visa office — user pools, identity pools
├── 19-kms-encryption/              ← National locksmith — CMKs, envelope encryption
├── 20-cloudtrail/                  ← Auditor — API logging, governance
├── 21-ha-ft-dr/                    ← Emergency resilience — HA, FT, DR strategies
├── 22-arn/                         ← Passport system — resource addressing
├── 23-ecs-containers/              ← Container ships — ECS, Fargate, ECR
├── 24-elasticache/                 ← Speed cache — Redis, Memcached
├── 25-kinesis/                     ← River of data — streams, firehose, analytics
├── 26-step-functions/              ← Workflow conductor — state machines
├── 27-eventbridge/                 ← Event bus — rules, targets, scheduling
├── 28-secrets-ssm/                 ← Secrets & config — Parameter Store, Secrets Manager
├── 29-waf-shield/                  ← Firewall & DDoS — WAF rules, Shield
├── 30-direct-connect/              ← Private highway — dedicated network, VPN
├── 31-cicd/                        ← Assembly line — CodePipeline, CodeBuild, CodeDeploy
├── 32-systems-manager/             ← Fleet commander — SSM, Run Command, Patch Manager
├── 33-config/                      ← Compliance inspector — rules, conformance packs
└── 34-xray/                        ← Detective — distributed tracing, service maps
```

Each folder contains:
- **README.md** — Concept + Analogy + Architecture + Exam focus per cert
- **QUESTIONS.md** — Scenario questions (technical → real-world), answers, "why wrong" for other options

---

## Study Plan — 8 Weeks to 3 Exams

### Weeks 1-2: The Foundation (Architect mindset)
- 00-the-country, 01-iam, 02-vpc, 03-ec2, 04-ebs, 05-efs, 06-s3

### Weeks 3-4: Data & Compute (Developer mindset)
- 07-rds, 08-dynamodb, 09-lambda, 10-api-gateway, 18-cognito, 24-elasticache

### Weeks 5-6: Operations & Networking (SysOps mindset)
- 11-elb-autoscaling, 12-route53, 13-cloudfront, 14-cloudwatch, 34-xray
- 15-cloudformation, 32-systems-manager, 33-config, 20-cloudtrail

### Weeks 7-8: Advanced + Exam Drills
- 16-organizations, 17-sqs-sns-ses, 19-kms-encryption, 21-ha-ft-dr
- 22-arn, 23-ecs-containers, 25-kinesis, 26-step-functions, 27-eventbridge
- 28-secrets-ssm, 29-waf-shield, 30-direct-connect, 31-cicd
- Mock exams, weak-area review

---

## How Each File Works

Every README.md follows this pattern:
1. **One-liner analogy** — What is this service in the country?
2. **ELI10** — Explain to a 10-year-old
3. **The Concept** — Technical details mapped to the analogy
4. **Architecture** — ASCII diagrams showing how it connects
5. **Exam Angle** — What SAA/DVA/SOA each care about
6. **Key Numbers** — Limits, defaults, quotas examiners love testing

Every QUESTIONS.md follows this pattern:
1. **Scenario question** — Real exam style
2. **Options** — 4 choices
3. **Answer** — Correct option + WHY
4. **Analogy mapping** — Same answer in country language
5. **Why wrong** — Each wrong option explained
