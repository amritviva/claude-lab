# SOA-C02 SysOps Administrator Associate -- Gotchas & Ace Sheet

> **The Country Analogy:** You're the **operations manager** of AWS-land. The architect
> designed the cities, the developer built the apps, and now YOU keep everything running.
> Monitoring, patching, troubleshooting, automating, securing. Every question asks:
> "How do you keep this infrastructure healthy and compliant?"

---

## Exam Profile

| Detail | Value |
|--------|-------|
| Code | SOA-C02 |
| Questions | 65 (50 scored + 15 unscored) |
| Time | 130 minutes (~2 min/question) |
| Passing | 720 / 1000 |
| Format | Multiple choice + multiple response + **exam lab** (hands-on) |
| Cost | $150 USD |

**Note:** SOA-C02 includes a hands-on **exam lab** section where you perform tasks in a real AWS console. This is unique among the three associate exams.

---

## Domain Breakdown

| # | Domain | Weight | What It ACTUALLY Tests |
|---|--------|--------|----------------------|
| 1 | Monitoring, Logging & Remediation | 20% | CloudWatch metrics/alarms/logs, EventBridge, CloudTrail, automated remediation. "Can you spot and fix problems?" |
| 2 | Reliability & Business Continuity | 16% | Multi-AZ, Auto Scaling, backup/restore, DR strategies, Route 53 failover. "Can you keep the lights on?" |
| 3 | Deployment, Provisioning & Automation | 18% | CloudFormation, AMIs, EC2 Image Builder, Systems Manager, automation. "Can you deploy and manage at scale?" |
| 4 | Security & Compliance | 16% | IAM, SCPs, Config, Inspector, GuardDuty, encryption, compliance auditing. "Can you keep it locked down?" |
| 5 | Networking & Content Delivery | 18% | VPC, subnets, NACLs, SGs, Route 53, CloudFront, VPN, Direct Connect. "Can you troubleshoot the network?" |
| 6 | Cost & Performance Optimization | 12% | Trusted Advisor, Cost Explorer, right-sizing, Compute Optimizer. "Can you make it fast and cheap?" |

---

## Top 30 SOA Gotchas

### Gotcha 1: CloudWatch Agent = Memory & Disk Metrics

EC2 built-in metrics include CPU, network, disk I/O, and status checks. But **memory utilization and disk space** are NOT built-in. You MUST install the **CloudWatch Agent** to collect them. This is tested constantly.

Think of it this way: CloudWatch can see the outside of the building (CPU, network) but needs an agent **inside** the building to see memory and disk.

### Gotcha 2: CloudWatch Monitoring Intervals

| Type | Interval | Cost |
|------|----------|------|
| Basic Monitoring | 5 minutes | Free |
| Detailed Monitoring | 1 minute | Paid |
| High-Resolution Custom Metrics | 1 second | Paid (custom) |

"Need per-second metrics" = high-resolution custom metrics via CloudWatch Agent. "Need per-minute" = enable detailed monitoring.

### Gotcha 3: CloudWatch Logs Default Retention = NEVER EXPIRE

By default, CloudWatch Logs are retained **forever**. This means ever-growing costs. Always set a retention policy. Common trap: "Reduce CloudWatch costs" -- set log retention periods.

### Gotcha 4: CloudFormation Rollback Behaviour

- **Create fails**: automatic rollback (deletes everything created). Disable with `--disable-rollback` for debugging.
- **Update fails**: automatic rollback to previous working state.
- **DELETE_FAILED**: usually because a resource can't be deleted (e.g., non-empty S3 bucket). Must fix manually.
- **UPDATE_ROLLBACK_FAILED**: the rollback itself failed. Need `ContinueUpdateRollback` to recover (can skip problematic resources).

### Gotcha 5: CloudFormation DeletionPolicy

