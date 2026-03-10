# RDS — The Kitchen

> **In the AWS Country, RDS is the professional kitchen.** You pick a chef (engine), rent the building (instance), and AWS handles plumbing, electricity, and pest control (patching, backups, failover). You cook (queries); they maintain the kitchen.

---

## ELI10

Imagine you want to run a restaurant but you hate fixing ovens, cleaning drains, and calling electricians. So you rent a kitchen from a company that handles ALL of that. You just pick what type of chef you want (Italian, French, Japanese), bring your recipes, and start cooking. If the kitchen catches fire, they automatically switch you to a backup kitchen in another city. That's RDS — a managed kitchen where you focus on the food, not the building.

---

## The Concept

### What Is RDS?

**Relational Database Service** — AWS runs the database server for you. You don't SSH into the machine, you don't patch the OS, you don't set up replication manually.

```
┌─────────────────────────────────────────────────┐
│                   THE KITCHEN (RDS)              │
│                                                  │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐    │
│  │  Table A  │  │  Table B  │  │  Table C  │    │
│  │  (Room)   │  │  (Room)   │  │  (Room)   │    │
│  │           │  │           │  │           │    │
│  │ Row = Drawer │ Row = Drawer│ Row = Drawer│   │
│  │ Col = Label  │ Col = Label │ Col = Label │   │
│  └───────────┘  └───────────┘  └───────────┘    │
│                                                  │
│  Chef: MySQL / PostgreSQL / Aurora / etc.        │
│  Building: db.t3.micro → db.r6g.16xlarge        │
│  AWS handles: patching, backups, failover        │
└─────────────────────────────────────────────────┘
```

**Analogy Mapping:**
| Kitchen Analogy | RDS Concept |
|---|---|
| Building | DB Instance (compute + memory) |
| Room | Table |
| Drawer | Row |
| Label on drawer | Column |
| Chef | Database Engine |
| Kitchen size | Instance class (db.t3, db.r6g, etc.) |
| Pantry | EBS storage (gp2, gp3, io1, io2) |

### The 6 Chefs (Database Engines)

| Chef | Analogy | Notes |
|---|---|---|
| **MySQL** | The reliable home cook | Most popular open-source, community edition |
| **PostgreSQL** | The sophisticated chef | Advanced features, extensions, JSONB |
| **MariaDB** | MySQL's cooler cousin | Fork of MySQL, community-driven |
| **Oracle** | The expensive Michelin chef | Bring Your Own License (BYOL) or License Included |
| **SQL Server** | The corporate caterer | Microsoft's engine, Windows-centric |
| **Aurora** | The luxury hotel chef | AWS-built, MySQL/PostgreSQL compatible, 5x faster |

---

### Multi-AZ: Two Kitchens in Different Cities

When your kitchen catches fire (AZ failure), you need a backup. Multi-AZ gives you a **standby replica in a different Availability Zone** with **synchronous replication**.

```
         ┌──────────────────┐         ┌──────────────────┐
         │   PRIMARY (AZ-A) │ ──sync──│  STANDBY (AZ-B)  │
         │   Kitchen #1     │  repli  │  Kitchen #2      │
         │   (read/write)   │  cation │  (NO traffic)    │
         └────────┬─────────┘         └────────┬─────────┘
                  │                             │
                  │   ← Automatic failover      │
                  │     (60-120 seconds)        │
                  │                             │
              DNS endpoint stays the same
```

**Key facts:**
- Standby is NOT readable — it just sits there waiting
- Failover is automatic — DNS CNAME flips to standby
- Synchronous replication — zero data loss
- Same region, different AZ
- ~2x cost (you pay for the standby instance)
- Multi-AZ is for **high availability**, NOT performance

### Read Replicas: Copy Kitchen for Takeout Only

Need to handle more read traffic? Create up to 5 read replicas (15 for Aurora). They serve read-only queries — like a copy of your kitchen that only does takeout.

