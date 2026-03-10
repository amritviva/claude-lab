# 02 - VPC: The Army Base HQ

> **Analogy:** A VPC is your own walled army base within the AWS country. You control the fences, gates, road signs, and who gets in or out. Subnets are divisions within the base. Security Groups are bodyguards. NACLs are fence guards.

---

## ELI10

Imagine you've been given a huge piece of land inside the AWS country, and you build a **walled army base** on it. Inside, you divide the base into sections: some sections are near the **front gate** (public subnets) where visitors can come in, and others are deep in the **inner barracks** (private subnets) where only authorised soldiers go. The front gate has a **border control officer** (Internet Gateway) who lets traffic in and out. The inner barracks have a **secure comms room** (NAT Gateway) where soldiers inside can call out to the internet but nobody outside can call in. Every section has **road signs** (Route Tables) telling traffic where to go.

---

## The Concept

### VPC -- The Walled Compound

A VPC is a logically isolated section of the AWS cloud where you launch resources. You define the IP address range, create subnets, configure route tables, and set up security.

```
┌─────────────────── VPC: 10.0.0.0/16 ───────────────────┐
│                   (65,536 IP addresses)                  │
│                                                          │
│  ┌──────── Public Subnet ────────┐  ┌── Private Subnet ─┐│
│  │  10.0.1.0/24 (256 IPs)       │  │  10.0.2.0/24      ││
│  │  - Web servers                │  │  - Databases       ││
│  │  - Load balancers             │  │  - App servers     ││
│  │  - Bastion hosts              │  │  - Lambda (VPC)    ││
│  └───────────────────────────────┘  └────────────────────┘│
└──────────────────────────────────────────────────────────┘
```

**Key facts:**
- VPC is Regional (spans all AZs in a Region)
- CIDR block: /16 (largest, 65,536 IPs) to /28 (smallest, 16 IPs)
- Can add secondary CIDR blocks (up to 5 by default)
- **Default VPC:** Every Region has one, CIDR `172.31.0.0/16`, one /20 public subnet per AZ

### CIDR Planning -- Mapping Your Land

```
10.0.0.0/16  = The entire base (65,536 addresses)
10.0.0.0/24  = One division (256 addresses, 251 usable)
10.0.0.0/28  = One tent (16 addresses, 11 usable)

Subnet rule: AWS RESERVES 5 IPs in every subnet:
  .0 = Network address
  .1 = VPC router
  .2 = DNS server
  .3 = Reserved for future use
  .255 = Broadcast address (even though broadcast isn't supported)

So a /24 subnet: 256 - 5 = 251 usable IPs
A /28 subnet: 16 - 5 = 11 usable IPs
```

**Exam tip:** When a question says "minimum number of IPs needed," always add 5 for AWS reserved addresses.

### Subnets -- Divisions Within the Base

A subnet lives in exactly **one AZ** (cannot span AZs).

**Public subnet:** Has a route to the Internet Gateway (front gate area)
**Private subnet:** No direct route to the internet (inner barracks)

What makes a subnet "public":
1. Route table has a route `0.0.0.0/0 → IGW`
2. Instances have public/Elastic IPs
3. NACL and Security Groups allow the traffic

```
┌──────────── AZ-2a ────────────┐  ┌──────────── AZ-2b ────────────┐
│ ┌─── Public Subnet ─────────┐ │  │ ┌─── Public Subnet ─────────┐ │
│ │ 10.0.1.0/24               │ │  │ │ 10.0.3.0/24               │ │
│ │ Route: 0.0.0.0/0 → IGW   │ │  │ │ Route: 0.0.0.0/0 → IGW   │ │
│ └────────────────────────────┘ │  │ └────────────────────────────┘ │
│ ┌─── Private Subnet ────────┐ │  │ ┌─── Private Subnet ────────┐ │
│ │ 10.0.2.0/24               │ │  │ │ 10.0.4.0/24               │ │
│ │ Route: 0.0.0.0/0 → NAT   │ │  │ │ Route: 0.0.0.0/0 → NAT   │ │
│ └────────────────────────────┘ │  │ └────────────────────────────┘ │
└────────────────────────────────┘  └────────────────────────────────┘
```

### Internet Gateway (IGW) -- The Border Control Gate

