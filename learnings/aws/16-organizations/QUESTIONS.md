# 16 — Organizations: Exam-Style Questions

---

## Q1: SCP vs IAM Interaction

An IAM user in a member account has an IAM policy granting `s3:*` on all resources. However, the account's OU has an SCP that only allows EC2 and RDS services. Can the user access S3?

- **A)** Yes — IAM policies override SCPs
- **B)** No — the SCP restricts the maximum permissions, and S3 is not allowed
- **C)** Yes — but only if the user is the root user of the account
- **D)** It depends on whether the SCP uses an allow-list or deny-list strategy

**Correct Answer: B**

**Why:** BOTH the SCP AND the IAM policy must allow an action for it to work. The SCP sets the ceiling — it defines the maximum possible permissions for the entire account. Even with an IAM admin policy (`*:*`), if the SCP doesn't allow S3, nobody in that account can use S3. It's like a country signing a treaty banning nuclear weapons — even if the country's own laws allow it, the treaty overrides.

- **A is wrong:** IAM policies never override SCPs. SCPs are the outer boundary. IAM works WITHIN the SCP boundary.
- **C is wrong:** SCPs DO affect the root user of member accounts. Only the management account's root user is immune to SCPs.
- **D is wrong:** Whether the SCP uses allow-list or deny-list doesn't matter for the outcome. If the effective result is that S3 is not permitted, the user can't access S3 regardless of strategy.

---

## Q2: Management Account SCP Immunity

A security team attaches an SCP to the root of the organization that denies all actions on CloudTrail (`cloudtrail:*`). An admin in the management account tries to stop CloudTrail logging. What happens?

- **A)** The action is denied — SCPs apply to all accounts including the management account
- **B)** The action succeeds — the management account is not affected by SCPs
- **C)** The action is denied only if the admin is not the root user
- **D)** The action succeeds only if the management account has an explicit IAM allow policy

**Correct Answer: B**

**Why:** The management account is UN Headquarters — it's above the treaties it creates. SCPs NEVER affect the management account, period. This is by design: if SCPs could lock out the management account, you could accidentally lock yourself out of the entire organization with no way to fix it.

- **A is wrong:** This is the most common misconception. SCPs affect all MEMBER accounts but NOT the management account.
- **C is wrong:** Even regular IAM users in the management account are unaffected by SCPs. It's the account that's immune, not just the root user.
- **D is wrong:** The management account doesn't need explicit allows — SCPs simply don't apply to it. Standard IAM rules (policies attached to users/roles) still apply within the management account, but SCPs don't add any restrictions.

---

## Q3: Consolidated Billing and Reserved Instances

A company has 5 AWS accounts in an Organization. Account A purchased 10 Reserved Instances for m5.large in us-east-1. Account B is running 5 m5.large instances in us-east-1 but has no reservations. What happens to Account B's billing?

- **A)** Account B pays full On-Demand price — Reserved Instances don't share across accounts
- **B)** Account B's instances are covered by Account A's unused Reserved Instances at the reserved price
- **C)** Account B gets a 50% discount as a partial benefit of being in the organization
- **D)** Account B must explicitly request RI sharing from Account A

**Correct Answer: B**

**Why:** Reserved Instance sharing is enabled by default in consolidated billing. If Account A has 10 RIs but only uses 5, the remaining 5 RIs automatically apply to matching instances in other accounts. Account B's 5 m5.large instances get the reserved price. It's like one country buying bulk train tickets for the entire alliance — any country can use the unused tickets.

- **A is wrong:** RI sharing IS the default in Organizations. You'd have to explicitly DISABLE it for RIs not to share.
- **C is wrong:** There's no "partial discount." Either the RI applies (full reserved price) or it doesn't (full On-Demand price). It's binary.
- **D is wrong:** RI sharing is automatic — no request needed. The management account can disable sharing for specific accounts, but the default is shared.

---

## Q4: SCP Inheritance

