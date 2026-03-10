# RDS — Exam Questions

> 10+ scenario-based questions mixing SAA-C03, DVA-C02, and SOA-C02 perspectives.

---

### Q1 (SAA) — Multi-AZ vs Read Replica

A company runs a production MySQL database on RDS. The application experiences heavy read traffic during business hours but the primary concern is **ensuring zero downtime during an AZ failure**. Which solution addresses this requirement?

A. Create 3 Read Replicas across different AZs
B. Enable Multi-AZ deployment
C. Use Aurora with 15 Read Replicas
D. Create a cross-region Read Replica and promote it during failure

**Answer: B**

**Why B is correct:** Multi-AZ provides automatic failover with synchronous replication. When the primary AZ fails, the standby takes over in 60-120 seconds with zero data loss. The DNS endpoint flips automatically — no application changes needed. Think of it as having a second kitchen in a different city that's kept perfectly in sync. When kitchen #1 burns down, the phone number automatically routes to kitchen #2.

**Why A is wrong:** Read Replicas use async replication and don't provide automatic failover. They're copy kitchens for takeout only — if the main kitchen burns down, you'd have to manually promote a replica, which takes time and may lose recent data.

**Why C is wrong:** While Aurora is excellent, the question asks specifically about zero downtime during AZ failure for a MySQL RDS instance. Multi-AZ is the direct answer. Aurora would be a migration, not a configuration change.

**Why D is wrong:** Cross-region Read Replicas are for disaster recovery, not AZ-level failover. Manual promotion is required, which doesn't meet "zero downtime."

---

### Q2 (DVA) — Lambda + RDS Connection Management

A developer's Lambda function connects to an RDS PostgreSQL database. Under load, the database hits its `max_connections` limit and new Lambda invocations fail with "too many connections" errors. What is the MOST operationally efficient solution?

A. Increase the RDS instance size to get a higher max_connections limit
B. Use Amazon RDS Proxy between Lambda and the database
C. Implement connection pooling logic within the Lambda function code
D. Reduce Lambda reserved concurrency to match max_connections

**Answer: B**

**Why B is correct:** RDS Proxy is purpose-built for this. It pools and shares database connections across many Lambda invocations. Lambda opens/closes connections rapidly (each invocation = new connection), which overwhelms the DB. RDS Proxy acts as a receptionist — managing a queue of connections so the DB only sees a manageable number. It also supports IAM auth, eliminating passwords in code.

**Why A is wrong:** Scaling up the instance increases max_connections, but it's expensive and doesn't solve the root problem. Lambda can spawn thousands of concurrent instances — no RDS instance size can keep up.

**Why C is wrong:** Lambda execution contexts are ephemeral and isolated. You can't share a connection pool across invocations like you would in a long-running server. Connection pooling inside Lambda code doesn't help.

**Why D is wrong:** This artificially limits your application throughput. You're throttling Lambda to protect the database — the tail wagging the dog. RDS Proxy solves this without sacrificing throughput.

---

### Q3 (SOA) — Encrypting an Existing Database

A SysOps administrator needs to enable encryption at rest for an existing unencrypted RDS MySQL production database with minimal downtime. What is the correct approach?

A. Modify the RDS instance and enable encryption
B. Create a snapshot, copy the snapshot with encryption enabled, restore from the encrypted snapshot
C. Enable encryption on the existing EBS volumes attached to the RDS instance
D. Create an encrypted Read Replica, then promote it to primary

**Answer: B**

**Why B is correct:** You cannot enable encryption on an existing unencrypted RDS instance. The only path is: snapshot → copy snapshot with encryption → restore from encrypted copy. It's like taking a photograph of the kitchen, making an encrypted copy, then rebuilding the kitchen from that encrypted photograph. You'll need to update your application's connection string to point to the new instance.

**Why A is wrong:** RDS does not allow modifying encryption settings after creation. This option simply doesn't exist in the console or API.

**Why C is wrong:** You don't have access to the underlying EBS volumes in RDS — it's managed. You can't modify them directly.

**Why D is wrong:** You cannot create an encrypted Read Replica from an unencrypted source. Replicas inherit the encryption setting of the primary.

---

### Q4 (SAA) — Aurora vs Standard RDS

