# ARN — Exam Practice Questions

---

## Q1: S3 Bucket vs Object ARN

A developer writes an IAM policy to allow a Lambda function to read objects from an S3 bucket called `data-lake`. The policy uses the Resource:

```json
"Resource": "arn:aws:s3:::data-lake"
```

The Lambda function gets `AccessDenied` errors when trying to `GetObject`. What should the developer change?

**A)** Add the region and account ID to the ARN: `arn:aws:s3:us-east-1:123456789012:data-lake`
**B)** Change the Resource to `arn:aws:s3:::data-lake/*`
**C)** Change the action to `s3:*` instead of `s3:GetObject`
**D)** Add `"Effect": "Allow"` to the policy statement

### Answer: B

**Why:** `arn:aws:s3:::data-lake` refers to the **bucket itself** (the building). `arn:aws:s3:::data-lake/*` refers to the **objects inside** (the people in the building). `GetObject` operates on objects, not buckets. You need both ARNs if you want bucket-level actions (like `ListBucket`) AND object-level actions (like `GetObject`).

- **A is wrong:** S3 ARNs never include region or account ID — bucket names are globally unique.
- **C is wrong:** The action is correct; the resource is wrong. Broadening to `s3:*` wouldn't fix a resource-level mismatch.
- **D is wrong:** The policy likely already has Allow. The problem is the resource scope, not the effect.

---

## Q2: IAM ARN Format

A SysOps admin is writing a resource-based policy to allow an IAM user from another account to access an SQS queue. Which ARN format is correct for referencing the IAM user?

**A)** `arn:aws:iam:us-east-1:111122223333:user/deploy-user`
**B)** `arn:aws:iam::111122223333:user/deploy-user`
**C)** `arn:aws:iam:::user/deploy-user`
**D)** `arn:aws:iam::111122223333:deploy-user`

### Answer: B

**Why:** IAM is a **global service** — there's no region in the ARN (the region field is empty, shown as `::`). The account ID IS required (unlike S3) because user names are only unique within an account, not globally. The format must include the resource type (`user/`).

- **A is wrong:** IAM ARNs don't have a region. Including `us-east-1` makes it invalid.
- **C is wrong:** IAM ARNs require the account ID. Only S3 skips both region AND account.
- **D is wrong:** Missing the resource type `user/`. The ARN must specify whether it's a user, role, group, or policy.

---

## Q3: Wildcards in Policies

A solutions architect needs to grant a role access to invoke ANY Lambda function in the `ap-southeast-2` region of account `123456789012`. Which Resource ARN is correct?

**A)** `arn:aws:lambda:ap-southeast-2:123456789012:function/*`
**B)** `arn:aws:lambda:*:123456789012:function:*`
**C)** `arn:aws:lambda:ap-southeast-2:123456789012:*`
**D)** `arn:aws:lambda:ap-southeast-2:*:function:*`

### Answer: C

**Why:** `arn:aws:lambda:ap-southeast-2:123456789012:*` matches ALL Lambda resources in that region and account, which includes all functions. However, the more precise answer depends on the exact format. Lambda uses colon separator: `function:name`. Option A uses slash which is incorrect for Lambda. Option C with `*` at the resource position matches all resource types and IDs in that region/account.

Actually, let me reconsider. Lambda ARNs use colon: `arn:aws:lambda:region:account:function:function-name`. Option A uses slash which doesn't match Lambda's format. Option C is the broadest wildcard for the region/account.

- **A is wrong:** Lambda ARNs use colon separator (`function:name`), not slash (`function/name`). This would never match.
- **B is wrong:** The `*` in the region field means ALL regions, not just `ap-southeast-2`.
- **D is wrong:** The `*` in the account field means ALL accounts, violating least privilege and the requirement for a specific account.

### Corrected Answer: C

---

## Q4: Cross-Account Resource Reference

A company has two AWS accounts: Dev (111111111111) and Prod (222222222222). A Lambda function in Dev needs to write to a DynamoDB table `Orders` in Prod. Which ARN should be used in the IAM policy attached to the Lambda's execution role?

