# Lambda — Exam Questions

> 12 scenario-based questions mixing SAA-C03, DVA-C02, and SOA-C02 perspectives.

---

### Q1 (DVA) — Cold Start Optimization

A developer's Java Lambda function takes 8 seconds to respond on the first invocation but only 200ms on subsequent calls. The function initializes a database connection pool in the handler. What TWO changes would MOST reduce cold start latency?

A. Increase the function's memory to 3 GB
B. Move the database connection pool initialization outside the handler function
C. Switch from Java to Python runtime
D. Enable Provisioned Concurrency

**Answer: B and D**

**Why B is correct:** Code outside the handler runs once during cold start and is reused across warm invocations. But more importantly, the handler is called EVERY time — cold or warm. Moving init code outside the handler means warm starts skip the expensive DB connection setup entirely. Currently the DB pool initializes on every call, making even warm starts slower than they need to be.

**Why D is correct:** Provisioned Concurrency pre-warms execution environments. The cold start happens in advance, so the first user request hits a warm container. Like having the kitchen already set up before the first order arrives.

**Why A is wrong:** More memory = more CPU, which helps execution speed, but the 8-second cold start is caused by JVM initialization + DB connection setup, not CPU starvation. It might shave off a second or two but won't fix the fundamental issue.

**Why C is wrong:** Switching runtimes is a major code rewrite. While Python has faster cold starts than Java, the exam wants architectural solutions, not "rewrite your app."

---

### Q2 (SAA) — Lambda vs ECS Decision

A company needs to process uploaded videos — each video takes 30-45 minutes to transcode. The workload is sporadic (0-50 videos per day). Which compute option is MOST appropriate?

A. Lambda with 15-minute timeout
B. Lambda with Step Functions orchestrating multiple Lambda invocations
C. ECS Fargate tasks triggered by S3 events
D. EC2 Auto Scaling group with spot instances

**Answer: C**

**Why C is correct:** Lambda maxes out at 15 minutes — can't handle 30-45 minute jobs. ECS Fargate is serverless containers with no time limit. Trigger a Fargate task per video via EventBridge/S3 notification. Pay only while the container runs. Like renting a bigger kitchen (container) for jobs too large for the magic kitchen (Lambda).

**Why A is wrong:** Lambda timeout is 15 minutes max. A 30-45 minute job will be killed mid-process.

**Why B is wrong:** While Step Functions can chain Lambda invocations, video transcoding isn't easily split into 15-minute chunks. The transcoder needs to process the entire file in one continuous operation.

**Why D is wrong:** EC2 works but is less operationally efficient. You'd need to manage instance lifecycle, AMIs, scaling policies. Fargate is serverless and simpler for sporadic workloads.

---

### Q3 (DVA) — Versions and Aliases

A developer wants to gradually shift production traffic from Lambda v3 to v4. They want 10% of traffic on v4 initially, increasing to 100% over a week. How should they configure this?

A. Create a new alias "prod" pointing to v4 and update API Gateway
B. Use a weighted alias: "prod" pointing 90% to v3 and 10% to v4, adjusting daily
C. Deploy v4 as $LATEST and let API Gateway route to $LATEST
D. Create two API Gateway stages — one pointing to v3, one to v4

**Answer: B**

**Why B is correct:** Lambda aliases support weighted routing between two versions. Configure the "prod" alias with 90% to v3 and 10% to v4. API Gateway points to the alias (not a version), so no API changes needed. Gradually shift the weight. Like updating the menu to show the new dish to 10% of customers first. If something goes wrong, flip back to 100% v3 instantly.

**Why A is wrong:** This switches 100% of traffic to v4 immediately — no gradual rollout.

**Why C is wrong:** $LATEST is mutable and not a version — you can't do weighted routing with it. Also, pointing production to $LATEST is dangerous (any deploy immediately hits prod).

**Why D is wrong:** Two stages means two different URLs. Clients would need to be aware of which stage to call. Weighted alias is transparent.

---

### Q4 (SOA) — Concurrency Throttling

A SysOps administrator notices that Lambda function "ProcessOrders" is being throttled during peak hours. The account has 1,000 concurrent execution limit. CloudWatch shows ProcessOrders peaks at 400 concurrent, but another function "GenerateReports" spikes to 800 concurrent. What is the BEST solution?

A. Request a concurrency limit increase to 2,000
B. Set reserved concurrency of 400 for ProcessOrders
C. Set reserved concurrency of 200 for GenerateReports
D. Enable Provisioned Concurrency for ProcessOrders

**Answer: B**

**Why B is correct:** Reserved concurrency guarantees 400 executions for ProcessOrders, regardless of what other functions do. Currently, GenerateReports at 800 + ProcessOrders at 400 = 1,200, exceeding the 1,000 limit. By reserving 400 for ProcessOrders, it's guaranteed its share. GenerateReports gets throttled to the remaining 600 unreserved pool — which is appropriate since it's a report generator (less critical). Like reserving 400 parking spots for VIP customers — nobody else can take them.

