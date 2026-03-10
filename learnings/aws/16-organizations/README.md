# 16 — Organizations: The United Nations

> **One-liner:** AWS Organizations is the United Nations — it governs multiple countries (accounts), enforces treaties (SCPs), and manages a single treasury (consolidated billing).

---

## ELI10

Imagine 20 different countries all joining the United Nations. Each country has its own government and laws, but the UN sets rules that ALL countries must follow — like "no country can build nuclear weapons" (even if their own laws allow it). The UN headquarters pays all the bills from one big bank account, and because they buy so much together, they get bulk discounts. The UN can also organize countries into regional alliances (like NATO or ASEAN) and apply special rules to each alliance.

---

## The Concept

### The Structure

```
┌──────────────────────────────────────────────────────────────────┐
│                    AWS ORGANIZATION                                │
│                    (United Nations)                                │
│                                                                    │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  ROOT (UN Charter)                                          │  │
│  │  SCP: FullAWSAccess (default)                               │  │
│  │                                                              │  │
│  │  ┌──────────────────────┐  ┌──────────────────────────┐    │  │
│  │  │  Management Account  │  │  OU: Production           │    │  │
│  │  │  (UN Headquarters)   │  │  (NATO Alliance)          │    │  │
│  │  │                      │  │  SCP: DenyDeleteVPC       │    │  │
│  │  │  - Pays all bills    │  │                            │    │  │
│  │  │  - Cannot be         │  │  ┌────────┐ ┌────────┐   │    │  │
│  │  │    restricted by SCP │  │  │Acct 111│ │Acct 222│   │    │  │
│  │  │  - Creates accounts  │  │  │(France)│ │(Germany│   │    │  │
│  │  │  - Manages SCPs      │  │  └────────┘ └────────┘   │    │  │
│  │  └──────────────────────┘  └──────────────────────────┘    │  │
│  │                                                              │  │
│  │  ┌──────────────────────────┐  ┌────────────────────────┐  │  │
│  │  │  OU: Development          │  │  OU: Sandbox            │  │  │
│  │  │  (ASEAN Alliance)         │  │  (Pacific Islands)      │  │  │
│  │  │  SCP: DenyProdRegions     │  │  SCP: SpendingLimit     │  │  │
│  │  │                            │  │                          │  │  │
│  │  │  ┌────────┐ ┌────────┐   │  │  ┌────────┐            │  │  │
│  │  │  │Acct 333│ │Acct 444│   │  │  │Acct 555│            │  │  │
│  │  │  │(Japan) │ │(Korea) │   │  │  │(Fiji)  │            │  │  │
│  │  │  └────────┘ └────────┘   │  │  └────────┘            │  │  │
│  │  └──────────────────────────┘  └────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

### Management Account = UN Headquarters

The management account (formerly "master account") is special:

- **Pays all bills** — consolidated billing for all member accounts
- **Cannot be restricted by SCPs** — headquarters is above the treaties
- **Creates/invites member accounts** — admits new countries to the UN
- **Best practice:** Use ONLY for billing and organization management. Don't run workloads here.

### Member Accounts = Individual Countries

Each account is an isolated environment with its own:
- IAM users, roles, policies
- Resources (EC2, S3, RDS, etc.)
- Root user (can be restricted by SCPs!)

### OUs = Regional Alliances

Organizational Units group accounts and can be nested (up to 5 levels deep):

```
Root
├── OU: Security         (Dedicated security accounts)
├── OU: Infrastructure   (Shared services — networking, DNS)
├── OU: Workloads
│   ├── OU: Production   (Prod accounts — strict SCPs)
│   └── OU: Development  (Dev accounts — relaxed SCPs)
├── OU: Sandbox          (Experimentation — spending limits)
└── OU: Suspended        (Accounts pending closure)
```

---

## SCPs = Treaties & Sanctions

**Service Control Policies** are permission GUARDRAILS. They define the maximum possible permissions for an account.

### Critical Rule: SCPs Don't GRANT — They RESTRICT

```
┌─────────────────────────────────────────────┐
│           WHAT A USER CAN DO                 │
│                                              │
│  ┌───────────────┐   ┌───────────────┐      │
│  │   IAM Policy   │   │     SCP       │      │
│  │   (Grants)     │ ∩ │  (Allows)     │ = Access
│  └───────────────┘   └───────────────┘      │
│                                              │
│  BOTH must allow the action for it to work.  │
│  SCP = maximum boundary.                     │
│  IAM Policy = actual permissions within that. │
└─────────────────────────────────────────────┘
```

Think of it as:
- **SCP** = "You're allowed to use highways, airports, and trains" (boundary)
- **IAM Policy** = "Here are your actual tickets for Highway 1 and Airport A" (permissions)
- Even with an IAM admin policy (`*:*`), if the SCP denies EC2, you can't use EC2.

### SCP Inheritance

```
Root ──── SCP: FullAWSAccess
  │
  OU: Production ──── SCP: DenyDeleteVPC, DenyLeaveOrg
  │                   (Production inherits Root SCP + its own)
  │
  Account 111 ──── SCP: DenyS3Delete
                   (Account inherits Root + OU SCPs + its own)

