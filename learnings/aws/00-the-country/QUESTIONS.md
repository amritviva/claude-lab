# 00 - The Country: Exam Questions

---

## Q1 (SAA) — Region Selection

A company is expanding to Australia and must comply with Australian data sovereignty laws requiring all customer data to remain within Australian borders. They also want to minimise latency for their Sydney-based users. Which factor should be the **primary** consideration when selecting an AWS Region?

A. Cost — ap-southeast-2 is more expensive than us-east-1
B. Available services — ensure the required services are available in the Region
C. Compliance — data residency requirements mandate ap-southeast-2
D. Proximity — choosing the closest Region for lowest latency

**Answer: C**

**Why C is correct:** Compliance and data sovereignty are always the **first** filter when selecting a Region. If the law says data must stay in Australia, you MUST use ap-southeast-2 regardless of cost or latency. In the country analogy, it's like immigration law -- you can't choose to live in a cheaper country if your visa requires you to stay in Australia.

**Why others are wrong:**
- **A:** Cost matters but is secondary to legal compliance. You can't break the law to save money.
- **B:** Service availability matters but is checked after compliance. Most major services are available in ap-southeast-2.
- **D:** Proximity is important but is the same Region anyway. Even if it weren't, compliance trumps latency.

---

## Q2 (SAA) — Multi-AZ Architecture

A solutions architect is designing a web application that must remain available even if an entire data centre fails. The application uses EC2 instances, an RDS database, and stores session data in ElastiCache. Which combination of actions provides high availability? (Select TWO)

A. Deploy EC2 instances across multiple Regions
B. Deploy EC2 instances across multiple Availability Zones behind an ALB
C. Enable Multi-AZ deployment for RDS
D. Use a single large EC2 instance in a Cluster placement group
E. Store session data on EBS volumes

**Answer: B, C**

**Why B and C are correct:** Multi-AZ deployment distributes resources across cities (AZs) within a country (Region). If one city floods, the others keep running. EC2 across AZs with ALB handles web tier HA. RDS Multi-AZ gives automatic database failover.

**Why others are wrong:**
- **A:** Multi-Region is for disaster recovery, not just "data centre failure." It's overkill and adds complexity (international shipping vs domestic delivery).
- **D:** Cluster placement = all instances on the same rack. That's the OPPOSITE of HA -- if that rack fails, everything dies.
- **E:** EBS is single-AZ and not a session store. If the AZ fails, EBS data is inaccessible. ElastiCache with Multi-AZ replication is the right session store.

---

## Q3 (DVA) — Lambda Multi-AZ Behaviour

A developer deploys a Lambda function in ap-southeast-2. The function processes images uploaded to S3. During an AZ outage in ap-southeast-2a, the developer notices the Lambda function continues to work. Why?

A. Lambda functions are global services and run in all Regions simultaneously
B. Lambda functions are automatically deployed across multiple AZs within a Region
C. Lambda functions run on edge locations, not in AZs
D. The developer must have manually configured multi-AZ deployment for Lambda

**Answer: B**

**Why B is correct:** Lambda is multi-AZ by default. AWS automatically runs your Lambda function across multiple AZs within the Region -- you don't configure anything. In the country analogy, Lambda soldiers are stationed across all cities automatically, so if one city goes down, soldiers in other cities pick up the work.

**Why others are wrong:**
- **A:** Lambda is a Regional service, not global. It runs in the Region you deploy it in.
- **C:** Lambda runs in AZs within Regions, not at edge locations. Lambda@Edge is a separate service that runs at CloudFront edge locations.
- **D:** There is no manual multi-AZ configuration for Lambda -- it's automatic and you cannot change it.

---

## Q4 (SOA) — AZ Failure Recovery

A SysOps administrator receives alerts that EC2 instances in us-east-1a are experiencing degraded performance. RDS Multi-AZ failover has already occurred to us-east-1b. However, the web application is still showing errors. What is the most likely cause?

A. The RDS failover changed the database endpoint, requiring application configuration changes
B. The EC2 instances in us-east-1a are still receiving traffic because the ALB hasn't detected the failure
C. The application's Auto Scaling group is not configured to launch instances in multiple AZs
D. The EBS volumes in us-east-1a are corrupted and need to be restored from snapshots

**Answer: C**

**Why C is correct:** If the Auto Scaling group only launches instances in us-east-1a, when that AZ degrades, ASG cannot launch healthy replacements in other AZs. It's like having all your soldiers stationed in one city -- when that city has problems, there's nobody in other cities to take over. The fix: configure ASG to span multiple AZs.