```
         ┌──────────────────┐
         │     PRIMARY      │
         │  (read + write)  │
         └──┬─────┬─────┬──┘
            │     │     │      async replication
            ▼     ▼     ▼
         ┌────┐ ┌────┐ ┌────┐
         │ RR │ │ RR │ │ RR │   ← Read Replicas
         │ #1 │ │ #2 │ │ #3 │     (read-only)
         └────┘ └────┘ └────┘
```

**Key facts:**
- **Asynchronous** replication (slight lag — "eventual consistency")
- Can be in same AZ, cross-AZ, or **cross-region**
- Each replica has its own DNS endpoint
- Can be promoted to standalone DB (breaks replication)
- Cross-region replicas: great for disaster recovery
- Read replicas are for **performance**, NOT high availability

### Multi-AZ vs Read Replica — The Exam Loves This

| Feature | Multi-AZ | Read Replica |
|---|---|---|
| Purpose | High availability | Read scaling |
| Replication | Synchronous | Asynchronous |
| Readable? | No (standby only) | Yes (read-only) |
| Failover? | Automatic (60-120s) | Manual promotion |
| Cross-region? | No (same region) | Yes |
| Max count | 1 standby | 5 (RDS) / 15 (Aurora) |
| Cost | ~2x | Per replica |

---

### Aurora: The Luxury Hotel Kitchen

Aurora is AWS's custom-built engine. Think of it as a luxury hotel with multiple chefs sharing one massive central pantry.

```
┌────────────────────────────────────────────────────┐
│                    AURORA CLUSTER                    │
│                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │   Primary    │  │  Replica 1  │  │  Replica 2  │  │
│  │  (writer)    │  │  (reader)   │  │  (reader)   │  │
│  └──────┬───────┘  └──────┬──────┘  └──────┬──────┘  │
│         │                 │                │          │
│  ═══════╪═════════════════╪════════════════╪═══════   │
│         │     SHARED CLUSTER STORAGE       │          │
│         │   (6 copies across 3 AZs)        │          │
│         │   Auto-grows 10GB → 128TB        │          │
│  ═══════╪══════════════════════════════════════════   │
│                                                      │
│  Endpoints:                                          │
│  • Cluster endpoint → always points to writer        │
│  • Reader endpoint  → load-balances across readers   │
│  • Instance endpoint → specific instance (avoid)     │
└──────────────────────────────────────────────────────┘
```

**Why Aurora is special:**
- **6 copies** of data across **3 AZs** (2 copies per AZ)
- Can lose 2 copies and still write, lose 3 and still read
- Storage auto-scales: 10GB to 128TB (no pre-provisioning)
- Up to **15 read replicas** (vs 5 for regular RDS)
- Failover to replica takes **< 30 seconds** (vs 60-120s for RDS)
- 5x throughput of MySQL, 3x throughput of PostgreSQL
- Compatible with MySQL 5.7/8.0 and PostgreSQL (drop-in replacement)

### Aurora Endpoints

| Endpoint | Analogy | Points To |
|---|---|---|
| **Cluster (writer)** | Main kitchen phone | Always the primary instance |
| **Reader** | Takeout hotline | Load-balances across all replicas |
| **Instance** | Direct line to one chef | Specific instance (use sparingly) |
| **Custom** | VIP line | Subset of instances you choose |

### Aurora Serverless: Kitchen That Appears on Demand

Aurora Serverless scales compute automatically. No kitchen sits idle — it materializes when guests arrive and vanishes when they leave.

```
No traffic → 0 ACUs (paused, pay $0 for compute)
Light traffic → 2 ACUs
Heavy traffic → 64 ACUs (v2 max: 256 ACUs)
```

- **ACU** = Aurora Capacity Unit (2 GB RAM each)
- **v1**: Can pause to 0 (good for dev/test). Single AZ.
- **v2**: Scales instantly, Multi-AZ, can mix with provisioned. Production-ready.
- Use case: variable/unpredictable workloads, dev/test, new apps

---

### Backups: CCTV and Photographs

**Automated Backups (CCTV Rewind = PITR)**
- Enabled by default
- Retention: 1-35 days (default 7)
- Point-in-Time Recovery: restore to any second within retention window
- Backed by transaction logs uploaded every **5 minutes**
- Backups happen during maintenance window (can cause I/O suspension on single-AZ)
- Deleted when you delete the DB instance (unless you snapshot first)

