# 06 - S3: The National Warehouse

> **Analogy:** S3 is the country's national warehouse with infinite storage. Buckets are warehouse sections (globally unique names). Objects are boxes with labels (keys). Different storage classes are like different temperature-controlled rooms -- some are instant access, others take hours to retrieve from deep freeze.

---

## ELI10

Imagine the AWS country has a **massive national warehouse** that can store absolutely anything and never runs out of space. Inside, you create **sections** (buckets) and each section has a globally unique name -- no two sections in the whole world can have the same name. You put **boxes** (objects) in these sections, and each box has a **label** (key) and can hold up to 5 TB. Some boxes go on the **main floor** (Standard) for quick access, some go to the **back room** (Infrequent Access) for cheaper storage, and some go into the **deep freeze vault** (Glacier) where it takes hours to dig them out.

---

## The Concept

### S3 Fundamentals

```
S3 Bucket: amrit-company-data-prod
├── images/logo.png                    (Object: key = images/logo.png)
├── documents/report-2024.pdf          (Object: key = documents/report-2024.pdf)
├── backups/db/2024-01-15.sql.gz       (Object: key = backups/db/2024-01-15.sql.gz)
└── config.json                        (Object: key = config.json)

Note: The "/" is part of the key name. S3 has NO actual folder hierarchy.
      The console shows "folders" as a convenience -- it's all flat.
```

**Key facts:**
- **Bucket names are globally unique** (across ALL AWS accounts worldwide)
- **Objects**: key (name) + value (data) + metadata + version ID + tags
- **Max object size**: 5 TB
- **Max upload in single PUT**: 5 GB (use multi-part upload for anything over 100 MB)
- **Multi-part upload**: required over 5 GB, recommended over 100 MB
- **Flat namespace**: prefixes (like `images/`) simulate folders but aren't real directories
- **Regional service**: data stays in the Region unless you replicate it
- **Private by default**: no public access unless explicitly configured

### Storage Classes -- Temperature-Controlled Rooms

| Class | Analogy | Retrieval | Min Storage | Min Size | AZs | Use Case |
|-------|---------|-----------|-------------|----------|-----|----------|
| **Standard** | Main floor | Instant | None | None | 3+ | Frequently accessed |
| **Intelligent-Tiering** | Smart robot that moves boxes | Instant | 30 days | None | 3+ | Unknown/changing patterns |
| **Standard-IA** | Back room | Instant | 30 days | 128 KB | 3+ | Infrequent but fast needed |
| **One Zone-IA** | Single-city back room | Instant | 30 days | 128 KB | **1** | Re-creatable data |
| **Glacier Instant** | Cold room (instant door) | Instant | 90 days | 128 KB | 3+ | Quarterly access, instant |
| **Glacier Flexible** | Deep freeze (request & wait) | 1-12 hrs | 90 days | 40 KB | 3+ | Archive, hours OK |
| **Glacier Deep Archive** | Underground vault (dig out) | 12-48 hrs | 180 days | 40 KB | 3+ | Compliance, 7-10yr retain |

**Retrieval speed for Glacier Flexible:**
- Expedited: 1-5 minutes ($$$)
- Standard: 3-5 hours ($$)
- Bulk: 5-12 hours ($)

**Retrieval speed for Glacier Deep Archive:**
- Standard: 12 hours
- Bulk: 48 hours

### Intelligent-Tiering -- The Smart Robot

Automatically moves objects between tiers based on access patterns:

```
Frequent Access Tier (default) ── 30 days no access ──→ Infrequent Access
                                  ── 90 days no access ──→ Archive Instant
                                  ── 180 days no access ──→ Archive (optional)
                                  ── 730 days no access ──→ Deep Archive (optional)

Any access moves object back to Frequent Access immediately.
```

- No retrieval fees (unlike Standard-IA)
- Small monthly monitoring fee per object
- Best for: unpredictable access patterns

### Versioning -- Keeping Every Draft

```
Versioning OFF (default):
  PUT report.pdf  →  report.pdf (v1)
  PUT report.pdf  →  report.pdf (v1 overwritten, gone)

Versioning ON:
  PUT report.pdf  →  report.pdf (version: abc123)
  PUT report.pdf  →  report.pdf (version: def456, abc123 still exists!)
  DELETE report.pdf → adds "delete marker" (abc123 and def456 still exist!)
```

