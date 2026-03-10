# Systems Manager (SSM) — Fleet Commander

> **SSM is the fleet commander managing all soldiers (instances) remotely. Session Manager is the walkie-talkie (no SSH needed). Run Command broadcasts orders to the entire fleet. Patch Manager inspects uniforms. Automation runs complex multi-step operations.**

---

## ELI10

Imagine you're a general commanding 1,000 soldiers spread across the country. You need to talk to any soldier instantly (Session Manager), shout orders to all of them at once (Run Command), make sure everyone's wearing the right uniform and has the latest gear (Patch Manager), and run complex battle plans with many steps (Automation). You can see every soldier's equipment (Inventory), enforce rules about what they should look like (State Manager), and track incidents in a war room (OpsCenter). The best part? You never need to open any doors (port 22) — your orders flow through secure channels.

---

## The Concept

### SSM — The Full Fleet Management System

```
┌──────────────────────────────────────────────────────────────┐
│                   SYSTEMS MANAGER (SSM)                       │
│                                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Session     │  │ Run Command │  │ Patch Manager       │  │
│  │ Manager     │  │             │  │                     │  │
│  │ (SSH-free   │  │ (Broadcast  │  │ (Patch baselines,   │  │
│  │  shell      │  │  orders to  │  │  maintenance        │  │
│  │  access)    │  │  fleet)     │  │  windows)           │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Automation  │  │ State       │  │ Inventory           │  │
│  │             │  │ Manager     │  │                     │  │
│  │ (Multi-step │  │ (Enforce    │  │ (What's installed   │  │
│  │  runbooks)  │  │  desired    │  │  on each instance)  │  │
│  │             │  │  state)     │  │                     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                               │
│  ┌─────────────┐  ┌──────────────────────────────────────┐  │
│  │ OpsCenter   │  │ Parameter Store                       │  │
│  │ (Incident   │  │ (See 28-secrets-ssm for full details) │  │
│  │  tracking)  │  │                                       │  │
│  └─────────────┘  └──────────────────────────────────────┘  │
│                                                               │
│  All powered by the SSM AGENT on each managed instance       │
└──────────────────────────────────────────────────────────────┘
```

### SSM Agent — The Communication Device

```
┌──────────────────────────────────────────────────────────┐
│                    SSM AGENT                               │
│                                                            │
│  What: Software agent that runs on managed instances       │
│                                                            │
│  Pre-installed on:                                         │
│  • Amazon Linux 1 & 2                                      │
│  • Amazon Linux 2023                                       │
│  • Ubuntu Server (16.04+)                                  │
│  • Windows Server (2016+)                                  │
│                                                            │
│  Must install on:                                          │
│  • Older AMIs                                              │
│  • On-premises servers (hybrid environment)                │
│  • Custom AMIs                                             │
│                                                            │
│  Requirements:                                             │
│  • IAM role with AmazonSSMManagedInstanceCore policy       │
│  • Outbound HTTPS (443) to SSM endpoints                   │
│  • Agent must be running                                   │
│                                                            │
│  No inbound ports needed (no port 22!)                     │
│  Agent polls SSM service over HTTPS                        │
└──────────────────────────────────────────────────────────┘
```

### Session Manager — SSH Replacement

```
┌──────────────────────────────────────────────────────────┐
│              SESSION MANAGER vs SSH                        │
│                                                            │
│  Traditional SSH:                                          │
│  ┌──────┐    Port 22    ┌──────────┐                      │
│  │ User │──────────────>│ EC2      │                      │
│  └──────┘   SSH key     │ Instance │                      │
│             needed      └──────────┘                      │
│  ⚠ Open port 22 in Security Group                         │
│  ⚠ Manage SSH keys                                        │
│  ⚠ Bastion host needed for private subnets                │
│  ⚠ No centralized logging                                 │
│                                                            │
│  Session Manager:                                          │
│  ┌──────┐    HTTPS     ┌──────────┐    ┌────────┐        │
│  │ User │─────────────>│ SSM      │───>│ EC2    │        │
│  └──────┘  IAM auth    │ Service  │    │Instance│        │
│             No keys     └──────────┘    └────────┘        │
│  ✓ No port 22 needed (no inbound rules!)                  │
│  ✓ No SSH keys to manage                                  │
│  ✓ No bastion hosts needed                                │
│  ✓ IAM-based access control                               │
│  ✓ Full session logging to CloudWatch/S3                  │
│  ✓ Audit trail in CloudTrail                              │
│  ✓ Works for private subnet instances                     │
│  ✓ Port forwarding supported                              │
└──────────────────────────────────────────────────────────┘
```