**Why others are wrong:**
- **A:** RDS Multi-AZ uses a single DNS endpoint (CNAME) that automatically points to the new primary. No application changes needed.
- **B:** ALB has health checks. If instances are degraded, ALB would detect this via failed health checks and stop routing to them. The issue is no healthy instances to route TO.
- **D:** While possible, EBS corruption is a less likely root cause than ASG misconfiguration when the question says the AZ itself is degraded.

---

## Q5 (SAA) — Edge Locations

A company serves video content to users worldwide. They want to reduce latency for users in South America while their origin server is in us-east-1. Which AWS service uses edge locations to solve this?

A. S3 Transfer Acceleration
B. AWS Global Accelerator
C. Amazon CloudFront
D. Route 53 latency-based routing

**Answer: C**

**Why C is correct:** CloudFront is a CDN that caches content at edge locations (corner shops) worldwide. South American users get the video from a nearby edge location instead of travelling all the way to us-east-1. The first request goes to origin; subsequent requests are served from cache at the corner shop.

**Why others are wrong:**
- **A:** S3 Transfer Acceleration speeds up UPLOADS to S3, not content delivery to users.
- **B:** Global Accelerator routes traffic through the AWS backbone for better network paths, but doesn't cache content. It's for dynamic, non-cacheable traffic.
- **D:** Route 53 latency-based routing directs users to the closest Region, but you'd need an origin in South America. It doesn't cache content.

---

## Q6 (SAA) — Service Scope

A developer creates an IAM user in us-east-1. They then switch to ap-southeast-2 in the console. Can they see the IAM user?

A. No, IAM users are regional and must be created in each Region separately
B. Yes, IAM is a global service and users are visible in all Regions
C. No, but they can replicate the IAM user using cross-region replication
D. Yes, but only if they enable IAM cross-region sync

**Answer: B**

**Why B is correct:** IAM is a global service -- it operates at the "world government" level, not at the country (Region) level. An IAM user (citizen passport) is valid across all Regions. There's no concept of a "Regional" IAM user.

**Why others are wrong:**
- **A:** IAM is explicitly global. Unlike EC2 (AZ-scoped) or S3 (Regional), IAM has no Region.
- **C:** There is no IAM cross-region replication because there are no regions to replicate between.
- **D:** No such feature exists because IAM is already global by design.

---

## Q7 (SOA) — Cross-AZ Data Transfer

A SysOps administrator notices unexpectedly high data transfer costs. Investigation shows that an application in us-east-1a is making frequent API calls to a database in us-east-1b. What is the most cost-effective solution?

A. Move the application and database to the same AZ
B. Set up VPC peering between the two AZs
C. Use S3 Transfer Acceleration to speed up the data transfer
D. Enable cross-AZ data transfer free tier

**Answer: A**

**Why A is correct:** Cross-AZ data transfer costs ~$0.01/GB in each direction. Like shipping between cities -- it's cheap but adds up with high volume. Moving both to the same AZ (same city) makes the transfer free. However, this trades cost for availability -- if the AZ fails, both go down. The right production answer might be to accept the cost for HA, but the question asks for most cost-effective.

**Why others are wrong:**
- **B:** VPC peering connects separate VPCs, not AZs within the same VPC. AZs within a VPC already communicate via the VPC network.
- **C:** S3 Transfer Acceleration is for S3 uploads, not inter-AZ database traffic.
- **D:** There is no "cross-AZ data transfer free tier" -- this doesn't exist.

---

## Q8 (DVA) — AZ IDs vs AZ Names

A developer in Account A wants to ensure their EC2 instances are in the same physical data centre as instances in Account B for low-latency communication via VPC peering. They both launch in us-east-1a. Will this guarantee they're in the same physical AZ?

A. Yes, us-east-1a always maps to the same physical AZ across all accounts
B. No, AZ names are randomised per account; they should use AZ IDs instead
C. Yes, but only if both accounts are in the same AWS Organization
D. No, they need to use a Cluster placement group across accounts

**Answer: B**

**Why B is correct:** AWS randomises AZ name-to-physical-location mapping per account. So `us-east-1a` in Account A might be physically the same data centre as `us-east-1c` in Account B. It's like if two different maps of the same country labelled the cities differently. To coordinate, use **AZ IDs** (e.g., `use1-az1`) which are consistent across accounts.

