# Architecture Scenarios Part 1: Web Applications & Data Pipelines

> The hardest AWS exam questions don't test one service -- they test how 4-5+ services work TOGETHER.
> This doc covers 10 multi-service architectures you MUST know cold for SAA, DVA, and SOA.

---

## How to Use This Doc

Each scenario follows this format:
1. **Scenario** -- what the business needs (exam-style phrasing)
2. **Architecture Diagram** -- ASCII showing every service and data flow
3. **Why This Architecture** -- the design decisions behind it
4. **Country Analogy** -- map it to the AWS = Country mental model
5. **Exam Question** -- real MCQ with trap analysis
6. **Which Exam** -- SAA / DVA / SOA
7. **Key Trap** -- the mistake most people make

---

## Scenario 1: Classic 3-Tier Web Application

### The Scenario

A company runs a customer-facing web application that receives variable traffic throughout the day. They need high availability, automatic scaling, fast session management, and a relational database that survives AZ failures. The application stores user sessions and must not lose session data when instances scale in.

### Architecture Diagram

```
                         ┌─────────────┐
                         │   Route 53   │
                         │  (DNS alias) │
                         └──────┬───────┘
                                │
                         ┌──────▼───────┐
                         │     ALB      │
                         │ (Internet-   │
                         │  facing)     │
                         └──┬───────┬───┘
                            │       │
                   ┌────────▼──┐ ┌──▼────────┐
                   │  AZ-1     │ │  AZ-2     │
                   │ ┌───────┐ │ │ ┌───────┐ │
                   │ │ EC2   │ │ │ │ EC2   │ │
                   │ │ (ASG) │ │ │ │ (ASG) │ │
                   │ └───┬───┘ │ │ └───┬───┘ │
                   └─────┼─────┘ └─────┼─────┘
                         │             │
              ┌──────────▼─────────────▼──────────┐
              │        ElastiCache (Redis)         │
              │   (Session Store — Multi-AZ)       │
              └──────────────┬────────────────────┘
                             │
              ┌──────────────▼────────────────────┐
              │        RDS MySQL Multi-AZ          │
              │  Primary (AZ-1) ←→ Standby (AZ-2) │
              └───────────────────────────────────┘
```

### Why This Architecture

- **ALB over NLB** -- the app is HTTP/HTTPS, needs path-based routing and sticky sessions as fallback. ALB operates at Layer 7 (application layer).
- **Auto Scaling Group across 2 AZs** -- handles traffic spikes automatically. Min 2 instances (one per AZ) ensures HA even if one AZ goes down.
- **ElastiCache Redis for sessions** -- sessions stored externally so ANY instance can serve ANY user. When ASG terminates an instance, sessions survive. Redis (not Memcached) because Redis supports Multi-AZ replication.
- **RDS Multi-AZ** -- synchronous replication to standby. Automatic failover (60-120 seconds) with no data loss. The standby is NOT a read replica -- it's a hot standby that takes over the same DNS endpoint.
- **Private subnets for EC2/RDS/ElastiCache** -- only ALB sits in public subnets. Everything else is locked behind security groups.

### Country Analogy

```
Route 53 = Ministry of Foreign Affairs (translates domain name → ALB address)
ALB = Army Base Front Gate (checks credentials, routes visitors to right building)
EC2 ASG = Soldiers on shift rotation (more soldiers during busy hours, fewer at night)
ElastiCache = Shared locker room (every soldier can access any visitor's locker)
RDS Multi-AZ = Twin command centres (if Building A is bombed, Building B takes over instantly
               with the same phone number — callers never know)
AZs = Separate military districts (earthquake in District 1 doesn't affect District 2)
```

### Exam Question

**A web application stores user sessions on individual EC2 instances behind an ALB. Users report being logged out randomly. The Auto Scaling Group frequently launches and terminates instances. How should a solutions architect fix this?**

A) Enable ALB sticky sessions (session affinity)
B) Store sessions in an ElastiCache Redis cluster
C) Store sessions in an S3 bucket
D) Increase the minimum capacity of the Auto Scaling Group

**Correct Answer: B**

- **A is wrong** -- Sticky sessions route a user to the same instance, but when that instance is terminated by ASG, the session is LOST. It's a band-aid, not a fix.
- **B is correct** -- Externalising sessions to ElastiCache means any instance can serve any user. Sessions survive instance termination. Redis supports replication for HA.
- **C is wrong** -- S3 has higher latency than ElastiCache. Session lookups happen on every request -- you need sub-millisecond response times, not S3's ~100ms.
- **D is wrong** -- More instances doesn't fix the root cause. Sessions are still stored locally. When any instance terminates (even during a deployment), sessions are lost.

### Which Exam Tests This

- **SAA-C03**: Core scenario (design for HA + elasticity)
- **SOA-C02**: Troubleshooting session loss, ASG health checks
- **DVA-C02**: Less likely, but session management with ElastiCache appears

### Key Trap

> **Sticky sessions are NOT the answer when ASG is scaling in/out.** Sticky sessions only help when instances are stable. The moment ASG terminates an instance, every user pinned to that instance loses their session. The exam LOVES putting sticky sessions as a distractor.

---

## Scenario 2: Serverless Web Application

### The Scenario

A startup wants to build a web application with zero server management. They need a static frontend, a REST API backend, a NoSQL database, and the ability to handle traffic spikes from 100 to 100,000 users without provisioning. They want to pay only for what they use.

### Architecture Diagram

```
     Users (globally)
          │
   ┌──────▼──────┐
   │  CloudFront  │ ──── Edge Caches worldwide
   │  (CDN)       │
   └──┬───────┬───┘
      │       │
      │       │  /api/* requests
      │       │
┌─────▼────┐ ┌▼──────────────┐
│  S3       │ │ API Gateway   │
│ (Static   │ │ (REST API)    │
│  website) │ │ + Cognito     │
│ React/    │ │   Authorizer  │
│ Angular   │ └───────┬───────┘
└──────────┘         │
                ┌────▼────┐
                │ Lambda  │
                │ (Node/  │
                │  Python)│
                └────┬────┘
                     │
              ┌──────▼──────┐
              │  DynamoDB    │
              │ (On-Demand)  │
              └─────────────┘
```

### Why This Architecture

- **CloudFront in front of everything** -- caches static assets at edge locations. Also forwards `/api/*` requests to API Gateway. Single domain, no CORS headaches.
- **S3 for static hosting** -- React/Angular SPA files served from S3. No web server needed. CloudFront's OAC (Origin Access Control) ensures S3 is not publicly accessible directly.
- **API Gateway + Lambda** -- fully managed, auto-scaling API. Pay per request. No idle costs. API Gateway handles throttling, request validation, and CORS.
- **Cognito Authorizer on API Gateway** -- JWT validation happens at the API Gateway level BEFORE Lambda is invoked. Unauthorized requests are rejected without costing you Lambda execution time.
- **DynamoDB On-Demand** -- scales reads/writes automatically. No capacity planning. Perfect for unpredictable traffic patterns.

### Country Analogy

