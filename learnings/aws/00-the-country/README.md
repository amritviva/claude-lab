# 00 - The Country: Regions, Availability Zones & Edge Locations

> **Analogy:** AWS is a country. Regions are countries within the AWS world. AZs are cities within those countries. Edge Locations are corner shops scattered everywhere for fast local delivery.

---

## ELI10

Imagine AWS is a giant country that owns land all over the world. In each part of the world, they build a separate **country** (Region) -- like one in Australia, one in the USA, one in Japan. Inside each country, they build **cities** (Availability Zones) that are far enough apart that a flood in one city won't hit another, but close enough that they can send stuff between cities really fast. Then, outside all the countries, they set up hundreds of tiny **corner shops** (Edge Locations) in every neighbourhood so people can pick up their orders quickly without going all the way to the main warehouse.

---

## The Concept

### Regions -- The Countries

A **Region** is a geographically isolated cluster of data centres. Each Region is completely independent -- its own power grid, networking, and physical location.

```
AWS World
├── us-east-1        (USA - N. Virginia)     ← Oldest, most services, cheapest
├── us-west-2        (USA - Oregon)
├── eu-west-1        (Ireland)
├── ap-southeast-2   (Australia - Sydney)    ← Amrit's home turf
├── ap-northeast-1   (Japan - Tokyo)
└── ... 30+ Regions worldwide
```

**Why Regions matter:**
- **Data residency / sovereignty** -- Australian law may require data stays in ap-southeast-2
- **Latency** -- serve users from the closest country
- **Service availability** -- not all services launch in all Regions simultaneously
- **Cost** -- us-east-1 is typically cheapest; ap-southeast-2 costs ~10-20% more
- **Disaster recovery** -- replicate across countries (Regions) for maximum resilience

**Region selection criteria (exam favourite):**
1. Compliance / data sovereignty requirements
2. Proximity to customers (latency)
3. Available services and features
4. Pricing

### Availability Zones -- The Cities

Each Region contains **2-6 AZs** (typically 3). Each AZ is one or more discrete data centres with redundant power, networking, and connectivity.

```
ap-southeast-2 (Australia)
├── ap-southeast-2a  ← "Sydney CBD"
├── ap-southeast-2b  ← "Melbourne"
└── ap-southeast-2c  ← "Canberra"

Each city has:
- Independent power supply
- Independent cooling
- Independent networking
- Connected via low-latency private fibre (< 1ms)
```

**Key facts:**
- AZs within a Region are physically separated (distinct buildings, often different suburbs/cities)
- Connected by high-bandwidth, low-latency private fibre
- AZ names are **randomised per account** -- `us-east-1a` in your account might be a different physical DC than `us-east-1a` in someone else's account. Use **AZ IDs** (e.g., `use1-az1`) for cross-account coordination.
- Designing for **multi-AZ** = designing for high availability

**Shipping costs analogy:**
- Same AZ (within the city): Free / cheapest
- Cross-AZ (between cities in same country): Cheap ($0.01/GB typically)
- Cross-Region (international shipping): Expensive ($0.02+/GB)

### Edge Locations -- The Corner Shops

**300+ Edge Locations** worldwide, plus **13 Regional Edge Caches**. These are NOT full data centres -- they're lightweight caching points.

```
User in Brisbane
     │
     ▼
[Edge Location - Brisbane]  ← Corner shop: has cached copies
     │ cache miss?
     ▼
[Regional Edge Cache - Sydney]  ← Regional distribution centre
     │ cache miss?
     ▼
[Origin - ap-southeast-2]  ← Main warehouse
```

**Services that use Edge Locations:**
- **CloudFront** (CDN) -- caches content at corner shops
- **Route 53** (DNS) -- answers DNS queries from nearest corner shop
- **AWS WAF** -- filters malicious traffic at the edge
- **Lambda@Edge / CloudFront Functions** -- run code at corner shops
- **AWS Global Accelerator** -- routes traffic through AWS backbone from nearest edge

### Service Scope -- Who Operates Where?

This is critical for exams. Services operate at different levels:

```
┌─────────────────────────────────────────────┐
│              GLOBAL SERVICES                 │
│  IAM, Route 53, CloudFront, WAF,            │
│  Organizations, STS (global endpoint)       │
├─────────────────────────────────────────────┤
│           REGIONAL SERVICES                  │
│  S3*, Lambda*, API Gateway, DynamoDB*,      │
│  VPC, ECS, RDS, SQS, SNS, Step Functions   │
├─────────────────────────────────────────────┤
│              AZ SERVICES                     │
│  EC2, EBS, Subnet, ENI, RDS instance        │
└─────────────────────────────────────────────┘

* S3 = Regional service but globally unique bucket names
* Lambda = Regional but AWS runs it across AZs automatically (multi-AZ by default!)
* DynamoDB = Regional, automatically replicated across AZs
```

