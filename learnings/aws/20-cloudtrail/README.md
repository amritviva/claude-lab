# 20 — CloudTrail: The National Auditor

> **One-liner:** CloudTrail is the national auditor — it records every government action (API call), creating a tamper-proof audit log of who did what, when, and from where.

---

## ELI10

Imagine every government building has a security camera that records EVERYONE who walks in and out — their name, what they did, what time, and where they came from. This footage is kept in a tamper-proof vault that nobody can edit. If something goes wrong (a building gets demolished, money goes missing), the auditors go to the vault, pull the footage, and see exactly who did what. That's CloudTrail — every API call in your AWS account is recorded, forever if you want, and nobody can alter the records.

---

## The Concept

### What Gets Logged

Every CloudTrail event records:

```json
{
  "eventTime": "2026-03-10T14:23:05Z",
  "eventName": "RunInstances",           // WHAT happened
  "userIdentity": {
    "type": "IAMUser",
    "userName": "amrit",                  // WHO did it
    "arn": "arn:aws:iam::123:user/amrit",
    "accountId": "123456789012"
  },
  "sourceIPAddress": "203.0.113.50",     // WHERE from
  "userAgent": "aws-cli/2.x",           // HOW (which tool)
  "requestParameters": {                 // WHAT exactly
    "instanceType": "t3.large",
    "imageId": "ami-12345"
  },
  "responseElements": {                  // WHAT happened as a result
    "instancesSet": {
      "instanceId": "i-abcdef"
    }
  },
  "eventSource": "ec2.amazonaws.com"     // WHICH service
}
```

### Event Types

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CLOUDTRAIL EVENT TYPES                             │
│                                                                      │
│  ┌─────────────────────────────────────────┐                        │
│  │  MANAGEMENT EVENTS                       │                        │
│  │  (Government-level actions)              │                        │
│  │                                          │                        │
│  │  Examples:                               │                        │
│  │  - CreateVPC, DeleteSubnet               │                        │
│  │  - LaunchInstances, TerminateInstances   │                        │
│  │  - CreateUser, AttachRolePolicy          │                        │
│  │  - CreateBucket, PutBucketPolicy         │                        │
│  │  - CreateStack, UpdateStack              │                        │
│  │                                          │                        │
│  │  Logged: BY DEFAULT (free, always on)    │                        │
│  │  Volume: Low-medium                       │                        │
│  └─────────────────────────────────────────┘                        │
│                                                                      │
│  ┌─────────────────────────────────────────┐                        │
│  │  DATA EVENTS                             │                        │
│  │  (Citizen-level actions)                 │                        │
│  │                                          │                        │
│  │  Examples:                               │                        │
│  │  - S3: GetObject, PutObject, DeleteObject│                        │
│  │  - Lambda: Invoke                        │                        │
│  │  - DynamoDB: GetItem, PutItem, Query     │                        │
│  │  - SNS: Publish                          │                        │
│  │  - SQS: SendMessage, ReceiveMessage      │                        │
│  │                                          │                        │
│  │  Logged: NOT by default (opt-in, costs $)│                        │
│  │  Volume: Very high (millions per day)     │                        │
│  └─────────────────────────────────────────┘                        │
│                                                                      │
│  ┌─────────────────────────────────────────┐                        │
│  │  INSIGHTS EVENTS                         │                        │
│  │  (Unusual activity detection)            │                        │
│  │                                          │                        │
│  │  Detects:                                │                        │
│  │  - Unusual API call volume               │                        │
│  │  - Unusual error rates                   │                        │
│  │  - Anomalous user behavior               │                        │
│  │                                          │                        │
│  │  Example: Normally 10 TerminateInstances │                        │
│  │  per day, suddenly 500 in an hour        │                        │
│  │                                          │                        │
│  │  Logged: NOT by default (opt-in, costs $)│                        │
│  └─────────────────────────────────────────┘                        │
└─────────────────────────────────────────────────────────────────────┘
```

### Trail = Audit Mandate

A Trail defines WHERE CloudTrail sends its logs:

```
┌────────────────────────────────────────────────────────────────┐
│                        TRAIL                                    │
│                   (Audit Mandate)                                │
│                                                                  │
│  Scope:                                                          │
│  ├── Single-region trail → logs events from ONE region          │
│  └── Multi-region trail  → logs events from ALL regions         │
│      (Recommended — captures global service events)             │
│                                                                  │
│  Destinations:                                                   │
│  ├── S3 bucket  (primary storage — for long-term archive)       │
│  ├── CloudWatch Logs (for real-time monitoring and alerting)    │
│  └── Both simultaneously                                        │
│                                                                  │
│  Organization Trail:                                             │
│  └── Logs events from ALL accounts in the Organization          │
│      (Created from management account, applies everywhere)       │
└────────────────────────────────────────────────────────────────┘
```

### Architecture: CloudTrail Data Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                    │
│  AWS API Call ──→ CloudTrail ──→ S3 Bucket (log archive)          │
│  (Any service)       │               │                             │
│                      │               ├── Lifecycle policy → Glacier│
│                      │               │   (cheap long-term storage) │
│                      │               │                             │
│                      │               └── Athena → SQL queries      │
│                      │                   on audit logs              │
│                      │                                              │
│                      ├──→ CloudWatch Logs → Metric Filter → Alarm  │
│                      │    (real-time)       (pattern match) (SNS)  │
│                      │                                              │
│                      └──→ EventBridge → Lambda/Step Functions      │
│                           (react to specific events)               │
│                                                                    │
└──────────────────────────────────────────────────────────────────┘
```

