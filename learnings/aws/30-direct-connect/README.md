# Direct Connect — Private Highway

> **Direct Connect is a private highway from your office directly to the AWS Country. No public internet traffic, no traffic jams, no unpredictable routes. Dedicated connection = your own private lane. Hosted connection = a reserved lane on a shared highway.**

---

## ELI10

Imagine your school is across town from a big library (AWS). Normally, you take public roads (the internet) — sometimes there's traffic, sometimes the road is closed, and sometimes a stranger follows you. One day, the school builds a PRIVATE road that goes directly from the school to the library. No traffic, no detours, same route every time, and it's much faster. A "dedicated connection" is like owning your own private road. A "hosted connection" is like renting a reserved lane on someone else's private road. The private road isn't locked though — anyone on it can see what you're carrying. If you want privacy, you drive an armored truck (VPN) on the private road.

---

## The Concept

### Direct Connect = Dedicated Network Link to AWS

```
┌──────────────────────────────────────────────────────────────┐
│                                                               │
│  Your Data Center                  AWS Region                 │
│  ┌──────────────┐                  ┌──────────────┐          │
│  │              │                  │              │          │
│  │  Servers     │                  │  VPC 1       │          │
│  │  Routers     │  Direct Connect  │  VPC 2       │          │
│  │  Firewalls   │ ════════════════ │  VPC 3       │          │
│  │              │  (Private link)  │  S3, DynamoDB│          │
│  └──────────────┘                  └──────────────┘          │
│        │                                  │                   │
│        │         NOT over internet        │                   │
│        │         Dedicated fiber           │                   │
│        │         Consistent latency        │                   │
│        │         Consistent bandwidth      │                   │
│                                                               │
│  vs. Site-to-Site VPN:                                        │
│  ┌──────────────┐                  ┌──────────────┐          │
│  │  Your DC     │  ~~~Internet~~~  │  AWS VPC     │          │
│  │              │  (Encrypted VPN) │              │          │
│  └──────────────┘                  └──────────────┘          │
│        Cheaper, faster setup, variable performance            │
└──────────────────────────────────────────────────────────────┘
```

### Connection Types

```
┌──────────────────────────────────────────────────────────────┐
│                   CONNECTION TYPES                             │
│                                                               │
│  DEDICATED CONNECTION (Your Own Lane)                         │
│  ┌────────────────────────────────────────────┐              │
│  │ • Physical port at DX location              │              │
│  │ • Speeds: 1 Gbps, 10 Gbps, 100 Gbps        │              │
│  │ • Single-tenant — you get the whole port    │              │
│  │ • Setup time: weeks to months               │              │
│  │ • You request via AWS console               │              │
│  │ • Need to work with DX location partner     │              │
│  └────────────────────────────────────────────┘              │
│                                                               │
│  HOSTED CONNECTION (Shared Lane, Reserved Bandwidth)          │
│  ┌────────────────────────────────────────────┐              │
│  │ • Provisioned by DX Partner (ISP)           │              │
│  │ • Speeds: 50 Mbps to 10 Gbps               │              │
│  │ • Shared infrastructure, reserved capacity  │              │
│  │ • Faster setup than dedicated                │              │
│  │ • Good for smaller bandwidth needs          │              │
│  │ • You work with the partner, not AWS         │              │
│  └────────────────────────────────────────────┘              │
│                                                               │
│  Setup Time Reminder:                                         │
│  Dedicated: weeks to months (physical cross-connect)          │
│  Hosted: days to weeks (partner provisions)                   │
│  VPN: minutes to hours (software-only)                        │
└──────────────────────────────────────────────────────────────┘
```

### Virtual Interfaces (VIFs) — Highway On-Ramps