**Why others are wrong:**
- **A:** This is the common misconception. AZ names are NOT consistent across accounts.
- **C:** Being in the same Organization doesn't change AZ name mapping.
- **D:** Placement groups cannot span accounts or VPCs.

---

## Q9 (SOA) — Opt-in Regions

A SysOps administrator tries to create resources in the Africa (Cape Town) region (af-south-1) but receives an access denied error. All other Regions work fine. What is the most likely issue?

A. The IAM policy doesn't include af-south-1 in the Resource ARN
B. af-south-1 is an opt-in Region that must be explicitly enabled in account settings
C. The administrator's account has exceeded the global service quota
D. af-south-1 requires a separate AWS account

**Answer: B**

**Why B is correct:** Some newer Regions (af-south-1, ap-east-1, me-south-1, etc.) are opt-in Regions that are disabled by default. They must be explicitly enabled in the AWS account settings before you can create resources there. It's like needing a special visa to enter a newly opened country -- the default passport doesn't cover it.

**Why others are wrong:**
- **A:** IAM policies use wildcards for Regions. The issue is the Region being disabled, not IAM permissions.
- **C:** Service quotas are per-Region. An issue in af-south-1 wouldn't be caused by quotas in other Regions.
- **D:** Opt-in Regions work within the same account -- no separate account needed.

---

## Q10 (SAA) — Multi-AZ Default Behaviour

A solutions architect is reviewing the high availability of an application that uses DynamoDB, Lambda, S3, EC2, and RDS. Which services require MANUAL multi-AZ configuration? (Select TWO)

A. DynamoDB
B. Lambda
C. EC2
D. S3
E. RDS

**Answer: C, E**

**Why C and E are correct:** EC2 instances are AZ-scoped -- you must manually launch them in multiple AZs (typically via Auto Scaling). RDS requires you to explicitly enable Multi-AZ deployment for automatic failover. In the country analogy, these soldiers must be manually stationed across cities.

**Why others are wrong:**
- **A:** DynamoDB automatically replicates data across 3 AZs within a Region. No configuration needed.
- **B:** Lambda automatically runs across multiple AZs. AWS manages this transparently.
- **D:** S3 Standard automatically stores objects across 3+ AZs (except One Zone-IA).

---

## Q11 (SAA) — Data Transfer Costs

A company has two applications: App-A runs in us-east-1 and App-B runs in eu-west-1. App-A sends 500 GB of data daily to App-B. The architect wants to reduce data transfer costs. Which approach is most effective?

A. Use VPC peering between us-east-1 and eu-west-1
B. Move both applications to the same Region
C. Use AWS Direct Connect between the two Regions
D. Compress data before transfer and use S3 Transfer Acceleration

**Answer: B**

**Why B is correct:** Cross-Region data transfer (international shipping) is the most expensive type at ~$0.02/GB. That's $10/day or $300/month for 500 GB. Moving both apps to the same Region eliminates cross-Region charges entirely. If they must be in different AZs, that's only ~$0.01/GB -- half the cost.

**Why others are wrong:**
- **A:** VPC peering across Regions still incurs cross-Region data transfer charges. The tunnel exists but shipping is still international.
- **C:** Direct Connect reduces internet-based transfer costs but cross-Region data transfer charges still apply for traffic within AWS between Regions.
- **D:** Compression helps but doesn't eliminate the cross-Region charge. Transfer Acceleration is for S3 uploads, not app-to-app communication.

---

## Q12 (DVA) — API Gateway Endpoint Types

A developer is building an API with API Gateway. Most users are in Australia, but some are global. The developer wants low latency for Australian users without over-engineering. Which API Gateway endpoint type should they choose?

A. Edge-optimized — routes through CloudFront edge locations globally
B. Regional — deploys in ap-southeast-2 only
C. Private — accessible only within a VPC
D. Global — automatically deploys in all Regions

**Answer: B**

**Why B is correct:** A Regional endpoint in ap-southeast-2 serves Australian users with low latency since the API and users are in the same country. For the small number of global users, latency is acceptable. Edge-optimized would add CloudFront overhead for the majority of local users. Regional is the simpler, right-sized choice.

**Why others are wrong:**
- **A:** Edge-optimized routes ALL traffic through CloudFront, which adds a hop for users already close to the Region. It's better when users are spread globally.
- **C:** Private endpoints are for internal VPC-only access, not public-facing APIs.
- **D:** There is no "Global" API Gateway endpoint type. This doesn't exist.