Effective permissions for Account 111:
  FullAWSAccess MINUS DenyDeleteVPC MINUS DenyLeaveOrg MINUS DenyS3Delete
```

**Key facts about SCPs:**
- Default: `FullAWSAccess` attached to root (allows everything — SCPs are deny by default without this)
- Can use allow-list or deny-list strategy
- **Deny-list strategy (recommended):** Keep FullAWSAccess, add explicit denies
- **Allow-list strategy:** Remove FullAWSAccess, only explicitly allow needed services
- SCPs DO affect the root user of member accounts
- SCPs do NOT affect the management account
- SCPs do NOT affect service-linked roles

### Common SCP Patterns

```json
// Deny leaving the organization
{
  "Effect": "Deny",
  "Action": "organizations:LeaveOrganization",
  "Resource": "*"
}

// Deny access to specific regions
{
  "Effect": "Deny",
  "Action": "*",
  "Resource": "*",
  "Condition": {
    "StringNotEquals": {
      "aws:RequestedRegion": ["ap-southeast-2", "us-east-1"]
    }
  }
}

// Deny disabling CloudTrail
{
  "Effect": "Deny",
  "Action": [
    "cloudtrail:StopLogging",
    "cloudtrail:DeleteTrail"
  ],
  "Resource": "*"
}
```

---

## Consolidated Billing = One Treasury

```
┌─────────────────────────────────────────────────┐
│         CONSOLIDATED BILLING                     │
│                                                   │
│  Account A: 3 TB S3 storage                      │
│  Account B: 4 TB S3 storage                      │
│  Account C: 3 TB S3 storage                      │
│  ─────────────────────────────                    │
│  Total: 10 TB → Gets volume discount             │
│  (Individual accounts wouldn't qualify)           │
│                                                   │
│  Reserved Instances & Savings Plans:              │
│  - Purchased in Account A                         │
│  - Shared across ALL accounts in the org          │
│  - Account B can use Account A's reservations     │
│  (Can disable RI/SP sharing if needed)            │
└─────────────────────────────────────────────────┘
```

Benefits:
- **Volume discounts** — combined usage hits higher tiers
- **RI/Savings Plan sharing** — buy in one account, use in all
- **Single invoice** — one bill for the entire organization
- **Free feature** — consolidated billing is available even without full Organizations features

---

## AWS RAM = Federal Resource Sharing

**Resource Access Manager** shares resources across accounts without copying:

```
Account A (Shared Services)              Account B (Application)
┌────────────────────────────┐          ┌────────────────────────┐
│                            │          │                        │
│  Transit Gateway ──────────┼─ RAM ──→ │  Uses Transit Gateway  │
│  Subnet ───────────────────┼─ RAM ──→ │  Launches EC2 in subnet│
│  Route 53 Resolver ────────┼─ RAM ──→ │  Uses DNS resolver     │
│  License Manager ──────────┼─ RAM ──→ │  Uses shared licenses  │
│                            │          │                        │
└────────────────────────────┘          └────────────────────────┘

The resource lives in Account A.
Account B uses it as if it were their own.
No duplication. One source of truth.
```

**Shareable resources:** VPC subnets, Transit Gateways, Route 53 Resolver rules, License Manager configs, Aurora DB clusters, CodeBuild projects, and more.

**Within an Organization:** Sharing is automatic (no invitation needed). Outside org: requires invitation acceptance.

---

## STS AssumeRole = Diplomatic Passport

Cross-account access without sharing credentials:

```
Account A (Developer)                    Account B (Production)
┌────────────────────┐                  ┌────────────────────┐
│                    │                  │                    │
│  IAM User: alice   │                  │  IAM Role:         │
│  Policy: Allow     │  AssumeRole      │  CrossAccountRole  │
│  sts:AssumeRole    │────────────────→ │                    │
│  on Role ARN       │                  │  Trust Policy:     │
│                    │←─ Temp Creds ────│  Account A allowed │
│                    │                  │                    │
│  Uses temp creds   │                  │  Permission Policy:│
│  to access B's     │                  │  s3:GetObject,     │
│  resources         │                  │  dynamodb:Query    │
└────────────────────┘                  └────────────────────┘
```

**Key fact:** The Role ARN is NOT a secret. It's like a public embassy address. Security comes from the Trust Policy (who is allowed to present their passport) and the Permission Policy (what they can do once inside).

**Two things must align:**
1. **Trust Policy** on the role — "Account A is allowed to assume this role"
2. **IAM Policy** on the user — "You are allowed to assume this specific role"

---

## Control Tower = Automated UN Setup

Control Tower is the automated setup for a multi-account environment:

```
┌──────────────────────────────────────────────────────────────┐
│                    CONTROL TOWER                              │
│              (Automated UN Setup Wizard)                       │
│                                                                │
│  Landing Zone = Pre-built organizational structure             │
│  ├── Management Account (auto-configured)                     │
│  ├── Log Archive Account (centralized logs)                   │
│  ├── Audit Account (security & compliance)                    │
│  └── OU structure (Security, Sandbox, etc.)                   │
│                                                                │
│  Guardrails = Pre-built SCPs + Config Rules                   │
│  ├── Preventive = SCPs (stop bad actions)                     │
│  ├── Detective = Config Rules (find violations)               │
│  └── Proactive = CloudFormation hooks (pre-deploy checks)     │
│                                                                │
│  Account Factory = Self-service account creation               │
│  (Developers request new accounts through a catalog)           │
└──────────────────────────────────────────────────────────────┘
```

Control Tower sits ON TOP of Organizations, SCPs, Config, CloudTrail, and SSO. It orchestrates all of them.

---

## Policy Types Beyond SCPs

Organizations supports multiple policy types:

| Policy Type | Purpose | Analogy |
|-------------|---------|---------|
| **SCP** | Permission guardrails | Treaties (restrict what you can do) |
| **Tag Policies** | Enforce tag standards | Naming conventions for roads/buildings |
| **Backup Policies** | Enforce backup rules | Disaster preparedness mandates |
| **AI Services Opt-Out** | Control AI data usage | Privacy regulations |

**Tag Policies example:** Force all EC2 instances to have a `CostCenter` tag with values from an approved list. Non-compliant resources get flagged (not blocked — tag policies are detective, not preventive).

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- Multi-account strategy — when and why to use Organizations
- SCP + IAM interaction (both must allow)
- Consolidated billing — RI sharing, volume discounts
- Cross-account access via STS AssumeRole
- RAM for sharing VPC subnets and Transit Gateways
- Control Tower for landing zone setup

### DVA-C02 (Developer)
- STS AssumeRole for cross-account access
- Temporary credentials flow
- Trust policies and permission policies
- Role ARN is not a secret — trust policy provides security
- How to configure cross-account Lambda access

### SOA-C02 (SysOps)
- SCP creation and inheritance
- OU hierarchy design
- Drift detection in Control Tower guardrails
- Account factory provisioning
- Tag policies for compliance
- Backup policies across accounts
- Organization Trail (CloudTrail across all accounts)
- Consolidated billing troubleshooting

---

## Key Numbers

| Item | Value |
|------|-------|
| Max accounts per organization | **Soft limit, varies (typically starts at a few dozen, can increase)** |
| Max OU nesting depth | **5 levels** (root + 5) |
| Max SCPs per account | **5** directly attached |
| Max SCP size | **5,120 characters** |
| Max OUs per root | **1,000** |
| Max roots per organization | **1** |
| Max policies per organization (SCP) | **Depends on limit** |
| RI sharing | **Enabled by default** (can disable per account) |
| STS temporary credentials default duration | **1 hour** (configurable 15 min to 12 hours for roles) |
| STS session max for IAM user assuming role | **12 hours** |
| Tag policy — tags per resource | Follows service-specific limits |
| Control Tower guardrail types | **3** (Preventive, Detective, Proactive) |

---

## Cheat Sheet

- **SCPs restrict, never grant** — they set the ceiling, IAM policies work within it
- **Both SCP AND IAM must allow** for access to work
- **Management account is IMMUNE to SCPs** — headquarters can't be restricted
- **SCPs DO affect root user** of member accounts (unlike the management account)
- **SCPs do NOT affect service-linked roles** — AWS needs these to function
- **FullAWSAccess SCP** = default on root. Remove it = deny everything (allow-list mode)
- **Deny-list strategy** (recommended): Keep FullAWSAccess, add explicit denies
- **Consolidated billing** = volume discounts + RI/Savings Plan sharing
- **RI sharing** = on by default, can be disabled per account
- **RAM** = share resources (subnets, TGW) across accounts without duplication
- **STS AssumeRole** = temporary credentials for cross-account access
- **Role ARN is NOT a secret** — trust policy is the real gatekeeper
- **Control Tower** = automated multi-account setup (landing zone + guardrails + account factory)
- **Control Tower guardrails:** Preventive (SCPs), Detective (Config Rules), Proactive (CFN hooks)
- **Tag policies** = enforce naming standards (detective, not preventive)
- **Moving an account between OUs** = immediately subject to new OU's SCPs
- **Organization Trail** = single CloudTrail for all accounts
- **Account closure** = 90-day suspension period before permanent deletion
- **One root per organization** — can't have multiple roots
- **OU nesting** = 5 levels deep max