### Run Command — Broadcast Orders

```
┌──────────────────────────────────────────────────────────┐
│                   RUN COMMAND                               │
│                                                            │
│  Send commands to one or thousands of instances at once:   │
│                                                            │
│  ┌──────────────┐                                         │
│  │ SSM Document │  "Run this shell script on all          │
│  │ (command)    │   instances tagged Env=Prod"             │
│  └──────┬───────┘                                         │
│         │                                                  │
│    ┌────┴─────┬──────────┬──────────┐                     │
│    v          v          v          v                     │
│  Instance1  Instance2  Instance3  Instance4               │
│  (Prod)     (Prod)     (Prod)     (Prod)                 │
│                                                            │
│  Target selection:                                         │
│  • By tags (Env=Prod, Team=API)                            │
│  • By instance IDs                                         │
│  • By resource group                                       │
│  • All managed instances                                   │
│                                                            │
│  Features:                                                 │
│  • Rate control (concurrency: 10 at a time)                │
│  • Error threshold (stop if 5% fail)                       │
│  • Timeout per command                                     │
│  • Output to S3 or CloudWatch Logs                         │
│  • No SSH needed — uses SSM agent                          │
│  • Notifications via SNS                                   │
│                                                            │
│  Common SSM Documents:                                     │
│  • AWS-RunShellScript (Linux)                              │
│  • AWS-RunPowerShellScript (Windows)                       │
│  • AWS-RunPatchBaseline (patching)                         │
│  • AWS-ConfigureAWSPackage (install/update software)       │
└──────────────────────────────────────────────────────────┘
```

### Patch Manager — Uniform Inspector

```
┌──────────────────────────────────────────────────────────┐
│                   PATCH MANAGER                            │
│                                                            │
│  Patch Baseline (the uniform standard):                    │
│  ┌──────────────────────────────────────────────┐         │
│  │ • Defines which patches to approve/reject     │         │
│  │ • OS-specific (Linux, Windows, macOS)         │         │
│  │ • Auto-approval rules (severity-based)        │         │
│  │ • Custom baselines or AWS default baselines   │         │
│  │ • Example: "Auto-approve Critical patches     │         │
│  │   after 7 days"                               │         │
│  └──────────────────────────────────────────────┘         │
│                                                            │
│  Maintenance Window (inspection schedule):                 │
│  ┌──────────────────────────────────────────────┐         │
│  │ • Schedule: cron or rate expression            │         │
│  │ • Duration: how long the window stays open     │         │
│  │ • Cutoff: stop starting new tasks N minutes    │         │
│  │   before window closes                         │         │
│  │ • Targets: which instances to patch            │         │
│  │ • Tasks: Run Command, Automation, Lambda, SF   │         │
│  └──────────────────────────────────────────────┘         │
│                                                            │
│  Patch Compliance:                                         │
│  ┌──────────────────────────────────────────────┐         │
│  │ • Shows which instances are compliant/non-     │         │
│  │   compliant with their patch baseline          │         │
│  │ • Missing patches listed per instance          │         │
│  │ • Integrates with AWS Config for compliance    │         │
│  │   monitoring                                   │         │
│  │ • Compliance data in SSM Compliance dashboard  │         │
│  └──────────────────────────────────────────────┘         │
│                                                            │
│  Patch Group (tag-based):                                  │
│  • Tag: "Patch Group" = "WebServers"                       │
│  • Associates instances with a specific patch baseline     │
│  • One patch group → one patch baseline                    │
└──────────────────────────────────────────────────────────┘
```

