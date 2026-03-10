# X-Ray — Exam Practice Questions

---

## Q1: Annotations vs Metadata

A developer instruments a Lambda function with X-Ray. They need to tag traces with `customer_id` so the support team can search for all traces related to a specific customer. They also want to attach the full request body for debugging. What should they use?

**A)** Annotations for both customer_id and request body
**B)** Metadata for both customer_id and request body
**C)** Annotations for customer_id, Metadata for request body
**D)** Custom CloudWatch dimensions for customer_id, X-Ray for request body

### Answer: C

**Why:** Annotations are indexed and searchable — perfect for `customer_id` since the support team needs to FILTER traces by customer. Metadata is non-indexed — perfect for the request body since it's large, informational, and only needed when viewing a specific trace. Think of it as: annotations are sticky notes on the investigation board (findable), metadata is inside the case file (detailed but not searchable).

- **A is wrong:** Annotations have a 50 per-segment limit and should be reserved for searchable fields. The full request body is too large and doesn't need to be searchable.
- **B is wrong:** Metadata for customer_id means you CAN'T search by customer — defeating the purpose.
- **D is wrong:** CloudWatch dimensions are for metrics, not trace searchability. X-Ray annotations are the correct mechanism for trace filtering.

---

## Q2: Lambda X-Ray Integration

A developer enables X-Ray tracing on a Lambda function. The Lambda calls DynamoDB and an external HTTP API. X-Ray shows the Lambda segment but no subsegments for DynamoDB or the HTTP call. What is missing?

**A)** The X-Ray daemon is not running on the Lambda execution environment
**B)** The Lambda function code needs to use the X-Ray SDK to instrument downstream calls
**C)** DynamoDB doesn't support X-Ray tracing
**D)** The Lambda execution role needs `dynamodb:Trace` permission

### Answer: B

**Why:** Enabling active tracing on Lambda creates the segment (Lambda's own contribution), but subsegments (downstream calls to DynamoDB, HTTP) require **SDK instrumentation** in your code. You must use the X-Ray SDK to wrap the AWS SDK client and HTTP client. Example: `AWSXRay.captureAWSClient(new DynamoDB())` and `AWSXRay.captureHTTPsGlobal(require('http'))`.

- **A is wrong:** Lambda has built-in X-Ray support — no daemon needed. The daemon is only for EC2/ECS.
- **C is wrong:** DynamoDB calls ARE traced by X-Ray, but only when you instrument the AWS SDK client with the X-Ray SDK.
- **D is wrong:** There's no `dynamodb:Trace` permission. X-Ray needs `xray:PutTraceSegments` on the Lambda role, not DynamoDB-specific trace permissions.

---

## Q3: Sampling Rules

A payments service processes 10,000 requests per second. The team wants to trace 100% of payment failures but only 1% of successful payments to control costs. How should they configure sampling?

**A)** Set the default rule to 100% sampling
**B)** Create a custom sampling rule: service = payments, URL = /api/payments, HTTP status = 5xx, fixed rate = 1.0 (100%). Keep default rule for successes (1/s + 5%)
**C)** Disable sampling entirely
**D)** Set the reservoir to 10,000 per second

### Answer: B

**Why:** Custom sampling rules let you set different rates for different conditions. A high-priority rule targeting 5xx responses with 100% rate ensures all failures are traced. The default rule (or a lower-priority rule for 200 responses) captures 1% of successes. X-Ray evaluates rules by priority — lower number wins.

Note: X-Ray sampling rules can't directly filter by HTTP status (they filter by service, URL path, HTTP method). In practice, you'd need to sample more broadly and use annotations to filter failures. But the exam concept being tested is custom sampling rules for different request types.

- **A is wrong:** 100% sampling at 10K/s = 10,000 traces/second. Extremely expensive and unnecessary for successful requests.
- **C is wrong:** No sampling means ALL requests are traced. Even more expensive than 100%.
- **D is wrong:** A reservoir of 10,000/s means 10,000 guaranteed traces per second — effectively 100% at this volume.

---

## Q4: X-Ray Daemon Setup

