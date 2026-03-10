# WAF & Shield — Border Firewall & DDoS Defense

> **WAF is the border security checkpoint that inspects every person entering. Shield is the army defense system that protects the entire border from mass attacks. Firewall Manager is the central security command managing checkpoints across all border crossings.**

---

## ELI10

Imagine the country has border crossings where tourists enter. At each crossing, there's a security checkpoint (WAF) with guards who check passports, search bags, and look for suspicious items. They have rules: "Block anyone from this banned list," "Only allow 100 people per hour from any single country," and "Check for hidden weapons (SQL injection)." Sometimes, an enemy sends millions of fake tourists at once to overwhelm the border (DDoS attack). That's when the army (Shield) activates — Shield Standard is the regular patrol that's always on duty. Shield Advanced is the special forces with helicopters, real-time radar, and a 24/7 war room.

---

## The Concept

### WAF (Web Application Firewall) — The Border Checkpoint

```
┌──────────────────────────────────────────────────────────┐
│                         WAF                                │
│                                                            │
│  Internet Traffic                                          │
│       │                                                    │
│       v                                                    │
│  ┌─────────────────────────────────────┐                  │
│  │         WEB ACL (Access Control List)│                  │
│  │                                      │                  │
│  │  Rule 1: Block IPs from ban list     │──> BLOCK         │
│  │  Rule 2: Rate limit (2000 req/5min)  │──> BLOCK if over │
│  │  Rule 3: Block SQL injection         │──> BLOCK         │
│  │  Rule 4: Block XSS patterns          │──> BLOCK         │
│  │  Rule 5: Geo-block (allow AU only)   │──> BLOCK others  │
│  │  Rule 6: AWS Managed Bot Control     │──> Challenge     │
│  │                                      │                  │
│  │  Default Action: ALLOW               │──> ALLOW         │
│  └─────────────────────────────────────┘                  │
│       │                                                    │
│       v                                                    │
│  ┌──────────┐  ┌──────┐  ┌───────────┐  ┌──────────┐    │
│  │CloudFront│  │ ALB  │  │API Gateway│  │ AppSync  │    │
│  └──────────┘  └──────┘  └───────────┘  └──────────┘    │
│                                                            │
│  WAF attaches to these 4 services (NOT EC2, NOT NLB)      │
└──────────────────────────────────────────────────────────┘
```

### WAF Rule Types

| Rule Type | Analogy | What It Does |
|-----------|---------|-------------|
| **IP Set** | Banned/allowed passport list | Block or allow specific IP addresses/ranges (CIDR) |
| **Rate-based** | Crowd control | Block IPs exceeding N requests per 5-minute window |
| **SQL Injection** | Contraband scanner | Detect SQL injection patterns in requests |
| **XSS** | Poison detector | Detect cross-site scripting patterns |
| **Geo-match** | Country restriction | Allow/block by geographic location |
| **Size constraint** | Baggage limit | Block requests exceeding size limits |
| **Regex pattern** | Keyword scanner | Match custom patterns in URI, headers, body |
| **Label** | Stamp a passport | Tag requests for downstream rule processing |

### Managed Rule Groups

```
┌────────────────────────────────────────────────────────┐
│              MANAGED RULE GROUPS                         │
│                                                          │
│  AWS Managed Rules (free with WAF):                      │
│  • AWSManagedRulesCommonRuleSet (core protections)       │
│  • AWSManagedRulesSQLiRuleSet (SQL injection)            │
│  • AWSManagedRulesKnownBadInputsRuleSet                  │
│  • AWSManagedRulesLinuxRuleSet                            │
│  • AWSManagedRulesAmazonIpReputationList                 │
│  • AWSManagedRulesBotControlRuleSet ($10/mo extra)       │
│  • AWSManagedRulesATPRuleSet (Account Takeover Prev.)    │
│                                                          │
│  AWS Marketplace Rules:                                   │
│  • Third-party vendors (F5, Fortinet, Imperva, etc.)     │
│  • Subscription-based                                     │
│                                                          │
│  Custom Rules:                                            │
│  • Write your own conditions and actions                  │
│  • Combine with labels for complex logic                  │
└────────────────────────────────────────────────────────┘
```

### Rule Actions

```
ALLOW  → Let the request through
BLOCK  → Reject with 403 Forbidden
COUNT  → Log the match but don't block (testing mode)
CAPTCHA → Challenge with CAPTCHA puzzle
Challenge → Silent browser challenge (bot detection)
```

### Shield — The Army Defense System

```
┌──────────────────────────────────────────────────────────┐
│                        SHIELD                             │
│                                                           │
│  SHIELD STANDARD (Free — Always On)                       │
│  ┌──────────────────────────────────────────────┐        │
│  │ • Automatic DDoS protection                   │        │
│  │ • Protects against L3/L4 attacks              │        │
│  │   (SYN floods, UDP reflection, etc.)          │        │
│  │ • Applied to ALL AWS accounts automatically   │        │
│  │ • No signup needed                            │        │
│  └──────────────────────────────────────────────┘        │
│                                                           │
│  SHIELD ADVANCED ($3,000/month — Enterprise Protection)   │
│  ┌──────────────────────────────────────────────┐        │
│  │ • Everything in Standard PLUS:                │        │
│  │ • L7 (application layer) DDoS protection      │        │
│  │ • 24/7 DDoS Response Team (DRT/SRT) access    │        │
│  │ • Cost protection (AWS credits for scaling     │        │
│  │   costs caused by DDoS attacks)               │        │
│  │ • Real-time metrics and attack diagnostics     │        │
│  │ • Automatic application-layer mitigations      │        │
│  │ • WAF integration (free WAF for Shield-        │        │
│  │   protected resources)                         │        │
│  │ • Health-based detection                       │        │
│  │ • Global Threat Environment dashboard          │        │
│  │                                                │        │
│  │ Protects:                                      │        │
│  │ • CloudFront, Route 53, Global Accelerator     │        │
│  │ • ALB, ELB (Classic), Elastic IP               │        │
│  └──────────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────────┘
```

