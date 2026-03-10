# ECS & Containers — Exam Practice Questions

---

## Q1: Task Role vs Execution Role

A developer deploys a containerized application on ECS Fargate. The application needs to read items from a DynamoDB table, but gets `AccessDeniedException`. The task definition has an execution role with `AmazonECSTaskExecutionRolePolicy`. What should the developer do?

**A)** Add DynamoDB permissions to the execution role
**B)** Create a task role with DynamoDB read permissions and assign it to the task definition
**C)** Add DynamoDB permissions to the ECS service-linked role
**D)** Create an IAM user with DynamoDB permissions and pass credentials as environment variables

### Answer: B

**Why:** The **execution role** is the dock worker — it handles infrastructure tasks (pulling images, pushing logs). The **task role** is the cargo's permission badge — it defines what your application code can access at runtime. DynamoDB access is an application-level concern, so it needs a task role.

- **A is wrong:** The execution role is for ECS infrastructure actions (ECR, CloudWatch), not application-level AWS API calls.
- **C is wrong:** The service-linked role is for ECS to manage resources on your behalf (ENIs, load balancer registration). Not for application permissions.
- **D is wrong:** Never hardcode credentials. IAM roles (task roles) are the correct mechanism for containerized apps. This is an anti-pattern.

---

## Q2: Fargate vs EC2 Launch Type

A company runs a machine learning training workload that requires GPU instances and needs to use Spot pricing to minimize costs. They want to use containers. Which approach should they use?

**A)** ECS with Fargate launch type
**B)** ECS with EC2 launch type using GPU-enabled Spot instances
**C)** App Runner with GPU configuration
**D)** ECS with Fargate Spot launch type

### Answer: B

**Why:** GPU support and Spot instance pricing require EC2 launch type. You own the ships (EC2 instances) and can choose GPU instance types (like `p3` or `g4`) and use Spot pricing. Fargate doesn't support GPU instances, and App Runner doesn't support GPU either.

- **A is wrong:** Fargate doesn't support GPU instances. It abstracts the underlying hardware.
- **C is wrong:** App Runner doesn't support GPU configuration. It's for simple web applications.
- **D is wrong:** Fargate Spot provides cost savings on Fargate tasks but still doesn't support GPU. Spot in Fargate != EC2 Spot instances.

---

## Q3: Image Pull Failure

A SysOps administrator deploys a new ECS service but tasks keep failing with the error "CannotPullContainerError." The image exists in ECR. What is the MOST LIKELY cause?

**A)** The task role doesn't have ECR permissions
**B)** The execution role doesn't have `ecr:GetDownloadUrlForLayer` permission
**C)** The ECS cluster doesn't have enough CPU capacity
**D)** The container port mapping is incorrect

### Answer: B

**Why:** Pulling images from ECR is an **infrastructure** action handled by the **execution role**, not the task role. The execution role needs `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:GetDownloadUrlForLayer`, and `ecr:BatchGetImage`. The managed policy `AmazonECSTaskExecutionRolePolicy` includes all of these.

- **A is wrong:** The task role is for application-level API calls, not image pulling. Task role = cargo's badge, execution role = dock worker's badge.
- **C is wrong:** Insufficient capacity would show a "no container instances" error or placement failure, not a pull error.
- **D is wrong:** Port mapping issues would cause health check failures after the container starts, not image pull failures.

---

## Q4: Placement Strategy

A SysOps admin needs to run ECS tasks on EC2 instances and wants to minimize cost by packing tasks as tightly as possible on the fewest instances. Which placement strategy should they use?

**A)** `spread` with attribute `ecs.availability-zone`
**B)** `binpack` with field `memory`
**C)** `random`
**D)** `spread` with attribute `instanceId`

### Answer: B

**Why:** `binpack` places tasks on instances with the LEAST available resources that still fit the task, packing them tightly like tetris blocks. This minimizes the number of instances needed, reducing cost. Using `memory` as the field means it packs based on memory utilization.

- **A is wrong:** `spread` distributes tasks ACROSS availability zones for high availability. It's the opposite of tight packing — it maximizes distribution.
- **C is wrong:** `random` provides no optimization — it's just random placement.
- **D is wrong:** `spread` by `instanceId` distributes one task per instance — maximum spread, maximum cost.

---

## Q5: ECS vs EKS Decision

A company is migrating from on-premises Kubernetes to AWS. Their team has deep Kubernetes expertise, uses Helm charts, and needs to maintain portability across cloud providers. Which service should they use?

**A)** ECS with Fargate
**B)** EKS
**C)** App Runner
**D)** ECS with EC2 launch type

### Answer: B

**Why:** EKS is Kubernetes on AWS. The team already knows Kubernetes, uses K8s-native tools (Helm), and needs multi-cloud portability (K8s is the same everywhere). EKS lets them keep their existing workflows, manifests, and tooling. Migrating to ECS would require rewriting everything in the ECS-specific format.

- **A is wrong:** ECS uses a proprietary API — no portability, no Helm charts, requires rewriting task definitions.
- **C is wrong:** App Runner is too simple — no Kubernetes compatibility, no Helm, limited configuration options.
- **D is wrong:** Same as A — ECS is AWS-proprietary regardless of launch type.

---

## Q6: Service Auto-Scaling