### CloudTrail Console vs S3 Storage

```
┌────────────────────────────────────────┬──────────────────────────────┐
│     CLOUDTRAIL CONSOLE (Event History) │      S3 BUCKET (Trail)       │
│                                        │                              │
│  - Last 90 days ONLY                  │  - Unlimited retention       │
│  - Management events only              │  - All event types           │
│  - Quick lookup (no setup needed)      │  - Requires trail setup      │
│  - Cannot be queried with SQL          │  - Query with Athena         │
│  - Free                                │  - S3 storage costs          │
│  - No customization                    │  - Lifecycle to Glacier      │
│                                        │  - Cross-account delivery    │
└────────────────────────────────────────┴──────────────────────────────┘

Default (no trail): 90 days in console, management events only.
With trail: Unlimited, all event types, queryable, archivable.
```

### Log File Integrity Validation = Tamper-Proof Seal

```
Every hour, CloudTrail creates a DIGEST FILE:
  ├── Contains SHA-256 hashes of all log files in that hour
  ├── The digest itself is signed by CloudTrail
  └── Each digest references the previous digest (blockchain-like chain)

If someone modifies or deletes a log file:
  ├── Hash mismatch detected by validation
  └── You KNOW the logs were tampered with

Validate: aws cloudtrail validate-logs --trail-arn <arn> --start-time <time>

Use case: Prove to auditors that logs haven't been altered.
Court-admissible evidence (tamper-evident chain of custody).
```

### Event Selectors = What to Record

```
┌────────────────────────────────────────────────────────────────┐
│                    EVENT SELECTORS                               │
│                                                                  │
│  Basic Event Selectors:                                          │
│  ├── Management events: Read, Write, or Both                    │
│  └── Data events: Specific resources or All                     │
│      (e.g., "log S3 data events for bucket-X only")            │
│                                                                  │
│  Advanced Event Selectors:                                       │
│  ├── Fine-grained filtering                                     │
│  ├── eventName = "PutObject"                                    │
│  ├── resources.type = "AWS::S3::Object"                         │
│  ├── resources.ARN = "arn:aws:s3:::my-bucket/*"                │
│  └── readOnly = true (only read events)                         │
│                                                                  │
│  Why advanced? Reduce costs by logging only what you need.       │
│  Data events are HIGH volume — logging everything is expensive.  │
└────────────────────────────────────────────────────────────────┘
```

