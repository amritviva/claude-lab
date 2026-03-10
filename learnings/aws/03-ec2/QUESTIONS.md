# 03 - EC2: Exam Questions

---

## Q1 (SAA) — Purchase Option Selection

A company runs a batch data processing job every night that takes 4-6 hours. The job can be interrupted and restarted without data loss. The company wants to minimise costs. Which purchase option is most appropriate?

A. On-Demand Instances
B. Reserved Instances (1-year, All Upfront)
C. Spot Instances
D. Dedicated Hosts

**Answer: C**

**Why C is correct:** Spot Instances offer up to 90% discount and are perfect for fault-tolerant, interruptible workloads like batch processing. The job "can be interrupted and restarted" is the key phrase -- that's the Spot Instance sweet spot. It's like bidding at an auction for a temporary Airbnb -- you might get kicked out, but the savings are massive, and you can just re-book.

**Why others are wrong:**
- **A:** On-Demand works but costs 10x more than Spot. No reason to pay full price for a fault-tolerant batch job.
- **B:** Reserved Instances require 1-3 year commitment for a job that runs a few hours nightly. The capacity is wasted during the day.
- **D:** Dedicated Hosts are for licensing compliance or regulatory requirements, not cost optimization.

---

## Q2 (DVA) — User Data vs Metadata

A developer needs to retrieve the IAM role credentials currently attached to an EC2 instance from within the instance itself. Which endpoint should they query?

A. `http://169.254.169.254/latest/user-data`
B. `http://169.254.169.254/latest/meta-data/iam/security-credentials/role-name`
C. `http://169.254.169.254/latest/dynamic/instance-identity/document`
D. `http://localhost/iam/credentials`

**Answer: B**

**Why B is correct:** Instance metadata at 169.254.169.254 provides information ABOUT the instance, including IAM role credentials. The path `/meta-data/iam/security-credentials/{role-name}` returns the temporary access key, secret key, and session token. It's the soldier's internal radio -- they ask "what's my current VIP badge credentials?" and the metadata service responds.

**Why others are wrong:**
- **A:** User data is the bootstrap script (first-day instructions), not instance information. It returns whatever script you passed at launch.
- **C:** The instance identity document contains instance ID, Region, account ID -- but not IAM credentials.
- **D:** This endpoint doesn't exist. The metadata service is always at 169.254.169.254 (link-local address).

---

## Q3 (SAA) — Placement Groups

A financial trading company needs the lowest possible network latency between 20 EC2 instances running a high-frequency trading application. All instances are in the same Region. Which placement strategy should they use?

A. Spread placement group
B. Partition placement group
C. Cluster placement group
D. No placement group, just use enhanced networking

**Answer: C**

**Why C is correct:** Cluster placement groups put all instances on the same rack in the same AZ, providing the lowest possible network latency (10 Gbps bidirectional). It's like putting all soldiers in the same room at the same desk -- they can pass notes instantly. For HPC and low-latency trading, this is the only answer.

**Why others are wrong:**
- **A:** Spread placement puts each instance on different hardware racks. Maximum isolation but HIGHER latency between instances. Opposite of what's needed.
- **B:** Partition placement groups separate instances into logical partitions on different racks. Good for big data (Hadoop/Kafka), not for lowest latency.
- **D:** Enhanced networking improves single-instance performance but doesn't guarantee instances are physically close to each other.

---

## Q4 (SOA) — Status Checks

A SysOps administrator receives a CloudWatch alarm that an EC2 instance has failed its system status check but passes its instance status check. What does this indicate and what is the correct action?

A. The application on the instance has crashed; reboot the instance
B. The underlying AWS hardware has an issue; stop and start the instance (moves to new hardware)
C. The instance's OS is unresponsive; reboot the instance
D. The EBS volume is detached; reattach it

**Answer: B**

**Why B is correct:** System status checks verify AWS's infrastructure (power, network, hardware). A failure means the physical host has an issue -- it's like the building the soldier's room is in has structural problems. The fix: stop and start (NOT reboot) the instance, which migrates it to a new physical host. Reboot keeps it on the same host.

**Why others are wrong:**
- **A:** Application crashes would cause instance status check failure, not system status check failure.
- **C:** OS issues cause instance status check failures. System status checks are about underlying hardware.
- **D:** EBS detachment would show as I/O errors in instance monitoring, not a system status check failure.

---

## Q5 (SAA) — Reserved Instance vs Savings Plan

A company has a steady-state workload running m5.xlarge instances 24/7 in us-east-1. They also plan to experiment with c5 and r5 instances in the future. They want maximum cost savings with flexibility. Which purchase option is best?

A. Standard Reserved Instances for m5.xlarge
B. Convertible Reserved Instances for m5.xlarge
C. Compute Savings Plan
D. EC2 Instance Savings Plan

**Answer: C**