A startup is launching a new application that expects unpredictable traffic — from near-zero users at night to potential viral spikes during the day. They need a PostgreSQL-compatible database. Cost optimization is critical. Which solution is BEST?

A. RDS PostgreSQL with Multi-AZ and Read Replicas
B. Aurora PostgreSQL with Provisioned capacity
C. Aurora Serverless v2 PostgreSQL
D. RDS PostgreSQL on a db.t3.micro with storage auto scaling

**Answer: C**

**Why C is correct:** Aurora Serverless v2 scales ACUs automatically based on demand. Near-zero traffic = minimal ACUs (near-zero cost). Viral spike = scales up to 256 ACUs instantly. You don't pre-provision anything. It's the kitchen that appears when guests walk in and shrinks when they leave. PostgreSQL compatible, Multi-AZ capable, and cost-optimized for variable workloads.

**Why A is wrong:** Provisioned RDS instances run 24/7 regardless of traffic. You'd pay for a large instance to handle spikes even during zero-traffic periods. Not cost-optimized for unpredictable workloads.

**Why B is wrong:** Provisioned Aurora still requires you to choose instance sizes. You'd either over-provision (wasteful) or under-provision (can't handle spikes).

**Why D is wrong:** db.t3.micro can't handle viral spikes. Burstable instances have CPU credit limits and would throttle under sustained load.

---

### Q5 (SOA) — Backup and Recovery

An administrator notices that automated backups for an RDS instance have a retention period of 7 days. The business requires the ability to restore the database to any point within the last 30 days. Additionally, they need a backup that persists even if the RDS instance is deleted. What TWO actions should be taken?

A. Increase automated backup retention to 35 days and take a manual snapshot before any planned deletion
B. Increase automated backup retention to 30 days — automated backups persist after instance deletion
C. Create a cross-region Read Replica as a backup mechanism
D. Use AWS Backup with a 30-day retention policy and enable manual snapshots

**Answer: A**

**Why A is correct:** Two separate needs, two solutions: (1) Change retention to 30 days for PITR capability. Automated backups support 1-35 days, so 30 is within range. (2) Take a manual snapshot before deletion because automated backups are DELETED when the instance is deleted. Manual snapshots persist forever until you explicitly delete them. It's like CCTV (auto-backup) that gets erased when you demolish the building, vs a photograph (manual snapshot) you keep in your safe.

**Why B is wrong:** The first part is correct (increase retention), but the second part is false — automated backups do NOT persist after instance deletion. This is a critical exam trap.

**Why C is wrong:** Read Replicas are not backups. They provide continuous replication but don't give you point-in-time recovery to an arbitrary second.

**Why D is wrong:** While AWS Backup can manage RDS backups, the question's requirements are fully met by native RDS features. AWS Backup adds complexity without additional benefit here. The key trap is knowing that automated backups don't survive instance deletion.

---

### Q6 (DVA) — IAM Authentication

A developer is building a Lambda function that connects to an RDS MySQL database. The security team mandates that no database passwords should be stored anywhere — not in environment variables, not in Secrets Manager. How should the developer configure database authentication?

A. Use IAM database authentication with an auth token
B. Store credentials in AWS Systems Manager Parameter Store with SecureString
C. Use Cognito User Pool tokens to authenticate to RDS
D. Configure the RDS instance to allow passwordless connections from the Lambda VPC

**Answer: A**

**Why A is correct:** IAM database authentication generates a temporary auth token (valid 15 minutes) using the Lambda function's IAM role. No password stored anywhere — the role itself IS the credential. The Lambda requests a token from RDS using its IAM identity, then uses that token as the password in the MySQL connection. Like using your government-issued ID to enter the kitchen instead of the kitchen's own badge system.

**Why B is wrong:** Parameter Store SecureString still stores a password — it's just encrypted at rest. The security team said NO passwords anywhere.

**Why C is wrong:** Cognito doesn't authenticate directly to RDS. Cognito is for user-facing authentication, not database connections.

**Why D is wrong:** RDS doesn't support passwordless connections. Even within a VPC, authentication is required.

---

### Q7 (SAA) — Aurora Cluster Architecture

A solutions architect needs to design a highly available Aurora MySQL cluster for a critical application. The application has a write-heavy primary workload and a separate analytics workload that runs complex read queries. How should the endpoints be configured?

