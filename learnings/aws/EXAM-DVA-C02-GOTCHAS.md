# DVA-C02 Developer Associate -- Gotchas & Ace Sheet

> **The Country Analogy:** You're a **software engineer** building apps that run inside
> AWS-land. You don't design the cities (that's the architect). You write the code,
> deploy the apps, debug the issues, and wire up the services. Every question asks:
> "How do you build, deploy, and troubleshoot this app correctly?"

---

## Exam Profile

| Detail | Value |
|--------|-------|
| Code | DVA-C02 |
| Questions | 65 (50 scored + 15 unscored) |
| Time | 130 minutes (~2 min/question) |
| Passing | 720 / 1000 |
| Format | Multiple choice + multiple response |
| Cost | $150 USD |

---

## Domain Breakdown

| # | Domain | Weight | What It ACTUALLY Tests |
|---|--------|--------|----------------------|
| 1 | Development with AWS Services | 32% | Lambda, DynamoDB, API Gateway, S3, SQS/SNS, Step Functions, containers. "Can you build apps using AWS building blocks?" |
| 2 | Security | 26% | IAM roles, Cognito, KMS encryption, Secrets Manager, API auth (IAM/Cognito/Lambda authorisers). "Can you lock down your app?" |
| 3 | Deployment | 24% | CI/CD (CodePipeline, CodeBuild, CodeDeploy), SAM, CloudFormation, deployment strategies (canary, linear, blue/green). "Can you ship code safely?" |
| 4 | Troubleshooting & Optimization | 18% | X-Ray, CloudWatch Logs/Metrics, Lambda debugging, observability. "When it breaks, can you find and fix it?" |

---

## Top 30 DVA Gotchas

### Gotcha 1: Lambda Memory-CPU Link

Lambda doesn't let you set CPU directly. CPU scales linearly with memory:
- **1,769 MB = 1 full vCPU**
- 128 MB = tiny fraction of CPU
- 10,240 MB (10 GB) = 6 vCPUs

