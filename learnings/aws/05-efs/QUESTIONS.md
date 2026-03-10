# 05 - EFS: Exam Questions

---

## Q1 (SAA) — EFS vs EBS vs S3

A company runs a content management system on 10 EC2 instances behind an Application Load Balancer. All instances need access to the same set of uploaded images and documents. The content is updated frequently and must be immediately visible to all instances. Which storage solution is most appropriate?

A. S3 bucket accessed via the AWS SDK
B. EBS volume with Multi-Attach enabled
C. EFS file system mounted on all instances
D. Instance Store with rsync between instances

**Answer: C**

**Why C is correct:** EFS is a shared filing cabinet accessible from multiple instances across AZs simultaneously via NFS mount. Updates are immediately visible to all mounted instances. It's purpose-built for this exact use case -- shared content across a fleet of servers. Mount it on all 10 instances and they all see the same files instantly.

**Why others are wrong:**
- **A:** S3 works for static assets but requires application code changes to use the SDK (instead of file system paths). S3 is eventually consistent for new puts (though now strong read-after-write), and CMS applications typically expect a file system interface.
- **B:** EBS Multi-Attach only works for io1/io2 in the SAME AZ, and only up to 16 instances. It requires a cluster-aware file system and is designed for databases, not content sharing.
- **D:** Instance Store is ephemeral and rsync creates lag/complexity. Not suitable for real-time content sharing.

---

## Q2 (SAA) — Cost Optimization

A company stores 10 TB of data on EFS Standard. Analysis shows that 80% of files haven't been accessed in the past 60 days. How can they reduce storage costs while maintaining access to all files?

A. Move the file system to S3 Standard-IA
B. Enable EFS Lifecycle Management to transition files to Infrequent Access after 30 days
C. Switch to EFS One Zone storage class
D. Delete files older than 60 days

**Answer: B**

**Why B is correct:** EFS Lifecycle Management automatically moves files to the Infrequent Access (IA) tier after a configured period of no access (7/14/30/60/90 days). Files in IA cost ~92% less per GB. When accessed, they're read from IA tier (small per-access fee). It's like the filing cabinet automatically moving old folders to cheaper back-office storage, but you can still grab them when needed.

8 TB at IA pricing instead of Standard = massive savings.

**Why others are wrong:**
- **A:** You can't "move" EFS to S3. They're different services. You'd have to copy the data and change application code.
- **C:** One Zone reduces cost by ~47% but sacrifices multi-AZ durability for ALL files. Lifecycle Management is better because it only moves infrequent files to IA while keeping active files in Standard.
- **D:** Deleting files is data loss, not cost optimization. The company needs access to all files.

---

## Q3 (DVA) — Lambda with EFS

A developer has a Lambda function that processes machine learning models. The models total 15 GB and must be loaded at invocation. The function currently fails because Lambda's /tmp directory is limited. What is the best solution?

A. Increase Lambda's /tmp size to 15 GB
B. Store models in S3 and download them at invocation
C. Mount an EFS file system to the Lambda function
D. Package the models in a Lambda Layer

**Answer: C**

**Why C is correct:** Lambda can mount EFS file systems when the function is in a VPC. EFS provides virtually unlimited shared storage that's accessible as a standard file system path. The models are loaded from the EFS mount point without downloading. It's like giving the Lambda robot access to the shared filing cabinet in the hallway instead of trying to cram everything into its tiny locker (/tmp).

**Why others are wrong:**
- **A:** Lambda /tmp can be configured up to 10 GB (increased from 512 MB), but 15 GB exceeds this limit.
- **B:** Downloading 15 GB from S3 at every invocation would cause massive latency (30+ seconds) and Lambda would likely timeout.
- **D:** Lambda Layers have a 250 MB unzipped deployment package limit. 15 GB is way beyond this.

---

## Q4 (SOA) — Throughput Troubleshooting

A SysOps administrator notices that an EFS file system with Bursting throughput mode has degraded performance during peak hours. The file system stores 500 GiB of data. The BurstCreditBalance metric is at 0%. What should they do?

A. Switch to Provisioned throughput mode and set the required throughput
B. Add more data to the file system to increase the baseline throughput
C. Enable Max I/O performance mode
D. Create a second EFS file system and distribute the workload

**Answer: A**

**Why A is correct:** With Bursting mode, baseline throughput = 50 MiB/s per TiB. At 500 GiB (0.5 TiB), the baseline is only 25 MiB/s. When burst credits are depleted (0%), performance is capped at this low baseline. Switching to Provisioned throughput mode lets you set the throughput independently of storage size. Alternatively, Elastic throughput mode automatically scales. It's like the filing cabinet's speed is tied to how full it is -- switch to a mode where you set the speed directly.