An organization has the following structure:
- Root: SCP allows all services (FullAWSAccess)
- OU: Production: SCP denies S3 deletion
- Account 111 (in Production OU): SCP denies Lambda creation

A user in Account 111 with full IAM admin permissions tries to delete an S3 object. What happens?

- **A)** The action succeeds — the account-level SCP doesn't mention S3 deletion
- **B)** The action is denied — the OU-level SCP denying S3 deletion is inherited by Account 111
- **C)** The action succeeds — account-level SCPs override OU-level SCPs
- **D)** The action is denied — but only because the IAM policy doesn't explicitly allow it

**Correct Answer: B**

**Why:** SCPs inherit downward. Account 111 is subject to ALL SCPs in its chain: Root → Production OU → Account 111. The effective permissions are the INTERSECTION of all levels. Even though Account 111's own SCP only denies Lambda creation, the Production OU's SCP denying S3 deletion also applies. It's like a country being bound by both its regional alliance treaties AND its own national restrictions.

- **A is wrong:** SCPs are cumulative down the hierarchy. The account doesn't escape OU-level restrictions.
- **C is wrong:** Account-level SCPs don't override OU-level SCPs — they ADD to them. The effective SCP is the intersection of all SCPs from root to account.
- **D is wrong:** The user has full IAM admin permissions. The denial comes from the SCP, not IAM.

---

## Q5: Cross-Account Access

A developer in Account A needs to read DynamoDB tables in Account B. Which setup enables this?

- **A)** Share Account B's IAM user credentials with the developer
- **B)** Create a role in Account B with DynamoDB read permissions and a trust policy allowing Account A, then the developer assumes that role
- **C)** Add Account A's IP address to Account B's VPC security group
- **D)** Use AWS RAM to share the DynamoDB table with Account A

**Correct Answer: B**

**Why:** STS AssumeRole is the diplomatic passport system. Account B creates a role (the embassy) with the needed permissions and a trust policy that says "Account A is welcome." The developer in Account A assumes the role, gets temporary credentials, and uses them to access Account B's DynamoDB. Secure, auditable, no permanent credentials shared.

- **A is wrong:** NEVER share IAM credentials across accounts. This is a security anti-pattern — no auditability, no expiration, no principle of least privilege.
- **C is wrong:** Security Groups control network access, not AWS API access. DynamoDB is accessed via API, not network connections to a VPC.
- **D is wrong:** AWS RAM supports sharing specific resources (subnets, Transit Gateways), but DynamoDB tables are NOT shareable via RAM. Cross-account DynamoDB access requires IAM roles.

---

## Q6: Control Tower

A company is setting up a new multi-account environment from scratch. They want automated account provisioning, centralized logging, security guardrails, and SSO. What should they use?

- **A)** AWS Organizations with manually configured SCPs, CloudTrail, and IAM Identity Center
- **B)** AWS Control Tower, which automates the setup of Organizations, SCPs, CloudTrail, Config, and IAM Identity Center
- **C)** A CloudFormation StackSet that deploys security resources to each account
- **D)** AWS Config with organization-wide rules

**Correct Answer: B**

**Why:** Control Tower is the automated UN setup wizard. It creates a landing zone with best-practice OU structure, a Log Archive account (centralized logs), an Audit account (security), guardrails (SCPs + Config Rules), and Account Factory (self-service account creation). It orchestrates Organizations, SCPs, Config, CloudTrail, and IAM Identity Center into one automated solution. Don't build what's already built.

- **A is wrong:** This works but is manual and error-prone. You'd spend weeks configuring what Control Tower does in hours. It's like building UN headquarters brick by brick when there's a prefab kit available.
- **C is wrong:** StackSets deploy infrastructure but don't provide the governance layer (guardrails, account factory, centralized logging). It's one tool, not the full solution.
- **D is wrong:** AWS Config is one component of the solution, not the full multi-account setup. Control Tower uses Config internally as part of its detective guardrails.

---

## Q7: SCPs and Root User