```yaml
Resources:
  MyDB:
    Type: AWS::RDS::DBInstance
    DeletionPolicy: Retain    # Keep resource when stack is deleted
    # DeletionPolicy: Delete  # Delete resource (default)
    # DeletionPolicy: Snapshot # Take snapshot then delete (RDS, EBS, ElastiCache, Neptune, Redshift)
```

"Protect database from accidental stack deletion" = `DeletionPolicy: Retain` or `DeletionPolicy: Snapshot`.

### Gotcha 6: CloudFormation Drift Detection

Drift = someone manually changed a resource in the console that CloudFormation manages. Drift detection **finds** these changes but does NOT fix them. To fix:
1. Import the changes into the template, OR
2. Run a stack update to overwrite the manual changes

### Gotcha 7: SSM Session Manager

Session Manager = SSH alternative. Why it's better:
- No port 22 open (no inbound SG rule needed)
- No SSH key pairs to manage
- All sessions are **logged** (CloudWatch Logs, S3)
- IAM-based access control
- Works through NAT Gateway / VPC endpoints (no public IP needed)

"Secure shell access without opening ports" = Session Manager. Always.

### Gotcha 8: SSM Run Command

Execute commands across a fleet of EC2 instances without SSH:
- Uses **SSM Agent** (pre-installed on Amazon Linux 2, Windows Server)
- Target by tags, resource groups, or individual instances
- Output to S3 or CloudWatch Logs
- Rate control: concurrency limit + error threshold

"Run a script on 500 EC2 instances" = SSM Run Command. Not SSH.

### Gotcha 9: SSM Patch Manager

Automated patching workflow:
1. **Patch Baseline**: defines which patches to approve/reject
2. **Maintenance Window**: when patching happens
3. **Patch Group**: which instances get which baseline

Default baselines exist for each OS. "Automate OS patching across fleet" = SSM Patch Manager.

### Gotcha 10: AWS Config -- What IS vs What HAPPENED

- **AWS Config** = what IS the current state of resources? Are they compliant? Like a **building inspector** who checks if buildings meet code.
- **AWS CloudTrail** = what HAPPENED? Who did what and when? Like the country's **security cameras** recording all activity.

"Who deleted the S3 bucket?" = CloudTrail. "Are all S3 buckets encrypted?" = Config.

### Gotcha 11: Config Rules Are Reactive, Not Preventive

Config rules evaluate compliance AFTER a change is made. They **detect** non-compliance, they don't **prevent** it.
- **Preventive** controls: SCPs, IAM policies, S3 Block Public Access
- **Detective** controls: Config rules, GuardDuty, CloudTrail

"Prevent users from creating unencrypted EBS volumes" = IAM policy (preventive). "Detect unencrypted EBS volumes" = Config rule (detective).

### Gotcha 12: Config Auto-Remediation

Config can automatically fix non-compliant resources using **SSM Automation documents**:
```
Config Rule (detects non-compliance)
  → Auto-Remediation Action (SSM Automation runbook)
    → Fix the resource
```

Example: Config detects unencrypted EBS volume → triggers SSM runbook → encrypts the volume.

### Gotcha 13: Organizations SCPs -- Boundaries, Not Grants

SCPs set the **maximum permissions boundary** for an account. They don't grant anything.

```
Effective permissions = IAM Policy ∩ SCP
(intersection -- must be allowed by BOTH)
```

Key traps:
- SCPs affect the **root user** of member accounts
- SCPs do NOT affect the **management account** (formerly master account)
- SCPs do NOT affect service-linked roles

### Gotcha 14: Auto Scaling Cooldown Period

Default cooldown = **300 seconds (5 minutes)**. During cooldown, Auto Scaling ignores additional scaling alarms. Purpose: prevent thrashing (scaling up and down rapidly).

"Instances keep launching and terminating" = cooldown period too short, or health check misconfigured.

### Gotcha 15: EBS gp2 Burst Credits

gp2 volumes get a burst balance:
- Baseline: 3 IOPS per GB (100 IOPS minimum)
- Burst: up to 3,000 IOPS
- Volumes < 1,000 GB can deplete burst credits under sustained load