**Exam trap:** Lambda is multi-AZ by default. EC2 is NOT -- you must manually launch instances in multiple AZs.

### Multi-AZ by Default vs Manual

| Service | Multi-AZ? | Notes |
|---------|-----------|-------|
| Lambda | Automatic | AWS handles it, no config needed |
| DynamoDB | Automatic | Data replicated across 3 AZs |
| S3 | Automatic | Objects stored across 3+ AZs (except One Zone-IA) |
| ELB | Automatic | When you enable multiple AZ subnets |
| EC2 | **Manual** | Must launch in multiple AZs yourself |
| RDS | **Manual** | Must enable Multi-AZ deployment |
| EBS | **Single AZ** | Locked to one AZ, use snapshots to move |
| ElastiCache | **Manual** | Must enable Multi-AZ with auto-failover |

---

## Architecture Diagram

```
                        ┌──────────── AWS GLOBAL ────────────┐
                        │  IAM, Route 53, CloudFront, WAF    │
                        └──────────────┬─────────────────────┘
                                       │
          ┌────────────────────────────┼────────────────────────────┐
          │                            │                            │
   ┌──────▼──────┐             ┌──────▼──────┐             ┌──────▼──────┐
   │  us-east-1  │             │ap-southeast-2│            │  eu-west-1  │
   │   (USA)     │             │ (Australia)  │             │  (Ireland)  │
   ├─────────────┤             ├─────────────┤             ├─────────────┤
   │ ┌─────────┐ │             │ ┌─────────┐ │             │ ┌─────────┐ │
   │ │  AZ-1a  │ │             │ │  AZ-2a  │ │             │ │  AZ-1a  │ │
   │ └─────────┘ │             │ └─────────┘ │             │ └─────────┘ │
   │ ┌─────────┐ │             │ ┌─────────┐ │             │ ┌─────────┐ │
   │ │  AZ-1b  │ │             │ │  AZ-2b  │ │             │ │  AZ-1b  │ │
   │ └─────────┘ │             │ └─────────┘ │             │ └─────────┘ │
   │ ┌─────────┐ │             │ ┌─────────┐ │             │ ┌─────────┐ │
   │ │  AZ-1c  │ │             │ │  AZ-2c  │ │             │ │  AZ-1c  │ │
   │ └─────────┘ │             │ └─────────┘ │             │ └─────────┘ │
   └─────────────┘             └─────────────┘             └─────────────┘
          │                            │                            │
   [Edge Locations]            [Edge Locations]            [Edge Locations]
   NYC, Chicago, LA...         Sydney, Melbourne,          London, Paris,
                               Auckland, Brisbane...        Frankfurt...
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- Region selection criteria (compliance, latency, cost, services)
- Multi-AZ architecture for high availability
- Multi-Region architecture for disaster recovery
- Which services are global vs regional vs AZ-scoped
- Cross-region data transfer costs
- Edge locations for CloudFront/Route 53

### DVA-C02 (Developer)
- Lambda multi-AZ behaviour (automatic, no config)
- DynamoDB Global Tables (multi-region)
- API Gateway edge-optimized vs regional endpoints
- Understanding which Region your code deploys to

### SOA-C02 (SysOps Administrator)
- AZ failure scenarios and recovery
- Monitoring AZ-level health (CloudWatch)
- Cross-AZ data transfer cost optimization
- Service quotas per Region
- Enabling Regions (opt-in Regions like af-south-1)

---

## Key Numbers

| Fact | Value |
|------|-------|
| Total Regions | 30+ (and growing) |
| AZs per Region | 2-6 (typically 3) |
| Edge Locations | 300+ globally |
| Regional Edge Caches | 13 |
| Cross-AZ data transfer | ~$0.01/GB |
| Cross-Region data transfer | ~$0.02/GB |
| AZ latency (within Region) | Single-digit milliseconds |
| Default opt-in Regions | Disabled by default (must enable in console) |
| AZ naming | Randomised per account |
| Minimum AZs per Region | 2 (but most have 3) |

---

## Cheat Sheet

- Region = independent country with its own infrastructure
- AZ = city within that country (2-6 per Region, physically separated, low-latency connected)
- Edge Location = corner shop for caching (CloudFront, Route 53, WAF)
- AZ names are randomised per account -- use AZ IDs for cross-account
- Lambda, DynamoDB, S3 = multi-AZ by default
- EC2, RDS, ElastiCache = you must configure multi-AZ manually
- EBS = single-AZ only (use snapshots to move)
- Region selection: compliance first, then latency, then services, then cost
- us-east-1 = oldest Region, most services, cheapest, where most new services launch first
- Global services: IAM, Route 53, CloudFront, WAF, Organizations
- Cross-AZ = cheap; Cross-Region = expensive
- Opt-in Regions exist (af-south-1, ap-east-1, etc.) -- must be explicitly enabled
- S3 bucket names are globally unique even though S3 is a Regional service
