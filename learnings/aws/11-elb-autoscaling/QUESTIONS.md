# ELB & Auto Scaling — Exam Questions

> 12 scenario-based questions mixing SAA-C03, DVA-C02, and SOA-C02 perspectives.

---

### Q1 (SAA) — ALB vs NLB Selection

A financial trading platform needs a load balancer that provides ultra-low latency, supports TCP connections, and requires a static IP address for firewall whitelisting by partners. Which load balancer should be used?

A. ALB with Elastic IP
B. NLB with Elastic IP per AZ
C. CLB with Elastic IP
D. GWLB with Elastic IP

**Answer: B**

**Why B is correct:** NLB operates at Layer 4 (TCP), provides ultra-low latency (~100 microseconds), handles millions of requests per second, and supports **static IPs / Elastic IPs per AZ**. Partners can whitelist specific IPs. Like a fast traffic director who just reads the address on the envelope and routes instantly — no time spent opening and reading the mail.

**Why A is wrong:** ALB does NOT support Elastic IPs or static IPs. ALB uses DNS names that resolve to changing IPs. You can't whitelist ALB IPs.

**Why C is wrong:** CLB is legacy and shouldn't be used for new builds. It also doesn't provide static IPs.

**Why D is wrong:** GWLB is for routing through security appliances, not for serving application traffic.

---

### Q2 (SAA) — Path-Based Routing

A company has a monolithic application being broken into microservices. The API service handles `/api/*`, the admin dashboard handles `/admin/*`, and static assets are served from `/static/*`. They want a single domain name. Which solution is BEST?

A. Three separate ALBs, each with its own DNS record
B. One ALB with listener rules routing by path to three different target groups
C. One NLB with routing rules for each path
D. API Gateway with three stage routes

**Answer: B**

**Why B is correct:** ALB supports path-based routing — a single ALB with listener rules that route `/api/*` to the API target group, `/admin/*` to the admin target group, and `/static/*` to the static target group. One entry point, intelligent routing. Like one smart receptionist who reads your destination and sends you to the right floor.

**Why A is wrong:** Three ALBs means three DNS entries, three sets of SSL certificates, and triple the cost. Completely unnecessary.

**Why C is wrong:** NLB operates at Layer 4 (TCP). It cannot inspect HTTP paths — it doesn't read the mail.

**Why D is wrong:** API Gateway could work but is designed for serverless backends. For EC2-based microservices, ALB is the standard pattern and much cheaper at high throughput.

---

### Q3 (SOA) — Unhealthy Target Troubleshooting

A SysOps administrator deploys a new target group behind an ALB. All instances show "unhealthy" in the target group. The instances are running and accessible via SSH. The health check is configured to check HTTP on port 80 at path `/health`. What are the TWO most likely causes?

A. The security group on the instances doesn't allow inbound traffic on port 80 from the ALB
B. The application isn't returning HTTP 200 at the `/health` path
C. The instances need to be manually registered with the target group
D. The ALB doesn't have a public IP address

**Answer: A and B**

**Why A is correct:** Security groups must allow inbound traffic from the ALB's security group on the health check port. If port 80 is blocked, the ALB can't reach the instances, and every health check fails. Like the traffic director trying to call each soldier but the phone line is disconnected.

**Why B is correct:** The application might not have a `/health` endpoint, or it might return a non-200 status code. The ALB expects the configured success code (default 200). If the app returns 404 or 500, the target is marked unhealthy.

**Why C is wrong:** If the instances are showing "unhealthy" (not "unused"), they're already registered. Unregistered targets wouldn't appear at all.

**Why D is wrong:** ALB doesn't need a public IP to health-check targets. Health checks happen over the private network within the VPC.

---

### Q4 (SAA) — Auto Scaling Policy Selection

An e-commerce site has predictable traffic spikes every day at 9am (marketing emails go out) and every Black Friday. During normal hours, they want CPU to stay around 60%. Which combination of scaling policies is BEST?

A. Target tracking (60% CPU) only
B. Target tracking (60% CPU) + scheduled scaling for 9am daily + scheduled scaling for Black Friday
C. Step scaling with CloudWatch alarms at 50%, 60%, 70%, 80% CPU
D. Predictive scaling only

**Answer: B**

**Why B is correct:** Three different patterns need three approaches: (1) Target tracking at 60% CPU handles the baseline — like a thermostat maintaining temperature. (2) Scheduled scaling at 9am pre-warms instances before the email spike — don't wait for CPU to hit 60%, have soldiers ready before the battle. (3) Scheduled scaling for Black Friday scales up in advance for the known mega-event. Combining policies gives the best coverage.

**Why A is wrong:** Target tracking alone is reactive. It won't scale up BEFORE the 9am spike — it waits until CPU rises. Users experience slowness during the scaling window.

**Why C is wrong:** Step scaling is reactive (needs CloudWatch alarms to fire). Same problem as target tracking — reacts after the fact.

