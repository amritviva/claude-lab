# Step Functions — Exam Practice Questions

---

## Q1: Standard vs Express

A company processes IoT sensor data from 50,000 devices. Each device sends data every second. The workflow validates the data, enriches it, and stores it in DynamoDB — total processing takes about 10 seconds per message. Which Step Functions workflow type should they use?

**A)** Standard workflow with synchronous execution
**B)** Express workflow (asynchronous)
**C)** Standard workflow with asynchronous execution
**D)** Express workflow (synchronous)

### Answer: B

**Why:** 50,000 messages/second = extremely high volume. Express workflows handle 100,000+ executions/second. Processing takes 10 seconds (well under the 5-minute limit). At-least-once is acceptable for IoT data (duplicate sensor readings are tolerable). Asynchronous because no caller needs to wait for each result — it's fire-and-forget processing.

- **A is wrong:** Standard workflows cap at ~2,000 state transitions/second and cost much more per transition. Not suitable for 50K/s volume.
- **C is wrong:** Same throughput limitation as A. Standard is for long-running, low-volume workflows.
- **D is wrong:** Synchronous Express means the caller waits for the result. With IoT data at 50K/s, there's no caller waiting — devices just emit data.

---

## Q2: Error Handling

A Step Functions workflow calls a Lambda function that occasionally fails due to a downstream API timeout. The architect wants to retry 3 times with exponential backoff (2s, 4s, 8s) before routing to an error-handling state. Which configuration achieves this?

**A)** Configure a CloudWatch alarm to detect Lambda failures and trigger a remediation Lambda
**B)** Add a Retry block with `IntervalSeconds: 2`, `MaxAttempts: 3`, `BackoffRate: 2.0`, and a Catch block pointing to the error state
**C)** Use a Choice state after the Lambda to check for errors
**D)** Configure the Lambda function's built-in retry mechanism

### Answer: B

**Why:** Step Functions has **native Retry and Catch** on Task states. `IntervalSeconds: 2` starts with 2 seconds, `BackoffRate: 2.0` doubles each time (2s, 4s, 8s), and `MaxAttempts: 3` tries 3 times. If all retries fail, Catch routes to the error-handling state. This is built into the state machine definition — no external services needed.

- **A is wrong:** CloudWatch alarms operate at the minute level, not per-execution. Way too slow and complex for per-invocation retry logic.
- **C is wrong:** A Choice state after the Lambda would only work if the Lambda returns an error in its output. It wouldn't catch Lambda failures (crashes, timeouts). Also, it doesn't provide automatic retry.
- **D is wrong:** Lambda's built-in retry is for asynchronous invocations only (like from SNS, S3 events). When Step Functions calls Lambda, Step Functions controls the retry — not Lambda.

---

## Q3: Callback Pattern

An order processing workflow needs human approval before processing refunds over $500. The workflow should pause, send a notification to a manager, and wait for them to approve or reject via a web portal. Which integration pattern should the architect use?

**A)** Use a Wait state for 24 hours, then check approval status
**B)** Use `.waitForTaskToken` — send the task token to the manager, pause until they call `SendTaskSuccess` or `SendTaskFailure`
**C)** Use a polling loop with a Choice state checking a DynamoDB approval flag every 5 minutes
**D)** Use Express workflow with synchronous execution

### Answer: B

**Why:** The `.waitForTaskToken` pattern is specifically designed for this. Step Functions generates a task token, you send it (via SNS/SQS/email) to the manager. The workflow PAUSES (no cost while waiting). When the manager clicks "Approve" in the web portal, the portal calls `SendTaskSuccess(taskToken)` and the workflow resumes. Think of it as: the conductor pauses the orchestra and hands a baton to the manager — when they raise it, the music continues.

- **A is wrong:** A fixed 24-hour wait doesn't respond to the actual approval. What if the manager approves in 5 minutes? What if they need 3 days? Rigid and wasteful.
- **C is wrong:** Polling loops waste resources and cost money (each state transition costs). The callback pattern is event-driven and free while waiting.
- **D is wrong:** Express workflows max out at 5 minutes. Human approval could take hours or days.

---

## Q4: Parallel vs Map State

A workflow processes a single customer order that requires three independent operations: charge the credit card, send a confirmation email, and update inventory. All three must complete before the order is finalized. Which state type should be used?

