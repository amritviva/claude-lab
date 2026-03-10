# AWS Config — Exam Practice Questions

---

## Q1: Config vs CloudTrail

A security team needs to answer two questions: (1) "Is this S3 bucket currently encrypted?" and (2) "Who disabled encryption on this bucket last Tuesday?" Which services answer which question?

**A)** AWS Config answers both questions
**B)** CloudTrail answers both questions
**C)** Config answers #1 (current state), CloudTrail answers #2 (who did it)
**D)** Config answers #2 (change history), CloudTrail answers #1 (current state)

### Answer: C

**Why:** Config records the configuration STATE of resources — it knows whether the S3 bucket is encrypted right now and tracks the full configuration timeline. CloudTrail logs API ACTIVITY — it knows who called `PutBucketEncryption` or `DeleteBucketEncryption` and when. Together: Config tells you WHAT changed, CloudTrail tells you WHO changed it.

- **A is wrong:** Config records what a resource looks like, but doesn't track who made the change (no principal/user info in Config items).
- **B is wrong:** CloudTrail logs API calls but doesn't evaluate compliance state. It can show the API call but not the resulting configuration.
- **D is wrong:** Reversed — Config tracks state (what it looks like now), CloudTrail tracks activity (who did what).

---

## Q2: Auto-Remediation

A company's Config rule detects that an S3 bucket has public read access enabled. They want the bucket to be automatically made private when this violation is detected. What should they configure?

**A)** A Lambda function triggered by an SNS notification from Config
**B)** An auto-remediation action on the Config rule using an SSM Automation runbook
**C)** An EventBridge rule that triggers a Step Functions workflow
**D)** A CloudWatch alarm that triggers an EC2 Auto Scaling action

### Answer: B

**Why:** Config rules natively support auto-remediation via SSM Automation runbooks. When a resource is evaluated as NON_COMPLIANT, Config automatically triggers the specified runbook (e.g., `AWS-DisableS3BucketPublicReadWrite`) to fix the issue. Built-in, no custom code needed, with retry configuration.

- **A is wrong:** Custom Lambda triggered by SNS works but is unnecessarily complex. Auto-remediation is a native Config feature — no need for custom solutions.
- **C is wrong:** EventBridge + Step Functions is over-engineered for a simple remediation that SSM Automation handles natively.
- **D is wrong:** CloudWatch alarms monitor metrics, not compliance state. Auto Scaling scales instances, not S3 bucket configurations.

---

## Q3: Managed vs Custom Rules

A company has a specific policy: all EC2 instances must have a tag called "CostCenter" with a non-empty value. There's no AWS managed rule for this exact requirement. What should they do?

**A)** Use the managed rule `required-tags` and configure it with the "CostCenter" tag
**B)** Write a custom Lambda-backed Config rule
**C)** This can't be done with AWS Config
**D)** Use CloudTrail to monitor for untagged instances

### Answer: A

**Why:** The `required-tags` managed rule checks whether resources have specified tags. You configure it with the tag key "CostCenter" (and optionally required values). This is an AWS managed rule that supports custom tag requirements — no custom code needed.

- **B is wrong:** A custom rule would work but is unnecessary when the `required-tags` managed rule handles this exact use case. Always prefer managed rules over custom when available.
- **C is wrong:** AWS Config absolutely supports tag compliance checking via the `required-tags` managed rule.
- **D is wrong:** CloudTrail logs API calls, not resource tag compliance. It doesn't evaluate whether resources have specific tags.

---

## Q4: Configuration Recorder

A SysOps admin enables AWS Config in a new region but no resources are being recorded. What is the MOST LIKELY issue?

**A)** AWS Config needs to be enabled per-resource manually
**B)** The Configuration Recorder hasn't been started, or the IAM role or S3 delivery bucket is misconfigured
**C)** AWS Config only works in us-east-1
**D)** The resources don't support AWS Config

### Answer: B

**Why:** Three things must be correct: (1) Configuration Recorder must be STARTED (it can be created but not started), (2) the IAM role must have permissions to read resource configs and write to S3, (3) the S3 delivery bucket must exist and accept writes from Config. Any of these misconfigurations will prevent recording.

- **A is wrong:** Config records all supported resource types by default (unless you restrict to specific types). You don't enable it per-resource.
- **C is wrong:** AWS Config works in all commercial regions. It's a regional service — you enable it per-region.
- **D is wrong:** Config supports 300+ resource types. While some resources aren't supported, it's unlikely that ALL resources in the region are unsupported.

---

## Q5: Multi-Account Compliance

A company with 100 AWS accounts in an Organization needs a single dashboard showing compliance across all accounts. They want to see which accounts have non-compliant S3 buckets. What should they configure?

**A)** Enable Config in each account and manually check compliance
**B)** Create a Config Aggregator in the management account and deploy Organization Config rules
**C)** Use CloudWatch dashboards to aggregate Config metrics
**D)** Use AWS Trusted Advisor for compliance checking

### Answer: B

**Why:** Config Aggregator collects compliance data from all accounts in the Organization into a single view. Organization Config rules deploy rules consistently across all 100 accounts. The management account sees aggregate compliance: "72 accounts compliant, 28 non-compliant for s3-bucket-encryption."

- **A is wrong:** Manually checking 100 accounts is impractical. Aggregator automates this.
- **C is wrong:** CloudWatch dashboards show metrics, not Config compliance data. Config has its own dashboard and Aggregator.
- **D is wrong:** Trusted Advisor checks a fixed set of best practices. It doesn't support custom compliance rules or the level of detail Config provides.