A security team wants to prevent anyone in member accounts from creating IAM access keys for the root user. They create an SCP denying `iam:CreateAccessKey` when the principal is root. Does this work?

- **A)** No — SCPs cannot restrict the root user in any account
- **B)** Yes — SCPs restrict the root user in member accounts (but not the management account)
- **C)** No — the root user's permissions come from AWS, not IAM policies or SCPs
- **D)** Yes — SCPs restrict the root user in ALL accounts including the management account

**Correct Answer: B**

**Why:** SCPs DO affect the root user of MEMBER accounts. This is a key differentiator from the management account. The root user of a member account is like the president of a member country — they're powerful domestically, but still bound by UN treaties (SCPs). The management account's root user, however, is like the UN Secretary-General — immune to the treaties.

- **A is wrong:** SCPs CAN restrict the root user — but only in member accounts. This is a critical exam fact.
- **C is wrong:** While the root user has special status, SCPs explicitly apply to them in member accounts. This was an intentional design decision by AWS.
- **D is wrong:** The management account is always exempt from SCPs. The SCP would restrict root users in member accounts only.

---

## Q8: OU Design

A company has the following requirements:
- Production workloads need strict security controls
- Developers need sandbox accounts for experimentation with spending limits
- Some accounts are being decommissioned
- Shared services (DNS, Active Directory) need to be accessible by all accounts

Which OU structure is BEST?

- **A)** One OU for all accounts with different SCPs attached to each account individually
- **B)** Root → Security OU, Infrastructure OU, Workloads OU (Production + Development), Sandbox OU, Suspended OU
- **C)** Root → Production OU, Non-Production OU
- **D)** No OUs — attach SCPs directly to each account

**Correct Answer: B**

**Why:** This follows the AWS recommended OU structure:
- **Security OU** — security tools accounts (GuardDuty, Security Hub delegated admin)
- **Infrastructure OU** — shared services (networking, DNS, Active Directory)
- **Workloads OU** with nested Production and Development OUs — different SCP strictness
- **Sandbox OU** — experimentation with spending guardrails
- **Suspended OU** — accounts being decommissioned (strict SCP denying almost everything)

It's like organizing the UN into specialized committees, each with appropriate rules.

- **A is wrong:** Per-account SCPs don't scale. With 50+ accounts, managing individual SCPs is a nightmare. OUs provide grouping.
- **C is wrong:** Too simple — doesn't account for shared services, security, or suspended accounts. Where do decommissioned accounts go?
- **D is wrong:** Same problem as A. SCPs are meant to be applied at the OU level for manageable governance.

---

## Q9: AWS RAM Sharing

A company wants Account B to launch EC2 instances in a VPC subnet owned by Account A, without creating VPC peering. What should they use?

- **A)** VPC Peering between Account A and Account B
- **B)** AWS RAM to share the subnet from Account A to Account B
- **C)** Transit Gateway connecting both accounts' VPCs
- **D)** Copy the subnet configuration and create an identical subnet in Account B

**Correct Answer: B**

**Why:** AWS RAM can share VPC subnets across accounts. Account B's EC2 instances launch directly into Account A's subnet — same VPC, same CIDR, same security groups. No peering, no Transit Gateway, no data transfer costs between accounts. It's like sharing an office floor — different companies, same building, same address.

- **A is wrong:** VPC peering connects two separate VPCs. The question says "without creating VPC peering." Also, peering means separate subnets in separate VPCs — not launching into the same subnet.
- **C is wrong:** Transit Gateway connects VPCs at the network layer but still keeps resources in separate VPCs. RAM sharing lets resources live in the SAME subnet.
- **D is wrong:** Copying subnet configuration creates a completely separate subnet with a potentially conflicting CIDR. Resources wouldn't be in the same network.

---

## Q10: SCP Strategy

A company wants to ensure NO account in the organization can launch EC2 instances outside of ap-southeast-2 and us-east-1. However, they also need IAM and STS to work globally (these are global services hosted in us-east-1). What SCP should they use?

