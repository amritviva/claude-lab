# Step Functions — Workflow Conductor

> **Step Functions is an orchestra conductor managing a complex performance. The state machine is the musical score, each state is a section of the piece, and the conductor ensures every instrument plays at the right time, handles mistakes, and keeps the show going.**

---

## ELI10

Imagine an orchestra conductor standing in front of 50 musicians. The conductor has a musical score (state machine) that says: "First, violins play for 30 seconds. Then, if the audience claps, trumpets join in. If not, flutes play softly. Meanwhile, drums and piano play at the same time. If any musician makes a mistake, try again 3 times, then skip to the next part." The conductor doesn't play any instrument — they just coordinate everyone. That's Step Functions: it doesn't do the work, it orchestrates who does what and when.

---

## The Concept

### Step Functions = Serverless Workflow Orchestration

```
┌──────────────────────────────────────────────────────────────┐
│                    STATE MACHINE                              │
│                  (The Musical Score)                          │
│                                                               │
│  ┌─────────┐    ┌─────────┐    ┌──────────┐    ┌──────────┐ │
│  │  Task   │───>│ Choice  │───>│ Parallel │───>│ Succeed  │ │
│  │(Validate│    │(Premium │    │          │    │          │ │
│  │ Order)  │    │ member?)│    │ ┌──────┐ │    │          │ │
│  └─────────┘    └────┬────┘    │ │Charge│ │    └──────────┘ │
│                      │         │ │Card  │ │                  │
│                 ┌────┴────┐    │ └──────┘ │                  │
│                 │  No?    │    │ ┌──────┐ │                  │
│                 │  Wait   │    │ │Send  │ │                  │
│                 │ 24 hrs  │    │ │Email │ │                  │
│                 └─────────┘    │ └──────┘ │                  │
│                                └──────────┘                  │
└──────────────────────────────────────────────────────────────┘
```

### State Types — The Building Blocks

| State | Analogy | What It Does |
|-------|---------|-------------|
| **Task** | Musician playing | Does work: invoke Lambda, call AWS API, run ECS task, etc. |
| **Choice** | Conductor reads the audience | If/else branching based on input data |
| **Wait** | Pause between movements | Wait for X seconds, or until a specific timestamp |
| **Parallel** | Multiple sections playing together | Run branches concurrently, all must complete |
| **Map** | Each musician plays the same piece | Iterate over an array, process each item (like forEach) |
| **Pass** | Turn the page | Transform or inject data, no actual work |
| **Succeed** | Standing ovation | Terminal state — execution succeeded |
| **Fail** | Cancel the show | Terminal state — execution failed with error/cause |

### State Machine Definition — Amazon States Language (ASL)

```json
{
  "Comment": "Order Processing Workflow",
  "StartAt": "ValidateOrder",
  "States": {
    "ValidateOrder": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:ap-southeast-2:123456789012:function:validateOrder",
      "Next": "CheckInventory",
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed"],
          "IntervalSeconds": 3,
          "MaxAttempts": 3,
          "BackoffRate": 2.0
        }
      ],
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "OrderFailed"
        }
      ]
    },
    "CheckInventory": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.inStock",
          "BooleanEquals": true,
          "Next": "ProcessPayment"
        }
      ],
      "Default": "OutOfStock"
    },
    "ProcessPayment": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sqs:sendMessage",
      "Parameters": {
        "QueueUrl": "https://sqs.ap-southeast-2.amazonaws.com/123456789012/payments",
        "MessageBody.$": "$.orderDetails"
      },
      "Next": "OrderComplete"
    },
    "OrderComplete": { "Type": "Succeed" },
    "OutOfStock": { "Type": "Fail", "Error": "OutOfStock", "Cause": "Item not available" },
    "OrderFailed": { "Type": "Fail", "Error": "OrderError", "Cause": "Order processing failed" }
  }
}
```

### Standard vs Express Workflows

