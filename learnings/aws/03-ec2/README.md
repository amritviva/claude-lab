# 03 - EC2: The Soldiers

> **Analogy:** EC2 instances are soldiers in your army base. Each soldier has a training manual (AMI), a strength class (instance type), a temporary phone number (public IP) or permanent PO Box (Elastic IP), and first-day instructions (user data). You can hire them on-demand, bid at auction, or sign long-term contracts.

---

## ELI10

Think of EC2 like hiring soldiers for your army base. Each soldier is built from a **training manual** (AMI) that tells them what skills they have. You pick their **strength class** -- some are fast runners (compute-optimized), some carry heavy loads (memory-optimized), some are all-rounders (general purpose). When a soldier first shows up, you give them **first-day instructions** (user data) like "install this software, download these files." They get a **temporary phone number** that changes every time they take a break, or you can pay for a **permanent PO Box** address. You can hire soldiers for a day (on-demand), bid at auction for cheap (spot), or sign a year-long contract (reserved).

---

## The Concept

### AMI -- The Training Manual

An Amazon Machine Image is a blueprint used to launch EC2 instances.

```
AMI (Training Manual)
├── Root volume template (OS + pre-installed software)
├── Launch permissions (who can use this manual)
├── Block device mapping (which storage volumes to attach)
└── Architecture (x86_64 or arm64)
```

**AMI types:**
- **Amazon-provided** -- Amazon Linux 2, Ubuntu, Windows Server
- **AWS Marketplace** -- Third-party (pre-configured, may have hourly cost)
- **Community** -- Public AMIs shared by others (use with caution)
- **Custom** -- Your own (snapshot an instance, create AMI from it)

**Key facts:**
- AMIs are **Regional** -- must copy to use in another Region
- AMIs can be shared across accounts
- AMIs can be encrypted (use KMS)
- Creating an AMI from a running instance: recommend stopping first for data consistency

### Instance Types -- Soldier Strength Classes

**Mnemonic: "Great Cats Make Really Powerful Ideas Daily Here"**

| Family | Prefix | Analogy | Use Case |
|--------|--------|---------|----------|
| General Purpose | t3, m5, m6i | All-rounder recruit | Web servers, small DBs |
| Compute Optimized | c5, c6g | Commando (fast processor) | Batch processing, ML inference, gaming |
| Memory Optimized | r5, r6g, x1 | Medic with big backpack | In-memory DBs, real-time analytics |
| Storage Optimized | i3, d2, h1 | Supply truck | Data warehouses, distributed file systems |
| Accelerated Computing | p4, g5, inf1 | Specialist with special equipment | GPU: ML training, video encoding |

**Instance naming: `m5.xlarge`**
```
m  = Family (General Purpose)
5  = Generation
.  = separator
xlarge = Size

Sizes: nano < micro < small < medium < large < xlarge < 2xlarge ... < metal
```

**T-class burstable instances:**
- `t3.micro`, `t3.small` etc.
- Earn CPU credits when idle, spend them when busy
- `T3 Unlimited`: can burst beyond credit balance (pay for extra)
- Great for variable workloads (dev/test, small websites)

### Instance Lifecycle

```
    launch                stop              start
 ○ ────────→ [PENDING] ────→ [STOPPING] ────→ [PENDING]
                │                                 │
                ▼                                 ▼
           [RUNNING] ◄──────────────────── [RUNNING]
                │
                │ terminate
                ▼
         [SHUTTING-DOWN]
                │
                ▼
          [TERMINATED]

Also:
[RUNNING] → hibernate → [STOPPING] → [STOPPED] (RAM saved to EBS)
           → reboot → [RUNNING] (same host, keeps public IP)
```

**Key state transitions:**
- **Stop**: Lose public IP, keep private IP, keep EBS data, no charge (EBS still charged)
- **Terminate**: Everything gone (unless EBS `DeleteOnTermination` = false)
- **Reboot**: Same host, keeps everything, quick restart
- **Hibernate**: RAM contents dumped to encrypted EBS root volume, resumes fast

