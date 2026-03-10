# Architecture Scenarios 2: Security & Disaster Recovery

> 10 multi-service architecture scenarios for SAA-C03, DVA-C02, SOA-C02.
> Analogy: **AWS = A Country**. Every scenario maps to the country.

---

## SECURITY & COMPLIANCE (Scenarios 1-5)

---

## Scenario 1: Multi-Account Security Posture

### The Scenario

A financial services company runs 40 AWS accounts across 5 business units. The CISO needs centralised visibility into all API activity, resource compliance, and threat detection -- while ensuring no child account can disable security controls. All audit logs must be immutable and retained for 7 years.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                     AWS ORGANIZATIONS (Management Account)          │
│                                                                     │
│  ┌──────────────┐   ┌──────────────────────────────────────────┐   │
│  │     SCPs      │   │           Organization Trail              │   │
│  │ "Deny Disable │   │  CloudTrail → S3 (Log Archive Acct)      │   │
│  │  CloudTrail"  │   │  + CloudWatch Logs (central)              │   │
│  │ "Deny Leave   │   └──────────────────────────────────────────┘   │
│  │  Org"         │                                                   │
│  └──────────────┘                                                   │
│                                                                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────┐   │
│  │  Config           │  │  GuardDuty        │  │  Security Hub   │   │
│  │  Aggregator       │  │  Delegated Admin  │  │  Central View   │   │
│  │  (all accounts)   │  │  (Security Acct)  │  │  (findings)     │   │
│  └────────┬─────────┘  └────────┬─────────┘  └───────┬────────┘   │
│           │                      │                     │            │
└───────────┼──────────────────────┼─────────────────────┼────────────┘
            │                      │                     │
     ┌──────▼──────────────────────▼─────────────────────▼──────┐
     │                    SECURITY ACCOUNT                       │
     │  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │
     │  │ Config Rules │  │ GuardDuty    │  │ Security Hub   │  │
     │  │ (delegated   │  │ (delegated   │  │ (aggregated    │  │
     │  │  admin)      │  │  admin)      │  │  findings)     │  │
     │  └─────────────┘  └──────────────┘  └────────────────┘  │
     │                          │                                │
     │                    ┌─────▼─────┐                         │
     │                    │    SNS     │→ Security team alerts   │
     │                    └───────────┘                         │
     └──────────────────────────────────────────────────────────┘
            │
     ┌──────▼──────────────────────────────────────────────────┐
     │                  LOG ARCHIVE ACCOUNT                     │
     │  ┌────────────────────────────────────────────────┐     │
     │  │  S3 Bucket (Object Lock — Governance/Compliance)│     │
     │  │  - CloudTrail logs from ALL accounts             │     │
     │  │  - Lifecycle: IA after 90d, Glacier after 1y     │     │
     │  │  - Retention: 7 years (compliance mode)          │     │
     │  └────────────────────────────────────────────────┘     │
     └─────────────────────────────────────────────────────────┘
            │
     ┌──────▼──────────────────────────────────────────────────┐
     │        CHILD ACCOUNTS (40 accounts, 5 OUs)              │
     │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐     │
     │  │ Prod OU │ │ Dev OU  │ │ Test OU │ │ Sandbox │     │
     │  │ (strict │ │ (medium │ │ (medium │ │ (least  │     │
     │  │  SCPs)  │ │  SCPs)  │ │  SCPs)  │ │  SCPs)  │     │
     │  └─────────┘ └─────────┘ └─────────┘ └─────────┘     │
     │                                                         │
     │  Each account has:                                      │
     │  - CloudTrail (org trail — cannot disable)              │
     │  - Config recorder (feeds aggregator)                   │
     │  - GuardDuty (member — feeds delegated admin)           │
     └─────────────────────────────────────────────────────────┘
```

### Why This Architecture

- **Organization Trail** logs ALL accounts from one config. No per-account setup, no gaps. Org trail cannot be disabled by child accounts.
- **SCPs as guardrails** prevent child accounts from disabling CloudTrail, leaving the org, or modifying the log bucket. SCPs don't grant -- they restrict.
- **Delegated admin for GuardDuty** moves the operational burden to the Security account (not the management account), following least privilege for the management account.
- **S3 Object Lock in Compliance mode** makes logs truly immutable -- not even the root user can delete them during the retention period. This is what auditors need.
- **Config Aggregator** gives a single-pane view of compliance across all 40 accounts without needing cross-account roles per account.

### Country Analogy

```
Organizations     = The UNITED NATIONS (governing body for all countries)
Management Acct   = The UN Secretary General's office
SCPs              = INTERNATIONAL LAWS — countries can't override them
                    "No country may dissolve its own audit department"