A team runs a Node.js application on EC2 instances. They want to enable X-Ray tracing. What do they need to set up?

**A)** Just import the X-Ray SDK in the application code
**B)** Install and run the X-Ray daemon on the EC2 instances, instrument the code with X-Ray SDK, and ensure the instance role has X-Ray permissions
**C)** Enable "active tracing" in the EC2 console
**D)** Install CloudWatch agent with X-Ray plugin

### Answer: B

**Why:** EC2 requires three things: (1) X-Ray daemon running as a background process (listens on UDP 2000, batches and sends traces), (2) Application code instrumented with X-Ray SDK (creates segments, subsegments, annotations), (3) IAM instance profile with `xray:PutTraceSegments` and `xray:PutTelemetryRecords` permissions.

- **A is wrong:** The SDK alone generates trace data but needs the daemon to forward it to the X-Ray API. Without the daemon, trace data has nowhere to go.
- **C is wrong:** EC2 doesn't have an "active tracing" toggle like Lambda. Tracing on EC2 requires manual daemon and SDK setup.
- **D is wrong:** CloudWatch agent and X-Ray daemon are separate. There's no "X-Ray plugin" for the CloudWatch agent (though newer unified agents may support both).

---

## Q5: Service Map Analysis

A SysOps admin looks at the X-Ray service map and sees that the `auth-service` node is red with a 15% error rate. All downstream services show green. What does this indicate?

**A)** The auth-service's downstream services are causing the errors
**B)** The auth-service itself is generating errors (not from downstream calls)
**C)** The X-Ray daemon is not running on the auth-service
**D)** The sampling rate is too low to detect real errors

### Answer: B

**Why:** On the service map, each node shows its own health. If `auth-service` is red but its downstream services are green, the errors originate IN the auth-service itself — not from downstream calls. If a downstream call was failing, that node would also be red/yellow. The investigation should focus on the auth-service's code, configuration, or resource limits.

- **A is wrong:** If downstream services were causing errors, their nodes would show elevated error rates too.
- **C is wrong:** If the daemon weren't running, the auth-service wouldn't appear on the service map at all.
- **D is wrong:** The service map shows aggregated data. A 15% error rate is clearly visible regardless of sampling rate.

---

## Q6: ECS Fargate X-Ray Setup

A team runs microservices on ECS Fargate. They want to add X-Ray tracing. How should they deploy the X-Ray daemon?

**A)** Install the daemon on the underlying Fargate infrastructure
**B)** Run the X-Ray daemon as a sidecar container in the task definition
**C)** Use a separate ECS service running only the X-Ray daemon
**D)** X-Ray doesn't work with Fargate

### Answer: B

**Why:** With Fargate, you don't have access to the underlying infrastructure (no EC2 to install on). The X-Ray daemon runs as a **sidecar container** in the same task definition as your application. The application container sends trace data to the sidecar on localhost:2000 (UDP), and the sidecar forwards to the X-Ray API.

- **A is wrong:** Fargate is serverless — you can't install anything on the underlying infrastructure. You only control containers.
- **C is wrong:** A separate ECS service would run on different tasks/IPs. The daemon needs to be co-located with the application (same task) to receive UDP traffic on localhost.
- **D is wrong:** X-Ray works with Fargate via the sidecar pattern. It's a well-documented and supported approach.

---

## Q7: Trace ID Propagation

A request flows from API Gateway → Lambda A → Lambda B (invoked via SDK). Lambda A has X-Ray enabled. Lambda B's traces show up as separate, disconnected traces instead of being part of the same trace. What's the issue?

**A)** Lambda B doesn't have X-Ray enabled
**B)** The Trace ID header (`X-Amzn-Trace-Id`) is not being propagated from Lambda A to Lambda B
**C)** X-Ray can't trace Lambda-to-Lambda calls
**D)** The X-Ray daemon is not running between the two Lambdas

### Answer: B

**Why:** For traces to connect across services, the **Trace ID must be propagated**. When Lambda A invokes Lambda B via the AWS SDK, the X-Ray SDK automatically propagates the trace header IF the SDK client is instrumented. If Lambda A uses a raw SDK call without X-Ray instrumentation, the trace header isn't forwarded, and Lambda B starts a new trace.

