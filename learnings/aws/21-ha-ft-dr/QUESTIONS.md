# 21 — HA, FT & DR: Exam-Style Questions

---

## Q1: HA vs FT

A company runs a trading platform that processes financial transactions. They currently use RDS Multi-AZ and claim their system is "fault tolerant." Their CTO asks if this is accurate. What is the correct assessment?

- **A)** Yes — RDS Multi-AZ is fault tolerant because it has a standby replica
- **B)** No — RDS Multi-AZ provides High Availability (automatic failover in 30-60 seconds) but NOT Fault Tolerance (which requires zero interruption)
- **C)** Yes — any system with redundancy is fault tolerant by definition
- **D)** No — RDS Multi-AZ only provides Disaster Recovery, not HA or FT

**Correct Answer: B**

**Why:** RDS Multi-AZ provides HIGH AVAILABILITY — when the primary fails, automatic failover to the standby happens in 30-60 seconds. But during those 30-60 seconds, the database is UNAVAILABLE. Fault Tolerance means ZERO downtime — the system continues operating without ANY interruption. For a trading platform, 30-60 seconds of downtime could mean millions in lost trades. True FT would require something like Aurora with auto-failover in < 30 seconds or active-active DynamoDB Global Tables. HA says "we'll be back shortly." FT says "you'll never notice."

- **A is wrong:** Redundancy doesn't equal fault tolerance. The failover gap (30-60 seconds) means it's HA, not FT.
- **C is wrong:** Redundancy is necessary for BOTH HA and FT, but the differentiator is whether there's any interruption during failover.
- **D is wrong:** RDS Multi-AZ is definitely HA (automatic failover within a region). It's not DR because it operates within a single region.

---

## Q2: DR Strategy Selection

A company has a non-critical internal reporting application. They need a DR strategy with RTO of 24 hours and RPO of 24 hours. Budget is minimal. Which strategy should they choose?

- **A)** Multi-Site Active/Active
- **B)** Warm Standby
- **C)** Pilot Light
- **D)** Backup & Restore

**Correct Answer: D**

**Why:** With 24-hour RTO and 24-hour RPO, this is the most relaxed DR requirement possible. Backup & Restore is the cheapest strategy — daily backups to S3 (cross-region), daily RDS snapshots copied to DR region, AMIs copied. On disaster, restore from backups, launch infrastructure from CloudFormation, restore database. Takes hours, but that's within the 24-hour window. No running resources in DR means minimal cost. For a non-critical internal app, you don't spend on standby infrastructure when daily backups are enough.

- **A is wrong:** Multi-Site Active/Active costs 2x the infrastructure. That's like hiring a full staff for a backup hospital when you only need evacuation blueprints.
- **B is wrong:** Warm Standby runs a smaller fleet 24/7. Unnecessary cost for a non-critical app with 24-hour RTO.
- **C is wrong:** Pilot Light keeps a database running in DR 24/7. Still unnecessary for 24-hour requirements.

---

## Q3: Pilot Light vs Warm Standby

A company needs to differentiate between Pilot Light and Warm Standby for their DR planning. Which statement CORRECTLY distinguishes them?

- **A)** Pilot Light runs both compute and database in DR; Warm Standby only runs database
- **B)** Pilot Light runs minimal core infrastructure (typically just database) in DR; Warm Standby runs a scaled-down but functional version of the full stack including compute
- **C)** Pilot Light is for single-region DR; Warm Standby is for multi-region DR
- **D)** There is no meaningful difference — they are interchangeable terms

**Correct Answer: B**

**Why:** This is THE exam trap. The key differentiator is whether COMPUTE is running in DR:
- **Pilot Light:** The pilot flame — only the critical core (usually the database) is running. Compute resources are NOT running. On failover, you must LAUNCH EC2 instances, configure them, and switch DNS.
- **Warm Standby:** A scaled-down but functional production clone. DB AND compute are running (just fewer instances). On failover, you SCALE UP what's already running and switch DNS.

Warm Standby is faster to recover (RTO: minutes) because compute is already running. Pilot Light takes longer (RTO: tens of minutes) because you must launch compute from scratch.

- **A is wrong:** It's backwards. Warm Standby has more running, not less.
- **C is wrong:** Both are multi-region strategies. The distinction is about what's running, not where.
- **D is wrong:** They are explicitly different strategies with different RTO/RPO characteristics and costs.

---

## Q4: Route 53 Failover

A company uses Route 53 failover routing with a primary ALB in us-east-1 and a secondary ALB in eu-west-1. The primary ALB is healthy but the application behind it returns HTTP 500 errors. Route 53 doesn't fail over. Why?

