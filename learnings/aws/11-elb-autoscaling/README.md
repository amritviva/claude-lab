# ELB & Auto Scaling — Traffic Directors + Army Reserves

> **In the AWS Country, Elastic Load Balancers are traffic directors at the highway junction** — they decide which lane (server) each car (request) goes to. **Auto Scaling is the army reserves system** — it recruits new soldiers (instances) when the battle heats up and sends them home when it's quiet.

---

## ELI10

Picture a busy highway junction with a traffic director standing in the middle. Cars arrive from all directions, and the director points each car to a lane that isn't too crowded. If one lane is closed (server is unhealthy), the director stops sending cars there. Now imagine an army general watching from above. When too many cars show up, the general calls in reserve soldiers (new servers) to open more lanes. When traffic dies down, the reserves go home. You only pay for soldiers while they're on duty. That's ELB + Auto Scaling.

---

## The Concept

### The Four Load Balancers

```
┌─────────────────────────────────────────────────────────────────┐
│                    LOAD BALANCER FAMILY                           │
│                                                                  │
│  ┌──────────────────┐  ALB (Application Load Balancer)           │
│  │  SMART DIRECTOR  │  Layer 7 — HTTP/HTTPS                      │
│  │  Reads the mail  │  Path/host routing, sticky sessions        │
│  │  before routing  │  WebSocket, gRPC, HTTP/2                   │
│  └──────────────────┘  Best for: web apps, microservices         │
│                                                                  │
│  ┌──────────────────┐  NLB (Network Load Balancer)               │
│  │  FAST DIRECTOR   │  Layer 4 — TCP/UDP/TLS                     │
│  │  Just looks at   │  Millions of req/s, ultra-low latency      │
│  │  the address     │  Static IP / Elastic IP per AZ             │
│  └──────────────────┘  Best for: gaming, IoT, financial trading  │
│                                                                  │
│  ┌──────────────────┐  GWLB (Gateway Load Balancer)              │
│  │  SECURITY CHECK  │  Layer 3 — IP packets                      │
│  │  Routes through  │  Transparent to traffic                    │
│  │  firewalls/IDS   │  Uses GENEVE protocol (port 6081)          │
│  └──────────────────┘  Best for: firewalls, IDS/IPS, DPI         │
│                                                                  │
│  ┌──────────────────┐  CLB (Classic Load Balancer)               │
│  │  RETIRED DIRECTOR│  Layer 4 + Layer 7 (limited)               │
│  │  Don't hire      │  LEGACY — don't use for new builds         │
│  │  for new builds  │  No path routing, no host routing          │
│  └──────────────────┘                                            │
└─────────────────────────────────────────────────────────────────┘
```

---

### ALB: The Smart Director (Layer 7)

ALB reads the HTTP request (headers, path, host, query params) before deciding where to route it. Like a director who reads your mail before sending you to the right office.

```
                         Internet
                            │
                     ┌──────┴──────┐
                     │     ALB     │
                     │  (Layer 7)  │
                     └──┬───┬───┬──┘
                        │   │   │
            ┌───────────┘   │   └───────────┐
            ▼               ▼               ▼
   Path: /api/*      Host: admin.*    Path: /images/*
   ┌──────────┐      ┌──────────┐    ┌──────────┐
   │ Target   │      │ Target   │    │ Target   │
   │ Group A  │      │ Group B  │    │ Target   │
   │ (API     │      │ (Admin   │    │ Group C  │
   │  servers)│      │  servers)│    │ (S3/     │
   └──────────┘      └──────────┘    │  static) │
                                     └──────────┘
```

**Routing Rules (in priority order):**

| Rule Type | Example | Use Case |
|---|---|---|
| Path-based | `/api/*` → API servers | Microservices by URL path |
| Host-based | `admin.example.com` → Admin servers | Multi-tenant, subdomains |
| HTTP header | `User-Agent: Mobile*` → Mobile servers | Device-specific routing |
| Query string | `?platform=mobile` → Mobile servers | Feature flags |
| Source IP | `10.0.0.0/8` → Internal servers | Internal vs external traffic |
| HTTP method | `POST /orders` → Write servers | Read/write separation |

