# 06 - S3: Exam Questions

---

## Q1 (SAA) — Storage Class Selection

A healthcare company must retain patient records for 7 years. Records are accessed frequently for the first 30 days, occasionally for the next year, and almost never after that. They need the most cost-effective storage strategy while ensuring compliance. What lifecycle configuration should they use?

A. Store in S3 Standard. Transition to Glacier Deep Archive after 30 days. Delete after 7 years.
B. Store in S3 Standard. Transition to Standard-IA after 30 days. Transition to Glacier Flexible after 365 days. Transition to Glacier Deep Archive after 730 days. Delete after 2,555 days (7 years).
C. Store in S3 Intelligent-Tiering for the entire 7 years
D. Store in Glacier Deep Archive from day 1. Delete after 7 years.

**Answer: B**

**Why B is correct:** This matches the access pattern perfectly: hot (Standard, 30 days) → warm (Standard-IA, occasional access for a year) → cold (Glacier Flexible, rarely accessed) → frozen (Deep Archive, compliance retention). Each transition moves data to a cheaper room in the warehouse while maintaining accessibility when needed. The lifecycle waterfall minimizes cost at each stage.

**Why others are wrong:**
- **A:** Jumping straight to Deep Archive after 30 days means the "occasional access" in the next year requires 12-48 hour retrieval times. Too slow for records that might be needed.
- **C:** Intelligent-Tiering works but has a monthly monitoring fee per object. For predictable access patterns (well-known in healthcare), explicit lifecycle rules are cheaper than paying the monitoring fee on millions of objects.
- **D:** Records accessed frequently in the first 30 days can't be in Deep Archive (12-48 hour retrieval). This makes the data practically inaccessible when needed most.

---

## Q2 (DVA) — Pre-signed URLs

A developer builds an application where users can download private files from S3. The files should only be accessible for 1 hour after the user requests a download link. The developer's Lambda function uses an IAM role. What is the maximum expiration time for the pre-signed URL?

A. 1 hour
B. 6 hours
C. 12 hours (IAM role limit)
D. 7 days (IAM user limit)

**Answer: C**