**Key facts:**
- Once enabled, can only be **suspended** (not disabled)
- Suspending does NOT delete existing versions
- Delete = adds a delete marker (recoverable)
- Permanent delete = specify version ID in delete request
- MFA Delete: requires MFA to permanently delete versions or change versioning state
- **Versioning is required** for replication (CRR/SRR)

### Lifecycle Rules -- Automated Box Movement

```
Example lifecycle policy:
Day 0:   Object created in Standard
Day 30:  → Transition to Standard-IA
Day 60:  → Transition to Glacier Flexible
Day 365: → Transition to Glacier Deep Archive
Day 730: → Expire (delete)

Can also:
- Expire old versions after N days
- Delete incomplete multipart uploads after N days
- Transition noncurrent versions to cheaper classes
```

**Transition waterfall (can only move down, not up):**
```
Standard → Standard-IA → Intelligent-Tiering → One Zone-IA
    ↓           ↓               ↓                    ↓
Glacier Instant → Glacier Flexible → Glacier Deep Archive
```

### Replication

| Type | Name | Use Case |
|------|------|----------|
| **CRR** | Cross-Region Replication | DR, compliance, lower latency in another region |
| **SRR** | Same-Region Replication | Log aggregation, live replication between accounts |

**Requirements:**
- Versioning must be enabled on BOTH source and destination
- Buckets can be in different accounts
- IAM role for S3 to assume
- **Not retroactive**: only new objects after enabling are replicated
- **Delete markers** are NOT replicated by default (can enable)
- **No chaining**: if Bucket A → B → C, objects in A do NOT auto-replicate to C

### Encryption

| Type | Key Management | Audit Trail | Analogy |
|------|---------------|-------------|---------|
| **SSE-S3** | Amazon manages key | No | Amazon locks the warehouse door |
| **SSE-KMS** | You manage key in KMS | Yes (CloudTrail) | You choose the lock, Amazon uses it |
| **SSE-C** | You provide key with every request | You manage | You bring your own padlock every time |
| **Client-side** | You encrypt before upload | You manage | You seal the box before sending it |

**SSE-S3 (default since Jan 2023):**
- AES-256 encryption
- Amazon manages everything
- No additional cost
- `x-amz-server-side-encryption: AES256`

**SSE-KMS:**
- Uses AWS KMS (CMK)
- CloudTrail audit trail (who decrypted what, when)
- Per-request KMS API calls (watch for KMS throttling at high volume!)
- `x-amz-server-side-encryption: aws:kms`
- KMS request rate limit: 5,500-30,000 requests/sec per region

**Bucket key (SSE-KMS optimization):**
- Reduces KMS API calls by 99%
- Generates a bucket-level key that encrypts individual object keys
- Saves cost on KMS requests

### Access Control

**Hierarchy (from recommended to legacy):**

1. **IAM Policies** -- Identity-based (what can this user/role do?)
2. **Bucket Policies** -- Resource-based (who can access this bucket?)
3. **Access Points** -- Simplified access management for shared datasets
4. **Pre-signed URLs** -- Temporary access to specific objects
5. **ACLs** -- Legacy, avoid (but still on exams)

