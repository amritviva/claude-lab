# Route 53 — Exam Questions

> 12 scenario-based questions mixing SAA-C03, DVA-C02, and SOA-C02 perspectives.

---

### Q1 (SAA) — CNAME vs Alias at Zone Apex

A company wants to point their naked domain `example.com` (no www) to a CloudFront distribution. Which DNS record type should they use?

A. CNAME record pointing to the CloudFront distribution domain
B. A record with Alias pointing to the CloudFront distribution
C. A record with the CloudFront IP address
D. TXT record with the CloudFront URL

**Answer: B**

**Why B is correct:** Alias records work at the zone apex (naked domain) and can point to CloudFront distributions. They're free for AWS resource queries and automatically resolve to the current IP addresses of the target. Like the ministry having a direct hotline to the CloudFront post office network — no intermediary needed.

**Why A is wrong:** CNAME records CANNOT be used at the zone apex (example.com). DNS specification (RFC) prohibits it. CNAME works for `www.example.com` but not `example.com`. This is the #1 Route 53 exam trap.

**Why C is wrong:** CloudFront uses dynamic IPs that change. Hardcoding an IP address would break when CloudFront changes its infrastructure.

**Why D is wrong:** TXT records are for text metadata (SPF, domain verification), not for routing traffic.

---

### Q2 (SAA) — Routing Policy Selection: Multi-Region Low Latency

A global application is deployed in us-east-1, eu-west-1, and ap-southeast-2. Users should be routed to the AWS region that provides the **lowest latency**. Which routing policy should be used?

A. Geolocation routing
B. Geoproximity routing
C. Latency-based routing
D. Weighted routing with equal weights

**Answer: C**

**Why C is correct:** Latency-based routing measures the actual network latency between the user and each AWS region, then routes to the lowest-latency region. A user in Japan might get better latency to us-west-2 than to ap-northeast-1 depending on network conditions. Latency routing uses real measurements, not geographic assumptions.

**Why A is wrong:** Geolocation routes by the user's country/continent, not by actual network performance. A user in Turkey might be routed to the EU even if US East has lower latency.

**Why B is wrong:** Geoproximity routes by geographic distance (with optional bias), not actual latency. Geographic distance doesn't always correlate with network latency.

**Why D is wrong:** Weighted routing splits traffic by percentage regardless of user location. A user in Sydney could be routed to us-east-1 — terrible latency.

---

### Q3 (SAA) — Failover + Health Checks

A company runs their primary application in us-east-1 and a static "maintenance page" on S3 in us-west-2. If the primary application becomes unavailable, users should see the maintenance page. Which configuration achieves this?

A. Simple routing with two A records
B. Failover routing with primary pointing to ALB (health checked) and secondary pointing to S3 website
C. Weighted routing with 100% to ALB and 0% to S3
D. Multi-value answer routing with both targets

**Answer: B**

**Why B is correct:** Failover routing with health checks is designed for active-passive scenarios. Primary record points to the ALB with a health check. When the health check fails, Route 53 automatically routes ALL traffic to the secondary record (S3 maintenance page). Like having a backup phone number that automatically activates when the main line goes down.

**Why A is wrong:** Simple routing with multiple values returns ALL records to the client. Users could randomly get the S3 maintenance page even when the app is healthy.

**Why C is wrong:** Weighted routing with 0% to S3 means S3 NEVER gets traffic, even if the ALB is down. Weighted routing doesn't failover — it's a fixed split.

**Why D is wrong:** Multi-value returns multiple healthy IPs. If both pass health checks, users could randomly get the maintenance page. If the ALB fails, users only get S3 — which works, but multi-value is not the right pattern for active-passive DR.

---

### Q4 (SAA) — Geolocation vs Geoproximity

A European company must ensure that users in the EU are ALWAYS served by their EU data center due to GDPR compliance. Users from other regions should be served by the nearest data center. Which routing policy should be used?

A. Latency-based routing
B. Geolocation routing
C. Geoproximity routing
D. Weighted routing

**Answer: B**

**Why B is correct:** Geolocation routing routes based on the user's geographic location (continent, country, or US state). EU users will ALWAYS be routed to the EU data center — guaranteed by political boundary. This ensures GDPR compliance by keeping EU user traffic within EU infrastructure. Other regions get the "default" record pointing to their nearest server.

**Why A is wrong:** Latency-based routing might send EU users to a US server if it happens to have lower latency. No guarantee of data sovereignty.

**Why C is wrong:** Geoproximity routes by distance, not political boundaries. An EU user near the UK-US Atlantic cable might get routed to the US server. No compliance guarantee.

