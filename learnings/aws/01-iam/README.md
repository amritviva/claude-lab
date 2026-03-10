# 01 - IAM: The Government Identity System

> **Analogy:** IAM is the government of AWS-land. It issues passports (users), organises departments (groups), hands out temporary VIP badges (roles), and writes laws (policies) that determine who can do what.

---

## ELI10

Imagine AWS is a country, and IAM is the government's identity office. Every person who wants to enter the country needs a **passport** (IAM User). People are organised into **departments** like HR or Engineering (Groups). Sometimes a visitor needs a **temporary VIP badge** to access something special -- that's a **Role**. And all the rules about who can go where and do what are written down as **laws** (Policies). The country also has a **President** (Root User) who has ultimate power, but the president stays locked in a bunker and only comes out for emergencies.

---

## The Concept

### The Identity Hierarchy

```
ROOT USER (The President)
  │
  ├── IAM Users (Citizens with passports)
  │     ├── alice@company.com  (passport + console password)
  │     ├── bob@company.com    (passport + access keys for CLI)
  │     └── deploy-bot         (passport + access keys only, no console)
  │
  ├── IAM Groups (Government departments)
  │     ├── Developers         (department with its own laws)
  │     ├── Admins             (department with broad laws)
  │     └── ReadOnly           (department: look but don't touch)
  │
  ├── IAM Roles (Temporary VIP badges)
  │     ├── EC2-S3-ReadRole    (badge for soldiers to read warehouses)
  │     ├── Lambda-DynamoDB    (badge for Lambda to access DynamoDB)
  │     └── CrossAccountRole   (badge for visitors from another country)
  │
  └── IAM Policies (The laws)
        ├── AWS Managed         (pre-written federal laws)
        ├── Customer Managed    (custom state laws you write)
        └── Inline              (personal restraining orders, attached to one entity)
```

### Root User -- The President

The root user is created when you first open an AWS account. It has **unrestricted access** to everything.

**Lock the president away:**
- Enable MFA immediately (hardware MFA preferred)
- Do NOT create access keys for root
- Do NOT use root for daily tasks
- Use root ONLY for tasks that require it:
  - Change account settings (name, email, root password)
  - Close the account
  - Restore IAM user permissions (if you lock yourself out)
  - Change support plan
  - Enable MFA Delete on S3
  - Configure S3 bucket with cross-account access policies
  - Register as seller in GovCloud

### Users -- Citizens with Passports

An IAM User is a permanent identity within your account.

**Two types of credentials:**
1. **Console password** -- for AWS Management Console (like a passport at the airport counter)
2. **Access keys** (Access Key ID + Secret Access Key) -- for CLI/SDK/API (like a digital passport for programmatic access)

**Key facts:**
- New users have NO permissions by default (newborn citizen, no rights)
- Max 2 access keys per user (rotate without downtime)
- Access keys should be rotated regularly
- Users can belong to multiple groups
- **Users CANNOT belong to other users** (no nesting)

### Groups -- Government Departments

Groups are collections of users. Policies attached to a group apply to all members.

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Developers    │     │     Admins      │     │    ReadOnly     │
│                 │     │                 │     │                 │
│  alice          │     │  carol          │     │  eve            │
│  bob            │     │  dave           │     │  frank          │
│                 │     │                 │     │                 │
│ Policy:         │     │ Policy:         │     │ Policy:         │
│ EC2, S3, Lambda │     │ AdministratorAc │     │ ReadOnlyAccess  │
│ full access     │     │ cess            │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

**Key facts:**
- Groups can only contain users (not other groups -- no nesting!)
- A user can belong to up to **10 groups**
- Groups cannot be used as a Principal in a resource-based policy
- **There is no "All Users" group by default** -- you must create it
- Max **300 groups** per account

### Roles -- Temporary VIP Badges

Roles are the most powerful and most-tested concept in IAM. A Role is NOT a permanent identity -- it's a **set of temporary credentials** that can be assumed.

**Who assumes roles:**
- AWS Services (EC2 instance needs S3 access → assume a role)
- Users in another AWS account (cross-account access)
- Federated users (SAML/OIDC identity providers)
- Applications (web identity federation)

**How roles work:**

```
1. EC2 Instance: "I need to read S3"
        │
        ▼
2. STS (Visa Office): "Here's your temporary badge"
   Returns: AccessKeyId + SecretAccessKey + SessionToken
   Expires in: 1-12 hours (configurable)
        │
        ▼
3. EC2 uses temp credentials to call S3
   S3: "Badge checks out, here's your data"
```