**ALB Key Features:**
- Listener rules with fixed responses (return 404, redirect to HTTPS)
- WebSocket support (native)
- HTTP/2 support
- gRPC support
- Server Name Indication (SNI) — multiple TLS certs on one ALB
- Authenticate via Cognito or OIDC (built-in — no application code needed)
- Access logs to S3
- WAF integration (attach AWS WAF rules to ALB)

### Target Group Types (ALB)

| Target Type | What It Is |
|---|---|
| Instance | EC2 instance IDs |
| IP | Specific IP addresses (useful for on-premises or ECS tasks) |
| Lambda | Lambda function (ALB can invoke Lambda directly) |

---

### NLB: The Fast Director (Layer 4)

NLB operates at the transport layer — it doesn't read HTTP content, just routes TCP/UDP connections. Extremely fast and scales to millions of requests per second.

```
                         Internet
                            │
                     ┌──────┴──────┐
                     │     NLB     │
                     │  (Layer 4)  │
                     │             │
                     │ Static IPs: │
                     │ AZ-A: 1.2.3.4│
                     │ AZ-B: 5.6.7.8│
                     └──────┬──────┘
                            │
                    TCP connection forwarded
                    (source IP preserved!)
                            │
                     ┌──────┴──────┐
                     │Target Group │
                     │ (instances) │
                     └─────────────┘
```

**NLB Key Features:**
- **Static IP per AZ** (can assign Elastic IP) — exam favorite
- Preserves source IP (client IP visible to backend)
- Millions of requests per second
- Ultra-low latency (~100 microseconds vs ~400ms for ALB)
- TCP, UDP, TLS termination
- Health checks: TCP, HTTP, HTTPS
- No security groups on NLB itself (traffic passes through transparently)
- **PrivateLink support** — expose services to other VPCs via NLB

**Target Group Types (NLB):**
- Instance
- IP
- ALB (NLB can front-end an ALB! For static IP + Layer 7 features)

---

### GWLB: The Security Checkpoint (Layer 3)

GWLB transparently routes traffic through third-party virtual appliances (firewalls, IDS/IPS) without the source or destination knowing.

```
     Traffic flow:
     Source → GWLB → Firewall appliance → GWLB → Destination
                      (inspect/filter)
```

**Key facts:**
- Uses GENEVE protocol on port 6081
- Transparent bump-in-the-wire deployment
- Used with: Palo Alto, Fortinet, Check Point, etc.
- Gateway Load Balancer Endpoint (GWLBE) in each VPC

---

### ALB vs NLB — Selection Criteria (Exam Decision Table)

| Need | Choose |
|---|---|
| HTTP/HTTPS routing | ALB |
| Path/host-based routing | ALB |
| WebSocket | ALB |
| WAF integration | ALB |
| Cognito/OIDC auth at LB | ALB |
| Static IP / Elastic IP | NLB |
| Millions of req/s, ultra-low latency | NLB |
| TCP/UDP (non-HTTP) protocol | NLB |
| PrivateLink (expose to other VPCs) | NLB |
| Source IP preservation (without X-Forwarded-For) | NLB |
| Firewall/IDS/IPS appliances | GWLB |

---

### Health Checks: Is the Soldier Alive?

The director checks each soldier's health before sending traffic.

```
ALB → Target Group → Health Check
                      │
                      ├── Protocol: HTTP/HTTPS
                      ├── Path: /health
                      ├── Port: traffic port or override
                      ├── Healthy threshold: 5 (consecutive successes)
                      ├── Unhealthy threshold: 2 (consecutive failures)
                      ├── Interval: 30 seconds
                      ├── Timeout: 5 seconds
                      └── Success codes: 200 (or range: 200-299)
```

