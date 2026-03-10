# 01 - IAM: Exam Questions

---

## Q1 (SAA) — Policy Evaluation Logic

An IAM user belongs to two groups. Group "Developers" has a policy allowing `s3:*` on all resources. Group "Restricted" has a policy explicitly denying `s3:DeleteObject` on all resources. The user tries to delete an S3 object. What happens?

A. The delete succeeds because the Developers policy allows s3:*
B. The delete fails because the explicit deny in Restricted overrides the allow
C. The delete succeeds because the most recently attached policy takes precedence
D. The delete fails because users in multiple groups cannot have conflicting policies

**Answer: B**

**Why B is correct:** The golden rule: explicit DENY always wins, no matter what. It's like having a law (Allow) that says "developers can access all warehouses" AND a law (Deny) that says "nobody can destroy warehouse items." The Deny law overrides. AWS evaluates all policies together -- one explicit deny anywhere blocks the action.

**Why others are wrong:**
- **A:** Allow s3:* is powerful but explicit deny trumps it. Always.
- **C:** There is no concept of policy recency/order. All policies are evaluated simultaneously.
- **D:** Users CAN be in groups with conflicting policies. The conflict is resolved by the deny-wins rule.

---

## Q2 (DVA) — EC2 Instance Credentials

A developer is writing code on an EC2 instance that needs to read from a DynamoDB table. What is the recommended approach for providing AWS credentials to the application?

A. Embed access keys in the application code
B. Store access keys in environment variables on the instance
C. Attach an IAM role to the EC2 instance with DynamoDB read permissions
D. Create a shared credentials file at ~/.aws/credentials

**Answer: C**

**Why C is correct:** IAM roles (VIP badges) are the recommended way to give EC2 instances access to AWS services. The instance assumes the role and gets temporary credentials automatically via the instance metadata service. No static keys to manage, rotate, or leak.

**Why others are wrong:**
- **A:** NEVER embed access keys in code. They end up in version control, logs, or get stolen. This is a critical security anti-pattern.
- **B:** Environment variables are better than hardcoding but still static credentials that must be rotated manually and could be exposed.
- **D:** Credentials files are for local development, not EC2 instances. They're static and harder to manage than roles.

---

## Q3 (SAA) — Cross-Account Access

Company A (Account 111111111111) needs to grant Company B (Account 222222222222) read access to an S3 bucket. What is the recommended approach?

A. Create an IAM user in Account A and share the access keys with Company B
B. Create an IAM role in Account A with a trust policy allowing Account B, and a permission policy for S3 read
C. Make the S3 bucket public so Company B can access it
D. Copy the data to an S3 bucket in Account B

**Answer: B**

**Why B is correct:** Cross-account access via IAM roles is the recommended pattern. Account A creates a role (VIP badge) that Account B's users can assume. The trust policy says "Account B is allowed to pick up this badge." The permission policy says "this badge grants S3 read access." It's like a foreign diplomat receiving a temporary visitor badge -- their identity comes from their country, but the badge grants local access.

**Why others are wrong:**
- **A:** Sharing access keys between accounts is a security risk. Keys are permanent, hard to track, and could be leaked.
- **C:** Making a bucket public exposes it to the entire internet, not just Company B. Massive security violation.
- **D:** Data duplication increases cost, creates sync issues, and doesn't solve the access pattern -- it avoids it.

---

## Q4 (SOA) — Credential Report vs Access Advisor

A SysOps administrator needs to identify IAM users who haven't used their passwords in over 90 days, as part of a security audit. Which tool should they use?

A. IAM Access Advisor
B. IAM Credential Report
C. AWS CloudTrail
D. AWS Config

**Answer: B**

**Why B is correct:** The IAM Credential Report is an account-level CSV file that lists ALL users and the status of their credentials (password last used, access key last used, MFA status). It's like a census of all citizens showing when each last used their passport. Perfect for "find all users who haven't logged in recently."

