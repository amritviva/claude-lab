# ARN — National Identity Passport

> **Every citizen (resource) in the AWS Country gets a unique national identity number. No two are alike. You need it for everything official.**

---

## ELI10

Imagine every person in a country has a unique passport number. It tells you which country they belong to, which state they live in, which department issued it, and their personal ID. When the government writes laws (IAM policies), they use these passport numbers to say exactly who the law applies to. Sometimes they use wildcards — like saying "everyone in New South Wales" instead of naming each person. That's what an ARN is: a universal address for anything in AWS.

---

## The Concept

### ARN = Amazon Resource Name

Every single resource in AWS — an S3 bucket, a Lambda function, an IAM user, a DynamoDB table — gets a globally unique ARN. It's the canonical way to identify resources across all of AWS.

### Format (The Passport Template)

```
arn:partition:service:region:account-id:resource-type/resource-id
```

| Field | Analogy | Example |
|-------|---------|---------|
| `arn` | "This is a passport" | Always `arn` |
| `partition` | Which country system | `aws` (standard), `aws-cn` (China), `aws-us-gov` (GovCloud) |
| `service` | Which government department | `s3`, `lambda`, `iam`, `ec2`, `dynamodb` |
| `region` | Which state/territory | `ap-southeast-2`, `us-east-1` |
| `account-id` | Which household (AWS account) | `123456789012` |
| `resource-type/resource-id` | The actual citizen | `function/my-function`, `table/Users` |

### Resource Separators

Different services use different separators between resource-type and resource-id:

```
arn:aws:iam::123456789012:user/johndoe          ← slash separator
arn:aws:sns:us-east-1:123456789012:my-topic     ← colon separator (no resource-type)
arn:aws:s3:::my-bucket                          ← no region, no account
arn:aws:s3:::my-bucket/photos/*                 ← path within bucket
```