**A)** Three sequential Task states
**B)** Map state iterating over the three operations
**C)** Parallel state with three branches
**D)** Three separate Step Functions executions triggered by SNS

### Answer: C

**Why:** Parallel state runs multiple branches **concurrently** and waits for ALL to complete. Three different operations on the same data = Parallel. Map is for the same operation on different items (like processing each item in an order). The distinction: Parallel = different things at once. Map = same thing on many items.

- **A is wrong:** Sequential execution is slower. If card charge takes 3s, email takes 2s, and inventory takes 1s, sequential = 6s. Parallel = 3s (the slowest one).
- **B is wrong:** Map is for iterating over an array of SIMILAR items. Charging a card, sending email, and updating inventory are DIFFERENT operations, not iterations over a collection.
- **D is wrong:** Three separate executions adds complexity (how do you know when all three are done?) and loses the orchestration benefit of Step Functions.

---

## Q5: Distributed Map for S3

A company has 10 million CSV files in S3 that need to be processed — each file needs validation and transformation. The processing takes about 2 seconds per file. What is the MOST efficient approach using Step Functions?

**A)** Standard workflow with an inline Map state processing files one at a time
**B)** Standard workflow with a Distributed Map state reading from S3
**C)** Express workflow with a Lambda function processing all files in a loop
**D)** Standard workflow with a Parallel state for each file

### Answer: B

**Why:** Distributed Map is designed for massive-scale parallel processing of S3 objects. It can process millions of items with up to 10,000 concurrent child executions. It reads directly from S3 (listing objects or reading a manifest). Inline Map maxes out at 40 concurrent iterations — too slow for 10M files.

- **A is wrong:** Inline Map has max 40 concurrent iterations. 10M files at 40 concurrent = extremely slow. Also, 10M iterations would exceed the 25,000 execution history event limit.
- **C is wrong:** Express has a 5-minute limit. Processing 10M files at 2 seconds each would take years in a single execution, even with batching.
- **D is wrong:** Parallel state requires defining each branch statically in the ASL. You can't dynamically create 10 million branches.

---

## Q6: Step Functions vs SQS

A developer is building an order processing system. Orders go through 5 sequential steps: validate, check inventory, charge payment, ship, and send confirmation. If any step fails, the entire order should be rolled back. Which approach is BEST?

**A)** SQS queues between each step, with each step reading from one queue and writing to the next
**B)** Step Functions Standard workflow with Task states for each step, Retry and Catch for error handling
**C)** EventBridge rules routing events between Lambda functions for each step
**D)** SNS topics triggering Lambda functions for each step

### Answer: B

**Why:** Step Functions provides: sequential orchestration (A → B → C → D → E), error handling (Retry + Catch), rollback capability (Catch routes to compensation states), and visual execution tracking. SQS is for decoupling, not orchestration — it doesn't know about steps, sequence, or rollback.

- **A is wrong:** SQS chains are hard to debug, have no built-in rollback, and lose the concept of "one order = one workflow." Each queue is independent — if step 3 fails, how do you tell steps 1 and 2 to roll back?
- **C is wrong:** EventBridge routes events but doesn't orchestrate workflows. No concept of "this event is step 3 of 5" or "roll back if step 3 fails."
- **D is wrong:** SNS is pub/sub fanout. It broadcasts to all subscribers simultaneously — not sequential processing.

---

## Q7: Input/Output Processing

A developer has a Step Functions workflow where a Lambda function returns `{ "statusCode": 200, "body": { "orderId": "123", "total": 45.99 } }`. The next state only needs the `body` object. What should the developer configure?

**A)** `InputPath`: `$.body` on the next state
**B)** `OutputPath`: `$.body` on the Lambda Task state
**C)** `ResultPath`: `$.body` on the Lambda Task state
**D)** `Parameters`: `{ "body.$": "$.body" }` on the next state

### Answer: B

**Why:** `OutputPath` filters what gets passed OUT of a state to the next state. Setting `OutputPath: $.body` means only the body portion (`{ "orderId": "123", "total": 45.99 }`) is passed forward. The distinction between the processing fields:
- **InputPath** = filter what comes INTO a state
- **ResultPath** = where to PUT the result in the original input (combines result with input)
- **OutputPath** = filter what goes OUT to the next state
- **Parameters** = construct the input to the task from the state's input