**gp3 has NO burst credit system** -- you get a flat 3,000 IOPS baseline. If questions mention "burst credit depletion," migration to gp3 or io1/io2 is the fix.

### Gotcha 16: RDS Storage Autoscaling

RDS storage autoscaling triggers when:
- Free storage < **10%** of allocated storage
- Low storage lasts >= 5 minutes
- At least 6 hours since last scaling

You set a **Maximum Storage Threshold**. If not set, autoscaling won't work. "RDS running out of disk" = enable storage autoscaling.

### Gotcha 17: Route 53 Health Checks

Three types:
1. **Endpoint health check**: monitors an IP or domain (HTTP, HTTPS, TCP)
2. **Calculated health check**: combines multiple health checks (AND/OR logic)
3. **CloudWatch alarm-based**: healthy/unhealthy based on CloudWatch alarm state

Health checks enable **failover routing** -- Route 53 only returns healthy endpoints. "Automatic DNS failover" = Route 53 health check + failover routing policy.

### Gotcha 18: S3 Event Notifications vs EventBridge

- **S3 Event Notifications**: direct to SNS, SQS, or Lambda. Simple. Limited filtering (prefix/suffix only).
- **S3 via EventBridge**: more targets (18+), advanced filtering (by metadata, size, etc.), event replay, archive.

"Complex event filtering on S3 events" = EventBridge. "Simple notification on upload" = S3 Event Notification (or EventBridge -- both work).

### Gotcha 19: VPC Flow Logs

VPC Flow Logs capture **metadata** about network traffic:
- Source/destination IP, port, protocol, action (ACCEPT/REJECT), bytes
- Published to CloudWatch Logs or S3

Flow Logs do NOT capture:
- Packet contents (payload)
- DNS queries to Route 53 Resolver
- DHCP traffic
- Traffic to metadata service (169.254.169.254)

"See which IPs are being blocked" = VPC Flow Logs (REJECT records). "See packet content" = need a network packet capture tool, not Flow Logs.

### Gotcha 20: Trusted Advisor Checks

| Support Plan | Checks Available |
|-------------|-----------------|
| Basic / Developer | 7 core checks (S3 bucket permissions, SG unrestricted ports, IAM use, MFA on root, EBS snapshots, RDS snapshots, Service Limits) |
| Business / Enterprise | Full set (115+ checks) + API access + CloudWatch integration |

"Enable all Trusted Advisor checks" = upgrade to Business or Enterprise support plan.

### Gotcha 21: EC2 Status Checks

Two types:
- **System Status Check**: hardware/infrastructure issue (host problem). Fix: stop and start instance (migrates to new host). NOT reboot (stays on same host).
- **Instance Status Check**: OS/software issue. Fix: reboot instance.

"System status check failed" = stop/start (not reboot). This distinction is a favourite trick.

### Gotcha 22: CloudWatch Composite Alarms

Combine multiple alarms with AND/OR logic to reduce alarm noise:
```
Composite Alarm = (CPU Alarm AND Memory Alarm)
```
Only fires when BOTH conditions are met. Reduces false positives.

### Gotcha 23: EC2 Placement Groups and Recovery

- **Auto Recovery**: CloudWatch alarm triggers `recover` action. Moves instance to new hardware, keeps same private IP, EBS volumes, and Elastic IP. Only works for instances backed by EBS (not instance store).
- **Auto Scaling**: launches NEW instances (different IP, fresh start).

"Maintain same IP after hardware failure" = EC2 Auto Recovery. "Replace failed instances" = Auto Scaling.

### Gotcha 24: ELB Access Logs vs CloudTrail

- **ELB Access Logs**: detailed request-level logs (client IP, latencies, response codes). Stored in S3.
- **CloudTrail**: API calls to the ELB service (CreateLoadBalancer, ModifyListener). Who did what to the ELB itself.