**Why others are wrong:**
- **B:** Adding dummy data to increase throughput is a hack that wastes money. Provisioned/Elastic mode is the proper solution.
- **C:** Max I/O mode increases aggregate throughput for thousands of instances but at the cost of higher latency. It doesn't solve the burst credit problem.
- **D:** Splitting across two file systems adds complexity without solving the fundamental throughput-to-storage ratio issue.

---

## Q5 (SAA) — EFS vs FSx for Windows

A company is migrating a Windows-based file server to AWS. The application uses SMB protocol and NTFS permissions. Which AWS service should they use?

A. Amazon EFS
B. Amazon FSx for Windows File Server
C. Amazon S3 with s3fs-fuse
D. Amazon EBS with Multi-Attach

**Answer: B**

**Why B is correct:** EFS uses NFS protocol and supports **Linux only**. Windows applications using SMB protocol and NTFS permissions need FSx for Windows File Server. It's like EFS labels are written in one language (NFS/Linux) and the Windows soldiers speak a different language (SMB/Windows). FSx for Windows speaks their language.

**Why others are wrong:**
- **A:** EFS is NFS-based and Linux-only. Windows cannot natively mount EFS file systems. This is one of the most common exam traps.
- **C:** s3fs-fuse is a community tool that's not performant or suitable for production file server workloads. Also doesn't support SMB/NTFS.
- **D:** EBS Multi-Attach is io1/io2 only, same-AZ only, and doesn't provide a file system protocol like SMB.

---

## Q6 (SOA) — Mount Target Security

A SysOps administrator creates an EFS file system and mounts it on EC2 instances, but the mount fails with a timeout error. The EFS file system and EC2 instances are in the same VPC and AZ. What is the most likely cause?

A. The EFS file system is encrypted and the instance doesn't have KMS permissions
B. The mount target's Security Group doesn't allow inbound NFS traffic (port 2049) from the instance's Security Group
C. The instance is using an incorrect mount command
D. EFS is not available in this Region

**Answer: B**

**Why B is correct:** Each EFS mount target has its own Security Group. The Security Group must allow inbound TCP port 2049 (NFS) from the EC2 instances. A timeout error (not a permissions error or protocol error) is the classic symptom of a blocked port. It's like the shared filing cabinet has a bodyguard (Security Group) who isn't letting the soldier through the door.

**Why others are wrong:**
- **A:** KMS encryption issues would cause a permissions/access denied error, not a timeout. The connection would be established but authentication would fail.
- **C:** An incorrect mount command would give a syntax error or protocol error, not a timeout.
- **D:** If EFS wasn't available in the Region, the file system couldn't have been created in the first place.

---

## Q7 (SAA) — One Zone EFS

A startup is looking to reduce costs for their development environment. They currently use EFS Standard for development and testing workloads. The data is not critical and can be recreated. What should they recommend?

A. Switch to S3 Infrequent Access
B. Use EFS One Zone storage class
C. Switch to EBS gp2 volumes
D. Use Instance Store

**Answer: B**

**Why B is correct:** EFS One Zone stores data in a single AZ instead of multiple AZs, reducing cost by ~47%. For dev/test workloads where data is not critical and can be recreated, sacrificing multi-AZ durability for cost savings makes sense. It's like using a single-city filing cabinet instead of one replicated across all cities -- cheaper, but if that city has problems, you lose the files.

**Why others are wrong:**
- **A:** S3 is object storage. Switching from EFS (file system) to S3 would require application code changes. The question implies a drop-in replacement.
- **C:** EBS is single-instance (mostly). If multiple dev instances share files, EBS doesn't provide shared access like EFS.
- **D:** Instance Store is ephemeral (lost on stop/terminate) and can't be shared across instances. Too risky even for dev.

---

## Q8 (DVA) — EFS Access Points

A developer is building a multi-tenant application where each tenant stores files on a shared EFS file system. They need to ensure Tenant A cannot access Tenant B's files. What EFS feature should they use?

A. EFS encryption with separate KMS keys per tenant
B. EFS Access Points with enforced root directories per tenant
C. IAM policies restricting each tenant to specific EFS paths
D. Separate EFS file systems per tenant

**Answer: B**

**Why B is correct:** EFS Access Points create application-specific entry points with enforced root directories and user/group identity. Each tenant gets an Access Point that restricts their view to `/tenant-a/` or `/tenant-b/`. The tenant cannot navigate above their root directory. It's like giving each tenant their own key to their own drawer in the shared filing cabinet -- they can't open other drawers.