If a Lambda is slow and CPU-bound, **increase memory** (even if you don't need more RAM).

### Gotcha 2: Lambda /tmp Storage

- **Default**: 512 MB
- **Maximum**: 10,240 MB (10 GB)
- Persists between warm invocations of the same execution environment
- NOT shared across concurrent invocations

If question mentions "temporary file storage in Lambda" or "download large file in Lambda," /tmp is the answer.

### Gotcha 3: Lambda 15-Minute Timeout

Lambda max execution = **15 minutes (900 seconds)**. Default is 3 seconds. If the workload takes longer:
- Use Step Functions to orchestrate multiple Lambdas
- Use Fargate for long-running tasks
- Use SQS + Lambda with shorter per-message processing

### Gotcha 4: DynamoDB RCU Math

```
1 RCU = 1 strongly consistent read of up to 4 KB/sec
      = 2 eventually consistent reads of up to 4 KB/sec
      = 0.5 transactional reads of up to 4 KB/sec

Formula:
  Item size → round UP to nearest 4 KB
  RCU = (rounded size / 4 KB) x reads/sec
  Eventually consistent? Divide by 2.
  Transactional? Multiply by 2.
```

**Example:** 10 strongly consistent reads/sec of 6 KB items:
- Round 6 KB up to 8 KB (nearest 4 KB multiple)
- 8 / 4 = 2 RCU per read
- 2 x 10 = **20 RCU**

Same but eventually consistent: 20 / 2 = **10 RCU**

### Gotcha 5: DynamoDB WCU Math

```
1 WCU = 1 write of up to 1 KB/sec
      = 0.5 transactional writes of up to 1 KB/sec

Formula:
  Item size → round UP to nearest 1 KB
  WCU = rounded size x writes/sec
  Transactional? Multiply by 2.
```

**Example:** 5 writes/sec of 2.5 KB items:
- Round 2.5 KB up to 3 KB
- 3 x 5 = **15 WCU**

Transactional: 15 x 2 = **30 WCU**

### Gotcha 6: API Gateway 29-Second Timeout

API Gateway has a **hard limit of 29 seconds** for integration timeout. You cannot change this. If your backend takes longer:
- Return immediately + process asynchronously (SQS, Step Functions)
- Use WebSocket API for long-running operations
- Lambda behind API GW is double-constrained: 29s API GW limit AND Lambda's own timeout

### Gotcha 7: API Gateway Throttle Limits

- **Account-level**: 10,000 requests/second across all APIs
- **Burst**: 5,000 requests
- **Per-stage/method**: configurable throttle settings
- Returns **429 Too Many Requests** when throttled

### Gotcha 8: SQS Visibility Timeout vs Message Retention

- **Visibility Timeout**: how long a message is hidden from other consumers after being read (default 30s, max 12 hours). Like checking out a library book -- others can't see it while you have it.
- **Message Retention**: how long unprocessed messages stay in queue (default 4 days, max 14 days). Like how long the library holds a reserved book.

If messages are being processed twice, **increase visibility timeout**. If messages are disappearing before processing, **increase retention period**.

### Gotcha 9: SQS Standard vs FIFO

| Feature | Standard | FIFO |
|---------|----------|------|
| Ordering | Best-effort | Strict FIFO |
| Delivery | At-least-once (possible duplicates) | Exactly-once |
| Throughput | Unlimited | 300 msg/s (or 3,000 with batching) |
| Name | Any | Must end in `.fifo` |

"Exactly-once processing" or "message ordering" = FIFO. "High throughput, duplicates OK" = Standard.

### Gotcha 10: X-Ray -- Daemon vs SDK

- **X-Ray SDK**: you add it to your code to **instrument** (create traces, segments, subsegments, annotations, metadata)
- **X-Ray Daemon**: runs alongside your app to **collect and send** trace data to X-Ray service

You need BOTH. SDK creates the data, Daemon ships it. On Lambda, the daemon runs automatically.

**Annotations** = indexed, searchable (for filtering traces). **Metadata** = not indexed (for storing extra data).

### Gotcha 11: CodeDeploy AppSpec Hooks Order

For **EC2/On-Premises**:
```
BeforeInstall → Install → AfterInstall → ApplicationStart → ValidateService
```

For **Lambda**:
```
BeforeAllowTraffic → AfterAllowTraffic
```

For **ECS**:
```
BeforeInstall → Install → AfterInstall → BeforeAllowTraffic → AfterAllowTraffic
```

Exam loves asking which hook runs validation scripts. Answer: `ValidateService` (EC2) or `AfterAllowTraffic` (Lambda/ECS).

### Gotcha 12: Lambda Versions and Aliases

- **Version**: immutable snapshot of function code + config. Once published, never changes. Like a Git tag.
- **Alias**: mutable pointer to a version. Like a Git branch name.
  - `PROD` alias points to version 5
  - `DEV` alias points to version 8
  - Can do **weighted aliases**: 90% to v5, 10% to v6 (canary deployment)

`$LATEST` is the only mutable version. Published versions are immutable.

### Gotcha 13: Lambda Layers -- Max 5

- A function can use **maximum 5 layers**
- Total unzipped deployment package (code + all layers) max **250 MB**
- Layers are extracted to `/opt` in the execution environment
- Use for: shared libraries, custom runtimes, common dependencies

### Gotcha 14: DynamoDB Streams vs Kinesis Data Streams for DynamoDB

| Feature | DynamoDB Streams | Kinesis Data Streams |
|---------|-----------------|---------------------|
| Retention | 24 hours | Up to 365 days |
| Consumers | 2 simultaneous | Unlimited (with enhanced fan-out) |
| Shards | Managed automatically | You manage shard count |
| Cross-region | No (use Global Tables) | No |

"Need to replay events beyond 24 hours" = Kinesis. "Simple change capture for Lambda trigger" = DynamoDB Streams.

### Gotcha 15: Cognito User Pool vs Identity Pool

This is tested CONSTANTLY:
- **User Pool** = **authentication** (who are you?). Sign-up, sign-in, MFA, tokens (JWT). The country's **passport office**.
- **Identity Pool** = **authorization** (what can you do?). Exchanges tokens for temporary AWS credentials (STS). The country's **work visa office**.

Typical flow: User Pool authenticates -> Identity Pool gives AWS creds -> User accesses S3/DynamoDB directly.

### Gotcha 16: Step Functions Standard vs Express

| Feature | Standard | Express |
|---------|----------|---------|
| Max duration | 1 year | 5 minutes |
| Execution model | Exactly-once | At-least-once (async) or at-most-once (sync) |
| Price | Per state transition | Per execution + duration + memory |
| Use case | Long workflows, human approval | High-volume, short processing |
| Max executions | 2,000/sec | 100,000/sec |

"Long-running workflow with human approval" = Standard. "High-volume, short-duration" = Express.

### Gotcha 17: SAM Template = CloudFormation Extension

```yaml
Transform: AWS::Serverless-2016-10-31  # This line makes it SAM
```

SAM resources:
- `AWS::Serverless::Function` → Lambda + IAM Role + Event Source
- `AWS::Serverless::Api` → API Gateway
- `AWS::Serverless::SimpleTable` → DynamoDB table

`sam build` → `sam deploy` (which calls CloudFormation under the hood). SAM is syntactic sugar, not a separate service.

### Gotcha 18: Environment Variables vs Secrets Manager vs Parameter Store

| Use | Service |
|-----|---------|
| Non-sensitive config | Lambda Environment Variables |
| Sensitive values, auto-rotation | Secrets Manager ($0.40/secret/month) |
| Config values, hierarchy | SSM Parameter Store (free for Standard) |
| DB passwords specifically | Secrets Manager (has RDS rotation built-in) |

"Automatic rotation of database password" = Secrets Manager. "Store config cheaply" = Parameter Store.

### Gotcha 19: KMS Envelope Encryption Flow

```
1. App calls GenerateDataKey → KMS returns:
   ├── Plaintext Data Encryption Key (DEK)
   └── Encrypted DEK (encrypted with CMK)
2. App encrypts data with plaintext DEK
3. App stores encrypted data + encrypted DEK together
4. App DELETES plaintext DEK from memory

To decrypt:
1. App sends encrypted DEK to KMS → Decrypt → plaintext DEK
2. App decrypts data with plaintext DEK
3. App deletes plaintext DEK from memory
```

Why not encrypt directly with KMS? KMS has a **4 KB limit** for direct encryption. Envelope encryption handles any size.

### Gotcha 20: CloudFormation Intrinsic Functions

- **!Ref**: returns the "default" value (resource ID, parameter value)
- **!GetAtt**: returns a specific attribute (`!GetAtt MyBucket.Arn`)
- **!Sub**: string substitution (`!Sub "arn:aws:s3:::${BucketName}"`)
- **!Join**: concatenate with delimiter
- **!Select**: pick from a list by index
- **!Split**: split string into list
- **!ImportValue**: reference a cross-stack export

"Get the ARN of a resource" = `!GetAtt`. "Reference a parameter" = `!Ref`. "Build a string with variables" = `!Sub`.

### Gotcha 21: Lambda Concurrency

- **Unreserved**: shared pool across all functions (default 1,000 per region)
- **Reserved Concurrency**: guarantees X concurrent executions for this function (and caps it)
- **Provisioned Concurrency**: pre-warms X execution environments (eliminates cold starts)

"Eliminate cold starts" = Provisioned Concurrency. "Guarantee capacity" = Reserved Concurrency. "Limit a function to prevent it from consuming all capacity" = also Reserved Concurrency.

### Gotcha 22: API Gateway Authorisers

- **IAM Authoriser**: AWS Sig V4 headers. For AWS-to-AWS or backend service calls.
- **Cognito Authoriser**: validates JWT from Cognito User Pool. Simplest for user auth.
- **Lambda Authoriser** (Custom): your own auth logic. Returns IAM policy. Use when auth is not Cognito (e.g., custom OAuth, SAML, API keys + custom logic).
  - **Token-based**: receives bearer token
  - **Request-based**: receives request parameters (headers, query strings, stage variables)

### Gotcha 23: S3 Pre-Signed URLs

- Generated by **anyone with valid credentials** to the object
- Default expiry: 3,600 seconds (1 hour) for AWS CLI
- Max expiry: 7 days (when using IAM user credentials)
- **Inherits the permissions of the credential that signed it**
- If the signing credential expires or is revoked, the pre-signed URL stops working

"Temporary access to a private S3 object" = pre-signed URL.

### Gotcha 24: STS AssumeRole

- Returns **temporary credentials** (access key, secret key, session token)
- Max duration: 1 hour (default) to 12 hours (configurable on the role)
- Cross-account access: Role in Account B trusts Account A -> User in A calls AssumeRole -> gets creds for B
- **ExternalId**: prevents "confused deputy" problem in cross-account scenarios

### Gotcha 25: DynamoDB Partition Key Design

- **Hot partition** = one partition key getting all the traffic. Kills performance.
- Good keys: `userId`, `deviceId` -- high cardinality, even distribution
- Bad keys: `date`, `status` -- low cardinality, creates hot partitions
- **Write sharding**: append random suffix to partition key to distribute writes

### Gotcha 26: CloudFormation Stack Updates

- **Update with No Interruption**: resource updated in-place (e.g., changing a tag)
- **Update with Some Interruption**: resource might restart (e.g., changing instance type)
- **Replacement**: old resource deleted, new one created (e.g., changing a DynamoDB partition key)

Always check the CloudFormation docs for "Update requires" before changing a property.

### Gotcha 27: Lambda Dead Letter Queues (DLQ) vs Destinations

- **DLQ**: catches failed async invocations only. SQS or SNS target. Legacy.
- **Destinations**: catches both success AND failure for async invocations. More targets (SQS, SNS, Lambda, EventBridge). Preferred.

"Route failed Lambda invocations" = Destinations (preferred) or DLQ. "Route both success and failure" = Destinations only.

### Gotcha 28: ECS Task Roles vs Execution Roles

- **Task Role**: what the **container application** can do (e.g., access DynamoDB, S3). Like the worker's ID badge.
- **Execution Role**: what **ECS agent** can do (e.g., pull image from ECR, write logs to CloudWatch). Like the HR department's access to set up the worker.

"Container needs to access DynamoDB" = Task Role. "ECS can't pull image from ECR" = Execution Role problem.

### Gotcha 29: CodeBuild buildspec.yml Phases

```yaml
version: 0.2
phases:
  install:      # Install dependencies
  pre_build:    # Login to ECR, run tests
  build:        # Compile code, build Docker image
  post_build:   # Push image, create artifacts
artifacts:      # What to output
cache:          # What to cache between builds
```

If the question asks "where to run unit tests," it's `pre_build`. "Where to build the Docker image," it's `build`.

### Gotcha 30: AppSync vs API Gateway

- **API Gateway**: REST or WebSocket APIs. You manage resolvers/integrations.
- **AppSync**: GraphQL API. Built-in DynamoDB/Lambda/RDS resolvers. Real-time subscriptions. Offline sync with Amplify.

"GraphQL" in the question = AppSync. "REST API" = API Gateway. "Real-time data sync for mobile" = AppSync.

---

## SDK & CLI Patterns Tested

### Exponential Backoff

When you get throttled (429) or server errors (5xx):
```
Retry 1: wait 1 sec
Retry 2: wait 2 sec
Retry 3: wait 4 sec
Retry 4: wait 8 sec
(+ random jitter to prevent thundering herd)
```
AWS SDKs implement this automatically. If the question says "reduce throttling," the answer is exponential backoff with jitter.

### Pagination

Most AWS API calls return paginated results. The SDK provides:
- `NextToken` / `ExclusiveStartKey` -- manual pagination
- Built-in paginators in SDK v3 (e.g., `paginateListObjects`)

"My Lambda only returns partial DynamoDB results" = you're not paginating.

### Credential Provider Chain (SDK v3)

The SDK checks credentials in this order:
1. Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
2. Shared credentials file (`~/.aws/credentials`)
3. ECS container credentials (Task Role)
4. EC2 instance metadata (Instance Profile / IAM Role)

"Lambda can't access DynamoDB" = check the Lambda execution role. "EC2 can't access S3" = check the instance profile/IAM role.

### S3 Pre-Signed URLs (SDK)

```javascript
// Generate upload URL
const command = new PutObjectCommand({ Bucket: 'my-bucket', Key: 'file.pdf' });
const url = await getSignedUrl(s3Client, command, { expiresIn: 3600 });
```

### STS AssumeRole (SDK)

```javascript
const { Credentials } = await sts.assumeRole({
  RoleArn: 'arn:aws:iam::123456789012:role/CrossAccountRole',
  RoleSessionName: 'my-session'
});
// Use returned credentials for cross-account access
```

---

## CI/CD Deployment Decision Tree

### When to Use What

```
Need to deploy code changes?
├── Just infrastructure (no app code)?
│   └── CloudFormation / CDK / SAM
├── Application code to EC2?
│   ├── In-place (rolling update)?
│   │   └── CodeDeploy (in-place)
│   └── Blue/Green (zero downtime)?
│       └── CodeDeploy (blue/green)
├── Lambda function update?
│   ├── All-at-once (instant switch)?
│   │   └── CodeDeploy (AllAtOnce)
│   ├── Gradual (test with % of traffic)?
│   │   ├── 10% then 90% → CodeDeploy (Canary10Percent5Minutes)
│   │   └── Linear increase → CodeDeploy (Linear10PercentEvery1Minute)
│   └── SAM + AutoPublishAlias (simplest)
├── ECS container update?
│   └── CodeDeploy (blue/green with ALB target group switching)
└── Full pipeline (source → build → test → deploy)?
    └── CodePipeline (orchestrates CodeCommit/GitHub + CodeBuild + CodeDeploy)
```

### Deployment Types by Compute

| Compute | In-Place | Blue/Green | Canary | Linear |
|---------|----------|------------|--------|--------|
| EC2 | Yes | Yes | No | No |
| Lambda | N/A | N/A | Yes | Yes |
| ECS | No | Yes | Yes | Yes |

### CodePipeline Stages

```
Source (CodeCommit, GitHub, S3)
  → Build (CodeBuild)
    → Test (CodeBuild, 3rd party)
      → Deploy (CodeDeploy, CloudFormation, ECS, S3)
```

Each stage can have **manual approval actions** (e.g., before production deploy).

---

## DynamoDB Math Cheat Sheet

### RCU Formula

```
Item Size (round up to nearest 4 KB) = S
Reads per second = R

Strongly Consistent:    RCU = (S / 4) x R
Eventually Consistent:  RCU = (S / 4) x R / 2
Transactional:          RCU = (S / 4) x R x 2
```

### WCU Formula

```
Item Size (round up to nearest 1 KB) = S
Writes per second = W

Standard:       WCU = S x W
Transactional:  WCU = S x W x 2
```

### Practice Problems

**Q1:** 20 strongly consistent reads/sec, item size 3 KB
- Round 3 KB to 4 KB
- (4/4) x 20 = **20 RCU**

**Q2:** 20 eventually consistent reads/sec, item size 3 KB
- Round 3 KB to 4 KB
- (4/4) x 20 / 2 = **10 RCU**

**Q3:** 10 strongly consistent reads/sec, item size 9 KB
- Round 9 KB to 12 KB
- (12/4) x 10 = **30 RCU**

**Q4:** 5 writes/sec, item size 1.5 KB
- Round 1.5 KB to 2 KB
- 2 x 5 = **10 WCU**

**Q5:** 10 transactional writes/sec, item size 2 KB
- 2 x 10 x 2 = **40 WCU**

**Q6:** 8 transactional reads/sec, item size 5 KB
- Round 5 KB to 8 KB
- (8/4) x 8 x 2 = **32 RCU**

### GSI and LSI

- **LSI** (Local Secondary Index): same partition key, different sort key. Must be created at table creation. Max 5 per table. Shares RCU/WCU with base table.
- **GSI** (Global Secondary Index): different partition key and sort key. Can be created anytime. Max 20 per table. Has its OWN RCU/WCU (separate provisioning).

If GSI is throttled, the base table writes are also throttled (back-pressure). Size your GSI capacity appropriately.

---

## Exam Day Quick Reminders

1. **DynamoDB questions**: always check if they say "strongly" or "eventually" consistent -- it halves the RCU
2. **Lambda questions**: check if it's a concurrency, memory, timeout, or permissions issue
3. **"Least privilege"**: always the answer when they ask about security best practice
4. **API Gateway 29s**: if Lambda takes 30s behind API GW, it will time out at the gateway
5. **Cognito**: User Pool = auth, Identity Pool = AWS creds. This distinction is tested 3-5 times
6. **Encryption**: at rest = KMS, in transit = TLS/SSL, client-side = you encrypt before sending
7. **Flag and move**: 2 minutes per question max, review flagged ones at the end
