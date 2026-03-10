# 20 — CloudTrail: Exam-Style Questions

---

## Q1: Event History vs Trail

A security team needs to investigate who deleted an S3 bucket 6 months ago. They check CloudTrail Event History but can't find the event. What is the issue?

- **A)** CloudTrail doesn't log S3 bucket deletions
- **B)** CloudTrail Event History only retains events for 90 days — they need a trail configured to send logs to S3 for longer retention
- **C)** S3 bucket deletions are data events and require explicit configuration
- **D)** CloudTrail was not enabled in the region where the bucket existed

**Correct Answer: B**

**Why:** CloudTrail Event History (the console view) only keeps events for 90 days. After that, they're gone. If they needed to look back 6 months, they should have had a trail configured to deliver logs to an S3 bucket, where they can keep logs indefinitely. It's like the security camera DVR only holds 90 days of footage — if you need older footage, you should have been copying it to a permanent archive.

- **A is wrong:** DeleteBucket is a management event — it IS logged by default in CloudTrail. The problem is retention, not logging.
- **C is wrong:** DeleteBucket is a management event (bucket-level operation), not a data event. Data events are object-level operations like GetObject, PutObject. Management events are logged by default.
- **D is wrong:** CloudTrail is enabled by default in all regions for management events. There's no setup needed for basic event capture.

---

## Q2: Management vs Data Events

A company wants to audit every S3 object download (GetObject) from their sensitive data bucket. They check CloudTrail and see CreateBucket and PutBucketPolicy events but no GetObject events. Why?

- **A)** GetObject events have a 30-minute delivery delay
- **B)** S3 object-level operations are DATA events, which are NOT logged by default — they must enable data events for the specific bucket in their trail configuration
- **C)** GetObject events are only visible in CloudWatch Logs, not CloudTrail
- **D)** The trail needs to be a multi-region trail to capture S3 events

**Correct Answer: B**

**Why:** GetObject is a DATA event (citizen-level action). Data events are high-volume and NOT logged by default — you must explicitly enable them. They see CreateBucket and PutBucketPolicy because those are MANAGEMENT events (government-level actions, logged by default). To see GetObject, configure the trail to log S3 data events for the specific bucket. Be warned: data events for a busy bucket can generate millions of events and significant costs.

- **A is wrong:** While CloudTrail has up to 15-minute delivery delay, the events would eventually appear IF they were being logged. The issue is they're not being logged at all.
- **C is wrong:** CloudTrail can deliver to CloudWatch Logs, but the events must first be captured by CloudTrail. Data events aren't captured without explicit configuration.
- **D is wrong:** Multi-region vs single-region affects which REGIONS are covered, not which EVENT TYPES are logged. Data events must be explicitly enabled regardless of region configuration.

---

## Q3: Log File Integrity

A compliance auditor asks the security team to prove that CloudTrail logs have not been tampered with since they were created. What feature provides this guarantee?

- **A)** S3 bucket versioning on the CloudTrail log bucket
- **B)** CloudTrail log file integrity validation using SHA-256 digest files
- **C)** S3 Object Lock on the CloudTrail log bucket
- **D)** CloudWatch Logs integration with tamper-proof storage

**Correct Answer: B**

**Why:** Log file integrity validation creates hourly digest files containing SHA-256 hashes of every log file. Each digest is signed by CloudTrail and references the previous digest (like a blockchain). You can validate the entire chain: `aws cloudtrail validate-logs`. If any log file was modified, deleted, or forged, the hash won't match. This provides cryptographic proof of log integrity — court-admissible evidence. It's like a tamper-evident seal on each evidence bag in the audit vault.

- **A is wrong:** Versioning keeps old versions but doesn't prove the original version wasn't modified before versioning was enabled. It also doesn't provide cryptographic proof of integrity.
- **C is wrong:** S3 Object Lock prevents deletion/modification (WORM), which is complementary but different from proving integrity. Object Lock says "nobody changed it" while integrity validation says "here's cryptographic proof nobody changed it."
- **D is wrong:** CloudWatch Logs doesn't have a "tamper-proof" feature. CloudTrail's integrity validation is the specific answer.

