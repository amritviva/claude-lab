# 05 - EFS: The Shared Filing Cabinet

> **Analogy:** EFS is a shared filing cabinet that sits in the hallway of the army base -- any soldier in any city (AZ) can walk up and use it simultaneously. Unlike EBS (one cabinet per soldier per room), EFS is communal. But it's Linux-only -- Windows soldiers can't read the labels.

---

## ELI10

Imagine the army base has a giant **shared filing cabinet** in the main hallway. Any soldier from any city (AZ) can walk up, open a drawer, and read or write files. A hundred soldiers can use it at the same time. The cabinet grows and shrinks automatically -- if soldiers add more files, it gets bigger; if they remove files, it shrinks. There's no need to decide the size upfront. The only catch? It uses a special **labelling system** (NFS protocol) that only **Linux** soldiers can read -- Windows soldiers need their own system (FSx).

---

## The Concept

### What is EFS?

EFS (Elastic File System) is a managed NFS file system that can be mounted on multiple EC2 instances simultaneously, across multiple AZs.

```
┌──── AZ-a ────────┐    ┌──── AZ-b ────────┐    ┌──── AZ-c ────────┐
│                   │    │                   │    │                   │
│ [EC2] [EC2] [EC2] │    │ [EC2] [Lambda]   │    │ [EC2] [ECS Task] │
│   │     │     │   │    │   │       │       │    │   │       │      │
│   └──┬──┘     │   │    │   └───┬───┘       │    │   └───┬───┘      │
│      │        │   │    │       │            │    │       │          │
│  [Mount Target]   │    │   [Mount Target]  │    │   [Mount Target] │
│      │            │    │       │            │    │       │          │
└──────┼────────────┘    └───────┼────────────┘    └───────┼──────────┘
       │                         │                         │
       └─────────────────────────┼─────────────────────────┘
                                 │
                     ┌───── EFS File System ─────┐
                     │  (shared across all AZs)   │
                     │  Grows/shrinks auto         │
                     │  Petabyte scale             │
                     └────────────────────────────┘
```

### EFS vs EBS vs S3 -- The Exam Favourite Comparison

| Feature | EBS | EFS | S3 |
|---------|-----|-----|-----|
| Analogy | Cabinet in your room | Shared hallway cabinet | National warehouse |
| Type | Block storage | File storage (NFS) | Object storage |
| Access | One instance (except Multi-Attach io2) | Thousands of instances | Unlimited via API |
| AZ scope | Single AZ | Multi-AZ (Regional) | Multi-AZ (Regional) |
| Protocol | Attached as block device | NFS v4.0/4.1 | HTTP/S REST API |
| OS support | Any | **Linux only** | Any (API-based) |
| Size | Must provision (up to 64 TiB) | Auto-scales (petabytes) | Unlimited |
| Performance | Provisioned IOPS | Bursting or Provisioned | Depends on class |
| Price | Per GB provisioned | Per GB used | Per GB stored |
| Use case | Database, boot volume | Shared content, web serving | Backup, data lake, static |

**Exam decision tree:**
- Need a boot volume? → EBS
- Need shared file access (Linux)? → EFS
- Need shared file access (Windows)? → FSx for Windows
- Need object storage / unlimited scale? → S3
- Need highest IOPS (>256K)? → Instance Store
- Need block storage for single instance? → EBS

### Storage Classes

| Class | Analogy | Use Case | Cost |
|-------|---------|----------|------|
| **Standard** | Active desk drawers | Frequently accessed files | Higher $/GB |
| **Standard-IA** | Back office storage | Accessed a few times a month | Lower $/GB + per-access fee |
| **One Zone** | Single-city cabinet | Dev/test, non-critical | 47% cheaper than Standard |
| **One Zone-IA** | Single-city back office | Infrequent + non-critical | Cheapest |

```
File access frequency:
  High  ──→  EFS Standard      (multi-AZ, frequently accessed)
  Medium ──→  EFS Standard-IA   (multi-AZ, infrequent, per-access fee)
  Dev/Test ──→  EFS One Zone    (single AZ, cheaper)
  Archive ──→  EFS One Zone-IA  (single AZ, cheapest)
```

### Lifecycle Policies -- Automatic Drawer Reorganisation

EFS can automatically move files between storage classes based on access patterns:

- Move to IA after: 7, 14, 30, 60, or 90 days of no access
- Move back to Standard on first access (optional)
- Saves cost without manual intervention
- Similar concept to S3 Lifecycle Rules but for files

### Performance Modes

| Mode | Analogy | Latency | Throughput | Use Case |
|------|---------|---------|------------|----------|
| **General Purpose** (default) | Standard filing speed | Low (sub-ms) | Good | Web serving, CMS, home dirs |
| **Max I/O** | Industrial filing system | Higher latency | Highest throughput | Big data, media processing, thousands of instances |

**Key difference:** General Purpose = low latency, Max I/O = highest aggregate throughput (but higher per-operation latency). General Purpose is the default and right choice 90% of the time.

### Throughput Modes

| Mode | Analogy | Behaviour |
|------|---------|-----------|
| **Bursting** (default) | Earn and spend filing speed credits | Throughput scales with file system size; burst when needed |
| **Provisioned** | Pay for guaranteed filing speed | Set throughput independent of storage size |
| **Elastic** | Auto-adjusting speed | Automatically scales throughput up/down based on workload |

**Bursting details:**
- Baseline: 50 MiB/s per TiB of storage
- Burst: up to 100 MiB/s (all file systems), higher for larger
- Problem: small file system = low baseline = long burst recovery