**Bucket Policy example:**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "PublicRead",
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::my-website-bucket/*"
  }]
}
```

**Block Public Access:**
- Account-level AND bucket-level setting
- Four switches: Block public ACLs, Block public policies, Ignore public ACLs, Restrict public policies
- **Overrides** bucket policies and ACLs that grant public access
- Enabled by default on new buckets

**Pre-signed URLs:**
- Generate a URL with temporary access (upload or download)
- Inherits the permissions of the IAM user/role that generated it
- Expiration: configurable (default 1 hour, max 7 days for IAM user, 12 hours for IAM role)
- Use case: private objects that need temporary sharing

### S3 Access Points

- Named network endpoints with their own access policy
- Simplify managing access to shared datasets
- Each access point has its own DNS name and policy
- Can restrict to specific VPC (VPC-only access points)

### Event Notifications

```
S3 Bucket
  │
  │ PUT / DELETE / RESTORE events
  │
  ├──→ Lambda Function (process image, generate thumbnail)
  ├──→ SQS Queue (buffer for downstream processing)
  ├──→ SNS Topic (fan out to multiple subscribers)
  └──→ EventBridge (advanced filtering, more destinations)
```

**EventBridge integration (newer, more powerful):**
- All S3 events can go to EventBridge
- Advanced filtering, multiple destinations, archive/replay
- Recommended over direct S3 → SQS/SNS/Lambda for new designs

### S3 Transfer Acceleration

- Uses CloudFront edge locations to speed up uploads
- User uploads to nearest edge location → AWS backbone → S3 bucket
- Must use a special endpoint: `bucketname.s3-accelerate.amazonaws.com`
- Extra cost, but faster for distant uploads
- Must be enabled on the bucket

### S3 Select & Glacier Select

- Run SQL queries on objects **without downloading the entire object**
- Filter rows/columns from CSV, JSON, Parquet
- Up to 400% faster, 80% cheaper than downloading full object
- Returns only the data you need

### Static Website Hosting

- Host static websites directly from S3
- Endpoint: `http://bucket-name.s3-website-region.amazonaws.com`
- Requires: bucket policy for public read, index document, optional error document
- **HTTP only** (for HTTPS, put CloudFront in front)
- Common exam question: 403 errors = check bucket policy + Block Public Access settings

### Object Lock (WORM)

- Write Once Read Many
- Prevents object deletion or overwriting for a set period
- **Retention modes:**
  - **Governance**: users with special permissions can override
  - **Compliance**: NO ONE can delete, not even root (truly immutable)
- **Legal Hold**: indefinite lock, independent of retention period
- Requires versioning
- Use case: regulatory compliance, financial records

### Glacier Vault Lock

- Similar to Object Lock but for Glacier vaults
- Policy-based, once locked it's immutable
- Use case: compliance archives (SEC Rule 17a-4, HIPAA)

### MFA Delete

- Requires MFA to: permanently delete object versions, change versioning state
- Must be enabled by **root account** via CLI (not console)
- Extra protection against accidental/malicious deletion

---

## Architecture Diagram

```
┌────────────── S3 Bucket: company-data-prod ──────────────────┐
│                                                               │
│  Storage Classes:                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐ │
│  │ Standard │→ │ Std-IA   │→ │ Glacier  │→ │ Deep Archive │ │
│  │ (hot)    │  │ (warm)   │  │ Flexible │  │ (frozen)     │ │
│  │ Day 0    │  │ Day 30   │  │ (cold)   │  │ Day 365      │ │
│  └──────────┘  └──────────┘  │ Day 90   │  └──────────────┘ │
│                               └──────────┘                    │
│                                                               │
│  Versioning: ON                                               │
│  Encryption: SSE-KMS (with bucket key)                        │
│  Replication: CRR → eu-west-1 (DR copy)                      │
│  Lifecycle: Standard → IA (30d) → Glacier (90d) → Delete (2y)│
│  Block Public Access: ON                                      │
│  Object Lock: Compliance mode (1 year retention)              │
│                                                               │
│  Access:                                                      │
│  ├── IAM Policies (internal users/roles)                      │
│  ├── Bucket Policy (cross-account access for partner)         │
│  ├── Access Point: analytics-ap (VPC-only, read access)       │
│  ├── Pre-signed URLs (temporary customer downloads)           │
│  └── Event Notification → Lambda (thumbnail generation)       │
│                                                               │
│  Monitoring:                                                  │
│  ├── S3 Storage Lens (org-wide usage analytics)               │
│  ├── CloudWatch: request metrics, storage metrics             │
│  ├── CloudTrail: data events (who accessed what)              │
│  └── Access Logs → separate logging bucket                    │
│                                                               │
└───────────────────────────────────────────────────────────────┘

     ┌───── Upload Path ─────┐
     │                        │
 [User] ──→ [Edge Location] ──→ [S3 Bucket]
         Transfer Acceleration
         (faster for distant users)
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- Storage class selection for cost optimization
- Lifecycle rules design (transition waterfall)
- Replication (CRR for DR, SRR for log aggregation)
- Encryption strategy (SSE-S3 vs SSE-KMS vs SSE-C)
- Cross-account access (bucket policies + IAM roles)
- Static website hosting with CloudFront for HTTPS
- Object Lock for compliance (Governance vs Compliance mode)
- S3 Transfer Acceleration for global uploads
- Event notifications architecture (S3 → Lambda/SQS/SNS/EventBridge)

### DVA-C02 (Developer)
- Pre-signed URLs for temporary access
- Multipart upload API
- S3 Select for efficient querying
- Event notifications triggering Lambda
- SSE-KMS encryption and KMS throttling
- SDK usage patterns (putObject, getObject)
- Bucket key for KMS cost reduction
- CORS configuration for web applications

### SOA-C02 (SysOps Administrator)
- S3 Storage Lens and inventory reports
- Access logging configuration
- Replication monitoring and troubleshooting
- Lifecycle rule management
- Bucket policy troubleshooting (Block Public Access conflicts)
- S3 metrics in CloudWatch
- Cost optimization (Intelligent-Tiering, lifecycle rules)
- MFA Delete configuration

---

## Key Numbers

| Fact | Value |
|------|-------|
| Max object size | 5 TB |
| Max single PUT upload | 5 GB |
| Multipart upload required | Over 5 GB |
| Multipart recommended | Over 100 MB |
| Max parts in multipart | 10,000 |
| Buckets per account | 100 (soft limit, can increase to 1,000) |
| Objects per bucket | Unlimited |
| Durability (Standard) | 99.999999999% (11 nines) |
| Availability (Standard) | 99.99% |
| Availability (Standard-IA) | 99.9% |
| Availability (One Zone-IA) | 99.5% |
| Std-IA minimum storage | 30 days, 128 KB |
| Glacier Flexible min storage | 90 days, 40 KB |
| Glacier Deep Archive min storage | 180 days, 40 KB |
| Glacier Flexible retrieval | 1 min - 12 hours |
| Glacier Deep Archive retrieval | 12 - 48 hours |
| Pre-signed URL max expiry (IAM user) | 7 days |
| Pre-signed URL max expiry (IAM role) | 12 hours |
| KMS requests per sec | 5,500-30,000 (Region dependent) |
| S3 requests per prefix | 5,500 GET/HEAD, 3,500 PUT/DELETE per second |
| Max prefixes per bucket | Unlimited |
| Bucket name length | 3-63 characters |
| Bucket policy max size | 20 KB |
| Object tags max | 10 per object |
| Lifecycle rules max | 1,000 per bucket |

---

## Cheat Sheet

- S3 = infinite object storage, 11 nines durability, private by default
- Bucket names are globally unique, objects are Regional
- Max object size: 5 TB; use multipart upload over 100 MB (required over 5 GB)
- Flat namespace -- "folders" are just key prefixes
- SSE-S3 = default encryption since Jan 2023 (Amazon manages keys)
- SSE-KMS = your key in KMS, audit trail in CloudTrail (watch for throttling)
- Bucket Key = reduces KMS API calls by 99%
- Versioning: once enabled, can only be suspended (not disabled)
- MFA Delete: root only, via CLI only
- Lifecycle rules: can transition down the class hierarchy, not up
- CRR requires versioning on both buckets, not retroactive
- Delete markers are NOT replicated by default
- No replication chaining (A→B→C does not auto-replicate A to C)
- Pre-signed URLs inherit creator's permissions (max 7 days for IAM user)
- Block Public Access overrides bucket policies and ACLs
- Static website hosting is HTTP only (use CloudFront for HTTPS)
- S3 Select = SQL on objects without full download (CSV, JSON, Parquet)
- Object Lock: Governance (override with permission) vs Compliance (nobody can delete)
- 5,500 GET + 3,500 PUT per second per prefix (scale by adding prefixes)
- Transfer Acceleration uses CloudFront edges for faster distant uploads
- Event notifications: S3 → Lambda/SQS/SNS/EventBridge
- Intelligent-Tiering = auto-moves between tiers, no retrieval fee, monitoring fee
- Glacier Flexible: Expedited (1-5 min), Standard (3-5 hr), Bulk (5-12 hr)
- Glacier Deep Archive: Standard (12 hr), Bulk (48 hr)
- S3 Storage Lens = org-wide usage analytics dashboard
