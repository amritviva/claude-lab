# 04 - EBS: The Backpack / Cabinet

> **Analogy:** EBS is a cabinet bolted to the wall of your EC2 soldier's room -- same AZ only! Instance Store is a built-in shelf that comes with the room but gets demolished when the room is destroyed. Snapshots are photos of the cabinet stored in the national warehouse (S3).

---

## ELI10

Every soldier (EC2 instance) needs a place to store their stuff. An **EBS volume** is like a filing cabinet bolted to the wall of their room. It stays even if the soldier takes a break (stop), but it can only be in **one room in one city** (one AZ). If you want to move it to another city, you take a **photo** (snapshot) and build a new cabinet from that photo. Some rooms come with a **built-in shelf** (Instance Store) that's super fast but if the room is demolished, the shelf and everything on it is gone forever.

---

## The Concept

### EBS vs Instance Store -- Cabinet vs Built-in Shelf

| Feature | EBS | Instance Store |
|---------|-----|----------------|
| Analogy | Cabinet bolted to wall | Built-in shelf in the room |
| Persistence | Survives stop/start | **Lost on stop/terminate/hardware failure** |
| AZ scope | Single AZ | Single AZ (same host) |
| Can detach | Yes (most types) | No |
| Snapshot | Yes | No |
| Boot volume | Yes | Yes (some AMIs) |
| Performance | Up to 256,000 IOPS (io2 Block Express) | Millions of IOPS |
| Use case | Databases, persistent data | Temp storage, cache, buffers |

### EBS Volume Types -- Cabinet Tiers

This is one of the most heavily tested areas. Know these numbers cold.

```
┌─────────────────── SSD-BACKED (random I/O) ───────────────────┐
│                                                                │
│  gp3 (General Purpose SSD) ← DEFAULT CHOICE                   │
│  ├── Baseline: 3,000 IOPS, 125 MB/s (included free)           │
│  ├── Max: 16,000 IOPS, 1,000 MB/s                             │
│  ├── Size: 1 GiB - 16 TiB                                     │
│  ├── IOPS/throughput independent of size (you set them)        │
│  └── Cost: cheapest SSD                                        │
│                                                                │
│  gp2 (General Purpose SSD) ← LEGACY, still on exams           │
│  ├── Baseline: 3 IOPS per GiB (min 100 IOPS)                  │
│  ├── Max: 16,000 IOPS (at 5,334+ GiB)                         │
│  ├── Burst: up to 3,000 IOPS (credit bucket model)            │
│  ├── Size: 1 GiB - 16 TiB                                     │
│  ├── IOPS tied to volume size                                  │
│  └── Exam trap: "need more IOPS from gp2" → increase size     │
│       or switch to gp3/io2                                     │
│                                                                │
│  io2 / io2 Block Express (Provisioned IOPS SSD) ← MISSION     │
│  ├── io2: up to 64,000 IOPS, 1,000 MB/s                 CRIT  │
│  ├── io2 Block Express: up to 256,000 IOPS, 4,000 MB/s        │
│  ├── Size: 4 GiB - 64 TiB (Block Express)                     │
│  ├── 50 IOPS per GiB ratio (io2)                               │
│  ├── Multi-Attach supported (io1/io2 only!)                    │
│  ├── Sub-millisecond latency                                   │
│  └── Use: critical databases, high-performance workloads       │
│                                                                │
└────────────────────────────────────────────────────────────────┘

┌─────────────────── HDD-BACKED (sequential I/O) ──────────────┐
│                                                                │
│  st1 (Throughput Optimized HDD)                                │
│  ├── Max: 500 IOPS, 500 MB/s                                  │
│  ├── Size: 125 GiB - 16 TiB                                   │
│  ├── NOT bootable                                              │
│  └── Use: Big data, data warehouses, log processing            │
│                                                                │
│  sc1 (Cold HDD)                                                │
│  ├── Max: 250 IOPS, 250 MB/s                                  │
│  ├── Size: 125 GiB - 16 TiB                                   │
│  ├── NOT bootable                                              │
│  ├── Cheapest EBS option                                       │
│  └── Use: Infrequent access, archival                          │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### Volume Type Comparison Table

| Type | IOPS (max) | Throughput (max) | Size | Boot? | Multi-Attach? |
|------|-----------|-----------------|------|-------|---------------|
| gp3 | 16,000 | 1,000 MB/s | 1 GiB - 16 TiB | Yes | No |
| gp2 | 16,000 | 250 MB/s | 1 GiB - 16 TiB | Yes | No |
| io2 | 64,000 | 1,000 MB/s | 4 GiB - 16 TiB | Yes | Yes |
| io2 BE | 256,000 | 4,000 MB/s | 4 GiB - 64 TiB | Yes | Yes |
| st1 | 500 | 500 MB/s | 125 GiB - 16 TiB | **No** | No |
| sc1 | 250 | 250 MB/s | 125 GiB - 16 TiB | **No** | No |

### gp2 Burst Bucket Model (Exam Favourite)

```
gp2 IOPS = 3 x Volume Size (GiB)

