# AWS Config — Compliance Inspector

> **AWS Config is a building code inspector who continuously walks through every building (resource) in the country, checks if they follow the building codes (rules), takes photos (configuration snapshots), and can auto-fix violations (remediation).**

---

## ELI10

Imagine a building inspector who visits every building in the city every day. They check: "Does this building have a fire alarm? Are the exits marked? Is the roof strong enough?" Each building gets a report card: COMPLIANT or NON_COMPLIANT. If a building fails inspection, the inspector can either just report it or automatically send a repair crew to fix it. The inspector also keeps a complete history — they can show you what any building looked like on any day in the past.

---

## The Concept

### AWS Config — Continuous Compliance Monitoring

```
┌──────────────────────────────────────────────────────────────┐
│                       AWS CONFIG                              │
│                                                               │
│  ┌────────────┐     ┌────────────┐     ┌─────────────────┐  │
│  │Configuration│     │ Config     │     │ Compliance       │  │
│  │ Recorder   │────>│ Rules      │────>│ Dashboard        │  │
│  │ (Camera)   │     │ (Codes)    │     │ (Report Card)    │  │
│  └────────────┘     └────────────┘     └─────────────────┘  │
│       │                    │                     │            │
│       v                    v                     v            │
│  Records ALL          Evaluates each       COMPLIANT or      │
│  resource config      resource against     NON_COMPLIANT     │
│  changes              rules                per resource      │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                  REMEDIATION                            │  │
│  │  Non-compliant → Auto-fix via SSM Automation Runbook    │  │
│  │  Example: S3 bucket without encryption →                │  │
│  │           auto-enable encryption                        │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### Configuration Recorder — The Camera

```
┌──────────────────────────────────────────────────────────┐
│              CONFIGURATION RECORDER                        │
│                                                            │
│  What it does:                                             │
│  • Records configuration of AWS resources                  │
│  • Detects configuration CHANGES                           │
│  • Creates configuration ITEMS (snapshots)                 │
│  • Stores in Configuration HISTORY                         │
│  • Delivers to S3 bucket (configuration snapshots)         │
│                                                            │
│  Configuration Item:                                       │
│  ┌──────────────────────────────────────────────┐         │
│  │ Resource: s3-bucket/my-data-bucket            │         │
│  │ Type: AWS::S3::Bucket                         │         │
│  │ Region: ap-southeast-2                        │         │
│  │ Account: 123456789012                         │         │
│  │ Config captured at: 2026-03-11T10:30:00Z      │         │
│  │                                                │         │
│  │ Configuration:                                 │         │
│  │   Versioning: Enabled                          │         │
│  │   Encryption: AES256                           │         │
│  │   PublicAccess: Blocked                        │         │
│  │   Logging: Enabled                             │         │
│  │                                                │         │
│  │ Relationships:                                 │         │
│  │   → IAM Policy: bucket-access-policy           │         │
│  │   → CloudTrail: data-trail                     │         │
│  └──────────────────────────────────────────────┘         │
│                                                            │
│  You must ENABLE the recorder — it's not on by default!    │
│  Records to an S3 bucket + optional SNS notifications      │
└──────────────────────────────────────────────────────────┘
```

### Config Rules — The Building Codes

```
┌──────────────────────────────────────────────────────────┐
│                    CONFIG RULES                            │
│                                                            │
│  MANAGED RULES (AWS pre-built — 300+):                     │
│  ┌──────────────────────────────────────────────┐         │
│  │ s3-bucket-versioning-enabled                  │         │
│  │ s3-bucket-server-side-encryption-enabled      │         │
│  │ s3-bucket-public-read-prohibited              │         │
│  │ encrypted-volumes                             │         │
│  │ rds-instance-public-access-check              │         │
│  │ iam-user-mfa-enabled                          │         │
│  │ restricted-ssh (no 0.0.0.0/0 on port 22)     │         │
│  │ ec2-instance-no-public-ip                     │         │
│  │ lambda-function-settings-check                │         │
│  │ root-account-mfa-enabled                      │         │
│  └──────────────────────────────────────────────┘         │
│                                                            │
│  CUSTOM RULES:                                             │
│  ┌──────────────────────────────────────────────┐         │
│  │ Lambda-backed:                                │         │
│  │ • Write a Lambda function                     │         │
│  │ • Lambda evaluates resource configuration      │         │
│  │ • Returns COMPLIANT or NON_COMPLIANT           │         │
│  │                                                │         │
│  │ Guard-backed (CloudFormation Guard):            │         │
│  │ • Write Guard rules (policy-as-code DSL)       │         │
│  │ • No Lambda needed                             │         │
│  │ • Simpler for straightforward checks           │         │
│  └──────────────────────────────────────────────┘         │
│                                                            │
│  Trigger Types:                                            │
│  • Configuration change: evaluates when resource changes   │
│  • Periodic: evaluates on schedule (1hr, 3hr, 6hr,         │
│    12hr, 24hr)                                             │
│  • Hybrid: both triggers                                   │
└──────────────────────────────────────────────────────────┘
```

### Remediation — Auto-Fix Violations

```
┌──────────────────────────────────────────────────────────┐
│                   REMEDIATION                              │
│                                                            │
│  When a resource is NON_COMPLIANT:                         │
│                                                            │
│  Auto-Remediation:                                         │
│  ┌──────────────────────────────────────────────┐         │
│  │ Config Rule → Non-compliant detected →         │         │
│  │ SSM Automation Runbook → Fix the issue          │         │
│  │                                                │         │
│  │ Examples:                                      │         │
│  │ • S3 bucket not encrypted →                    │         │
│  │   Run AWS-EnableS3BucketEncryption              │         │
│  │ • Security Group allows 0.0.0.0/0 on 22 →      │         │
│  │   Run custom runbook to revoke the rule         │         │
│  │ • EBS volume not encrypted →                    │         │
│  │   Run snapshot → create encrypted volume        │         │
│  └──────────────────────────────────────────────┘         │
│                                                            │
│  Manual Remediation:                                       │
│  • Config detects non-compliance                           │
│  • Team receives notification (SNS/EventBridge)            │
│  • Team manually fixes the issue                           │
│                                                            │
│  Retry:                                                    │
│  • Auto-retry up to 5 times if remediation fails           │
│  • Max 5 retries with configurable delay                   │
└──────────────────────────────────────────────────────────┘
```

### Conformance Packs — Compliance Packages

```
┌──────────────────────────────────────────────────────────┐
│              CONFORMANCE PACKS                             │
│                                                            │
│  Pre-packaged groups of Config Rules + Remediation:        │
│                                                            │
│  ┌──────────────────────────────────────────────┐         │
│  │ AWS Best Practices Pack:                      │         │
│  │ • 30+ rules covering S3, IAM, EC2, RDS, etc.  │         │
│  │                                                │         │
│  │ PCI DSS Pack:                                  │         │
│  │ • Rules aligned to PCI compliance              │         │
│  │                                                │         │
│  │ HIPAA Pack:                                    │         │
│  │ • Rules for healthcare data compliance          │         │
│  │                                                │         │
│  │ CIS Benchmark Pack:                            │         │
│  │ • CIS AWS Foundations Benchmark rules           │         │
│  │                                                │         │
│  │ Custom Pack:                                   │         │
│  │ • Your own combination of rules                │         │
│  └──────────────────────────────────────────────┘         │
│                                                            │
│  Deploy across entire Organization via                     │
│  Organization Conformance Packs                            │
└──────────────────────────────────────────────────────────┘
```

### Aggregator — Multi-Account Dashboard

```
┌──────────────────────────────────────────────────────────┐
│              CONFIG AGGREGATOR                             │
│                                                            │
│  Aggregate compliance data across:                         │
│  • Multiple AWS accounts                                   │
│  • Multiple regions                                        │
│  • Entire AWS Organization                                 │
│                                                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐               │
│  │Account A │  │Account B │  │Account C │               │
│  │ Config   │  │ Config   │  │ Config   │               │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘               │
│       │              │              │                      │
│       └──────────────┼──────────────┘                      │
│                      v                                     │
│              ┌──────────────┐                              │
│              │  Aggregator   │                              │
│              │  (Central     │                              │
│              │   Dashboard)  │                              │
│              └──────────────┘                              │
│                                                            │
│  View: total compliant/non-compliant across ALL accounts   │
│  Query: "Which accounts have public S3 buckets?"           │
└──────────────────────────────────────────────────────────┘
```

### AWS Config vs CloudTrail

```
┌────────────────────────┬─────────────────────────────┐
│      AWS Config         │       CloudTrail             │
├────────────────────────┼─────────────────────────────┤
│ WHAT a resource        │ WHO did WHAT and WHEN        │
│ looks like             │                               │
│                         │                               │
│ Configuration STATE    │ API ACTIVITY log              │
│ over time              │                               │
│                         │                               │
│ "Is this S3 bucket     │ "Who changed this S3         │
│  encrypted?"           │  bucket's settings?"         │
│                         │                               │
│ Compliance checking    │ Security auditing             │
│ Resource inventory     │ Forensics                     │
│ Change tracking        │ API call history              │
│                         │                               │
│ Evaluates against      │ Logs every API call           │
│ rules                  │ (management & data events)    │
│                         │                               │
│ Config Items           │ Event records                 │
│ (resource snapshots)   │ (API call details)            │
└────────────────────────┴─────────────────────────────┘