**Why others are wrong:**
- **A:** EFS encryption is at the file system level, not per-path. You can't encrypt different paths with different keys.
- **C:** IAM policies can control who can mount EFS but can't restrict access to specific file paths within EFS. File-level access is controlled by POSIX permissions and Access Points.
- **D:** Separate file systems work but are more expensive and harder to manage than a single file system with Access Points.

---

## Q9 (SAA) — Performance Mode Selection

A media company needs to mount an EFS file system on 5,000 EC2 instances for video transcoding. The aggregate throughput is more important than individual operation latency. Which performance mode should they use?

A. General Purpose performance mode
B. Max I/O performance mode
C. Provisioned throughput mode
D. Elastic throughput mode

**Answer: B**

**Why B is correct:** Max I/O performance mode is designed for workloads with thousands of concurrent connections that need the highest possible aggregate throughput. The trade-off is slightly higher per-operation latency. For video transcoding at scale (5,000 instances), aggregate throughput matters more than latency. It's like switching the filing cabinet to an industrial conveyor belt system -- moves more total files per hour, even if each individual pickup is slightly slower.

**Why others are wrong:**
- **A:** General Purpose is the default and good for most workloads, but it has a per-file-system limit on total I/O operations. With 5,000 instances, you may hit the PercentIOLimit ceiling.
- **C:** Provisioned throughput controls throughput AMOUNT, not the performance MODE. You can combine Max I/O mode WITH Provisioned throughput.
- **D:** Elastic throughput controls throughput scaling, not the I/O pattern. It's a throughput mode, not a performance mode. They're separate settings.

---

## Q10 (SOA) — Backup Strategy

A SysOps administrator needs to set up automated daily backups of an EFS file system with 30-day retention. The backups should be cross-Region for disaster recovery. What is the recommended approach?

A. Use rsync on a cron job to copy files to S3 daily
B. Use AWS Backup with a backup plan for EFS, including cross-Region copy rules
C. Create EFS snapshots daily using Lambda
D. Use EFS replication to mirror data to another Region

**Answer: B**

**Why B is correct:** AWS Backup is the recommended service for EFS backups. It supports automated backup plans with schedules, retention policies, and cross-Region copy rules. It's a managed service that handles the complexity. It's like hiring a professional archiving service instead of manually photocopying files every day.

**Why others are wrong:**
- **A:** rsync is manual, error-prone, and doesn't provide point-in-time recovery. It also requires maintaining EC2 instances for the cron job.
- **C:** EFS doesn't have a native "snapshot" API like EBS. AWS Backup is the mechanism for EFS backups.
- **D:** EFS Replication is for continuous replication, not point-in-time backups with retention. Replication mirrors deletions too -- if a file is accidentally deleted, the deletion replicates.

---

## Q11 (SAA) — Encryption Requirements

A company requires all data at rest to be encrypted. They create an EFS file system but forget to enable encryption. The file system now contains 500 GiB of data. How can they encrypt it?

A. Enable encryption on the existing file system using the console
B. Create a new encrypted EFS file system and migrate data using AWS DataSync
C. Use AWS KMS to encrypt the file system in-place
D. Enable encryption via the EFS API UpdateFileSystem call

**Answer: B**

**Why B is correct:** EFS encryption at rest must be enabled at file system creation time. It cannot be added to an existing file system. The only path is: create a new encrypted file system, migrate data using DataSync (or rsync), and delete the old one. It's like the filing cabinet's lock must be built into it at the factory -- you can't add a lock after it's been deployed.

**Why others are wrong:**
- **A:** There is no option to enable encryption after creation. The setting is immutable.
- **C:** KMS provides the encryption keys but cannot retroactively encrypt an EFS file system.
- **D:** UpdateFileSystem can change throughput mode and lifecycle policies, but NOT encryption.

---

## Q12 (DVA) — EFS with Containers

A developer is running an ECS Fargate task that needs persistent shared storage accessible by multiple tasks. The tasks run on Linux. Which storage option integrates with Fargate?

A. EBS volumes mounted to Fargate tasks
B. EFS file system mounted to Fargate tasks
C. Instance Store attached to Fargate tasks
D. S3 mounted as a file system via s3fs

**Answer: B**

**Why B is correct:** EFS integrates natively with ECS Fargate. You define an EFS volume in the task definition, and Fargate automatically mounts it. Multiple Fargate tasks can share the same EFS file system. It's like the shared hallway filing cabinet being accessible to any container (robot worker) in any city (AZ).

**Why others are wrong:**
- **A:** EBS cannot be mounted to Fargate tasks. EBS requires an EC2 host, which Fargate abstracts away.
- **C:** Instance Store requires a physical host. Fargate is serverless -- there's no instance to have Instance Store.
- **D:** s3fs is a FUSE-based tool that's unreliable and not officially supported. Not suitable for production Fargate workloads.