Example: 100 GiB gp2 = 300 baseline IOPS
  - Burst: up to 3,000 IOPS
  - Burst credits: earned at baseline rate, spent at burst rate
  - Credits max out at 5.4 million I/O credits

To get 16,000 IOPS from gp2: need 5,334 GiB volume (16,000 / 3 = 5,333.3)

Better option: switch to gp3 (set IOPS independently of size)
```

### Snapshots -- Photos of the Cabinet

Snapshots are point-in-time copies of EBS volumes stored in S3 (managed by AWS, you don't see the S3 bucket).

```
EBS Volume (AZ-a)
     │
     │ create snapshot
     ▼
Snapshot (Regional, stored in S3)
     │
     ├──→ Create volume in AZ-a (same AZ)
     ├──→ Create volume in AZ-b (different AZ = migration!)
     ├──→ Copy to another Region (cross-region backup)
     └──→ Share with other accounts
```

**Key facts:**
- **Incremental**: only changed blocks are stored after the first snapshot
- Snapshots are Regional (can be used to create volumes in any AZ within the Region)
- Can copy snapshots cross-region (for DR)
- Can share snapshots with other accounts
- **Deleting a snapshot**: AWS handles incremental chain; you can safely delete any snapshot
- Snapshots are stored in S3 but you cannot access them directly via S3 API

### Fast Snapshot Restore (FSR)

- Normal snapshots: first read from new volume is slow (data must be fetched from S3)
- FSR: eliminates this latency penalty -- full performance immediately
- Costs extra (per-AZ per-hour charge)
- Must be enabled per-snapshot per-AZ

### Encryption

```
Unencrypted Volume → Can't encrypt directly!

Process to encrypt:
1. Create snapshot of unencrypted volume
2. Copy snapshot with encryption enabled (select KMS key)
3. Create new volume from encrypted snapshot
4. Swap volumes (detach old, attach new)
```

**Key facts:**
- Uses AES-256 encryption with AWS KMS
- Encryption happens transparently (no performance impact worth mentioning)
- Encrypted volumes → encrypted snapshots (and vice versa)
- Can encrypt with default AWS key or custom CMK
- Cannot change encryption after volume creation
- Root volume encryption: enable at launch or use the snapshot copy process

### Multi-Attach -- Shared Cabinet

- Available for **io1/io2 only**
- Attach a single volume to up to **16 Nitro instances** in the **same AZ**
- Each instance gets full read/write access
- Use case: clustered applications (e.g., Oracle RAC)
- Must use a cluster-aware file system (NOT ext4, NOT xfs)
- Limited to same AZ (not cross-AZ)

### RAID Configurations

| Config | Purpose | Analogy | IOPS |
|--------|---------|---------|------|
| RAID 0 | Performance (striping) | Two cabinets side by side, spread load | Up to ~260,000 IOPS |
| RAID 1 | Redundancy (mirroring) | Two identical cabinets, same data | Same IOPS, double safety |

**When RAID 0 + EBS isn't enough (>260,000 IOPS): use Instance Store.**

### EBS-Optimized Instances

- Dedicated bandwidth between EC2 and EBS
- Most current-gen instances are EBS-optimized by default
- Without it, EBS traffic competes with network traffic

### Cross-AZ Migration via Snapshot

```
Volume in AZ-a
     │
  snapshot
     │
     ▼
Snapshot (Regional)
     │
  create volume in AZ-b
     │
     ▼