- **A is wrong:** InputPath on the NEXT state would work if the current state's full output is passed. But it's better practice to filter at the source (OutputPath on the producing state).
- **C is wrong:** ResultPath specifies WHERE to store the result in the state's input. `ResultPath: $.body` would store the Lambda result under a `body` key in the original input — not filter it.
- **D is wrong:** Parameters constructs input for the task execution, not for filtering output.

---

## Q8: Timeout and Heartbeat

A Step Functions workflow calls an ECS task that usually completes in 10 minutes but sometimes hangs indefinitely due to a bug. The team wants to detect hung tasks within 2 minutes. What should they configure?

**A)** Set `TimeoutSeconds: 600` on the Task state
**B)** Set `HeartbeatSeconds: 120` on the Task state, and have the ECS task send heartbeats
**C)** Set a CloudWatch alarm for ECS task duration
**D)** Use an Express workflow with a 5-minute limit

### Answer: B

**Why:** `HeartbeatSeconds` requires the task to send periodic heartbeats. If no heartbeat arrives within 120 seconds (2 minutes), Step Functions considers the task failed and triggers Retry/Catch. This detects hangs QUICKLY without waiting for the full timeout. The ECS task calls `SendTaskHeartbeat` periodically while processing. A `TimeoutSeconds` alone would let the task hang for the full duration.

- **A is wrong:** A 600-second timeout would let the task hang for 10 minutes before detecting the issue. The requirement is 2-minute detection.
- **C is wrong:** CloudWatch alarms have minimum 1-minute periods and don't integrate directly with Step Functions error handling. More operational overhead.
- **D is wrong:** Express workflows max at 5 minutes and the task normally takes 10 minutes. Also, Express doesn't provide per-task heartbeat control.

---

## Q9: Workflow Integration with API Gateway

A company wants to expose a Step Functions workflow as a REST API. Clients submit a request and expect an immediate response with the workflow result. The workflow takes about 3 seconds. Which is the BEST approach?

**A)** API Gateway → Lambda → Start Standard workflow asynchronously → poll for result
**B)** API Gateway → Start Synchronous Express workflow → return result
**C)** API Gateway → Standard workflow with `.waitForTaskToken`
**D)** API Gateway → Lambda that runs the workflow logic inline

### Answer: B

**Why:** Synchronous Express workflows are designed for this: the caller (API Gateway) waits for the workflow to complete and gets the result directly. 3 seconds is well within the 5-minute Express limit. API Gateway has native integration with Step Functions — no Lambda proxy needed.

- **A is wrong:** Polling adds complexity and latency. Starting a Standard workflow is asynchronous — you'd need a polling mechanism to get the result. Overkill for a 3-second workflow.
- **C is wrong:** `.waitForTaskToken` is for pausing until an EXTERNAL system calls back. There's no external system here — the workflow does all the work internally.
- **D is wrong:** Running workflow logic in a single Lambda loses all Step Functions benefits: visual tracking, error handling, state management, and maintainability.

---

## Q10: Execution Role Permissions

A developer creates a Step Functions workflow that invokes a Lambda function, writes to DynamoDB, and sends an SNS notification. The workflow fails with an AccessDenied error on the DynamoDB write. What should the developer check?

**A)** The Lambda function's execution role needs DynamoDB permissions
**B)** The Step Functions execution role needs DynamoDB permissions
**C)** The DynamoDB table's resource policy needs to allow Step Functions
**D)** The IAM user who created the workflow needs DynamoDB permissions

### Answer: B

**Why:** When Step Functions makes DIRECT integrations (calling DynamoDB, SNS, etc.), it uses its own **execution role**. This role needs permissions for every AWS service the workflow directly calls. If the DynamoDB write is a direct integration (`arn:aws:states:::dynamodb:putItem`), the Step Functions execution role needs `dynamodb:PutItem`.

- **A is wrong:** The Lambda execution role matters for actions the Lambda code performs. But if Step Functions is calling DynamoDB DIRECTLY (not through Lambda), it's the Step Functions role that matters.
- **C is wrong:** DynamoDB doesn't have resource-based policies. Access is controlled entirely through IAM identity policies.
- **D is wrong:** The IAM user who creates the workflow doesn't execute it. The execution role is what matters at runtime.