- Allows **bidirectional** internet access (in and out)
- One IGW per VPC (1:1 relationship)
- Horizontally scaled, redundant, no bandwidth constraints
- Free (you pay for data transfer, not the IGW itself)

### NAT Gateway -- The Secure Comms Room

- Allows private subnet instances to reach the internet (outbound only)
- Internet cannot initiate connections inbound
- Lives in a **public subnet** (needs IGW access itself)
- Managed by AWS, scales automatically
- **AZ-specific** -- deploy one per AZ for high availability
- Costs: hourly charge + data processing charge

```
Private Instance → NAT Gateway (in public subnet) → IGW → Internet
Internet → IGW → NAT Gateway → BLOCKED (no inbound initiation)
```

**NAT Gateway vs NAT Instance:**
| Feature | NAT Gateway | NAT Instance |
|---------|-------------|--------------|
| Managed by | AWS | You |
| Availability | Highly available in AZ | You manage failover |
| Bandwidth | Up to 100 Gbps | Depends on instance type |
| Security Groups | Cannot associate | Can associate |
| Bastion host | Cannot use as | Can use as |
| Cost | Higher | Lower (small instances) |
| Port forwarding | Not supported | Supported |

### Security Groups -- The Bodyguards

Security Groups are **stateful** firewalls at the instance (ENI) level.

**Stateful = If the bodyguard lets someone in, they automatically let them back out.**

```
┌─────── Security Group: web-sg ───────┐
│                                       │
│  INBOUND RULES (who can come in):     │
│  ┌──────────┬────────┬──────────────┐ │
│  │ Protocol │  Port  │  Source      │ │
│  ├──────────┼────────┼──────────────┤ │
│  │ TCP      │  80    │  0.0.0.0/0  │ │
│  │ TCP      │  443   │  0.0.0.0/0  │ │
│  │ TCP      │  22    │  10.0.0.0/16│ │
│  └──────────┴────────┴──────────────┘ │
│                                       │
│  OUTBOUND RULES (who can go out):     │
│  ┌──────────┬────────┬──────────────┐ │
│  │ Protocol │  Port  │  Destination │ │
│  ├──────────┼────────┼──────────────┤ │
│  │ All      │  All   │  0.0.0.0/0  │ │
│  └──────────┴────────┴──────────────┘ │
└───────────────────────────────────────┘
```

**Key facts:**
- **ALLOW rules only** (no deny rules -- the bodyguard either lets you in or ignores you)
- **Stateful**: return traffic automatically allowed
- Evaluated as a whole (all rules checked, any match = allowed)
- Can reference other Security Groups as source/destination (powerful!)
- Default: all inbound DENIED, all outbound ALLOWED
- Changes take effect **immediately**
- Applied at the **ENI level** (one instance can have multiple SGs)

### NACLs -- The Fence Guards

Network ACLs are **stateless** firewalls at the **subnet** level.

**Stateless = Fence guard checks your ID on the way in AND on the way out. Doesn't remember you.**

```
┌─────── NACL: public-nacl ────────────────────────────┐
│                                                       │
│  INBOUND RULES (processed in order, low # first):    │
│  ┌──────┬──────────┬──────┬──────────────┬─────────┐ │
│  │ Rule │ Protocol │ Port │  Source      │ Action  │ │
│  ├──────┼──────────┼──────┼──────────────┼─────────┤ │
│  │ 100  │ TCP      │ 80   │ 0.0.0.0/0   │ ALLOW   │ │
│  │ 110  │ TCP      │ 443  │ 0.0.0.0/0   │ ALLOW   │ │
│  │ 120  │ TCP      │ 22   │ 10.0.0.0/16 │ ALLOW   │ │
│  │ *    │ All      │ All  │ 0.0.0.0/0   │ DENY    │ │
│  └──────┴──────────┴──────┴──────────────┴─────────┘ │
└───────────────────────────────────────────────────────┘
```

**Key facts:**
- **ALLOW and DENY rules** (can explicitly block specific IPs)
- **Stateless**: must define both inbound AND outbound rules
- Rules evaluated **in number order** (lowest first), first match wins
- One NACL per subnet (but one NACL can be applied to many subnets)
- **Default NACL**: allows ALL inbound and outbound (wide open!)
- **Custom NACL**: denies ALL by default (locked down)
- Must allow **ephemeral ports** (1024-65535) for return traffic

### Security Groups vs NACLs -- Bodyguard vs Fence Guard

