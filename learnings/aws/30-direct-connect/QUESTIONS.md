# Direct Connect — Exam Practice Questions

---

## Q1: DX vs VPN

A company needs a private, consistent-latency connection to AWS for transferring 5 TB of data daily. They can wait 8 weeks for setup. Which connection type should they use?

**A)** Site-to-Site VPN
**B)** Direct Connect dedicated connection
**C)** Direct Connect hosted connection
**D)** AWS Transfer Family over the internet

### Answer: B

**Why:** 5 TB daily requires consistent, high-bandwidth throughput. Direct Connect dedicated provides predictable performance without internet variability. The 8-week setup time accommodates DX's physical provisioning. A VPN over the internet would have variable performance and potentially insufficient bandwidth for 5 TB/day.

- **A is wrong:** VPN traverses the public internet — variable latency, potential congestion, and shared bandwidth. Not suitable for consistent 5 TB/day transfers.
- **C is wrong:** Hosted connections go through a partner and are typically lower bandwidth (50 Mbps-10 Gbps). Dedicated gives you full control of the port for high-volume transfers.
- **D is wrong:** Transfer Family is for SFTP/FTPS file transfers, not for establishing a persistent high-bandwidth link. Still goes over the internet.

---

## Q2: Encryption Requirement

A financial company uses Direct Connect for their AWS workloads. A new compliance requirement mandates that ALL data in transit must be encrypted. What is the BEST solution?

**A)** Direct Connect is already encrypted — no changes needed
**B)** Establish a Site-to-Site VPN over the Direct Connect connection
**C)** Enable TLS on all applications
**D)** Replace Direct Connect with a VPN connection

### Answer: B

**Why:** Direct Connect is NOT encrypted by default — data travels in plaintext over the dedicated link. A VPN over DX gives you both: the consistency/bandwidth of DX AND the encryption of IPsec VPN. You keep the private highway but add an armored truck. This is the classic "encrypted private connection" pattern on the exam.

- **A is wrong:** This is the trap answer. DX provides a PRIVATE connection, not an ENCRYPTED one. Private != encrypted.
- **C is wrong:** TLS encrypts application traffic but doesn't encrypt ALL data in transit (DNS queries, non-HTTPS traffic, internal protocols). VPN encrypts everything at the network layer.
- **D is wrong:** Replacing DX with VPN loses the consistent latency and bandwidth benefits. VPN over DX gives you both.

---

## Q3: Multi-Region Access

A company has a single Direct Connect connection in Sydney (ap-southeast-2). They need to access VPCs in us-east-1 and eu-west-1 as well. What should they configure?

**A)** Create additional DX connections in us-east-1 and eu-west-1
**B)** Create a Direct Connect Gateway and associate it with VPCs in all three regions
**C)** Use VPC peering between the regions
**D)** Create Public VIFs to access resources in other regions

### Answer: B

**Why:** A Direct Connect Gateway enables one DX connection to reach VPCs in ANY region. You create Private VIFs to the DX Gateway, then associate the DX Gateway with Virtual Private Gateways (or Transit Gateway) in each region. One highway, multiple destinations — the DX Gateway is the highway junction.

- **A is wrong:** Creating DX connections in each region means 3 physical connections (3x cost, 3x setup time). DX Gateway avoids this.
- **C is wrong:** VPC peering connects VPCs to each other but doesn't help on-premises traffic reach those VPCs via Direct Connect. You still need DX Gateway for the DX-to-multi-region path.
- **D is wrong:** Public VIFs access AWS public services (S3, DynamoDB), not VPC resources (EC2, RDS). For VPC access, you need Private VIFs via DX Gateway.

---

## Q4: Resilient Architecture

A hospital's critical systems require connectivity to AWS with NO single point of failure. Which Direct Connect architecture provides maximum resilience?