"Debug slow responses through load balancer" = ELB Access Logs. "Who modified the load balancer" = CloudTrail.

### Gotcha 25: CloudFormation StackSets

Deploy stacks across **multiple accounts AND regions** from a single template:
- Managed from the **management account** (or delegated admin)
- Set max concurrent accounts and failure tolerance
- Use for: organization-wide Config rules, IAM baselines, GuardDuty setup

"Deploy a CloudFormation template to all accounts in the organization" = StackSets.

### Gotcha 26: AWS Inspector vs GuardDuty vs Macie

| Service | What It Does | Analogy |
|---------|-------------|---------|
| Inspector | Scans EC2/ECR for vulnerabilities + network exposure | Building inspector checking for structural problems |
| GuardDuty | Threat detection using ML on CloudTrail/VPC/DNS logs | Security guard watching cameras for suspicious activity |
| Macie | Scans S3 for sensitive data (PII, credit cards) | Customs officer checking luggage for contraband |

"Find vulnerabilities on EC2" = Inspector. "Detect suspicious API calls" = GuardDuty. "Find PII in S3" = Macie.

### Gotcha 27: IAM Access Analyzer

Finds resources shared with external entities:
- S3 buckets, IAM roles, KMS keys, Lambda functions, SQS queues
- Generates **findings** when a resource policy allows access from outside your zone of trust (account or organization)

"Identify unintended cross-account access" = IAM Access Analyzer.

### Gotcha 28: S3 Replication Requirements

For Cross-Region (CRR) or Same-Region (SRR) replication:
- **Versioning** must be enabled on BOTH source and destination
- **IAM role** with permissions to replicate
- Objects encrypted with **SSE-C** cannot be replicated
- **Delete markers** are NOT replicated by default (can be enabled)
- Existing objects are NOT automatically replicated (only new objects after enabling)

### Gotcha 29: CloudWatch Contributor Insights

Identifies the top-N contributors to a pattern:
- Top talkers (IPs generating most traffic)
- Top error generators
- Top resource consumers

Uses VPC Flow Logs or CloudWatch Logs as input. "Find which IPs are generating the most errors" = Contributor Insights.

### Gotcha 30: AWS Backup vs Service-Native Backups

- **AWS Backup**: centralized, policy-based, cross-service, cross-account, cross-region
- **Service-native** (RDS snapshots, EBS snapshots, DynamoDB PITR): per-service, per-region

"Centralized backup policy across multiple services and accounts" = AWS Backup. "Backup just one RDS database" = native RDS snapshots are fine.

---

## Troubleshooting Flowcharts

### EC2 Instance Can't Connect to Internet

```
Instance in public subnet?
├── No → Move to public subnet or use NAT Gateway from private subnet
└── Yes:
    Has public IP or Elastic IP?
    ├── No → Assign public IP or EIP
    └── Yes:
        Internet Gateway attached to VPC?
        ├── No → Create and attach IGW
        └── Yes:
            Route table has 0.0.0.0/0 → IGW?
            ├── No → Add route to IGW
            └── Yes:
                Security Group allows outbound?
                ├── No → Add outbound rule
                └── Yes:
                    NACL allows outbound + inbound (ephemeral ports)?
                    ├── No → Fix NACL rules (remember: stateless!)
                    └── Yes → Check OS-level firewall (iptables/Windows Firewall)
```

### Lambda Function Timeout

```
Lambda timing out?
├── Check timeout setting (default 3s, max 15min)
│   └── Too low? Increase it
├── Check memory (more memory = more CPU)
│   └── CPU-bound? Increase memory
├── In a VPC?
│   ├── Yes: Does the VPC subnet have NAT Gateway / VPC endpoint?
│   │   └── No → Lambda in VPC can't reach internet without NAT GW
│   └── No → Not a VPC issue
├── Connecting to RDS/external service?
│   └── Check SG of the target allows Lambda's SG
└── Cold start issue?
    └── Use Provisioned Concurrency or optimize package size
```