```
CloudFront = Post Office network (packages delivered from nearest branch, not HQ)
S3 = National Warehouse (stores all the brochures/pamphlets — static content)
API Gateway = Reception Desk at Government Office (checks your ID via Cognito,
              routes your request to the right department)
Cognito = ID Card Issuing Office (gives you a token/badge that proves who you are)
Lambda = Magic Kitchen (chef appears only when an order comes in, disappears after)
DynamoDB = The Apartment Building (each tenant has a key-value unit, instant access,
           building grows floors automatically when needed)
```

### Exam Question

**A company deploys a serverless application using S3, API Gateway, Lambda, and DynamoDB. Users report slow initial page loads after periods of inactivity. API responses take 5-10 seconds on the first request but are fast afterwards. What should the developer do?**

A) Increase the Lambda function memory
B) Enable DynamoDB Accelerator (DAX)
C) Configure Lambda provisioned concurrency
D) Enable API Gateway caching

**Correct Answer: C**

- **A is wrong** -- More memory also means more CPU (they scale together in Lambda), which helps execution time but doesn't fix cold starts. The issue is initialisation time, not execution time.
- **B is wrong** -- DAX is a caching layer for DynamoDB reads. The bottleneck here is Lambda cold start, not DynamoDB latency. DynamoDB single-digit millisecond response isn't the 5-10 second problem.
- **C is correct** -- Provisioned concurrency keeps Lambda execution environments warm and pre-initialised. Eliminates cold starts entirely. You pay for it, but it guarantees consistent latency.
- **D is wrong** -- API Gateway caching caches responses so Lambda isn't invoked for repeated identical requests. But the FIRST request after cache expiry still hits Lambda and triggers a cold start. It reduces frequency but doesn't eliminate the problem.

### Which Exam Tests This

- **SAA-C03**: Core serverless architecture pattern
- **DVA-C02**: Heavy focus -- Lambda cold starts, provisioned concurrency, API Gateway stages
- **SOA-C02**: Monitoring Lambda with CloudWatch, API Gateway throttling

### Key Trap

> **DAX is for DynamoDB read latency, NOT Lambda cold starts.** The exam describes symptoms (slow first request, fast after) that scream "cold start" -- but DAX is a tempting distractor because it's also about caching/speed. Always identify WHERE the latency is: Lambda initialisation vs database query vs network.

---

## Scenario 3: Highly Available WordPress

### The Scenario

A media company runs a WordPress site that receives 10 million page views per month. They need the site to survive an AZ failure, handle traffic spikes during breaking news, share uploaded media across all instances, and cache database queries to reduce RDS load.

### Architecture Diagram

```
                    ┌─────────────┐
                    │  CloudFront  │ (caches images, CSS, JS)
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │     ALB      │
                    │ (HTTPS:443)  │
                    └──┬───────┬───┘
                       │       │
              ┌────────▼──┐ ┌──▼────────┐
              │   AZ-1    │ │   AZ-2    │
              │ ┌───────┐ │ │ ┌───────┐ │
              │ │ EC2   │ │ │ │ EC2   │ │
              │ │ (WP)  │ │ │ │ (WP)  │ │
              │ │ ASG   │ │ │ │ ASG   │ │
              │ └───┬───┘ │ │ └───┬───┘ │
              └─────┼─────┘ └─────┼─────┘
                    │             │
         ┌──────────┼─────────────┼──────────┐
         │          ▼             ▼           │
         │    ┌──────────────────────┐        │
         │    │   EFS (shared /wp-   │        │
         │    │   content/uploads)   │        │
         │    └──────────────────────┘        │
         │                                    │
         │    ┌──────────────────────┐        │
         │    │  ElastiCache Redis   │        │
         │    │  (WP object cache)   │        │
         │    └──────────────────────┘        │
         │                                    │
         │    ┌──────────────────────┐        │
         │    │   RDS Aurora MySQL   │        │
         │    │  Multi-AZ (writer +  │        │
         │    │  reader replicas)    │        │
         │    └──────────────────────┘        │
         └────────────────────────────────────┘
```

### Why This Architecture

- **CloudFront for static assets** -- offloads 60-80% of requests from the ALB. Images, CSS, JS cached at edge. Reduces origin load dramatically.
- **EFS, not EBS, for media uploads** -- EBS is attached to ONE instance. If User A uploads a photo to Instance 1, Instance 2 can't see it. EFS is a shared filesystem that all instances mount simultaneously. WordPress `wp-content/uploads/` lives on EFS.
- **ElastiCache for WordPress object cache** -- WordPress plugins (like W3 Total Cache or Redis Object Cache) store database query results in Redis. Reduces RDS read load by 80%+.
- **Aurora Multi-AZ over standard RDS** -- Aurora replicates 6 copies across 3 AZs automatically. Reader replicas handle read-heavy WordPress queries. Failover in <30 seconds (vs 60-120 for standard RDS).
- **ASG with target tracking on CPU** -- scales out during breaking news (CPU spikes), scales in during quiet hours.

### Country Analogy

```
CloudFront = Post Office network (delivers newspapers from nearest branch, not printing press)
ALB = Base Front Gate (routes visitors, health-checks soldiers)
EC2 ASG = Soldiers (more on duty during breaking news, fewer at night)
EFS = Shared filing cabinet (every soldier in every building reads/writes the same files)
     vs EBS = Personal locker (only one soldier can access it — useless when you have many)
ElastiCache = Cheat sheet board (common answers posted so soldiers don't keep calling HQ)
Aurora = Triple-redundant command centre (6 copies of every document across 3 districts)
```

### Exam Question

**A WordPress site runs on EC2 instances in an Auto Scaling Group. Users upload images, but some users report that uploaded images are missing. The operations team notices that images uploaded to one instance are not visible on other instances. What is the MOST operationally efficient solution?**

A) Use S3 for media storage with a WordPress S3 plugin
B) Use EFS and mount it on all instances for shared media storage
C) Use EBS Multi-Attach volumes
D) Sync files between instances using a cron job and rsync

**Correct Answer: B**

- **A is partially right but not "most operationally efficient"** -- S3 with a plugin works, but requires a WordPress plugin (WP Offload Media), URL rewriting, and plugin maintenance. EFS is transparent to WordPress -- it just mounts as a directory. However, note: on SAA, both A and B can appear. If the question says "most cost-effective" → S3. If "most operationally efficient" → EFS.
- **B is correct** -- EFS mounts as a POSIX filesystem. WordPress writes to `/wp-content/uploads/` normally. No plugin needed, no application changes. All instances see the same files instantly.
- **C is wrong** -- EBS Multi-Attach only works with io1/io2 volumes and requires a cluster-aware filesystem (like GFS2). WordPress doesn't support cluster-aware filesystems. This is a trap for people who know Multi-Attach exists but don't know its constraints.
- **D is wrong** -- Cron + rsync is a manual, fragile solution. Files are only synced on schedule (not real-time). New instances from ASG scaling won't have the files until the next sync. This is the "we did it in 2005" answer.

### Which Exam Tests This

- **SAA-C03**: EFS vs EBS vs S3 decision (extremely common)
- **SOA-C02**: EFS mount targets, NFS security groups, monitoring
- **DVA-C02**: Less likely for WordPress specifically, but EFS concepts appear

