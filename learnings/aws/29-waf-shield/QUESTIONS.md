# WAF & Shield — Exam Practice Questions

---

## Q1: WAF Attachment Points

A company wants to protect their web application from SQL injection attacks. The architecture uses an NLB in front of EC2 instances. Where should they attach WAF?

**A)** Directly to the NLB
**B)** Replace the NLB with an ALB and attach WAF to the ALB
**C)** Attach WAF to each EC2 instance
**D)** Attach WAF to the VPC

### Answer: B

**Why:** WAF can ONLY attach to CloudFront, ALB, API Gateway, and AppSync. NLB operates at Layer 4 (TCP) and doesn't support WAF. To use WAF, you need a Layer 7 load balancer (ALB). The solution is to replace the NLB with an ALB (or add CloudFront in front of the NLB).

- **A is wrong:** WAF doesn't attach to NLB. NLB is Layer 4 — it doesn't inspect HTTP content where SQL injection lives.
- **C is wrong:** WAF doesn't attach to EC2 instances. It's a managed service that integrates with specific AWS services.
- **D is wrong:** WAF doesn't attach to VPCs. NACLs and Security Groups are the VPC-level firewalls, but they don't inspect HTTP content.

---

## Q2: Shield Standard vs Advanced

A gaming company experiences a massive DDoS attack causing their ALB to auto-scale and incur high costs. They want protection against future attacks AND reimbursement for the scaling costs. What should they enable?

**A)** Shield Standard with WAF rate-based rules
**B)** Shield Advanced
**C)** AWS Firewall Manager with Shield Standard
**D)** CloudFront with Shield Standard

### Answer: B

**Why:** Shield Advanced provides **cost protection** — AWS credits for scaling costs caused by DDoS attacks (ELB, CloudFront, Route 53, Global Accelerator). Shield Standard only provides basic L3/L4 protection with no cost reimbursement. The $3,000/month cost of Shield Advanced is worth it when DDoS-caused scaling bills could be much higher.

- **A is wrong:** Shield Standard is free and always on, but provides no cost protection. Rate-based WAF rules help but don't reimburse scaling costs.
- **C is wrong:** Firewall Manager is for centralized policy management, not DDoS cost protection.
- **D is wrong:** CloudFront with Shield Standard absorbs some DDoS traffic at the edge but doesn't provide cost protection for backend scaling.

---

## Q3: Rate-Based Rules

A web application is experiencing a brute force login attack where attackers try thousands of password combinations from a single IP. Which WAF rule type is MOST effective?

**A)** SQL injection rule
**B)** Geo-match rule blocking the attacker's country
**C)** Rate-based rule limiting requests to the login endpoint
**D)** IP set rule blocking the attacker's IP

### Answer: C

**Why:** Rate-based rules automatically block IPs that exceed a threshold within a 5-minute window. You can scope it to the login endpoint URI. When the attacker exceeds the rate, they're automatically blocked. This handles distributed attacks (rotating IPs) better than blocking a single IP.

- **A is wrong:** SQL injection rules detect malicious SQL in request parameters, not brute force login attempts. The attack is valid HTTP requests with wrong passwords.
- **B is wrong:** Geo-blocking an entire country is too broad. Legitimate users from that country would also be blocked. Also, attackers use VPNs.
- **D is wrong:** Blocking one IP works for one attacker but fails against distributed attacks (botnets with thousands of IPs). Rate-based rules automatically identify and block any high-traffic IP.

---

## Q4: WAF Rule Testing

A security team creates new WAF rules to block suspicious patterns. They want to test the rules before enforcing them to avoid blocking legitimate traffic. What approach should they use?

**A)** Deploy rules in a separate staging environment
**B)** Set rule action to COUNT, monitor logs, then switch to BLOCK
**C)** Set the Web ACL default action to BLOCK
**D)** Enable Shield Advanced to test rules automatically