### AWS Firewall Manager — Central Command

```
┌──────────────────────────────────────────────────────────┐
│              FIREWALL MANAGER                              │
│     (Requires AWS Organizations)                           │
│                                                            │
│  Centrally manage across ALL accounts:                     │
│  • WAF rules                                               │
│  • Shield Advanced protections                             │
│  • Security Groups                                         │
│  • Network Firewall policies                               │
│  • Route 53 Resolver DNS Firewall                          │
│                                                            │
│  Benefits:                                                 │
│  • Auto-apply WAF rules to new resources                   │
│  • Compliance: ensure all ALBs have WAF attached           │
│  • Single pane of glass for security policies              │
│  • Identify non-compliant resources                        │
│                                                            │
│  Cost: ~$100/month per policy per region                    │
└──────────────────────────────────────────────────────────┘
```

### WAF vs Security Groups vs NACLs

```
┌─────────────┬─────────────────┬──────────────────┬──────────────┐
│              │ WAF              │ Security Group    │ NACL          │
├─────────────┼─────────────────┼──────────────────┼──────────────┤
│ Layer       │ L7 (HTTP/HTTPS) │ L3/L4 (IP/port)  │ L3/L4        │
│ Inspects    │ Request content │ IP + port          │ IP + port    │
│ Attaches to │ CF, ALB, APIGW  │ EC2, Lambda, RDS  │ Subnet       │
│ Stateful?   │ N/A             │ Yes                │ No (stateless)│
│ SQL/XSS?    │ Yes             │ No                 │ No           │
│ Rate limit? │ Yes             │ No                 │ No           │
│ Geo block?  │ Yes             │ No                 │ No           │
│ Default     │ Allow or Block  │ Deny all inbound   │ Allow all    │
└─────────────┴─────────────────┴──────────────────┴──────────────┘
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- **WAF placement** — attaches to CloudFront, ALB, API Gateway, AppSync (NOT NLB, NOT EC2)
- **Shield Standard vs Advanced** — free L3/L4 vs paid L7 + DRT + cost protection
- **Rate-based rules** for brute force and DDoS mitigation
- **Firewall Manager** for multi-account WAF policy management

### DVA-C02 (Developer)
- **WAF rule types** — SQL injection, XSS, rate-based, geo-match
- **Web ACL association** with API Gateway and CloudFront
- **Count action** for testing rules before blocking
- **Custom request/response** — add headers, return custom error pages

### SOA-C02 (SysOps)
- **Firewall Manager** — centralized policy management across accounts
- **Shield Advanced metrics** — attack detection, real-time dashboards
- **WAF logging** — to S3, CloudWatch Logs, or Kinesis Data Firehose
- **Compliance** — ensure all ALBs/CloudFront distributions have WAF attached
- **Cost protection** with Shield Advanced

---

## Key Numbers

| Fact | Value |
|------|-------|
| Shield Standard cost | Free (always on) |
| Shield Advanced cost | $3,000/month (1-year commitment) |
| WAF cost | $5/Web ACL/month + $1/rule/month + $0.60/million requests |
| Max rules per Web ACL | 1,500 WCU (Web ACL Capacity Units) |
| Rate-based rule window | 5 minutes |
| Rate-based rule minimum rate | 100 requests per 5 minutes |
| WAF attaches to | CloudFront, ALB, API Gateway, AppSync |
| Shield protects | CloudFront, Route 53, Global Accelerator, ALB, ELB, Elastic IP |
| Firewall Manager cost | ~$100/policy/region/month |
| WAF logging destinations | S3, CloudWatch Logs, Kinesis Firehose |
| Bot Control cost | $10/month + $1/million requests |

---

## Cheat Sheet

- **WAF = Layer 7 firewall.** Inspects HTTP/HTTPS request content (headers, body, URI, IP).
- **WAF attaches to CloudFront, ALB, API Gateway, AppSync.** NOT NLB, NOT EC2 directly.
- **Rate-based rules** = block IPs exceeding N requests per 5-minute window. Use for brute force + DDoS.
- **Managed rules** = AWS-maintained rulesets for common threats (SQLi, XSS, bots, bad IPs). Free with WAF.
- **Bot Control** = managed rule group for bot detection. Uses CAPTCHA and silent challenges.
- **COUNT action** = test rules without blocking. See what WOULD be blocked. Then switch to BLOCK.
- **Shield Standard = free, always on.** Protects against L3/L4 DDoS (SYN floods, UDP reflection).
- **Shield Advanced = $3,000/month.** L7 DDoS protection, 24/7 DRT, cost protection, free WAF.
- **Cost protection** = AWS credits for scaling costs during DDoS attacks (Shield Advanced only).
- **Firewall Manager** = centralized security management across AWS Organizations accounts.
- **WAF vs Security Groups:** WAF inspects content (SQL, XSS). SGs filter by IP/port. Different layers.
- **WAF logging** → S3 (analysis), CloudWatch (real-time monitoring), Firehose (streaming).
- **IP set rules** = block/allow specific CIDR ranges. Good for known bad actors or trusted networks.
- **Geo-match** = block/allow by country. Useful for compliance (serve only specific regions).
