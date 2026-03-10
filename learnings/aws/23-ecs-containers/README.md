# ECS & Containers — Container Ships

> **ECS is the country's shipping port. Task Definitions are manifests, Tasks are shipments, Services schedule recurring deliveries, and Fargate means you rent the ship instead of owning one.**

---

## ELI10

Imagine a massive shipping port where goods arrive in standard-sized containers. Every shipment needs a manifest — a paper that lists what's inside each container, how heavy it is, and where it goes. A "task" is one shipment being delivered right now. A "service" is a schedule that says "deliver 3 shipments of groceries every day, forever." The "cluster" is the port facility itself. With EC2 launch type, you own the ships and maintain them. With Fargate, you just hand over your containers and AWS drives the ship for you.

---

## The Concept

### ECS (Elastic Container Service) = The Shipping Port

```
┌──────────────────────────────────────────────────────────────┐
│                        ECS CLUSTER (The Port)                 │
│                                                               │
│  ┌─────────────────────┐    ┌─────────────────────┐          │
│  │  EC2 Launch Type     │    │  Fargate Launch Type │          │
│  │  (Own Your Ships)    │    │  (Rent a Ship)       │          │
│  │                      │    │                      │          │
│  │  ┌──────┐ ┌──────┐  │    │  ┌──────┐ ┌──────┐  │          │
│  │  │Task 1│ │Task 2│  │    │  │Task 3│ │Task 4│  │          │
│  │  │      │ │      │  │    │  │      │ │      │  │          │
│  │  └──────┘ └──────┘  │    │  └──────┘ └──────┘  │          │
│  │                      │    │                      │          │
│  │  EC2 Instance 1      │    │  (No instances to    │          │
│  │  EC2 Instance 2      │    │   manage — AWS does  │          │
│  │  (You patch, scale)  │    │   it all)            │          │
│  └─────────────────────┘    └─────────────────────┘          │
│                                                               │
│  ┌─────────────────────────────────────────────────┐         │
│  │  Service: "Run 3 copies of web-app at all times" │         │
│  │  → Auto-replaces failed tasks                     │         │
│  │  → Integrates with ALB for load balancing         │         │
│  └─────────────────────────────────────────────────┘         │
└──────────────────────────────────────────────────────────────┘
```

### Core Components

| Component | Analogy | What It Is |
|-----------|---------|------------|
| **Cluster** | The port facility | Logical grouping of tasks/services. Can span EC2 + Fargate. |
| **Task Definition** | Shipping manifest | JSON template: which Docker images, CPU, memory, ports, env vars, volumes |
| **Task** | One shipment in transit | Running instance of a task definition (1+ containers) |
| **Service** | Recurring delivery schedule | Maintains desired count of tasks, handles replacement, integrates with ALB |
| **Container Instance** | A ship (EC2 only) | EC2 instance registered to the cluster, runs the ECS agent |

### Task Definition — The Manifest

```json
{
  "family": "web-app",
  "taskRoleArn": "arn:aws:iam::123456789012:role/ecsTaskRole",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "networkMode": "awsvpc",
  "containerDefinitions": [
    {
      "name": "app",
      "image": "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/web-app:latest",
      "cpu": 256,
      "memory": 512,
      "portMappings": [{ "containerPort": 3000 }],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/web-app",
          "awslogs-region": "ap-southeast-2"
        }
      }
    }
  ],
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512"
}
```

### Task Role vs Execution Role (CRITICAL EXAM TOPIC)

```
┌─────────────────────────────────────────────────────────┐
│                                                          │
│  Task Execution Role                Task Role            │
│  (The dock worker)                  (The cargo itself)   │
│                                                          │
│  Needed BY ECS to:                  Needed BY YOUR CODE: │
│  • Pull images from ECR             • Call DynamoDB      │
│  • Push logs to CloudWatch          • Write to S3        │
│  • Pull secrets from                • Invoke Lambda      │
│    Secrets Manager                  • Send SQS messages  │
│  • Pull params from SSM                                  │
│                                                          │
│  WHO uses it: ECS agent             WHO uses it: App code│
│  WHEN: Before/during launch         WHEN: At runtime     │
└─────────────────────────────────────────────────────────┘
```

**Exam trap:** If your container can't pull images from ECR → fix the **Execution Role**.
If your app code can't write to DynamoDB → fix the **Task Role**.

### EC2 vs Fargate Decision Tree

```
                    Need containers?
                         │
                         v
              ┌─── Do you need ───┐
              │   full control?    │
              │                    │
              v                    v
        EC2 Launch Type      Fargate Launch Type
        ┌──────────────┐     ┌──────────────┐
        │ You manage:   │     │ AWS manages:  │
        │ • EC2 scaling │     │ • All infra   │
        │ • OS patching │     │ • Scaling     │
        │ • ECS agent   │     │ • Patching    │
        │               │     │               │
        │ Good for:     │     │ Good for:     │
        │ • GPU tasks   │     │ • Most apps   │
        │ • Spot pricing│     │ • Micro-svc   │
        │ • Custom AMI  │     │ • Quick start │
        │ • Cost control│     │ • Less ops    │
        │   at scale    │     │               │
        └──────────────┘     └──────────────┘
```

### ECR (Elastic Container Registry) = Container Warehouse