**Why C is correct:** Compute Savings Plans offer up to 66% savings and apply across ANY instance family, Region, OS, or tenancy. The company wants flexibility to change instance types (m5 → c5/r5), which Compute Savings Plans handle. It's like a flexible gym membership -- you commit to spending $/hr but can use any equipment in any branch.

**Why others are wrong:**
- **A:** Standard RIs are locked to a specific instance family (m5). Switching to c5 or r5 would waste the reservation.
- **B:** Convertible RIs allow changing instance family but only offer up to 54% savings (less than Compute SP's 66%) and require explicit conversion actions.
- **D:** EC2 Instance Savings Plans give the deepest discount (~72%) but are locked to a specific instance family in a specific Region. No flexibility for c5/r5.

---

## Q6 (DVA) — IMDSv2

A security audit flags that an EC2 instance's metadata endpoint is vulnerable to SSRF (Server-Side Request Forgery) attacks. What is the recommended remediation?

A. Block access to 169.254.169.254 using Security Groups
B. Require IMDSv2 (Instance Metadata Service Version 2) which requires a session token
C. Disable the instance metadata service entirely
D. Encrypt the metadata responses using KMS

**Answer: B**

**Why B is correct:** IMDSv2 requires a two-step process: first a PUT request to get a session token (with a TTL), then use that token in subsequent GET requests. SSRF attacks typically can't perform this two-step dance because they're limited to simple GET requests. It's like requiring a two-factor check at the internal radio -- you need a session badge before asking questions.

**Why others are wrong:**
- **A:** Security Groups operate at the network level and cannot block traffic to the link-local metadata address (169.254.169.254).
- **C:** Disabling metadata entirely breaks many AWS features (IAM role credentials, instance identity, etc.). Too drastic.
- **D:** Encryption of metadata responses is not a feature. The issue is unauthorized ACCESS, not data-in-transit encryption.

---

## Q7 (SOA) — CloudWatch Metrics

A SysOps administrator needs to monitor memory utilization on EC2 instances. After checking CloudWatch, they find CPU, network, and disk I/O metrics but no memory metrics. Why?

A. Memory metrics require an enhanced monitoring license
B. Memory metrics are only available for Dedicated Hosts
C. Memory metrics require the CloudWatch Agent to be installed on the instance
D. Memory metrics are available under a different CloudWatch namespace

**Answer: C**

**Why C is correct:** EC2 default CloudWatch metrics are hypervisor-level: CPU, network, disk I/O, status checks. Memory and disk USAGE are OS-level metrics that require the CloudWatch Agent installed inside the instance. It's like the building manager (hypervisor) knows how much electricity a room uses (CPU) but needs a sensor INSIDE the room to know how full the filing cabinets are (memory).

**Why others are wrong:**
- **A:** There is no "enhanced monitoring license." The CloudWatch Agent is free to install; you pay for custom metric ingestion.
- **B:** Memory metrics have nothing to do with Dedicated Hosts. All instance types need the agent.
- **D:** The metrics simply don't exist without the agent. There's no hidden namespace.

---

## Q8 (SAA) — Hibernate

A company runs a specialised analytics application that takes 15 minutes to initialise (loading large datasets into memory). They want to quickly stop and resume the application while preserving the in-memory state. What should they use?

A. Stop and start the instance (data in memory survives)
B. Create an AMI before stopping, then launch from the AMI
C. Use EC2 Hibernate to save RAM contents to the encrypted EBS root volume
D. Use Instance Store to persist memory between stops

**Answer: C**

**Why C is correct:** EC2 Hibernate dumps the contents of RAM to the encrypted EBS root volume before stopping. When started, RAM is restored and the application resumes exactly where it left off -- no 15-minute re-initialization. It's like a soldier going to sleep with a note of exactly where they left off, then waking up and continuing immediately.

**Why others are wrong:**
- **A:** Stopping an EC2 instance wipes RAM. The application would need to reinitialize (15 minutes wasted).
- **B:** Creating an AMI captures the disk state but NOT the RAM contents. The application would still need to re-load data into memory.
- **D:** Instance Store is ephemeral and lost on stop. It doesn't persist anything, let alone memory state.

---

## Q9 (SAA) — Spot Fleet

A media company needs to process 10,000 video files. Each file takes about 5 minutes. The processing is stateless and can be retried. They want to minimize cost while completing the job within 24 hours. What architecture should they use?

A. 10 On-Demand c5.4xlarge instances running continuously
B. A Spot Fleet with mixed instance types and the lowestPrice allocation strategy
C. 50 Reserved Instances for the 24-hour period
D. A single p3.16xlarge GPU instance

**Answer: B**

**Why B is correct:** Spot Fleet lets you request a collection of Spot Instances across multiple instance types and AZs. The `lowestPrice` strategy picks the cheapest available capacity. Since the work is stateless and retriable, Spot interruptions just mean re-queuing that video. Mixed instance types increase the chance of getting capacity. It's like bidding at multiple auctions simultaneously -- you take the cheapest deals available.

**Why others are wrong:**
- **A:** On-Demand costs 10x more than Spot. For a stateless, retriable workload, this is a waste.
- **C:** Reserved Instances require 1-3 year commitment. You can't reserve for 24 hours.
- **D:** A single instance is a bottleneck. 10,000 files at 5 min each = 833 hours on one machine. Parallel processing across many instances is needed.

---

## Q10 (DVA) — Instance Profile

A developer creates an IAM role with S3 read permissions and tries to assign it to an EC2 instance using the AWS CLI. The command fails. What is the most likely issue?

A. The role needs to be wrapped in an instance profile before it can be attached to EC2
B. IAM roles cannot be attached to EC2 instances via CLI
C. The role needs the `iam:PassRole` permission
D. The developer's IAM user needs the `ec2:AssociateIamInstanceProfile` permission

**Answer: A**

**Why A is correct:** EC2 doesn't directly use IAM roles -- it uses **instance profiles**, which are containers for roles. The AWS Console automatically creates an instance profile when you create a role "for EC2," but the CLI does not. You must manually create an instance profile and add the role to it. It's like the VIP badge (role) needs to be placed in a badge holder (instance profile) before the soldier can wear it.

**Why others are wrong:**
- **B:** IAM roles CAN be attached via CLI. The issue is the missing instance profile wrapper.
- **C:** `iam:PassRole` is needed by the PERSON attaching the role, not by the role itself. While this could also cause failures, the question says the CLI command itself fails, suggesting an API-level issue.
- **D:** This permission is needed but isn't the "most likely" first issue -- the instance profile creation is the more fundamental requirement.

---

## Q11 (SOA) — EC2 Recovery

A SysOps administrator wants to automatically recover an EC2 instance if it fails system status checks. The instance must keep its private IP, public IP, Elastic IP, metadata, and placement group. What should they configure?

A. Auto Scaling group with min=1, max=1
B. CloudWatch alarm with EC2 recovery action
C. AWS Lambda function triggered by CloudWatch Events to terminate and relaunch
D. EC2 instance with a custom health check script

**Answer: B**

**Why B is correct:** CloudWatch alarm with the EC2 `recover` action migrates the instance to new hardware while preserving: instance ID, private IP, Elastic IP, metadata, placement group, and attached EBS volumes. It's an in-place hardware migration. Like moving a soldier to a new barracks room while keeping all their personal effects and badge numbers intact.

**Why others are wrong:**
- **A:** Auto Scaling would terminate the old instance and launch a NEW one with a different instance ID, private IP, and potentially different AZ. Not a true recovery.
- **C:** Lambda-based termination and relaunch creates a new instance. Same problem as Auto Scaling -- new identity.
- **D:** Custom health checks don't have the ability to trigger EC2 recovery actions.

---

## Q12 (SAA) — Elastic IP Cost

A developer allocates 5 Elastic IPs. They associate 2 with running instances, 1 with a stopped instance, and leave 2 unassociated. How many EIPs are they being charged for?

A. 0 (Elastic IPs are free)
B. 2 (only the ones on running instances are free)
C. 3 (the stopped instance and 2 unassociated EIPs)
D. 5 (all Elastic IPs have charges)

**Answer: C**

**Why C is correct:** Elastic IPs are free ONLY when associated with a RUNNING instance. You're charged for: EIPs associated with stopped instances and EIPs not associated with any instance. The logic: AWS has limited IPv4 addresses and charges you for wasting them. It's like having a permanent PO Box -- free while you're using it, but the post office charges you rent if you leave it empty.

- 2 on running instances = free
- 1 on stopped instance = CHARGED
- 2 unassociated = CHARGED
- Total charged: 3

**Why others are wrong:**
- **A:** EIPs are NOT unconditionally free. They're only free when actively used.
- **B:** Close but wrong -- the 2 on running instances ARE free, but you're also charged for the stopped instance EIP (3 total, not 2).
- **D:** The 2 on running instances are free.

---

## Q13 (DVA) — AMI Cross-Region

A developer has a custom AMI in us-east-1 that they need to use in ap-southeast-2. What must they do?

A. AMIs are global, so they can use it directly in ap-southeast-2
B. Copy the AMI from us-east-1 to ap-southeast-2
C. Create a snapshot of the AMI and share it with ap-southeast-2
D. Export the AMI to S3 and import it in ap-southeast-2

**Answer: B**

**Why B is correct:** AMIs are Regional resources. To use one in another Region, you must copy it using the `ec2:CopyImage` API or the console's "Copy AMI" action. It's like a training manual (AMI) that's stored at one base -- if another base needs it, you photocopy it and ship it there.

**Why others are wrong:**
- **A:** AMIs are NOT global. They're Regional and must be explicitly copied.
- **C:** Snapshots underlie AMIs but you copy the AMI itself, not the snapshot independently. The AMI copy process handles snapshot copying.
- **D:** Export/import is for moving AMIs outside of AWS (to on-premises). Between Regions, use the built-in copy feature.