**Why D is wrong:** Predictive scaling learns from past patterns but can't handle one-off events like Black Friday (which happens once a year). It's better as a complement, not the only policy.

---

### Q5 (SOA) — Connection Draining

A SysOps administrator is performing a rolling deployment by replacing instances in an ASG. Users report that their requests are being dropped mid-transaction during the deployment. What should be configured?

A. Increase the health check interval to give instances more time
B. Configure deregistration delay (connection draining) to allow in-flight requests to complete
C. Enable sticky sessions so users aren't moved to new instances
D. Increase the ASG cooldown period

**Answer: B**

**Why B is correct:** Deregistration delay (connection draining) tells the ALB to stop sending NEW traffic to the instance being removed but allows EXISTING connections to complete within the configured timeout (default 300s). Without it, in-flight requests are terminated immediately when the instance is deregistered. Like letting a soldier finish serving their current customer before leaving post.

**Why A is wrong:** Health check interval determines how often the ALB checks targets. It doesn't affect what happens when instances are removed.

**Why C is wrong:** Sticky sessions keep the same user on the same instance, but during a rolling deployment, that instance IS being replaced. Sticky sessions won't help when the instance is terminated.

**Why D is wrong:** ASG cooldown is the wait time between scaling actions. It doesn't affect how in-flight requests are handled.

---

### Q6 (SAA) — Cross-Zone Load Balancing

An application runs behind an ALB with 2 instances in AZ-A and 8 instances in AZ-B. Users in AZ-A report slower response times. What is the MOST LIKELY explanation?

A. ALB doesn't support cross-zone load balancing
B. This is expected — ALB has cross-zone enabled by default, distributing evenly across all 10 instances
C. AZ-A instances are receiving 50% of traffic (2 instances splitting the same load as 8 in AZ-B)
D. The health checks are failing for AZ-A instances

**Answer: B**

**Why B is correct:** Actually, wait — ALB has cross-zone load balancing ALWAYS enabled. Traffic is distributed evenly across ALL 10 instances regardless of AZ. Each instance gets ~10% of traffic. The AZ-A instances should NOT be overloaded.

If users in AZ-A report slowness despite even distribution, the issue is likely something ELSE (instance size, application-level issue). But given the answer options, **B** is correct because it correctly states that ALB distributes evenly — making C wrong as the explanation for slowness.

Trick question: the premise suggests AZ imbalance causes slowness, but ALB's cross-zone balancing prevents this.

**Why A is wrong:** ALB absolutely supports cross-zone load balancing — it's always on.

**Why C is wrong:** This would be true for NLB (cross-zone disabled by default) but NOT ALB. ALB distributes across all targets evenly.

**Why D is wrong:** If health checks were failing, the instances would be marked unhealthy and removed from rotation, not receive slower traffic.

---

### Q7 (DVA) — ALB + Lambda Integration

A developer wants to expose a Lambda function through an ALB instead of API Gateway. What must be configured?

A. A target group with target type "Lambda" and register the Lambda function
B. An integration with the Lambda function in the ALB listener rules
C. A Lambda function URL and point the ALB at it
D. An API Gateway HTTP proxy in front of the ALB

**Answer: A**

**Why A is correct:** ALB can directly invoke Lambda functions via a target group with target type set to "Lambda." Register the Lambda function ARN as the target. The ALB converts the HTTP request into a Lambda event, invokes the function, and converts the response back to HTTP. No API Gateway needed. Like telling the traffic director to forward visitors directly to the magic kitchen.

**Why B is wrong:** ALB doesn't have "integrations" like API Gateway. It uses target groups.

**Why C is wrong:** Lambda function URLs are a separate feature (direct HTTPS endpoint for Lambda). Using ALB + function URL adds an unnecessary hop.

**Why D is wrong:** The whole point is to use ALB instead of API Gateway. Adding API Gateway defeats the purpose.

---

### Q8 (SOA) — ASG Not Scaling

A SysOps administrator configured an ASG with a target tracking policy at 70% CPU. CloudWatch shows average CPU at 85% for 30 minutes, but no new instances are launched. What are possible causes? (Choose TWO)

A. The ASG has reached its maximum capacity
B. The cooldown period hasn't expired
C. The ASG is in a suspended scaling process
D. The target tracking policy is set to scale in only

**Answer: A and C**

**Why A is correct:** If the ASG is already at its maximum capacity, it can't launch more instances even if CPU is high. The army can't recruit more soldiers if they've hit the budget cap. Check the `Max` setting and increase it if needed.

**Why C is correct:** ASG scaling processes can be suspended (e.g., during deployments or maintenance). If the `Launch` process is suspended, no new instances will be created regardless of metrics. Check ASG suspended processes.

**Why B is wrong:** 30 minutes far exceeds the default 300-second cooldown. Even with a custom cooldown, 30 minutes would be unusual.

