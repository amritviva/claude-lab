# Systems Manager (SSM) — Exam Practice Questions

---

## Q1: Session Manager vs SSH

A security team mandates that all EC2 instance access must be audited, no SSH keys should be used, and no inbound ports should be open on Security Groups. How should the team access instances?

**A)** Use SSH with key pairs and audit via CloudTrail
**B)** Use SSM Session Manager with logging to S3 and CloudWatch
**C)** Open port 22 only from the corporate IP range
**D)** Use a bastion host in a public subnet

### Answer: B

**Why:** Session Manager meets all requirements: IAM-based authentication (no SSH keys), no inbound ports needed (agent communicates outbound on 443), and full session logging to S3 and CloudWatch for audit. CloudTrail logs who started sessions. Think of it as: the walkie-talkie goes through headquarters (SSM service), and every conversation is recorded.

- **A is wrong:** SSH requires port 22 open in Security Groups and SSH key management. CloudTrail doesn't log the actual session commands — only API calls.
- **C is wrong:** Port 22 open violates the "no inbound ports" requirement, even if restricted to corporate IP.
- **D is wrong:** Bastion hosts still require SSH keys and port 22. They add complexity without solving the audit or key management requirements.

---

## Q2: Instance Not Showing in SSM

A SysOps admin launches an EC2 instance using Amazon Linux 2023 but it doesn't appear in the Systems Manager managed instances list. What should they check? (Choose the MOST LIKELY cause)

**A)** The SSM Agent needs to be installed manually on Amazon Linux 2023
**B)** The EC2 instance profile doesn't have the `AmazonSSMManagedInstanceCore` IAM policy
**C)** Session Manager is not enabled in the region
**D)** The instance needs a public IP address

### Answer: B

**Why:** Amazon Linux 2023 comes with SSM Agent pre-installed, so the agent is fine. The most common reason an instance doesn't appear in SSM is a **missing or incorrect IAM instance profile**. The instance needs a role with `AmazonSSMManagedInstanceCore` policy for the agent to register with the SSM service.

- **A is wrong:** SSM Agent is pre-installed on Amazon Linux 2023. No manual installation needed.
- **C is wrong:** Session Manager is available in all regions by default. There's no "enable" step.
- **D is wrong:** Instances don't need a public IP for SSM. They need outbound HTTPS (443) — either via NAT Gateway, VPC endpoint, or internet gateway.

---

## Q3: Run Command vs SSH

A SysOps admin needs to install security patches on 200 EC2 instances across 3 regions. All instances have SSM Agent running. What is the MOST efficient approach?

**A)** SSH into each instance and run the patch command manually
**B)** Use SSM Run Command with the `AWS-RunPatchBaseline` document targeting instances by tag
**C)** Create a Lambda function that SSHs into each instance
**D)** Use EC2 User Data to run patches on next reboot

### Answer: B

**Why:** Run Command can target hundreds of instances simultaneously using tags. The `AWS-RunPatchBaseline` document is a pre-built SSM document specifically for applying patch baselines. It runs across all tagged instances in parallel with rate control, error thresholds, and output logging. No SSH required.

- **A is wrong:** Manual SSH into 200 instances is impractical, error-prone, and not auditable.
- **C is wrong:** Lambda SSH is a custom solution that requires managing SSH keys, network connectivity, and error handling. Run Command does this natively.
- **D is wrong:** User Data only runs at instance launch (or reboot with specific configuration). It's not designed for ongoing patch management.

---

## Q4: Patch Manager Configuration

A company requires that all production EC2 instances have Critical security patches applied within 3 days of release. Non-critical patches should be applied within 14 days. How should this be configured?

**A)** Create a custom patch baseline with auto-approval rules: Critical = 3 days, Others = 14 days
**B)** Use the AWS default patch baseline with no modifications
**C)** Write a Lambda function to check for patches and apply them
**D)** Use State Manager to check patch status hourly

### Answer: A

**Why:** Custom patch baselines let you define auto-approval rules by severity. Set Critical/Important patches to auto-approve after 3 days and other severities after 14 days. Associate the baseline with a Patch Group (tag your prod instances). Schedule a maintenance window to scan and install approved patches.

- **B is wrong:** AWS default baselines may not match the specific 3-day/14-day requirements. They use default auto-approval periods that may differ.
- **C is wrong:** Custom Lambda for patch management reinvents Patch Manager. More complexity, harder to maintain, no built-in compliance reporting.
- **D is wrong:** State Manager enforces configurations but doesn't replace Patch Manager's auto-approval and baseline features. Checking hourly doesn't help if patches aren't approved yet.

---

## Q5: Maintenance Windows

A company runs a critical application on EC2 instances. They need to apply OS patches every Sunday between 2 AM and 6 AM (4-hour window). If patching hasn't completed by 5:30 AM, no new patch operations should start. How should this be configured?

**A)** Maintenance window with duration of 4 hours and cutoff of 30 minutes
**B)** CloudWatch Events cron rule triggering a Lambda function
**C)** Maintenance window with duration of 4 hours and cutoff of 0
**D)** Run Command scheduled with a cron expression

### Answer: A

**Why:** Maintenance window configuration: Duration = 4 hours (2 AM to 6 AM), Cutoff = 30 minutes (stop starting new tasks at 5:30 AM). This ensures patching that started before 5:30 AM can finish, but no new patch operations begin after that. The cutoff provides a safety margin before the window closes.

- **B is wrong:** Lambda for scheduling is unnecessarily complex when Maintenance Windows natively support scheduling, targeting, and task execution.
- **C is wrong:** Cutoff of 0 means new tasks can start until the very last second of the window. Tasks starting at 5:59 AM might not finish before 6 AM, potentially impacting business hours.
- **D is wrong:** Run Command can be scheduled but doesn't have the maintenance window's cutoff concept. You'd need custom logic to stop starting new commands near the end.