### Key Trap

> **EBS Multi-Attach is NOT a general shared filesystem.** It only works with io1/io2, only in a single AZ, and requires a cluster-aware filesystem. The exam puts it as a distractor for any "shared storage" question. Always pick EFS for shared POSIX storage across instances.

---

## Scenario 4: Global Low-Latency Application

### The Scenario

A multinational company operates in US, Europe, and Asia-Pacific. Users in each region must experience <100ms response times. The application needs a globally distributed database, static content delivery at the edge, and automatic routing to the nearest healthy region. The company requires RPO of 1 second and RTO of 1 minute.

### Architecture Diagram

```
                    ┌──────────────────┐
                    │     Route 53     │
                    │ (Latency-based   │
                    │  routing policy) │
                    └──┬─────┬─────┬──┘
                       │     │     │
          ┌────────────▼┐ ┌──▼──┐ ┌▼────────────┐
          │  us-east-1  │ │eu-  │ │ ap-south-    │
          │             │ │west │ │ east-1       │
          │ CloudFront  │ │-1   │ │              │
          │      │      │ │     │ │ CloudFront   │
          │ ┌────▼────┐ │ │     │ │      │       │
          │ │   ALB   │ │ │ ... │ │ ┌────▼────┐  │
          │ └────┬────┘ │ │     │ │ │   ALB   │  │
          │ ┌────▼────┐ │ │     │ │ └────┬────┘  │
          │ │   ASG   │ │ │     │ │ ┌────▼────┐  │
          │ └────┬────┘ │ │     │ │ │   ASG   │  │
          │      │      │ │     │ │ └────┬────┘  │
          └──────┼──────┘ └─────┘ └──────┼───────┘
                 │                        │
    ┌────────────▼────────────────────────▼──────────┐
    │           Aurora Global Database                │
    │                                                 │
    │  us-east-1 (Primary)  ←── replication ──→       │
    │  [Writer + Readers]       (< 1 second)          │
    │                                                 │
    │  eu-west-1 (Secondary)    ap-southeast-1        │
    │  [Read-only Readers]      [Read-only Readers]   │
    └─────────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────┐
    │              S3 Cross-Region Replication         │
    │  us-east-1 (source) ──→ eu-west-1 (replica)    │
    │                     ──→ ap-southeast-1 (replica)│
    └─────────────────────────────────────────────────┘
```

### Why This Architecture

- **Route 53 Latency-Based Routing** -- automatically sends users to the region with lowest network latency. Not geographic -- latency-based. A user in India routes to ap-southeast-1, a user in France routes to eu-west-1.
- **Aurora Global Database** -- replicates from a single primary region to up to 5 secondary regions with <1 second replication lag. Secondary regions serve reads locally. In a disaster, you promote a secondary to primary (RTO ~1 minute).
- **CloudFront per region** -- each region has its own CloudFront distribution (or a single global distribution). Static assets are cached at edge locations closest to users. This is about the ORIGIN being region-local, not CloudFront itself (CloudFront is always global).
- **S3 Cross-Region Replication (CRR)** -- user-uploaded content (avatars, documents) replicates to all regions. Users in Asia don't wait for S3 reads from us-east-1.
- **RPO < 1 second** -- Aurora Global Database replication lag is typically <1 second. If us-east-1 dies, you lose at most 1 second of writes.

### Country Analogy

```
Route 53 = Ministry of Foreign Affairs with latency intelligence
           (sends visitors to the nearest embassy, not the capital)
Aurora Global Database = Embassy network with real-time document sync
           (the Capital writes laws, embassies get copies in <1 second,
            if the Capital is destroyed, an embassy becomes the new Capital)
CloudFront = Local post offices in every country (deliver locally, don't fly back to HQ)
S3 CRR = Embassy document couriers (copies of all files sent to every embassy)
Regions = Countries (US, EU, APAC = three allied nations)
```

### Exam Question

**A company has users in North America, Europe, and Asia. They need sub-100ms read latency for all users with a relational database. In a regional failure, the application must recover within 1 minute with less than 1 second of data loss. Which architecture meets these requirements?**

A) RDS Multi-AZ in us-east-1 with read replicas in eu-west-1 and ap-southeast-1
B) Aurora Global Database with secondary clusters in eu-west-1 and ap-southeast-1
C) DynamoDB Global Tables across three regions
D) RDS Multi-AZ with Route 53 failover routing

**Correct Answer: B**

- **A is wrong** -- RDS cross-region read replicas use asynchronous replication with variable lag (seconds to minutes). Promoting a cross-region read replica to standalone requires manual steps and takes minutes to hours. Doesn't meet RPO <1s or RTO <1 min reliably.
- **B is correct** -- Aurora Global Database has <1 second replication lag (RPO), and secondary-to-primary promotion takes ~1 minute (RTO). Read replicas in each region serve local reads with low latency.
- **C is wrong** -- DynamoDB Global Tables would work for NoSQL, but the question says "relational database." Also, DynamoDB Global Tables is eventually consistent across regions (not <1 second guaranteed RPO for relational use cases).
- **D is wrong** -- RDS Multi-AZ is within a SINGLE region. It survives an AZ failure, not a REGION failure. Route 53 failover to... what? There's no database in the other region to fail over to.

### Which Exam Tests This

- **SAA-C03**: Heavy focus -- global architecture, Aurora Global, Route 53 routing policies, disaster recovery (RPO/RTO)
- **SOA-C02**: Aurora Global failover procedures, Route 53 health checks
- **DVA-C02**: Less likely at this architecture level

### Key Trap

> **RDS Multi-AZ is NOT multi-region.** Multi-AZ protects against AZ failure within ONE region. For multi-region disaster recovery, you need Aurora Global Database or cross-region read replicas. The exam loves confusing "Multi-AZ" with "multi-region."

---

## Scenario 5: Microservices with ECS Fargate

### The Scenario

A company is breaking a monolithic application into microservices. They need containerised services with independent scaling, path-based routing (e.g., `/users` goes to User Service, `/orders` goes to Order Service), service-to-service communication, and a managed container orchestrator without managing servers.

### Architecture Diagram

```
                    ┌──────────────┐
                    │   Route 53   │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │     ALB      │
                    │ (path-based  │
                    │  routing)    │
                    └──┬───┬───┬──┘
                       │   │   │
           ┌───────────┘   │   └───────────┐
           │               │               │
     /users/*        /orders/*       /products/*
           │               │               │
    ┌──────▼──────┐ ┌──────▼──────┐ ┌──────▼──────┐
    │ Target      │ │ Target      │ │ Target      │
    │ Group 1     │ │ Group 2     │ │ Group 3     │
    └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
           │               │               │
    ┌──────▼──────┐ ┌──────▼──────┐ ┌──────▼──────┐
    │ ECS Fargate │ │ ECS Fargate │ │ ECS Fargate │
    │ User Svc    │ │ Order Svc   │ │ Product Svc │
    │ (3 tasks)   │ │ (5 tasks)   │ │ (2 tasks)   │
    └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
           │               │               │
           └───────┬───────┘───────────────┘
                   │
        ┌──────────▼──────────┐
        │  Cloud Map          │
        │  (Service Discovery)│
        │                     │
        │  users.local        │
        │  orders.local       │
        │  products.local     │
        └─────────────────────┘
                   │
        ┌──────────▼──────────┐
        │  RDS Aurora          │
        │  (shared database    │
        │   or per-service DB) │
        └──────────────────────┘

    ┌─────────────────────────────────┐
    │  ECR (Container Registry)       │
    │  user-svc:latest                │
    │  order-svc:latest               │
    │  product-svc:latest             │
    └─────────────────────────────────┘
```