**A)** Two dedicated connections at the same DX location
**B)** One dedicated connection with a Site-to-Site VPN backup
**C)** Two dedicated connections at two different DX locations
**D)** A LAG (Link Aggregation Group) with 4 connections

### Answer: C

**Why:** Maximum resilience requires eliminating ALL single points of failure. Two connections at different DX locations means: if one DX location goes down (fire, power outage, fiber cut), the other location provides connectivity. This is AWS's recommended "maximum resilience" pattern for critical workloads.

- **A is wrong:** Two connections at the SAME location fail together if the location has an outage. One point of failure remains: the DX location itself.
- **B is wrong:** VPN backup provides failover but with degraded performance (internet-dependent). For critical hospital systems, full DX resilience is preferred.
- **D is wrong:** LAG bundles connections at the SAME location for bandwidth, not resilience. All 4 connections fail together if the location goes down.

---

## Q5: Immediate Connectivity Need

A company signs a contract with AWS and needs private connectivity within 48 hours while their Direct Connect provisioning (expected 6 weeks) is in progress. What should they do?

**A)** Request expedited DX provisioning
**B)** Set up a Site-to-Site VPN immediately, then transition to DX when ready
**C)** Use AWS Transit Gateway with internet routing
**D)** Use AWS PrivateLink over the internet

### Answer: B

**Why:** VPN can be set up in minutes to hours (software-only, no physical provisioning). Use VPN immediately for connectivity, then migrate to DX when the physical connection is ready. The VPN can remain as a backup after DX is live. This is a common real-world and exam pattern: "need connectivity now but DX takes weeks."

- **A is wrong:** DX requires physical cross-connects — you can't expedite fiber installation and router configuration to 48 hours. The physical constraint is real.
- **C is wrong:** Transit Gateway routes traffic between VPCs and on-premises, but it still needs a connection method (DX or VPN). It doesn't provide connectivity by itself.
- **D is wrong:** PrivateLink provides private access to AWS services, but it's for VPC-to-service connectivity, not for on-premises-to-AWS connectivity.

---

## Q6: VIF Types

A company uses Direct Connect and needs to: (1) access their private EC2 instances in a VPC, and (2) upload large files to S3 without going over the internet. Which VIF configuration is correct?

**A)** Two Private VIFs — one for VPC, one for S3
**B)** One Private VIF for VPC access, one Public VIF for S3 access
**C)** One Transit VIF for both VPC and S3 access
**D)** One Private VIF for everything

### Answer: B

**Why:** Private VIF connects to VPC resources (EC2, RDS) via private IP addresses. S3 is a PUBLIC AWS service — even though you're accessing it over DX (not internet), you need a **Public VIF** because S3 uses public IP endpoints. The traffic still stays on AWS's backbone, but the routing is via public IP space.

- **A is wrong:** Private VIF can't reach S3 (a public service). Two Private VIFs would both only reach VPC resources. Exception: S3 VPC endpoints (Gateway endpoints) can route S3 traffic through Private VIF, but the standard pattern tested on exams is Public VIF for S3.
- **C is wrong:** Transit VIF connects to a Transit Gateway for multi-VPC access. It doesn't directly provide access to public AWS services like S3.
- **D is wrong:** A single Private VIF only reaches VPC resources. S3 traffic needs a different path.

---

## Q7: DX + Transit Gateway

A company has 200 VPCs across 5 regions. They need to connect their on-premises data center to ALL 200 VPCs via Direct Connect. What is the MOST scalable approach?

**A)** Create 200 Private VIFs — one per VPC
**B)** Use a DX Gateway with 200 Virtual Private Gateways
**C)** Use a DX Gateway with Transit Gateway, and attach all VPCs to the Transit Gateway
**D)** Create 5 DX connections — one per region

### Answer: C

**Why:** Transit Gateway supports thousands of VPC attachments. One DX connection → DX Gateway → Transit VIF → Transit Gateway → 200+ VPCs. This is the most scalable pattern. A single Transit VIF replaces 200 individual Private VIFs. The DX Gateway enables cross-region reach.