---

## Q4: CloudTrail + Athena

A security team needs to find all API calls made by a specific IAM user across all services in the past year. They have CloudTrail logs in S3. What is the MOST efficient approach?

- **A)** Download all log files from S3 and search them locally with grep
- **B)** Use CloudTrail Event History to search by username
- **C)** Create an Athena table pointing to the CloudTrail S3 bucket and run a SQL query filtering by userIdentity.userName
- **D)** Use CloudWatch Logs Insights to search the logs

**Correct Answer: C**

**Why:** Athena can query the compressed JSON log files directly in S3 using standard SQL. You create a table (CloudTrail has a pre-built Athena table template), then query: `SELECT * FROM cloudtrail_logs WHERE useridentity.username = 'amrit' AND year = '2026'`. Athena is serverless, pay-per-query, and can scan terabytes of logs efficiently. It's the forensic investigator's SQL workbench on the audit archive.

- **A is wrong:** A year of CloudTrail logs could be terabytes of compressed JSON. Downloading and grepping locally is impractical, slow, and expensive (data transfer costs).
- **B is wrong:** Event History only covers 90 days. The question asks about a full year.
- **D is wrong:** CloudWatch Logs Insights works if logs were sent to CloudWatch Logs, but it's designed for shorter-term queries. For a year of archived data in S3, Athena is the right tool.

---

## Q5: Organization Trail

A company with 20 AWS accounts in an Organization wants centralized audit logging. They create an Organization Trail from the management account. A member account admin tries to delete this trail from their account. What happens?

- **A)** The trail is deleted only for their account — other accounts are unaffected
- **B)** The deletion fails — member accounts cannot modify or delete an Organization Trail
- **C)** The trail is deleted across all accounts in the organization
- **D)** The deletion succeeds but the trail is automatically recreated within 24 hours

**Correct Answer: B**

**Why:** Organization Trails are governed by the management account. Member accounts can SEE the trail in their CloudTrail console but CANNOT modify, disable, or delete it. This is by design — centralized audit logging shouldn't be defeatable by the accounts being audited. It's like a federal audit mandate — individual countries can't opt out or shred the records.

- **A is wrong:** Organization Trails are all-or-nothing from the management account's perspective. Member accounts can't partially remove themselves.
- **C is wrong:** The deletion simply fails. Member accounts don't have permission to affect the organization trail.
- **D is wrong:** There's no auto-recreation mechanism. The deletion is just blocked outright.

---

## Q6: CloudTrail + EventBridge

A security team wants to be notified within minutes when someone creates a new IAM user in any account. What is the FASTEST approach?

- **A)** CloudTrail → S3 → Lambda (triggered by S3 PutObject) → Parse log → SNS
- **B)** CloudTrail → EventBridge rule matching CreateUser → SNS notification
- **C)** CloudTrail → CloudWatch Logs → Metric Filter for "CreateUser" → Alarm → SNS
- **D)** Check CloudTrail Event History daily using a scheduled Lambda

**Correct Answer: B**

**Why:** EventBridge receives CloudTrail management events in near-real-time. You create a rule: `source = aws.iam AND detail.eventName = CreateUser`. When matched, EventBridge immediately triggers the SNS notification. This is the fastest automated path — minutes, not hours. It's like having an instant wiretap on the government communications — the moment someone makes the call, you're notified.

- **A is wrong:** CloudTrail delivers logs to S3 within 15 minutes, and log files are batched. This adds latency. EventBridge is faster.
- **C is wrong:** CloudWatch Logs + Metric Filter works but adds more hops. The metric filter polls logs, then the alarm evaluates, then triggers. EventBridge is more direct.
- **D is wrong:** Daily checks mean you could be 24 hours late. The question asks for notification "within minutes."

---

## Q7: CloudTrail Insights

A company notices that their EC2 instances are being terminated much more frequently than normal. They want CloudTrail to automatically detect and alert on such unusual patterns. What should they enable?