### Answer: B

**Why:** COUNT action logs which requests WOULD be blocked without actually blocking them. The team can analyze WAF logs to see if legitimate traffic matches the rules (false positives). Once confident, they switch the action to BLOCK. Think of it as: the border guard stamps "suspicious" on passports but still lets everyone through — then reviews the stamps before actually turning people away.

- **A is wrong:** A separate staging environment may not have the same traffic patterns as production. Testing with real production traffic (via COUNT) is more accurate.
- **C is wrong:** Setting default action to BLOCK would block all traffic that doesn't match any ALLOW rule — extremely disruptive.
- **D is wrong:** Shield Advanced provides DDoS protection, not WAF rule testing.

---

## Q5: Firewall Manager

A company with 50 AWS accounts in an Organization needs to ensure ALL ALBs across ALL accounts have WAF enabled with the same SQL injection and XSS rules. New ALBs created in any account should automatically get WAF. What should they use?

**A)** AWS Config rules to check WAF compliance
**B)** AWS Firewall Manager WAF policy
**C)** Lambda function triggered by CloudTrail that attaches WAF to new ALBs
**D)** CloudFormation StackSets deploying WAF to all accounts

### Answer: B

**Why:** Firewall Manager creates centralized WAF policies that automatically apply to all existing and NEW resources across all Organization accounts. When someone creates a new ALB in any account, Firewall Manager automatically attaches the WAF Web ACL. It also reports non-compliant resources.

- **A is wrong:** Config rules detect non-compliance but don't remediate. They'd tell you an ALB doesn't have WAF but wouldn't attach it.
- **C is wrong:** Custom Lambda is fragile, hard to maintain across 50 accounts, and has delay between ALB creation and WAF attachment.
- **D is wrong:** StackSets can deploy WAF resources but don't automatically discover and attach to new ALBs. It's a point-in-time deployment.

---

## Q6: WAF Logging

A security team needs to analyze WAF logs to identify patterns of blocked requests. They want to run SQL queries on the logs and retain them for 90 days. Which logging destination is BEST?

**A)** CloudWatch Logs with Logs Insights
**B)** S3 with Amazon Athena
**C)** Kinesis Data Firehose to OpenSearch
**D)** DynamoDB

### Answer: B

**Why:** S3 provides cheap long-term storage (90 days easily), and Athena lets you run SQL queries directly on S3 data. This is the most cost-effective option for periodic log analysis. CloudWatch Logs Insights is great for real-time queries but more expensive for 90-day retention of high-volume WAF logs.

- **A is wrong:** CloudWatch Logs is more expensive for large volumes and long retention. Good for real-time monitoring but not cost-effective for 90-day analysis.
- **C is wrong:** OpenSearch (Elasticsearch) is powerful for real-time dashboards but expensive for simple log analysis. Overkill for periodic SQL queries.
- **D is wrong:** DynamoDB is not a log storage service. WAF doesn't log to DynamoDB, and it's not designed for log analysis.

---

## Q7: Bot Control

An e-commerce site notices bots scraping their product prices every hour. The bots mimic real browsers (correct User-Agent, accept cookies). How should the team protect the site?

**A)** Block all requests without a valid Referer header
**B)** Use AWS WAF Bot Control managed rule group with CAPTCHA/Challenge actions
**C)** Implement rate-based rules at 10 requests per minute
**D)** Block all non-US IP addresses

### Answer: B

**Why:** AWS WAF Bot Control uses advanced detection (browser fingerprinting, silent JavaScript challenges, behavioral analysis) to identify sophisticated bots even when they mimic real browsers. CAPTCHA challenges block automated scrapers while allowing human users through. Standard WAF rules (User-Agent, rate limits) fail against sophisticated bots.