Volume in AZ-b  ← Attach to instance in AZ-b
```

This is the ONLY way to move an EBS volume between AZs.

---

## Architecture Diagram

```
┌──────── AZ-a ─────────────────────────────────────────┐
│                                                        │
│  ┌─── EC2 Instance ──────────────────────────┐         │
│  │                                           │         │
│  │  Root Volume: gp3 20GB (boot)             │         │
│  │  Data Volume: gp3 500GB                   │         │
│  │  Instance Store: 475GB NVMe (ephemeral)   │         │
│  │                                           │         │
│  └───────────────────────────────────────────┘         │
│                         │                              │
│                    EBS Volumes                          │
│              (network-attached,                         │
│               same AZ only!)                           │
│                                                        │
│  ┌─── DB Instance (io2) ────────────────────┐          │
│  │                                          │          │
│  │  io2: 64,000 IOPS, 1TB                  │─┐        │
│  │  Multi-Attach to 2 instances             │ │        │
│  │                                          │ │        │
│  └──────────────────────────────────────────┘ │        │
│  ┌────────────────────────────────────────────┘        │
│  │  Second DB Instance (same io2 volume)    │          │
│  └──────────────────────────────────────────┘          │
│                                                        │
└────────────────────────────────────────────────────────┘
         │
    [Snapshot]──→ S3 (Regional, incremental)
         │
         ├──→ New volume in AZ-b (migration)
         ├──→ Copy to eu-west-1 (DR)
         └──→ Share with Account B
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- Choosing the right volume type for a workload
- gp2 vs gp3 vs io2 decision tree
- Cross-AZ migration via snapshots
- Encryption strategy (snapshot copy process)
- Multi-Attach for shared storage
- Instance Store vs EBS decision
- Cost optimization: gp3 over gp2, right-sizing

### DVA-C02 (Developer)
- EBS volume types and performance characteristics
- Snapshot lifecycle (create, copy, share)
- Encryption at rest with KMS
- Block device mappings in launch templates

### SOA-C02 (SysOps Administrator)
- Monitoring EBS performance (CloudWatch: VolumeReadOps, VolumeWriteOps, VolumeQueueLength)
- gp2 burst credits monitoring (BurstBalance metric)
- Volume modification (change type/size/IOPS on the fly)
- Snapshot management and lifecycle policies (DLM)
- Fast Snapshot Restore configuration
- RAID configuration for performance
- Troubleshooting degraded performance (check queue length, burst balance)

---

## Key Numbers

| Fact | Value |
|------|-------|
| gp3 baseline IOPS | 3,000 |
| gp3 baseline throughput | 125 MB/s |
| gp3 max IOPS | 16,000 |
| gp3 max throughput | 1,000 MB/s |
| gp2 IOPS formula | 3 x size (GiB) |
| gp2 burst IOPS | 3,000 |
| gp2 max IOPS | 16,000 (at 5,334 GiB) |
| io2 max IOPS | 64,000 |
| io2 Block Express max IOPS | 256,000 |
| io2 IOPS:GiB ratio | 50:1 |
| st1 max throughput | 500 MB/s |
| sc1 max throughput | 250 MB/s |
| HDD min size | 125 GiB |
| Max volume size | 64 TiB (io2 BE), 16 TiB (others) |
| Multi-Attach max instances | 16 (Nitro) |
| Snapshots per Region | 100,000 |
| EBS volumes per instance | ~40 (depends on instance type) |
| RAID 0 max with EBS | ~260,000 IOPS |

---

## Cheat Sheet

- EBS = network-attached storage, **single AZ only**
- Instance Store = local NVMe, blazing fast, **ephemeral** (lost on stop/terminate)
- gp3 = default choice (3,000 IOPS baseline, IOPS independent of size)
- gp2 = legacy (IOPS tied to size: 3 per GiB, burst to 3,000)
- io2 = mission-critical (64K IOPS, Multi-Attach, sub-ms latency)
- io2 Block Express = extreme (256K IOPS)
- st1/sc1 = HDD, NOT bootable, for sequential I/O
- Snapshots are incremental, stored in S3, Regional scope
- Cross-AZ migration: snapshot → create volume in new AZ
- Encryption: can't encrypt existing volume directly (snapshot → encrypt copy → new volume)
- Multi-Attach = io1/io2 only, same AZ, up to 16 Nitro instances
- FSR = pay extra for instant full performance on new volumes from snapshots
- RAID 0 for performance, RAID 1 for redundancy
- Need > 260K IOPS? Use Instance Store
- gp2 exam trap: "need more IOPS" → increase volume size or switch to gp3/io2
- DLM (Data Lifecycle Manager) automates snapshot creation/deletion
- DeleteOnTermination: true by default for root, false by default for additional volumes