**Role components:**
- **Trust Policy** -- WHO can assume this role (the bouncer's list)
- **Permission Policy** -- WHAT the role can do once assumed (the access card)

**STS -- The Visa Issuing Office:**
- `sts:AssumeRole` -- assume a role within or across accounts
- `sts:AssumeRoleWithSAML` -- assume using SAML token (corporate SSO)
- `sts:AssumeRoleWithWebIdentity` -- assume using OIDC token (Google, Facebook)
- `sts:GetSessionToken` -- get temp creds with MFA
- `sts:GetCallerIdentity` -- "who am I?" (like checking your passport)
- Credentials are temporary: default 1 hour, configurable 15min-12hrs

**Service-Linked Roles:**
- Pre-defined by AWS services
- Cannot be modified or deleted while the service uses them
- Example: `AWSServiceRoleForElasticLoadBalancing`

### Policies -- The Laws

Policies are JSON documents that define permissions.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3Read",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket",
        "arn:aws:s3:::my-bucket/*"
      ],
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": "203.0.113.0/24"
        }
      }
    }
  ]
}
```

**Policy types (by attachment):**
| Type | Analogy | Scope |
|------|---------|-------|
| AWS Managed | Federal laws (pre-written) | Reusable, maintained by AWS |
| Customer Managed | State laws (you write) | Reusable, you maintain |
| Inline | Personal restraining order | Attached to exactly one entity, dies with it |

**Policy types (by function):**
| Type | Analogy | Used For |
|------|---------|----------|
| Identity-based | Laws about what a citizen CAN do | Attached to users/groups/roles |
| Resource-based | Laws about who can enter a building | Attached to resources (S3 bucket, SQS queue) |
| Permission Boundary | Maximum security clearance level | Caps what a user/role CAN EVER do |
| SCP (Org) | Constitutional law | Caps what an entire account can do |
| Session Policy | Day pass restrictions | Limits permissions for one session |
| ACL | Legacy guest list | Old S3/VPC system, mostly replaced |

### Policy Evaluation Logic -- How AWS Decides

This is an exam favourite. The evaluation order:

```
START: Request comes in
  │
  ▼
1. By default: IMPLICIT DENY (everything denied unless allowed)
  │
  ▼
2. Check all applicable policies
  │
  ▼
3. Is there an EXPLICIT DENY anywhere?
  │
  ├── YES → DENY (game over, explicit deny ALWAYS wins)
  │
  └── NO → Is there an ALLOW?
            │
            ├── YES → ALLOW
            │
            └── NO → DENY (implicit deny)
```

**The golden rule: Explicit DENY always beats ALLOW.** No matter how many Allow statements exist, one Deny overrides them all.

**Cross-account access evaluation:**
- Identity-based policy in Account A must ALLOW
- Resource-based policy in Account B must ALLOW
- BOTH must allow -- it's like needing a visa from your country AND an entry stamp from the destination

**Same-account access evaluation:**
- EITHER identity-based OR resource-based policy can grant access
- Only one needs to allow (they're additive within the same account)

### Federation -- Accepting Foreign Passports

```
Corporate Active Directory (Foreign Country)
     │
     │ SAML 2.0
     ▼
AWS STS ──→ Temporary Role Credentials
     │
     ▼
User accesses AWS with corporate login
```

**Federation types:**
- **SAML 2.0** -- Enterprise SSO (Active Directory, Okta)
- **Web Identity (OIDC)** -- Social logins (Google, Facebook, Amazon)
- **AWS SSO / IAM Identity Center** -- AWS's recommended approach (successor to AWS SSO)
- **Custom Identity Broker** -- Your code calls STS directly

### Permission Boundaries -- Maximum Security Clearance

```
Permission Boundary (ceiling): s3:*, ec2:*, lambda:*
Identity Policy (actual grant):  s3:*, ec2:*, rds:*
                                         │