A. Use the cluster endpoint for both workloads
B. Use the cluster endpoint for writes and the reader endpoint for analytics
C. Use instance endpoints for both workloads to control exactly which instance handles each
D. Create a custom endpoint for the analytics workload pointing to larger replica instances

**Answer: D**

**Why D is correct:** Custom endpoints let you group specific instances. You can have larger instances for heavy analytics queries and smaller ones for simple reads. The analytics workload hits the custom endpoint (pointing to beefy replicas), while the write workload uses the cluster endpoint. The reader endpoint would load-balance across ALL replicas, including small ones that might choke on complex analytics queries.

**Why A is wrong:** The cluster endpoint always points to the writer. Running analytics on the writer would degrade write performance.

**Why B is wrong:** This is a reasonable answer but not BEST. The reader endpoint distributes across ALL replicas equally. If you have mixed-size replicas, analytics queries could land on small instances.

**Why C is wrong:** Instance endpoints point to specific instances and don't failover. If that instance dies, your application breaks. Aurora's endpoint abstraction exists specifically to avoid this.

---

### Q8 (SOA) — Performance Troubleshooting

An RDS PostgreSQL instance is experiencing intermittent slowdowns. CloudWatch shows CPU utilization averaging 40%, but users report multi-second query latencies during peak hours. What is the BEST tool to identify the root cause?

A. Enable Enhanced Monitoring to check OS-level metrics
B. Enable Performance Insights to identify top SQL queries by wait events
C. Check CloudWatch ReadIOPS and WriteIOPS metrics
D. Enable slow query logging in the parameter group

**Answer: B**

**Why B is correct:** Performance Insights shows you exactly which SQL queries are consuming resources and what they're waiting on (CPU, I/O, locks, etc.). CPU at 40% average can hide spikes, but more importantly, the issue might be lock contention or I/O waits — not CPU at all. Performance Insights visualizes DB load broken down by wait events and top SQL, making it the fastest path to root cause.

**Why A is wrong:** Enhanced Monitoring shows OS metrics (memory, swap, disk, network) but doesn't show SQL-level detail. If the issue is a bad query, Enhanced Monitoring won't find it.

**Why C is wrong:** IOPS metrics tell you about storage throughput but don't identify WHICH queries are causing the load.

**Why D is wrong:** Slow query logging helps but requires you to parse logs manually. Performance Insights gives you a visual dashboard immediately.

---

### Q9 (SAA) — Cross-Region Disaster Recovery

A company with its primary database in us-east-1 needs a disaster recovery strategy with an RPO (Recovery Point Objective) of less than 1 minute and an RTO (Recovery Time Objective) of less than 5 minutes. Which approach meets these requirements?

A. RDS with automated backups and cross-region snapshot copy
B. Aurora Global Database
C. RDS with a cross-region Read Replica
D. RDS Multi-AZ with automated backups

**Answer: B**

**Why B is correct:** Aurora Global Database provides cross-region replication with less than 1-second lag (RPO < 1 second) and failover in under 1 minute (RTO < 5 minutes). It replicates at the storage layer, not the database layer, making it extremely fast. Like having the luxury hotel chain replicate its central pantry to another country in real-time.

**Why A is wrong:** Snapshot copy is periodic, not continuous. RPO could be hours depending on snapshot frequency. Restore time is also much longer than 5 minutes.

**Why C is wrong:** Cross-region Read Replicas use async replication, so RPO is typically seconds to minutes (not guaranteed < 1 minute). Promotion to primary is manual and takes several minutes, likely exceeding 5-minute RTO.

**Why D is wrong:** Multi-AZ is same-region only. It doesn't protect against a full regional disaster.

---

### Q10 (DVA) — Parameter Groups

A developer needs to change the `max_connections` setting on a production RDS MySQL instance. They modify the parameter in a custom parameter group, but the change doesn't take effect. What is the MOST LIKELY reason?

A. The parameter group is not associated with the RDS instance
B. The `max_connections` parameter is a static parameter that requires a reboot
C. Parameter group changes require a new DB instance to take effect
D. The developer modified the default parameter group, which is read-only

**Answer: B**

