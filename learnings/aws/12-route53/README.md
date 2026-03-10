# Route 53 — The Ministry of Foreign Affairs

> **In the AWS Country, Route 53 is the Ministry of Foreign Affairs.** It manages how the outside world finds your services. Every hosted zone is an embassy, every DNS record is a contact card, and routing policies determine how visitors are directed to the right destination.

---

## ELI10

Imagine you're calling a big company but you only know their name, not their phone number. So you call the Ministry of Foreign Affairs and say "I need to reach Example Corp." The ministry looks up the name in their registry and gives you the phone number (IP address). Sometimes they give you the nearest office's number, sometimes the healthiest branch, sometimes they split your call between two offices. That's Route 53 — it translates names into addresses and decides which address to give you.

---

## The Concept

### Why "Route 53"?

DNS operates on port 53. That's the whole joke. Route + 53 = DNS routing service.

### Hosted Zones: The Embassies

A hosted zone is a container for DNS records for a domain.

```
┌──────────────────────────────────────────────────────────┐
│                PUBLIC HOSTED ZONE                         │
│                                                          │
│  Domain: example.com                                     │
│  Accessible from: the entire internet                    │
│                                                          │
│  Records:                                                │
│  ├── example.com        A      → 54.1.2.3               │
│  ├── www.example.com    CNAME  → example.com             │
│  ├── api.example.com    A      → ALB DNS name (Alias)    │
│  └── mail.example.com   MX     → 10 mail.example.com    │
│                                                          │
│  Cost: $0.50/month per hosted zone                       │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│               PRIVATE HOSTED ZONE                         │
│                                                          │
│  Domain: internal.mycompany.com                          │
│  Accessible from: associated VPCs ONLY                   │
│                                                          │
│  Records:                                                │
│  ├── db.internal.mycompany.com    A → 10.0.1.50         │
│  ├── cache.internal.mycompany.com A → 10.0.2.100        │
│  └── api.internal.mycompany.com   A → 10.0.3.25         │
│                                                          │
│  Associated VPCs: vpc-abc123, vpc-def456                 │
│  Can associate VPCs from DIFFERENT accounts              │
└──────────────────────────────────────────────────────────┘
```

---

### DNS Record Types

| Record | What It Maps | Example | Notes |
|---|---|---|---|
| **A** | Name → IPv4 | `example.com → 54.1.2.3` | Most common |
| **AAAA** | Name → IPv6 | `example.com → 2600:1f18::1` | IPv6 version of A |
| **CNAME** | Name → another name | `www.example.com → example.com` | **Cannot be at zone apex!** |
| **MX** | Name → mail server | `example.com → 10 mail.example.com` | Priority + mail server |
| **NS** | Name → name servers | `example.com → ns-1.awsdns-01.com` | Delegation |
| **TXT** | Name → text | `example.com → "v=spf1..."` | Email validation, verification |
| **SOA** | Zone authority info | Auto-created | Start of Authority |
| **SRV** | Service locator | `_sip._tcp.example.com → ...` | Service discovery |
| **CAA** | Certificate authority | `example.com → 0 issue "amazon.com"` | Restrict who can issue SSL certs |

### CNAME vs Alias — The Exam's Favorite Trick

```
CNAME:
  www.example.com → app.example.com
  ✓ Points name to another name
  ✗ CANNOT use at zone apex (example.com)
  ✗ Charged for DNS queries
  ✗ Not AWS-specific

ALIAS (AWS-specific):
  example.com → d111111.cloudfront.net
  ✓ Points name to AWS resource
  ✓ CAN use at zone apex (example.com) ← EXAM FAVORITE
  ✓ FREE for queries to AWS resources
  ✓ Native health check integration
  ✓ Automatically resolves to IP
```

**Alias targets (what Alias can point to):**
- CloudFront distributions
- ELB (ALB, NLB, CLB)
- API Gateway
- S3 website endpoint
- VPC Interface Endpoint
- Another Route 53 record in the same hosted zone
- Elastic Beanstalk environment
- Global Accelerator

**Alias CANNOT point to:** EC2 instance DNS name, RDS instance DNS name

**Exam rule:** If the question says "zone apex" or "naked domain" (example.com without www), the answer is **Alias**, not CNAME.

---

### Routing Policies

This is the heart of Route 53 on every exam. Seven policies, each for a different use case.

#### 1. Simple Routing — One Answer

```
example.com → 54.1.2.3
(or multiple values: 54.1.2.3, 54.4.5.6, 54.7.8.9 → client picks randomly)
```
- No health checks
- If multiple values, client receives ALL and picks one randomly
- Use case: single resource, basic setup

#### 2. Weighted Routing — Split by Percentage

```
example.com:
  Record 1 (weight 70) → 54.1.2.3   (70% of responses)
  Record 2 (weight 20) → 54.4.5.6   (20%)
  Record 3 (weight 10) → 54.7.8.9   (10%)
```
- Supports health checks (skip unhealthy targets)
- Weight 0 = no traffic (but still resolves if all others are 0)
- Use case: gradual migration, A/B testing, blue/green deployment