```
┌────────────────────────────┬────────────────────────────┐
│    STANDARD WORKFLOW        │    EXPRESS WORKFLOW          │
├────────────────────────────┼────────────────────────────┤
│ Exactly-once execution     │ At-least-once execution     │
│ Up to 1 YEAR duration      │ Up to 5 MINUTES duration    │
│ 2,000 transitions/second   │ 100,000+ transitions/second │
│ Higher cost per transition  │ Lower cost (per execution)  │
│ Execution history logged    │ Logs sent to CloudWatch     │
│                             │                              │
│ Use for:                    │ Use for:                     │
│ • Order processing          │ • IoT data processing        │
│ • ETL pipelines             │ • High-volume streaming      │
│ • Long-running workflows    │ • Microservice orchestration │
│ • ML model training         │ • Real-time transformations  │
│ • Human approval flows      │                              │
│                             │                              │
│ Priced: per state           │ Priced: per execution +      │
│ transition                  │ duration                     │
└────────────────────────────┴────────────────────────────┘

Express sub-types:
• Synchronous: caller WAITS for result (API Gateway → Express → response)
• Asynchronous: fire-and-forget (event triggers, no immediate response)
```

### Error Handling — Retry & Catch

```
┌──────────────────────────────────────────────────────────┐
│                  ERROR HANDLING                            │
│                                                           │
│  RETRY (try again before giving up):                      │
│  ┌─────────────────────────────────────────────┐         │
│  │ "Retry": [{                                  │         │
│  │   "ErrorEquals": ["States.TaskFailed"],       │         │
│  │   "IntervalSeconds": 3,    ← wait 3s         │         │
│  │   "MaxAttempts": 3,        ← try 3 times     │         │
│  │   "BackoffRate": 2.0       ← 3s, 6s, 12s     │         │
│  │ }]                                            │         │
│  └─────────────────────────────────────────────┘         │
│                                                           │
│  CATCH (if all retries fail, go here):                    │
│  ┌─────────────────────────────────────────────┐         │
│  │ "Catch": [{                                  │         │
│  │   "ErrorEquals": ["States.ALL"],              │         │
│  │   "ResultPath": "$.error",                    │         │
│  │   "Next": "HandleError"                       │         │
│  │ }]                                            │         │
│  └─────────────────────────────────────────────┘         │
│                                                           │
│  Built-in Error Types:                                    │
│  • States.ALL — catch everything                          │
│  • States.TaskFailed — task failed                        │
│  • States.Timeout — task timed out                        │
│  • States.Permissions — insufficient permissions          │
│  • States.ResultPathMatchFailure — result path error      │
│                                                           │
│  Timeouts:                                                │
│  • TimeoutSeconds — max time for a single task            │
│  • HeartbeatSeconds — task must send heartbeat            │
│    before this interval or it's considered failed          │
└──────────────────────────────────────────────────────────┘
```

### Integration Patterns

```
┌────────────────────────────────────────────────────────────┐
│                INTEGRATION PATTERNS                         │
│                                                             │
│  1. REQUEST-RESPONSE (default):                             │
│     Step Functions calls service → waits → gets response    │
│     "Resource": "arn:aws:states:::lambda:invoke"            │
│                                                             │
│  2. RUN A JOB (.sync):                                      │
│     Step Functions starts job → waits for COMPLETION         │
│     "Resource": "arn:aws:states:::ecs:runTask.sync"         │
│     Good for: ECS tasks, Glue jobs, Batch jobs              │
│                                                             │
│  3. WAIT FOR CALLBACK (.waitForTaskToken):                   │
│     Step Functions pauses → sends token → waits for          │
│     external system to call SendTaskSuccess/SendTaskFailure  │
│     "Resource": "arn:aws:states:::sqs:sendMessage            │
│                  .waitForTaskToken"                           │
│     Good for: human approvals, external API callbacks        │
│                                                             │
│  Optimized Integrations (200+ AWS services):                 │
│  Lambda, ECS, SNS, SQS, DynamoDB, Glue, Batch,              │
│  SageMaker, EMR, CodeBuild, API Gateway, EventBridge...     │
└────────────────────────────────────────────────────────────┘
```

### Map State — Process Arrays

```
Input:  { "orders": [order1, order2, order3] }

┌─────────────────────────────────────┐
│           Map State                  │
│                                      │
│  Inline Map:                         │
│  Process items within the workflow   │
│  Max 40 concurrent iterations        │
│                                      │
│  Distributed Map:                    │
│  Process millions of items from S3   │
│  Up to 10,000 concurrent executions  │
│  Reads from: S3, JSON array          │
│                                      │
│  order1 ──> [Process] ──> result1    │
│  order2 ──> [Process] ──> result2    │
│  order3 ──> [Process] ──> result3    │
│                                      │
│  Output: [result1, result2, result3] │
└─────────────────────────────────────┘
```