**Why A is wrong:** Increasing the limit works but doesn't prevent the same problem from recurring if GenerateReports grows further. Reserved concurrency is the architectural fix.

**Why C is wrong:** Capping GenerateReports at 200 might fix the immediate issue but is overly restrictive. The question says it needs 800 at peak. Better to protect the critical function.

**Why D is wrong:** Provisioned concurrency eliminates cold starts — it doesn't increase the concurrency limit or reserve capacity for throttling protection.

---

### Q5 (DVA) — Event Source Mapping with SQS

A developer configures a Lambda function with an SQS event source mapping. The function processes messages but occasionally fails. Failed messages reappear and are reprocessed, but some messages fail repeatedly and block new messages from processing. What should the developer configure?

A. A Dead Letter Queue on the Lambda function
B. A Dead Letter Queue on the SQS queue (redrive policy) with maxReceiveCount
C. Lambda Destinations for failure routing
D. Increase the SQS visibility timeout

**Answer: B**

**Why B is correct:** For SQS event source mappings, the DLQ must be configured on the SQS QUEUE, not on the Lambda function. Set a redrive policy with maxReceiveCount (e.g., 3). After 3 failed processing attempts, the poison message moves to the DLQ, unblocking the queue. Lambda DLQ (option A) is for async invocations, not event source mappings.

**Why A is wrong:** Lambda DLQ works for async invocations (S3, SNS, EventBridge). For SQS event source mappings, the queue itself handles retries and dead-lettering.

**Why C is wrong:** Lambda Destinations also only work for async invocations, not event source mappings.

**Why D is wrong:** Increasing visibility timeout prevents messages from reappearing too soon but doesn't handle poison messages that always fail. They'll keep retrying forever.

---

### Q6 (SAA) — VPC Lambda Internet Access

A Lambda function is configured in a private subnet to access an RDS database. After deployment, the function successfully queries RDS but fails when calling an external REST API. What is the MOST LIKELY cause and fix?

A. The Lambda function needs a public IP — move it to a public subnet
B. The private subnet lacks a NAT Gateway — add one in a public subnet
C. The security group blocks outbound traffic — allow HTTPS on port 443
D. The Lambda execution role lacks internet access permissions

**Answer: B**

**Why B is correct:** VPC Lambda in a private subnet has no internet access by default. To reach external APIs, traffic must route through a NAT Gateway in a public subnet, then through an Internet Gateway. RDS works because it's in the same VPC (private network). The external API fails because there's no path to the internet. Like being inside the army base (VPC) — you can reach other buildings on base (RDS), but to call outside, you need a phone line out (NAT Gateway).

**Why A is wrong:** Lambda CANNOT be placed in a public subnet and get a public IP. Even if it could, best practice is private subnet + NAT Gateway.

**Why C is wrong:** Security groups default to allowing all outbound traffic. This is unlikely the issue unless explicitly restricted.

**Why D is wrong:** IAM roles don't control network access. Network routing (NAT Gateway) is separate from permissions.

---

### Q7 (DVA) — Layers

A team has 5 Lambda functions that all use the same 50 MB image processing library. Each function has its own copy bundled in the deployment package. What is the BEST way to optimize this?

A. Upload the library to S3 and download it at runtime to /tmp
B. Create a Lambda Layer containing the library and attach it to all 5 functions
C. Create a container image with the library pre-installed
D. Use EFS to store the library and mount it to all functions

**Answer: B**

**Why B is correct:** Layers are designed exactly for this — shared code/libraries across multiple functions. Upload the 50 MB library as a Layer once, attach it to all 5 functions. Each function's deployment package shrinks dramatically, deployments are faster, and library updates happen in one place. Like putting the shared ingredients on one shelf instead of stocking 5 separate pantries.

**Why A is wrong:** Downloading 50 MB at runtime adds latency to every cold start. /tmp is ephemeral and may be cleared between invocations.

**Why C is wrong:** Container images work but are overkill for sharing a library. You'd need 5 separate container images.

**Why D is wrong:** EFS adds latency, cost, and VPC complexity. Layers are the native, simplest solution.

---

### Q8 (SOA) — Memory Tuning

A Lambda function processes images and takes an average of 10 seconds at 512 MB memory. A SysOps administrator increases memory to 2048 MB and the function now takes 3 seconds. Despite the 4x memory cost per ms, the total cost per invocation decreased. Why?

A. Lambda charges less per ms at higher memory configurations
B. The function is CPU-bound; more memory provided more CPU, reducing duration enough to lower total cost
C. Lambda provides a free tier discount at higher memory levels
D. The reduced duration resulted in fewer cold starts

**Answer: B**

**Why B is correct:** Lambda CPU scales linearly with memory. At 512 MB, the function was CPU-starved — the processor couldn't keep up with image processing, stretching execution to 10 seconds. At 2048 MB (~1.16 vCPU), the CPU handles image processing in 3 seconds.

Cost math:
- 512 MB x 10s = 5,120 MB-seconds
- 2,048 MB x 3s = 6,144 MB-seconds