**Health check states:**
- `Initial` — registering target
- `Healthy` — passing health checks
- `Unhealthy` — failing health checks
- `Draining` — deregistering (connection draining)
- `Unused` — not in any target group

---

### Sticky Sessions (Session Affinity)

Force the same visitor to always go to the same soldier.

- **Application-based cookie (AWSALBAPP):** Your app sets a custom cookie
- **Duration-based cookie (AWSALB):** ALB generates the cookie with a configurable TTL
- **Risk:** Uneven load distribution (one server gets all the "sticky" users)
- Works on ALB and CLB. NLB doesn't do sticky sessions (it uses flow hash).

---

### Cross-Zone Load Balancing

```
WITHOUT cross-zone:                WITH cross-zone:
AZ-A (2 instances): 50% traffic   AZ-A (2 instances): 25% each
AZ-B (8 instances): 50% traffic   AZ-B (8 instances): 10% each
  → AZ-A instances overloaded!      → Even distribution!
```

| LB Type | Cross-Zone Default | Cost |
|---|---|---|
| ALB | Always enabled | Free |
| NLB | Disabled by default | Charges for inter-AZ data |
| CLB | Disabled by default | Free |

---

### Connection Draining (Deregistration Delay)

When a soldier is being removed, let them finish serving current visitors before leaving.

- Default: **300 seconds**
- Range: 0-3,600 seconds
- Set to 0 for instant deregistration (short-lived requests)
- During draining: existing connections complete, no new connections

---

### SSL/TLS Termination

```
Client ──── HTTPS ────▶ ALB ──── HTTP ────▶ EC2
                         │
                   SSL terminated here
                   (ACM certificate)
```

- ALB terminates SSL, forwards HTTP to backend (reduces backend CPU load)
- NLB can terminate TLS or pass through (end-to-end encryption)
- **SNI (Server Name Indication):** ALB supports multiple TLS certificates on one listener — routes to the right cert based on hostname. Like one reception desk handling mail for multiple companies.

---

## Auto Scaling Group (ASG): The Army Reserves

```
┌───────────────────────────────────────────────────────────┐
│                   AUTO SCALING GROUP                       │
│                                                           │
│  Launch Template: "Training Manual"                       │
│  ├── AMI: ami-abc123                                      │
│  ├── Instance type: t3.medium                             │
│  ├── Key pair: my-key                                     │
│  ├── Security group: sg-web                               │
│  ├── User data: bootstrap script                          │
│  └── IAM role: web-server-role                            │
│                                                           │
│  Capacity:                                                │
│  ├── Minimum: 2      (always at least 2 soldiers)         │
│  ├── Desired: 4      (we want 4 right now)                │
│  └── Maximum: 10     (never more than 10)                 │
│                                                           │
│  Subnets: AZ-A, AZ-B, AZ-C                               │
│                                                           │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐                         │
│  │ EC2 │ │ EC2 │ │ EC2 │ │ EC2 │  ← current desired      │
│  │  1  │ │  2  │ │  3  │ │  4  │                          │
│  └─────┘ └─────┘ └─────┘ └─────┘                         │
│                                                           │
│  Scaling Policies: "When to call reserves"                │
│  └── Target Tracking / Step / Scheduled / Predictive      │
└───────────────────────────────────────────────────────────┘
```

### Launch Template vs Launch Configuration