### Why This Architecture

- **ECS Fargate over ECS on EC2** -- Fargate = serverless containers. No EC2 instances to manage, patch, or scale. You define CPU/memory per task and AWS handles the rest. Use EC2 launch type only when you need GPU, specific instance types, or cost savings via Spot/Reserved.
- **ALB path-based routing** -- single ALB, multiple target groups. `/users/*` → User Service target group, `/orders/*` → Order Service. Each service scales independently behind its own target group.
- **Cloud Map for service discovery** -- when Order Service needs to call User Service internally, it resolves `users.local` via Cloud Map (AWS-managed DNS). No hardcoded IPs. Services register/deregister automatically as tasks scale.
- **ECR for container images** -- private Docker registry integrated with ECS. Images scanned for vulnerabilities. Task definitions reference ECR image URIs.
- **Per-service scaling** -- Order Service can scale to 20 tasks during Black Friday while Product Service stays at 2. Each service has its own Auto Scaling policy based on CPU, memory, or custom CloudWatch metrics.

### Country Analogy

```
ALB = Army Base Front Gate with multiple windows
      (Window 1 for citizens = /users, Window 2 for supplies = /orders)
ECS Fargate = Outsourced specialist squads (you describe the mission, Army provides soldiers)
      vs ECS on EC2 = Your own soldiers (you recruit, house, and manage them)
Target Groups = Assignment rosters (Route visitors to the right squad)
Cloud Map = Internal phone directory (squads call each other by name, not phone number)
ECR = Uniform warehouse (stores each squad's gear/uniform so new recruits can suit up fast)
Each service = Independent military unit (can grow/shrink its own headcount)
```

### Exam Question

**A company migrates a monolithic application to microservices running on Amazon ECS. Each microservice must scale independently and communicate with other services by name. External users access services through a single domain. Which combination of services should the solutions architect use?**

A) Network Load Balancer with ECS on EC2 and Route 53 private hosted zones
B) Application Load Balancer with path-based routing, ECS Fargate, and AWS Cloud Map
C) API Gateway with ECS Fargate and VPC Link
D) Application Load Balancer with host-based routing and ECS on EC2

**Correct Answer: B**

- **A is wrong** -- NLB operates at Layer 4 (TCP/UDP). It doesn't support path-based routing (`/users`, `/orders`). You'd need separate NLBs per service, defeating the "single domain" requirement. Also, Route 53 private hosted zones work but Cloud Map is purpose-built for service discovery with ECS.
- **B is correct** -- ALB supports path-based routing (single domain, multiple services). Fargate eliminates server management. Cloud Map provides native service discovery integrated with ECS.
- **C is partially valid** -- API Gateway + VPC Link works for external-to-service communication, but API Gateway adds cost per request and is designed for serverless backends (Lambda). For container microservices, ALB is more cost-effective and simpler.
- **D is close but wrong** -- Host-based routing uses different subdomains (`users.example.com`, `orders.example.com`), not path-based. The question says "single domain." Also, ECS on EC2 adds unnecessary server management overhead.

### Which Exam Tests This

- **SAA-C03**: ECS Fargate vs EC2 launch type, ALB routing, service discovery
- **DVA-C02**: ECS task definitions, container deployments, ECR, Blue/Green with CodeDeploy
- **SOA-C02**: ECS monitoring, task placement, service auto scaling

### Key Trap

> **NLB does NOT support path-based routing.** NLB is Layer 4 (TCP). ALB is Layer 7 (HTTP). Any question mentioning URL paths (`/users`, `/api/v1`) requires ALB. NLB is for extreme performance, static IPs, or non-HTTP protocols (gaming, IoT, gRPC without HTTP/2 termination).

---

## Scenario 6: Event-Driven ETL Pipeline

### The Scenario

A company receives CSV files from partners uploaded to S3. Each file must be validated, transformed, and loaded into DynamoDB. Some files are malformed and must be quarantined. The pipeline must handle retries gracefully and alert the operations team on persistent failures.

### Architecture Diagram

```
    Partner uploads CSV
           │
    ┌──────▼──────┐
    │  S3 Bucket   │
    │ (raw-uploads)│
    │              │──── S3 Event Notification
    └──────────────┘            │
                         ┌──────▼──────┐
                         │    SQS      │
                         │ (processing │
                         │  queue)     │
                         └──────┬──────┘
                                │
                         ┌──────▼──────┐
                         │   Lambda    │
                         │ (validator  │
                         │  + ETL)     │
                         └──┬──────┬───┘
                            │      │
                   Success  │      │  Failure (after retries)
                            │      │
                 ┌──────────▼┐  ┌──▼───────────┐
                 │ DynamoDB  │  │  SQS DLQ     │
                 │ (clean    │  │ (Dead Letter  │
                 │  data)    │  │  Queue)       │
                 └───────────┘  └──────┬───────┘
                                       │
                 ┌─────────────┐  ┌────▼────────┐
                 │ S3 Bucket   │  │ CloudWatch  │
                 │ (quarantine)│  │ Alarm → SNS │
                 │             │  │ → Email/    │
                 └─────────────┘  │   PagerDuty │
                                  └─────────────┘
```

### Why This Architecture

- **S3 Event → SQS (not direct to Lambda)** -- SQS decouples the upload from processing. If Lambda is throttled or erroring, messages queue up safely instead of being lost. S3 events can trigger Lambda directly, but you lose the retry/buffering benefits of SQS.
- **SQS standard queue** -- at-least-once delivery, nearly unlimited throughput. Lambda polls SQS automatically (event source mapping). Lambda processes batches of messages concurrently.
- **DLQ (Dead Letter Queue)** -- after `maxReceiveCount` attempts (e.g., 3), poison messages move to the DLQ. This prevents a single bad file from blocking the entire queue. The DLQ is a separate SQS queue.
- **Lambda idempotency is critical** -- SQS can deliver the same message more than once. Lambda must handle duplicates (e.g., use a conditional write to DynamoDB with a unique file ID to avoid double-processing).
- **CloudWatch Alarm on DLQ** -- alarm triggers when `ApproximateNumberOfMessagesVisible > 0` on the DLQ. This means something failed all retries and needs human attention.

### Country Analogy

```
S3 (raw) = Import dock (packages arrive from foreign partners)
SQS = Sorting conveyor belt (packages queue up for inspection, belt doesn't stop if inspectors are busy)
Lambda = Customs inspectors (check each package, stamp valid ones, reject bad ones)
DynamoDB = Approved goods warehouse (only clean, validated items stored here)
DLQ = Quarantine room (packages that failed inspection 3 times go here for manual review)
CloudWatch Alarm = Quarantine room alarm (buzzes when something is stuck in quarantine)
SNS = PA system (broadcasts the alarm to the duty officer's phone/email)
```