#### 3. Latency-Based Routing — Fastest Region

```
example.com:
  us-east-1 → 54.1.2.3    (if user is closest to US East)
  eu-west-1 → 52.4.5.6    (if user is closest to EU)
  ap-southeast-2 → 13.7.8.9 (if user is closest to Sydney)
```
- Based on latency between user and AWS region (not geographic distance)
- Supports health checks + failover
- Use case: multi-region applications

#### 4. Failover Routing — Primary/Secondary

```
example.com:
  PRIMARY   → 54.1.2.3    (health check: passing)
  SECONDARY → 54.4.5.6    (only if primary fails)
```
- Active-passive setup
- MUST use health checks on primary
- If primary health check fails → all traffic goes to secondary
- Use case: disaster recovery, active-passive

#### 5. Geolocation Routing — By User's Country

```
example.com:
  Users in Australia  → 13.7.8.9     (Sydney server)
  Users in Europe     → 52.4.5.6     (London server)
  Users in USA        → 54.1.2.3     (US server)
  Default             → 54.1.2.3     (everyone else)
```
- Based on user's geographic location (continent, country, or US state)
- MUST set a default record (catch-all for unknown locations)
- Use case: content localization, compliance (data sovereignty), restrict access
- **Not the same as latency-based** — geolocation is political boundaries, latency is network speed

#### 6. Geoproximity Routing — By Distance + Bias

```
example.com:
  us-east-1 (bias: +25)  → more traffic pulled toward US East
  eu-west-1 (bias: 0)    → normal coverage area
  ap-southeast-2 (bias: -10) → smaller coverage area
```
- Routes based on geographic distance between user and resource
- **Bias** expands (+) or shrinks (-) the geographic area of a resource
- Requires Route 53 **Traffic Flow** (visual editor)
- Use case: fine-tuned geographic routing, shifting traffic between regions

#### 7. Multi-Value Answer Routing — Multiple Healthy IPs

```
example.com:
  Record 1 → 54.1.2.3    (health check: passing) ✓
  Record 2 → 54.4.5.6    (health check: failing) ✗
  Record 3 → 54.7.8.9    (health check: passing) ✓

Response: [54.1.2.3, 54.7.8.9]  (only healthy records)
```
- Returns up to 8 healthy records
- Client picks one randomly
- NOT a substitute for a load balancer (client-side selection)
- Use case: simple availability improvement without a load balancer

### Routing Policy Selection — Quick Decision Table

| Requirement | Policy |
|---|---|
| Single resource, basic | Simple |
| Split traffic by percentage | Weighted |
| Lowest latency to user | Latency |
| Active-passive DR | Failover |
| Route by user's country | Geolocation |
| Route by distance + shift traffic | Geoproximity |
| Return multiple healthy IPs | Multi-Value |

---

### Health Checks: Is the Destination Alive?

Route 53 health checkers run from **15+ global locations**.

```
┌──────────────────────────────────────────────────────────┐
│                    HEALTH CHECK TYPES                      │
│                                                          │
│  1. ENDPOINT CHECK                                       │
│     Monitor an IP or domain                              │
│     Protocol: HTTP, HTTPS, TCP                           │
│     Interval: 30s (default) or 10s (fast, extra cost)    │
│     Threshold: 3 consecutive (default)                   │
│     Can check response body (first 5,120 bytes)          │
│                                                          │
│  2. CALCULATED CHECK                                     │
│     Combines multiple health checks                      │
│     Logic: AND, OR, or X of Y                           │
│     Up to 256 child health checks                        │
│                                                          │
│  3. CLOUDWATCH ALARM CHECK                               │
│     Health based on CloudWatch alarm state                │
│     Use case: monitor private resources                  │
│     (health checkers can't reach private IPs)            │
└──────────────────────────────────────────────────────────┘
```

**Key facts:**
- Health checkers are OUTSIDE your VPC — they check PUBLIC endpoints
- For private resources: use CloudWatch Alarm health check
- Allow Route 53 health checker IPs in your security group
- Health check + routing policy = automatic DNS failover

---

### DNSSEC (DNS Security)

- Digitally signs DNS records to prevent spoofing (DNS cache poisoning)
- Route 53 supports DNSSEC for domain registration and DNS signing
- KMS Customer Managed Key (CMK) in us-east-1 required for signing
- Protects against man-in-the-middle DNS attacks

---

### Route 53 Resolver: Hybrid DNS

For organizations with on-premises data centers AND AWS:

```
┌──────────────────┐         ┌──────────────────┐
│   ON-PREMISES    │         │       VPC         │
│   DNS Server     │◄───────▶│  Route 53         │
│   (10.0.0.2)     │         │  Resolver         │
│                  │         │                   │
│  Query: ec2.aws  │────────▶│  Inbound Endpoint │
│  (forward to AWS)│         │  (on-prem → AWS)  │
│                  │         │                   │
│  Query: on-prem  │◄────────│  Outbound Endpoint│
│  (forward to     │         │  (AWS → on-prem)  │
│   on-premises)   │         │                   │
└──────────────────┘         └──────────────────┘
```