### Special Cases — Services That Break the Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│  S3 ARNs — No Region, No Account ID                            │
│  arn:aws:s3:::my-bucket                                         │
│  arn:aws:s3:::my-bucket/*                                       │
│  Why? S3 bucket names are GLOBALLY unique. No need for region   │
│  or account — the name alone identifies it worldwide.           │
├─────────────────────────────────────────────────────────────────┤
│  IAM ARNs — No Region                                           │
│  arn:aws:iam::123456789012:user/admin                           │
│  Why? IAM is a GLOBAL service. Users aren't tied to a region.   │
├─────────────────────────────────────────────────────────────────┤
│  EC2 ARNs — Full Format                                         │
│  arn:aws:ec2:ap-southeast-2:123456789012:instance/i-0abc123     │
│  EC2 instances live in a specific region + account.             │
└─────────────────────────────────────────────────────────────────┘
```

### Wildcards — Laws That Apply to Groups

```
arn:aws:s3:::*                    → ALL S3 buckets (every citizen in the S3 department)
arn:aws:s3:::my-bucket/*          → ALL objects in my-bucket (everyone in that household)
arn:aws:dynamodb:*:*:table/*      → ALL DynamoDB tables in ALL regions and accounts
arn:aws:lambda:ap-southeast-2:123456789012:function:*  → ALL Lambda functions in Sydney
```

| Wildcard | Meaning | Analogy |
|----------|---------|---------|
| `*` | Match anything (zero or more chars) | "Everyone in this department" |
| `?` | Match exactly one character | "Any single person" |

### ARN Parsing — Anatomy of Real ARNs

```
arn:aws:lambda:ap-southeast-2:634851795467:function:processPayment
 │    │    │          │            │           │          │
 │    │    │          │            │           │          └── Resource ID
 │    │    │          │            │           └── Resource Type
 │    │    │          │            └── Account ID
 │    │    │          └── Region (Sydney)
 │    │    └── Service (Lambda)
 │    └── Partition (standard AWS)
 └── Prefix (always "arn")
```

### Where ARNs Are Used

```
┌──────────────────────────────────────────────────────┐
│                  ARN Usage Points                      │
├──────────────────────┬───────────────────────────────┤
│ IAM Policies         │ "Resource": "arn:aws:s3:::*"  │
│ Resource Policies    │ S3 bucket policy, SQS policy  │
│ API Calls            │ aws lambda invoke --func arn  │
│ CloudFormation       │ !Ref / !GetAtt → returns ARN  │
│ CloudWatch Alarms    │ Target resource by ARN        │
│ Event Rules          │ EventBridge target ARN        │
│ Cross-Account Access │ Specify resource in other acct│
└──────────────────────┴───────────────────────────────┘
```

---

## Architecture Diagram

```
               arn:aws:service:region:account:resource
                │     │    │      │      │       │
                │     │    │      │      │       │
                v     v    v      v      v       v
             ┌─────┬─────┬──────┬──────┬───────┬──────────┐
             │ arn │ aws │ s3   │      │       │ my-bucket│  ← S3 (no region/account)
             ├─────┼─────┼──────┼──────┼───────┼──────────┤
             │ arn │ aws │ iam  │      │ 1234..│ user/bob │  ← IAM (no region)
             ├─────┼─────┼──────┼──────┼───────┼──────────┤
             │ arn │ aws │ ec2  │ ap-2 │ 1234..│ i-0abc   │  ← EC2 (full)
             ├─────┼─────┼──────┼──────┼───────┼──────────┤
             │ arn │ aws │lambda│ us-1 │ 1234..│ func/pay │  ← Lambda (full)
             └─────┴─────┴──────┴──────┴───────┴──────────┘
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- Constructing ARNs in IAM policies (especially S3 bucket vs object-level permissions)
- Cross-account access using ARNs in resource policies
- Wildcard usage in policies — least privilege principle
- Know which services have global ARNs (IAM, S3) vs regional ARNs (EC2, Lambda, DynamoDB)

### DVA-C02 (Developer)
- ARN format for Lambda functions (including version/alias: `arn:...:function:name:qualifier`)
- Using ARNs in SDK calls and CloudFormation templates
- API Gateway ARNs for method-level permissions
- Constructing ARNs programmatically

### SOA-C02 (SysOps)
- Troubleshooting "resource not found" errors (wrong ARN format)
- ARNs in CloudWatch alarms and EventBridge rules
- Cross-account ARN references in Organizations
- Config rules referencing resources by ARN

---

## Key Numbers

| Fact | Value |
|------|-------|
| ARN max length | 2048 characters |
| Partition options | `aws`, `aws-cn`, `aws-us-gov` |
| S3 ARN includes region? | No |
| S3 ARN includes account? | No |
| IAM ARN includes region? | No |
| ARNs case-sensitive? | **Yes** |
| Wildcard `*` | Zero or more characters |
| Wildcard `?` | Exactly one character |

---

## Cheat Sheet

- **ARN = globally unique resource identifier** across all of AWS
- **Format:** `arn:partition:service:region:account-id:resource`
- **S3 ARNs skip region and account** — bucket names are globally unique
- **IAM ARNs skip region** — IAM is a global service
- **ARNs are CASE-SENSITIVE** — `arn:aws:s3:::MyBucket` != `arn:aws:s3:::mybucket`
- **Bucket vs Objects:** `arn:aws:s3:::bucket` (the bucket) vs `arn:aws:s3:::bucket/*` (objects inside)
- **Two separators:** slash (`/`) and colon (`:`) between resource-type and resource-id
- **Lambda ARN with version:** `arn:aws:lambda:region:acct:function:name:version`
- **Wildcards in policies:** `*` matches everything, use for broad permissions
- **Cross-account:** always specify full ARN including account-id
- **CloudFormation `!Ref`** on many resources returns the ARN
- **`!GetAtt Resource.Arn`** explicitly returns the ARN in CloudFormation
- **Condition keys can match on ARN:** `aws:SourceArn`, `aws:PrincipalArn`