A web application runs on ECS Fargate with a service maintaining 2 tasks. During peak hours, response times increase. The solutions architect wants the service to automatically scale between 2 and 10 tasks based on average CPU utilization. What should they configure?

**A)** EC2 Auto Scaling Group attached to the ECS cluster
**B)** Application Auto Scaling with a target tracking policy on ECS service CPU utilization
**C)** CloudWatch alarm that triggers a Lambda function to update the service desired count
**D)** ECS capacity provider with managed scaling

### Answer: B

**Why:** ECS Service Auto Scaling uses **Application Auto Scaling** (not EC2 Auto Scaling). Target tracking policy is the simplest: "keep average CPU at 70%" and it adjusts task count automatically. This works directly with Fargate — no instances to scale.

- **A is wrong:** EC2 Auto Scaling manages EC2 instances, not ECS tasks. With Fargate, there are no EC2 instances.
- **C is wrong:** This is a manual/custom approach. AWS provides built-in service auto-scaling — always prefer the managed solution.
- **D is wrong:** Capacity providers manage the COMPUTE capacity (how many instances for EC2 launch type), not the task count. Service auto-scaling manages task count.

---

## Q7: Logging Configuration

A developer needs to view container logs from an ECS Fargate task in CloudWatch Logs. The logs aren't appearing. The task definition doesn't include a log configuration. What should the developer add?

**A)** Install the CloudWatch agent inside the container
**B)** Add `logConfiguration` with `awslogs` log driver in the container definition
**C)** Enable VPC Flow Logs for the task's ENI
**D)** Configure the execution role with CloudWatch Logs permissions and add `logConfiguration` with `awslogs` driver

### Answer: D

**Why:** Two things are needed: (1) The container definition must specify the `awslogs` log driver with log group, region, and stream prefix, AND (2) the execution role must have `logs:CreateLogStream` and `logs:PutLogEvents` permissions. Logging is an infrastructure concern, so it's the execution role (dock worker), not the task role.

- **A is wrong:** Fargate tasks don't allow installing agents — you don't have access to the underlying host. The `awslogs` driver is the correct approach.
- **B is wrong:** Partially correct (you do need the log configuration) but incomplete — without execution role permissions, logs still won't flow.
- **C is wrong:** VPC Flow Logs capture network traffic metadata (IPs, ports), not application logs.

---

## Q8: App Runner Use Case

A startup needs to deploy a containerized REST API as quickly as possible with automatic scaling, HTTPS, and CI/CD from their ECR repository. They have no DevOps team and want minimal infrastructure management. Which service is MOST appropriate?

**A)** ECS with Fargate and an ALB
**B)** EKS with Fargate
**C)** App Runner
**D)** EC2 with Docker installed

### Answer: C

**Why:** App Runner is the simplest container service — point it at your ECR image (or source code), and it handles HTTPS, load balancing, auto-scaling, and deployments. No cluster, no task definitions, no ALB to configure, no service to manage. It's Uber for containers — just tell it where to go.

- **A is wrong:** ECS + Fargate + ALB works but requires configuring a cluster, task definition, service, target group, ALB, and listener. More operational overhead.
- **B is wrong:** EKS is the most complex option — overkill for a startup with no DevOps team.
- **D is wrong:** Maximum operational overhead. You manage the OS, Docker, scaling, HTTPS certificates — everything.

---

## Q9: ECR Lifecycle Policies

A team pushes new Docker images to ECR daily. After 6 months, the repository has thousands of images consuming significant storage. What is the MOST cost-effective way to manage this?

**A)** Write a Lambda function to delete old images on a schedule
**B)** Create an ECR lifecycle policy to expire images older than 30 days, keeping the latest 10
**C)** Manually delete old images using the AWS CLI
**D)** Move old images to S3 Glacier for archival

### Answer: B

**Why:** ECR lifecycle policies are the built-in, automated solution. You define rules like "keep only the last 10 tagged images" or "expire untagged images older than 7 days." ECR handles the cleanup automatically — no Lambda, no manual work.

- **A is wrong:** Custom Lambda is unnecessary complexity when ECR has built-in lifecycle policies.
- **C is wrong:** Manual processes don't scale and aren't sustainable.
- **D is wrong:** ECR images can't be moved to S3 Glacier. ECR manages its own storage.

---

## Q10: Service Discovery

A microservices application runs on ECS with three services: `api`, `auth`, and `worker`. The `api` service needs to call `auth` and `worker` by name without hardcoding IP addresses. What should the solutions architect configure?

**A)** An Application Load Balancer with path-based routing for each service
**B)** ECS Service Connect or AWS Cloud Map for service discovery
**C)** Store task IP addresses in DynamoDB and query before each call
**D)** Use environment variables to pass IP addresses between tasks

### Answer: B

**Why:** AWS Cloud Map (used by ECS Service Discovery and Service Connect) lets services register DNS names. `auth.local` resolves to the current IPs of the auth service's tasks. When tasks scale or restart, the DNS records update automatically. Service Connect is the newer, simpler option built on Cloud Map.

- **A is wrong:** ALB works for external traffic but adds cost and latency for internal service-to-service communication. Overkill for internal discovery.
- **C is wrong:** Custom solution that adds complexity, latency, and a DynamoDB dependency. Not scalable or maintainable.
- **D is wrong:** Task IPs change when tasks restart or scale. Environment variables are static — they'd become stale immediately.