---

## CloudTrail + Athena = SQL on Audit Logs

```
                    S3 Bucket (CloudTrail logs)
                         │
                         │ Create Athena table
                         │ pointing to log location
                         ▼
┌──────────────────────────────────────────────────┐
│                    ATHENA                          │
│                                                    │
│  SELECT userIdentity.userName,                     │
│         eventName,                                  │
│         sourceIPAddress,                            │
│         eventTime                                   │
│  FROM cloudtrail_logs                               │
│  WHERE eventName = 'DeleteBucket'                  │
│    AND eventTime > '2026-03-01'                    │
│  ORDER BY eventTime DESC;                          │
│                                                    │
│  → "amrit deleted prod-backup-bucket on March 5    │
│     from IP 203.0.113.50 using the CLI"            │
└──────────────────────────────────────────────────┘

Perfect for: forensic investigation, compliance reporting,
             security analysis, who-did-what queries.
```

---

## CloudTrail Lake = Managed Query Service

```
┌────────────────────────────────────────────────────────────────┐
│                    CLOUDTRAIL LAKE                               │
│              (Managed event data store)                          │
│                                                                  │
│  Traditional: CloudTrail → S3 → Set up Athena → Query          │
│  Lake:        CloudTrail → Lake Event Data Store → Query        │
│                                                                  │
│  Benefits:                                                       │
│  ├── No S3 setup needed                                         │
│  ├── SQL query built-in (no Athena config)                      │
│  ├── Cross-account event aggregation                            │
│  ├── Retention: Up to 2,555 days (7 years)                     │
│  ├── Non-AWS events (integrations via channels)                 │
│  └── Dashboards and saved queries                               │
│                                                                  │
│  Trade-off: More expensive than S3 + Athena for large volumes   │
│  Best for: Organizations wanting managed query without S3 setup │
└────────────────────────────────────────────────────────────────┘
```

---

## CloudTrail + EventBridge = Real-Time Reaction

```
API Call                CloudTrail              EventBridge            Target
   │                       │                        │                    │
   │── DeleteBucket ──────→│── Event ──────────────→│── Rule match? ────→│
   │                       │                        │   "DeleteBucket"   │
   │                       │                        │                    │
   │                       │                        │── SNS: Alert team  │
   │                       │                        │── Lambda: Remediate│
   │                       │                        │── Step Functions   │
```

**Key use cases:**
- Alert when someone creates an IAM user
- Auto-remediate when someone opens a Security Group to 0.0.0.0/0
- Log when someone accesses production resources
- Trigger workflows when specific API calls happen

**Important:** CloudTrail events appear in EventBridge for management events. For data events, you must have a trail with those events enabled.

---

## CloudTrail + CloudWatch Logs = Real-Time Monitoring

```
CloudTrail → CloudWatch Log Group → Metric Filter → Alarm → SNS
                                    │
                                    ├── "Unauthorized" → UnauthorizedCount → Alert if > 5
                                    ├── "DeleteTrail" → TrailDeletion → Alert immediately
                                    └── "ConsoleLogin" without MFA → NoMFALogin → Alert
```

Deliver CloudTrail logs to a CloudWatch Log Group for:
- Metric filters (turn API patterns into numbers)
- Alarms (alert on thresholds)
- Logs Insights queries (interactive investigation)

---

## Organization Trail