---

## Q6: Conformance Packs

A healthcare company needs to ensure all AWS resources comply with HIPAA regulations across their 20 accounts. They need to deploy the same set of compliance rules consistently. What should they use?

**A)** Deploy individual Config rules one by one in each account
**B)** Deploy a HIPAA Conformance Pack across the Organization
**C)** Use AWS Shield Advanced for HIPAA compliance
**D)** Enable AWS CloudTrail for HIPAA logging

### Answer: B

**Why:** Conformance Packs are pre-packaged collections of Config rules aligned to compliance frameworks. AWS provides a HIPAA pack with relevant rules. Deploy it as an Organization Conformance Pack — it automatically applies to all 20 accounts. One action deploys 30+ rules consistently.

- **A is wrong:** Deploying rules individually across 20 accounts is error-prone and hard to maintain. Conformance Packs bundle and deploy consistently.
- **C is wrong:** Shield Advanced is DDoS protection, not compliance monitoring.
- **D is wrong:** CloudTrail provides audit logging, which is part of HIPAA compliance, but doesn't evaluate resource configurations against HIPAA rules.

---

## Q7: Configuration Timeline

An EC2 instance's Security Group was changed unexpectedly and an internal application broke. The team needs to: (1) See what the Security Group looked like before the change, (2) Identify who made the change. What tools do they use?

**A)** Config for both — it tracks changes and who made them
**B)** Config timeline for the previous configuration, CloudTrail for the API call that changed it
**C)** CloudWatch Logs for both
**D)** VPC Flow Logs for the Security Group change

### Answer: B

**Why:** Config's configuration timeline shows the Security Group's configuration at every point in time — you can compare the before and after to see exactly what rules changed. CloudTrail shows the `AuthorizeSecurityGroupIngress` or `RevokeSecurityGroupIngress` API call, including who made it, when, and from which IP. Perfect partnership.

- **A is wrong:** Config tracks WHAT changed but not WHO. It records configuration items, not the IAM principal who made the change.
- **C is wrong:** CloudWatch Logs don't track Security Group configurations or changes.
- **D is wrong:** VPC Flow Logs capture network traffic (packets), not Security Group rule changes.

---

## Q8: Custom Rule Trigger

A developer creates a custom Config rule backed by a Lambda function. The rule should evaluate EC2 instances whenever their configuration changes (Security Groups, tags, instance type, etc.) AND also run every 24 hours to catch any missed changes. What trigger configuration should they use?

**A)** Configuration change trigger only
**B)** Periodic trigger (24 hours) only
**C)** Both configuration change AND periodic triggers
**D)** EventBridge rule to trigger the Lambda every 24 hours

### Answer: C

**Why:** Config rules support hybrid triggers — both configuration change AND periodic. Configuration change triggers provide real-time evaluation when resources change. The 24-hour periodic trigger catches anything that might have been missed and ensures regular compliance checks. This is the most thorough approach.

- **A is wrong:** Configuration change trigger alone misses cases where the evaluation logic changes (new policy) or where changes aren't captured.
- **B is wrong:** 24-hour periodic trigger alone means up to 24 hours of non-compliance before detection. Configuration change trigger provides near-real-time evaluation.
- **D is wrong:** EventBridge can trigger Lambda independently, but it bypasses Config's compliance tracking. The evaluation results wouldn't appear in Config's compliance dashboard.

---

## Q9: Advanced Query

A security team needs to quickly find all S3 buckets across the account that do NOT have encryption enabled. They want an immediate answer, not a compliance evaluation. What Config feature should they use?

**A)** Create a Config rule for S3 encryption and wait for evaluation
**B)** Use Config Advanced Query: `SELECT * WHERE resourceType = 'AWS::S3::Bucket' AND configuration.serverSideEncryptionConfiguration IS NULL`
**C)** Check S3 console for each bucket manually
**D)** Run a Lambda function to list all buckets and check encryption

### Answer: B

**Why:** Config Advanced Query allows SQL-like queries against the current configuration state of all recorded resources. The query returns results immediately — no need to create a rule and wait for evaluation. It queries the Config resource database directly.

- **A is wrong:** Creating a Config rule and waiting for evaluation takes time. The requirement is an immediate answer.
- **C is wrong:** Manual console checking doesn't scale and is slow.
- **D is wrong:** Lambda works but requires writing code. Advanced Query provides this capability natively with SQL-like syntax.

---

## Q10: Remediation Retry

A Config rule detects non-compliant resources and triggers auto-remediation via SSM Automation. The remediation occasionally fails due to transient API throttling. What can the SysOps admin configure to handle this?

**A)** Nothing — Config doesn't support remediation retries
**B)** Configure remediation with automatic retries (up to 5 attempts) and a delay between retries
**C)** Create a CloudWatch alarm for remediation failures
**D)** Use a Step Functions workflow for remediation instead of SSM Automation

### Answer: B

**Why:** Config auto-remediation supports automatic retries — up to 5 attempts with configurable delay between them. If the SSM Automation runbook fails due to transient throttling, Config waits and retries. This handles temporary API issues gracefully.

- **A is wrong:** Config explicitly supports remediation retries. This was added as a feature.
- **C is wrong:** A CloudWatch alarm would alert you about failures but wouldn't automatically retry the remediation.
- **D is wrong:** Step Functions is more complex and doesn't integrate as natively with Config's remediation as SSM Automation does.
