# Parameter Store & Secret Vault — Config & Credential Management

> **In the Country:** Parameter Store is the **public notice board with some locked drawers** — anyone with clearance can read the posted configs, and sensitive stuff goes in locked drawers (SecureString). The Secret Vault (AWS Secrets Manager) is the **top-secret vault with armed guards** — encrypted, auto-rotating credentials with 24/7 surveillance.

---

## ELI10

Imagine your school has two places to keep information. The **bulletin board** in the hallway has class schedules, lunch menus, and announcements — anyone can read them. Some notices are in locked glass cases (you need a key to read those). Then there's the **principal's safe** in the office — it has the master keys to every room, the alarm codes, and the Wi-Fi password. The safe automatically changes the alarm code every month so nobody can memorize it. The bulletin board is Parameter Store. The principal's safe is the Secret Vault.

---

## The Concept

### Parameter Store — The Notice Board

```
NOTICE BOARD (Parameter Store)
│
├── /prod/app/feature-flag     = "true"          (String — posted openly)
├── /prod/app/max-retries      = "3"             (String — posted openly)
├── /prod/db/connection-string  = "host=..."      (String — posted openly)
├── /prod/db/password           = "enc(Ax7f...)"  (SecureString — locked drawer, KMS key needed)
│
├── /dev/app/feature-flag      = "false"
├── /dev/db/password           = "enc(Bk9g...)"
│
└── Hierarchical paths = organized by environment/service/key
```

**Two Tiers:**

| | Standard | Advanced |
|-|----------|----------|
| Cost | Free | $0.05/param/month |
| Max params | 10,000 | 100,000 |
| Max value size | 4 KB | 8 KB |
| Parameter policies | No | Yes (expiration, notifications) |
| Throughput | 40 TPS default (up to 1,000) | 1,000 TPS default (up to 10,000) |

**Parameter Types:**
- **String** — Plain text (`"hello"`)
- **StringList** — Comma-separated (`"a,b,c"`)
- **SecureString** — Encrypted with KMS (the locked drawer)

### Secret Vault (AWS Secrets Manager) — The Top-Secret Safe

```
TOP-SECRET VAULT
│
├── prod/db/master-credentials
│   ├── Current version: { username: "admin", password: "Xk9$mP2..." }
│   ├── Previous version: { username: "admin", password: "old-pass..." }
│   └── Auto-rotation: Every 30 days via Lambda
│
├── prod/api/third-party-key
│   └── { api_key: "sk-live-..." }
│
└── Cross-account sharing via resource policy
```

**Key features:**
- **Auto-rotation** via Lambda function (built-in for RDS, Redshift, DocumentDB)
- **Versioning** — current, previous, and pending stages
- **Cross-account access** via resource policies
- **$0.40/secret/month** + $0.05 per 10,000 API calls
- **Replication** across regions for DR

### When to Use Which

```
DECISION TREE:
│
├── Need auto-rotation of credentials?
│   └── YES → Secret Vault (Secrets Manager)
│
├── Storing DB passwords, API keys, OAuth tokens?
│   └── YES → Secret Vault (Secrets Manager)
│
├── Storing config values, feature flags, URLs?
│   └── YES → Parameter Store (Standard tier, free)
│
├── Storing encrypted config but don't need rotation?
│   └── YES → Parameter Store SecureString
│
├── Need > 10,000 parameters?
│   └── YES → Parameter Store Advanced tier
│
└── Budget-conscious, simple config?
    └── YES → Parameter Store Standard (free)
```

---

## Architecture — How They Connect

```
┌──────────────────────────────────────────────┐
│              Your Application                 │
│                                               │
│  Lambda / EC2 / ECS / CloudFormation          │
│         │                    │                │
│    GetParameter()     GetSecretValue()        │
│         │                    │                │
│         ▼                    ▼                │
│  ┌─────────────┐    ┌──────────────────┐     │
│  │  Parameter   │    │  Secret Vault    │     │
│  │  Store       │    │  (Secrets Mgr)   │     │
│  │             │    │                  │     │
│  │  String     │    │  Auto-rotation   │     │
│  │  StringList │    │  via Lambda      │     │
│  │  SecureStr  │──► │                  │     │
│  └──────┬──────┘    └────────┬─────────┘     │
│         │                    │                │
│         └────────┬───────────┘                │
│                  │                            │
│                  ▼                            │
│              KMS (encryption)                 │
└──────────────────────────────────────────────┘
```

**Integration points:**
- **CloudFormation** — `{{resolve:ssm:param-name}}` or `{{resolve:secretsmanager:secret-name}}`
- **Lambda** — SDK call or environment variable from Parameter Store
- **ECS** — Task definition references both services
- **CodePipeline** — Inject build-time config from either service

---

## Exam Angle

| Exam | Focus |
|------|-------|
| **SAA-C03** | When to use Parameter Store vs Secret Vault, encryption at rest, cross-account access patterns |
| **DVA-C02** | SDK integration, caching (Lambda extension), CloudFormation dynamic references, rotation Lambda |
| **SOA-C02** | Parameter policies (expiration alerts), rotation monitoring, cross-account sharing, compliance |

---

## Key Numbers

| Metric | Value |
|--------|-------|
| Parameter Store Standard max params | 10,000 |
| Parameter Store Advanced max params | 100,000 |
| Parameter Store max value size (Standard) | 4 KB |
| Parameter Store max value size (Advanced) | 8 KB |
| Secret Vault cost | $0.40/secret/month |
| Secret Vault max size | 64 KB |
| Secret Vault rotation | Built-in for RDS, Redshift, DocumentDB |
| Parameter Store SecureString | Uses KMS (aws/ssm default key) |
| Default throughput (Standard) | 40 TPS |
| Default throughput (Advanced) | 1,000 TPS |
| Secret Vault replication | Cross-region supported |

---

## Cheat Sheet

- **Free config storage** → Parameter Store Standard tier
- **Need rotation** → Secret Vault, always
- **SecureString** uses KMS — you choose the key (default or custom CMK)
- **Hierarchical paths** (`/prod/db/password`) = organized, IAM-filterable
- **CloudFormation resolve** = `{{resolve:ssm:name:version}}` or `{{resolve:secretsmanager:arn}}`
- **Lambda caching** = AWS Parameters and Config Lambda Extension (reduces API calls)
- **Rotation Lambda** = built-in templates for RDS/Redshift/DocumentDB, custom for anything else
- **Cross-account** = Secret Vault uses resource policies; Parameter Store uses RAM or IAM
- **Version stages** = AWSCURRENT (latest), AWSPREVIOUS (last rotation)
- **Parameter policies** (Advanced only) = expiration date, notification before expiry