### Automation — Runbooks

```
┌──────────────────────────────────────────────────────────┐
│                   AUTOMATION                               │
│                                                            │
│  Multi-step automated workflows (like simple Step Functions│
│  but built into SSM):                                      │
│                                                            │
│  Automation Document (Runbook):                            │
│  ┌──────────────────────────────────────────────┐         │
│  │ Step 1: Create AMI from instance              │         │
│  │ Step 2: Launch new instance from AMI           │         │
│  │ Step 3: Run tests on new instance              │         │
│  │ Step 4: If tests pass → update ASG             │         │
│  │ Step 5: If tests fail → terminate instance     │         │
│  └──────────────────────────────────────────────┘         │
│                                                            │
│  AWS provides pre-built runbooks:                          │
│  • AWS-RestartEC2Instance                                  │
│  • AWS-StopEC2Instance                                     │
│  • AWS-CreateImage                                         │
│  • AWS-UpdateCloudFormationStack                           │
│  • AWS-ConfigureS3BucketVersioning                         │
│                                                            │
│  Triggered by:                                             │
│  • Manual execution                                        │
│  • Maintenance window                                      │
│  • AWS Config remediation                                  │
│  • EventBridge rule                                        │
│  • CloudWatch alarm action                                 │
│                                                            │
│  Features:                                                 │
│  • Approval steps (human approval before proceeding)       │
│  • Conditional branching                                   │
│  • Rate control for fleet operations                       │
│  • Cross-account/region execution                          │
└──────────────────────────────────────────────────────────┘
```

### State Manager — Desired State Enforcement

```
┌──────────────────────────────────────────────────────────┐
│                   STATE MANAGER                            │
│                                                            │
│  Ensures instances stay in a desired configuration:        │
│                                                            │
│  Association:                                              │
│  "Every 30 minutes, ensure all Prod instances              │
│   have CloudWatch agent installed and running"             │
│                                                            │
│  • Uses SSM Documents (same as Run Command)                │
│  • Runs on schedule or on instance launch                  │
│  • Reports compliance/non-compliance                       │
│  • Auto-remediation: re-applies if drift detected          │
│                                                            │
│  vs AWS Config:                                            │
│  Config = DETECT drift/non-compliance                      │
│  State Manager = ENFORCE desired state (prevent drift)     │
└──────────────────────────────────────────────────────────┘
```

### Inventory — Asset Tracking

```
┌──────────────────────────────────────────────────────────┐
│                   INVENTORY                                │
│                                                            │
│  Collects metadata from managed instances:                 │
│  • Installed applications                                  │
│  • OS version and patches                                  │
│  • Network configuration                                   │
│  • Running services                                        │
│  • Windows registry entries                                │
│  • Custom inventory (your own data)                        │
│                                                            │
│  Sync to S3 → Query with Athena                            │
│  Visualize in QuickSight                                   │
│                                                            │
│  "Show me all instances running Java 8"                    │
│  "Which instances have OpenSSL < 3.0?"                     │
└──────────────────────────────────────────────────────────┘
```

### Hybrid Environment — On-Premises Management

```
┌──────────────────────────────────────────────────────────┐
│              HYBRID ENVIRONMENT                            │
│                                                            │
│  SSM manages on-premises servers too:                      │
│                                                            │
│  On-Premises Server                                        │
│  ┌──────────────────┐                                     │
│  │ SSM Agent +      │                                     │
│  │ Hybrid Activation│ ──HTTPS──> SSM Service              │
│  │ (mi-xxxxxxxxxx)  │                                     │
│  └──────────────────┘                                     │
│                                                            │
│  Setup:                                                    │
│  1. Create a Hybrid Activation in SSM                      │
│  2. Get activation code + activation ID                    │
│  3. Install SSM Agent on-prem server                       │
│  4. Register with activation code                          │
│  5. Server appears as "mi-" managed instance               │
│                                                            │
│  All SSM features work: Session Manager, Run Command,      │
│  Patch Manager, Inventory, State Manager                   │
│                                                            │
│  "mi-" prefix = managed instance (on-prem)                 │
│  "i-" prefix = EC2 instance (cloud)                        │
└──────────────────────────────────────────────────────────┘
```