- **Inbound Endpoint:** On-premises DNS forwards queries to AWS
- **Outbound Endpoint:** Route 53 forwards queries to on-premises DNS
- **Resolver Rules:** Define which domains forward where

---

### Domain Registration

Route 53 can register domains (but you can also use external registrars).

- Register directly: `.com`, `.org`, `.net`, hundreds of TLDs
- Transfer: move existing domain to Route 53 (unlock at current registrar, get auth code)
- Auto-renew available
- Domain lock to prevent unauthorized transfer

---

## Architecture Diagram: Multi-Region with Failover

```
                    Users Worldwide
                          │
                   ┌──────┴──────┐
                   │  Route 53   │
                   │             │
                   │ Failover    │
                   │ Routing     │
                   └──┬──────┬──┘
                      │      │
            Health ✓  │      │  Health ✗ (failover)
                      │      │
              ┌───────┴──┐ ┌─┴──────────┐
              │us-east-1 │ │eu-west-1   │
              │(PRIMARY) │ │(SECONDARY) │
              │          │ │            │
              │┌────────┐│ │┌──────────┐│
              ││  ALB   ││ ││  ALB     ││
              │└───┬────┘│ │└────┬─────┘│
              │    │     │ │     │      │
              │┌───┴────┐│ │┌────┴─────┐│
              ││  ASG   ││ ││  ASG     ││
              │└────────┘│ │└──────────┘│
              │          │ │            │
              │┌────────┐│ │┌──────────┐│
              ││  RDS   ││ ││  RDS     ││
              ││ Primary││ ││ Read     ││
              │└────────┘│ │└──────────┘│
              └──────────┘ └────────────┘
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- Alias vs CNAME (zone apex = Alias, always)
- Routing policy selection (weighted, latency, failover, geolocation)
- Failover routing + health checks for DR
- Latency-based routing for multi-region
- Geolocation vs Geoproximity (political boundaries vs distance)
- Private hosted zones for internal DNS
- Health check types (endpoint, calculated, CloudWatch)

### DVA-C02 (Developer)
- Alias record targets (which AWS resources are supported)
- Simple routing with multiple values
- Weighted routing for canary deployments
- Health check configuration for app endpoints
- TTL management and its impact on DNS caching

### SOA-C02 (SysOps)
- Health check troubleshooting (security groups blocking health checkers)
- DNSSEC configuration
- Resolver (hybrid DNS with on-premises)
- Domain transfer process
- Route 53 logging (query logging to CloudWatch Logs)
- Failover testing and health check monitoring
- Traffic Flow visual editor for complex routing

---

## Key Numbers

| Metric | Value |
|---|---|
| Hosted zone cost | $0.50/month |
| Query cost (standard) | $0.40 per million |
| Query cost (Alias to AWS) | Free |
| Query cost (Latency/Geo/Weighted) | $0.60 per million |
| Health check cost (basic) | $0.50/month |
| Health check cost (fast, 10s) | $1.00/month + extra per check |
| Health check interval (standard) | 30 seconds |
| Health check interval (fast) | 10 seconds |
| Health check threshold | 3 consecutive (default) |
| Health checkers | 15+ global locations |
| Max records per hosted zone | 10,000 (can request increase) |
| Max hosted zones per account | 500 (can request increase) |
| Multi-value answer max | 8 records per response |
| Calculated health check children | Up to 256 |
| Health check body check | First 5,120 bytes |
| DNS TTL (typical) | 60-300 seconds |
| CNAME | Cannot be at zone apex |
| Alias | Free, works at zone apex |

---

## Cheat Sheet

- Route 53 = DNS service. Maps names to IPs. Port 53.
- Hosted Zone = container for DNS records. Public (internet) or Private (VPC only).
- A record = name → IPv4. AAAA = name → IPv6.
- CNAME = name → name. CANNOT be at zone apex. Costs for queries.
- Alias = name → AWS resource. CAN be at zone apex. FREE for queries. Always pick Alias for AWS resources.
- Simple = one answer. Weighted = split by %. Latency = fastest region.
- Failover = active-passive DR. Geolocation = by country. Geoproximity = by distance + bias. Multi-Value = multiple healthy IPs.
- Health checks run from 15+ global locations. Must allow their IPs in security groups.
- Private health checks: use CloudWatch Alarm health check (checkers can't reach private IPs).
- Calculated health checks combine multiple checks with AND/OR logic.
- DNSSEC = digital signatures to prevent DNS spoofing. KMS CMK in us-east-1.
- Resolver = hybrid DNS. Inbound = on-prem queries AWS. Outbound = AWS queries on-prem.
- Geolocation needs a default record. Geoproximity needs Traffic Flow.
- Weighted routing with weight=0 sends no traffic (good for maintenance).
- Multi-value is NOT a load balancer — it's client-side random selection of healthy IPs.
- Domain registration: Route 53 or external registrar. Can transfer in.