**A)** `arn:aws:dynamodb:ap-southeast-2:111111111111:table/Orders`
**B)** `arn:aws:dynamodb:ap-southeast-2:222222222222:table/Orders`
**C)** `arn:aws:dynamodb:::table/Orders`
**D)** `arn:aws:dynamodb:*:*:table/Orders`

### Answer: B

**Why:** You must reference the resource in the account where it lives — the Prod account (`222222222222`). The ARN always identifies the resource's home, not the requester's home. Think of it as: you need the passport number of the person you want to visit, not your own.

- **A is wrong:** This points to the Dev account's Orders table, which is not the target.
- **C is wrong:** DynamoDB ARNs require both region and account ID (it's not like S3 with global names).
- **D is wrong:** Wildcards in region and account would match ANY table called "Orders" in ANY account — massive security risk and not what's needed.

---

## Q5: ARN Case Sensitivity

A developer creates an S3 bucket called `MyDataBucket` and writes an IAM policy with:

```json
"Resource": "arn:aws:s3:::mydatabucket/*"
```

Users report they cannot access objects in the bucket. What's the issue?

**A)** The policy is missing the region in the S3 ARN
**B)** ARNs are case-sensitive and the bucket name case doesn't match
**C)** S3 bucket names must be lowercase so `MyDataBucket` is invalid
**D)** The `/*` wildcard is not valid for S3 ARNs

### Answer: C

**Why:** S3 bucket names must be **all lowercase**. A bucket named `MyDataBucket` cannot exist — S3 would reject the creation. If the bucket actually exists, it must be `mydatabucket`. However, this is a trick question: the real issue is that S3 bucket naming rules enforce lowercase, so if the bucket exists as `mydatabucket` the policy is actually correct.

**Wait — let me re-evaluate.** S3 bucket naming rules since March 2018 require all lowercase. If the bucket was created before that, uppercase was allowed. ARNs ARE case-sensitive. So the answer depends on when the bucket was created.

**For the exam:** ARNs are case-sensitive (B is the key concept being tested). If the bucket name is literally `MyDataBucket` (legacy), then `mydatabucket` in the ARN won't match.

### Corrected Answer: B

**Why (corrected):** ARNs are case-sensitive. `arn:aws:s3:::MyDataBucket` and `arn:aws:s3:::mydatabucket` are different ARNs. The policy must exactly match the bucket name as it was created.

- **A is wrong:** S3 ARNs don't include region.
- **C is partially right** (modern buckets must be lowercase) but the exam concept being tested is ARN case sensitivity.
- **D is wrong:** `/*` is valid and standard for matching all objects in a bucket.

---

## Q6: Lambda Function ARN with Alias

A developer configures API Gateway to invoke a Lambda function using the ARN `arn:aws:lambda:us-east-1:123456789012:function:processOrder`. After deploying a new version and creating an alias called `prod`, how should the developer update the ARN to point to the alias?

**A)** `arn:aws:lambda:us-east-1:123456789012:function:processOrder/prod`
**B)** `arn:aws:lambda:us-east-1:123456789012:function:processOrder:prod`
**C)** `arn:aws:lambda:us-east-1:123456789012:alias:processOrder:prod`
**D)** `arn:aws:lambda:us-east-1:123456789012:function:prod`

### Answer: B

**Why:** Lambda function ARNs use a **qualifier** appended with a colon after the function name. The qualifier can be a version number (`:3`) or an alias name (`:prod`). The full format is `function:function-name:qualifier`. Think of it as: the function is the citizen, and the alias is their current job title appended to their passport number.

- **A is wrong:** Lambda uses colons, not slashes, for qualifiers.
- **C is wrong:** The resource type is still `function`, not `alias`. The alias is the qualifier.
- **D is wrong:** `prod` would be treated as the function name, not an alias of `processOrder`.

---

## Q7: Partition in ARN

A government agency runs workloads in AWS GovCloud. A developer is writing a CloudFormation template that needs to construct ARNs dynamically. Which pseudo parameter should they use to handle the partition correctly?