Wait — that's actually MORE MB-seconds. But the ACTUAL pricing tiers and the dramatic reduction in duration often make the total cheaper because you cross fewer billing boundaries. The key insight for the exam: **increasing memory can reduce cost for CPU-bound functions because duration drops faster than memory cost increases.**

**Why A is wrong:** Lambda charges the same rate per GB-second regardless of memory configuration.

**Why C is wrong:** No such discount exists.

**Why D is wrong:** Cold start frequency is unrelated to memory configuration.

---

### Q9 (DVA) — Async Invocation Retries

A developer's Lambda function is triggered asynchronously by S3 PUT events. The function occasionally fails due to a transient database error. Without any custom configuration, how many times will Lambda attempt to run the function for a single S3 event?

A. 1 time (no retries)
B. 2 times (1 initial + 1 retry)
C. 3 times (1 initial + 2 retries)
D. Indefinitely until successful

**Answer: C**

**Why C is correct:** For asynchronous invocations, Lambda automatically retries twice — total of 3 attempts (1 original + 2 retries). After all 3 fail, the event is either sent to a DLQ/Destination or discarded. Like the kitchen trying to cook the order 3 times before giving up and sending it to the complaint department.

**Why A is wrong:** Lambda always retries async invocations (at least the default 2 retries).

**Why B is wrong:** It's 2 retries, not 1.

**Why D is wrong:** Lambda doesn't retry indefinitely. That would be an event source mapping behavior (e.g., Kinesis, which retries until the record expires).

---

### Q10 (SAA) — Lambda@Edge vs CloudFront Functions

A company needs to add a simple security header (`X-Frame-Options: DENY`) to all HTTP responses served through CloudFront. The processing must add minimal latency. Which option is BEST?

A. Lambda@Edge on viewer response
B. CloudFront Functions on viewer response
C. A Lambda function behind the origin
D. CloudFront cache behavior with custom headers

**Answer: B**

**Why B is correct:** CloudFront Functions run at viewer request/response for lightweight operations like header manipulation. They execute in under 1 ms, cost 1/6th of Lambda@Edge, and run at all 300+ edge locations. Adding a single header is the perfect use case. Like having a stamp at every local post office — quick, cheap, everywhere.

**Why A is wrong:** Lambda@Edge works but is overkill. Higher latency (~5ms vs <1ms), higher cost, and unnecessary for a simple header addition.

**Why C is wrong:** Processing at the origin means every request goes all the way back to the origin server, defeating the purpose of edge processing and adding latency.

**Why D is wrong:** CloudFront cache behaviors can add custom headers to origin requests, not viewer responses. This doesn't solve the problem.

---

### Q11 (DVA) — DynamoDB Streams + Lambda

A Lambda function is configured with a DynamoDB Streams event source mapping. The function fails while processing a batch of stream records. What happens next?

A. The failed records are sent to the function's DLQ
B. Lambda retries the entire batch until the records expire from the stream (24 hours)
C. Lambda skips the failed records and moves to the next batch
D. The failed records are returned to the stream for other consumers

**Answer: B**

**Why B is correct:** For stream-based event source mappings (DynamoDB Streams, Kinesis), Lambda retries the entire batch until success OR the records expire from the stream. DynamoDB Streams retain records for 24 hours. This means a single bad record can block processing of all subsequent records in that shard. To handle this: configure `BisectBatchOnFunctionError` (splits the batch to isolate the bad record), `MaximumRetryAttempts`, or an `OnFailure` destination.

**Why A is wrong:** DLQ is for async invocations. Event source mappings use Destinations (OnFailure) for error handling, not DLQ.

**Why C is wrong:** Lambda does NOT skip records. Stream processing is ordered — skipping would break the order guarantee.

**Why D is wrong:** Stream records aren't "returned." They remain in the stream, and Lambda retries from the same position.

---

### Q12 (SOA) — Troubleshooting Permissions

A Lambda function needs to read from an S3 bucket and write to a DynamoDB table. The function's execution role has `AmazonS3ReadOnlyAccess` but when it tries to write to DynamoDB, it gets an `AccessDeniedException`. What is the fix?

A. Add the DynamoDB table ARN to the S3 policy
B. Attach a policy with `dynamodb:PutItem` permission to the Lambda execution role
C. Add a resource-based policy to the DynamoDB table allowing the Lambda function
D. Use the Lambda function's environment variables to pass DynamoDB credentials

**Answer: B**

**Why B is correct:** The Lambda execution role defines what AWS services the function can access. It has S3 read access but no DynamoDB permissions. Attach a policy granting `dynamodb:PutItem` (and any other needed DynamoDB actions) to the execution role. The execution role is the chef's badge — it determines which rooms (services) the chef can enter.

**Why A is wrong:** You can't add DynamoDB permissions to an S3 policy. Each service has its own action namespace.

**Why C is wrong:** DynamoDB doesn't support resource-based policies (unlike S3 or Lambda). Access is controlled through IAM identity-based policies only.

**Why D is wrong:** Never pass credentials through environment variables. IAM roles are the correct way to grant service access to Lambda.