**Why others are wrong:**
- **A:** Access Advisor shows which SERVICES a specific user has accessed, not credential usage across all users. It answers "what did this user access?" not "which users are inactive?"
- **C:** CloudTrail logs API calls and can show user activity, but querying 90 days of logs across all users is complex. The Credential Report gives this data in one CSV.
- **D:** AWS Config tracks resource configuration changes, not IAM credential usage.

---

## Q5 (DVA) — STS AssumeRoleWithWebIdentity

A mobile application authenticates users via Google Sign-In. After authentication, the app needs temporary AWS credentials to upload photos to S3. What is the correct flow?

A. Exchange the Google token for IAM access keys using AWS SSO
B. Use `sts:AssumeRoleWithWebIdentity` to exchange the Google OIDC token for temporary AWS credentials
C. Store AWS access keys in the mobile app and use Google auth only for the UI
D. Create an IAM user for each Google user

**Answer: B**

**Why B is correct:** `AssumeRoleWithWebIdentity` is the STS call that exchanges a web identity token (Google, Facebook, Amazon) for temporary AWS credentials. It's like a foreign citizen (Google user) showing their passport (OIDC token) at the visa office (STS) and receiving a temporary VIP badge (AWS credentials) to access specific resources. Note: In practice, AWS recommends using Cognito Identity Pools which handles this flow for you.

**Why others are wrong:**
- **A:** AWS SSO (Identity Center) is for workforce identity federation (SAML/corporate), not consumer mobile apps with social login.
- **C:** Never store AWS credentials in mobile apps. They can be decompiled and extracted.
- **D:** Creating IAM users for millions of mobile users is unscalable and not the intended pattern. IAM users are for internal staff, not end users.

---

## Q6 (SAA) — Permission Boundaries

An organisation allows team leads to create IAM users for their teams. However, they want to ensure that team leads cannot create users with more permissions than a defined maximum. What should they use?

A. Service Control Policies (SCPs)
B. IAM Permission Boundaries
C. IAM Groups with restricted policies
D. Resource-based policies on all resources

**Answer: B**

**Why B is correct:** Permission Boundaries define the maximum permissions an IAM entity can ever have, regardless of what identity-based policies are attached. It's like giving a team lead the ability to issue security clearances, but capping the maximum clearance level they can grant. The effective permissions = intersection of identity policy AND permission boundary.

**Why others are wrong:**
- **A:** SCPs apply at the Organization/OU/Account level, not at the individual user creation level. They cap what an entire account can do, not what a specific team lead can grant.
- **C:** Groups restrict members' permissions but don't prevent a team lead from creating users OUTSIDE the group with broader permissions.
- **D:** Resource-based policies control access to specific resources, not the maximum permissions a user can have.

---

## Q7 (SOA) — MFA Enforcement

A SysOps administrator needs to enforce MFA for all IAM users accessing the AWS Console. Users without MFA should be denied access to all services except IAM (to set up their own MFA). How should this be implemented?

A. Enable MFA in the password policy
B. Create an IAM policy that denies all actions except IAM when `aws:MultiFactorAuthPresent` is false, and attach it to all users
C. Configure the root account to require MFA for all users
D. Use AWS Organizations SCP to block non-MFA access

**Answer: B**

**Why B is correct:** An IAM policy with a condition on `aws:MultiFactorAuthPresent` is the correct approach. The policy allows IAM actions (so users can set up MFA) but denies everything else unless MFA is present. It's like a law that says "you can enter the government office to get your photo ID, but you need that photo ID to do anything else."

**Why others are wrong:**
- **A:** Password policy enforces password complexity and rotation, not MFA. There's no "require MFA" toggle in password policy.
- **C:** Root account MFA only protects the root login, not other IAM users.
- **D:** SCPs can enforce MFA at the account level, but the question specifically asks about allowing IAM access for MFA setup, which requires the nuanced condition in an IAM policy. SCPs don't have the same granularity for self-service MFA.

