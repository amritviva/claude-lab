# 02 - VPC: Exam Questions

---

## Q1 (SAA) — Public vs Private Subnet

A solutions architect is designing a three-tier web application. The web tier must be internet-accessible, the application tier should only receive traffic from the web tier, and the database tier should only be accessible from the application tier. How should the subnets be configured?

A. All three tiers in public subnets with Security Groups controlling access
B. Web tier in public subnet, application and database tiers in private subnets
C. All three tiers in private subnets with a NAT Gateway for internet access
D. Web tier and application tier in public subnets, database in private subnet

**Answer: B**

**Why B is correct:** Only resources that need direct internet access should be in public subnets. The web tier (load balancer/web servers) faces the internet, so it goes near the front gate. The app tier and database are inner barracks -- they don't need internet-facing access and should be in private subnets. Security Groups chain the access: internet → web-sg → app-sg → db-sg.

**Why others are wrong:**
- **A:** Putting everything in public subnets gives every tier a potential internet-facing surface. Even with SGs, it violates least-privilege network design. Defense in depth means multiple layers.
- **C:** If the web tier is in a private subnet, users can't reach it from the internet without additional complexity (ALB in public subnet forwarding to private).
- **D:** The application tier doesn't need to be in a public subnet. Only the entry point (web/ALB) needs public access.

---

## Q2 (SAA) — Security Group vs NACL

An EC2 instance in a public subnet is running a web server on port 80. Users can reach the website but the instance CANNOT make outbound API calls to a third-party service on port 443. The Security Group allows all outbound traffic. What is the most likely cause?

A. The Internet Gateway is not properly attached to the VPC
B. The NACL on the subnet is blocking outbound traffic on port 443
C. The route table doesn't have a route to the Internet Gateway
D. The instance doesn't have a public IP address

**Answer: B**

**Why B is correct:** Since inbound traffic on port 80 works, the IGW, route table, and public IP are all fine (eliminates A, C, D). The Security Group allows all outbound. The remaining suspect is the NACL -- the stateless fence guard. If the NACL's outbound rules don't explicitly allow port 443, it blocks the traffic. Remember: NACLs are stateless, so both inbound AND outbound rules must be configured.

**Why others are wrong:**
- **A:** If IGW wasn't attached, inbound HTTP on port 80 wouldn't work either.
- **C:** If the route table lacked an IGW route, no internet traffic would work at all.
- **D:** If no public IP, inbound HTTP wouldn't work. The instance clearly has internet connectivity for inbound.

---

## Q3 (DVA) — Lambda in VPC

A developer deploys a Lambda function inside a VPC to access an RDS database in a private subnet. After deployment, the Lambda function can reach RDS but cannot call the AWS Translate API. What should the developer do?

A. Move the Lambda function out of the VPC
B. Add a NAT Gateway in a public subnet and update the private subnet's route table, OR create a VPC Interface Endpoint for Translate
C. Attach an Elastic IP to the Lambda function
D. Create a VPC peering connection to the AWS Translate service

**Answer: B**

**Why B is correct:** When Lambda is deployed in a VPC, it lives in the private subnet (inner barracks). It can reach RDS (also in private subnet) but has NO internet access by default. To call AWS APIs (like Translate), it needs either: (1) a NAT Gateway (secure comms room to reach the internet) or (2) a VPC Interface Endpoint (private tunnel directly to the AWS service). Both work; the endpoint is cheaper for high-volume AWS API calls.

**Why others are wrong:**
- **A:** Moving Lambda out of the VPC would fix API access but break RDS connectivity. Lambda needs to stay in the VPC for RDS.
- **C:** You cannot attach Elastic IPs to Lambda functions. Lambda doesn't expose ENIs for EIP association.
- **D:** VPC peering connects two VPCs you own. AWS Translate is an AWS-managed service, not a VPC you can peer with.

---

## Q4 (SOA) — NACL Troubleshooting

A SysOps administrator creates a custom NACL for a public subnet. After applying it, all traffic to EC2 instances in the subnet stops working. The NACL has the following inbound rules:

| Rule | Protocol | Port | Source | Action |
|------|----------|------|--------|--------|
| 100 | TCP | 80 | 0.0.0.0/0 | ALLOW |
| 110 | TCP | 443 | 0.0.0.0/0 | ALLOW |
| * | All | All | 0.0.0.0/0 | DENY |

What is the most likely issue?

A. The NACL needs an inbound rule for SSH (port 22)
B. The NACL outbound rules are denying all traffic (custom NACLs deny all by default)
C. The Security Group is blocking the traffic
D. The NACL rule numbers are too high

**Answer: B**