**Why D is wrong:** Target tracking policies always handle both scale-out and scale-in. You can disable scale-in separately, but the policy itself always triggers scale-out when the metric exceeds the target.

---

### Q9 (SAA) — NLB + PrivateLink

A SaaS company wants to expose their API to customers in different AWS accounts without traversing the public internet. The customers need to whitelist a static IP. Which architecture meets these requirements?

A. ALB with VPC Peering
B. NLB with AWS PrivateLink (VPC Endpoint Service)
C. API Gateway with VPC Link
D. Direct Connect between accounts

**Answer: B**

**Why B is correct:** PrivateLink (VPC Endpoint Service) lets you expose a service via NLB to consumers in other VPCs/accounts. Traffic stays on the AWS backbone (never hits the internet). NLB provides static IPs for whitelisting. Consumers create an interface VPC endpoint in their VPC to connect. Like building a private tunnel between two buildings — no one on the street can see the traffic.

**Why A is wrong:** VPC Peering connects entire VPCs and doesn't provide static IPs. ALB doesn't support static IPs. Also, peering doesn't work well for SaaS (every customer would need a peering connection).

**Why C is wrong:** API Gateway with VPC Link exposes services publicly via API Gateway. The traffic goes through the internet to API Gateway, then privately via VPC Link. It doesn't stay entirely private.

**Why D is wrong:** Direct Connect is for on-premises to AWS connectivity, not between AWS accounts.

---

### Q10 (SOA) — Lifecycle Hooks

A SysOps administrator needs to ensure that every new instance launched by an ASG downloads configuration files from S3 and registers with a configuration management tool BEFORE receiving traffic. If the setup fails, the instance should be terminated. How should this be configured?

A. User data script in the launch template
B. A launch lifecycle hook with a Lambda function or script that performs setup
C. A startup script in the AMI
D. CloudWatch Events rule triggering a Lambda function on instance launch

**Answer: B**

**Why B is correct:** Lifecycle hooks pause the instance in `Pending:Wait` state before it enters `InService`. During this pause, a script or Lambda function can perform setup tasks. If setup succeeds, send `CONTINUE` — the instance joins the ASG and receives traffic. If setup fails, send `ABANDON` — the instance is terminated. Like a quarantine area where new recruits must pass training before joining active duty.

**Why A is wrong:** User data scripts run during boot but the ASG doesn't wait for them to complete. The instance could start receiving traffic while the script is still running — or even if it fails.

**Why C is wrong:** Same issue as user data — the AMI startup script runs but the ASG doesn't know or care about its result.

**Why D is wrong:** CloudWatch Events (EventBridge) can trigger Lambda on instance launch, but it's asynchronous. The instance might already be receiving traffic before the Lambda completes.

---

### Q11 (SAA) — Weighted Target Groups for Canary

A company wants to deploy a new version of their application to 10% of users for testing. They're using ALB with an ASG. What is the MOST operationally simple approach?

A. Create a new ASG with the new version and use Route 53 weighted routing
B. Create a second target group with the new version and use ALB weighted target group routing (90/10 split)
C. Use Lambda@Edge to route 10% of requests to a different origin
D. Deploy the new version on 10% of instances in the same target group

**Answer: B**

**Why B is correct:** ALB supports weighted target groups in listener rules. Create Target Group A (v1, weight 90) and Target Group B (v2, weight 10). The ALB splits traffic accordingly. No DNS changes, no infrastructure overhead. Adjust weights to shift traffic. Like the director sending 9 out of 10 visitors to the old office and 1 to the new one.

**Why A is wrong:** Route 53 weighted routing works but adds DNS TTL delay and is less precise. ALB weighted routing is instant and at the request level.

**Why C is wrong:** Lambda@Edge is for CloudFront. The architecture uses ALB, not CloudFront.

**Why D is wrong:** You can't run two application versions in the same target group cleanly. There's no mechanism to route specific percentages to specific instances within one target group.

---

### Q12 (SOA) — Slow Start Mode

After deploying new instances, the ALB immediately sends full traffic to them. The instances become overwhelmed because they need time to build in-memory caches before handling full load. What feature should be configured?

A. Increase the health check grace period
B. Enable slow start mode on the target group
C. Add a lifecycle hook to delay traffic
D. Increase the deregistration delay

**Answer: B**

**Why B is correct:** Slow start mode linearly increases the traffic sent to a newly registered target over a configured period (30-900 seconds). The instance starts with minimal traffic and ramps up, giving it time to warm caches, load data, and stabilize. Like gradually turning up the volume instead of blasting music at full volume from the start.

**Why A is wrong:** Health check grace period delays when health checks START, but once the instance passes its first check, it receives full traffic immediately.

**Why C is wrong:** Lifecycle hooks pause the instance before it joins the target group. Once it proceeds, it gets full traffic. There's no gradual ramp-up.

**Why D is wrong:** Deregistration delay is for instances leaving the target group, not instances joining.