**Why B is correct:** RDS parameters are either **dynamic** (apply immediately) or **static** (require reboot). `max_connections` is static in some contexts — the pending-reboot status means the change is queued but not applied. The developer needs to reboot the instance. It's like changing the kitchen's maximum occupancy sign — you need to close and reopen to enforce the new limit.

**Why A is wrong:** If the parameter group weren't associated, none of its settings would apply, not just max_connections. The question implies other settings work.

**Why C is wrong:** Parameter groups can be modified and applied to existing instances — you don't need a new instance.

**Why D is wrong:** The question says "custom parameter group," so it's not the default read-only one.

---

### Q11 (SOA) — Multi-AZ Failover Testing

A SysOps administrator needs to test the Multi-AZ failover behavior of a production RDS instance to verify the application handles failover correctly. What is the recommended approach?

A. Stop the primary instance from the console
B. Reboot the primary instance with the "Reboot with failover" option
C. Terminate the primary instance and let the standby promote
D. Modify the instance to disable Multi-AZ, then re-enable it

**Answer: B**

**Why B is correct:** "Reboot with failover" is the AWS-recommended way to test Multi-AZ failover. It forces the primary to failover to the standby, simulating a real AZ failure without data loss or instance termination. The DNS CNAME flips to the standby, and you can observe how your application handles the ~60-120 second interruption.

**Why A is wrong:** Stopping an RDS instance is not the same as an AZ failure. It doesn't trigger a Multi-AZ failover — it just stops the instance entirely.

**Why C is wrong:** Terminating (deleting) the instance is destructive. You'd lose the instance permanently. This is NOT how you test failover.

**Why D is wrong:** Disabling/re-enabling Multi-AZ doesn't simulate failover. It would sync data again from scratch, which takes time and doesn't test your application's failover handling.

---

### Q12 (SAA) — Storage Type Selection

A financial trading application requires consistent I/O performance with at least 40,000 IOPS for its RDS Oracle database. Which storage type should the solutions architect choose?

A. gp2 with a 14 TB volume
B. gp3 with provisioned IOPS set to 40,000
C. io1 with provisioned IOPS set to 40,000
D. io2 with provisioned IOPS set to 40,000

**Answer: C or D (both acceptable; D is newer and preferred)**

**Why C/D is correct:** io1/io2 (Provisioned IOPS SSD) supports up to 64,000 IOPS with guaranteed, consistent performance. For a trading application requiring exactly 40,000 IOPS, you need provisioned I/O — not burst-based. io2 is the newer generation with better durability (99.999% vs 99.9%). Like having a dedicated high-speed supply chain to the kitchen — guaranteed deliveries, no waiting.

**Why A is wrong:** gp2 delivers 3 IOPS/GB. To get 40,000 IOPS, you'd need 13.3 TB. The 14 TB volume gets you ~42,000 max, but gp2 performance is burst-based above 3,000 IOPS baseline for smaller volumes. Not guaranteed consistent.

**Why B is wrong:** gp3 supports up to 16,000 IOPS max. 40,000 IOPS exceeds gp3's ceiling.

---

### Q13 (DVA) — Aurora Reader Endpoint Behavior

A developer has an Aurora cluster with 1 writer and 3 reader instances. They configure the application to use the reader endpoint for all SELECT queries. One reader instance is significantly slower than the others due to a long-running analytics query. What will happen?

A. The reader endpoint automatically excludes the slow instance
B. The reader endpoint continues to route traffic to all 3 readers using round-robin, causing some application queries to be slow
C. The reader endpoint shifts traffic to the writer instance
D. The reader endpoint detects the slow instance and redirects to the fastest reader

**Answer: B**

**Why B is correct:** The reader endpoint uses simple DNS round-robin load balancing across all reader instances. It doesn't consider instance load, query latency, or health (beyond basic health checks). One slow reader means ~33% of queries will be slow. The endpoint is a phone line that rings each replica in turn — it doesn't know one kitchen is backed up with a complicated order.

**Why A is wrong:** The reader endpoint doesn't do intelligent routing. It's DNS-based round-robin, not application-level load balancing.

**Why C is wrong:** The reader endpoint never routes to the writer instance. Writer and reader endpoints are separate.

**Why D is wrong:** No latency-based routing exists for the reader endpoint. If you need this, use a custom endpoint or application-level routing.