**Hibernate requirements:**
- Root volume must be EBS (encrypted)
- RAM must fit on root volume
- Supported instance families: C, M, R, T (General/Compute/Memory)
- Max hibernation: 60 days
- Must be enabled at launch (can't enable later)

### User Data -- First-Day Instructions

A bash script (or cloud-init directives) that runs **once** at first boot.

```bash
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Hello from $(hostname)</h1>" > /var/www/html/index.html
```

**Key facts:**
- Runs as **root** (no sudo needed)
- Runs only on **first boot** (unless you configure cloud-init for every boot)
- Accessible via metadata: `http://169.254.169.254/latest/user-data`
- Max size: 16 KB
- Base64 encoded when passed via API

### Instance Metadata -- The Soldier's Internal Radio

Every EC2 instance can query information about itself:

```
http://169.254.169.254/latest/meta-data/

Useful endpoints:
/ami-id                  → Which training manual was I built from?
/instance-id             → What's my serial number?
/instance-type           → What's my strength class?
/local-ipv4              → What's my internal address?
/public-ipv4             → What's my external phone number?
/iam/security-credentials/role-name → What's my temporary VIP badge?
/placement/availability-zone → Which city am I in?
```

**IMDSv2 (Instance Metadata Service v2):**
- Requires a session token (PUT request first, then GET with token)
- Protects against SSRF attacks
- **Exam tip:** If asked about securing metadata access, answer is IMDSv2

### IP Addressing

| Type | Analogy | Persistence | Cost |
|------|---------|-------------|------|
| Private IP | Internal base extension number | Stays until terminated | Free |
| Public IP | Temporary phone number | Lost on stop, new on start | Free |
| Elastic IP | Permanent PO Box | Stays until you release it | Free when attached to running instance, **charged when NOT attached** |

**Elastic IP warning:** You're charged for an EIP that is:
- Not associated with any instance
- Associated with a stopped instance
- Associated with an unattached ENI

### Placement Groups -- Where Soldiers Sit

| Type | Analogy | Behaviour | Use Case |
|------|---------|-----------|----------|
| **Cluster** | Same room, same desk | Same rack, same AZ, lowest latency | HPC, big data (10Gbps between instances) |
| **Spread** | Different buildings | Different hardware racks | Critical instances that must be isolated (max 7 per AZ) |
| **Partition** | Different floors | Grouped on separate racks | Big data (Hadoop, Cassandra, Kafka) |

```
Cluster:                    Spread:                     Partition:
┌─── Rack ──────────┐     ┌─Rack1─┐ ┌─Rack2─┐        ┌─Part1──┐ ┌─Part2──┐
│ [i1][i2][i3][i4]  │     │ [i1]  │ │ [i2]  │        │ [i1]   │ │ [i3]   │
│ Low latency!      │     └───────┘ └───────┘        │ [i2]   │ │ [i4]   │
└───────────────────┘     ┌─Rack3─┐                   └────────┘ └────────┘
                          │ [i3]  │
                          └───────┘
```

### Purchase Options -- How You Hire Soldiers

| Option | Analogy | Discount | Commitment | Key Facts |
|--------|---------|----------|------------|-----------|
| **On-Demand** | Hotel room | 0% | None | Pay by second (Linux) or hour (Windows) |
| **Reserved** | Apartment lease | Up to 72% | 1 or 3 years | All Upfront > Partial > No Upfront |
| **Savings Plans** | Flexible gym membership | Up to 72% | 1 or 3 years | $/hr commitment, flexible instance type |
| **Spot** | Auction Airbnb | Up to 90% | None | Can be reclaimed with 2-min warning |
| **Dedicated Host** | Entire building floor | Varies | On-Demand or Reserved | Physical server, for licensing/compliance |
| **Dedicated Instance** | Private room | Varies | On-Demand | Dedicated hardware, but AWS manages placement |
| **Capacity Reservation** | Reserved parking spot | 0% | None | Guarantee capacity in specific AZ |

**Spot Instance details:**
- You set a max price; if market price exceeds it, instance is reclaimed
- 2-minute warning before termination (via metadata or CloudWatch Events)
- **Spot Fleet**: collection of Spot + optional On-Demand instances
- **Spot Block**: reserved for 1-6 hours (deprecated in some regions)
- Best for: batch jobs, data analysis, CI/CD, fault-tolerant workloads
- NOT for: databases, critical applications, stateful workloads

**Reserved Instance types:**
- **Standard RI**: up to 72% off, can change AZ/size/networking, can sell on marketplace
- **Convertible RI**: up to 54% off, can change instance family/OS/tenancy
- **Scheduled RI**: reserved for specific time windows (deprecated)

### SSM Session Manager -- Remote Access Without SSH

- No SSH keys needed, no bastion host needed, no port 22 open
- Requires SSM Agent (pre-installed on Amazon Linux 2, Windows)
- Instance needs IAM role with SSM permissions
- All sessions logged to CloudWatch/S3 (audit trail)
- **Exam tip:** When asked about secure remote access without opening inbound ports, answer is SSM Session Manager

---

## Architecture Diagram

```
┌─────────── EC2 Instance Anatomy ──────────────────────┐
│                                                        │
│  ┌──── AMI (Training Manual) ────┐                     │
│  │ OS: Amazon Linux 2            │                     │
│  │ Pre-installed: nginx, node    │                     │
│  └───────────────────────────────┘                     │
│                                                        │
│  Instance Type: m5.xlarge                              │
│  ├── 4 vCPUs                                           │
│  ├── 16 GB RAM                                         │
│  └── EBS-optimized                                     │
│                                                        │
│  Network:                                              │
│  ├── Private IP: 10.0.1.42 (permanent)                 │
│  ├── Public IP: 54.xx.xx.xx (temporary)                │
│  └── Security Groups: [web-sg, ssh-sg]                 │
│                                                        │
│  Storage:                                              │
│  ├── Root: EBS gp3 20GB (DeleteOnTermination=true)     │
│  ├── Data: EBS gp3 100GB (DeleteOnTermination=false)   │
│  └── Temp: Instance Store 475GB (ephemeral!)           │
│                                                        │
│  IAM Role: EC2-S3-ReadRole (VIP badge)                 │
│  User Data: bootstrap.sh (first-day instructions)      │
│  Key Pair: my-key.pem (SSH badge)                      │
│  Metadata: http://169.254.169.254/latest/              │
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- Choosing the right purchase option for a scenario
- Placement group selection (cluster vs spread vs partition)
- EC2 + Auto Scaling + ELB architecture
- Hibernate for long-initialization workloads
- AMI strategy (golden AMI, cross-region copy)
- Spot Instances for cost optimization

### DVA-C02 (Developer)
- User data scripts and metadata API
- IMDSv2 for secure metadata access
- IAM roles for EC2 (never embed access keys)
- Deploying applications with CodeDeploy to EC2
- Instance profiles (wrapper around IAM role for EC2)

### SOA-C02 (SysOps Administrator)
- Instance troubleshooting (status checks: system + instance)
- Monitoring with CloudWatch (CPU, network, disk -- NOT memory/disk usage without agent)
- Placement group constraints
- Capacity reservations
- EC2 instance recovery (CloudWatch alarm → recover action)
- SSM Session Manager setup and audit logging
- Scheduled scaling and predictive scaling

---

## Key Numbers

| Fact | Value |
|------|-------|
| Instances per Region | 20 On-Demand (soft limit) |
| Elastic IPs per Region | 5 |
| Security Groups per instance | 5 |
| Key Pairs per Region | 5,000 |
| User Data max size | 16 KB |
| Spot termination notice | 2 minutes |
| Hibernate max duration | 60 days |
| Metadata endpoint | 169.254.169.254 |
| Spread placement max per AZ | 7 instances |
| Reserved Instance term | 1 or 3 years |
| EIP cost when unattached | ~$0.005/hr |
| Burstable credit (t3.micro) | Earns 12 credits/hr |

---

## Cheat Sheet

- AMI = blueprint to create instances (Regional, can copy cross-region)
- Instance Type naming: `[family][generation].[size]` (e.g., m5.xlarge)
- User Data runs once at first boot as root, max 16KB
- Metadata at 169.254.169.254 -- use IMDSv2 for security
- Public IP = temporary (lost on stop); Elastic IP = permanent (costs if unused)
- Stop = lose public IP, keep EBS; Terminate = lose everything (unless EBS persist)
- Hibernate = save RAM to encrypted EBS root, resume later (max 60 days)
- Spot = up to 90% off, 2-min warning, for fault-tolerant workloads only
- Reserved = up to 72% off, 1/3-year commitment, All Upfront is cheapest
- Savings Plans = flexible RI alternative, $/hr commitment
- Placement: Cluster=low latency, Spread=isolation (max 7/AZ), Partition=big data
- IAM Role > Access Keys for EC2 (always use instance profiles)
- SSM Session Manager = secure access without SSH/port 22
- CloudWatch default: CPU, network, disk I/O. NOT memory or disk usage (need agent)
- Status checks: System (AWS hardware) + Instance (your OS)
- EC2 is AZ-scoped -- must manually launch in multiple AZs for HA
- Dedicated Host = physical server (licensing); Dedicated Instance = isolated hardware