- **A is wrong:** Even with X-Ray enabled on both, the traces will be disconnected without trace ID propagation. Enabling tracing is necessary but not sufficient.
- **C is wrong:** X-Ray absolutely supports Lambda-to-Lambda tracing. The SDK handles propagation when properly instrumented.
- **D is wrong:** Lambda doesn't use an external daemon. The issue is header propagation, not daemon connectivity.

---

## Q8: X-Ray Groups

A team wants a CloudWatch alarm that fires when the error rate for traces matching `/api/orders/*` exceeds 5%. Which X-Ray feature should they use?

**A)** Custom sampling rules for the orders endpoint
**B)** X-Ray Groups with a filter expression, connected to a CloudWatch alarm
**C)** X-Ray Insights with automatic anomaly detection
**D)** CloudWatch Logs filter on X-Ray trace data

### Answer: B

**Why:** X-Ray Groups let you define filter expressions (e.g., `service("order-service") AND http.url BEGINSWITH "/api/orders/"`) that group matching traces. Groups emit CloudWatch metrics (error rate, latency, request count), and you can create CloudWatch alarms on these metrics. This gives you targeted alerting on specific trace patterns.

- **A is wrong:** Sampling rules control WHICH requests are traced, not alerting. They don't generate CloudWatch alarms.
- **C is wrong:** Insights detect anomalies automatically but don't provide the specific threshold-based alerting (">5% error rate") the team wants.
- **D is wrong:** X-Ray trace data isn't stored in CloudWatch Logs. X-Ray has its own storage. Groups + CloudWatch metrics is the correct integration.

---

## Q9: X-Ray vs CloudWatch

A microservices application has intermittent latency spikes. CloudWatch shows average Lambda duration is 200ms, but some users report 5-second response times. Which tool helps identify the bottleneck?

**A)** CloudWatch detailed monitoring with 1-minute metrics
**B)** X-Ray traces filtered for high latency to see which downstream service is slow
**C)** VPC Flow Logs to check network latency
**D)** CloudTrail to check API call patterns

### Answer: B

**Why:** CloudWatch shows averages and aggregates — a 200ms average hides the 5-second outliers. X-Ray traces individual requests end-to-end. Filter for traces with duration > 5000ms, then examine the trace to see which segment (service) or subsegment (downstream call) is consuming the time. Is it DynamoDB? An external API? Cold starts? X-Ray shows exactly where.

- **A is wrong:** 1-minute CloudWatch metrics still show averages. You need per-request tracing, not per-minute metrics, to find intermittent bottlenecks.
- **C is wrong:** VPC Flow Logs show network packet-level data (IPs, ports, bytes). They don't show application-level latency breakdowns.
- **D is wrong:** CloudTrail logs API calls to AWS services, not the latency breakdown of your application's request processing.

---

## Q10: Active Tracing on API Gateway

A developer enables X-Ray active tracing on an API Gateway stage. Traces appear for the API Gateway segment but the Lambda function behind it doesn't show subsegments. What additional step is needed?

**A)** Enable active tracing on the Lambda function as well
**B)** Install the X-Ray daemon on the API Gateway
**C)** Increase the sampling rate to 100%
**D)** Add the `X-Amzn-Trace-Id` header in the API Gateway method request

### Answer: A

**Why:** API Gateway with active tracing creates its own segment and propagates the Trace ID to Lambda. But Lambda must ALSO have active tracing enabled to create its segment and subsegments. Without it, Lambda receives the trace ID but doesn't generate trace data. Both services need tracing enabled independently.

- **B is wrong:** API Gateway is a fully managed service. You can't install a daemon on it. Tracing is toggled in stage settings.
- **C is wrong:** Increasing sampling rate doesn't help if the Lambda isn't instrumented. Zero percent of an uninstrumented service still equals zero traces.
- **D is wrong:** API Gateway automatically propagates the trace header when active tracing is enabled. You don't need to configure it manually.