### RDS High CPU / Slow Queries

```
RDS CPU consistently high?
├── Check Performance Insights → identify top SQL queries
├── Top queries are reads?
│   ├── Add Read Replicas to offload
│   ├── Add ElastiCache for frequently read data
│   └── Optimize queries (missing indexes?)
├── Top queries are writes?
│   ├── Scale up instance class (vertical scaling)
│   ├── Optimize write queries (batch inserts)
│   └── Consider Aurora (better write performance)
├── Connection count too high?
│   └── Use RDS Proxy (connection pooling)
└── Storage IOPS maxed out?
    └── Switch to io1/io2 or increase provisioned IOPS
```

### S3 403 Access Denied

```
S3 403 Forbidden?
├── Check IAM policy: does the user/role have s3:GetObject?
├── Check Bucket Policy: does it allow the caller?
├── Check S3 Block Public Access settings (account + bucket level)
├── Cross-account? Need BOTH bucket policy AND IAM policy
├── Object owned by different account? (ACL issue)
│   └── Enable BucketOwnerEnforced (disable ACLs)
├── Object encrypted with KMS? Caller needs kms:Decrypt
├── VPC Endpoint policy restricting access?
└── Using pre-signed URL? Check if signing credentials are still valid
```

### CloudFormation Stack Stuck in UPDATE_ROLLBACK_FAILED

```
Stack in UPDATE_ROLLBACK_FAILED?
├── Why? A resource can't be rolled back to previous state
├── Check Events tab for the specific error
├── Options:
│   ├── Fix the underlying resource manually, then:
│   │   └── ContinueUpdateRollback (console or CLI)
│   ├── Skip the problematic resource:
│   │   └── ContinueUpdateRollback --resources-to-skip "ResourceLogicalId"
│   └── Last resort:
│       └── Delete the stack (may need to retain some resources)
└── Prevention: always use DeletionPolicy and test in staging first
```

---

## Monitoring & Alerting Decision Tree

### Which CloudWatch Metric for Which Problem

```
Problem: High latency
├── ELB → TargetResponseTime
├── API Gateway → Latency, IntegrationLatency
├── Lambda → Duration
├── RDS → ReadLatency, WriteLatency
└── DynamoDB → SuccessfulRequestLatency

Problem: Errors
├── ELB → HTTPCode_Target_5XX_Count, UnHealthyHostCount
├── API Gateway → 4XXError, 5XXError
├── Lambda → Errors, Throttles
├── SQS → ApproximateNumberOfMessagesNotVisible (stuck messages)
└── DynamoDB → ThrottledRequests, SystemErrors

Problem: Resource exhaustion
├── EC2 → CPUUtilization (built-in), MemoryUtilization (agent)
├── RDS → FreeStorageSpace, CPUUtilization, FreeableMemory
├── EBS → VolumeQueueLength, BurstBalance (gp2)
├── Lambda → ConcurrentExecutions (approaching limit?)
└── SQS → ApproximateAgeOfOldestMessage (processing falling behind)
```

### When to Use CloudWatch vs X-Ray vs CloudTrail

| Scenario | Tool |
|----------|------|
| CPU is at 95%, need an alarm | CloudWatch Metrics + Alarms |
| Lambda is slow, need to find the bottleneck | X-Ray (distributed tracing) |
| Who deleted the production database? | CloudTrail |
| Are my Config rules compliant? | AWS Config |
| Application error rate spiking | CloudWatch Metrics + Logs |
| Request latency across microservices | X-Ray Service Map |
| Unauthorized API calls detected | GuardDuty (or CloudTrail + Athena) |

### Alarm -> SNS -> Lambda Remediation Pattern

```
CloudWatch Alarm triggers
  → SNS Topic receives notification
    → Lambda function invoked
      → Automated remediation action

Examples:
- CPU > 90% for 5 min → SNS → Lambda → add EC2 instance
- Unauthorized SG change detected (Config) → SNS → Lambda → revert SG
- RDS storage < 10% → SNS → Lambda → increase storage
- GuardDuty finding → EventBridge → SNS → Lambda → isolate instance
```