| Feature | Launch Template | Launch Configuration |
|---|---|---|
| Versioning | Yes (multiple versions) | No (immutable) |
| Inheritance | Yes (parent/child templates) | No |
| Mixed instance types | Yes | No |
| Spot + On-Demand mix | Yes | No |
| Status | **Current** | **Legacy** (don't use) |

**Always use Launch Templates.** Launch Configurations are the old way.

---

### Scaling Policies

**1. Target Tracking (Thermostat)**
```
"Maintain CPU at 70%"
→ ASG adds/removes instances to stay at target
→ Simplest and most common
→ Built-in metrics: CPU, NetworkIn/Out, ALB request count per target
```

**2. Step Scaling (Staircase)**
```
CPU 60-70% → add 1 instance
CPU 70-80% → add 2 instances
CPU 80%+   → add 3 instances
→ More granular than target tracking
→ Requires CloudWatch alarms
```

**3. Scheduled Scaling (Calendar)**
```
Every Monday 8am → set desired to 10
Every Friday 6pm → set desired to 4
→ For predictable patterns
→ Cron expression or one-time schedule
```

**4. Predictive Scaling (Crystal Ball)**
```
ML analyzes past traffic patterns → pre-scales before demand arrives
→ Needs 2+ weeks of historical data
→ Great for cyclical patterns
→ Can combine with target tracking
```

### Cooldown Period

After a scaling action, the ASG waits before doing another one.

- Default: **300 seconds** (5 minutes)
- Purpose: wait for new instances to stabilize and start handling traffic
- If cooldown is too short: thrashing (constant scale up/down)
- If cooldown is too long: slow to respond to changes
- Target tracking has its own built-in cooldown (scale-in cooldown)

### Scaling Cooldown vs Warm-Up

- **Cooldown:** Wait time after ANY scaling action before allowing another
- **Warm-up (instance warm-up):** Time for a new instance to be ready. During warm-up, the instance's metrics aren't included in ASG aggregate. Prevents premature scale-in.

---

### Lifecycle Hooks

Pause instances during launch or termination to run custom actions.

```
Pending ──▶ Pending:Wait ──▶ Pending:Proceed ──▶ InService
                 │
            Run bootstrap:
            install software,
            pull config,
            register with LB
            (default: 1 hour timeout)

InService ──▶ Terminating:Wait ──▶ Terminating:Proceed ──▶ Terminated
                    │
               Run cleanup:
               drain connections,
               deregister from DNS,
               upload logs
```

---

### Instance Refresh

Rolling update of all instances in the ASG without manual intervention.

- Set minimum healthy percentage (e.g., 90%)
- ASG replaces instances in batches
- Use case: new AMI, new launch template version
- Checkpoints for validation between batches

---

### Termination Policies

When scaling in, which instance gets terminated first?

Default order:
1. AZ with most instances (balance AZs)
2. Instance with oldest launch configuration/template
3. Instance closest to next billing hour
4. Random if tied

Custom policies: OldestInstance, NewestInstance, OldestLaunchConfiguration, ClosestToNextInstanceHour, Default

---

### Weighted Target Groups (ALB)

Route different percentages of traffic to different target groups.

```
ALB Listener Rule:
  /api/* →
    Target Group A (v1): weight 90
    Target Group B (v2): weight 10
```

Use case: blue/green or canary deployments at the ALB level.

### Slow Start Mode

Gradually increase traffic to a newly registered target instead of sending full load immediately.

- Duration: 30-900 seconds
- During slow start: target receives linearly increasing share of traffic
- Prevents overwhelming new instances still warming up caches

---

## Architecture Diagram: Full Setup

```
                         Internet
                            │
                     ┌──────┴──────┐
                     │  Route 53   │
                     └──────┬──────┘
                            │
                     ┌──────┴──────┐
                     │     ALB     │
                     │ (Layer 7)   │
                     │ WAF + HTTPS │
                     └──┬───┬───┬──┘
                        │   │   │
                        │   │   │  Target Group (health checks)
                        ▼   ▼   ▼
              ┌─────────────────────────────────┐
              │      AUTO SCALING GROUP          │
              │                                 │
              │  ┌────┐ ┌────┐ ┌────┐ ┌────┐   │
              │  │EC2 │ │EC2 │ │EC2 │ │EC2 │   │
              │  │AZ-A│ │AZ-A│ │AZ-B│ │AZ-B│   │
              │  └────┘ └────┘ └────┘ └────┘   │
              │                                 │
              │  Min: 2 | Desired: 4 | Max: 8   │
              │  Policy: Target Tracking (70% CPU)│
              │  Cooldown: 300s                  │
              │  Launch Template: v3              │
              └─────────────────────────────────┘

              CloudWatch Alarm: CPU > 70%
                    │
                    ▼
              ASG scales out → launches new EC2
              ALB registers new target
              Health check passes → traffic flows
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- ALB vs NLB selection (Layer 7 vs Layer 4, static IP, protocols)
- Auto Scaling policies: target tracking vs step vs scheduled
- Multi-AZ architecture with cross-zone load balancing
- ALB path/host-based routing for microservices
- NLB for PrivateLink (cross-VPC service exposure)
- Blue/green deployment with weighted target groups
- Health check configuration and unhealthy instance replacement

### DVA-C02 (Developer)
- ALB target group types (instance, IP, Lambda)
- Sticky sessions configuration and implications
- Health check path and success codes
- User data in launch templates (bootstrap scripts)
- ALB access logs format and analysis

### SOA-C02 (SysOps)
- Troubleshooting unhealthy targets (health check config, security groups, NACLs)
- Auto Scaling cooldown tuning
- Instance refresh for rolling deployments
- Lifecycle hooks for custom launch/termination scripts
- Termination policy selection
- CloudWatch metrics: HealthyHostCount, UnHealthyHostCount, RequestCount, TargetResponseTime
- Scaling activity troubleshooting (why didn't it scale?)
- Connection draining (deregistration delay) tuning
- Cross-zone load balancing cost implications (NLB)

---

## Key Numbers

| Metric | Value |
|---|---|
| ALB routing | Layer 7 (HTTP/HTTPS) |
| NLB routing | Layer 4 (TCP/UDP/TLS) |
| GWLB routing | Layer 3 (IP) |
| NLB requests per second | Millions |
| ALB targets per target group | 1,000 |
| NLB targets per target group | 1,000 |
| ALB listener rules | 100 per listener (default) |
| NLB static IPs | 1 per AZ (can be Elastic IP) |
| Health check interval | 5-300 seconds |
| Default deregistration delay | 300 seconds |
| Max deregistration delay | 3,600 seconds |
| ASG cooldown default | 300 seconds |
| Lifecycle hook timeout | Default 1 hour, max 48 hours |
| Instance warm-up | Configurable (default varies) |
| Slow start duration | 30-900 seconds |
| ASG max instances | 500 per group (default, can increase) |
| ALB idle timeout | 60 seconds (default, 1-4000s) |
| Cross-zone (ALB) | Always on, free |
| Cross-zone (NLB) | Off by default, costs for inter-AZ |
| SNI | Multiple certs per ALB listener |

---

## Cheat Sheet

- ALB = Layer 7, smart routing (path, host, header). WebSocket, gRPC, WAF, Cognito auth.
- NLB = Layer 4, fast routing (TCP/UDP). Static IP, millions req/s, PrivateLink.
- GWLB = Layer 3, security appliances. GENEVE protocol, transparent routing.
- CLB = legacy. Don't use for new builds.
- Target Group = squad of servers. Health checks determine who gets traffic.
- Cross-zone: ALB always on (free). NLB off by default (inter-AZ costs).
- Sticky sessions = same user → same server. Risk: uneven load.
- Connection draining = 300s default. Let in-flight requests finish.
- ASG = auto-scale EC2. Min/Desired/Max capacity.
- Launch Template = modern (versioned, mixed instances). Launch Config = legacy.
- Target Tracking = simplest ("keep CPU at 70%"). Step = granular. Scheduled = predictable. Predictive = ML.
- Cooldown = 300s default. Prevents thrashing.
- Lifecycle hooks = pause launch/terminate for custom scripts.
- Instance refresh = rolling replacement of all instances.
- Termination: balance AZs first → oldest config → closest to billing hour.
- NLB + ALB combo: static IP with Layer 7 features.
- Weighted target groups = canary/blue-green at ALB level.
- Slow start mode = gradually warm up new targets (30-900s).