- **A)** CloudTrail data events for EC2
- **B)** CloudTrail Insights events
- **C)** CloudWatch Anomaly Detection on CloudTrail metrics
- **D)** AWS Config rules for EC2 instance count

**Correct Answer: B**

**Why:** CloudTrail Insights analyzes management event patterns and detects unusual activity — like a sudden spike in TerminateInstances calls compared to the normal baseline. It learns what's "normal" and flags anomalies. When Insights detects unusual activity, it creates an Insights event that can trigger EventBridge rules for alerting. It's the intelligence agency noticing "we've never seen 500 demolition orders in one hour before."

- **A is wrong:** Data events are for object-level operations (S3 GetObject, Lambda Invoke). EC2 TerminateInstances is a management event, already logged by default.
- **C is wrong:** CloudWatch Anomaly Detection works on CloudWatch metrics, not CloudTrail events. Different data source, different purpose.
- **D is wrong:** AWS Config tracks resource configuration state, not API call patterns. It could tell you "an instance was terminated" but not "terminations are happening at an unusual rate."

---

## Q8: Cross-Account Log Delivery

A security account (Account S) needs to receive CloudTrail logs from 10 member accounts. The S3 bucket is in Account S. What needs to be configured?

- **A)** Each member account needs an IAM role that allows writing to Account S's bucket
- **B)** The S3 bucket policy in Account S must allow CloudTrail from each member account to write logs, and each member account's trail must specify Account S's bucket
- **C)** Create an Organization Trail — it automatically handles cross-account delivery
- **D)** Use S3 cross-region replication from each account's bucket to Account S's bucket

**Correct Answer: C**

**Why:** If the accounts are in an Organization (which 10 member accounts implies), an Organization Trail is the simplest and most maintainable solution. Created from the management account, it automatically delivers logs from all member accounts to a central S3 bucket. No per-account configuration needed. New accounts added to the org are automatically included.

- **A is wrong:** CloudTrail uses the CloudTrail service principal to write to S3, not IAM roles in member accounts. The bucket policy authorizes the CloudTrail service.
- **B is wrong:** This approach works for manual cross-account setup but is operationally complex with 10+ accounts. Each account needs individual trail configuration. Organization Trail automates this.
- **D is wrong:** S3 replication would duplicate data, add latency, and require replication setup in each account. Organization Trail is the purpose-built solution.

---

## Q9: Global Service Events

A company creates a multi-region trail but notices IAM events (CreateUser, AttachRolePolicy) only appear in us-east-1 logs. Is this a problem?

- **A)** Yes — the trail is misconfigured and should log IAM events in every region
- **B)** No — IAM is a global service, and global service events are logged in us-east-1 only. The multi-region trail captures them correctly.
- **C)** Yes — you need to create a separate trail in us-east-1 for global service events
- **D)** No — IAM events appear in every region with a multi-region trail

**Correct Answer: B**

**Why:** Global services (IAM, STS, CloudFront, Route 53, Organizations) route their API calls through us-east-1 regardless of where the caller is. CloudTrail logs these events in us-east-1. A multi-region trail captures events from ALL regions including us-east-1, so global service events are included. There's no issue — this is normal behavior. It's like federal government actions being recorded at the national capital, even if the person making the request is in another city.

- **A is wrong:** It's not misconfigured. Global services genuinely only log in us-east-1. This is by design.
- **C is wrong:** A multi-region trail already includes us-east-1. No separate trail needed.
- **D is wrong:** IAM events appear ONLY in us-east-1 logs, not in every region. They're not duplicated across regions.

---

## Q10: CloudTrail + S3 Security

A company stores CloudTrail logs in an S3 bucket. They want to ensure nobody (including admins) can delete the log files. What should they implement?

- **A)** S3 bucket policy denying s3:DeleteObject
- **B)** S3 Object Lock in Compliance mode (WORM — Write Once Read Many)
- **C)** CloudTrail log file integrity validation
- **D)** S3 versioning with MFA delete

**Correct Answer: B**

