# 19 — KMS & Encryption: The National Locksmith

> **One-liner:** KMS is the national locksmith service — it manages master keys that never leave the vault, creates copy keys for encrypting your data, and tracks every time a key is used.

---

## ELI10

Imagine a country has a National Locksmith who keeps the most important master keys locked in an unbreakable vault. When you need to lock a box, you don't get the master key — instead, the locksmith makes a special copy key (data key) from the master key. You lock your box with the copy key, then the locksmith locks the copy key WITH the master key. Now you have a locked box and a locked key. To unlock, you bring the locked key back to the locksmith, they unlock it with the master key, and now you can open your box. The master key NEVER leaves the vault.

---

## The Concept

### Key Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                     KMS (National Locksmith)                      │
│                                                                   │
│  ┌────────────────────────────────────────────┐                  │
│  │           KMS KEY (formerly CMK)            │                  │
│  │        (Master Key in the Vault)            │                  │
│  │                                              │                  │
│  │  - Never leaves KMS                          │                  │
│  │  - 256-bit symmetric (default)               │                  │
│  │  - Can be symmetric or asymmetric            │                  │
│  │  - Has a key policy (who can use it)         │                  │
│  │  - All usage logged in CloudTrail            │                  │
│  └──────────────────┬───────────────────────────┘                  │
│                     │                                              │
│                     │ GenerateDataKey                              │
│                     ▼                                              │
│  ┌────────────────────────────────────────────┐                  │
│  │         DATA ENCRYPTION KEY (DEK)           │                  │
│  │         (Copy Key for Your Data)            │                  │
│  │                                              │                  │
│  │  Returns TWO versions:                       │                  │
│  │  1. Plaintext DEK  → Use to encrypt data    │                  │
│  │  2. Encrypted DEK  → Store alongside data   │                  │
│  │                                              │                  │
│  │  After encrypting, DISCARD plaintext DEK     │                  │
│  │  Keep only the encrypted DEK with your data  │                  │
│  └──────────────────────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
```

### Envelope Encryption = Two-Layer Locking

This is the CORE concept tested on all three exams:

```
ENCRYPTION (Locking):
┌──────────┐    Plaintext DEK     ┌──────────────┐
│ Your Data │───────────────────→  │ Encrypted    │
│ (file)    │    (encrypt data)    │ Data         │
└──────────┘                       └──────┬───────┘
                                          │
┌──────────┐    KMS Key            ┌──────┴───────┐
│ Plaintext│───────────────────→   │ Encrypted    │
│ DEK      │    (encrypt DEK)      │ DEK          │
└──────────┘                       └──────────────┘
     │
     └── DISCARD (never store plaintext DEK)

Store together: [Encrypted Data] + [Encrypted DEK]

DECRYPTION (Unlocking):
┌──────────────┐     KMS Key          ┌──────────┐
│ Encrypted    │───────────────────→   │ Plaintext│
│ DEK          │  (KMS decrypts DEK)  │ DEK      │
└──────────────┘                       └────┬─────┘
                                            │