- **A)** An allow-list SCP that only allows actions in ap-southeast-2 and us-east-1
- **B)** A deny SCP that denies all actions where `aws:RequestedRegion` is not ap-southeast-2 or us-east-1, with an exception for global services
- **C)** A deny SCP on all regions except ap-southeast-2, applied to the root
- **D)** Separate SCPs: one allowing ap-southeast-2, another allowing us-east-1

**Correct Answer: B**

**Why:** The deny-list strategy with global service exceptions is the correct approach. You deny everything outside your approved regions, but exclude global services (IAM, STS, CloudFront, Route 53, Organizations, etc.) from the deny. Without the exception, users couldn't manage IAM or assume roles because those API calls go through us-east-1 regardless of the user's region.

```json
{
  "Effect": "Deny",
  "Action": "*",
  "Resource": "*",
  "Condition": {
    "StringNotEquals": {
      "aws:RequestedRegion": ["ap-southeast-2", "us-east-1"]
    },
    "ArnNotLike": {
      "aws:PrincipalARN": ["arn:aws:iam::*:role/AdminBypass"]
    }
  }
}
```
Plus a separate statement allowing global services regardless of region.

- **A is wrong:** An allow-list approach would require removing the default FullAWSAccess SCP and building allows from scratch. This is complex and risky — miss one service and it breaks.
- **C is wrong:** Denying all regions except one doesn't account for the two-region requirement or global services. IAM, STS, and other global services would break.
- **D is wrong:** Multiple allow SCPs don't stack the way you'd expect. And this approach doesn't address the global services issue.

---

## Q11: Account Closure

A member account in the organization is no longer needed. The admin moves it to the Suspended OU and initiates closure. What happens?

- **A)** The account is immediately deleted and all resources are destroyed
- **B)** The account enters a 90-day suspension period, then is permanently closed. Resources remain accessible during suspension
- **C)** The account enters a 90-day suspension period during which it cannot be accessed, then is permanently closed
- **D)** The account must be removed from the organization before it can be closed

**Correct Answer: C**

**Why:** When you close an AWS account, it enters a 90-day suspension. During this period, you CAN reactivate it (if you change your mind), but you CANNOT access its resources or sign in. After 90 days, the account is permanently closed and all resources are deleted. Moving it to a Suspended OU (with a restrictive SCP) is a best practice to prevent any accidental usage during the transition.

- **A is wrong:** AWS doesn't immediately delete accounts. The 90-day grace period exists to prevent irreversible mistakes.
- **B is wrong:** Resources are NOT accessible during suspension. The account is frozen — you can only reactivate it.
- **D is wrong:** Member accounts can be closed while still in the organization. You don't need to remove them first.

---

## Q12: Tag Policies

A company wants to enforce that all EC2 instances across the organization have a `CostCenter` tag with a value from an approved list (CC-100, CC-200, CC-300). They enable tag policies. What happens when a developer launches an EC2 instance with `CostCenter: CC-999` (not on the approved list)?

- **A)** The instance launch is blocked by the tag policy
- **B)** The instance launches successfully but is flagged as non-compliant in the tag policy report
- **C)** The instance launches with the tag automatically changed to the closest matching approved value
- **D)** The tag policy only applies to the management account, not member accounts

**Correct Answer: B**

**Why:** Tag policies are DETECTIVE, not PREVENTIVE. They define the correct tag values but don't block non-compliant resources from being created. They report violations so you can identify and fix them. It's like a naming convention for roads — the convention says "use street, avenue, or boulevard" but the government doesn't physically stop you from naming a road "banana lane." They just flag it for correction.

- **A is wrong:** Tag policies don't block resource creation. Only SCPs can prevent actions. To enforce tag compliance preventively, you'd need an SCP that denies resource creation without valid tags (separate from tag policies).
- **C is wrong:** Tag policies don't modify tags automatically. They only report on compliance.
- **D is wrong:** Tag policies apply to member accounts, not just the management account. That's their whole purpose — organization-wide tag governance.