```
┌────────────────────────────────────────────┐
│                  ECR                         │
│                                              │
│  Repository: web-app                         │
│  ├── web-app:latest                          │
│  ├── web-app:v1.2.3                          │
│  └── web-app:v1.2.2                          │
│                                              │
│  Features:                                   │
│  • Image scanning (vulnerability detection)  │
│  • Lifecycle policies (auto-delete old imgs) │
│  • Cross-region replication                  │
│  • Cross-account access (resource policies)  │
│  • Immutable image tags (prevent overwrite)  │
│  • Encryption at rest (AES-256 or KMS)       │
└────────────────────────────────────────────┘
```

### EKS (Elastic Kubernetes Service) = Kubernetes Port

EKS is for when you want **Kubernetes** (the open-source orchestrator) instead of AWS's proprietary ECS. Same ships, different port management system.

| | ECS | EKS |
|---|-----|-----|
| Orchestrator | AWS proprietary | Kubernetes (open-source) |
| Learning curve | Lower | Higher |
| Portability | AWS-only | Multi-cloud |
| Pricing | No control plane cost | $0.10/hour for control plane |
| Best for | AWS-native shops | K8s expertise, multi-cloud |

### App Runner = Simplest Container Service

```
You → Push code/image → App Runner → Running app with URL
                          │
                          └── Auto-scales, HTTPS, load balancing, deployments
                              No cluster, no task definitions, no services to manage
```

Think of App Runner as **Uber for containers** — just tell it where you want to go (your code), and it handles everything.

### Capacity Providers

```
┌───────────────────────────────────────┐
│         Capacity Providers             │
│                                        │
│  Fargate          → Serverless tasks   │
│  Fargate Spot     → Cheap serverless   │
│  Auto Scaling     → EC2 instances that │
│   Group Provider     scale with demand  │
│                                        │
│  Strategy: spread, binpack, random     │
│  • spread: distribute across AZs       │
│  • binpack: pack tightly (save $$$)    │
│  • random: random placement            │
└───────────────────────────────────────┘
```

### Service Discovery

ECS integrates with **AWS Cloud Map** for service discovery:
- Services register themselves with DNS names
- Other services find them via DNS lookup
- Example: `web-app.local` → resolves to task IPs
- Uses Route 53 private hosted zones under the hood

### ECS Anywhere

Run ECS tasks on **your own servers** (on-premises). The ECS agent runs on your hardware, registers with an ECS cluster, and receives task assignments just like EC2 instances. Think of it as: franchise ports that follow the same shipping rules but on your own land.

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- **Fargate vs EC2 decision** — when to choose each (most questions prefer Fargate for "least operational overhead")
- **ALB integration** with ECS services (dynamic port mapping)
- **Task Role vs Execution Role** — which solves which problem
- **ECS vs EKS** — when to choose Kubernetes
- **App Runner** for simplest container deployment

### DVA-C02 (Developer)
- **Task definitions** — JSON structure, container definitions, port mappings
- **ECR** — push/pull images, lifecycle policies, image scanning
- **Service discovery** via Cloud Map
- **Logging** — awslogs driver, CloudWatch Logs integration
- **Task Role** for application permissions

### SOA-C02 (SysOps)
- **Capacity providers** — Fargate Spot, ASG providers, placement strategies
- **Service auto-scaling** — target tracking, step scaling
- **Troubleshooting:** task won't start (image pull fails = execution role, port conflicts, insufficient resources)
- **ECS Anywhere** — hybrid deployments
- **Patching** — EC2 launch type requires OS patching, Fargate doesn't

---

## Key Numbers

| Fact | Value |
|------|-------|
| Max containers per task definition | 10 |
| Max tasks per service | 5,000 (soft limit) |
| Fargate CPU range | 0.25 vCPU to 16 vCPU |
| Fargate memory range | 0.5 GB to 120 GB |
| Task definition max size | 64 KB |
| ECR image scan limit | 1 scan per image per 24 hours (basic) |
| EKS control plane cost | $0.10/hour (~$73/month) |
| ECS control plane cost | Free (you pay for compute only) |
| App Runner min instances | 1 (provisioned) or 0 (with scale-to-zero) |
| ECS Anywhere | Requires SSM agent + ECS agent on-prem |

---

## Cheat Sheet

- **ECS = AWS-native container orchestration.** Free control plane. Pay for compute.
- **Fargate = serverless containers.** No EC2 to manage. "Least operational overhead" answer.
- **EC2 Launch Type = you manage instances.** Choose for GPU, Spot, custom AMI, cost optimization at scale.
- **Task Definition = blueprint.** Immutable. New version = new revision number.
- **Task Role = what YOUR CODE can do.** Execution Role = what ECS AGENT can do.
- **Can't pull image from ECR?** Check Execution Role. Can't write to S3? Check Task Role.
- **ECR** = Docker Hub but private, in your account. Supports scanning + lifecycle policies.
- **EKS** = Kubernetes on AWS. Choose when: multi-cloud, existing K8s expertise, K8s ecosystem tools needed.
- **App Runner** = simplest option. Source code or image in, running app out. No infra to configure.
- **Service** maintains desired task count. Integrates with ALB. Replaces unhealthy tasks.
- **`awsvpc` network mode** = each task gets its own ENI (required for Fargate).
- **Capacity providers:** Fargate, Fargate Spot (up to 70% savings), ASG-based.
- **Placement strategies:** `spread` (HA across AZs), `binpack` (cost optimization), `random`.
- **Service discovery** via Cloud Map → DNS names for service-to-service communication.
- **ECS Anywhere** = run ECS-managed tasks on on-premises servers.