**Manual Snapshots (Photograph)**
- User-initiated, kept forever (until you delete them)
- Can copy cross-region
- Can share with other AWS accounts
- The way to migrate: snapshot → restore in new region/account

**Key exam pattern:** "How to encrypt an unencrypted database?"
→ Take snapshot → Copy snapshot with encryption → Restore from encrypted snapshot

---

### Encryption

**At Rest:**
- KMS (AES-256) — must be enabled at creation time
- Cannot encrypt an existing unencrypted DB directly
- All replicas, snapshots, and backups inherit encryption from primary
- Aurora: encrypted storage, automated backups, snapshots, replicas — all or nothing

**In Transit:**
- SSL/TLS — download RDS CA certificate, enforce in connection string
- Can force SSL via parameter group: `rds.force_ssl = 1`

### IAM Authentication

Instead of the kitchen issuing its own badges (DB username/password), you use your government ID (IAM).

- Works with MySQL and PostgreSQL
- IAM generates a 15-minute auth token
- SSL required when using IAM auth
- Good for: EC2 instances, Lambda functions (use IAM role, no passwords in code)

---

### RDS Proxy: The Receptionist

When thousands of connections hit your DB, it chokes. RDS Proxy sits in front and manages a connection pool — like a receptionist managing the queue.

```
┌────────┐  ┌────────┐  ┌────────┐
│Lambda 1│  │Lambda 2│  │Lambda 3│   ← 1000s of connections
└───┬────┘  └───┬────┘  └───┬────┘
    │           │           │
    ▼           ▼           ▼
┌──────────────────────────────────┐
│         RDS PROXY                │
│   (connection pooling)           │
│   Manages ~100 DB connections    │
└──────────────┬───────────────────┘
               │
               ▼
┌──────────────────────────────────┐
│         RDS / Aurora             │
│   (no longer overwhelmed)        │
└──────────────────────────────────┘
```

**Key facts:**
- Fully managed, serverless, highly available (Multi-AZ)
- Reduces failover time by up to 66%
- Enforces IAM authentication (no DB credentials in code)
- Perfect for Lambda (Lambda opens/closes connections rapidly)
- Supports MySQL, PostgreSQL, MariaDB, SQL Server
- Must be in the same VPC as the DB

---

### Storage

**Storage Types:**
| Type | IOPS | Use Case |
|---|---|---|
| gp2 | Burst to 3,000 IOPS (3 IOPS/GB) | General purpose |
| gp3 | Baseline 3,000 IOPS, up to 16,000 | General purpose (newer, decouple IOPS from size) |
| io1/io2 | Up to 64,000 IOPS | High-performance (OLTP) |
| Magnetic | Legacy | Don't use |

**Storage Auto Scaling:**
- Automatically increases storage when free space < 10%
- Set maximum storage threshold
- Must have at least 6 hours since last modification
- Must be low on space for 5 minutes
- Requested increase is at least 5GB or 10% of current

---

### Parameter Groups and Option Groups

**Parameter Group** = Kitchen rules (max_connections, character_set, timezone)
- DB-level configuration
- Can modify dynamically (some need reboot)
- Default parameter group is read-only — create custom one

**Option Group** = Extra kitchen features (Oracle TDE, SQL Server native backup)
- Engine-specific add-ons
- Not all engines use option groups

### Maintenance Windows

- AWS patches the OS and engine during maintenance window
- Multi-AZ: patches standby first → failover → patches old primary
- Can defer, but some patches are mandatory
- Enhanced Monitoring: OS-level metrics (CPU, memory, file system) at 1-60 second granularity
- Performance Insights: identify SQL queries causing load, visualize DB load by wait events

---

## Architecture Diagram: Full RDS Setup