```
┌──────────────────────────────────────────────────────────────┐
│                VIRTUAL INTERFACES (VIFs)                       │
│                                                               │
│  Think of VIFs as different on-ramps on the highway:          │
│                                                               │
│  ┌────────────────────────────────────────┐                  │
│  │  PRIVATE VIF                            │                  │
│  │  → Access resources in a VPC            │                  │
│  │  → Uses private IP addresses            │                  │
│  │  → Connects to VPC via Virtual Gateway  │                  │
│  │    or Direct Connect Gateway            │                  │
│  │  → Use case: access EC2, RDS, etc.      │                  │
│  └────────────────────────────────────────┘                  │
│                                                               │
│  ┌────────────────────────────────────────┐                  │
│  │  PUBLIC VIF                             │                  │
│  │  → Access AWS PUBLIC services           │                  │
│  │  → S3, DynamoDB, SQS, SNS, etc.        │                  │
│  │  → Uses public IP addresses             │                  │
│  │  → Doesn't go over internet though!     │                  │
│  │  → Traffic stays on AWS backbone        │                  │
│  └────────────────────────────────────────┘                  │
│                                                               │
│  ┌────────────────────────────────────────┐                  │
│  │  TRANSIT VIF                            │                  │
│  │  → Access multiple VPCs via             │                  │
│  │    Transit Gateway                      │                  │
│  │  → One VIF → many VPCs                  │                  │
│  │  → Requires Direct Connect Gateway      │                  │
│  │  → Most scalable option                 │                  │
│  └────────────────────────────────────────┘                  │
└──────────────────────────────────────────────────────────────┘
```

### Direct Connect Gateway — Highway Junction

```
┌──────────────────────────────────────────────────────────────┐
│              DIRECT CONNECT GATEWAY                            │
│                                                               │
│  Your DC ──── DX Connection ──── DX Gateway                   │
│                                      │                        │
│                          ┌───────────┼───────────┐           │
│                          v           v           v           │
│                     VPC in       VPC in       VPC in         │
│                   us-east-1    ap-se-2     eu-west-1         │
│                                                               │
│  Without DX Gateway:                                          │
│  • 1 Private VIF per VPC                                      │
│  • Only access VPCs in the DX location's region               │
│                                                               │
│  With DX Gateway:                                             │
│  • 1 DX connection → access VPCs in ANY region                │
│  • Connects via Virtual Private Gateways or Transit Gateway   │
│  • Up to 10 VGWs (Virtual Private Gateways) per DX Gateway   │
│  • Global reach from single connection point                  │
│                                                               │
│  DX Gateway + Transit Gateway:                                │
│  • Most scalable: 1 connection → TGW → thousands of VPCs     │
│  • Uses Transit VIF (not Private VIF)                         │
└──────────────────────────────────────────────────────────────┘
```

### LAG — Link Aggregation Group

```
┌──────────────────────────────────────────────┐
│              LAG (Link Aggregation)            │
│                                                │
│  Bundle multiple DX connections into one:      │
│                                                │
│  Connection 1 (10 Gbps) ──┐                   │
│  Connection 2 (10 Gbps) ──┼── LAG (20 Gbps)  │
│                             │                   │
│  Rules:                                        │
│  • All connections must be same speed           │
│  • All at same DX location                      │
│  • Max 4 connections per LAG                    │
│  • Provides aggregated bandwidth                │
│  • NOT for resilience (same location)           │
│  • For resilience: use connections at           │
│    DIFFERENT DX locations                       │
└──────────────────────────────────────────────┘
```

### Encryption — CRITICAL EXAM TOPIC

```
┌──────────────────────────────────────────────────────────────┐
│              ENCRYPTION                                       │
│                                                               │
│  Direct Connect is NOT encrypted by default!                  │
│  Data travels over a private link but in PLAIN TEXT.          │
│                                                               │
│  To encrypt:                                                  │
│  ┌────────────────────────────────────────────┐              │
│  │  Option 1: VPN over Direct Connect          │              │
│  │  • Site-to-Site VPN using the DX connection │              │
│  │  • IPsec encryption end-to-end              │              │
│  │  • Public VIF + VPN endpoint                │              │
│  │  • Private + encrypted = best of both       │              │
│  └────────────────────────────────────────────┘              │
│                                                               │
│  ┌────────────────────────────────────────────┐              │
│  │  Option 2: MACsec (802.1AE)                 │              │
│  │  • Layer 2 encryption on the DX link itself │              │
│  │  • Only on 10 Gbps and 100 Gbps dedicated   │              │
│  │  • Encrypts traffic at the physical layer   │              │
│  │  • Requires compatible hardware             │              │
│  └────────────────────────────────────────────┘              │
│                                                               │
│  Exam tip: "Encrypted private connection" = VPN over DX       │
└──────────────────────────────────────────────────────────────┘
```