- **A)** Route 53 doesn't support failover between regions
- **B)** The Route 53 health check is monitoring the ALB endpoint, which returns HTTP 200 (healthy ALB) even though the application returns 500 errors
- **C)** Failover routing doesn't work with ALBs — only with EC2 instances
- **D)** Route 53 health checks have a 30-minute delay before triggering failover

**Correct Answer: B**

**Why:** Route 53 health checks monitor a specific endpoint. If the health check targets the ALB itself (e.g., ALB's DNS name), the ALB returns 200 (it's running fine as a load balancer). The fact that backend targets return 500 is invisible to Route 53 unless the health check specifically targets an application endpoint that reflects the actual application health. The fix: configure the health check to hit an application health endpoint (e.g., `/health`) that checks backend systems and returns 500 when the app is unhealthy.

- **A is wrong:** Route 53 absolutely supports cross-region failover — it's one of its primary use cases.
- **C is wrong:** Route 53 failover works with any endpoint type: ALBs, EC2 instances, S3 static websites, CloudFront distributions, etc.
- **D is wrong:** Route 53 health checks run every 30 seconds (standard) or 10 seconds (fast), and failover triggers after 3 consecutive failures (default). The delay is seconds to minutes, not 30 minutes.

---

## Q5: RDS Multi-AZ vs Read Replica

A database architect needs to choose between RDS Multi-AZ and a cross-region Read Replica for a production application. The primary need is protecting against an entire AWS region going down. Which should they choose?

- **A)** RDS Multi-AZ — it provides protection against regional failures
- **B)** Cross-Region Read Replica — it provides a copy of the database in another region that can be promoted to primary
- **C)** Both — Multi-AZ for regional protection, Read Replica for read scaling
- **D)** Neither — use DynamoDB Global Tables instead

**Correct Answer: B**

**Why:** RDS Multi-AZ operates within a SINGLE region — the standby is in a different AZ but the same region. If the entire region goes down, both primary and standby are lost. A Cross-Region Read Replica exists in a completely different region. If Region A fails, promote the Read Replica in Region B to a standalone primary. The trade-off: Read Replicas use asynchronous replication, so there might be seconds of data lag (RPO > 0). But for regional disaster protection, it's the right choice.

- **A is wrong:** Multi-AZ protects against AZ failures and instance failures, NOT regional failures. Both AZs are in the same region.
- **C is wrong:** The question asks specifically about regional failure protection. Multi-AZ doesn't help with that. The correct answer combines Multi-AZ (for AZ-level HA) AND Cross-Region Read Replica (for DR), but the question asks which one protects against regional failure — that's B only.
- **D is wrong:** While DynamoDB Global Tables provide multi-region active-active, the question is about RDS specifically. You can't just switch database engines to answer a DR question.

---

## Q6: S3 Cross-Region Replication

A company enables S3 Cross-Region Replication (CRR) from their production bucket in ap-southeast-2 to a DR bucket in us-east-1. After enabling CRR, they notice existing objects are NOT replicated — only new objects are. How should they handle existing objects?

- **A)** Delete and re-upload all existing objects to trigger replication
- **B)** Use S3 Batch Replication to replicate existing objects
- **C)** CRR automatically replicates all objects — wait 24 hours for backfill
- **D)** Create a new bucket and enable CRR before uploading any objects

**Correct Answer: B**

**Why:** CRR only replicates objects uploaded AFTER replication is enabled. Existing objects are NOT automatically replicated. S3 Batch Replication is the purpose-built solution for this — it creates a batch job that replicates all existing objects (including those that failed previous replication or were created before CRR was enabled). It's a one-time operation to "backfill" the DR bucket.

- **A is wrong:** Deleting and re-uploading production data is risky (potential data loss during re-upload) and operationally expensive for large buckets.
- **C is wrong:** CRR does NOT backfill existing objects automatically. This is a common misconception and a frequently tested fact.
- **D is wrong:** Creating a new bucket and migrating is unnecessary when Batch Replication solves the problem on the existing bucket.

---

## Q7: Aurora Global Database

A company needs a database solution with < 1 minute RTO for cross-region failover and < 1 second RPO. They currently use RDS PostgreSQL. What should they migrate to?

- **A)** RDS PostgreSQL with a Cross-Region Read Replica
- **B)** Aurora PostgreSQL Global Database
- **C)** DynamoDB Global Tables
- **D)** RDS PostgreSQL Multi-AZ with daily cross-region snapshot copies

**Correct Answer: B**