### Exam Question

**An application processes files uploaded to S3. A Lambda function reads from an SQS queue and processes each file. Occasionally, a malformed file causes the Lambda function to fail repeatedly, blocking other messages. How should the developer prevent a single bad file from blocking the queue?**

A) Increase the Lambda function timeout
B) Configure a dead-letter queue on the SQS queue with a maxReceiveCount of 3
C) Enable SQS FIFO queue to process messages in order
D) Increase the SQS visibility timeout

**Correct Answer: B**

- **A is wrong** -- A longer timeout doesn't help if the file is malformed. The function will still fail, just slower. It wastes Lambda execution time.
- **B is correct** -- After 3 failed attempts, the message moves to the DLQ. The main queue continues processing other messages. The bad file is isolated for investigation.
- **C is wrong** -- FIFO would make it WORSE. FIFO processes messages in strict order. If message 1 keeps failing, messages 2, 3, 4... are all blocked behind it. Standard queue at least allows other messages to be processed in parallel.
- **D is wrong** -- Visibility timeout controls how long a message is invisible after being read. Increasing it prevents duplicate processing but doesn't remove the poison message. After visibility timeout expires, the same bad message comes back.

### Which Exam Tests This

- **DVA-C02**: Core scenario -- SQS, DLQ, Lambda event source mapping, idempotency
- **SAA-C03**: Event-driven architecture, decoupling with SQS
- **SOA-C02**: Monitoring DLQ depth, CloudWatch alarms on SQS metrics

### Key Trap

> **FIFO queues make blocking WORSE, not better.** FIFO guarantees order, which means a failing message blocks everything behind it in the same message group. Standard queues process messages independently -- a bad message only blocks itself. The exam asks about "blocking" to trick you into thinking order matters.

---

## Scenario 7: Log Analytics Pipeline

### The Scenario

A company needs to collect application logs from hundreds of EC2 instances, aggregate them in near real-time, store them cost-effectively for long-term analysis, and allow business analysts to run SQL queries and build dashboards without managing servers.

### Architecture Diagram

```
    EC2 Instances (hundreds)
    ┌──────┐ ┌──────┐ ┌──────┐
    │ App  │ │ App  │ │ App  │ ...
    │ Logs │ │ Logs │ │ Logs │
    └──┬───┘ └──┬───┘ └──┬───┘
       │        │        │
       └────────┼────────┘
                │
    ┌───────────▼───────────┐
    │  CloudWatch Logs      │
    │  (Log Groups)         │
    │  /app/production      │
    └───────────┬───────────┘
                │
                │ Subscription Filter
                │
    ┌───────────▼───────────┐
    │  Kinesis Data Firehose │
    │  (delivery stream)     │
    │                        │
    │  - Buffers (60s/5MB)   │
    │  - Optional transform  │
    │    via Lambda          │
    │  - Converts to Parquet │
    └─────────┬─────────────┘
              │
    ┌─────────▼─────────────┐
    │  S3 Bucket             │
    │  (logs-archive)        │
    │                        │
    │  Lifecycle:            │
    │  - 30d: S3 Standard    │
    │  - 90d: S3 IA          │
    │  - 365d: S3 Glacier    │
    └─────────┬─────────────┘
              │
    ┌─────────▼─────────────┐
    │  AWS Glue Crawler      │
    │  (discovers schema     │
    │   from Parquet files)  │
    └─────────┬─────────────┘
              │
    ┌─────────▼─────────────┐
    │  Athena                │
    │  (SQL queries on S3)   │
    │  - Serverless          │
    │  - Pay per query       │
    │  - Uses Glue Data      │
    │    Catalog             │
    └─────────┬─────────────┘
              │
    ┌─────────▼─────────────┐
    │  QuickSight            │
    │  (BI dashboards)       │
    └────────────────────────┘
```

### Why This Architecture

- **CloudWatch Logs Agent on EC2** -- the unified CloudWatch agent collects logs and ships them to CloudWatch Log Groups. No custom log aggregation infrastructure needed.
- **Kinesis Data Firehose (not Kinesis Data Streams)** -- Firehose is fully managed, auto-scales, and delivers to S3/Redshift/OpenSearch automatically. No shard management. You want Firehose when the destination is S3. Use Data Streams when you need real-time processing with custom consumers.
- **Parquet format** -- Firehose can convert JSON/CSV to Parquet (columnar format). Athena queries on Parquet are 30-90% cheaper and 10x faster than querying raw JSON because Athena scans only needed columns.
- **S3 lifecycle policies** -- recent logs in Standard (fast access), older logs in IA (cheaper, slightly slower), ancient logs in Glacier (archive pricing). This optimises storage cost over time.
- **Athena + Glue Catalog** -- Glue Crawler auto-discovers schema from Parquet files in S3. Athena queries S3 directly using that schema. No ETL into a database. Serverless, pay per TB scanned.

### Country Analogy

```
CloudWatch Logs = Field reports from every soldier (every instance sends activity reports)
Kinesis Firehose = Army postal service (automatically collects reports, bundles them,
                   delivers to the archive — you don't manage the postal workers)
     vs Kinesis Data Streams = Your own courier network (you hire couriers/shards,
                                manage capacity yourself — more control, more work)
S3 = National Archive (all reports stored permanently, older ones moved to cheaper basement vaults)
Glue Crawler = Archivist (reads reports and creates a catalogue/index of what's in them)
Athena = Research desk (analysts ask questions about the archive using SQL,
         pay per question, no building to maintain)
QuickSight = War room dashboard (visual charts on the big screen for generals)
```

### Exam Question

**A company needs to analyze application logs stored in Amazon S3 using SQL queries. They want a serverless solution that minimizes cost. The logs are currently stored as JSON files. What should the solutions architect recommend to reduce query costs?**

A) Load the logs into Amazon Redshift and query there
B) Convert logs to Apache Parquet format and query with Amazon Athena
C) Use Amazon EMR with Apache Spark to query the JSON files
D) Import logs into Amazon RDS and run SQL queries

**Correct Answer: B**

- **A is wrong** -- Redshift is a data warehouse, not serverless. It runs on provisioned clusters (you pay per hour even when not querying). Overkill and expensive for log analysis.
- **B is correct** -- Parquet is columnar: Athena only reads the columns you SELECT, not the entire file. JSON is row-based: Athena must scan every byte. Parquet reduces data scanned = reduces cost (Athena charges $5/TB scanned). Athena is serverless.
- **C is wrong** -- EMR requires managing a Hadoop/Spark cluster. Not serverless. More operational overhead and cost than Athena for ad-hoc queries.
- **D is wrong** -- RDS is a transactional database, not designed for analytics on large log datasets. Import would be slow, schema management is painful, and it doesn't scale for TB-scale log analysis.

### Which Exam Tests This

- **SAA-C03**: Core analytics pattern -- Kinesis Firehose → S3 → Athena
- **SOA-C02**: CloudWatch Logs subscription filters, Firehose monitoring, S3 lifecycle
- **DVA-C02**: Less likely for the full pipeline, but Athena + S3 query patterns appear