**Elastic (newest):**
- Automatically provides throughput based on demand
- Up to 10 GiB/s reads, 3 GiB/s writes
- Most cost-effective for unpredictable workloads
- Recommended for most new file systems

### Mount Targets

- You create a **mount target** in each AZ where you want to access EFS
- Each mount target gets an IP address and DNS name
- Mount target has its own **Security Group** (controls who can mount)
- EC2 instances mount via NFS: `mount -t nfs4 fs-xxx.efs.region.amazonaws.com:/ /mnt/efs`

### Encryption

- **At rest**: optional, uses KMS (must enable at creation)
- **In transit**: TLS encryption via EFS mount helper (`amazon-efs-utils` package)
- Cannot change at-rest encryption after creation

### EFS with Lambda

- Lambda can mount EFS file systems (since 2020)
- Lambda must be in a VPC to use EFS
- Use case: large ML models, shared data between Lambda invocations
- Lambda's /tmp is limited to 10 GB; EFS gives petabyte-scale shared storage

### EFS Access Points

- Application-specific entry points into an EFS file system
- Can enforce: user/group identity, root directory, permissions
- Like creating different "doors" to the same filing cabinet, each with its own rules
- Useful for: multi-tenant applications, container workloads

---

## Architecture Diagram

```
                    ┌──────── EFS File System ──────────┐
                    │  Performance: General Purpose       │
                    │  Throughput: Elastic                 │
                    │  Encrypted: Yes (KMS)                │
                    │  Lifecycle: 30 days → IA             │
                    └──────────────┬───────────────────────┘
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
┌───────▼──── AZ-a ──────┐ ┌──────▼──── AZ-b ──────┐ ┌──────▼──── AZ-c ──────┐
│                         │ │                        │ │                        │
│ [Mount Target]          │ │ [Mount Target]         │ │ [Mount Target]         │
│  SG: efs-sg (port 2049) │ │  SG: efs-sg            │ │  SG: efs-sg            │
│         │               │ │        │               │ │        │               │
│    ┌────┴────┐          │ │   ┌────┴────┐          │ │   ┌────┴────┐          │
│    │         │          │ │   │         │          │ │   │         │          │
│  [EC2]    [EC2]         │ │ [EC2]   [Lambda]       │ │ [EC2]   [ECS]         │
│  (web1)   (web2)        │ │ (web3)  (processor)    │ │ (web4)  (workers)     │
│                         │ │                        │ │                        │
└─────────────────────────┘ └────────────────────────┘ └────────────────────────┘
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- EFS vs EBS vs S3 decision (THE classic exam question)
- Shared storage across AZs for web server content
- Cost optimization with lifecycle policies (Standard → IA)
- One Zone for dev/test cost savings
- EFS with Auto Scaling Group (shared content across fleet)
- Performance mode selection (General Purpose vs Max I/O)

### DVA-C02 (Developer)
- Mounting EFS in Lambda for large shared data
- EFS Access Points for multi-tenant isolation
- Using EFS with containers (ECS/EKS)
- Encryption in transit with mount helper

### SOA-C02 (SysOps Administrator)
- Monitoring EFS (CloudWatch: TotalIOBytes, PercentIOLimit, BurstCreditBalance)
- Throughput mode selection and changes
- Troubleshooting mount issues (security groups, NFS port 2049)
- Lifecycle policy configuration
- Backup with AWS Backup
- Performance troubleshooting (PercentIOLimit metric)

---

## Key Numbers

| Fact | Value |
|------|-------|
| Max file system size | Petabytes (auto-scaling) |
| Max file size | 47.9 TiB |
| NFS protocol | v4.0, v4.1 |
| NFS port | 2049 |
| Max throughput (Elastic) | 10 GiB/s read, 3 GiB/s write |
| Bursting baseline | 50 MiB/s per TiB |
| General Purpose IOPS | Up to 35,000 read, 7,000 write |
| Max I/O concurrent connections | Thousands |
| Standard-IA retrieval fee | Per GB read |
| One Zone savings | ~47% vs Standard multi-AZ |
| Encryption | At rest (KMS) + In transit (TLS) |
| OS support | Linux only (NFS) |
| Lambda /tmp limit | 10 GB (EFS = unlimited alternative) |

---

## Cheat Sheet

- EFS = shared NFS file system, multi-AZ, Linux only
- Auto-scales (no provisioning size), pay for what you use
- EBS = single instance, single AZ; EFS = many instances, many AZs; S3 = object store
- Windows? Use FSx for Windows File Server (not EFS)
- Storage classes: Standard, Standard-IA, One Zone, One Zone-IA
- Lifecycle policies auto-move to IA after N days (saves $$$)
- Performance modes: General Purpose (default, low latency) vs Max I/O (high throughput)
- Throughput modes: Bursting (default), Provisioned, Elastic (recommended)
- Mount targets: one per AZ, needs Security Group allowing port 2049 (NFS)
- Encryption at rest: KMS, must enable at creation (can't add later)
- Encryption in transit: TLS via amazon-efs-utils mount helper
- Lambda can mount EFS (must be in VPC)
- EFS Access Points = per-application entry points with enforced user/directory
- Exam trap: "shared storage across AZs for Linux web servers" = EFS
- Exam trap: "shared storage for Windows" = FSx, NOT EFS
- Exam trap: "need a boot volume" = EBS, NOT EFS
- BurstCreditBalance metric = key SysOps monitoring metric
