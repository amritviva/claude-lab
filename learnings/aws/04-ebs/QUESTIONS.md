# 04 - EBS: Exam Questions

---

## Q1 (SAA) — Volume Type Selection

A company is running a MySQL database on EC2 that requires consistent, low-latency performance with 40,000 IOPS. Which EBS volume type should they use?

A. gp3 (General Purpose SSD)
B. gp2 (General Purpose SSD)
C. io2 (Provisioned IOPS SSD)
D. st1 (Throughput Optimized HDD)

**Answer: C**

**Why C is correct:** gp3 and gp2 both max out at 16,000 IOPS. The requirement is 40,000 IOPS, which exceeds their ceiling. io2 supports up to 64,000 IOPS (or 256,000 with Block Express). For mission-critical databases needing high IOPS, io2 is the right choice. It's like needing a heavy-duty industrial cabinet (io2) because the standard office cabinet (gp3) can't hold enough drawers.

**Why others are wrong:**
- **A:** gp3 maxes at 16,000 IOPS. Can't reach 40,000.
- **B:** gp2 maxes at 16,000 IOPS. Can't reach 40,000.
- **D:** st1 is HDD-based with max 500 IOPS. Not even close, and not suitable for databases (random I/O).

---

## Q2 (SAA) — gp2 Performance

A developer has a 200 GiB gp2 EBS volume and is experiencing slow performance during peak hours. The baseline performance is too low. What are two valid solutions? (Select TWO)

A. Increase the volume size to 1,000 GiB
B. Switch to gp3 and provision 10,000 IOPS
C. Enable EBS burst mode in the console
D. Add a second gp2 volume and configure RAID 1
E. Wait for burst credits to replenish

**Answer: A, B**

**Why A and B are correct:**
- **A:** gp2 IOPS = 3 x size. 200 GiB = 600 baseline IOPS. Increasing to 1,000 GiB = 3,000 baseline IOPS. More cabinet space = more drawers = higher throughput.
- **B:** gp3 lets you set IOPS independently of size. You can have 200 GiB with 10,000 IOPS provisioned. Switch to gp3 and dial up the IOPS without changing the size.

**Why others are wrong:**
- **C:** There is no "enable burst mode" setting. Bursting happens automatically with gp2 credits. You can't toggle it on/off.
- **D:** RAID 1 is mirroring (redundancy), not performance. RAID 0 would improve performance, but RAID 1 writes the same data to both volumes.
- **E:** Waiting for credits is a temporary fix. During the next peak, the same problem occurs. The question implies this is a recurring issue.

---

## Q3 (SOA) — Cross-AZ Migration

A SysOps administrator needs to move an EBS volume from us-east-1a to us-east-1b because the EC2 instance it was attached to is being migrated. What is the correct process?

A. Detach the volume from the instance in us-east-1a and attach it to an instance in us-east-1b
B. Create a snapshot of the volume, then create a new volume from the snapshot in us-east-1b
C. Use EBS volume replication to copy the volume to us-east-1b
D. Stop the instance, change its AZ to us-east-1b, and restart

**Answer: B**

**Why B is correct:** EBS volumes are locked to a single AZ. You CANNOT move them directly. The process is: snapshot the volume (takes a photo), then create a new volume from the snapshot in the target AZ (build a new cabinet from the photo). It's like you can't carry the cabinet between cities, but you can take a blueprint and build a replica.

**Why others are wrong:**
- **A:** You cannot attach a volume to an instance in a different AZ. EBS volumes are AZ-scoped.
- **C:** There is no "EBS volume replication" feature. Snapshots are the mechanism.
- **D:** You cannot change an instance's AZ. The instance is tied to its AZ for its lifetime.

---

## Q4 (SAA) — Encryption

A solutions architect needs to encrypt an existing unencrypted EBS root volume that is attached to a running production instance. What is the correct process with minimal downtime?

A. Enable encryption on the existing volume using the ModifyVolume API
B. Create a snapshot, copy the snapshot with encryption enabled, create a new volume from the encrypted snapshot, stop the instance, detach old volume, attach new volume, start the instance
C. Create an encrypted AMI from the running instance and launch a new instance from it
D. Use AWS KMS to encrypt the volume in-place

**Answer: B**

**Why B is correct:** You cannot encrypt an existing unencrypted volume in-place. The process is: snapshot → encrypted copy → new volume → swap. The instance must be stopped briefly to swap root volumes. It's like you can't add a lock to an existing cabinet -- you have to photograph it, build a new locked cabinet from the photo, and swap them.