Effective permissions = INTERSECTION:    s3:*, ec2:*
(rds:* denied because it exceeds the boundary)
```

Permission boundaries are used when you want to delegate user creation. Example: Let a dev team create their own IAM users, but cap what those users can ever do.

### Access Keys vs Console Password

| Feature | Console Password | Access Keys |
|---------|-----------------|-------------|
| Used for | AWS Console (browser) | CLI / SDK / API |
| Authentication | Username + password + MFA | Access Key ID + Secret |
| Rotation | Password policy enforces | Manual, max 2 per user |
| Analogy | Showing passport at airport counter | Digital passport scan |

### MFA -- Double-Checking Your Passport

- Virtual MFA (Authenticator app) -- most common
- Hardware MFA (YubiKey, Gemalto) -- most secure, recommended for root
- SMS MFA -- least secure, being phased out
- Can require MFA via policy conditions: `"aws:MultiFactorAuthPresent": "true"`

---

## Architecture Diagram

```
┌─────────────────────── AWS ACCOUNT ───────────────────────┐
│                                                           │
│  ┌─── ROOT USER (President) ───┐                          │
│  │  - Full access              │                          │
│  │  - Lock away with MFA       │                          │
│  │  - No access keys!          │                          │
│  └─────────────────────────────┘                          │
│                                                           │
│  ┌─── IAM ─────────────────────────────────────────────┐  │
│  │                                                     │  │
│  │  Users ──────┐                                      │  │
│  │  (passports) ├──→ Groups (departments)              │  │
│  │              │      │                               │  │
│  │              │      ▼                               │  │
│  │              └──→ Policies (laws) ←── Roles         │  │
│  │                     │              (VIP badges)     │  │
│  │                     │                  ▲            │  │
│  │                     ▼                  │            │  │
│  │              ┌──────────┐         ┌────┴────┐      │  │
│  │              │Resources │         │  STS    │      │  │
│  │              │(S3, EC2) │         │(Visa    │      │  │
│  │              └──────────┘         │ Office) │      │  │
│  │                                   └─────────┘      │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                           │
│  ┌─── EXTERNAL ────────────────────────────────────────┐  │
│  │  Federation: SAML / OIDC / Identity Center          │  │
│  │  (Accepting foreign passports)                      │  │
│  └─────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────┘
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- Cross-account access patterns (role assumption)
- Identity-based vs resource-based policies
- Permission boundaries for delegated administration
- Federation with corporate IdP (SAML 2.0)
- Service-linked roles
- Policy evaluation logic (explicit deny wins)
- When to use IAM Identity Center vs IAM users

### DVA-C02 (Developer)
- Programmatic access with access keys
- STS AssumeRole, AssumeRoleWithWebIdentity
- IAM roles for Lambda execution
- Cognito vs IAM for mobile/web app authentication
- Policy variables and conditions
- Signing API requests (SigV4)

### SOA-C02 (SysOps Administrator)
- Password policies and rotation
- Access key rotation and auditing
- IAM Credential Report (account-level, all users)
- IAM Access Advisor (user-level, last accessed services)
- Troubleshooting access denied errors
- MFA enforcement via policies
- AWS Config rules for IAM compliance

---

## Key Numbers

| Fact | Value |
|------|-------|
| IAM Users per account | 5,000 |
| Groups per account | 300 |
| Roles per account | 1,000 |
| Managed policies per user/group/role | 10 |
| Inline policies per user | 10 |
| Customer managed policies per account | 1,500 |
| Policy document size (managed) | 6,144 characters |
| Policy document size (inline) | 2,048 characters |
| Groups per user | 10 |
| Access keys per user | 2 |
| MFA devices per user | 8 |
| STS session duration (AssumeRole) | 15 min - 12 hours (default 1hr) |
| STS session duration (Console federation) | 15 min - 12 hours |
| Account alias | Globally unique, 3-63 chars |
| IAM is | GLOBAL (not regional) |

---

## Cheat Sheet

- IAM is a **global** service (not tied to any Region)
- Root user: lock it down, MFA, no access keys, use only for account-level tasks
- New IAM users have **ZERO permissions** by default
- Explicit DENY always wins over Allow -- no exceptions
- Roles > Users for services (never embed access keys in EC2/Lambda)
- STS issues temporary credentials (like a visa office)
- Groups contain users only -- no nesting groups inside groups
- Permission Boundary = ceiling on what identity-based policies can grant
- Cross-account: both sides must allow (identity policy + resource policy)
- Same-account: either side can allow (identity OR resource policy)
- Credential Report = account-wide CSV of all users and their credential status
- Access Advisor = per-user report of which services were last accessed
- IAM Identity Center (AWS SSO) = recommended for managing workforce access
- Service-Linked Roles = pre-made by AWS, can't modify, auto-created
- Policy evaluation: Explicit Deny > Explicit Allow > Implicit Deny
- Use policy conditions for extra security: MFA required, IP restrictions, time-based
- IAM Access Analyzer: identifies resources shared externally