---

## Q8 (DVA) — Instance Profile

A developer creates an IAM role for an EC2 instance but can't attach it. The role exists and has the correct permissions. What is likely the issue?

A. The role doesn't have EC2 listed in its trust policy
B. The developer needs to create an instance profile and add the role to it
C. IAM roles cannot be attached to running EC2 instances
D. The role exceeds the maximum number of policies

**Answer: A**

**Why A is correct:** For an IAM role to be assumed by EC2, the role's trust policy must list `ec2.amazonaws.com` as a trusted principal. It's like a VIP badge that specifies who can pick it up -- if EC2 isn't on the list, EC2 can't assume the role. Note: when you create a role "for EC2" via the console, it auto-configures this. Via CLI/SDK, you must set it manually.

**Why others are wrong:**
- **B:** The console auto-creates instance profiles. If using CLI, this could be an issue, but the trust policy is the more common gotcha.
- **C:** IAM roles CAN be attached to running EC2 instances (this was added in 2017). You don't need to stop the instance.
- **D:** Policy limits would throw a different error, and 10 managed policies is a generous limit.

---

## Q9 (SAA) — Identity-Based vs Resource-Based Policies

An S3 bucket in Account A needs to be accessed by a Lambda function in Account B. Which policy combination is required?

A. Only a bucket policy on the S3 bucket in Account A allowing Account B
B. Only an IAM role in Account B with S3 permissions
C. Both a bucket policy in Account A AND an IAM role with S3 permissions in Account B
D. Either a bucket policy in Account A OR an IAM role in Account B (not both)

**Answer: D**

**Why D is correct:** Wait -- this is a tricky one! For cross-account access to S3, you can use EITHER:
1. Resource-based policy (bucket policy) that allows the Lambda role from Account B, OR
2. IAM role in Account B assumes a role in Account A that has S3 access

But actually for S3 specifically with resource-based policies, if the bucket policy allows the Lambda role ARN from Account B, and the Lambda role has the necessary S3 permissions, it works. The key nuance: **S3 bucket policies are resource-based policies, and for cross-account access, EITHER the resource-based policy OR identity+role assumption is sufficient.**

Actually, let me correct: For cross-account, the standard rule is BOTH sides must allow. But S3 resource-based policies are an exception -- if the bucket policy in Account A explicitly allows the principal from Account B, AND the Lambda role in Account B allows the S3 action, access is granted without assuming a role.

**Answer: C** (corrected)

**Why C is correct:** For cross-account access, BOTH sides must agree. The bucket policy in Account A must allow the Lambda function's role from Account B, AND the Lambda role in Account B must have permissions to perform the S3 action. It's like needing both an exit visa from your country AND an entry visa from the destination.

**Why others are wrong:**
- **A:** Bucket policy alone isn't enough. The Lambda's execution role also needs S3 permissions.
- **B:** The IAM role alone isn't enough. Account A's bucket must also explicitly allow cross-account access.
- **D:** For cross-account access, you need both sides to allow. Within the SAME account, either is sufficient.

---

## Q10 (SOA) — Access Key Rotation

A security audit reveals that several IAM users have access keys older than 90 days. The SysOps administrator needs to enforce key rotation. What is the recommended approach?

A. Set an access key rotation policy in IAM (like password rotation)
B. Use AWS Config with the `access-keys-rotated` managed rule to detect non-compliance, and create a Lambda function to disable old keys
C. Delete all access keys older than 90 days immediately
D. Migrate all users to IAM roles, which automatically rotate credentials

**Answer: B**

**Why B is correct:** IAM does not have built-in access key rotation enforcement (unlike password policies). You must use AWS Config to detect non-compliant keys and automate remediation. The Config rule `access-keys-rotated` checks key age, and a remediation Lambda can notify users or disable old keys. It's like having an automated compliance auditor that flags expired passports.