```
                         Internet
                            │
                     ┌──────┴──────┐
                     │   Route 53  │
                     └──────┬──────┘
                            │
                     ┌──────┴──────┐
                     │     ALB     │
                     └──────┬──────┘
                            │
                  ┌─────────┴─────────┐
                  │    App Servers     │
                  │  (EC2 / Lambda)    │
                  └─────────┬─────────┘
                            │
                  ┌─────────┴─────────┐
                  │     RDS Proxy     │
                  │  (connection pool) │
                  └─────────┬─────────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
       ┌──────┴───┐  ┌─────┴────┐  ┌─────┴────┐
       │ Primary  │  │ Read     │  │ Standby  │
       │ (AZ-A)   │  │ Replica  │  │ Multi-AZ │
       │ R/W      │  │ (AZ-A)   │  │ (AZ-B)   │
       └──────────┘  └──────────┘  └──────────┘
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- Multi-AZ vs Read Replica (when to use each)
- Aurora vs regular RDS (cost, performance, availability)
- Encryption at rest: can't encrypt existing DB (snapshot → restore)
- RDS Proxy for Lambda connection management
- Cross-region read replicas for DR
- Storage auto scaling configuration
- Aurora Serverless v2 for variable workloads

### DVA-C02 (Developer)
- IAM authentication for RDS (token-based, no passwords)
- RDS Proxy with Lambda (connection pooling)
- Parameter groups (configuration)
- SSL enforcement in code
- Read replica endpoint usage in application code
- Aurora cluster vs reader endpoints

### SOA-C02 (SysOps)
- Maintenance windows and patching strategy
- Enhanced Monitoring vs CloudWatch metrics
- Performance Insights — diagnosing slow queries
- Storage auto scaling thresholds
- Backup retention and PITR restore process
- Multi-AZ failover testing (reboot with failover)
- Event notifications (SNS) for DB events
- Manual snapshot management and cross-region copy

---

## Key Numbers

| Metric | Value |
|---|---|
| Max DB instances per region | 40 |
| Max Read Replicas (RDS) | 5 |
| Max Read Replicas (Aurora) | 15 |
| Aurora storage range | 10 GB — 128 TB |
| Aurora data copies | 6 across 3 AZs |
| Aurora failover time | < 30 seconds |
| RDS Multi-AZ failover | 60-120 seconds |
| Automated backup retention | 1-35 days (default 7) |
| PITR granularity | 5 minutes |
| IAM auth token validity | 15 minutes |
| Max storage (gp2/gp3) | 64 TB |
| Max storage (io1/io2) | 64 TB |
| Max IOPS (io1) | 64,000 |
| Max IOPS (gp3) | 16,000 |
| RDS Proxy failover improvement | Up to 66% faster |
| gp2 burst IOPS | 3,000 |
| gp2 baseline | 3 IOPS per GB |
| Storage auto scale min increase | 5 GB or 10% |
| Enhanced Monitoring interval | 1-60 seconds |

---

## Cheat Sheet

- RDS = managed relational DB. You manage data; AWS manages infra.
- 6 engines: MySQL, PostgreSQL, MariaDB, Oracle, SQL Server, Aurora.
- Multi-AZ = HA (sync replication, auto failover, NOT readable).
- Read Replica = performance (async replication, readable, up to 5/15).
- Aurora = 6 copies across 3 AZs, auto-scaling storage, 5x MySQL speed.
- Aurora Serverless v2 = auto-scales ACUs, can go to 0 (v1) or near-zero.
- PITR = restore to any second, based on 5-min transaction log uploads.
- Snapshot = manual backup, kept forever, can copy cross-region.
- Can't encrypt existing DB — snapshot → copy encrypted → restore.
- IAM Auth = token-based, 15 min, MySQL + PostgreSQL only.
- RDS Proxy = connection pooler, perfect for Lambda, must be in same VPC.
- Storage auto scaling: kicks in when < 10% free, after 6 hours, min 5GB increase.
- Parameter group = DB config. Option group = engine-specific features.
- Enhanced Monitoring = OS metrics. Performance Insights = SQL-level analysis.
- Cluster endpoint → writer. Reader endpoint → load-balanced readers.
- CNAME Alias flips on failover — apps don't need to change connection strings.