┌──────────────┐    Plaintext DEK      ┌────┴─────┐
│ Encrypted    │───────────────────→   │ Your Data│
│ Data         │  (decrypt data)       │ (file)   │
└──────────────┘                       └──────────┘
```

**Why envelope encryption?**
- KMS has a 4 KB limit on direct encrypt/decrypt. You can't send a 1 GB file to KMS.
- Data key encrypts locally (fast, no network). Only the small DEK goes to KMS.
- If someone steals the encrypted data + encrypted DEK, they can't decrypt without KMS access.

### Three Types of KMS Keys

```
┌─────────────────────────────────────────────────────────────────────┐
│                    KMS KEY TYPES                                     │
│                                                                      │
│  ┌───────────────────────┐  ┌─────────────────────┐                │
│  │  AWS MANAGED KEY       │  │  CUSTOMER MANAGED   │                │
│  │  (Government locksmith)│  │  KEY (Your locksmith)│                │
│  │                        │  │                      │                │
│  │  Name: aws/s3,         │  │  Name: You choose    │                │
│  │  aws/ebs, aws/rds      │  │                      │                │
│  │                        │  │  Rotation: You       │                │
│  │  Rotation: Automatic   │  │  control (auto       │                │
│  │  (every year, can't    │  │  every year optional)│                │
│  │  disable)              │  │                      │                │
│  │                        │  │  Key policy: Full    │                │
│  │  Key policy: AWS       │  │  control             │                │
│  │  manages               │  │                      │                │
│  │                        │  │  Cost: $1/month +    │                │
│  │  Cost: Free            │  │  $0.03/10K requests  │                │
│  │  (pay per use only)    │  │                      │                │
│  │                        │  │  Deletion: 7-30 day  │                │
│  │  Can't delete          │  │  waiting period      │                │
│  └───────────────────────┘  └─────────────────────┘                │
│                                                                      │
│  ┌───────────────────────┐                                          │
│  │  AWS OWNED KEY         │                                          │
│  │  (AWS internal)        │                                          │
│  │                        │                                          │
│  │  Used by AWS services  │                                          │
│  │  internally            │                                          │
│  │  You can't see/manage  │                                          │
│  │  them                  │                                          │
│  │  Free, shared across   │                                          │
│  │  accounts              │                                          │
│  └───────────────────────┘                                          │
└─────────────────────────────────────────────────────────────────────┘
```

### Key Policies + IAM Policies

KMS uses a **dual authorization** model:

```
Key Policy (on the key itself)    +    IAM Policy (on the user/role)
─────────────────────────────          ────────────────────────────
"Allow Account 123 to use            "Allow this user to call
 this key"                             kms:Encrypt on key X"

BOTH must allow for access to work.
(Unless the key policy grants access directly to a user/role)
```

**Default key policy:** Allows the account root to manage the key (which means IAM policies in that account can grant KMS permissions). Without this default policy, even the account admin can't manage the key.

### Grants = Temporary Key Access

Grants allow temporary access to a KMS key without modifying the key policy:

```
Admin creates grant:
  "Lambda function X can use key Y for Decrypt only,
   grant expires when revoked"

Use cases:
- AWS services use grants internally (EBS creating encrypted volumes)
- Temporary cross-service access
- Delegate encrypt/decrypt without modifying policy
```

### Key Rotation

```
┌─────────────────────────────────────────────────────────────┐
│                      KEY ROTATION                            │
│                                                               │
│  AWS Managed Keys:                                            │
│  - Automatic rotation every year (MANDATORY, can't disable)  │
│                                                               │
│  Customer Managed Keys:                                       │
│  - Automatic rotation: Optional, every year when enabled      │
│  - Manual rotation: Create new key, update alias to point     │
│    to new key. Old key stays for decrypting old data.         │
│                                                               │
│  What happens during rotation:                                │
│  - New key MATERIAL is generated                              │
│  - Key ID stays the SAME                                      │
│  - Old key material is kept (for decrypting old data)        │
│  - Key alias doesn't change                                   │
│  - Applications don't need to change                          │
│                                                               │
│  Imported Key Material:                                       │
│  - NO automatic rotation                                      │
│  - Must rotate manually                                       │
└─────────────────────────────────────────────────────────────┘
```

### Key Deletion = Dangerous Operation

```
Customer Managed Key Deletion:
  1. Schedule deletion (7-30 day waiting period)
  2. Key is DISABLED during waiting period
  3. After waiting period → key is PERMANENTLY deleted
  4. ALL data encrypted with this key becomes UNRECOVERABLE

  Safeguards:
  - CloudTrail logs all key usage → find who's still using it
  - CloudWatch alarm on key usage during waiting period
  - Cancel deletion during waiting period if needed
```

---

## Encryption at Rest vs In Transit

```
┌──────────────────────────────────┬──────────────────────────────────┐
│       ENCRYPTION AT REST         │     ENCRYPTION IN TRANSIT         │
│     (Data in the warehouse)      │    (Data on the highway)          │
│                                  │                                    │
│  KMS encrypts stored data:       │  SSL/TLS encrypts moving data:   │
│  - S3 objects (SSE-S3, SSE-KMS, │  - HTTPS (port 443)              │
│    SSE-C)                        │  - TLS 1.2+ (recommended)        │
│  - EBS volumes                   │  - ACM certificates              │
│  - RDS databases                 │  - CloudFront → Origin           │
│  - DynamoDB tables               │  - VPN connections               │
│  - Redshift clusters             │  - API Gateway endpoints         │
│  - EFS file systems              │                                    │
│  - Lambda environment variables  │  AWS handles this for managed     │
│  - SQS messages                  │  services (HTTPS endpoints)       │
│  - CloudWatch Logs               │                                    │
└──────────────────────────────────┴──────────────────────────────────┘
```

### S3 Encryption Options

```
┌─────────────────────────────────────────────────────────────────────┐
│                    S3 ENCRYPTION                                     │
│                                                                      │
│  SSE-S3 (Server-Side Encryption with S3-managed keys)               │
│  - AWS manages everything. Free. Default since Jan 2023.            │
│  - Key: AES-256. Header: x-amz-server-side-encryption: AES256      │
│                                                                      │
│  SSE-KMS (Server-Side Encryption with KMS)                          │
│  - You choose the KMS key. Audit trail in CloudTrail.               │
│  - Header: x-amz-server-side-encryption: aws:kms                   │
│  - Key: AWS managed (aws/s3) or Customer managed                   │
│  - IMPORTANT: KMS API limits (5,500-30,000 req/s per region)       │
│    If you GET/PUT millions of objects, you might hit KMS limits     │
│                                                                      │
│  SSE-C (Server-Side Encryption with Customer-provided keys)         │
│  - YOU provide the key with each request. AWS doesn't store it.     │
│  - Must use HTTPS (key in the request header)                       │
│  - You manage the key lifecycle entirely                             │
│                                                                      │
│  Client-Side Encryption                                              │
│  - YOU encrypt before uploading. S3 stores opaque blob.             │
│  - S3 never sees plaintext. Full client control.                    │
└─────────────────────────────────────────────────────────────────────┘
```

### Multi-Region Keys

```
Primary Key (ap-southeast-2)        Replica Key (us-east-1)
┌────────────────────────┐         ┌────────────────────────┐
│  Key ID: mrk-abc123    │ ──────→ │  Key ID: mrk-abc123    │
│  Same key material     │ Replicate│  Same key material     │
│  Same key policy       │         │  Same key policy       │
└────────────────────────┘         └────────────────────────┘

Use case: Encrypt in one region, decrypt in another
         (DynamoDB Global Tables, S3 CRR with encryption)

NOT the same as creating separate keys in each region.
Multi-region keys share the same key material.
```

---

## CloudHSM = Your Own Locksmith Hardware

```
┌─────────────────────────────────────────────────────────────────────┐
│                    KMS vs CloudHSM                                    │
│                                                                      │
│  KMS (Shared Locksmith)              CloudHSM (Your Own Hardware)   │
│  ├── Multi-tenant                    ├── Single-tenant (dedicated)  │
│  ├── FIPS 140-2 Level 2             ├── FIPS 140-2 Level 3         │
│  ├── AWS manages hardware            ├── You manage keys            │
│  ├── Integrated with all             ├── Custom integration needed  │
│  │   AWS services                    ├── Runs in your VPC           │
│  ├── Automatic key rotation          ├── Manual key management      │
│  ├── Pay per API call               ├── Pay per hour (~$1.50/hr)   │
│  └── Key material in AWS            └── Key material in YOUR HSM   │
│                                                                      │
│  Use KMS for: 99% of use cases                                      │
│  Use CloudHSM for: Regulatory requirements (FIPS 140-2 L3),        │
│                     custom key store, SSL acceleration,              │
│                     Oracle TDE, contractual requirement for          │
│                     dedicated hardware                               │
└─────────────────────────────────────────────────────────────────────┘
```

**CloudHSM + KMS integration:** You can configure a KMS Custom Key Store backed by CloudHSM. KMS API + CloudHSM hardware = best of both worlds.

---

## Asymmetric Keys

```
Symmetric (default):           Asymmetric:
┌─────────────────┐           ┌─────────────────┐
│  ONE key for     │           │  TWO keys:       │
│  encrypt AND     │           │  Public  (share) │
│  decrypt         │           │  Private (secret) │
│                  │           │                   │
│  Key never       │           │  Public key can   │
│  leaves KMS      │           │  be downloaded    │
│                  │           │                   │
│  Use: Most AWS   │           │  Use: Encryption  │
│  services        │           │  outside AWS,     │
│                  │           │  digital signing  │
└─────────────────┘           └─────────────────┘
```

Asymmetric use cases:
- External parties encrypt data with public key, only you can decrypt with private key
- Digital signatures (sign with private key, verify with public key)
- When callers CAN'T use KMS API (outside AWS, no AWS credentials)

---

## Architecture: KMS in Action

```
┌────────────┐                    ┌────────────────┐
│ Application │                    │      KMS       │
│             │                    │                │
│ "Encrypt    │── GenerateDataKey─→│ Returns:       │
│  this file" │                    │ 1. Plaintext DEK│
│             │←──────────────────│ 2. Encrypted DEK│
│             │                    └────────────────┘
│             │
│ Encrypt file with plaintext DEK
│ Discard plaintext DEK
│ Store: [encrypted file] + [encrypted DEK]
│             │
│             │── Store to S3 ───→  [encrypted file + encrypted DEK]
│             │
│ LATER...    │
│             │── Get from S3 ──→  [encrypted file + encrypted DEK]
│             │
│             │── Decrypt DEK ────→┌────────────────┐
│             │                    │      KMS       │
│             │←── Plaintext DEK ──│ Decrypts DEK   │
│             │                    │ using master key│
│             │                    └────────────────┘
│             │
│ Decrypt file with plaintext DEK
│ Discard plaintext DEK
└────────────┘
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- Envelope encryption — why it exists (4 KB limit)
- S3 encryption options (SSE-S3 vs SSE-KMS vs SSE-C)
- KMS key types (AWS managed vs Customer managed)
- Multi-region keys for DynamoDB Global Tables / S3 CRR
- CloudHSM vs KMS decision (FIPS 140-2 Level 3)
- Cross-account key sharing (key policy + IAM policy)

### DVA-C02 (Developer)
- Encrypt/Decrypt API calls and their limits
- GenerateDataKey for envelope encryption
- S3 encryption headers
- Lambda environment variable encryption (KMS)
- KMS API throttling and how to handle it (caching, backoff)
- Client-side vs server-side encryption decisions

### SOA-C02 (SysOps)
- Key rotation configuration (automatic vs manual)
- Key deletion scheduling and safeguards
- Key policy management
- Monitoring key usage via CloudTrail
- KMS API quotas and request throttling
- Grants management
- Importing key material

---

## Key Numbers

| Item | Value |
|------|-------|
| KMS Encrypt/Decrypt limit | **4 KB** of data directly |
| KMS API requests | **5,500 to 30,000 req/s** (varies by region) |
| Customer managed key cost | **$1/month** + $0.03 per 10,000 requests |
| AWS managed key cost | **Free** (pay per API use only) |
| Key deletion waiting period | **7 to 30 days** (default 30) |
| Automatic rotation frequency | **Every 365 days** |
| Symmetric key algorithm | **AES-256-GCM** |
| Asymmetric algorithms | **RSA, ECC** |
| CloudHSM cost | **~$1.50/hour per HSM** |
| CloudHSM FIPS level | **140-2 Level 3** |
| KMS FIPS level | **140-2 Level 2** (Level 3 in some regions) |
| Max key aliases per account | **Soft limit** |
| Key material import | **Supported for symmetric keys only** |
| Multi-region key replication | **Any region, same key material** |

---

## Cheat Sheet

- **Envelope encryption** = encrypt data with DEK, encrypt DEK with KMS key. Two layers.
- **KMS key never leaves KMS** — only the DEK travels
- **4 KB limit** on direct KMS Encrypt/Decrypt → use GenerateDataKey for larger data
- **Three key types:** AWS managed (free, auto-rotate), Customer managed ($1/mo, you control), AWS owned (invisible)
- **Key policy + IAM policy** — BOTH needed for cross-account access (unless key policy grants directly)
- **Default key policy** allows account root to manage → enables IAM policies to grant access
- **Key rotation:** AWS managed = mandatory yearly. Customer managed = optional yearly. Imported = manual only.
- **Key deletion:** 7-30 day waiting period. IRREVERSIBLE after. All encrypted data becomes unrecoverable.
- **S3 SSE-KMS** has API throttling implications for high-throughput workloads
- **S3 SSE-C** requires HTTPS and you manage the key entirely
- **CloudHSM** = FIPS 140-2 Level 3, single-tenant, dedicated hardware. Use for compliance.
- **KMS Custom Key Store** = KMS API backed by CloudHSM hardware
- **Multi-region keys** = same key material in multiple regions. NOT separate keys.
- **Asymmetric keys** = public key downloadable, use when callers can't access KMS API
- **Grants** = temporary key access without policy changes
- **CloudTrail logs ALL KMS API calls** — every encrypt, decrypt, key creation
- **Lambda env vars** encrypted with KMS by default (aws/lambda key)
- **EBS, RDS, S3, DynamoDB, EFS, SQS, CloudWatch Logs** — all support KMS encryption
- **KMS condition keys:** `kms:ViaService` (restrict key to specific AWS service), `kms:EncryptionContext`