- **A is wrong:** Many legitimate requests lack Referer headers (direct navigation, privacy extensions). This would block real customers.
- **C is wrong:** Sophisticated scrapers often stay under rate limits by distributing across many IPs. Also, 10 req/min is too aggressive for real users browsing products.
- **D is wrong:** The bots might be in the US. Geo-blocking is too broad and blocks international customers.

---

## Q8: DDoS Architecture

A solutions architect needs to design a highly DDoS-resilient architecture for a public-facing web application. Which combination provides the BEST protection?

**A)** ALB → EC2 instances with Security Groups
**B)** CloudFront → ALB → EC2, with WAF on CloudFront and Shield Advanced
**C)** NLB → EC2 with Shield Standard
**D)** API Gateway → Lambda with WAF on API Gateway

### Answer: B

**Why:** This is the gold standard for DDoS resilience: CloudFront absorbs L3/L4 attacks at the edge (200+ points of presence), WAF on CloudFront filters L7 attacks, Shield Advanced provides 24/7 DRT support and cost protection, and the ALB + EC2 behind CloudFront are protected from direct attack. Layer upon layer of defense.

- **A is wrong:** ALB directly on the internet is more vulnerable. No edge absorption, no WAF content inspection (unless WAF is on ALB), no Shield Advanced cost protection.
- **C is wrong:** NLB doesn't support WAF. Shield Standard only provides basic L3/L4 protection. No L7 protection.
- **D is wrong:** API Gateway + Lambda is excellent for many use cases and WAF on APIGW provides L7 filtering. But it's less resilient than CloudFront for DDoS because it lacks the edge network absorption.

---

## Q9: Account Takeover Prevention

A banking application needs to detect and prevent account takeover attempts (credential stuffing, stolen password attacks). Which AWS service feature addresses this?

**A)** Shield Advanced with DDoS detection
**B)** WAF with AWSManagedRulesATPRuleSet (Account Takeover Prevention)
**C)** GuardDuty with threat detection
**D)** IAM with MFA enforcement

### Answer: B

**Why:** The AWSManagedRulesATPRuleSet is specifically designed for Account Takeover Prevention (ATP). It inspects login attempts, detects credential stuffing patterns (known stolen credentials), identifies distributed login attacks, and blocks compromised credentials. It integrates with WAF and attaches to ALB/CloudFront protecting the login endpoint.

- **A is wrong:** Shield Advanced protects against DDoS (volumetric attacks), not targeted credential-based attacks.
- **C is wrong:** GuardDuty monitors for threats in your AWS account (unusual API calls, compromised instances), not web application login attacks.
- **D is wrong:** MFA prevents unauthorized access after credential theft but doesn't detect or block the attack pattern itself. ATP proactively blocks the attack before it succeeds.

---

## Q10: WAF Scope — Regional vs Global

A developer creates a WAF Web ACL in `us-east-1` and wants to attach it to a CloudFront distribution. But they can't see the Web ACL when configuring CloudFront. What's the issue?

**A)** CloudFront doesn't support WAF
**B)** WAF Web ACLs for CloudFront must be created in the `us-east-1` region with CloudFront scope (Global)
**C)** The Web ACL needs to be in the same region as the ALB origin
**D)** CloudFront requires Shield Advanced to use WAF

### Answer: B

**Why:** WAF has two scopes: **Regional** (for ALB, API Gateway, AppSync) and **CloudFront** (global). Even though CloudFront Web ACLs are created in `us-east-1`, they must be specifically created with the CloudFront/Global scope. A Regional Web ACL created in `us-east-1` won't appear in CloudFront configuration. The developer likely created a Regional-scoped Web ACL instead of a CloudFront-scoped one.

- **A is wrong:** CloudFront absolutely supports WAF — it's one of the primary WAF attachment points.
- **C is wrong:** WAF attaches to CloudFront at the edge, not to the origin. The origin region is irrelevant for WAF scope.
- **D is wrong:** Shield Advanced is not required for WAF on CloudFront. WAF works independently with Shield Standard (free).