**Why C is correct:** Pre-signed URLs generated using IAM role credentials (like Lambda's execution role) have a maximum expiration of 12 hours (the maximum duration of STS temporary credentials). URLs generated with IAM user credentials can last up to 7 days. Since the developer uses a Lambda function (which uses an IAM role), the max is 12 hours. The 1-hour requirement is well within this limit.

**Why others are wrong:**
- **A:** 1 hour is the default, not the maximum. The max for role-based credentials is 12 hours.
- **B:** 6 hours is the default STS session duration, not the maximum pre-signed URL expiry.
- **D:** 7 days is the maximum for IAM USER credentials, not role credentials. Lambda uses roles.

---

## Q3 (SAA) — Cross-Account Access

Company A needs to give Company B's EC2 instances read access to an S3 bucket. The traffic must stay within AWS's network. What is the recommended approach?

A. Make the bucket public with a condition restricting access to Company B's IP range
B. Create a bucket policy granting access to Company B's IAM role ARN
C. Create a pre-signed URL and share it with Company B
D. Enable S3 cross-region replication to Company B's bucket

**Answer: B**

**Why B is correct:** A bucket policy (resource-based policy) can grant access to specific IAM principals in other accounts by ARN. Company B's EC2 instances assume their IAM role, and the bucket policy in Company A allows that role. Traffic stays on AWS's private network. It's like writing a law on the warehouse door that says "visitors carrying this specific VIP badge from Country B can enter and read."

Company B's role also needs S3 permissions in its identity policy (both sides must allow for cross-account).

**Why others are wrong:**
- **A:** Making a bucket public is a massive security risk. IP-based restrictions are fragile (IPs can change) and don't verify identity.
- **C:** Pre-signed URLs are for temporary access to individual objects, not ongoing programmatic access for EC2 instances. They expire and aren't practical at scale.
- **D:** Replication copies data to another bucket. The question asks for access to the original bucket, not a copy. Replication also costs storage for the duplicate.

---

## Q4 (SOA) — Troubleshooting Public Access

A SysOps administrator configures an S3 bucket for static website hosting. They set a bucket policy allowing public read access (`"Principal": "*"`), but users still get 403 Forbidden errors. What is the most likely cause?

A. The bucket doesn't have a website hosting configuration enabled
B. S3 Block Public Access is enabled at the account or bucket level
C. The objects need individual ACLs granting public read
D. The bucket name doesn't match the domain name

**Answer: B**

**Why B is correct:** S3 Block Public Access overrides bucket policies and ACLs that grant public access. Even with a perfect bucket policy, if Block Public Access is enabled (which it is by default on new buckets), public access is blocked. It's like having a master lock on the warehouse that overrides all individual section access rules.

**Why others are wrong:**
- **A:** Without website hosting configuration, the bucket wouldn't serve web pages, but the objects would still be accessible via the S3 API URL (not the website URL). The 403 on the website URL would be a 404, not a 403.
- **C:** Bucket policies override the need for individual ACLs. If the bucket policy allows Principal *, ACLs aren't needed.
- **D:** Bucket name / domain name mismatch would cause DNS/routing issues, not 403 Forbidden.

---

## Q5 (SAA) — Replication

A company has an S3 bucket in us-east-1 that serves as their primary data store. They need to replicate data to eu-west-1 for disaster recovery. The bucket was created 6 months ago and already contains 2 TB of data. After enabling Cross-Region Replication (CRR), what happens?

A. All 2 TB of existing data is automatically replicated to eu-west-1
B. Only new objects uploaded after enabling CRR are replicated; existing objects are not
C. All existing and new objects are replicated, but existing objects take up to 24 hours
D. CRR cannot be enabled on a bucket that already contains data

**Answer: B**

**Why B is correct:** S3 Replication (CRR/SRR) is NOT retroactive. Only objects PUT after replication is enabled are replicated. Existing objects must be manually copied (e.g., using S3 Batch Replication or `aws s3 sync`). It's like installing a new photocopier that copies everything fed into it going forward -- it doesn't go back and copy what's already in the filing cabinet.

**Why others are wrong:**
- **A:** Replication is not retroactive. This is one of the most tested S3 facts.
- **C:** Existing objects are NOT automatically replicated at any speed. You must use S3 Batch Replication (a separate feature) to replicate existing objects.
- **D:** CRR can absolutely be enabled on existing buckets. It just won't replicate what's already there.

---

## Q6 (DVA) — SSE-KMS Throttling

A developer's application uploads 10,000 objects per second to S3 with SSE-KMS encryption. The application starts receiving `ThrottlingException` errors from KMS. What are two valid solutions? (Select TWO)

A. Switch to SSE-S3 encryption
B. Enable S3 Bucket Key to reduce KMS API calls
C. Request a KMS API rate limit increase
D. Use client-side encryption instead
E. Reduce the upload rate to 5,500 per second

**Answer: A, B**

**Why A and B are correct:**
- **A:** SSE-S3 uses Amazon-managed keys with no KMS API calls. Zero KMS throttling. The trade-off is losing the KMS audit trail in CloudTrail.
- **B:** S3 Bucket Key generates a bucket-level data key that encrypts individual object keys locally, reducing KMS API calls by up to 99%. 10,000 objects might only need 1-2 KMS calls instead of 10,000.

**Why others are wrong:**
- **C:** KMS rate limits can be increased (up to 30,000 req/sec in some Regions) by contacting AWS, but it's a temporary fix. The fundamental issue is making too many KMS calls per object.
- **D:** Client-side encryption works but requires the application to manage encryption/decryption, key management, and adds complexity. It's a valid but less practical solution.
- **E:** Reducing upload rate throttles the application's functionality. The goal is to fix the KMS issue, not slow down the application.

---

## Q7 (SAA) — Versioning and Deletion

A company enables S3 versioning on a critical bucket. An employee accidentally deletes the file `reports/annual-2024.pdf`. A month later, they need to recover it. Is recovery possible?

A. No, once deleted the file is permanently gone
B. Yes, delete the "delete marker" to restore the file
C. Yes, but only within 30 days of deletion (versioning retention period)
D. Yes, restore from S3 Glacier

**Answer: B**

**Why B is correct:** With versioning enabled, a DELETE operation doesn't actually remove the object -- it adds a "delete marker" (a special version that makes the object appear deleted). All previous versions still exist. To recover: delete the delete marker, and the latest version before deletion becomes the current version. It's like putting a "DELETED" sticky note on the box -- remove the sticky note and the box reappears.

**Why others are wrong:**
- **A:** Versioning exists specifically to prevent permanent accidental deletion. Previous versions survive DELETE operations.
- **C:** There is no "30-day retention period" for versioning. Versions persist indefinitely until explicitly deleted by version ID.
- **D:** Glacier is a storage class, not a backup/recovery mechanism for versioned objects. The file isn't in Glacier unless a lifecycle rule moved it there.

---

## Q8 (SAA) — Object Lock

A financial institution must store transaction records in S3 in a way that guarantees no one -- not even root account users -- can delete or modify them for 5 years. Which configuration satisfies this requirement?

A. S3 Versioning with MFA Delete enabled
B. S3 Object Lock in Governance mode with 5-year retention
C. S3 Object Lock in Compliance mode with 5-year retention
D. S3 Glacier Vault Lock with a compliance policy

**Answer: C**

**Why C is correct:** Object Lock in **Compliance mode** is truly immutable -- NO ONE can delete or overwrite the object during the retention period, not even the root user or AWS. It satisfies WORM (Write Once Read Many) requirements. It's like sealing a box in a tamper-proof safe that physically cannot be opened until the timer expires.

**Why others are wrong:**
- **A:** MFA Delete adds a layer of protection but doesn't prevent deletion entirely. A user WITH MFA could still delete. Not a true WORM guarantee.
- **B:** Governance mode allows users with special permissions (`s3:BypassGovernanceRetention`) to override the lock. A root user could bypass it. Not truly immutable.
- **D:** Glacier Vault Lock works for Glacier vaults but the question specifies S3 (not Glacier). Also, Vault Lock applies to an entire vault, not individual objects.

---

## Q9 (SOA) — S3 Performance

A data analytics team uploads thousands of files to S3, all with the key prefix `data/2024/01/`. They're experiencing performance issues on PUT requests. What is the recommended solution?

A. Enable S3 Transfer Acceleration
B. Use different key prefixes to distribute the load (e.g., data/2024/01/a/, data/2024/01/b/)
C. Increase the S3 service quota for PUT requests
D. Switch to S3 Intelligent-Tiering for better performance

**Answer: B**

**Why B is correct:** S3 supports 3,500 PUT/DELETE and 5,500 GET/HEAD requests per second **per prefix**. If all files go to the same prefix, they share one prefix's throughput limit. Distributing files across multiple prefixes multiplies the available throughput. It's like having one warehouse aisle (prefix) -- if everyone crowds the same aisle, it's slow. Spread across multiple aisles and throughput multiplies.

Note: AWS improved S3 performance significantly in 2018, so random prefixes are less critical than before, but for extreme volumes, distributing prefixes still helps.

**Why others are wrong:**
- **A:** Transfer Acceleration speeds up uploads from distant locations via edge locations. It doesn't solve per-prefix throughput limits.
- **C:** S3 performance limits are per-prefix, not account-level quotas. You can't "increase" the per-prefix limit via a quota request.
- **D:** Storage class doesn't affect PUT/GET performance. Intelligent-Tiering is about cost, not throughput.

---

## Q10 (DVA) — Event Notifications

A developer needs to process images uploaded to S3 by generating thumbnails. The thumbnail Lambda function takes 30 seconds per image. During peak hours, 1,000 images are uploaded per minute. The Lambda function is falling behind. What architecture improvement should they make?

A. Increase Lambda timeout to 5 minutes
B. Configure S3 event notifications to send to an SQS queue, and have Lambda poll the queue
C. Use S3 batch operations to process images
D. Enable S3 Transfer Acceleration to speed up processing

**Answer: B**

**Why B is correct:** Direct S3 → Lambda notifications can cause Lambda concurrency issues under high load (1,000 concurrent invocations). Adding SQS as a buffer decouples the upload rate from processing rate. Lambda polls the queue at a controlled rate, handles retries on failure, and the queue absorbs burst traffic. It's like adding a mailroom (SQS) between the warehouse loading dock (S3) and the workers (Lambda) -- mail stacks up neatly instead of overwhelming the workers.

**Why others are wrong:**
- **A:** Increasing timeout doesn't help the THROUGHPUT problem. Each function already has enough time (30s < 15min max). The issue is processing 1,000 concurrent images.
- **C:** S3 Batch Operations is for running operations on existing objects (copy, tag, restore). It's not an event-driven processing mechanism.
- **D:** Transfer Acceleration speeds up uploads. It has nothing to do with processing speed.

---

## Q11 (SAA) — Static Website Hosting

A company hosts a static website on S3. Users report that the website works over HTTP but not HTTPS. How should the solutions architect enable HTTPS?

A. Enable SSL/TLS on the S3 bucket endpoint
B. Place a CloudFront distribution in front of the S3 bucket with an ACM certificate
C. Use Route 53 to add HTTPS to the S3 website endpoint
D. Enable server-side encryption (SSE-S3) on the bucket

**Answer: B**

**Why B is correct:** S3 static website hosting only supports HTTP. To serve over HTTPS, put CloudFront in front of S3. CloudFront can use an ACM (AWS Certificate Manager) certificate for free. CloudFront also adds caching and better performance globally. It's like the warehouse (S3) only has a regular front door (HTTP), but you put a secure lobby (CloudFront) in front with a proper lock (SSL certificate).

**Why others are wrong:**
- **A:** S3 website endpoints do NOT support HTTPS. There is no option to enable SSL on them.
- **C:** Route 53 is DNS routing, not HTTPS termination. It directs traffic but doesn't add encryption.
- **D:** SSE-S3 encrypts data AT REST on S3's disks. It has nothing to do with HTTPS (encryption IN TRANSIT to users).

---

## Q12 (SAA) — MFA Delete

A company wants to add an extra layer of protection to prevent accidental permanent deletion of versioned S3 objects. Who can enable MFA Delete, and how?

A. Any IAM administrator can enable it via the AWS Console
B. Only the root account owner can enable it, and only via the AWS CLI or API
C. Any user with s3:PutBucketVersioning permission can enable it via the Console
D. MFA Delete is automatically enabled when versioning is turned on

**Answer: B**

**Why B is correct:** MFA Delete can ONLY be enabled by the root account owner, and ONLY through the CLI or API (not the console). Once enabled, permanently deleting an object version or changing the versioning state requires MFA authentication. It's like the President (root user) personally installing a special lock on the warehouse vault -- and it can only be done via secure command line, not through the front desk.

**Why others are wrong:**
- **A:** IAM administrators cannot enable MFA Delete. Only root.
- **C:** The S3 console does not have an option to enable MFA Delete. CLI/API only.
- **D:** MFA Delete is NOT automatically enabled with versioning. It must be explicitly turned on.

---

## Q13 (DVA) — S3 Select

A developer stores large CSV files (each 10 GB) in S3. Their application only needs rows where the `status` column equals "ACTIVE". Currently, the application downloads the entire file and filters client-side. How can they reduce data transfer and cost?

A. Use S3 Inventory to pre-filter the files
B. Use S3 Select to run a SQL expression on the object and return only matching rows
C. Store the data in DynamoDB for faster querying
D. Use Athena to query the CSV files

**Answer: B**

**Why B is correct:** S3 Select lets you run simple SQL expressions directly on S3 objects (CSV, JSON, Parquet). Instead of downloading 10 GB and filtering, S3 Select returns only the matching rows. Up to 400% faster and 80% cheaper. It's like asking the warehouse worker to pull only the specific boxes you need, instead of dumping the entire shelf on your truck and sorting later.

```sql
SELECT * FROM s3object s WHERE s.status = 'ACTIVE'
```

**Why others are wrong:**
- **A:** S3 Inventory generates reports about objects in a bucket (metadata). It doesn't filter WITHIN objects.
- **C:** Migrating 10 GB CSV files to DynamoDB is a major architecture change. S3 Select is a drop-in optimization.
- **D:** Athena works for complex SQL on S3 but is heavier (creates tables, uses Glue catalog). S3 Select is simpler for single-object filtering. Both are valid, but S3 Select is the better answer for simple per-object filtering.

---

## Q14 (SAA) — Glacier Retrieval

A legal firm stores old case files in S3 Glacier Flexible Retrieval. They receive a court order requiring urgent access to specific files within 5 minutes. Which retrieval option should they use?

A. Standard retrieval (3-5 hours)
B. Bulk retrieval (5-12 hours)
C. Expedited retrieval (1-5 minutes)
D. Instant retrieval (milliseconds)

**Answer: C**

**Why C is correct:** Glacier Flexible Retrieval offers three retrieval speeds. Expedited retrieval returns data in 1-5 minutes, fitting the "within 5 minutes" requirement. It's the most expensive option but the fastest for Glacier Flexible. It's like paying for express delivery from the deep freeze vault -- costs more, but you get it in minutes instead of hours.

**Why others are wrong:**
- **A:** Standard retrieval takes 3-5 hours. Too slow for a court order requiring 5-minute access.
- **B:** Bulk retrieval takes 5-12 hours. The cheapest but slowest option. Way too slow.
- **D:** "Instant retrieval" is a different storage class (Glacier Instant Retrieval), not a retrieval option for Glacier Flexible. If the files were in Glacier Instant Retrieval, access would be in milliseconds. But the question says Glacier Flexible.