**Why:** S3 Object Lock in Compliance mode is a WORM (Write Once Read Many) setting. Once set, NOBODY can delete the objects — not even the root user — until the retention period expires. This is the strongest protection for audit logs. Governance mode allows privileged users to delete, but Compliance mode is absolute. It's like sealing evidence in a vault that nobody can open until the case retention period ends.

- **A is wrong:** Bucket policies can be modified by admins. An admin could update the policy to allow deletion, then delete the logs.
- **C is wrong:** Integrity validation DETECTS tampering but doesn't PREVENT it. You'd know the logs were tampered with, but the damage is done.
- **D is wrong:** MFA delete adds friction (requires MFA to delete versions) but a determined admin with MFA access could still delete logs. Compliance mode Object Lock is stronger — truly immutable.

---

## Q11: CloudTrail Delivery Timing

An automated security system needs to react to specific API calls. A Lambda function polls CloudTrail logs in S3 for new events every minute. The team complains about a 15-20 minute delay between when an API call is made and when they detect it. What should they change?

- **A)** Increase the Lambda polling frequency to every 10 seconds
- **B)** Switch to EventBridge rules that match CloudTrail events instead of polling S3
- **C)** Enable CloudTrail log streaming to reduce delivery latency
- **D)** Use CloudTrail Lake for faster event access

**Correct Answer: B**

**Why:** CloudTrail delivers log files to S3 within approximately 15 minutes, and files are batched. Polling S3 will always have this inherent delay. EventBridge receives CloudTrail management events in near-real-time (seconds to minutes). By creating an EventBridge rule that matches the specific API call, the Lambda is triggered almost immediately — no polling needed. It's the difference between checking the mailbox every minute vs getting a phone call the instant the letter arrives.

- **A is wrong:** Polling more frequently doesn't help if the logs haven't been delivered to S3 yet. The 15-minute delivery delay is the bottleneck, not the polling frequency.
- **C is wrong:** There's no "CloudTrail log streaming" feature that reduces S3 delivery latency. The ~15 minute delay is inherent to S3 delivery.
- **D is wrong:** CloudTrail Lake ingests events with similar or higher latency than S3 delivery. It's designed for query and analysis, not real-time detection.

---

## Q12: Multi-Account Investigation

After a security incident, an investigator needs to determine which IAM user in which account deleted a production DynamoDB table last Tuesday at approximately 3 PM. The organization has 50 accounts with an Organization Trail sending logs to a central S3 bucket. What is the MOST efficient investigation approach?

- **A)** Log into each of the 50 accounts and check CloudTrail Event History
- **B)** Use Athena to query the central S3 bucket with SQL: filter by eventName='DeleteTable', eventTime around last Tuesday 3 PM, and eventSource='dynamodb.amazonaws.com'
- **C)** Check CloudWatch dashboards for DynamoDB table metrics
- **D)** Use AWS Config to find when the table was deleted

**Correct Answer: B**

**Why:** The central S3 bucket has logs from ALL 50 accounts (Organization Trail). Athena queries across all accounts simultaneously with one SQL statement:

```sql
SELECT useridentity.accountid, useridentity.username,
       eventtime, sourceipaddress, requestparameters
FROM cloudtrail_logs
WHERE eventname = 'DeleteTable'
  AND eventsource = 'dynamodb.amazonaws.com'
  AND eventtime BETWEEN '2026-03-03T14:00:00Z' AND '2026-03-03T16:00:00Z'
```

One query, seconds to run, identifies the account, user, time, and IP. It's the forensic investigator searching the centralized archive with SQL instead of checking 50 separate filing cabinets.

- **A is wrong:** Logging into 50 accounts manually is absurdly time-consuming and error-prone. The centralized logs exist for exactly this purpose.
- **C is wrong:** CloudWatch shows THAT the table disappeared (metrics stopped) but not WHO deleted it or from where.
- **D is wrong:** AWS Config records the configuration change (table existed → table gone) but doesn't provide the same level of detail as CloudTrail (who, from where, what tool).