### Key Trap

> **Kinesis Data Firehose vs Kinesis Data Streams -- know the difference.** Firehose = managed delivery to S3/Redshift/OpenSearch, no coding, no shards. Data Streams = real-time processing with custom consumers (Lambda, KCL apps), you manage shards. If the question says "deliver to S3" → Firehose. If "real-time processing with multiple consumers" → Data Streams.

---

## Scenario 8: Real-Time Clickstream Analytics

### The Scenario

An e-commerce company wants to capture every user click (page views, add-to-cart, purchases) in real time. They need to update a real-time dashboard showing trending products, archive all events to S3 for later analysis, and trigger personalised recommendations within 2 seconds of a user action.

### Architecture Diagram

```
    Web/Mobile Clients
    ┌──────┐ ┌──────┐ ┌──────┐
    │Click │ │Click │ │Click │
    └──┬───┘ └──┬───┘ └──┬───┘
       │        │        │
       └────────┼────────┘
                │
    ┌───────────▼────────────────┐
    │  API Gateway (HTTP API)    │
    │  + Kinesis Integration     │
    │  (direct, no Lambda)       │
    └───────────┬────────────────┘
                │
    ┌───────────▼────────────────┐
    │  Kinesis Data Streams      │
    │  (clickstream-events)      │
    │  [4 shards = 4MB/s write]  │
    └──┬────────┬────────┬───────┘
       │        │        │
       │        │        │  ← 3 consumers (fan-out)
       │        │        │
┌──────▼──────┐ │  ┌─────▼──────────┐
│ Lambda      │ │  │ Kinesis Data   │
│ Consumer 1  │ │  │ Firehose       │
│ (real-time  │ │  │ Consumer 3     │
│  trending   │ │  │ (S3 archive)   │
│  update)    │ │  └────────┬───────┘
└──────┬──────┘ │           │
       │        │    ┌──────▼──────┐
┌──────▼──────┐ │    │ S3 (archive)│
│ DynamoDB    │ │    │ Parquet     │
│ (trending   │ │    └─────────────┘
│  products   │ │
│  table)     │ │
└─────────────┘ │
                │
       ┌────────▼────────┐
       │ Lambda           │
       │ Consumer 2       │
       │ (personalisation │
       │  engine)         │
       └────────┬─────────┘
                │
       ┌────────▼─────────┐
       │ DynamoDB          │
       │ (user-            │
       │  recommendations) │
       └──────────────────┘
```

### Why This Architecture

- **Kinesis Data Streams, not SQS** -- Kinesis supports multiple consumers reading the same data independently (fan-out). SQS delivers each message to ONE consumer only. Clickstream data needs to go to real-time processing AND archive AND recommendations simultaneously.
- **API Gateway → Kinesis (direct integration)** -- API Gateway can write directly to Kinesis via service integration, no Lambda in between. This reduces latency and cost for high-volume ingestion (thousands of events/second).
- **Enhanced Fan-Out** -- each consumer gets dedicated 2MB/s read throughput per shard. Without enhanced fan-out, all consumers share 2MB/s per shard. Critical when you have 3+ consumers.
- **DynamoDB for trending** -- Lambda aggregates click counts per product in DynamoDB using atomic counters (`ADD` operation). The real-time dashboard reads from this table. DynamoDB's single-digit ms latency makes the dashboard feel instant.
- **Firehose for archive** -- runs as a separate consumer, buffering events and writing to S3 in Parquet format. This is the "we'll analyse it later" path.

### Country Analogy

```
Kinesis Data Streams = Live TV broadcast (multiple viewers watch the same stream simultaneously)
     vs SQS = Letter delivery (each letter goes to one recipient only — can't broadcast)
Shards = TV channels (more channels = more bandwidth, but you manage channel count)
Enhanced Fan-Out = Dedicated TV cable per viewer (each viewer gets full HD, not shared bandwidth)
Lambda Consumer 1 = Intelligence analyst (watches live feed, updates trending board in real-time)
Lambda Consumer 2 = Personal adviser (watches what each citizen does, recommends next action)
Firehose = Archivist with a video recorder (records everything for the national archive)
DynamoDB = Real-time scoreboard (updated every second, visible to everyone)
```

### Exam Question

**An e-commerce application captures clickstream data and needs to process it with three independent consumers simultaneously: real-time analytics, personalisation, and archival to S3. The system handles 10,000 events per second. Which ingestion service should be used?**

A) Amazon SQS with three separate queues
B) Amazon SNS with three SQS subscriptions
C) Amazon Kinesis Data Streams with enhanced fan-out
D) Amazon SQS FIFO queue with three consumers

**Correct Answer: C**

- **A is wrong** -- Three separate SQS queues means you need to publish each event to all three queues. Who does the fan-out? You'd need SNS in front (option B). SQS alone doesn't broadcast.
- **B is close but wrong** -- SNS → 3 SQS queues works for fan-out, but SNS + SQS is for event notification, not high-throughput streaming. At 10,000 events/second, Kinesis is purpose-built. SNS also has a max message size of 256KB and wasn't designed for continuous data streams. Plus, this pattern loses ordering.
- **C is correct** -- Kinesis Data Streams is designed for real-time streaming with multiple consumers. Enhanced fan-out gives each consumer dedicated throughput. Handles 10K+ events/second easily with enough shards.
- **D is wrong** -- FIFO queues have a limit of 300 messages/second (3,000 with batching per message group). Can't handle 10,000 events/second. Also, SQS (FIFO or standard) delivers each message to ONE consumer, not three.

### Which Exam Tests This

- **SAA-C03**: Kinesis vs SQS vs SNS decision, fan-out patterns
- **DVA-C02**: Kinesis producer/consumer code, shard management, enhanced fan-out
- **SOA-C02**: Kinesis monitoring, shard splitting, CloudWatch metrics for Kinesis

### Key Trap

> **SQS is point-to-point. Kinesis is fan-out.** SQS delivers each message to ONE consumer. If you need multiple consumers processing the SAME data, you need either Kinesis Data Streams or SNS fan-out to multiple SQS queues. The exam describes "multiple consumers" to test whether you pick SQS (wrong) or Kinesis (right).

---

## Scenario 9: Event-Driven Order Processing

### The Scenario

An e-commerce company processes orders through multiple steps: validate payment, check inventory, charge credit card, update inventory, and send confirmation email. Each step can fail independently. The company needs automatic retries, error handling per step, and the ability to add new steps (like fraud detection) without changing existing code.

### Architecture Diagram