### Step Functions vs SQS vs EventBridge

```
┌───────────────────┬────────────────┬──────────────────┐
│  Step Functions    │  SQS            │  EventBridge      │
├───────────────────┼────────────────┼──────────────────┤
│ Orchestration     │ Decoupling      │ Event routing     │
│ Complex workflows │ Simple queue    │ Pattern matching  │
│ Visual workflow   │ FIFO or std     │ Rules + targets   │
│ Error handling    │ DLQ for errors  │ Archive & replay  │
│ State tracking    │ No state        │ No state          │
│ Branching/loops   │ No logic        │ No logic          │
│                    │                  │                    │
│ "Do A, then B,    │ "Put work here, │ "When X happens,  │
│  if C then D"     │  someone will    │  notify Y and Z"  │
│                    │  pick it up"    │                    │
└───────────────────┴────────────────┴──────────────────┘
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- **Standard vs Express** — duration, pricing, execution guarantees
- **Orchestration pattern** — when to use Step Functions vs SQS vs EventBridge
- **Error handling** — Retry with exponential backoff, Catch for fallback
- **Long-running workflows** — human approval, callback pattern
- **Parallel processing** — Parallel state, Map state (distributed for S3 processing)

### DVA-C02 (Developer)
- **ASL (Amazon States Language)** — JSON workflow definition, state types
- **Integration patterns** — `.sync`, `.waitForTaskToken`, request-response
- **Input/Output processing** — InputPath, OutputPath, ResultPath, Parameters
- **Error handling** — Retry, Catch, error types (States.ALL, States.TaskFailed)
- **Callback pattern** — task token for external system integration

### SOA-C02 (SysOps)
- **Monitoring** — ExecutionsFailed, ExecutionsTimedOut, ThrottledEvents
- **Execution history** — view in console, troubleshoot failed executions
- **CloudWatch Logs** — required for Express workflows (not auto-logged like Standard)
- **IAM roles** — Step Functions execution role needs permissions for all integrated services
- **Quotas** — state transitions per second, max execution duration

---

## Key Numbers

| Fact | Value |
|------|-------|
| Standard max duration | 1 year |
| Express max duration | 5 minutes |
| Standard state transitions/sec | 2,000 (default soft limit) |
| Express executions/sec | 100,000+ |
| Max input/output size | 256 KB |
| Max execution history events | 25,000 (Standard) |
| Inline Map max concurrency | 40 |
| Distributed Map max concurrency | 10,000 |
| Retry MaxAttempts default | 3 |
| Task default timeout | No timeout (waits forever — always set TimeoutSeconds!) |

---

## Cheat Sheet

- **Step Functions = serverless orchestrator.** Coordinates Lambda, ECS, SQS, DynamoDB, etc.
- **Standard = long, reliable.** Up to 1 year, exactly-once, full execution history.
- **Express = fast, cheap.** Up to 5 minutes, at-least-once, high volume.
- **Synchronous Express** = API Gateway calls workflow, waits for response.
- **ASL (Amazon States Language)** = JSON-based workflow definition.
- **Task state** = do work. Choice = if/else. Parallel = concurrent. Map = forEach. Wait = pause.
- **Retry** = automatic retry with exponential backoff (IntervalSeconds × BackoffRate).
- **Catch** = fallback when all retries exhausted. Goes to error-handling state.
- **ALWAYS set TimeoutSeconds** on Task states. Default is NO timeout (hangs forever).
- **HeartbeatSeconds** = task must heartbeat within this interval or it's timed out.
- **`.sync`** = wait for job completion (ECS, Glue, Batch).
- **`.waitForTaskToken`** = pause until external system calls back with token.
- **Callback pattern** = human approval, external API, async processing.
- **Distributed Map** = process millions of S3 items in parallel.
- **Step Functions vs SQS:** orchestration (multi-step logic) vs decoupling (fire-and-forget).
- **Step Functions vs EventBridge:** workflow control vs event routing.
- **Execution role** needs IAM permissions for every service the workflow calls.