| Feature | Security Group | NACL |
|---------|---------------|------|
| Analogy | Bodyguard | Fence guard |
| Level | Instance (ENI) | Subnet |
| Stateful? | YES | NO |
| Rules | Allow only | Allow AND Deny |
| Rule order | All evaluated | Number order, first match |
| Default inbound | Deny all | Allow all (default NACL) |
| Return traffic | Automatic | Must explicitly allow |
| Applied to | Specific instances | All instances in subnet |

### Route Tables -- Road Signs

Every subnet must be associated with a route table. If you don't specify one, it uses the **main route table**.

```
Public Subnet Route Table:
┌───────────────────┬─────────────┐
│   Destination     │   Target    │
├───────────────────┼─────────────┤
│   10.0.0.0/16     │   local     │  ← Traffic within VPC stays internal
│   0.0.0.0/0       │   igw-xxx   │  ← Everything else → Internet Gateway
└───────────────────┴─────────────┘

Private Subnet Route Table:
┌───────────────────┬─────────────┐
│   Destination     │   Target    │
├───────────────────┼─────────────┤
│   10.0.0.0/16     │   local     │  ← Traffic within VPC stays internal
│   0.0.0.0/0       │   nat-xxx   │  ← Everything else → NAT Gateway
└───────────────────┴─────────────┘
```

### VPC Peering -- Tunnel Between Two Bases

- Connects two VPCs via private AWS network (no internet involved)
- Can peer across Regions and across accounts
- **NOT transitive**: If A peers with B, and B peers with C, A cannot talk to C through B
- CIDR blocks cannot overlap
- Must update route tables on both sides

```
VPC-A (10.0.0.0/16) ←──peering──→ VPC-B (172.16.0.0/16)
                                      ←──peering──→ VPC-C (192.168.0.0/16)

VPC-A CANNOT reach VPC-C through VPC-B (not transitive!)
Solution: Direct peering between A and C, or use Transit Gateway
```

### VPC Endpoints -- Secret Underground Tunnels

VPC Endpoints let private subnet resources access AWS services without going through the internet.

**Two types:**

| Type | Analogy | Services | Cost |
|------|---------|----------|------|
| **Gateway Endpoint** | Underground road (added to route table) | S3, DynamoDB **only** | Free |
| **Interface Endpoint** | Private phone line (ENI in subnet) | 80+ services | Hourly + data |

```
Without Endpoint:
Private EC2 → NAT GW → IGW → Internet → S3 ($$$ data transfer)

With Gateway Endpoint:
Private EC2 → Route Table → Gateway Endpoint → S3 (free, private)

With Interface Endpoint:
Private EC2 → ENI (in subnet) → AWS PrivateLink → Other AWS Service
```

**Exam tip:** Gateway Endpoints are free and used for S3/DynamoDB. Interface Endpoints cost money but work for everything else.

### Transit Gateway -- Central Railway Station

When you have many VPCs that all need to talk to each other:

```
Without Transit Gateway (mesh):      With Transit Gateway (hub-and-spoke):

  VPC-A ──── VPC-B                      VPC-A ──┐
    │  \    / │                                  │
    │   \  /  │                         VPC-B ──→ TGW ←── VPN
    │    \/   │                                  │
    │    /\   │                         VPC-C ──┘
    │   /  \  │
  VPC-C ──── VPN                   (Simple! Hub-and-spoke!)
  (Messy! N*(N-1)/2 peerings!)
```

### VPC Flow Logs -- Security Cameras

- Capture IP traffic information for network interfaces
- Can be set at: VPC level, Subnet level, or ENI level
- Logs to: CloudWatch Logs or S3
- Cannot change after creation (must delete and recreate)
- Does NOT capture: DNS traffic to Route 53, DHCP traffic, metadata (169.254.169.254), Windows license activation

---

## Architecture Diagram