Together: Config tells you WHAT changed.
CloudTrail tells you WHO changed it and WHEN.
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- **Config rules** for compliance (managed rules for common checks)
- **Auto-remediation** via SSM Automation
- **Multi-account** compliance with Aggregator and Organization rules
- **Config vs CloudTrail** — state vs activity
- **Conformance Packs** for framework compliance (PCI, HIPAA, CIS)

### DVA-C02 (Developer)
- **Custom Config rules** — Lambda-backed evaluation functions
- **Trigger types** — configuration change vs periodic
- **Resource types** supported by Config
- **Query** — Advanced Query to find resources by configuration

### SOA-C02 (SysOps)
- **Configuration Recorder** setup — S3 bucket, IAM role, resource types
- **Remediation** configuration — SSM Automation runbooks, retry settings
- **Compliance reporting** — compliant/non-compliant counts, timeline
- **Aggregator** — multi-account, multi-region compliance view
- **Troubleshooting** — recorder not recording (IAM role, S3 bucket permissions)
- **Config + SSM** — Config detects, SSM Automation fixes

---

## Key Numbers

| Fact | Value |
|------|-------|
| AWS Managed Rules | 300+ |
| Max Config rules per account | 400 (soft limit) |
| Configuration history retention | 7 years |
| Periodic rule evaluation | 1hr, 3hr, 6hr, 12hr, 24hr |
| Remediation retries | Up to 5 |
| Conformance packs per account | 50 |
| Aggregator source accounts | Unlimited (Organization) |
| Config recorder must-have | S3 bucket + IAM role |
| Advanced Query | SQL-like syntax |
| Snapshot delivery | S3 bucket (configurable frequency) |