```
┌───────────────────────────────────────────────────────────────┐
│                  ORGANIZATION TRAIL                             │
│                                                                 │
│  Created in: Management Account                                │
│  Applies to: ALL accounts in the Organization                  │
│                                                                 │
│  Management Account ──┐                                        │
│  Account A ───────────┼──→ Central S3 Bucket                   │
│  Account B ───────────┤    (in management or delegated account)│
│  Account C ───────────┘                                        │
│                                                                 │
│  Member accounts:                                               │
│  ├── CAN see the trail in their CloudTrail console             │
│  ├── CANNOT modify or delete the organization trail            │
│  ├── CANNOT access the central S3 bucket (unless granted)      │
│  └── CAN create their OWN additional trails                    │
│                                                                 │
│  Best practice: Centralize audit logs, restrict access          │
└───────────────────────────────────────────────────────────────┘
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- CloudTrail + S3 + Athena for audit log analysis
- Organization Trail for multi-account auditing
- Multi-region trail to capture all events
- CloudTrail + EventBridge for automated security responses
- Log file integrity validation for compliance
- Data events vs management events (cost implications)

### DVA-C02 (Developer)
- Understanding CloudTrail event structure (userIdentity, eventName, sourceIPAddress)
- How to query CloudTrail logs (Athena, CloudWatch Logs Insights)
- Event selectors for filtering specific events
- Integration with EventBridge for event-driven architectures
- CloudTrail + Lambda for automated responses

### SOA-C02 (SysOps)
- Trail configuration (single-region vs multi-region)
- Organization Trail setup and management
- Log file integrity validation
- CloudTrail + CloudWatch Logs for monitoring and alerting
- Troubleshooting: "Who deleted my resource?" → check CloudTrail
- Event history (90 days) vs Trail (unlimited)
- S3 bucket policy for cross-account log delivery
- CloudTrail Lake vs S3 + Athena

---

## Key Numbers

| Item | Value |
|------|-------|
| Event history retention (console) | **90 days** |
| S3 trail retention | **Unlimited** (you manage lifecycle) |
| CloudTrail Lake retention | **Up to 2,555 days** (7 years) |
| Log delivery delay | **Within 15 minutes** of API call |
| Digest file frequency | **Every 1 hour** |
| Management events | **Logged by default, free for first trail** |
| Data events cost | **$0.10 per 100,000 events** |
| Insights events cost | **$0.35 per 100,000 events analyzed** |
| Max trails per region | **5** (soft limit) |
| Log file format | **JSON, gzip compressed** |
| S3 log path format | `s3://bucket/AWSLogs/AccountId/CloudTrail/Region/YYYY/MM/DD/` |

---

## Cheat Sheet

- **Management events = logged by default, free** (first trail). Data events = opt-in, paid.
- **90 days** in console (Event History). For longer → create a trail to S3.
- **Multi-region trail** = captures events from ALL regions (recommended, catches global events)
- **Organization Trail** = one trail for ALL accounts in the org
- **Log integrity validation** = SHA-256 digest chain, tamper-proof, court-admissible
- **CloudTrail + Athena** = SQL queries on audit logs (forensic investigation)
- **CloudTrail Lake** = managed alternative to S3+Athena (easier setup, higher cost)
- **CloudTrail + EventBridge** = react to API calls in near-real-time
- **CloudTrail + CloudWatch Logs** = metric filters + alarms on API patterns
- **Data events are HIGH volume** — enable selectively (specific buckets, specific functions)
- **Insights** = detect unusual API activity patterns (spike in TerminateInstances, etc.)
- **Log delivery** = within 15 minutes (NOT real-time; EventBridge is faster)
- **CloudTrail ≠ CloudWatch** — CloudTrail = WHO did WHAT (API audit). CloudWatch = HOW resources perform (metrics/logs).
- **Global service events** (IAM, STS, CloudFront) are logged in us-east-1
- **S3 bucket policy** must allow CloudTrail to write logs (`s3:PutObject` with condition)
- **KMS encryption** for CloudTrail logs in S3 = SSE-KMS with key policy allowing CloudTrail
- **Member accounts** can see org trail but can't modify/delete it
- **Event selectors** = choose which data events to log (reduce cost and noise)
- **Advanced event selectors** = fine-grained filtering (event name, resource type, read/write)
- **First management events trail** is free. Additional trails = $2.00 per 100,000 events.