**Why others are wrong:**
- **A:** ModifyVolume can change type, size, and IOPS, but NOT encryption. There is no in-place encryption toggle.
- **C:** This works but creates an entirely new instance (new instance ID, new IP), which is more disruptive than swapping volumes. The question asks for minimal downtime.
- **D:** KMS provides the encryption keys but doesn't encrypt volumes in-place. KMS is the key management service, not a volume encryption service.

---

## Q5 (DVA) — Snapshots

A developer creates snapshots of a 100 GiB EBS volume daily. After 30 days, they have 30 snapshots. They need to delete snapshot #15 (from day 15). Is it safe to delete a single snapshot from the middle of the chain?

A. No, deleting a middle snapshot will corrupt all subsequent snapshots
B. No, you must delete snapshots in order (newest first)
C. Yes, AWS handles incremental snapshot data management; deleting any snapshot is safe
D. Yes, but only if you first consolidate the snapshot chain

**Answer: C**

**Why C is correct:** EBS snapshots are incremental, but AWS manages the data blocks behind the scenes. When you delete a snapshot, AWS moves any blocks that are exclusively referenced by that snapshot to the next snapshot that needs them. You can safely delete ANY snapshot without affecting others. It's like removing a photo from a photo album -- the events in other photos still exist.

**Why others are wrong:**
- **A:** AWS specifically designs snapshots to be independently deletable. No corruption occurs.
- **B:** There is no required deletion order. Delete any snapshot in any order.
- **D:** There is no "consolidate" operation for EBS snapshots. AWS handles block management automatically.

---

## Q6 (SOA) — Monitoring Burst Credits

A SysOps administrator notices intermittent performance drops on a gp2 EBS volume. The volume is 100 GiB. Which CloudWatch metric should they check first, and what is the likely cause?

A. VolumeReadOps — the application is reading too frequently
B. BurstBalance — the volume has depleted its I/O burst credits
C. VolumeQueueLength — too many pending I/O operations
D. VolumeThroughputPercentage — the volume is reaching its throughput limit

**Answer: B**

**Why B is correct:** A 100 GiB gp2 volume has 300 baseline IOPS (3 x 100). It can burst to 3,000 IOPS using credits. If the application sustains more than 300 IOPS, credits drain. When credits hit 0, performance drops to 300 IOPS baseline. The **BurstBalance** metric shows the percentage of burst credits remaining. If it's hitting 0%, that's the cause. It's like running out of sprint energy -- the soldier has to slow down to a walk.

**Why others are wrong:**
- **A:** VolumeReadOps shows total read operations but doesn't explain WHY performance drops intermittently.
- **C:** VolumeQueueLength is useful for overall I/O pressure but doesn't specifically indicate credit depletion.
- **D:** VolumeThroughputPercentage is only available for Provisioned IOPS volumes (io1/io2), not gp2.

---

## Q7 (SAA) — Multi-Attach

A company needs two EC2 instances to simultaneously read and write to the same EBS volume for a clustered database application. Both instances are in the same AZ. Which volume type supports this?

A. gp3 with Multi-Attach enabled
B. io2 with Multi-Attach enabled
C. st1 with Multi-Attach enabled
D. Any EBS volume type supports Multi-Attach

**Answer: B**

**Why B is correct:** Multi-Attach is available ONLY for io1 and io2 (Provisioned IOPS) volumes. It allows attaching a single volume to up to 16 Nitro instances in the same AZ. It's like having one shared cabinet with multiple locks -- only the premium cabinets (io1/io2) support this feature.

**Why others are wrong:**
- **A:** gp3 does NOT support Multi-Attach. Only io1/io2.
- **C:** st1 (HDD) does NOT support Multi-Attach.
- **D:** Multi-Attach is limited to io1/io2. It is NOT available on all volume types.

---

## Q8 (SAA) — Instance Store vs EBS

A machine learning training job requires the highest possible I/O performance (over 300,000 IOPS). The training data can be re-downloaded if lost. Which storage option should be used?

A. io2 Block Express (256,000 IOPS)
B. RAID 0 with multiple gp3 volumes
C. Instance Store (NVMe)
D. io2 with Multi-Attach to distribute I/O

**Answer: C**

**Why C is correct:** Instance Store (local NVMe SSD) provides millions of IOPS -- far exceeding any EBS option. Since the data can be re-downloaded if lost (fault-tolerant), the ephemeral nature of Instance Store is acceptable. It's like using the super-fast built-in shelf in the room -- blazing speed, but if the room is demolished, you'll need to re-stock from the warehouse.

**Why others are wrong:**
- **A:** io2 Block Express maxes at 256,000 IOPS. The requirement is over 300,000.
- **B:** RAID 0 with EBS volumes maxes around 260,000 IOPS. Still below requirement.
- **D:** Multi-Attach doesn't increase IOPS per volume. Both instances share the same 64,000 IOPS ceiling of the io2 volume.