```
                    INTERNET
                       │
                       ▼
              ┌──── IGW ────┐
              │(Border Gate) │
              └──────┬───────┘
                     │
┌────────────── VPC: 10.0.0.0/16 ──────────────────────────────┐
│                    │                                          │
│  ┌─── Public Subnet 10.0.1.0/24 (AZ-a) ───┐                │
│  │         │                                │                │
│  │    [ALB/NLB]  [Bastion]  [NAT GW]       │                │
│  │         │                    │           │                │
│  │    SG: web-sg          SG: nat-sg       │                │
│  └─────────┼────────────────────┼───────────┘                │
│            │                    │                             │
│  ┌─── Private Subnet 10.0.2.0/24 (AZ-a) ──┐                │
│  │         │                    │           │                │
│  │    [App Server]         [Lambda]         │                │
│  │         │                                │                │
│  │    SG: app-sg                            │                │
│  └─────────┼────────────────────────────────┘                │
│            │                                                  │
│  ┌─── Private Subnet 10.0.3.0/24 (AZ-a) ──┐                │
│  │         │                                │                │
│  │    [RDS Primary]    [ElastiCache]        │                │
│  │         │                                │    ┌─────────┐ │
│  │    SG: db-sg                             │    │Gateway  │ │
│  └──────────────────────────────────────────┘    │Endpoint │ │
│                                                   │(S3,DDB) │ │
│                                                   └─────────┘ │
└───────────────────────────────────────────────────────────────┘
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- Multi-tier architecture design (public/private subnets)
- When to use NAT Gateway vs VPC Endpoint
- VPC Peering vs Transit Gateway (scale / transitivity)
- Gateway Endpoint (S3/DynamoDB) vs Interface Endpoint
- PrivateLink for exposing services to other VPCs
- CIDR planning to avoid overlap
- Bastion host architecture

### DVA-C02 (Developer)
- Lambda in VPC (needs ENI, NAT Gateway for internet, VPC Endpoint for AWS services)
- Security Group configuration for app tiers
- VPC Endpoint for accessing DynamoDB/S3 from Lambda
- Understanding public vs private subnet for deployment

### SOA-C02 (SysOps Administrator)
- VPC Flow Logs: setup, analysis, troubleshooting
- NACL vs Security Group troubleshooting
- NAT Gateway monitoring and high availability (one per AZ)
- Troubleshooting connectivity (check: SG, NACL, Route Table, IGW, NAT)
- Default VPC management
- VPC peering troubleshooting (CIDR overlap, route tables)

---

## Key Numbers

| Fact | Value |
|------|-------|
| VPCs per Region | 5 (soft limit, can increase) |
| Subnets per VPC | 200 |
| Route tables per VPC | 200 |
| Routes per route table | 50 (can increase to 1,000) |
| Security Groups per VPC | 2,500 |
| Rules per Security Group | 60 inbound + 60 outbound |
| NACLs per VPC | 200 |
| Rules per NACL | 20 (can increase to 40) |
| Elastic IPs per Region | 5 (soft limit) |
| IGWs per VPC | 1 |
| NAT Gateways per AZ | 5 |
| VPC Peering per VPC | 50 (can increase to 125) |
| CIDR blocks per VPC | 5 (can increase) |
| Default VPC CIDR | 172.31.0.0/16 |
| Default subnet CIDR | /20 (4,096 IPs, 4,091 usable) |
| Reserved IPs per subnet | 5 |
| Gateway Endpoints cost | Free |
| Interface Endpoints cost | ~$0.01/hr + data |

---

## Cheat Sheet

- VPC = your private network in AWS, Regional scope, spans all AZs
- Public subnet = has route to IGW; Private subnet = no route to IGW
- IGW = bidirectional internet access (one per VPC, free)
- NAT Gateway = outbound-only internet for private subnets (costs money, AZ-specific)
- Security Group = stateful bodyguard (allow only, instance level)
- NACL = stateless fence guard (allow + deny, subnet level, rule order matters)
- Default SG: deny inbound, allow outbound
- Default NACL: allow all; Custom NACL: deny all
- 5 IPs reserved per subnet (network, router, DNS, future, broadcast)
- VPC Peering is NOT transitive -- use Transit Gateway for hub-and-spoke
- Gateway Endpoint = free tunnel to S3/DynamoDB (added to route table)
- Interface Endpoint = paid private link to other AWS services (ENI in subnet)
- VPC Flow Logs capture traffic metadata (not packet contents)
- Lambda in VPC needs NAT Gateway for internet, VPC Endpoint for AWS services
- SG can reference other SGs (e.g., "allow traffic from web-sg")
- NACL needs ephemeral port rules (1024-65535) because it's stateless
- Troubleshooting order: SG → NACL → Route Table → IGW/NAT → DNS