Child Accounts    = Member countries, each with their own government
OUs               = Continents grouping countries (Prod=Europe, Dev=Asia)
CloudTrail Org    = UN AUDITOR stationed in EVERY country simultaneously
  Trail             (one appointment covers all, countries can't fire them)
Log Archive Acct  = VAULT COUNTRY — a neutral, locked-down nation whose only
                    job is storing audit records. No one can enter and shred files.
S3 Object Lock    = The vault has TIME-LOCKED DOORS — documents can't be
                    removed until 7 years pass, not even by the vault keeper
GuardDuty         = INTELLIGENCE AGENCY with agents in every country,
                    reporting to a central HQ in the Security country
Config Aggregator = COMPLIANCE INSPECTOR who can see every country's
                    building codes from one office
Security Hub      = WAR ROOM dashboard — all findings from all agencies
                    on one screen
SNS               = The RED PHONE — rings when something is wrong
```

### Exam Question

**A company with 50 AWS accounts needs to ensure CloudTrail logging cannot be disabled by any individual account administrator. Logs must be stored immutably for 5 years. Which combination of services achieves this? (Choose 2)**

A. Enable CloudTrail in each account individually and use IAM policies to deny `cloudtrail:StopLogging`
B. Create an Organization Trail in the management account and apply an SCP denying `cloudtrail:StopLogging` and `cloudtrail:DeleteTrail`
C. Store logs in a centralised S3 bucket with S3 Object Lock in Compliance mode
D. Store logs in a centralised S3 bucket with S3 Object Lock in Governance mode

**Correct: B, C**

- **A is wrong:** IAM policies can be modified by account admins. SCPs cannot be overridden by child accounts -- only the management account controls SCPs.
- **B is correct:** Org Trail + SCP is the only way to guarantee child accounts cannot disable logging. The org trail automatically covers all accounts.
- **C is correct:** Compliance mode Object Lock means NO ONE (not even root) can delete objects during retention. This is what "immutable" means for auditors.
- **D is wrong:** Governance mode allows users with `s3:BypassGovernanceRetention` permission to delete objects. An admin could grant themselves that permission. Not truly immutable.

### Which Exam Tests This

- **SAA-C03**: Multi-account security architecture, S3 Object Lock, Organizations
- **SOA-C02**: Setting up org trails, Config aggregators, delegated admin
- **DVA-C02**: Less likely (this is infrastructure, not developer workflow)

### Key Trap

**Governance vs Compliance mode on S3 Object Lock.** The exam loves this distinction. Governance = "most people can't delete, but privileged users can bypass." Compliance = "absolutely nobody can delete, period." If the question says "immutable" or "regulatory" or "auditor" -- it's Compliance mode.

---

## Scenario 2: Encryption at Rest Everywhere

### The Scenario

A healthcare company handling PHI (Protected Health Information) must encrypt all data at rest using customer-managed keys with annual rotation. They use S3 for documents, RDS MySQL for patient records, EBS volumes for EC2 instances, and DynamoDB for session data. All encryption keys must be centrally managed and auditable.

### Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                         AWS KMS                                   │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │              Customer Managed Keys (CMKs)                   │  │
│  │                                                             │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐ │  │
│  │  │ s3-phi   │ │ rds-phi  │ │ ebs-phi  │ │ dynamo-phi   │ │  │
│  │  │ key      │ │ key      │ │ key      │ │ key          │ │  │
│  │  │          │ │          │ │          │ │              │ │  │
│  │  │ Rotation:│ │ Rotation:│ │ Rotation:│ │ Rotation:    │ │  │
│  │  │ Annual   │ │ Annual   │ │ Annual   │ │ Annual       │ │  │
│  │  │ (auto)   │ │ (auto)   │ │ (auto)   │ │ (auto)       │ │  │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └──────┬───────┘ │  │
│  │       │             │            │               │         │  │
│  └───────┼─────────────┼────────────┼───────────────┼─────────┘  │
│          │             │            │               │             │
│  ┌───────┼─────────────┼────────────┼───────────────┼─────────┐  │
│  │       │      Key Policy (per key)│               │         │  │
│  │  "Only role X    "Only RDS       "Only EC2       "Only     │  │
│  │   can encrypt/    service can     service can     DynamoDB  │  │
│  │   decrypt with    use this key"   use this key"   service   │  │
│  │   this key"                                       can use"  │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  CloudTrail logs EVERY key usage (kms:Decrypt, kms:GenerateData*)│
└──────────┬────────────┬─────────────┬───────────────┬────────────┘
           │            │             │               │
    ┌──────▼──────┐ ┌───▼─────┐ ┌────▼────┐ ┌───────▼──────┐
    │    S3       │ │  RDS    │ │  EBS    │ │  DynamoDB    │
    │             │ │  MySQL  │ │         │ │              │
    │ SSE-KMS     │ │         │ │ Encrypt │ │ Encryption   │
    │ (bucket     │ │ Storage │ │ at      │ │ at rest      │
    │  default    │ │ encrypt │ │ volume  │ │ (CMK)        │
    │  encryption)│ │ (CMK)   │ │ level   │ │              │
    │             │ │         │ │ (CMK)   │ │ Per-table    │
    │ Bucket      │ │ Enable  │ │         │ │ or default   │
    │ policy:     │ │ at      │ │ Default │ │              │
    │ DENY if     │ │ creation│ │ EBS     │ │              │
    │ not SSE-KMS │ │ (cannot │ │ encrypt │ │              │
    │             │ │ add     │ │ setting │ │              │
    │             │ │ later!) │ │ per-    │ │              │
    │             │ │         │ │ region  │ │              │
    └─────────────┘ └─────────┘ └─────────┘ └──────────────┘
           │            │             │               │
           └────────────┴─────────────┴───────────────┘
                                │
                    ┌───────────▼───────────┐
                    │  CloudTrail           │
                    │  (data event logging) │
                    │                       │
                    │  Every Encrypt/Decrypt│
                    │  call logged with:    │
                    │  - Who (principal)    │
                    │  - Which key          │
                    │  - When               │
                    │  - What resource      │
                    └───────────────────────┘
```

### Why This Architecture

- **Separate CMKs per service** follow least privilege for encryption. The S3 key can't be used to decrypt RDS data, and vice versa. If one key is compromised, blast radius is limited.
- **Key policies** are the primary access control for KMS keys (not just IAM). The key policy must explicitly allow the service principal to use the key. This is a separate layer from IAM.
- **Automatic annual rotation** keeps the same key ID but creates new backing key material. Old data stays readable (KMS keeps all old key material). New data uses new material. Zero downtime.
- **S3 bucket policy with DENY if not SSE-KMS** ensures no object can be uploaded without encryption. Belt-and-suspenders with default bucket encryption.
- **RDS encryption must be enabled at creation** -- you cannot encrypt an existing unencrypted RDS instance. You'd have to snapshot, copy snapshot with encryption, restore from encrypted snapshot. This is a huge exam trap.

### Country Analogy

```
KMS                = The NATIONAL LOCKSMITH SERVICE
CMKs               = MASTER KEYS — one for the warehouse, one for the
                     kitchen, one for the barracks, one for the building
Key Policies       = AUTHORISATION LISTS posted on each lock:
                     "Only warehouse staff may use the warehouse key"
Key Rotation       = The locksmith CHANGES THE LOCKS every year, but the
                     old keys still work on old doors (old data). New doors
                     get new locks (new data uses new key material).
SSE-KMS on S3      = Every box entering the warehouse MUST be padlocked
                     with the warehouse master key. No exceptions.
Bucket Policy DENY = A GUARD at the warehouse door who rejects any box
                     that isn't padlocked, even if the warehouse itself
                     would accept it
RDS Encryption     = The kitchen's walls are built with soundproofing
                     (encryption) at CONSTRUCTION TIME. You can't add
                     soundproofing after the kitchen is built — you'd
                     have to demolish and rebuild.
EBS Encryption     = Each soldier's locker is individually padlocked
Default EBS        = A REGIONAL LAW saying "all new lockers come padlocked
  Encryption         automatically" — no soldier needs to remember
CloudTrail + KMS   = The auditor logs EVERY TIME a key is used:
                     "Sgt Smith unlocked Locker 47 at 14:32"
```

### Exam Question

**A company needs to encrypt an existing unencrypted RDS MySQL database with a customer-managed KMS key. What is the correct approach?**

A. Modify the RDS instance to enable encryption and specify the KMS key
B. Create a snapshot, copy the snapshot with encryption enabled using the CMK, then restore from the encrypted snapshot
C. Enable encryption on the existing RDS instance using the AWS CLI `modify-db-instance` command with the `--kms-key-id` parameter
D. Create an RDS read replica with encryption enabled, then promote the read replica

**Correct: B**

- **A is wrong:** You cannot modify an existing RDS instance to add encryption. The console option is greyed out for unencrypted instances.
- **B is correct:** The only way is: snapshot → copy snapshot with encryption → restore. The copy step is where you specify the CMK.
- **C is wrong:** Same as A but using CLI. The API will reject this -- encryption is an immutable property set at creation.
- **D is wrong:** An unencrypted RDS instance cannot create an encrypted read replica. Read replicas inherit the encryption status of the source.

### Which Exam Tests This

- **SAA-C03**: KMS CMK architecture, encryption patterns, key rotation
- **SOA-C02**: Enabling default EBS encryption, troubleshooting unencrypted resources
- **DVA-C02**: Envelope encryption concept, using KMS in application code (GenerateDataKey)

### Key Trap

**You cannot encrypt an existing unencrypted RDS instance in-place.** The exam will offer "modify the instance" as a tempting answer. It's always wrong. Same applies to EBS volumes -- you can't encrypt an existing unencrypted volume. You must create an encrypted snapshot and restore/create from it.

---

## Scenario 3: Zero-Trust API Architecture

### The Scenario

A fintech startup is building a public-facing REST API that handles payment processing. They need: user authentication via social login and email/password, fine-grained authorization per endpoint, protection against DDoS and SQL injection, and the Lambda functions must access an RDS database in a private subnet without traversing the internet.

### Architecture Diagram

```
                        INTERNET
                           │
                    ┌──────▼──────┐
                    │     WAF     │
                    │             │
                    │ Rules:      │
                    │ - Rate limit│
                    │   (2000/5m) │
                    │ - SQL inject│
                    │   managed   │
                    │   rule set  │
                    │ - Geo block │
                    │ - IP reputa-│
                    │   tion list │
                    └──────┬──────┘
                           │
                    ┌──────▼──────────────────────────────────────┐
                    │          API GATEWAY (REST API)              │
                    │                                              │
                    │  ┌────────────────────────────────────────┐ │
                    │  │       Cognito Authorizer                │ │
                    │  │                                         │ │
                    │  │  Validates JWT from Cognito User Pool   │ │
                    │  │  Checks: token expiry, signature,      │ │
                    │  │  audience, issuer                       │ │
                    │  │                                         │ │
                    │  │  Passes claims (groups, custom attribs) │ │
                    │  │  to Lambda via $context.authorizer      │ │
                    │  └────────────────────────────────────────┘ │
                    │                                              │
                    │  Resource Policy:                            │
                    │  - Allow only from specific VPC endpoint     │
                    │    (for internal callers)                    │
                    │  - Allow public access (for external users)  │
                    │                                              │
                    │  Usage Plans + API Keys (for B2B partners)  │
                    │  Throttling: 1000 req/sec, burst 2000       │
                    └──────┬──────────────────────────────────────┘
                           │
          ┌────────────────┼────────────────────────┐
          │                │                         │
   ┌──────▼──────┐ ┌──────▼──────┐ ┌───────────────▼───────────┐
   │  Lambda     │ │  Lambda     │ │  Lambda                    │
   │  /payments  │ │  /users     │ │  /transactions             │
   │             │ │             │ │                             │
   │  IAM Role:  │ │  IAM Role:  │ │  IAM Role:                │
   │  pay-role   │ │  user-role  │ │  txn-role                 │
   │  (DynamoDB  │ │  (Cognito   │ │  (RDS connect,            │
   │   write)    │ │   admin)    │ │   Secrets Manager read)   │
   │             │ │             │ │                             │
   │  VPC: YES   │ │  VPC: NO   │ │  VPC: YES                 │
   └──────┬──────┘ └────────────┘ └───────────┬───────────────┘
          │                                    │
          │    ┌───────────────────────────┐   │
          │    │      PRIVATE VPC          │   │
          │    │                           │   │
          └────┤  Private Subnet A        ├───┘
               │  ┌─────────────────────┐ │
               │  │  Lambda ENIs        │ │
               │  │  (auto-created when │ │
               │  │   Lambda in VPC)    │ │
               │  └────────┬────────────┘ │
               │           │              │
               │  ┌────────▼────────────┐ │
               │  │  VPC Endpoint       │ │
               │  │  (Secrets Manager)  │ │
               │  │  Interface type     │ │
               │  │  - Private DNS      │ │
               │  │  - No internet      │ │
               │  └─────────────────────┘ │
               │                          │
               │  Private Subnet B        │
               │  ┌─────────────────────┐ │
               │  │  RDS MySQL          │ │
               │  │  Multi-AZ           │ │
               │  │  Security Group:    │ │
               │  │  Allow 3306 from    │ │
               │  │  Lambda SG only     │ │
               │  └─────────────────────┘ │
               │                          │
               └──────────────────────────┘

        ┌──────────────────────────────────────┐
        │         COGNITO USER POOL            │
        │                                       │
        │  Identity Providers:                  │
        │  - Email/password (built-in)          │
        │  - Google (social)                    │
        │  - Facebook (social)                  │
        │                                       │
        │  Groups: admin, user, partner         │
        │  Custom attributes: tenant_id         │
        │                                       │
        │  App Client:                          │
        │  - OAuth2 flows: Authorization Code   │
        │  - Scopes: openid, payments:write     │
        │                                       │
        │  Token: JWT (access + ID + refresh)   │
        └──────────────────────────────────────┘
```

### Why This Architecture

- **WAF in front of API Gateway** catches attacks before they reach your code. Managed rule groups (SQL injection, known bad inputs) are maintained by AWS. Rate limiting protects against DDoS at the application layer.
- **Cognito authorizer on API Gateway** validates JWTs without your Lambda running at all. Invalid tokens are rejected at the gateway level -- cheaper and faster than validating inside Lambda.
- **Each Lambda gets its own IAM role** with only the permissions it needs. The payments Lambda can write to DynamoDB but can't touch Cognito. The users Lambda can manage Cognito but can't access the database. Blast radius is minimised.
- **Lambda in VPC** is required to reach the private RDS instance. Without VPC attachment, Lambda runs in AWS's shared network and cannot access your private subnets.
- **VPC Endpoint for Secrets Manager** means the Lambda can fetch database credentials without needing a NAT Gateway or internet access. Traffic stays on AWS's private network.

### Country Analogy

```
WAF                 = BORDER CHECKPOINT — inspects everyone entering the
                      country. Known criminals (SQL injection patterns) are
                      turned away. Too many arrivals per minute? Gate closes.
API Gateway         = The CUSTOMS DESK inside the airport. Checks your
                      passport (JWT), stamps it, routes you to the right
                      department.
Cognito Authorizer  = PASSPORT CONTROL OFFICER at customs — verifies your
                      passport is real, not expired, issued by a trusted
                      authority. No valid passport = you don't enter.
Cognito User Pool   = The PASSPORT OFFICE — issues passports (JWTs),
                      supports foreign passports (Google, Facebook = social
                      login), stamps group memberships on the passport.
Lambda (per-function= SPECIALISED GOVERNMENT WORKERS — the payments clerk
  IAM roles)          can access the treasury but not the citizen registry.
                      The citizen clerk can access the registry but not the
                      treasury. Each worker has a BADGE with specific doors.
Lambda in VPC       = The worker is STATIONED INSIDE the army base. They
                      can walk to the database room directly.
VPC Endpoint        = A SECURE INTERNAL PHONE LINE inside the base that
                      connects to the Secrets vault. No need to leave the
                      base (no internet) to call.
RDS in private      = The DATABASE VAULT is deep inside the army base.
  subnet              No outside road leads to it. Only base personnel
                      (Lambda in same VPC) can walk in.
Security Group      = The DOOR LOCK on the vault: "Only personnel with
                      Lambda badges (Lambda SG) may enter through port 3306"
```

### Exam Question

**A Lambda function in a VPC needs to call AWS Secrets Manager to retrieve database credentials but must not use the internet. What should you configure?**

A. Add a NAT Gateway in a public subnet and route Lambda's private subnet through it
B. Create an interface VPC endpoint for Secrets Manager in the Lambda's VPC with private DNS enabled
C. Attach an Elastic IP to the Lambda function's ENI
D. Move the Lambda function out of the VPC so it can access Secrets Manager directly

**Correct: B**

- **A is wrong:** NAT Gateway works but uses the internet (traffic goes VPC → NAT → IGW → internet → Secrets Manager). The requirement says "must not use the internet."
- **B is correct:** Interface VPC endpoint creates a private connection to Secrets Manager. With private DNS, the Lambda calls the normal `secretsmanager.region.amazonaws.com` endpoint, but traffic routes privately through the endpoint. No internet involved.
- **C is wrong:** You cannot attach an Elastic IP to a Lambda ENI. Lambda ENIs are managed by AWS.
- **D is wrong:** Moving Lambda out of VPC means it loses access to the private RDS instance. This solves one problem but creates another.

### Which Exam Tests This

- **SAA-C03**: VPC endpoints, Lambda in VPC, zero-trust patterns, WAF + API Gateway
- **DVA-C02**: Cognito authorizers, Lambda execution roles, API Gateway configuration
- **SOA-C02**: WAF rule management, VPC endpoint troubleshooting, security group debugging

### Key Trap

**Lambda in VPC loses internet access by default.** Many candidates forget this. Lambda in a private subnet can't reach ANY AWS service (S3, DynamoDB, SQS, Secrets Manager) unless you add either a NAT Gateway (for internet route) or VPC endpoints (for private route). The exam will test whether you know the difference and when to use which.

---

## Scenario 4: Continuous Compliance Monitoring & Auto-Remediation

### The Scenario

A company's security policy requires: all S3 buckets must have versioning enabled, all EBS volumes must be encrypted, all security groups must not allow SSH (port 22) from 0.0.0.0/0, and all IAM users must have MFA enabled. Non-compliant resources must be automatically remediated within 15 minutes, and all compliance evidence must be retained for auditors.

### Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────┐
│                        AWS CONFIG                                   │
│                                                                     │
│  Config Recorder (records ALL resource changes)                     │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    Config Rules                               │  │
│  │                                                               │  │
│  │  ┌──────────────┐ ┌────────────────┐ ┌───────────────────┐  │  │
│  │  │ s3-bucket-   │ │ encrypted-     │ │ restricted-ssh    │  │  │
│  │  │ versioning-  │ │ volumes        │ │                   │  │  │
│  │  │ enabled      │ │                │ │ (AWS Managed Rule)│  │  │
│  │  │              │ │ (AWS Managed)  │ │                   │  │  │
│  │  │ (AWS Managed)│ │                │ │ Checks: SG with   │  │  │
│  │  │              │ │ Checks: EBS    │ │ 0.0.0.0/0:22     │  │  │
│  │  │ Checks: S3   │ │ vol encrypted? │ │                   │  │  │
│  │  │ versioning?  │ │                │ │                   │  │  │
│  │  └──────┬───────┘ └───────┬────────┘ └────────┬──────────┘  │  │
│  │         │                  │                    │             │  │
│  │  ┌──────▼───────┐ ┌───────▼────────┐ ┌────────▼──────────┐  │  │
│  │  │ Remediation  │ │ Remediation    │ │ Remediation       │  │  │
│  │  │ Action:      │ │ Action:        │ │ Action:           │  │  │
│  │  │ SSM Auto-    │ │ SNS Alert      │ │ SSM Automation    │  │  │
│  │  │ mation doc   │ │ (can't auto-   │ │ doc:              │  │  │
│  │  │ "Enable S3   │ │ encrypt exist- │ │ "Revoke SG rule   │  │  │
│  │  │ Versioning"  │ │ ing EBS vol)   │ │ allowing 22 from  │  │  │
│  │  │              │ │                │ │ 0.0.0.0/0"        │  │  │
│  │  └──────┬───────┘ └───────┬────────┘ └────────┬──────────┘  │  │
│  └─────────┼─────────────────┼────────────────────┼─────────────┘  │
│            │                  │                    │                 │
└────────────┼──────────────────┼────────────────────┼─────────────────┘
             │                  │                    │
      ┌──────▼───────┐  ┌──────▼──────┐  ┌──────────▼────────┐
      │ SSM          │  │    SNS      │  │ SSM               │
      │ Automation   │  │             │  │ Automation         │
      │              │  │  Topic:     │  │                    │
      │ RunBook:     │  │  "security- │  │ RunBook:           │
      │ AWS-Enable   │  │   alerts"   │  │ Custom doc:        │
      │ S3Bucket     │  │             │  │ revoke-open-ssh    │
      │ Versioning   │  │  ┌────────┐ │  │                    │
      │              │  │  │ Email  │ │  │ Steps:             │
      │ Runs auto-   │  │  │ Sub    │ │  │ 1. Describe SG     │
      │ matically    │  │  │        │ │  │ 2. Revoke ingress  │
      │ when non-    │  │  │ Slack  │ │  │    0.0.0.0/0:22   │
      │ compliant    │  │  │ Sub    │ │  │ 3. SNS notify      │
      └──────────────┘  │  └────────┘ │  └────────────────────┘
                        └─────────────┘
             │                                       │
             ▼                                       ▼
      ┌──────────────────────────────────────────────────────┐
      │              S3 — Compliance Evidence Bucket          │
      │                                                       │
      │  Config Snapshots (periodic full state)               │
      │  Config History (per-resource change timeline)        │
      │  Compliance evaluation results (JSON)                 │
      │                                                       │
      │  Lifecycle: Standard → IA (90d) → Glacier (1y)       │
      │  Retention: 5 years                                   │
      └──────────────────────────────────────────────────────┘
```

### Why This Architecture

- **AWS Managed Config Rules** are pre-built by AWS for common checks (S3 versioning, EBS encryption, open SSH). No custom Lambda needed for standard compliance checks.
- **Auto-remediation via SSM Automation** runs immediately when non-compliance is detected. Config triggers the SSM document, which executes the fix. S3 versioning can be enabled automatically. Open SSH rules can be revoked automatically.
- **EBS encryption cannot be auto-remediated** on existing volumes (same issue as RDS). You must alert and manually handle it. The architecture acknowledges this by routing to SNS instead of SSM.
- **Config delivers compliance snapshots to S3** for audit evidence. This gives auditors a point-in-time record of every resource's compliance status.
- **SSM Automation documents** are the "how-to" scripts. AWS provides pre-built ones (like `AWS-EnableS3BucketVersioning`) and you can write custom ones for specific remediations.

### Country Analogy

```
AWS Config          = BUILDING INSPECTORS — they continuously inspect every
                      building (resource) in the country
Config Rules        = BUILDING CODES — "every warehouse must have
                      fire sprinklers (versioning)", "every locker must have
                      a padlock (encryption)", "no building may have an
                      unlocked front door (open SSH)"
Config Recorder     = The inspector's NOTEBOOK — records every change to
                      every building, who changed it, when
Non-compliant       = VIOLATION NOTICE — "Building X fails Code Y"
SSM Automation      = REPAIR CREWS dispatched automatically when a
                      violation is found. "Crew: go install fire sprinklers
                      on Warehouse X immediately."
SNS Alert           = When the repair crew CAN'T fix it (can't encrypt an
                      existing locker), they send a RADIO ALERT to the
                      security chief: "Manual intervention needed"
S3 Evidence Bucket  = The FILING CABINET where all inspection reports,
                      violation notices, and repair receipts are stored
                      for auditors to review
Compliance Snapshot = A PHOTOGRAPH of every building's compliance status
                      at a specific moment — "On March 1, here's what
                      was compliant and what wasn't"
```

### Exam Question

**A company uses AWS Config rules to detect non-compliant resources. They want S3 buckets without versioning to be automatically remediated. Which service should Config trigger for auto-remediation?**

A. AWS Lambda function that calls the S3 API to enable versioning
B. AWS Systems Manager Automation document
C. Amazon EventBridge rule that triggers a Step Functions workflow
D. AWS CloudFormation stack update

**Correct: B**

- **A is wrong:** While Lambda could do this, Config has a native integration with SSM Automation for remediation. Lambda would require custom code and permissions management that SSM Automation handles out of the box.
- **B is correct:** Config rules have a built-in "Remediation action" that directly triggers SSM Automation documents. AWS even provides pre-built documents like `AWS-EnableS3BucketVersioning`. This is the intended pattern.
- **C is wrong:** EventBridge + Step Functions is over-engineered for this. Config's native remediation doesn't use EventBridge.
- **D is wrong:** CloudFormation manages infrastructure as code but isn't a remediation engine. You wouldn't update a stack to enable versioning on a bucket that was created outside CloudFormation.

### Which Exam Tests This

- **SOA-C02**: This is a primary SOA topic. Config rules, auto-remediation, SSM Automation, compliance monitoring.
- **SAA-C03**: Understanding Config's role in compliance architecture.
- **DVA-C02**: Less likely unless combined with custom Config rules using Lambda.

### Key Trap

**Config remediation uses SSM Automation, not Lambda.** The exam wants you to know the native integration. Also: auto-remediation has two modes -- **automatic** (fixes immediately) and **manual** (queues the fix for human approval). If the question says "automatically," you need automatic remediation. If it says "with approval," you need manual.

---

## Scenario 5: Cross-Account Resource Sharing

### The Scenario

A company has three AWS accounts: a Shared Services account (networking, DNS), a Production account (workloads), and a Data Analytics account (reporting). The production account needs to use a Transit Gateway owned by Shared Services, the analytics account needs to read from an S3 bucket in the production account, and developers in the production account need to assume a read-only role in the analytics account to debug queries.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                     AWS ORGANIZATIONS                                │
│                     Management Account                               │
│                                                                      │
│  OU: Infrastructure          OU: Workloads         OU: Analytics    │
│  ┌───────────────────┐  ┌───────────────────┐  ┌─────────────────┐ │
│  │ Shared Services   │  │ Production        │  │ Data Analytics  │ │
│  │ Account (111...)  │  │ Account (222...)  │  │ Account (333...)│ │
│  └───────────────────┘  └───────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════
METHOD 1: AWS RAM (Resource Access Manager) — Transit Gateway Sharing
═══════════════════════════════════════════════════════════════════════

┌─────────────────────────┐          ┌─────────────────────────┐
│  Shared Services (111)  │          │  Production (222)       │
│                         │   RAM    │                         │
│  Transit Gateway ───────┼──Share──▶│  TGW appears in this    │
│  (owned here)           │          │  account's console.     │
│                         │          │  Prod creates TGW       │
│  RAM Resource Share:    │          │  attachment from its    │
│  - Resource: TGW        │          │  VPC.                   │
│  - Principal: Org or    │          │                         │
│    Account 222          │          │  No need to manage      │
│  - Auto-accept (if Org) │          │  the TGW itself.        │
└─────────────────────────┘          └─────────────────────────┘

═══════════════════════════════════════════════════════════════════════
METHOD 2: S3 Resource Policy — Cross-Account Bucket Access
═══════════════════════════════════════════════════════════════════════

┌─────────────────────────┐          ┌─────────────────────────┐
│  Production (222)       │          │  Data Analytics (333)   │
│                         │          │                         │
│  S3 Bucket:             │  Bucket  │  IAM Role:              │
│  "prod-data-lake"       │  Policy  │  "analytics-reader"     │
│                         │◀─────────│                         │
│  Bucket Policy:         │          │  IAM Policy:            │
│  {                      │          │  {                      │
│   "Principal": {        │          │   "Action": "s3:Get*",  │
│     "AWS": "arn:aws:iam │          │   "Resource":           │
│      ::333:role/         │          │    "arn:aws:s3:::       │
│      analytics-reader"  │          │     prod-data-lake/*"   │
│   },                    │          │  }                      │
│   "Action": "s3:Get*",  │          │                         │
│   "Resource": "arn:aws  │          │  BOTH policies must     │
│    :s3:::prod-data-     │          │  allow the access!      │
│    lake/*"              │          │                         │
│  }                      │          │                         │
└─────────────────────────┘          └─────────────────────────┘

═══════════════════════════════════════════════════════════════════════
METHOD 3: STS AssumeRole — Cross-Account Role Assumption
═══════════════════════════════════════════════════════════════════════

┌─────────────────────────┐          ┌─────────────────────────┐
│  Production (222)       │          │  Data Analytics (333)   │
│                         │          │                         │
│  Developer IAM User/    │  STS     │  IAM Role:              │
│  Role: "dev-team"       │ Assume   │  "debug-readonly"       │
│                         │  Role    │                         │
│  IAM Policy on          │─────────▶│  Trust Policy:          │
│  dev-team:              │          │  {                      │
│  {                      │          │   "Principal": {        │
│   "Action":             │          │     "AWS": "arn:aws:iam │
│    "sts:AssumeRole",    │          │      ::222:role/         │
│   "Resource":           │          │      dev-team"          │
│    "arn:aws:iam::333    │          │   },                    │
│    :role/debug-readonly"│          │   "Condition": {        │
│  }                      │          │     "Bool": {           │
│                         │          │      "aws:MultiFactor   │
│  Developer runs:        │          │       AuthPresent":     │
│  aws sts assume-role    │          │       "true"            │
│  --role-arn arn:...     │          │     }                   │
│  → Gets temp creds      │          │   }                     │
│    (15min-12hr)         │          │  }                      │
│                         │          │                         │
│                         │          │  Permissions Policy:    │
│                         │          │  ReadOnlyAccess         │
│                         │          │  (AWS managed policy)   │
└─────────────────────────┘          └─────────────────────────┘
```

### Why This Architecture

- **AWS RAM for Transit Gateway** is the proper way to share network resources. The TGW stays in the shared services account (single owner), but production can attach its VPCs. No duplicate infrastructure, centralised network management.
- **S3 resource policy for cross-account access** requires BOTH the bucket policy (in the owning account) AND the IAM policy (in the accessing account) to allow the access. This two-sided handshake prevents either account from unilaterally granting access.
- **STS AssumeRole with MFA condition** is the gold standard for cross-account human access. Temporary credentials (not long-term keys), MFA required, time-limited (configurable 15 min to 12 hours). The trust policy in the target account is the "invitation" and the IAM policy in the source account is the "permission to accept."
- **Organizations enables RAM auto-accept** -- within an org, shared resources are automatically accepted without manual approval. Outside an org, the recipient must explicitly accept the share.
- **Separate methods for different use cases**: RAM for infrastructure sharing (TGW, subnets), resource policies for data access (S3, KMS, SQS), STS for human/service access to another account's console/API.

### Country Analogy

```
AWS RAM             = INTERNATIONAL HIGHWAY AGREEMENT — Country A (Shared
                      Services) builds a highway (Transit Gateway). Country
                      B (Production) signs an agreement to build an on-ramp
                      to it. The highway is owned and managed by Country A,
                      but Country B's citizens can use it.
                      Within the UN (Org), the agreement is automatic.

S3 Resource Policy  = IMPORT/EXPORT TREATY — Country B (Production) has a
  (cross-account)     warehouse with goods. Country C (Analytics) wants to
                      read the inventory.
                      TWO signatures needed:
                      1. Country B stamps the warehouse door: "Country C's
                         analyst may enter and read" (bucket policy)
                      2. Country C gives its analyst a passport that says
                         "allowed to visit Country B's warehouse" (IAM policy)
                      If EITHER signature is missing, the door stays locked.

STS AssumeRole     = DIPLOMATIC VISA — A developer in Country B (Production)
                      wants to visit Country C (Analytics) as a read-only
                      observer.
                      1. Country C issues a STANDING INVITATION:
                         "Country B's dev-team may visit, but must show
                         their MFA badge" (trust policy)
                      2. Country B's government says "our dev-team is
                         allowed to accept that invitation" (IAM policy)
                      3. Developer goes to the EMBASSY (STS), shows MFA,
                         gets a TEMPORARY VISITOR VISA (temp credentials)
                         valid for a set time (not permanent residency!)

Organizations      = The UN ensures all countries recognise each other.
                      RAM shares auto-accept within the UN (org).
```

### Exam Question

**An analytics team in Account B needs to read objects from an S3 bucket in Account A. The bucket does not have a bucket policy. A developer in Account B creates an IAM role with `s3:GetObject` permission on the bucket ARN. The role cannot access the bucket. What is the cause?**

A. The S3 bucket has ACLs blocking cross-account access
B. The S3 bucket in Account A needs a bucket policy explicitly allowing Account B's role
C. The IAM role needs `sts:AssumeRole` permission for Account A
D. S3 cross-account access requires AWS RAM sharing

**Correct: B**

- **A is wrong:** Default ACLs don't block cross-account access; the issue is the absence of a bucket policy. ACLs are legacy and not the primary mechanism here.
- **B is correct:** Cross-account S3 access requires BOTH an IAM policy in the requesting account AND a resource policy (bucket policy) in the owning account. Without the bucket policy, the owning account hasn't consented to the access.
- **C is wrong:** `sts:AssumeRole` is for assuming roles in another account. This role is in Account B accessing a resource in Account A -- it needs S3 permissions, not STS permissions. The IAM role already has the right S3 permissions; the missing piece is on Account A's side.
- **D is wrong:** RAM is for sharing infrastructure resources (Transit Gateway, subnets, etc.). S3 cross-account access uses bucket policies, not RAM.

### Which Exam Tests This

- **SAA-C03**: Cross-account patterns (RAM, resource policies, STS AssumeRole) are heavily tested
- **SOA-C02**: Troubleshooting cross-account access failures, setting up RAM shares
- **DVA-C02**: STS AssumeRole in application code, understanding temporary credentials

### Key Trap

**Cross-account S3 access needs BOTH sides to agree.** The IAM policy alone (in the accessing account) is not enough. The bucket policy (in the owning account) must also allow the access. The only exception: if the accessing account's role assumes a role IN the owning account (via STS), then only the owning account's role permissions matter. But direct cross-account access? Both policies must say yes.

---

## HIGH AVAILABILITY & DISASTER RECOVERY (Scenarios 6-10)

---

## Scenario 6: Active-Passive DR (Pilot Light)

### The Scenario

An e-commerce company runs its primary application in us-east-1. They need a disaster recovery strategy with an RTO of 1 hour and RPO of 15 minutes. The solution must minimise cost during normal operations while enabling rapid failover. The application uses an ALB, ASG with EC2 instances, RDS MySQL, and S3 for static assets.

### Architecture Diagram

```
                     ┌──────────────────────────┐
                     │       Route 53            │
                     │                           │
                     │  shop.example.com         │
                     │  Type: Failover           │
                     │                           │
                     │  Primary: us-east-1 ALB   │
                     │  (health check: /health)  │
                     │                           │
                     │  Secondary: us-west-2 ALB │
                     │  (failover record)        │
                     └─────────┬─────────────────┘
                               │
              ┌────────────────┴────────────────┐
              │                                  │
              ▼                                  ▼
┌─────────────────────────────┐  ┌─────────────────────────────────┐
│    us-east-1 (PRIMARY)      │  │    us-west-2 (DR — PILOT LIGHT) │
│                             │  │                                  │
│  ┌───────────────────────┐  │  │  ┌────────────────────────────┐ │
│  │  ALB                  │  │  │  │  ALB                       │ │
│  │  (active, serving     │  │  │  │  (provisioned but idle —   │ │
│  │   traffic)            │  │  │  │   no targets yet)          │ │
│  └───────────┬───────────┘  │  │  └────────────┬───────────────┘ │
│              │              │  │               │                  │
│  ┌───────────▼───────────┐  │  │  ┌────────────▼───────────────┐ │
│  │  ASG                  │  │  │  │  ASG                       │ │
│  │  Desired: 4           │  │  │  │  Desired: 0 (ZERO!)       │ │
│  │  Min: 2, Max: 8       │  │  │  │  Min: 0, Max: 8           │ │
│  │  EC2 instances        │  │  │  │  Launch Template ready     │ │
│  │  (running)            │  │  │  │  AMI: synced via           │ │
│  └───────────────────────┘  │  │  │  cross-region AMI copy     │ │
│                             │  │  └────────────────────────────┘ │
│  ┌───────────────────────┐  │  │                                  │
│  │  RDS MySQL            │  │  │  ┌────────────────────────────┐ │
│  │  Primary (Multi-AZ)   │──┼──┼─▶│  RDS MySQL                │ │
│  │                       │  │  │  │  Cross-Region Read Replica │ │
│  │  Automatic backups    │  │  │  │  (running, async repl)     │ │
│  │  every 5 min          │  │  │  │                            │ │
│  └───────────────────────┘  │  │  │  On failover:              │ │
│                             │  │  │  PROMOTE to standalone     │ │
│  ┌───────────────────────┐  │  │  └────────────────────────────┘ │
│  │  S3 Bucket            │  │  │                                  │
│  │  "shop-assets-east"   │──┼──┼─▶┌────────────────────────────┐ │
│  │                       │  │  │  │  S3 Bucket                 │ │
│  │  Cross-Region         │  │  │  │  "shop-assets-west"        │ │
│  │  Replication (CRR)    │  │  │  │  (replica, <15 min lag)    │ │
│  └───────────────────────┘  │  │  └────────────────────────────┘ │
│                             │  │                                  │
│  Cost: $$$$ (full prod)    │  │  Cost: $ (only RDS replica +    │
│                             │  │  ALB + S3 running. No EC2!)     │
└─────────────────────────────┘  └─────────────────────────────────┘

═══════════════════════════════════════════════════════════════════
FAILOVER SEQUENCE (when Route 53 health check fails):
═══════════════════════════════════════════════════════════════════

1. Route 53 detects primary ALB unhealthy → switches DNS to us-west-2
2. CloudWatch Alarm triggers Lambda (or manual action):
   a. Promote RDS read replica to standalone primary
   b. Update ASG desired count: 0 → 4
   c. EC2 instances launch from pre-baked AMI (~5 min)
3. ALB registers new EC2 targets, passes health checks
4. Traffic flows to us-west-2

Total failover time: ~30-60 minutes (within 1-hour RTO)
```

### Why This Architecture

- **Pilot Light** means the minimum core infrastructure is always running in DR region (just the database replica and network). Compute is provisioned but not running. This is cheaper than Warm Standby (where some compute runs) but slower to fail over.
- **RDS Cross-Region Read Replica** provides near-real-time data replication (async, usually seconds of lag). On failover, you promote it to a standalone primary. This is NOT the same as Multi-AZ (which is same-region HA, not DR).
- **S3 CRR (Cross-Region Replication)** replicates objects asynchronously. With S3 Replication Time Control (S3 RTC), 99.99% of objects replicate within 15 minutes, meeting the RPO.
- **ASG at Desired 0** means the launch template, AMI, security groups, and IAM roles are all pre-configured. The "pilot light" is lit -- you just need to turn up the flame (increase desired count).
- **Route 53 Failover routing** automatically detects when the primary is unhealthy and redirects DNS. But DNS propagation takes time, so the actual switch depends on TTL settings.

### Country Analogy

```
PRIMARY REGION       = The CAPITAL CITY — full government, full military,
  (us-east-1)         all citizens, everything running

DR REGION            = A BACKUP BUNKER in another country
  (us-west-2)

Pilot Light          = The bunker has:
                       - BLUEPRINTS for every government building (AMIs,
                         launch templates)
                       - A LIVE COPY of all government records being
                         continuously shipped over (RDS read replica)
                       - A COPY of the national archives being mailed
                         over daily (S3 CRR)
                       - Empty buildings ready to staff (ALB exists,
                         ASG at 0)
                       But NO SOLDIERS are stationed there (no EC2 running)

Failover             = The capital is ATTACKED (region failure):
                       1. The Ministry of Foreign Affairs (Route 53)
                          redirects all foreign ambassadors to the bunker
                       2. The bunker activates:
                          a. Records office becomes the new official
                             archive (promote RDS replica)
                          b. Soldiers are deployed from reserves
                             (ASG scales from 0 to 4)
                          c. Government buildings open for business
                             (ALB gets healthy targets)
                       3. The bunker IS the new capital

RDS Cross-Region     = A SCRIBE in the capital continuously copies every
  Read Replica         new document and mails it to the bunker. The bunker
                       is always ~minutes behind. On failover, the bunker
                       scribe becomes the official record keeper (promote).

Cost Optimisation    = You don't PAY for a full army sitting in the bunker
                       doing nothing. You only pay for the scribe (RDS
                       replica), the mailroom (S3 CRR), and the building
                       shells (ALB). Soldiers cost nothing until deployed.
```

### Exam Question

**A company implements pilot light DR in a secondary region. Their RDS MySQL cross-region read replica has been promoted during a failover event. After the primary region recovers, what must they do to re-establish the DR architecture?**

A. The read replica relationship automatically resumes when the primary region recovers
B. Delete the promoted instance and create a new cross-region read replica from the primary
C. Use the promoted instance as the new primary and create a new read replica back to the original region
D. Restore the original primary from the latest automated backup

**Correct: C**

- **A is wrong:** Once promoted, a read replica becomes a standalone instance. The replication link is permanently broken. It never automatically re-links.
- **B is wrong:** This would mean losing all data written to the promoted instance during the outage. That data only exists in the DR region.
- **C is correct:** The promoted instance now has the most recent data (including writes during the outage). Make it the new primary, then create a new cross-region read replica pointing back to the original region. You've effectively swapped primary and DR regions.
- **D is wrong:** The automated backup in the original region is stale -- it doesn't include writes that happened in the DR region during the outage.

### Which Exam Tests This

- **SAA-C03**: DR strategies (pilot light vs warm standby vs active-active), RTO/RPO, Route 53 failover
- **SOA-C02**: Executing failover procedures, promoting read replicas, RDS operations
- **DVA-C02**: Less likely (this is infrastructure, not application code)

### Key Trap

**Promoting an RDS read replica is irreversible.** It becomes a standalone instance. You can't "unpromote" it back to a replica. After failover, you must build a NEW replication chain with the promoted instance as the source. The exam tests whether you understand this one-way door.

---

## Scenario 7: Active-Active Multi-Region

### The Scenario

A global SaaS platform serves users in North America, Europe, and Asia Pacific. They need sub-100ms latency for all users, zero-downtime deployments, and the ability to survive an entire region failure without manual intervention. The application is stateless (session data in DynamoDB), and they serve both API traffic and static content.

### Architecture Diagram

```
                         ┌──────────────────────────┐
                         │     ROUTE 53              │
                         │                           │
                         │  api.saas.com             │
                         │  Policy: Latency-based    │
                         │  routing                  │
                         │                           │
                         │  + Health checks on each  │
                         │    region's ALB            │
                         │                           │
                         │  If region fails →         │
                         │  latency routing auto-    │
                         │  excludes unhealthy       │
                         └────────┬──────────────────┘
                                  │
              ┌───────────────────┼───────────────────────┐
              │                   │                        │
              ▼                   ▼                        ▼
┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
│   us-east-1         │ │   eu-west-1         │ │   ap-southeast-1    │
│                     │ │                     │ │                     │
│ ┌─────────────────┐ │ │ ┌─────────────────┐ │ │ ┌─────────────────┐ │
│ │      ALB        │ │ │ │      ALB        │ │ │ │      ALB        │ │
│ └────────┬────────┘ │ │ └────────┬────────┘ │ │ └────────┬────────┘ │
│          │          │ │          │          │ │          │          │
│ ┌────────▼────────┐ │ │ ┌────────▼────────┐ │ │ ┌────────▼────────┐ │
│ │      ASG        │ │ │ │      ASG        │ │ │ │      ASG        │ │
│ │   EC2 / ECS     │ │ │ │   EC2 / ECS     │ │ │ │   EC2 / ECS     │ │
│ └────────┬────────┘ │ │ └────────┬────────┘ │ │ └────────┬────────┘ │
│          │          │ │          │          │ │          │          │
│ ┌────────▼────────┐ │ │ ┌────────▼────────┐ │ │ ┌────────▼────────┐ │
│ │    DynamoDB     │ │ │ │    DynamoDB     │ │ │ │    DynamoDB     │ │
│ │  Global Table   │◀┼─┼─▶  Global Table   │◀┼─┼─▶  Global Table   │ │
│ │  (replica)      │ │ │ │  (replica)      │ │ │ │  (replica)      │ │
│ │                 │ │ │ │                 │ │ │ │                 │ │
│ │  Read + Write   │ │ │ │  Read + Write   │ │ │ │  Read + Write   │ │
│ │  (local)        │ │ │ │  (local)        │ │ │ │  (local)        │ │
│ └─────────────────┘ │ │ └─────────────────┘ │ │ └─────────────────┘ │
│                     │ │                     │ │                     │
└─────────────────────┘ └─────────────────────┘ └─────────────────────┘

═══════════════════════════════════════════════════════════════════
STATIC CONTENT LAYER
═══════════════════════════════════════════════════════════════════

         ┌──────────────────────────────────────────┐
         │            CloudFront                     │
         │                                           │
         │  Distribution: static.saas.com            │
         │                                           │
         │  Origin: S3 bucket (us-east-1)            │
         │  + S3 CRR to eu-west-1 origin group       │
         │  + Origin failover (if primary 5xx)       │
         │                                           │
         │  Edge Locations: 400+ worldwide           │
         │  Cache: static assets (JS, CSS, images)   │
         │                                           │
         │  ┌─────────────────────────────────────┐  │
         │  │      Lambda@Edge                     │  │
         │  │                                      │  │
         │  │  - A/B testing (modify request)      │  │
         │  │  - Auth token validation at edge     │  │
         │  │  - URL rewriting                     │  │
         │  │  - Custom headers (security)         │  │
         │  └─────────────────────────────────────┘  │
         └──────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════
CONFLICT RESOLUTION (DynamoDB Global Tables)
═══════════════════════════════════════════════════════════════════

  User A in US writes item X at T1
  User B in EU writes item X at T2 (T2 > T1)

  → DynamoDB Global Tables use "last writer wins" (timestamp-based)
  → Item X = User B's version in ALL regions after replication
  → Replication typically < 1 second
  → Application must be designed to handle this!
```

### Why This Architecture

- **DynamoDB Global Tables** are the key enabler -- they allow read AND write in every region, with automatic multi-master replication. Unlike RDS, you don't need to "promote" anything during failover. Every region is already a primary.
- **Route 53 latency-based routing** sends each user to the region with lowest network latency from their location. Combined with health checks, unhealthy regions are automatically excluded. No manual failover needed.
- **CloudFront with Lambda@Edge** handles static content globally. Edge locations cache content close to users. Lambda@Edge runs custom logic (auth, A/B testing) at the edge without hitting the origin.
- **Stateless application tier** is critical for active-active. No server holds session state -- it's all in DynamoDB Global Tables. Any server in any region can handle any request.
- **Last writer wins** is DynamoDB Global Tables' conflict resolution. The application must be designed to tolerate this (e.g., idempotent operations, conflict-safe data models).

### Country Analogy

```
Active-Active       = THREE CAPITAL CITIES running simultaneously. The US
                      capital, the European capital, and the Asian capital
                      all have FULL government offices, full military,
                      and full authority to act.

Route 53 Latency    = The MINISTRY OF FOREIGN AFFAIRS routes each visitor
                      to the NEAREST capital. An American goes to the US
                      capital. A German goes to the European capital.
                      If a capital is destroyed, visitors are sent to the
                      next-nearest capital automatically.

DynamoDB Global     = Every capital has a COMPLETE COPY of all national
  Tables              records. When one capital writes a new law, it's
                      automatically REPLICATED to the other two within
                      seconds. ALL capitals can write laws (multi-master).
                      If two capitals write conflicting laws at the same
                      time? The LATER timestamp wins. The country must be
                      designed to handle this.

CloudFront          = POST OFFICES in every major city worldwide. Citizens
                      pick up their mail (static content) from the nearest
                      post office, not from the capital.

Lambda@Edge         = CUSTOMS OFFICERS at each post office who check IDs,
                      redirect mail, or add stamps before delivering.

Stateless App       = Government workers have NO PERSONAL FILING CABINETS.
                      Everything is in the shared national records (DynamoDB).
                      Any worker in any capital can serve any citizen because
                      all data is in the shared system.
```

### Exam Question

**A company uses DynamoDB Global Tables for active-active multi-region. Two users in different regions update the same item simultaneously. How does DynamoDB resolve this conflict?**

A. The first write wins and the second write is rejected with a ConditionalCheckFailedException
B. Both writes are stored and the application must resolve the conflict on read
C. The write with the latest timestamp wins (last writer wins)
D. DynamoDB uses vector clocks to merge both writes

**Correct: C**

- **A is wrong:** DynamoDB Global Tables do NOT reject concurrent writes. There's no optimistic locking built into the replication mechanism.
- **B is wrong:** DynamoDB doesn't store multiple conflicting versions (unlike some distributed databases). It resolves immediately.
- **C is correct:** Global Tables use "last writer wins" based on the item's timestamp. The write with the most recent timestamp overwrites the other in all regions. Applications must be designed for this.
- **D is wrong:** DynamoDB does not use vector clocks. That's a Cassandra/Riak pattern. DynamoDB uses simple timestamp-based resolution.

### Which Exam Tests This

- **SAA-C03**: Multi-region architecture, Global Tables, Route 53 routing policies, CloudFront
- **DVA-C02**: DynamoDB Global Tables conflict resolution, Lambda@Edge use cases
- **SOA-C02**: Setting up Global Tables, monitoring replication lag

### Key Trap

**DynamoDB Global Tables = last writer wins.** The exam tests whether you know the conflict resolution strategy. Also: Global Tables require DynamoDB Streams to be enabled (replication uses streams under the hood). If streams are disabled, you can't create a global table.

---

## Scenario 8: Self-Healing Infrastructure

### The Scenario

A media streaming company runs a fleet of EC2 instances behind an ALB. Instances occasionally crash due to memory leaks in a third-party library. They need the infrastructure to detect unhealthy instances, terminate them, launch replacements, and notify the ops team -- all without human intervention. The system should also handle cases where the application is running but not responding to HTTP requests.

### Architecture Diagram

```
                    ┌─────────────────────────────┐
                    │           ALB               │
                    │                             │
                    │  Health Check:              │
                    │  Path: /health              │
                    │  Interval: 10 sec           │
                    │  Threshold: 3 consecutive   │
                    │  unhealthy = mark unhealthy │
                    │                             │
                    │  What it catches:           │
                    │  - App not responding        │
                    │  - 5xx errors               │
                    │  - Timeout (app hung)       │
                    └──────────┬──────────────────┘
                               │
                    ┌──────────▼──────────────────┐
                    │     AUTO SCALING GROUP       │
                    │                              │
                    │  Health Check Type: ELB      │
                    │  (NOT just EC2!)             │
                    │                              │
                    │  EC2 health check: is the    │
                    │  VM running? (basic)         │
                    │                              │
                    │  ELB health check: is the    │
                    │  APP healthy? (deep)         │
                    │                              │
                    │  Grace Period: 300 sec       │
                    │  (don't check new instances  │
                    │   for 5 min while they boot) │
                    │                              │
                    │  ┌────┐ ┌────┐ ┌────┐ ┌────┐│
                    │  │ EC2│ │ EC2│ │ EC2│ │ EC2││
                    │  │ OK │ │ OK │ │SICK│ │ OK ││
                    │  └────┘ └────┘ └──┬─┘ └────┘│
                    │                   │          │
                    │  ASG detects: ────┘          │
                    │  "Instance i-xxx is          │
                    │   unhealthy (ELB says so)"   │
                    │                              │
                    │  ASG ACTION:                 │
                    │  1. Terminate i-xxx          │
                    │  2. Launch new instance      │
                    │  3. Register with ALB        │
                    │  (maintains desired count)   │
                    └──────────┬───────────────────┘
                               │
         ┌─────────────────────┼──────────────────────┐
         │                     │                       │
         ▼                     ▼                       ▼
┌────────────────┐  ┌──────────────────┐  ┌───────────────────────┐
│  CloudWatch    │  │  CloudWatch      │  │  ASG Lifecycle Hook   │
│  Alarms        │  │  Composite Alarm │  │  (optional, advanced) │
│                │  │                  │  │                       │
│ Alarm 1:       │  │ "IF Alarm1 AND   │  │ On termination:       │
│ CPUUtilization │  │  Alarm2 THEN     │  │ 1. Pause termination  │
│ > 85% for 5min │  │  ALARM"          │  │ 2. Lambda drains      │
│                │  │                  │  │    connections         │
│ Alarm 2:       │  │ Reduces false    │  │ 3. Lambda captures    │
│ MemoryUsage    │  │ positives —      │  │    heap dump to S3    │
│ > 90% for 5min │  │ both conditions  │  │ 4. Complete lifecycle  │
│ (custom metric │  │ must be true     │  │    action             │
│  via CW Agent) │  │                  │  │                       │
│                │  │                  │  │ (debugging evidence    │
│ Alarm 3:       │  └────────┬─────────┘  │  preserved)           │
│ UnhealthyHost  │           │            └───────────────────────┘
│ Count > 0      │           │
│                │           │
└───────┬────────┘           │
        │                    │
        ▼                    ▼
┌────────────────────────────────────┐
│              SNS                    │
│                                    │
│  Topic: "infra-alerts"             │
│                                    │
│  Subscribers:                      │
│  ├── Email: ops-team@company.com   │
│  ├── SMS: +61-xxx (on-call)        │
│  ├── Lambda: slack-notifier        │
│  └── Lambda: incident-logger       │
│      (writes to DynamoDB           │
│       incident tracking table)     │
└────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════
FULL SELF-HEALING FLOW:
═══════════════════════════════════════════════════════════════════

  1. Instance memory leaks → app stops responding to /health
  2. ALB marks instance as unhealthy after 3 failed checks (30 sec)
  3. ASG detects ELB health check failure
  4. ASG terminates the unhealthy instance
  5. ASG launches a new instance from the launch template
  6. New instance boots, runs user data script, starts app
  7. ALB health check passes on new instance after grace period
  8. CloudWatch alarm fires → SNS → ops team notified
  9. Desired count maintained automatically

  Human intervention: ZERO
  Downtime: near-zero (other instances still serving traffic)
```

### Why This Architecture

- **ELB health checks on the ASG (not just EC2)** are critical. EC2-level health checks only detect if the VM is running. ELB health checks detect if the APPLICATION is responding. A memory leak that freezes the app won't kill the VM, so EC2 health check says "healthy" while the app is dead.
- **Health check grace period** prevents ASG from terminating instances that are still booting. Without it, a slow-starting application would be marked unhealthy and terminated in a loop.
- **Composite CloudWatch alarms** reduce alert fatigue. A CPU spike alone might be normal (traffic burst). But CPU spike AND memory spike AND unhealthy hosts? That's a real incident.
- **ASG Lifecycle Hooks** let you run custom logic before termination completes. Capture a heap dump, drain connections, write a log -- then allow the termination. This gives you debugging evidence.
- **SNS fanout to multiple subscribers** ensures the right people are notified through the right channels. Email for records, SMS for urgency, Lambda for automated incident tracking.

### Country Analogy

```
ALB Health Check    = A DOCTOR who visits each soldier every 10 seconds.
                      "Say 'aah'" (GET /health). Three failed visits =
                      soldier is declared unfit for duty.

ASG (ELB check)     = The COMMANDER watches the doctor's reports. When a
                      soldier is declared unfit:
                      1. Discharge the sick soldier (terminate)
                      2. Call up a reserve (launch new instance)
                      3. The reserve reports for duty (registers with ALB)

EC2 health check    = Checking if the soldier has a PULSE. Alive? OK.
  (basic)             But they might be unconscious (app frozen) and still
                      have a pulse. Not good enough.

ELB health check    = Checking if the soldier can PERFORM THEIR DUTIES.
  (deep)              "Can you salute? Can you march? Can you respond?"
                      This catches the frozen soldier.

Grace Period        = BASIC TRAINING — new recruits get 5 minutes before
                      the doctor starts checking them. They're still
                      getting dressed (booting up).

CloudWatch Alarms   = RADAR SYSTEMS watching the battlefield. One alarm
                      for each threat: enemy aircraft (CPU), artillery
                      (memory), casualties (unhealthy hosts).

Composite Alarm     = The WAR ROOM only activates when multiple radar
                      systems detect threats simultaneously. One blip?
                      Maybe a bird. Three blips? Scramble fighters.

Lifecycle Hook      = Before discharging the sick soldier, the MEDIC:
                      1. Finishes treating current patients (drain connections)
                      2. Takes a blood sample for the lab (heap dump to S3)
                      3. Then and only then, soldier is discharged

SNS                 = The RED PHONE network — simultaneously calls the
                      general (email), the medic (SMS), and updates the
                      war log (Lambda → DynamoDB).
```

### Exam Question

**An ASG uses EC2 health checks (default). Instances behind an ALB occasionally have their application crash, but the EC2 instance remains running. The ASG does not replace these instances. What should be changed?**

A. Reduce the health check interval on the ALB
B. Change the ASG health check type from EC2 to ELB
C. Add a CloudWatch alarm to detect unhealthy instances and trigger ASG scaling
D. Use a custom health check script on the instance that terminates itself

**Correct: B**

- **A is wrong:** Reducing the ALB health check interval makes the ALB detect failures faster, but the ASG still only checks EC2 status. The ASG doesn't use ALB health check results unless configured to.
- **B is correct:** When ASG health check type is set to ELB, the ASG uses the ALB's health check results. If the ALB says an instance is unhealthy (app not responding), the ASG will terminate and replace it. This is the key configuration.
- **C is wrong:** Over-engineered. ASG already has built-in health check replacement. You just need to tell it to use the ELB health check instead of the EC2 health check.
- **D is wrong:** Having the instance terminate itself is fragile and a hack. What if the script also crashes? The proper solution is the ASG's built-in ELB health check integration.

### Which Exam Tests This

- **SAA-C03**: ASG health check types, ALB integration, self-healing patterns
- **SOA-C02**: Configuring health checks, troubleshooting ASG replacement issues, lifecycle hooks
- **DVA-C02**: Less common but possible with CloudWatch custom metrics

### Key Trap

**ASG defaults to EC2 health checks, NOT ELB.** You must explicitly set the health check type to ELB when using an ALB. This is the single most common misconfiguration in ASG + ALB architectures. The exam WILL test this.

---

## Scenario 9: Blue/Green Deployment

### The Scenario

A company deploys updates to a web application running on EC2 instances every week. They need zero-downtime deployments with the ability to instantly roll back if the new version has issues. They want to test the new version with a small percentage of traffic before fully switching over. The application is stateless.

### Architecture Diagram

```
═══════════════════════════════════════════════════════════════════
PHASE 1: NORMAL STATE (100% → Blue)
═══════════════════════════════════════════════════════════════════

                    ┌───────────────────────────────┐
                    │          Route 53              │
                    │                                │
                    │  app.example.com               │
                    │  Type: Weighted Routing        │
                    │                                │
                    │  Blue ALB: weight 100          │
                    │  Green ALB: weight 0           │
                    └──────────┬────────────────────┘
                               │
              ┌────────────────┴────────────────┐
              │ (100%)                    (0%)  │
              ▼                                 ▼
┌─────────────────────────┐  ┌─────────────────────────┐
│   BLUE ENVIRONMENT      │  │   GREEN ENVIRONMENT     │
│   (CURRENT v1.0)        │  │   (NEW v1.1)            │
│                         │  │                         │
│  ┌───────────────────┐  │  │  ┌───────────────────┐  │
│  │  ALB (Blue)       │  │  │  │  ALB (Green)      │  │
│  └────────┬──────────┘  │  │  └────────┬──────────┘  │
│           │             │  │           │             │
│  ┌────────▼──────────┐  │  │  ┌────────▼──────────┐  │
│  │  ASG (Blue)       │  │  │  │  ASG (Green)      │  │
│  │  Desired: 4       │  │  │  │  Desired: 4       │  │
│  │  v1.0 AMI         │  │  │  │  v1.1 AMI         │  │
│  │                   │  │  │  │  (pre-deployed,    │  │
│  │  ┌──┐ ┌──┐       │  │  │  │   warmed up)      │  │
│  │  │EC│ │EC│       │  │  │  │                   │  │
│  │  │2 │ │2 │ ...   │  │  │  │  ┌──┐ ┌──┐       │  │
│  │  └──┘ └──┘       │  │  │  │  │EC│ │EC│ ...   │  │
│  └───────────────────┘  │  │  │  │2 │ │2 │       │  │
│                         │  │  │  └──┘ └──┘       │  │
└─────────────────────────┘  │  └───────────────────┘  │
                             │                         │
                             └─────────────────────────┘

═══════════════════════════════════════════════════════════════════
PHASE 2: CANARY TEST (90% → Blue, 10% → Green)
═══════════════════════════════════════════════════════════════════

                    ┌───────────────────────────────┐
                    │          Route 53              │
                    │                                │
                    │  Blue ALB: weight 90           │
                    │  Green ALB: weight 10          │
                    └───────────────────────────────┘

  Monitor for 30 minutes:
  - Error rates (CloudWatch)
  - Latency (CloudWatch)
  - Custom business metrics

  If errors spike → set Green weight to 0 (instant rollback)
  If healthy → proceed to Phase 3

═══════════════════════════════════════════════════════════════════
PHASE 3: FULL CUTOVER (0% → Blue, 100% → Green)
═══════════════════════════════════════════════════════════════════

                    ┌───────────────────────────────┐
                    │          Route 53              │
                    │                                │
                    │  Blue ALB: weight 0            │
                    │  Green ALB: weight 100         │
                    └───────────────────────────────┘

  Blue ASG still running (standby for rollback)
  After confidence period (e.g., 24h):
  → Terminate Blue ASG (or swap roles: Blue becomes next Green)

═══════════════════════════════════════════════════════════════════
ALTERNATIVE: CodeDeploy Blue/Green (managed by AWS)
═══════════════════════════════════════════════════════════════════

┌────────────────────────────────────────────────────────────────┐
│                    CodeDeploy                                   │
│                                                                 │
│  Deployment Group: blue-green                                  │
│                                                                 │
│  Traffic Shifting Options:                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ AllAtOnce      — instant 100% switch                    │   │
│  │ Canary10Pct5Min — 10% for 5 min, then 100%             │   │
│  │ Linear10Pct1Min — +10% every minute until 100%          │   │
│  │ Custom          — your own percentages and intervals    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Auto Rollback Triggers:                                       │
│  - CloudWatch alarm fires → auto rollback                      │
│  - Deployment fails → auto rollback                            │
│  - Manual rollback within window                               │
│                                                                 │
│  Lifecycle Hooks:                                              │
│  BeforeInstall → AfterInstall → BeforeAllowTraffic →          │
│  AfterAllowTraffic                                             │
│  (run tests at each stage!)                                    │
└────────────────────────────────────────────────────────────────┘
```

### Why This Architecture

- **Two full environments (Blue + Green)** mean the new version is fully tested and warmed up before any traffic hits it. No cold starts, no "first request is slow" problem.
- **Route 53 weighted routing** gives precise traffic control. 90/10 split for canary, then shift to 0/100 for cutover. Weight changes propagate within seconds (subject to TTL).
- **Instant rollback** = flip the weight back. If Green is broken, set Green to 0, Blue to 100. DNS propagates, traffic returns to the old version. Faster than redeploying.
- **CodeDeploy blue/green** automates the entire process including traffic shifting, health monitoring, and automatic rollback on alarm. It manages the ASG replacement sets.
- **Cost trade-off**: You're running 2x capacity during the deployment window. This is the price of zero-downtime blue/green. For cost-sensitive environments, consider rolling deployments instead.

### Country Analogy

```
Blue Environment    = The CURRENT GOVERNMENT — fully staffed, running
                      the country, citizens interact with them daily

Green Environment   = The SHADOW GOVERNMENT — fully staffed, fully trained
                      on new policies (v1.1), ready to take over but
                      currently has no citizens visiting

Route 53 Weighted   = The MINISTRY OF FOREIGN AFFAIRS controls which
                      government citizens are directed to

Canary (90/10)      = "Send 10% of citizens to the new government for a
                      trial period. Monitor how things go. If the new
                      government makes bad decisions (errors), pull
                      everyone back to the old government immediately."

Full Cutover        = "The trial went well. ALL citizens now go to the
                      new government. Old government is on standby
                      in case we need to revert."

Instant Rollback    = "New government is making a mess! FLIP THE SWITCH —
                      everyone goes back to the old government. Takes
                      seconds, not hours."

CodeDeploy          = An ELECTION COMMISSION that manages the transition
                      automatically: gradually shifts citizens, monitors
                      for problems, and can call a snap election (rollback)
                      if things go wrong

Cost (2x capacity)  = You're PAYING TWO FULL GOVERNMENTS during the
                      transition. Expensive, but guarantees no gap in
                      service.
```

### Exam Question

**A company uses CodeDeploy for blue/green deployments to EC2 instances behind an ALB. They want 10% of traffic routed to the new version for 10 minutes, then all traffic shifted if no CloudWatch alarms fire. Which deployment configuration should they use?**

A. CodeDeployDefault.AllAtOnce
B. CodeDeployDefault.OneAtATime
C. A custom configuration with Canary10Percent10Minutes
D. CodeDeployDefault.HalfAtATime

**Correct: C**

- **A is wrong:** AllAtOnce sends 100% immediately. No canary testing, no gradual shift.
- **B is wrong:** OneAtATime is a rolling deployment pattern (one instance at a time), not blue/green traffic shifting. It applies to in-place deployments.
- **C is correct:** Canary deployment configuration sends 10% of traffic first, waits the specified time (10 minutes), monitors alarms, then shifts the remaining 90%. This is exactly the requested behavior.
- **D is wrong:** HalfAtATime is also a rolling deployment pattern, not a canary traffic shift.

### Which Exam Tests This

- **DVA-C02**: CodeDeploy deployment configurations, blue/green patterns (heavily tested)
- **SAA-C03**: Route 53 weighted routing for blue/green, high-level deployment patterns
- **SOA-C02**: Managing CodeDeploy groups, troubleshooting deployment failures

### Key Trap

**CodeDeploy deployment types: in-place vs blue/green.** In-place updates the existing instances (rolling). Blue/green creates new instances and shifts traffic. The deployment CONFIGURATIONS (AllAtOnce, OneAtATime, HalfAtATime) apply to in-place. The traffic shifting options (Canary, Linear, AllAtOnce) apply to blue/green with ALB. Don't mix them up.

---

## Scenario 10: Database DR with Aurora Global Database

### The Scenario

A banking application uses Amazon Aurora MySQL for its core transaction database. Regulatory requirements mandate: RPO of 1 second, RTO of 1 minute for the database tier, automated failover without application code changes, encrypted backups available in a second region, and database credentials must be available in both regions. The application currently runs in us-east-1 with plans for DR in eu-west-1.

### Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────┐
│                    AURORA GLOBAL DATABASE                           │
│                                                                     │
│  ┌──────────────────────────────┐  ┌─────────────────────────────┐ │
│  │  PRIMARY CLUSTER             │  │  SECONDARY CLUSTER          │ │
│  │  us-east-1                   │  │  eu-west-1                  │ │
│  │                              │  │                             │ │
│  │  ┌────────────────────────┐  │  │  ┌───────────────────────┐ │ │
│  │  │  Writer Instance       │  │  │  │  Reader Instance(s)   │ │ │
│  │  │  (db.r6g.2xlarge)     │──┼──┼──▶  (read-only)          │ │ │
│  │  │                        │  │  │  │                       │ │ │
│  │  │  Handles all writes    │  │  │  │  Can serve local      │ │ │
│  │  │  + reads               │  │  │  │  read traffic         │ │ │
│  │  └────────────────────────┘  │  │  │                       │ │ │
│  │           │                   │  │  │  On failover:         │ │ │
│  │  ┌────────▼───────────────┐  │  │  │  PROMOTED to writer   │ │ │
│  │  │  Reader Instance(s)    │  │  │  │  (< 1 minute)        │ │ │
│  │  │  (same-region replicas)│  │  │  └───────────────────────┘ │ │
│  │  └────────────────────────┘  │  │                             │ │
│  │                              │  │  Replication lag:           │ │
│  │  Storage: 6 copies across   │  │  typically < 1 second       │ │
│  │  3 AZs (automatic)          │  │  (dedicated replication     │ │
│  │                              │  │   infrastructure, NOT       │ │
│  │                              │  │   binlog-based)             │ │
│  └──────────────────────────────┘  └─────────────────────────────┘ │
│                                                                     │
│  Cross-Region Replication:                                         │
│  - Storage-level (not logical/binlog)                              │
│  - Sub-second lag (RPO < 1 second)                                 │
│  - Dedicated replication network                                   │
│  - Data encrypted in transit                                       │
└────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════
AUTOMATED FAILOVER MECHANISM
═══════════════════════════════════════════════════════════════════

┌────────────────────────────────────────────────────────────────┐
│                                                                 │
│  MANAGED PLANNED FAILOVER (for planned DR testing):            │
│  - Zero data loss (waits for replication to catch up)          │
│  - Demotes primary, promotes secondary                         │
│  - ~1-2 minutes                                                │
│                                                                 │
│  UNPLANNED FAILOVER (detach + promote):                        │
│  - Detach secondary from global cluster                        │
│  - Promote to standalone cluster with writer                   │
│  - RPO: ~1 second (whatever hadn't replicated)                 │
│  - RTO: ~1 minute                                              │
│  - Can be automated via Lambda + CloudWatch                    │
│                                                                 │
│  WRITE FORWARDING (no failover needed for writes):             │
│  - Secondary region can forward writes to primary              │
│  - Adds latency (cross-region round trip)                      │
│  - Useful for active-active read + write patterns              │
│                                                                 │
└────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════
APPLICATION CONNECTIVITY (zero code changes)
═══════════════════════════════════════════════════════════════════

┌─────────────────────────┐     ┌─────────────────────────┐
│  us-east-1 App          │     │  eu-west-1 App          │
│                         │     │                         │
│  Connects to:           │     │  Connects to:           │
│  ┌───────────────────┐  │     │  ┌───────────────────┐  │
│  │ Cluster Endpoint  │  │     │  │ Reader Endpoint   │  │
│  │ (writer)          │  │     │  │ (read-only)       │  │
│  │ xxx.cluster-      │  │     │  │ xxx.cluster-ro-   │  │
│  │ abc.us-east-1.    │  │     │  │ def.eu-west-1.    │  │
│  │ rds.amazonaws.com │  │     │  │ rds.amazonaws.com │  │
│  └───────────────────┘  │     │  └───────────────────┘  │
│                         │     │                         │
│  After failover:        │     │  After failover:        │
│  Cluster endpoint DNS   │     │  This cluster's endpoint│
│  updates automatically  │     │  becomes the new writer │
│  (may take ~30 sec)     │     │  endpoint               │
└─────────────────────────┘     └─────────────────────────┘

═══════════════════════════════════════════════════════════════════
SECRETS MANAGER REPLICATION
═══════════════════════════════════════════════════════════════════

┌─────────────────────────┐     ┌─────────────────────────┐
│  us-east-1              │     │  eu-west-1              │
│                         │     │                         │
│  Secret:                │     │  Secret (replica):      │
│  "prod/aurora/creds"    │────▶│  "prod/aurora/creds"    │
│                         │     │                         │
│  {                      │     │  Same ARN pattern,      │
│   "host": "xxx.cluster" │     │  same name,             │
│   "username": "admin"   │     │  auto-synced            │
│   "password": "rotated" │     │                         │
│  }                      │     │  App uses same secret   │
│                         │     │  name in both regions   │
│  Auto-rotation: 30 days │     │                         │
│  Rotation Lambda        │     │  Rotation replicates    │
│                         │     │  automatically          │
└─────────────────────────┘     └─────────────────────────┘

═══════════════════════════════════════════════════════════════════
CROSS-REGION PITR (Point-in-Time Recovery)
═══════════════════════════════════════════════════════════════════

  Primary cluster (us-east-1):
  - Continuous backup to S3 (automatic, no performance impact)
  - PITR window: up to 35 days
  - Restore to any second within the window

  Secondary cluster (eu-west-1):
  - Has its OWN backup/PITR capability
  - Can restore to a point-in-time independently
  - Critical for scenarios where you need to recover from
    logical corruption (bad data write) in a specific region
```

### Why This Architecture

- **Aurora Global Database replicates at the storage level**, not through binlog (which is what RDS MySQL cross-region replicas use). Storage-level replication is faster (sub-second) and doesn't impact the writer's performance.
- **Managed planned failover** is for DR drills and planned migrations. It ensures zero data loss by waiting for the secondary to fully catch up before switching. Unplanned failover (detach + promote) is for actual disasters and accepts up to ~1 second of data loss.
- **Cluster endpoints resolve via DNS**, so after failover, the endpoint automatically points to the new writer. Applications don't need to change connection strings -- just reconnect. The DNS update takes ~30 seconds.
- **Secrets Manager replication** ensures database credentials exist in both regions. Without this, the DR region's application wouldn't know the database password after failover. Rotation in the primary automatically replicates to the secondary.
- **Each region has its own PITR** -- this is important for logical corruption recovery. If someone runs `DELETE FROM accounts WHERE 1=1` and it replicates to the secondary (replication is at the storage level, it replicates everything including bad writes), you need PITR to restore to before the bad write.

### Country Analogy

```
Aurora Global       = TWO NATIONAL TREASURIES connected by a dedicated
  Database            underground tunnel. Every gold coin deposited in
                      Treasury A appears in Treasury B within 1 second
                      via the tunnel (storage-level replication).

Primary Cluster     = TREASURY A (Capital) — accepts deposits and
  (writer)            withdrawals (writes and reads)

Secondary Cluster   = TREASURY B (Embassy abroad) — can show you your
  (reader)            balance (reads) but if you want to deposit, it
                      sends your request through the tunnel to Treasury A
                      (write forwarding). On disaster: Treasury B becomes
                      the new official treasury in < 1 minute.

Storage-Level       = The UNDERGROUND TUNNEL between treasuries. It carries
  Replication         the actual gold (data blocks), not receipts (binlog
                      statements). Faster and more reliable than mailing
                      transaction receipts (binlog replication).

Planned Failover    = SCHEDULED GOVERNMENT TRANSITION — the old treasury
                      chief ensures every last coin is accounted for
                      before handing the keys to the new chief. Zero loss.

Unplanned Failover  = EMERGENCY SUCCESSION — the old treasury is destroyed.
                      The embassy treasury takes over immediately. Some
                      coins that were "in the tunnel" (< 1 second) might
                      be lost. But the country keeps running.

Cluster Endpoint    = The MAILING ADDRESS of the treasury. After failover,
                      the postal service (DNS) automatically forwards
                      all mail to the new location. Citizens don't need
                      to learn a new address — same address, different
                      building.

Secrets Manager     = The COMBINATION TO THE VAULT. It's written on
  Replication         identical cards stored in both countries. When the
                      combination changes (rotation), both cards update
                      automatically. The DR country's staff can always
                      open their vault.

PITR                = A TIME MACHINE for the treasury. "Show me exactly
                      what the records looked like at 2:47 PM yesterday."
                      Works in both treasuries independently. Critical
                      when someone accidentally deletes records — the
                      underground tunnel faithfully replicated the
                      deletion to Treasury B too!
```

### Exam Question

**A company uses Aurora Global Database with a primary cluster in us-east-1 and a secondary in eu-west-1. During a regional outage in us-east-1, the secondary cluster must become the primary. What is the correct failover procedure?**

A. Use the "failover" option on the Aurora Global Database to switch primary regions
B. Detach the secondary cluster from the global database, then promote a reader instance to writer
C. Create a new Aurora cluster from the latest cross-region backup in eu-west-1
D. Wait for the us-east-1 region to recover, as Aurora Global Database does not support cross-region failover

**Correct: B**

- **A is wrong:** The managed "planned failover" option requires BOTH regions to be healthy. During a regional outage, the primary is unreachable, so planned failover won't work. Planned failover is for DR drills, not actual disasters.
- **B is correct:** For an unplanned outage, you detach the secondary cluster from the global database (this breaks the replication link), which promotes it to a standalone cluster with a writer. This takes about 1 minute. RTO met.
- **C is wrong:** Creating a new cluster from a backup would take much longer than 1 minute (RTO violated). Also, you'd lose data between the last backup and the failure (RPO violated). The secondary cluster already has sub-second replication -- use it.
- **D is wrong:** Aurora Global Database absolutely supports cross-region failover. That's its entire purpose.

### Which Exam Tests This

- **SAA-C03**: Aurora Global Database architecture, DR strategies, RPO/RTO requirements
- **SOA-C02**: Executing Aurora failover procedures, Secrets Manager replication
- **DVA-C02**: Less likely unless combined with application connection handling

### Key Trap

**Planned failover vs unplanned failover (detach + promote).** The exam loves this distinction:
- **Planned failover** = both regions healthy, zero data loss, used for DR testing. Think "controlled government transition."
- **Unplanned failover** = primary region down, detach secondary, up to ~1 second data loss. Think "emergency succession."

If the question says "regional outage" or "disaster," the answer is ALWAYS detach + promote (unplanned). If it says "DR drill" or "planned migration," the answer is managed planned failover.

---

## Quick Reference: All 10 Scenarios

| # | Scenario | Key Services | Primary Exam |
|---|----------|-------------|--------------|
| 1 | Multi-account security | Organizations, SCPs, CloudTrail org trail, Config aggregator, GuardDuty | SAA / SOA |
| 2 | Encryption at rest everywhere | KMS CMK, SSE-KMS, RDS encryption, EBS encryption, key rotation | SAA / SOA |
| 3 | Zero-trust API | Cognito, API Gateway authorizer, Lambda in VPC, VPC endpoints, WAF | SAA / DVA |
| 4 | Compliance monitoring | Config rules, SSM Automation, SNS, S3 evidence | SOA |
| 5 | Cross-account sharing | Organizations, STS AssumeRole, resource policies, RAM | SAA / SOA |
| 6 | Active-passive DR (pilot light) | Route 53 failover, RDS cross-region replica, S3 CRR | SAA / SOA |
| 7 | Active-active multi-region | DynamoDB Global Tables, Route 53 latency, CloudFront, Lambda@Edge | SAA / DVA |
| 8 | Self-healing infrastructure | ASG, ALB health checks, CloudWatch alarms, SNS | SAA / SOA |
| 9 | Blue/green deployment | Route 53 weighted, CodeDeploy, 2x ALB/ASG | DVA / SAA |
| 10 | Database DR | Aurora Global Database, Secrets Manager replication, PITR | SAA / SOA |

---

## Top Exam Traps (Summary)

1. **S3 Object Lock: Governance vs Compliance** — "immutable" = Compliance mode
2. **RDS/EBS encryption cannot be added after creation** — snapshot + copy + restore
3. **Lambda in VPC loses internet** — needs NAT Gateway or VPC endpoints
4. **Config remediation uses SSM Automation**, not Lambda
5. **Cross-account S3 needs BOTH bucket policy AND IAM policy**
6. **RDS read replica promotion is irreversible** — build new replication chain after
7. **DynamoDB Global Tables = last writer wins** — design app accordingly
8. **ASG defaults to EC2 health check**, not ELB — must explicitly set to ELB
9. **CodeDeploy: in-place configs vs blue/green traffic shifting** — don't mix them
10. **Aurora planned failover needs both regions healthy** — outage = detach + promote