**Why:** Aurora Global Database provides:
- **< 1 second replication** to secondary regions (RPO < 1 second)
- **< 1 minute** for promoting a secondary region to primary (RTO < 1 minute)
- Up to 5 secondary regions
- Uses storage-level replication (faster than logical replication)
- Compatible with PostgreSQL (direct migration path from RDS PostgreSQL)

This exactly matches the requirements: < 1 minute RTO and < 1 second RPO.

- **A is wrong:** RDS Cross-Region Read Replicas use asynchronous logical replication with seconds to minutes of lag. Promotion takes several minutes. Doesn't meet the < 1 second RPO or < 1 minute RTO requirements.
- **C is wrong:** DynamoDB Global Tables meet the performance requirements but require a complete database redesign (relational → NoSQL). The question implies they want to stay on PostgreSQL.
- **D is wrong:** Daily snapshots give RPO of up to 24 hours and RTO of hours (restore from snapshot + DNS change). Nowhere close to the requirements.

---

## Q8: DynamoDB Global Tables

A mobile gaming company uses DynamoDB and needs players in both Sydney and Tokyo to have < 10ms write latency. Their current single-region DynamoDB table in Sydney gives Tokyo players 200ms latency. What should they implement?

- **A)** DynamoDB Accelerator (DAX) in Tokyo
- **B)** DynamoDB Global Tables with replicas in both ap-southeast-2 and ap-northeast-1
- **C)** A DynamoDB read replica in Tokyo
- **D)** CloudFront in front of DynamoDB to cache responses

**Correct Answer: B**

**Why:** DynamoDB Global Tables create active-active replicas across regions. Players in Tokyo write to the Tokyo replica (< 10ms local write), and the data replicates to Sydney in < 1 second. Players in Sydney write to the Sydney replica locally. Both regions handle full read AND write traffic. This is true multi-region active-active — the strongest form of DR and the best latency for geographically distributed users.

- **A is wrong:** DAX is an in-memory cache that sits in front of DynamoDB. It reduces read latency but doesn't help with WRITE latency. Also, DAX runs in a single region — a DAX cluster in Tokyo would still write to the Sydney DynamoDB table.
- **C is wrong:** DynamoDB doesn't have "read replicas" as a concept. Global Tables is the multi-region feature.
- **D is wrong:** CloudFront caches static content and API responses. It doesn't reduce write latency to DynamoDB, and cached data could be stale.

---

## Q9: Multi-AZ Auto Scaling

An Auto Scaling Group has a desired capacity of 6, spread across 3 AZs (2 instances per AZ). AZ-A experiences a complete failure. What happens?

- **A)** The ASG maintains 4 instances across AZ-B and AZ-C (2 each), resulting in reduced capacity
- **B)** The ASG launches 2 new instances in AZ-B and AZ-C (total 8 across 2 AZs), then terminates 2 to return to desired capacity of 6
- **C)** The ASG launches 2 replacement instances in AZ-B and/or AZ-C to maintain the desired capacity of 6
- **D)** The ASG waits for AZ-A to recover before taking action

**Correct Answer: C**

**Why:** When an AZ fails, ASG detects the unhealthy instances and launches replacements in the remaining healthy AZs. The desired capacity stays at 6, so ASG launches 2 new instances across AZ-B and AZ-C (ending up with ~3 instances per surviving AZ). ASG tries to balance across available AZs but maintains the desired count. This is why you spread across multiple AZs — ASG automatically redistributes when one fails.

- **A is wrong:** ASG maintains the DESIRED capacity (6), not whatever survives the failure (4). That's the whole point of Auto Scaling — it replaces lost instances.
- **B is wrong:** ASG doesn't overshoot. It launches exactly what's needed to reach the desired capacity. The 2 lost instances are replaced with 2 new instances.
- **D is wrong:** ASG doesn't wait for AZ recovery. It immediately takes action to maintain desired capacity using available AZs.

---

## Q10: RPO and RTO Analysis

A financial company has the following requirements:
- Maximum acceptable data loss: 15 minutes
- Maximum acceptable downtime: 1 hour
- Budget is a concern but not the primary factor

Which DR strategy best fits?

- **A)** Backup & Restore (daily backups)
- **B)** Pilot Light with RDS Cross-Region Read Replica
- **C)** Warm Standby with Aurora Global Database
- **D)** Multi-Site Active/Active

**Correct Answer: B**