**Why others are wrong:**
- **A:** There is NO IAM policy for access key rotation. Password policies exist but don't cover access keys. This is a common misconception.
- **C:** Deleting keys immediately would break applications. The process should be: create new key → update applications → verify → deactivate old key → delete old key.
- **D:** While migrating to roles is a great long-term strategy, it's not "enforcing rotation" and may not be feasible for all use cases (e.g., third-party integrations).

---

## Q11 (SAA) — Federation with Corporate Identity

A company with 5,000 employees uses Active Directory for authentication. They want employees to access AWS Console using their existing corporate credentials. What is the recommended approach?

A. Create 5,000 IAM users and sync passwords from Active Directory
B. Use AWS IAM Identity Center (AWS SSO) with Active Directory integration
C. Use IAM roles with inline policies for each employee
D. Use Amazon Cognito User Pools

**Answer: B**

**Why B is correct:** IAM Identity Center (formerly AWS SSO) is AWS's recommended service for workforce identity federation. It integrates with Active Directory (via SAML 2.0) so employees use their corporate login to access AWS. It's like accepting foreign passports (corporate IDs) at the border -- no need to issue new passports (IAM users) to everyone.

**Why others are wrong:**
- **A:** Creating 5,000 IAM users duplicates identity management, creates sync nightmares, and is not scalable. IAM has a 5,000 user limit anyway.
- **C:** Roles are assumed temporarily, not used for direct console login by thousands of employees. Identity Center manages the role assumption flow.
- **D:** Cognito is for customer-facing applications (mobile/web apps), not workforce/employee access to the AWS Console.

---

## Q12 (DVA) — Policy Variables

A developer wants to create a single S3 policy that gives each IAM user access only to their own "folder" (prefix) in a shared bucket. The prefix should match their username. Which policy approach works?

A. Create individual policies for each user with hardcoded prefixes
B. Use the policy variable `${aws:username}` in the Resource ARN
C. Use S3 ACLs to grant per-user access
D. Create separate buckets for each user

**Answer: B**

**Why B is correct:** IAM policy variables like `${aws:username}` are dynamically replaced with the requesting user's name at evaluation time. A single policy can grant access to `arn:aws:s3:::shared-bucket/${aws:username}/*`. It's like a law that says "every citizen can access THEIR OWN locker" -- one law, personalised to each person.

```json
{
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": "arn:aws:s3:::shared-bucket/${aws:username}/*"
}
```

**Why others are wrong:**
- **A:** Works but doesn't scale. If you have 100 users, you need 100 policies. Policy variables solve this with one policy.
- **C:** S3 ACLs are legacy, limited, and don't support per-user prefix isolation elegantly.
- **D:** Separate buckets waste resources and are harder to manage. The 100-bucket default limit makes this impractical at scale.

---

## Q13 (SAA) — Service-Linked Roles

A solutions architect notices a role named `AWSServiceRoleForElasticLoadBalancing` in their account. They didn't create it. Can they modify or delete it?

A. Yes, any administrator can modify or delete service-linked roles
B. No, service-linked roles can only be modified or deleted by AWS
C. No, service-linked roles cannot be modified, and can only be deleted after removing the associated service resources
D. Yes, but only the root user can modify service-linked roles

**Answer: C**

**Why C is correct:** Service-linked roles are pre-defined by AWS services and created automatically when you use the service. You cannot modify their permissions (they're set by AWS). You can only delete them after removing all resources that depend on them (e.g., delete all load balancers first). It's like a government-mandated role -- you didn't create it, you can't change its responsibilities, and you can't fire the person until their department is shut down.

**Why others are wrong:**
- **A:** Service-linked roles cannot be modified. Their trust and permission policies are set by AWS.
- **B:** You CAN delete them yourself, but only after the service no longer needs them.
- **D:** Root user has no special ability to modify service-linked role permissions.