**A)** `AWS::Region`
**B)** `AWS::Partition`
**C)** `AWS::AccountId`
**D)** `AWS::URLSuffix`

### Answer: B

**Why:** `AWS::Partition` returns `aws` for standard regions, `aws-cn` for China, and `aws-us-gov` for GovCloud. Using this pseudo parameter instead of hardcoding `aws` makes templates portable across partitions. Example: `!Sub "arn:${AWS::Partition}:s3:::${BucketName}"`

- **A is wrong:** Region is just one field — doesn't solve the partition portability issue.
- **C is wrong:** Account ID is important but separate from the partition field.
- **D is wrong:** `AWS::URLSuffix` returns the domain suffix (e.g., `amazonaws.com`), not the ARN partition.

---

## Q8: Multiple Resources in Policy

A SysOps admin needs to allow an EC2 instance role to: (1) list all objects in the `reports` S3 bucket, and (2) get/put objects in the `reports` bucket. Which Resource block is correct?

**A)**
```json
"Resource": "arn:aws:s3:::reports/*"
```

**B)**
```json
"Resource": "arn:aws:s3:::reports"
```

**C)**
```json
"Resource": [
  "arn:aws:s3:::reports",
  "arn:aws:s3:::reports/*"
]
```

**D)**
```json
"Resource": "arn:aws:s3:::reports*"
```

### Answer: C

**Why:** `ListBucket` (s3:ListBucket) operates on the **bucket** (`arn:aws:s3:::reports`), while `GetObject`/`PutObject` operate on **objects** (`arn:aws:s3:::reports/*`). You need BOTH ARNs in the Resource array. This is the most commonly tested S3 ARN concept on all three exams.

- **A is wrong:** Only covers objects, not the bucket itself. `ListBucket` would fail.
- **B is wrong:** Only covers the bucket. `GetObject` and `PutObject` would fail.
- **D is wrong:** `reports*` would match any bucket starting with "reports" (like `reports-archive`), and it conflates bucket and object-level permissions. Dangerous and incorrect.

---

## Q9: ARN in Condition Keys

A security team wants to ensure that an S3 bucket only accepts objects uploaded by a specific Lambda function. Which IAM condition key uses an ARN?

**A)** `aws:SourceIp`
**B)** `aws:SourceArn`
**C)** `aws:PrincipalOrgID`
**D)** `s3:prefix`

### Answer: B

**Why:** `aws:SourceArn` is a condition key that matches the ARN of the resource making the request. In a bucket policy, you can restrict `PutObject` to only succeed when the `aws:SourceArn` matches the Lambda function's ARN. Think of it as: "only accept packages from this specific delivery person (identified by their passport number)."

- **A is wrong:** `SourceIp` filters by IP address, not resource identity. Lambda functions don't have predictable IPs.
- **C is wrong:** `PrincipalOrgID` checks the AWS Organization, not a specific resource.
- **D is wrong:** `s3:prefix` is for filtering by key prefix, not for identifying the caller.

---

## Q10: Troubleshooting Invalid ARN

A SysOps admin is debugging why a CloudWatch alarm can't trigger an SNS topic. The alarm's action ARN is:

```
arn:aws:sns:us-east-1:123456789012/alerts-topic
```

What's wrong?

**A)** SNS topic ARNs don't include the region
**B)** The separator between account ID and topic name should be a colon (`:`), not a slash (`/`)
**C)** SNS topic ARNs require a resource type prefix like `topic/`
**D)** The account ID is missing

### Answer: B

**Why:** SNS topic ARNs use a colon separator: `arn:aws:sns:us-east-1:123456789012:alerts-topic`. The slash after the account ID makes it an invalid ARN. Different services use different separators — SNS uses colons while IAM uses slashes. One misplaced character breaks the entire reference.

- **A is wrong:** SNS is a regional service — the region IS required in the ARN.
- **C is wrong:** SNS topic ARNs don't use a resource type prefix. The topic name comes directly after the account ID with a colon.
- **D is wrong:** The account ID `123456789012` is present — the issue is the separator character.