---

## Q9 (SOA) — Volume Modification

A SysOps administrator needs to increase the size of a gp3 volume from 100 GiB to 500 GiB while the instance is running. Is this possible, and are there any limitations?

A. No, the instance must be stopped to modify the volume
B. Yes, use ModifyVolume API. No limitations.
C. Yes, use ModifyVolume API. But you must wait at least 6 hours between modifications, and the volume will be in "optimizing" state.
D. Yes, but you can only increase size, not decrease

**Answer: C**

**Why C is correct:** EBS volumes can be modified live (no stop/detach required): you can change size, type, and IOPS. However, after a modification, the volume enters an "optimizing" state and you must wait at least 6 hours before making another modification. Also, you'll need to extend the file system within the OS to use the new space. Size can only be increased, never decreased.

**Why others are wrong:**
- **A:** ModifyVolume works on running instances. No stop required (since 2017).
- **B:** There ARE limitations: 6-hour cooldown between modifications, must extend file system in OS, size can only increase.
- **D:** Partially correct (size can only increase) but misses the cooldown limitation and doesn't mention live modification is possible.

---

## Q10 (SAA) — Fast Snapshot Restore

A company creates new EC2 instances from EBS snapshots during Auto Scaling events. They notice that new instances have degraded I/O performance for the first few minutes after launch. How can they eliminate this initialisation penalty?

A. Use gp3 volumes instead of gp2 for higher baseline performance
B. Enable Fast Snapshot Restore (FSR) on the snapshots in the target AZs
C. Pre-warm the EBS volumes by reading all blocks after launch
D. Use Instance Store instead of EBS

**Answer: B**

**Why B is correct:** When a new volume is created from a snapshot, the data is lazily loaded from S3. First reads to blocks not yet loaded are slower (fetched on-demand from S3). Fast Snapshot Restore pre-initialises the volume so ALL blocks are available at full performance immediately. It's like pre-stocking the new cabinet before the soldier arrives, instead of bringing items from the warehouse one-by-one as requested.

**Why others are wrong:**
- **A:** gp3 has better baseline performance than gp2, but the lazy loading penalty from snapshots affects ALL EBS volume types.
- **C:** Pre-warming (reading all blocks) works but takes time and delays the instance from serving traffic. FSR eliminates this step entirely.
- **D:** Instance Store doesn't use snapshots, so no lazy loading. But Instance Store is ephemeral and can't be created from snapshots. Not a practical solution.

---

## Q11 (DVA) — DeleteOnTermination

A developer launches an EC2 instance with one root volume (gp3, 20 GiB) and one additional data volume (gp3, 100 GiB) using default settings. When the instance is terminated, what happens to the volumes?

A. Both volumes are deleted
B. Neither volume is deleted
C. Root volume is deleted; data volume persists
D. Root volume persists; data volume is deleted

**Answer: C**

**Why C is correct:** By default, the root volume has `DeleteOnTermination = true` (destroyed with the room) and additional volumes have `DeleteOnTermination = false` (kept after the room is demolished). So the root volume is deleted on termination, but the data volume survives as an unattached volume.

**Why others are wrong:**
- **A:** Only the root volume is auto-deleted by default. Additional volumes persist.
- **B:** The root volume IS deleted by default. You must explicitly set DeleteOnTermination=false on root to keep it.
- **D:** Reversed. Root is deleted (true by default), data persists (false by default).

---

## Q12 (SAA) — Cross-Region DR

A company in us-east-1 wants to set up disaster recovery in eu-west-1. Their primary database runs on EBS io2 volumes. What is the correct approach to replicate EBS data to the DR region?

A. Enable EBS cross-region replication on the volumes
B. Create EBS snapshots and copy them to eu-west-1
C. Use EBS Multi-Attach to connect volumes across regions
D. Set up AWS DataSync between the two regions

**Answer: B**

**Why B is correct:** EBS snapshots can be copied across Regions. The process: create snapshot (Regional) → copy to eu-west-1 → in DR scenario, create volumes from the copied snapshots. This can be automated with DLM (Data Lifecycle Manager) or AWS Backup. It's like taking a photo of the cabinet, sending the photo internationally, and having a replica built at the destination.

**Why others are wrong:**
- **A:** There is no native "EBS cross-region replication" feature. You must use snapshots.
- **C:** Multi-Attach only works within the SAME AZ, let alone across Regions.
- **D:** DataSync is for file-based data transfer (S3, EFS, FSx), not block-level EBS replication.