```
    Customer places order
           │
    ┌──────▼──────────┐
    │  API Gateway     │
    │  (POST /orders)  │
    └──────┬───────────┘
           │
    ┌──────▼──────────┐
    │  SQS             │
    │  (order-queue)   │ ← Buffer: survives API Gateway timeout
    └──────┬───────────┘
           │
    ┌──────▼──────────────────────────────────────────────┐
    │  Step Functions (Standard Workflow)                   │
    │                                                      │
    │  ┌─────────────┐                                     │
    │  │ Validate    │                                     │
    │  │ Payment     │──── Fail → Notify customer          │
    │  │ (Lambda)    │                                     │
    │  └──────┬──────┘                                     │
    │         │ Pass                                        │
    │  ┌──────▼──────┐                                     │
    │  │ Check       │                                     │
    │  │ Inventory   │──── Fail → Backorder (wait state)   │
    │  │ (Lambda)    │              │                       │
    │  └──────┬──────┘         Wait 1 hour → retry         │
    │         │ Pass                                        │
    │  ┌──────▼──────┐                                     │
    │  │ Charge      │                                     │
    │  │ Card        │──── Fail → Retry 3x → Refund path  │
    │  │ (Lambda)    │                                     │
    │  └──────┬──────┘                                     │
    │         │ Pass                                        │
    │  ┌──────▼──────┐                                     │
    │  │ Update      │                                     │
    │  │ Inventory   │ (DynamoDB)                           │
    │  │ (Lambda)    │                                     │
    │  └──────┬──────┘                                     │
    │         │ Pass                                        │
    │  ┌──────▼──────┐                                     │
    │  │ Send        │                                     │
    │  │ Confirmation│ (SNS → SES email)                   │
    │  │ (Lambda)    │                                     │
    │  └─────────────┘                                     │
    │                                                      │
    └──────────────────────────────────────────────────────┘
           │
           │ On any unhandled failure
           │
    ┌──────▼──────┐     ┌─────────────┐
    │ SNS Topic   │────▶│ Ops Team    │
    │ (alerts)    │     │ PagerDuty   │
    └─────────────┘     └─────────────┘
```

### Why This Architecture

- **SQS between API Gateway and Step Functions** -- API Gateway has a 29-second timeout. Order processing takes longer. SQS decouples the request (API returns 202 Accepted immediately) from processing. The customer doesn't wait.
- **Step Functions Standard (not Express)** -- Standard Workflows run up to 1 year, have exactly-once execution, and maintain full execution history. Express Workflows are for high-volume, short-duration (5 min max), at-least-once. Order processing needs reliability and auditability → Standard.
- **Per-step error handling** -- Step Functions lets you define Catch and Retry at each state. Payment validation failure → notify customer. Inventory check failure → wait and retry. Card charge failure → retry 3x then refund. Each step has its own failure path.
- **Lambda for each step** -- each step is a small, focused Lambda function. Adding fraud detection means adding a new Lambda + a new state in the Step Functions definition. Zero changes to existing Lambda code.
- **SNS for notifications** -- SNS fans out: email via SES, SMS, push notifications, or webhook to PagerDuty. Adding a notification channel means adding an SNS subscription, not changing code.

### Country Analogy

```
API Gateway = Front desk (takes the order, hands you a receipt number, says "we'll process it")
SQS = Order filing cabinet (orders queue up safely even if the processing office is busy)
Step Functions = Assembly line supervisor (knows the exact order of operations,
                 handles errors at each station, can pause and resume)
Each Lambda = Specialist worker at one station on the assembly line:
  - Station 1: Payment clerk (validates credit card)
  - Station 2: Warehouse checker (is it in stock?)
  - Station 3: Cashier (charges the card)
  - Station 4: Stock updater (removes item from inventory count)
  - Station 5: Mail room (sends confirmation)
SNS = PA system (announces order status to customer, ops team, warehouse)
```

### Exam Question

**A company needs to orchestrate a multi-step order processing workflow where each step is a Lambda function. Some steps require waiting for human approval, and the workflow must maintain state for up to 30 days. The solution must provide visual tracking of each order's progress. Which service should be used?**

A) Amazon SQS with Lambda polling and DynamoDB for state management
B) AWS Step Functions Standard Workflow
C) AWS Step Functions Express Workflow
D) Amazon EventBridge with Lambda targets

**Correct Answer: B**

- **A is wrong** -- Building your own workflow engine with SQS + DynamoDB works but is significant custom development. You'd need to manage state transitions, error handling, retries, and wait states yourself. Step Functions does this natively. Also, no visual tracking out of the box.
- **B is correct** -- Standard Workflows support up to 1-year execution, human approval (callback/task tokens), visual execution history in the console, and built-in error handling per step.
- **C is wrong** -- Express Workflows have a 5-minute maximum duration. The question requires 30 days. Express is for high-volume, short-duration workflows (e.g., IoT data processing, streaming transforms). Not for long-running order processing.
- **D is wrong** -- EventBridge triggers Lambda functions based on events, but it doesn't orchestrate a sequence of steps, maintain state between steps, or provide wait states. It's event routing, not workflow orchestration.

### Which Exam Tests This

- **DVA-C02**: Heavy focus -- Step Functions state machine definition, error handling, task tokens, Standard vs Express
- **SAA-C03**: Decoupling, event-driven design, choosing Step Functions vs SQS vs EventBridge
- **SOA-C02**: Monitoring Step Functions executions, CloudWatch integration

### Key Trap

> **Step Functions Standard vs Express -- know the limits.** Standard: up to 1 year, exactly-once, 2,000 executions/sec, billed per state transition. Express: up to 5 minutes, at-least-once, 100,000 executions/sec, billed per execution+duration. If the question mentions "long-running" or "days/weeks" → Standard. If "high-volume" or "milliseconds" → Express.

---

## Scenario 10: Serverless Data Lake

### The Scenario

A company collects data from multiple sources (CSV files, JSON APIs, database exports) into S3. Business analysts need to query this data using standard SQL without managing any infrastructure. The data team needs automated schema discovery, ETL transformations, and interactive dashboards for executives.

### Architecture Diagram

```
    Data Sources
    ┌──────────┐  ┌──────────┐  ┌──────────┐
    │ CSV from │  │ JSON from│  │ DB Export │
    │ partners │  │ APIs     │  │ (mysqldump│
    └────┬─────┘  └────┬─────┘  └────┬─────┘
         │             │              │
         └─────────────┼──────────────┘
                       │
              ┌────────▼────────┐
              │   S3 Raw Zone   │ (landing bucket, original format)
              │  s3://data-lake │
              │  /raw/          │
              └────────┬────────┘
                       │
              ┌────────▼────────┐
              │  Glue Crawler   │ (scheduled: runs daily)
              │                 │
              │  - Scans S3     │
              │  - Detects      │
              │    schema       │
              │  - Updates Glue │
              │    Data Catalog │
              └────────┬────────┘
                       │
              ┌────────▼────────┐
              │  Glue Data      │
              │  Catalog        │ ← Central metadata store
              │                 │   (tables, schemas, partitions)
              │  databases:     │
              │  - raw_db       │
              │  - clean_db     │
              └────────┬────────┘
                       │
              ┌────────▼────────┐
              │  Glue ETL Job   │ (PySpark / Python Shell)
              │                 │
              │  - Read from    │
              │    raw zone     │
              │  - Clean,       │
              │    deduplicate, │
              │    transform    │
              │  - Write to     │
              │    clean zone   │
              │    (Parquet,    │
              │     partitioned)│
              └────┬───────┬────┘
                   │       │
         ┌─────────▼┐  ┌──▼──────────┐
         │ S3 Clean │  │ S3 Curated  │
         │ Zone     │  │ Zone        │
         │ /clean/  │  │ /curated/   │
         │ (Parquet)│  │ (aggregated)│
         └─────┬────┘  └──────┬──────┘
               │               │
               └───────┬───────┘
                       │
              ┌────────▼────────┐
              │  Amazon Athena  │ (serverless SQL)
              │                 │
              │  SELECT *       │
              │  FROM clean_db  │
              │  .orders        │
              │  WHERE year=2024│
              │  AND month=12   │
              └────────┬────────┘
                       │
              ┌────────▼────────┐
              │  QuickSight     │
              │  (BI Dashboard) │
              │                 │
              │  - Connects to  │
              │    Athena       │
              │  - SPICE for    │
              │    fast visuals │
              │  - Shared with  │
              │    executives   │
              └─────────────────┘
```