---

## Automation Patterns

### SSM Automation Runbooks

Pre-built or custom runbooks for common operational tasks:

| AWS-Managed Runbook | What It Does |
|---------------------|-------------|
| `AWS-RestartEC2Instance` | Stops and starts an EC2 instance |
| `AWS-StopEC2Instance` | Stops an EC2 instance |
| `AWS-CreateSnapshot` | Creates an EBS snapshot |
| `AWS-PatchInstanceWithRollback` | Patches an instance, rolls back on failure |
| `AWS-EnableS3BucketEncryption` | Enables default encryption on S3 bucket |
| `AWS-DisablePublicAccessForSecurityGroup` | Removes 0.0.0.0/0 rules from SG |

Custom runbooks: YAML or JSON documents with steps (aws:executeAwsApi, aws:runCommand, aws:branch, etc.)

### EventBridge Rules for Automated Responses

```
Event Source                    →  EventBridge Rule  →  Target
─────────────────────────────      ────────────────      ──────
EC2 state change (stopped)     →  Match pattern     →  SNS notification
GuardDuty finding (HIGH)       →  Match severity    →  Lambda (isolate instance)
Config compliance change       →  Match resource    →  SSM Automation
Health event (scheduled maint) →  Match service     →  Lambda (drain + failover)
CloudTrail (root login)        →  Match event name  →  SNS alert to security team
S3 object created              →  Match bucket/key  →  Lambda (process file)
```

EventBridge rule pattern example:
```json
{
  "source": ["aws.ec2"],
  "detail-type": ["EC2 Instance State-change Notification"],
  "detail": {
    "state": ["stopped"]
  }
}
```

### Config Auto-Remediation via SSM

```
Config Rule evaluates resource
  → NON_COMPLIANT
    → Auto-Remediation Action (SSM Automation document)
      → Fix the resource
        → Config re-evaluates → COMPLIANT

Common patterns:
┌─────────────────────────────────┬────────────────────────────────────────┐
│ Config Rule                     │ Remediation (SSM Runbook)              │
├─────────────────────────────────┼────────────────────────────────────────┤
│ s3-bucket-server-side-          │ AWS-EnableS3BucketEncryption           │
│ encryption-enabled              │                                        │
├─────────────────────────────────┼────────────────────────────────────────┤
│ restricted-ssh                  │ AWS-DisablePublicAccessForSecurityGroup│
├─────────────────────────────────┼────────────────────────────────────────┤
│ ebs-snapshot-public-            │ Custom: make snapshot private          │
│ restorable-check                │                                        │
├─────────────────────────────────┼────────────────────────────────────────┤
│ rds-instance-public-access-     │ Custom: disable public access          │
│ check                           │                                        │
└─────────────────────────────────┴────────────────────────────────────────┘
```

Set **max automatic remediation attempts** and **retry interval** to avoid infinite loops.

---

## Exam Day Quick Reminders

1. **The lab section is real AWS console** -- practice clicking through the console beforehand
2. **CloudWatch Agent** is the answer for memory/disk metrics -- burned into your brain
3. **SSM is the Swiss Army knife** for operations: Run Command, Session Manager, Patch Manager, Automation, Parameter Store
4. **Config = compliance state, CloudTrail = activity log** -- never confuse them
5. **SCPs restrict member accounts, NOT management account** -- trap question every time
6. **stop/start (not reboot) for system status check failures** -- migrates to new host
7. **gp2 burst credits deplete** on small volumes under sustained load -- migrate to gp3
8. **CloudFormation DeletionPolicy: Retain** saves your database when stack is deleted
9. **VPC Flow Logs capture metadata, not content** -- know the limitations
10. **Budget your time**: ~90 min for multiple choice, ~40 min for lab section