### OpsCenter — Incident Dashboard

```
┌──────────────────────────────────────────────────────────┐
│                   OPSCENTER                                │
│                                                            │
│  Centralized incident management:                          │
│  • OpsItems = incidents/issues to track                    │
│  • Auto-created from CloudWatch Alarms, Config rules,      │
│    EventBridge events                                      │
│  • Link related resources, runbooks, CloudWatch data       │
│  • Track resolution status                                 │
│  • Cross-account aggregation (with Organizations)          │
│                                                            │
│  Integrates with:                                          │
│  • CloudWatch (alarms → OpsItems)                          │
│  • Config (non-compliance → OpsItems)                      │
│  • EventBridge (events → OpsItems)                         │
│  • Automation (run remediation runbooks)                    │
└──────────────────────────────────────────────────────────┘
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- **Session Manager vs SSH** — no port 22, no bastion hosts, IAM-based access
- **Patch Manager** — patch baselines, maintenance windows, compliance
- **Hybrid environments** — manage on-premises servers with SSM agent
- **Run Command** — fleet-wide operations without SSH

### DVA-C02 (Developer)
- **SSM Documents** — command documents, automation documents
- **Parameter Store** — see 28-secrets-ssm (hierarchical paths, SecureString)
- **Run Command** — execute scripts across instances
- **SSM integration** — Lambda/ECS retrieving parameters at runtime

### SOA-C02 (SysOps)
- **Session Manager setup** — IAM role, agent, endpoints, logging to S3/CloudWatch
- **Patch Manager** — baselines, patch groups, compliance reporting, maintenance windows
- **Troubleshooting** — instance not appearing in SSM (agent not running, IAM role missing, no outbound 443)
- **State Manager** — enforce configurations, detect drift
- **Inventory** — track installed software across fleet
- **OpsCenter** — incident tracking and remediation

---

## Key Numbers

| Fact | Value |
|------|-------|
| SSM Agent port | Outbound HTTPS (443) only |
| Run Command max instances per invocation | 50 by tag, unlimited by resource group |
| Run Command output max (console) | 48,000 characters |
| Run Command output max (S3) | Unlimited |
| Maintenance window max duration | 24 hours |
| Maintenance window cutoff | Up to 23 hours before end |
| Patch baseline auto-approval delay | 0-100 days |
| Session Manager idle timeout | 20 minutes (configurable) |
| Hybrid activation instances | Up to 1,000 per activation |
| OpsItems retention | 3 years |

---

## Cheat Sheet

- **SSM = central fleet management.** Session Manager, Run Command, Patch Manager, Automation, Inventory, State Manager.
- **SSM Agent** = required on all managed instances. Pre-installed on Amazon Linux, Ubuntu, Windows Server.
- **Session Manager = SSH replacement.** No port 22, no SSH keys, no bastion hosts. IAM-based access + logging.
- **Run Command** = execute commands on hundreds of instances at once. No SSH. Uses SSM Documents.
- **Patch Manager** = patch baselines + maintenance windows. Tag instances into Patch Groups.
- **Maintenance window** = schedule for patching, automation, command execution.
- **Automation** = multi-step runbooks. Used for: AMI creation, stack updates, remediation.
- **State Manager** = enforce desired state. If drift detected, auto-reapply.
- **Inventory** = track what's installed on every instance. Export to S3 for Athena queries.
- **OpsCenter** = incident tracking. Auto-creates OpsItems from CloudWatch, Config, EventBridge.
- **Hybrid** = manage on-premises servers. Install SSM agent + hybrid activation. Shows as `mi-` prefix.
- **Instance not in SSM?** Check: (1) SSM agent running, (2) IAM role attached, (3) outbound 443 open, (4) VPC endpoint or internet access.
- **Parameter Store** = see `28-secrets-ssm/` for full details. Part of SSM but covered separately.
- **SSM Documents** = JSON/YAML defining actions. Types: Command, Automation, Session, Policy.