**Why D is wrong:** Weighted routing distributes by percentage regardless of user location. An EU user could be routed anywhere.

---

### Q5 (DVA) — Weighted Routing for Canary

A developer is migrating from an old API (v1) to a new API (v2). They want to gradually shift traffic: start with 10% to v2, validate, then increase to 50%, then 100%. Which Route 53 configuration supports this?

A. Two Simple routing records
B. Weighted routing: v1 weight=90, v2 weight=10 (adjust over time)
C. Failover routing with v1 as primary and v2 as secondary
D. Multi-value answer with both v1 and v2

**Answer: B**

**Why B is correct:** Weighted routing lets you assign relative weights to records. Set v1=90 and v2=10 for 90/10 split. After validation, change to v1=50, v2=50. Finally, v1=0, v2=100. Smooth traffic migration. Like gradually redirecting phone calls from the old office to the new one.

**Why A is wrong:** Simple routing returns all records and the client picks randomly. You can't control the percentage.

**Why C is wrong:** Failover is all-or-nothing — either 100% to primary or 100% to secondary. No gradual migration.

**Why D is wrong:** Multi-value returns multiple IPs for the client to pick randomly. No percentage control.

---

### Q6 (SOA) — Health Check for Private Resources

A SysOps administrator needs Route 53 to health-check a private RDS instance (10.0.1.50) that is not publicly accessible. Standard health checks fail. What is the correct approach?

A. Create a health check using the RDS private IP and allow Route 53 IPs in the security group
B. Create a CloudWatch alarm monitoring the RDS instance, then create a health check based on the CloudWatch alarm state
C. Make the RDS instance public temporarily for health checks
D. Use a VPC endpoint for Route 53 health checkers

**Answer: B**

**Why B is correct:** Route 53 health checkers operate from the public internet — they cannot reach private resources. The solution is to create a CloudWatch alarm (e.g., monitoring RDS CPU, connections, or a custom metric from a Lambda health check function). Then create a Route 53 health check of type "CloudWatch Alarm." When the alarm goes to ALARM state, the health check fails, triggering DNS failover. Like having an internal security guard call the ministry when something goes wrong, instead of the ministry trying to inspect the building directly.

**Why A is wrong:** Route 53 health checkers are external. Even if you allow their IPs, they can't reach private subnets (no route from the internet to private IPs).

**Why C is wrong:** Making RDS public is a massive security risk and violates best practices.

**Why D is wrong:** Route 53 health checkers don't use VPC endpoints. This feature doesn't exist.

---

### Q7 (SAA) — Alias Record Targets

Which of the following is a valid Alias record target? (Choose TWO)

A. An EC2 instance's public DNS name (ec2-54-1-2-3.compute-1.amazonaws.com)
B. An Application Load Balancer DNS name
C. A CloudFront distribution domain name
D. An RDS instance endpoint

**Answer: B and C**

**Why B is correct:** ALB (and NLB, CLB) DNS names are valid Alias targets. Route 53 resolves the Alias to the current IPs of the load balancer.

**Why C is correct:** CloudFront distribution domain names (d111111.cloudfront.net) are valid Alias targets. This is one of the most common Alias use cases.

**Why A is wrong:** EC2 public DNS names are NOT valid Alias targets. You must use an A record with the EC2's Elastic IP, or put an ALB in front.

**Why D is wrong:** RDS instance endpoints are NOT valid Alias targets. Use a CNAME record for RDS, or route through an ALB.

---

### Q8 (SOA) — DNSSEC Configuration

A SysOps administrator is enabling DNSSEC signing for a hosted zone. What prerequisite must be met?

A. The hosted zone must be a private hosted zone
B. A KMS Customer Managed Key (CMK) must exist in us-east-1
C. DNSSEC is only available for .com and .org domains
D. All records must use Alias type

**Answer: B**

**Why B is correct:** Route 53 DNSSEC signing requires a KMS Customer Managed Key (asymmetric, ECC_NIST_P256) in the **us-east-1 region** specifically. This key signs the DNS records. Like the ministry using an official government seal — the seal (key) must be stored in the capital (us-east-1).

**Why A is wrong:** DNSSEC is for public hosted zones, not private. Private zones are within your VPC — no external spoofing risk.

**Why C is wrong:** DNSSEC works with any TLD supported by Route 53.

**Why D is wrong:** DNSSEC signs all record types. There's no requirement for Alias records.

---

### Q9 (SAA) — Multi-Value vs Simple Routing

A company has 4 web servers with public IPs. They want Route 53 to return only healthy servers to DNS queries. They don't have a load balancer. Which routing policy should they use?