### Resilience — High Availability Patterns

```
Maximum Resilience (Critical Workloads):
┌────────────────┐              ┌────────────────┐
│ DX Location 1  │──Connection──│                │
│                │──Connection──│    AWS          │
└────────────────┘              │                │
┌────────────────┐              │                │
│ DX Location 2  │──Connection──│                │
│                │──Connection──│                │
└────────────────┘              └────────────────┘
4 connections across 2 locations = maximum resilience

High Resilience (Important Workloads):
┌────────────────┐──Connection──┐
│ DX Location 1  │              │    AWS
└────────────────┘              │
┌────────────────┐──Connection──┘
│ DX Location 2  │
└────────────────┘
2 connections across 2 locations

DX + VPN Backup:
┌──────┐── Direct Connect (primary) ──┐
│ DC   │                               │ AWS
│      │── Site-to-Site VPN (backup) ──┘
└──────┘
DX is primary, VPN failover via internet (cheaper than 2 DX)
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- **When to use DX** — consistent low latency, high bandwidth, regulatory compliance (no internet)
- **DX + VPN backup** — DX as primary, VPN as failover
- **DX Gateway** — connect one DX to VPCs across multiple regions
- **Encryption** — DX is NOT encrypted. Use VPN over DX or MACsec.
- **Resilience patterns** — dual connections at different DX locations

### DVA-C02 (Developer)
- **Less focus on DX** — mostly architecture decisions, not coding
- **Know the basics** — what DX is, why it's used, VIF types

### SOA-C02 (SysOps)
- **Setup process** — weeks/months (physical cross-connect), not instant
- **Monitoring** — ConnectionState, VIF state, BGP peer status in CloudWatch
- **Failover** — DX → VPN failover configuration, BGP routing
- **Troubleshooting** — BGP session down, VIF not in "available" state
- **LAG** — bundling connections, same speed requirement

---

## Key Numbers

| Fact | Value |
|------|-------|
| Dedicated speeds | 1 Gbps, 10 Gbps, 100 Gbps |
| Hosted speeds | 50 Mbps to 10 Gbps |
| Setup time (dedicated) | Weeks to months |
| Setup time (hosted) | Days to weeks |
| VPN setup time | Minutes to hours |
| LAG max connections | 4 |
| DX Gateway max VGWs | 10 |
| DX Gateway max Transit Gateways | 3 |
| Private VIF VLAN | 1 per VPC connection |
| Transit VIF | 1 per Transit Gateway |
| MACsec support | 10 Gbps and 100 Gbps dedicated only |
| BGP ASN (customer side) | Public or private ASN |

---

## Cheat Sheet

- **Direct Connect = dedicated private link to AWS.** Not over the internet. Consistent latency/bandwidth.
- **Dedicated = your own port.** 1/10/100 Gbps. Weeks to months to set up.
- **Hosted = partner's infrastructure.** 50 Mbps-10 Gbps. Faster setup.
- **NOT encrypted by default.** Use VPN over DX or MACsec for encryption.
- **VPN over DX** = "encrypted private connection" on the exam.
- **Private VIF** = access VPC resources (EC2, RDS). **Public VIF** = access AWS public services (S3, DynamoDB).
- **Transit VIF** = access many VPCs via Transit Gateway. Most scalable.
- **DX Gateway** = one DX connection → VPCs in multiple regions. Global reach.
- **LAG** = bundle up to 4 connections (same speed, same location) for more bandwidth. NOT for resilience.
- **For resilience:** use 2+ connections at DIFFERENT DX locations.
- **DX + VPN backup** = DX as primary, Site-to-Site VPN as failover (cheaper than dual DX).
- **Setup takes weeks/months** — exam might ask about immediate connectivity needs (VPN is faster).
- **BGP** = Border Gateway Protocol, required for DX routing.
- **MACsec** = Layer 2 encryption on 10/100 Gbps dedicated connections.