### Why This Architecture

- **S3 as the data lake foundation** -- S3 is the de facto data lake storage on AWS. Unlimited scale, $0.023/GB/month (Standard), supports any format. The data lake pattern uses S3 "zones": raw (as-is), clean (validated/transformed), curated (aggregated/business-ready).
- **Glue Crawler for schema discovery** -- crawls S3, infers schema (column names, types, partitions), and populates the Glue Data Catalog. No manual schema management. Re-runs detect schema changes automatically.
- **Glue Data Catalog as central metastore** -- a Hive-compatible metadata store. Athena, Redshift Spectrum, EMR, and Glue ETL all use it. Define the schema once, query from anywhere.
- **Glue ETL for transformation** -- serverless Spark jobs. Reads raw data, applies transformations (dedup, type casting, null handling), writes clean Parquet files partitioned by date. No EMR cluster to manage.
- **Athena for queries** -- serverless, pay $5/TB scanned. Parquet + partitioning reduces scanned data by 90%+. Partitioning by year/month means `WHERE year=2024 AND month=12` only scans that partition, not all data.
- **QuickSight SPICE** -- in-memory calculation engine. Imports data from Athena into SPICE for sub-second dashboard refresh. Executives don't wait for Athena queries.

### Country Analogy

```
S3 Raw Zone = National dock (everything arrives here in its original packaging — CSV boxes,
              JSON crates, database dump barrels)
Glue Crawler = Customs inspector (opens each container, catalogues what's inside,
               writes it in the national registry)
Glue Data Catalog = National Registry (the official record of everything in the country —
                    what it is, what format, where it's stored)
Glue ETL = Processing factory (takes raw imports, cleans, standardises, repackages
           into efficient Parquet pallets organised by date)
S3 Clean Zone = Organised warehouse (everything clean, labelled, on shelved aisles by date)
Athena = Research library with a search desk (analysts ask SQL questions,
         librarian only opens the relevant shelves — pays per shelf opened)
QuickSight = Executive war room (charts on the big screen, updated automatically,
             generals make decisions based on what they see)
Partitioning = Warehouse aisles (searching aisle "2024/December" is 100x faster
               than searching the entire warehouse)
```

### Exam Question

**A company stores 10TB of raw CSV data in S3. Business analysts want to run SQL queries on this data. The queries typically filter by date (year and month). What should a solutions architect recommend to minimise query cost?**

A) Load the data into Amazon Redshift and query there
B) Use Amazon Athena to query the CSV files directly
C) Use AWS Glue to convert CSV to Parquet partitioned by year and month, then query with Athena
D) Use Amazon EMR with Hive to query the CSV files

**Correct Answer: C**

- **A is wrong** -- Redshift works but requires provisioned clusters ($$$). Not serverless. The question asks to minimise cost, and Redshift has a baseline cost even when not querying.
- **B is partially right but expensive** -- Athena CAN query CSV, but CSV is row-based. Athena scans every byte of every file. 10TB of CSV = $50 per full scan query. That adds up fast.
- **C is correct** -- Parquet is columnar (scan only needed columns, ~90% less data). Partitioning by year/month means queries with `WHERE year=2024 AND month=12` skip all other partitions. Combined: 10TB CSV → ~1TB Parquet → query scans ~30GB for one month = $0.15 per query instead of $50.
- **D is wrong** -- EMR requires managing a Hadoop cluster. Not serverless, not minimising cost. EMR + Hive works but is overkill for SQL queries on S3. Athena is EMR under the hood but fully managed.

### Which Exam Tests This

- **SAA-C03**: Core data lake pattern, Glue + Athena + S3, cost optimisation
- **SOA-C02**: Glue job monitoring, crawler scheduling, Athena query performance
- **DVA-C02**: Less likely for the full pipeline, but Athena query patterns and Glue triggers appear

### Key Trap

> **Athena on raw CSV is valid but expensive.** The exam loves offering "Athena on CSV" as a distractor. Yes, Athena can query CSV, JSON, and almost any format. But the cost question is about DATA SCANNED. CSV = scan everything. Parquet + partitioning = scan almost nothing. Always convert to Parquet and partition when cost is a concern.

---

## Quick Reference: Which Service When?

| Need | Service | NOT This |
|------|---------|----------|
| Shared file storage across instances | **EFS** | EBS (single instance), S3 (not POSIX) |
| Session storage | **ElastiCache Redis** | DynamoDB (higher latency), sticky sessions (fragile) |
| Fan-out to multiple consumers | **Kinesis Data Streams** | SQS (point-to-point) |
| Deliver streaming data to S3 | **Kinesis Firehose** | Kinesis Data Streams (need custom consumer) |
| Multi-step workflow with state | **Step Functions** | SQS + DynamoDB (DIY pain) |
| SQL on S3 data | **Athena** | Redshift (not serverless), RDS (not for analytics) |
| Schema discovery on S3 | **Glue Crawler** | Manual DDL (doesn't scale) |
| Global database <1s RPO | **Aurora Global Database** | RDS read replicas (variable lag) |
| Path-based URL routing | **ALB** | NLB (Layer 4, no URL awareness) |
| Container orchestration, no servers | **ECS Fargate** | ECS on EC2 (you manage instances) |
| Eliminate Lambda cold starts | **Provisioned Concurrency** | DAX (that's for DynamoDB) |

---

## Exam Day Cheat Sheet

**When you see "decouple"** → SQS or EventBridge
**When you see "fan-out"** → SNS or Kinesis Data Streams
**When you see "orchestrate"** → Step Functions
**When you see "real-time stream"** → Kinesis Data Streams
**When you see "deliver to S3"** → Kinesis Firehose
**When you see "SQL on S3"** → Athena
**When you see "schema discovery"** → Glue Crawler
**When you see "shared filesystem"** → EFS
**When you see "session store"** → ElastiCache Redis
**When you see "global, <100ms"** → Aurora Global + CloudFront + Route 53 latency
**When you see "cost-effective analytics"** → Parquet + Partitioning + Athena
**When you see "serverless containers"** → Fargate
**When you see "path-based routing"** → ALB
**When you see "multiple consumers, same data"** → Kinesis (not SQS)
**When you see "long-running workflow"** → Step Functions Standard
**When you see "high-volume short workflow"** → Step Functions Express