A. Simple routing with 4 IP values
B. Multi-value answer routing with health checks
C. Weighted routing with equal weights
D. Failover routing with 4 records

**Answer: B**

**Why B is correct:** Multi-value answer routing returns up to 8 healthy records. Each record has its own health check — unhealthy servers are excluded from responses. The client picks randomly from the healthy set. Not a true load balancer, but provides basic DNS-level health awareness. Like the ministry giving you 4 phone numbers but crossing out any that are disconnected.

**Why A is wrong:** Simple routing returns ALL values regardless of health. No health check support. Dead servers still get traffic.

**Why C is wrong:** Weighted routing with equal weights works and supports health checks, but the question describes a basic scenario — multi-value is simpler and purpose-built for this.

**Why D is wrong:** Failover only supports primary + secondary (two records, active-passive). Can't handle 4 active servers.

---

### Q10 (SOA) — Troubleshooting Health Checks

A Route 53 health check configured for `http://54.1.2.3:80/health` is failing even though the application is healthy. Curling the endpoint from an EC2 instance in the same VPC returns HTTP 200. What is the MOST LIKELY cause?

A. The health check interval is too short
B. The instance's security group doesn't allow inbound HTTP from Route 53 health checker IP ranges
C. The health check is using HTTPS instead of HTTP
D. The response body exceeds 5,120 bytes

**Answer: B**

**Why B is correct:** Route 53 health checkers come from specific public IP ranges. If the security group only allows traffic from your VPC CIDR, the health checkers are blocked. You need to allow inbound HTTP on port 80 from Route 53 health checker IPs. AWS publishes these IP ranges. Like the ministry sending inspectors to check if the building is open — if the security guard doesn't recognize them, they get turned away.

**Why A is wrong:** Health check interval (30s or 10s) doesn't cause failures. It determines how often checks run.

**Why C is wrong:** The question says HTTP is configured. If it were HTTPS, the error would be different (SSL handshake failure, not health check failure).

**Why D is wrong:** Response body check is optional. If enabled, only the first 5,120 bytes are checked. A large response doesn't cause a failure — it's just truncated.

---

### Q11 (SAA) — Private Hosted Zone + Multi-Account

A company has a shared services VPC (Account A) and application VPCs (Account B, Account C). They want all VPCs to resolve `internal.company.com` DNS records. How should this be configured?

A. Create a private hosted zone in each account
B. Create one private hosted zone in Account A and associate it with VPCs in Accounts B and C
C. Create a public hosted zone and restrict access via IAM
D. Use Route 53 Resolver to forward queries from Accounts B and C to Account A

**Answer: B**

**Why B is correct:** A private hosted zone can be associated with VPCs in different accounts using cross-account authorization. Create the zone in Account A, then authorize and associate VPCs from Accounts B and C. All VPCs resolve the same DNS records. One embassy serving multiple territories.

**Why A is wrong:** Multiple hosted zones for the same domain create management overhead and inconsistency. Changes must be replicated manually across accounts.

**Why C is wrong:** Public hosted zones are accessible from the internet. Internal DNS should be private for security.

**Why D is wrong:** Resolver is for hybrid (on-premises ↔ AWS) DNS forwarding, not for sharing hosted zones across accounts. Cross-account VPC association is simpler.

---

### Q12 (SAA) — Geoproximity with Bias

A company has servers in us-east-1 and eu-west-1. Currently, latency-based routing sends South American users to us-east-1 and African users to eu-west-1. They want to shift some African traffic to us-east-1 to reduce load on the EU servers. Which approach works?

A. Switch to geolocation routing and assign African countries to us-east-1
B. Switch to geoproximity routing and set a positive bias on us-east-1
C. Use weighted routing with higher weight for us-east-1
D. Add more servers in eu-west-1 to handle the load

**Answer: B**

**Why B is correct:** Geoproximity with bias lets you expand or shrink the geographic "catchment area" of a resource. A positive bias on us-east-1 pulls traffic from farther away — including some African regions. A negative bias on eu-west-1 pushes traffic away. You can fine-tune exactly how much traffic shifts. Like moving a border line on a map — us-east-1's territory expands into Africa's proximity.

**Why A is wrong:** Geolocation routing assigns entire continents/countries. You'd have to manually pick which African countries go to US East, which is rigid and doesn't account for varying distances within Africa.

**Why C is wrong:** Weighted routing splits ALL traffic by percentage regardless of location. South American users might get sent to EU, which is worse.

**Why D is wrong:** Adding servers in EU handles load but doesn't shift traffic. The question specifically asks to shift African traffic to US East.