**Why:** RPO = 15 minutes, RTO = 1 hour. Let's evaluate:
- **Backup & Restore:** RPO = hours (daily backup → up to 24h data loss). **Fails RPO.**
- **Pilot Light:** RPO = minutes (async replication lag). RTO = ~tens of minutes (launch compute, switch DNS). **Fits both.** Cost-effective because only the DB runs in DR.
- **Warm Standby:** Fits but is more expensive (compute running 24/7 in DR). With RTO = 1 hour, you don't NEED compute pre-running.
- **Multi-Site:** Massive overkill for 1-hour RTO.

Pilot Light with a Cross-Region Read Replica gives RPO of minutes (replication lag) and RTO of tens of minutes (launch instances from pre-baked AMIs, promote read replica, switch DNS). Budget-conscious and meets both requirements.

- **A is wrong:** Daily backups → RPO of up to 24 hours. The 15-minute RPO requirement eliminates this option.
- **C is wrong:** While Warm Standby meets the requirements, it's more expensive than necessary. With 1-hour RTO tolerance, you don't need compute pre-running (Pilot Light can launch compute within that window).
- **D is wrong:** Multi-Site Active/Active for 1-hour RTO is like using a fire truck to light a candle. Wildly over-provisioned and expensive.

---

## Q11: EBS and Multi-AZ

An application stores critical data on EBS volumes attached to EC2 instances. The architect claims the data is "Multi-AZ" because they use EBS snapshots. Is this correct?

- **A)** Yes — EBS snapshots are stored in S3, which is Multi-AZ
- **B)** No — EBS volumes are single-AZ. Snapshots provide backup/recovery but not real-time Multi-AZ availability. For Multi-AZ shared storage, use EFS.
- **C)** Yes — EBS io2 volumes are Multi-AZ by default
- **D)** No — EBS doesn't support snapshots for Multi-AZ protection

**Correct Answer: B**

**Why:** EBS volumes live in a SINGLE AZ. If that AZ fails, the volume is unavailable. Snapshots are stored in S3 (Multi-AZ) and provide a BACKUP, but restoring from a snapshot takes time (not instant failover). This is Backup & Restore DR, not real-time Multi-AZ availability. For shared storage that's available across AZs, use EFS (which replicates across all AZs in a region by default).

**Note:** EBS io2 Block Express volumes DO support Multi-Attach (multiple instances in the SAME AZ), and io2 has 99.999% durability, but the volume itself still resides in one AZ.

- **A is wrong:** Snapshots in S3 provide durable BACKUP, not real-time availability. Restoring requires creating a new volume and attaching it — minutes of delay.
- **C is wrong:** io2 has high durability (99.999%) but the volume is still bound to a single AZ. Multi-Attach allows multiple EC2s to connect, but only within the same AZ.
- **D is wrong:** EBS absolutely supports snapshots. They're a core feature. But snapshots are for backup/recovery, not HA.

---

## Q12: Comprehensive DR Design

A healthcare platform must achieve:
- RPO: 0 (zero data loss)
- RTO: < 5 minutes
- Data stored in a relational database
- Compliance requires data in ap-southeast-2

Which architecture achieves this?

- **A)** RDS Multi-AZ in ap-southeast-2 with daily cross-region snapshots
- **B)** Aurora Global Database with primary in ap-southeast-2 and secondary in another region
- **C)** Aurora Multi-AZ in ap-southeast-2 (synchronous replication across AZs = zero data loss, < 30 second failover)
- **D)** DynamoDB Global Tables in ap-southeast-2 and us-east-1

**Correct Answer: C**

**Why:** RPO = 0 requires SYNCHRONOUS replication. Aurora Multi-AZ uses synchronous replication within a region (across 3 AZs) — zero data loss on AZ failure. Failover happens in < 30 seconds (well within 5-minute RTO). The data stays in ap-southeast-2 (compliance met).

The question doesn't mention REGIONAL disaster — it asks for RPO=0 and RTO < 5 min. Multi-AZ Aurora in one region meets both. If regional DR were required, Option B (Aurora Global) would be relevant, but Global DB has < 1 second replication lag (RPO > 0).

- **A is wrong:** RDS Multi-AZ has synchronous replication (RPO=0) but cross-region snapshots have hours of lag. If the question were just about AZ-level failure, RDS Multi-AZ would work, but Aurora gives faster failover.
- **B is wrong:** Aurora Global Database uses asynchronous replication (< 1 second lag). RPO is NOT zero — it's near-zero. For strict RPO=0 requirement, synchronous replication within a region is needed.
- **D is wrong:** DynamoDB is NoSQL, not relational. The question specifies relational database. Also, DynamoDB Global Tables use asynchronous replication (RPO > 0).