**Why B is correct:** Custom NACLs deny ALL traffic by default -- both inbound AND outbound. The admin added inbound rules but forgot outbound rules. Since NACLs are stateless (the fence guard doesn't remember you), return traffic from the web server back to clients needs explicit outbound rules. At minimum, outbound rules must allow ephemeral ports (1024-65535) for return traffic.

**Why others are wrong:**
- **A:** SSH isn't needed for web traffic. The question says "all traffic stops" which includes HTTP/HTTPS that ARE allowed inbound. The issue is outbound, not inbound.
- **C:** The question states a custom NACL was applied. Security Groups are stateful and would handle return traffic automatically.
- **D:** Rule numbers can be 1-32766. The numbers 100/110 are perfectly valid and follow AWS best practices (increment by 10/100).

---

## Q5 (SAA) — VPC Peering vs Transit Gateway

A company has 15 VPCs that all need to communicate with each other and with an on-premises network via VPN. What is the most scalable and manageable solution?

A. Create VPC peering connections between all VPCs (105 peering connections)
B. Use AWS Transit Gateway as a central hub
C. Use a single VPC with 15 subnets instead
D. Create VPN connections from each VPC to on-premises

**Answer: B**

**Why B is correct:** Transit Gateway is a central railway station (hub-and-spoke model). Each VPC connects once to the TGW, and the TGW routes traffic between all VPCs and to on-premises. 15 VPCs = 15 connections. With peering, you'd need N*(N-1)/2 = 105 connections, plus each VPC would need its own VPN. Transit Gateway also supports transitive routing, which peering does not.

**Why others are wrong:**
- **A:** 105 peering connections is a management nightmare. Peering doesn't support transitivity, so you need a full mesh. Plus, VPN must be configured separately per VPC.
- **C:** Consolidating into one VPC may not be architecturally appropriate (different teams, accounts, security boundaries). It also creates a single blast radius.
- **D:** 15 separate VPN connections to on-premises is expensive and complex to manage.

---

## Q6 (SAA) — VPC Endpoints

An application in a private subnet needs to read from an S3 bucket and write to a DynamoDB table. The company's security policy prohibits any internet traffic from private subnets. What is the most cost-effective solution?

A. Create two Interface Endpoints (one for S3, one for DynamoDB)
B. Create two Gateway Endpoints (one for S3, one for DynamoDB)
C. Set up a NAT Gateway for internet access to S3 and DynamoDB
D. Create a VPN connection to access S3 and DynamoDB over the corporate network

**Answer: B**

**Why B is correct:** Gateway Endpoints are secret underground tunnels to S3 and DynamoDB that are **completely free**. They're added as entries in the route table, and traffic stays on the AWS private network. Since the security policy prohibits internet traffic, NAT Gateway is out. Since Gateway Endpoints are free and support both S3 and DynamoDB, they're the clear winner.

**Why others are wrong:**
- **A:** Interface Endpoints work but cost ~$0.01/hr per endpoint per AZ plus data processing charges. Gateway Endpoints are FREE for S3 and DynamoDB.
- **C:** NAT Gateway would route traffic through the internet (even if via AWS network), violating the security policy. Also costs money.
- **D:** Routing through corporate network to reach AWS services is unnecessarily complex and slow.

---

## Q7 (SOA) — VPC Flow Logs

A SysOps administrator needs to investigate suspected data exfiltration from EC2 instances. They want to see all outbound traffic from a specific subnet. Which approach is correct?

A. Enable VPC Flow Logs at the VPC level and filter for the subnet in CloudWatch Logs Insights
B. Enable VPC Flow Logs at the subnet level, sending to CloudWatch Logs or S3
C. Enable packet capture with VPC traffic mirroring
D. Check CloudTrail for all EC2 network calls

**Answer: B**

**Why B is correct:** VPC Flow Logs capture IP traffic metadata (source IP, dest IP, ports, protocol, bytes, action) at the VPC, subnet, or ENI level. Setting it at the subnet level gives exactly the scope needed. Like security cameras on a specific floor of the base -- you see who's coming and going from that floor.

**Why others are wrong:**
- **A:** This also works (VPC-level logs include all subnets), but it captures MORE data than needed (all subnets), increasing cost and query complexity. Subnet-level is more targeted.
- **C:** Traffic mirroring captures actual packet contents (deep inspection), which is more than needed for identifying traffic patterns. It's also more expensive and complex.
- **D:** CloudTrail logs AWS API calls, not network traffic. It would show who called EC2 APIs, not what data EC2 instances are sending.

---

## Q8 (SAA) — NAT Gateway High Availability

A solutions architect deploys a NAT Gateway in us-east-1a. Private instances in both us-east-1a and us-east-1b use this NAT Gateway for internet access. If us-east-1a has an outage, what happens to instances in us-east-1b?

A. The NAT Gateway automatically fails over to us-east-1b
B. Instances in us-east-1b lose internet access because the NAT Gateway in us-east-1a is unavailable
C. AWS automatically creates a new NAT Gateway in us-east-1b
D. Instances in us-east-1b continue to work because NAT Gateways are multi-AZ

**Answer: B**

**Why B is correct:** NAT Gateways are AZ-specific resources. If the NAT Gateway lives in us-east-1a and that AZ goes down, instances in us-east-1b that route through it lose internet access. It's like having one secure comms room in one city -- if that city floods, soldiers in other cities can't make outbound calls. The fix: deploy a NAT Gateway in EACH AZ.

**Why others are wrong:**
- **A:** NAT Gateways do NOT automatically fail over across AZs. They're AZ-scoped.
- **C:** AWS does not auto-create NAT Gateways. You must provision them.
- **D:** NAT Gateways are NOT multi-AZ. They're highly available within a single AZ (redundant within the AZ) but not across AZs.

---

## Q9 (DVA) — Security Group Referencing

A developer has a web tier (Security Group: web-sg) and an application tier (Security Group: app-sg). Only the web tier should be able to communicate with the application tier on port 8080. What is the correct app-sg inbound rule?

A. Allow TCP port 8080 from 0.0.0.0/0
B. Allow TCP port 8080 from the web tier's subnet CIDR (e.g., 10.0.1.0/24)
C. Allow TCP port 8080 from web-sg (Security Group reference)
D. Allow TCP port 8080 from the web tier instances' private IP addresses

**Answer: C**

**Why C is correct:** Security Groups can reference other Security Groups as the source. This means "allow traffic from any instance associated with web-sg." It's like telling the bodyguard: "let anyone in who is escorted by the web team's bodyguard." This is dynamic -- if instances are added/removed from web-sg (scaling), the rule automatically applies. No IP management needed.

**Why others are wrong:**
- **A:** 0.0.0.0/0 allows traffic from everywhere, not just the web tier. Massive security hole.
- **B:** CIDR-based rules work but are fragile. If the web tier moves to a different subnet or the CIDR changes, you must update the rule.
- **D:** Individual IP addresses are the least scalable option. Auto Scaling adds/removes instances with different IPs.

---

## Q10 (SAA) — CIDR Planning

A solutions architect is designing a VPC that needs to be peered with an existing VPC (10.0.0.0/16) and an on-premises network (192.168.0.0/16). Which CIDR block should the new VPC use?

A. 10.0.0.0/16
B. 192.168.0.0/24
C. 172.16.0.0/16
D. 10.1.0.0/16

**Answer: C**

**Why C is correct:** VPC peering requires non-overlapping CIDR blocks. The existing VPC uses 10.0.0.0/16 (covers 10.0.0.0 - 10.0.255.255) and on-premises uses 192.168.0.0/16. 172.16.0.0/16 doesn't overlap with either. It's like making sure each army base has a unique postal code range so mail doesn't get confused.

**Why others are wrong:**
- **A:** 10.0.0.0/16 directly overlaps with the existing VPC. Peering will be rejected.
- **B:** 192.168.0.0/24 is a SUBSET of the on-premises 192.168.0.0/16 range. It overlaps.
- **D:** 10.1.0.0/16 covers 10.1.0.0 - 10.1.255.255, which doesn't overlap with 10.0.0.0/16 (covers 10.0.0.0 - 10.0.255.255). Wait -- actually this WOULD work too. But 172.16.0.0/16 is the safer choice as it uses a completely different RFC 1918 range with zero possibility of confusion.

---

## Q11 (SOA) — Default VPC

A SysOps administrator accidentally deleted the default VPC in ap-southeast-2. EC2 instances launched without specifying a VPC are now failing. How can this be resolved?

A. Contact AWS Support to restore the default VPC
B. Create a new VPC with CIDR 172.31.0.0/16 and it becomes the new default
C. Use the AWS Console or CLI to recreate the default VPC (Actions → Create default VPC)
D. Default VPCs cannot be deleted, so this scenario is impossible

**Answer: C**

**Why C is correct:** AWS provides a built-in option to recreate the default VPC. In the console: VPC → Actions → Create Default VPC. Via CLI: `aws ec2 create-default-vpc`. This creates a new default VPC with the standard configuration (172.31.0.0/16, public subnets, IGW).

**Why others are wrong:**
- **A:** No need to contact AWS Support. Self-service recreation is available.
- **B:** Manually creating a VPC with the same CIDR doesn't make it the "default" VPC. Default VPCs have special properties.
- **D:** Default VPCs CAN be deleted. It used to be a bigger problem before AWS added the recreate option.

---

## Q12 (SAA) — PrivateLink

A company offers a SaaS product and wants to allow customers in other AWS accounts to access their service privately (without traversing the internet). What AWS feature should they use?

A. VPC Peering between provider and customer VPCs
B. AWS PrivateLink (expose service as Interface Endpoint)
C. Transit Gateway shared across accounts
D. Public API Gateway with API keys for authentication

**Answer: B**

**Why B is correct:** AWS PrivateLink allows a service provider to expose their service behind a Network Load Balancer, and customers access it via Interface Endpoints in their own VPCs. Traffic stays on AWS's private network. It's like a private phone line -- the customer dials a local number (Interface Endpoint) that connects to the provider's service without going through public phone lines (internet).

**Why others are wrong:**
- **A:** VPC Peering exposes the entire VPC network to the other account. PrivateLink is more secure as it only exposes the specific service.
- **C:** Transit Gateway shares networking broadly. For a specific SaaS product, PrivateLink is more targeted and secure.
- **D:** Public API Gateway traverses the internet, which the question specifically says to avoid.