---

## Cheat Sheet

- **AWS Config = continuous compliance monitoring.** Records resource configurations, evaluates rules, reports compliance.
- **Configuration Recorder** = must be enabled. Records to S3 bucket. Tracks all resource changes.
- **Config Rules** = building codes. 300+ managed rules + custom (Lambda or Guard-backed).
- **Managed rules** = AWS pre-built. `s3-bucket-versioning-enabled`, `encrypted-volumes`, `restricted-ssh`, etc.
- **Custom rules** = Lambda function evaluates, returns COMPLIANT or NON_COMPLIANT.
- **Triggers:** configuration change (reactive) or periodic (scheduled).
- **Remediation** = auto-fix via SSM Automation runbooks. Up to 5 retries.
- **Conformance Packs** = grouped rules for compliance frameworks (PCI, HIPAA, CIS).
- **Aggregator** = multi-account, multi-region compliance dashboard.
- **Config vs CloudTrail:** Config = WHAT (state). CloudTrail = WHO/WHEN (activity).
- **Advanced Query** = SQL-like queries across all resources. "SELECT * WHERE resourceType = 'AWS::S3::Bucket'".
- **Organization rules** = deploy Config rules across all accounts in an Organization.
- **Configuration timeline** = visual history of how a resource's config changed over time.
- **NOT a preventive control.** Config DETECTS after the fact. Use SCPs/IAM for prevention.