---

## Q6: Hybrid Environment

A company manages 50 on-premises Linux servers alongside 200 EC2 instances. They want to use Systems Manager for all servers. How should they register the on-premises servers?

**A)** Install the SSM Agent and attach an IAM user's access keys
**B)** Create a Hybrid Activation, install SSM Agent, and register using the activation code
**C)** Create a VPN connection and the SSM Agent will auto-discover
**D)** Use AWS Outposts to bring SSM on-premises

### Answer: B

**Why:** Hybrid Activation is the process for registering on-premises servers with SSM. You create an activation in SSM (get activation code + ID), install the SSM Agent on each server, and register using the code. Registered servers appear as managed instances with a `mi-` prefix (instead of `i-` for EC2).

- **A is wrong:** Using IAM access keys on servers is a security anti-pattern. SSM uses the activation process with temporary credentials, not long-lived access keys.
- **C is wrong:** VPN provides network connectivity but doesn't register instances with SSM. The activation process is still required.
- **D is wrong:** Outposts is for running AWS infrastructure on-premises. It's a hardware solution, not needed for SSM management of existing servers.

---

## Q7: Automation Runbook

A SysOps admin needs to automate the following process: (1) Create an AMI from a running instance, (2) Wait for the AMI to be available, (3) Launch a test instance from the AMI, (4) Run validation tests, (5) If tests pass, update the launch template. What SSM feature should they use?

**A)** Run Command with a complex shell script
**B)** SSM Automation with a custom runbook
**C)** State Manager with a scheduled association
**D)** Patch Manager with a custom baseline

### Answer: B

**Why:** SSM Automation runs multi-step workflows with built-in support for: creating AMIs (`aws:createImage`), waiting for AWS operations (`aws:waitForAwsResourceProperty`), running commands (`aws:runCommand`), conditional logic, and approval steps. A runbook defines the entire process as sequential steps with error handling.

- **A is wrong:** Run Command executes a single command/script on instances. It doesn't orchestrate multi-step workflows with AMI creation, waiting, and conditional logic.
- **C is wrong:** State Manager enforces a desired configuration on instances. It's not designed for multi-step operational workflows.
- **D is wrong:** Patch Manager is specifically for OS/application patching, not custom operational workflows.

---

## Q8: State Manager vs AWS Config

A company wants to ensure that the CloudWatch agent is ALWAYS installed and running on all EC2 instances. If someone stops the agent, it should be automatically restarted. Which service is BEST?

**A)** AWS Config rule to detect non-compliance
**B)** SSM State Manager association that runs every 30 minutes
**C)** CloudWatch alarm on agent metrics
**D)** Lambda function triggered by EventBridge

### Answer: B

**Why:** State Manager continuously enforces desired state. Create an association using the `AWS-ConfigureAWSPackage` document to install/ensure CloudWatch agent is running, scheduled every 30 minutes. If someone stops the agent, the next association run reinstalls/restarts it automatically. State Manager ENFORCES; Config only DETECTS.

- **A is wrong:** Config detects that the agent isn't running but doesn't fix it. You'd need Config + SSM Automation for auto-remediation, which is more complex than State Manager alone.
- **C is wrong:** CloudWatch alarm would fire when agent stops, but it doesn't restart the agent. You'd need an alarm → Lambda → Run Command chain.
- **D is wrong:** EventBridge + Lambda works but is a custom solution. State Manager provides this enforcement natively.

---

## Q9: Inventory and Compliance

A security audit requires the company to identify all EC2 instances running a specific vulnerable version of OpenSSL. How should the SysOps team find these instances?

**A)** SSH into each instance and check the OpenSSL version
**B)** Use SSM Inventory to collect application metadata, then query for the vulnerable version
**C)** Check AWS Config for OpenSSL configuration
**D)** Use CloudWatch metrics to detect OpenSSL versions

### Answer: B

**Why:** SSM Inventory collects metadata from managed instances including installed applications, versions, and components. Enable inventory collection on all instances, then filter by application name and version to find instances running the vulnerable OpenSSL version. For advanced queries, sync inventory to S3 and use Athena.

- **A is wrong:** Manual SSH across potentially hundreds of instances is impractical and slow during a security audit.
- **C is wrong:** AWS Config monitors AWS resource configurations (S3 settings, Security Groups), not software installed on instances.
- **D is wrong:** CloudWatch doesn't collect software version information. It monitors performance metrics (CPU, memory, disk).

---

## Q10: Document Types

A team needs to create different SSM Documents for different purposes. Match the document types to their use cases:

Which document type would you use to define a multi-step operational workflow that creates a golden AMI from an existing instance?

**A)** Command document
**B)** Automation document
**C)** Session document
**D)** Policy document

### Answer: B

**Why:** SSM Document types serve different purposes:
- **Command document** = executed by Run Command on instances (run a script, install software)
- **Automation document** = multi-step workflows (create AMI, update stack, remediate) — executed by SSM Automation service
- **Session document** = configure Session Manager behavior (logging, shell type)
- **Policy document** = define State Manager associations (enforce desired state)

A golden AMI workflow requires multiple API-level steps (snapshot, create image, launch, test) — that's an Automation document.

- **A is wrong:** Command documents run ON instances. Creating an AMI is an API-level action, not an on-instance command.
- **C is wrong:** Session documents configure how interactive sessions work, not operational workflows.
- **D is wrong:** Policy documents define desired state enforcement, not multi-step operations.