- **A is wrong:** 200 Private VIFs is far beyond the limit per DX connection (max ~50 VIFs) and operationally unmaintainable.
- **B is wrong:** DX Gateway supports max 10 VGW associations. 200 VGWs far exceeds this limit.
- **D is wrong:** 5 DX connections (one per region) costs 5x more and still doesn't solve the per-VPC connectivity problem within each region.

---

## Q8: LAG Configuration

A network engineer wants to combine two 10 Gbps Direct Connect connections into a single 20 Gbps link. Which statements are true? (Select TWO)

For the exam, the single best answer:

**A)** Create a LAG with the two connections; they must be the same speed at the same DX location
**B)** Create a LAG with connections at different DX locations for resilience
**C)** Create a LAG with one 10 Gbps and one 1 Gbps connection
**D)** LAG requires at least 4 connections

### Answer: A

**Why:** LAG bundles multiple connections into a logical group for aggregated bandwidth. Requirements: all connections must be the SAME speed AND at the SAME DX location. LAG provides bandwidth aggregation, not resilience — for resilience, use different DX locations.

- **B is wrong:** LAG connections must be at the same DX location. Cross-location LAG is not supported. For resilience, use separate connections at different locations (not LAG).
- **C is wrong:** All connections in a LAG must be the same speed. You can't mix 10 Gbps and 1 Gbps.
- **D is wrong:** LAG requires a minimum of 2 connections (not 4). Maximum is 4 connections per LAG.

---

## Q9: MACsec Encryption

A company has a 10 Gbps dedicated Direct Connect connection. They want to encrypt traffic at the physical layer without the overhead of VPN tunneling. Which option is available?

**A)** Enable TLS on the Direct Connect connection
**B)** Enable MACsec (802.1AE) encryption on the connection
**C)** Use AWS CloudHSM to encrypt DX traffic
**D)** Enable KMS encryption on the DX connection

### Answer: B

**Why:** MACsec provides Layer 2 encryption directly on the Direct Connect link — no VPN tunnel overhead. It encrypts frames at wire speed with minimal latency impact. Available on 10 Gbps and 100 Gbps dedicated connections. Requires compatible hardware on the customer side and the DX location.

- **A is wrong:** TLS is Layer 4/7 encryption for application protocols. You can't enable TLS on a Direct Connect physical connection.
- **C is wrong:** CloudHSM manages encryption keys, not network traffic encryption. It doesn't encrypt DX connections.
- **D is wrong:** KMS encrypts data at rest (S3 objects, EBS volumes), not data in transit on a DX link.

---

## Q10: Cost Comparison

A startup needs private connectivity to AWS. Their bandwidth requirement is only 200 Mbps. They want the LOWEST cost option. Which approach is BEST?

**A)** 1 Gbps Dedicated Direct Connect connection
**B)** 200 Mbps Hosted Direct Connect connection through a partner
**C)** Site-to-Site VPN with a 200 Mbps internet connection
**D)** AWS PrivateLink

### Answer: C

**Why:** For 200 Mbps, a Site-to-Site VPN is the cheapest private connectivity option. DX has port fees ($0.30/hour for 1 Gbps dedicated, or partner fees for hosted), cross-connect fees, and data transfer charges. VPN only has hourly VPN connection charges (~$0.05/hour) and internet costs. For a startup with modest bandwidth, VPN provides encryption and private routing at a fraction of DX cost.

- **A is wrong:** 1 Gbps dedicated DX is overkill for 200 Mbps and costs significantly more (port hours, cross-connect, data transfer).
- **B is wrong:** Hosted DX at 200 Mbps is cheaper than dedicated but still more expensive than VPN due to partner fees and DX data transfer charges.
- **D is wrong:** PrivateLink provides private access to specific services, not general connectivity between on-premises and AWS.
