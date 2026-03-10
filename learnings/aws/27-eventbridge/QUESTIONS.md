# EventBridge — Exam Practice Questions

---

## Q1: EventBridge vs SNS

A company needs to route order events to different processing services based on the order's content: orders over $500 go to a fraud detection Lambda, orders from VIP customers go to a priority queue (SQS), and all orders go to an analytics pipeline (Kinesis). Which service is BEST suited?

**A)** SNS with message filtering
**B)** EventBridge with content-based rules
**C)** SQS with message attributes
**D)** Kinesis Data Streams with partition keys

### Answer: B

**Why:** EventBridge supports rich content-based filtering: numeric comparisons (`> 500`), exact match on customer type, and multiple rules on the same bus — each routing to different targets. One event can match multiple rules, so the analytics rule catches all orders while specific rules handle fraud and VIP routing.

- **A is wrong:** SNS message filtering supports attribute-based filtering but not rich content matching (no numeric > comparisons on message body). You'd need to extract attributes at publish time.
- **C is wrong:** SQS is a queue, not a router. It doesn't filter or route messages to different consumers based on content.
- **D is wrong:** Kinesis routes by partition key to shards, not by content to different services. It's a stream, not a router.

---

## Q2: Event Pattern Matching

A developer wants to create an EventBridge rule that triggers when an EC2 instance in the `ap-southeast-2` region is terminated. Which event pattern is correct?

**A)**
```json
{
  "source": ["aws.ec2"],
  "detail-type": ["EC2 Instance State-change Notification"],
  "region": ["ap-southeast-2"],
  "detail": { "state": ["terminated"] }
}
```

**B)**
```json
{
  "source": ["ec2"],
  "detail-type": ["EC2 Instance Terminated"],
  "detail": { "state": ["terminated"] }
}
```

**C)**
```json
{
  "source": ["aws.ec2"],
  "detail": { "state": ["terminated"], "region": ["ap-southeast-2"] }
}
```

**D)**
```json
{
  "source": ["aws.ec2"],
  "detail-type": ["EC2 Instance State-change Notification"],
  "detail": { "state": ["terminated"] }
}
```

### Answer: D

**Why:** The correct pattern uses `source: aws.ec2` (AWS services use the `aws.` prefix), the exact `detail-type`, and matches `state: terminated` in the detail. Region filtering is done at the event bus level (rules only see events from their own region), not in the pattern itself. If the rule is created in `ap-southeast-2`, it only sees events from that region.

- **A is wrong:** `region` is a top-level event field, but EventBridge rules automatically only see events from the bus's region. Adding `region` in the pattern is unnecessary and the syntax placement may cause issues.
- **B is wrong:** The source should be `aws.ec2`, not `ec2`. The detail-type must exactly match what EC2 emits: `EC2 Instance State-change Notification`, not a custom string.
- **C is wrong:** Missing `detail-type` makes the pattern too broad (matches ALL EC2 events). Also, `region` is not inside the `detail` object.

---

## Q3: Scheduler vs CloudWatch Events

A SysOps admin needs to schedule a Lambda function to run at 9 AM Sydney time every weekday. The team currently uses CloudWatch Events but struggles with time zone conversions (UTC). What is the BETTER approach?

**A)** CloudWatch Events with UTC-adjusted cron: `cron(22 * ? * SUN-THU *)`
**B)** EventBridge Scheduler with time zone set to `Australia/Sydney` and cron: `cron(0 9 ? * MON-FRI *)`
**C)** Lambda function that runs every minute and checks if it's 9 AM in Sydney
**D)** EC2 instance with a system cron job running at 9 AM AEST

### Answer: B

**Why:** EventBridge Scheduler natively supports time zones. You specify `Australia/Sydney` and write the cron in local time. It automatically handles daylight saving shifts (AEST/AEDT). CloudWatch Events only supports UTC, requiring manual offset calculation and DST adjustment.

- **A is wrong:** UTC offset changes with daylight saving (AEST = UTC+10, AEDT = UTC+11). A fixed UTC cron would be wrong for half the year. Also, the day mapping is wrong (SUN-THU instead of MON-FRI offset).
- **C is wrong:** Running a Lambda every minute is wasteful (1,440 invocations/day instead of 5). Cost and complexity for no benefit.
- **D is wrong:** Managing an EC2 instance for a cron job is maximum operational overhead. You manage the OS, patching, uptime, and monitoring — all for one scheduled task.

---

## Q4: Archive and Replay

A team deployed a new EventBridge rule targeting a Lambda function. The Lambda had a bug that caused it to silently drop events for 3 hours before the bug was discovered. They need to reprocess the lost events. What should they have configured?

**A)** A dead-letter queue (DLQ) on the rule
**B)** An EventBridge archive on the event bus
**C)** CloudTrail logging for EventBridge API calls
**D)** Lambda destination for failed invocations

### Answer: B

**Why:** An EventBridge archive stores copies of events that flow through the bus. After fixing the bug, you can **replay** the archived events for the 3-hour window. The replayed events flow through the bus again, matching rules and triggering the (now fixed) Lambda. Think of it as: the news archive lets you replay yesterday's news through the fixed filter.

- **A is wrong:** A DLQ captures events that EventBridge FAILED to deliver to the target. In this case, events were delivered successfully — the Lambda bug was in processing, not delivery. The DLQ would be empty.
- **C is wrong:** CloudTrail logs API calls (who created rules, who put events), not the events themselves. You can't replay API call logs as events.
- **D is wrong:** Lambda destinations handle the Lambda's OWN failures (errors, timeouts). If the Lambda ran "successfully" but had a logic bug (silently dropping data), the destination wouldn't trigger.

---

## Q5: Cross-Account Events

A company has a security account (111111111111) that monitors all EC2 instance terminations across 10 application accounts. How should they architect this?

**A)** Install CloudWatch agents on all EC2 instances that report to the security account
**B)** In each app account, create an EventBridge rule that sends EC2 termination events to the security account's event bus
**C)** Use AWS Config in the security account to monitor EC2 across all accounts
**D)** Enable CloudTrail in each account and aggregate logs in the security account

### Answer: B

**Why:** EventBridge supports **cross-account event delivery**. Each app account creates a rule on the default bus matching EC2 termination events, targeting the security account's custom event bus. The security account's bus has a resource policy allowing the app accounts. Events flow in near-real-time — the security account processes them with its own rules.

- **A is wrong:** CloudWatch agents report metrics and logs, not EC2 state changes. Also, installing agents on all instances is high operational overhead.
- **C is wrong:** AWS Config records configuration state, not real-time events. It's for compliance ("is this resource configured correctly?"), not for event monitoring ("an instance was just terminated").
- **D is wrong:** CloudTrail logs API calls and can be aggregated, but it's a log analysis approach with higher latency. EventBridge provides near-real-time event routing, which is better for security monitoring.

---

## Q6: EventBridge Pipes

A developer needs to process DynamoDB Stream events: filter for items with `status: COMPLETED`, enrich them by calling an external API via API Gateway, and send the result to an SQS queue. What is the simplest EventBridge approach?

**A)** EventBridge rule on the default bus with DynamoDB as a source
**B)** EventBridge Pipe: DynamoDB Stream → filter → API Gateway enrichment → SQS target
**C)** Lambda reading DynamoDB Stream, filtering, calling API, sending to SQS
**D)** EventBridge rule triggered by DynamoDB with a Step Functions target that handles the logic

### Answer: B

**Why:** EventBridge Pipes is designed for this exact pattern: source → filter → enrich → target, all point-to-point. DynamoDB Streams is a supported Pipe source. Filtering is built-in (event pattern matching). Enrichment via API Gateway is a native Pipe feature. SQS is a supported target. No code needed.

- **A is wrong:** DynamoDB doesn't natively emit events to EventBridge's default bus. You'd need a pipe or Lambda bridge.
- **C is wrong:** Lambda works but requires writing and maintaining code for filtering, API calls, error handling, and SQS integration. Pipes does this declaratively.
- **D is wrong:** Step Functions adds complexity (state machine definition, execution role, monitoring) for what is a simple linear flow. Pipes is simpler for point-to-point.

---

## Q7: Input Transformer

A developer has an EventBridge rule that triggers a Lambda function when an S3 object is created. The Lambda only needs the bucket name and object key, but the S3 event contains 30+ fields. How should the developer minimize the data sent to Lambda?

**A)** Filter the event in the Lambda function code
**B)** Use an input transformer on the rule to extract only bucket name and key
**C)** Use a smaller S3 event notification configuration
**D)** Create a custom event bus that only stores minimal event data

### Answer: B

**Why:** Input transformers let you reshape the event before it reaches the target. You define an input path (extract variables) and an input template (construct the payload). Example: extract `$.detail.bucket.name` and `$.detail.object.key`, then send `{"bucket": "<bucketName>", "key": "<objectKey>"}` to Lambda. Less data transferred, cleaner Lambda input.

- **A is wrong:** Works but wastes bandwidth sending 30+ fields to Lambda only to discard them. The input transformer is more efficient and cleaner.
- **C is wrong:** S3 event notifications have a fixed format. You can't customize what fields they include.
- **D is wrong:** Custom event buses don't filter event fields. They're separate channels, not data transformers.

---

## Q8: Schema Registry

A developer team has 15 microservices publishing custom events to EventBridge. New developers struggle to understand what events exist and their format. What EventBridge feature should the team enable?

**A)** CloudWatch Logs for all event buses
**B)** Schema Registry with schema discovery enabled
**C)** AWS X-Ray tracing for EventBridge
**D)** EventBridge Archive with unlimited retention

### Answer: B

**Why:** Schema Registry automatically discovers and catalogs event schemas from events flowing through the bus. It creates a schema for each unique `source` + `detail-type` combination. Developers can browse schemas in the console, download code bindings (TypeScript, Python, Java), and understand event formats without reading documentation. Think of it as: an auto-generated dictionary of all news story formats.

- **A is wrong:** CloudWatch Logs would show raw event data but not organized schemas. Hard to browse and understand event formats.
- **C is wrong:** X-Ray traces request flows across services, not event schemas. It's for performance debugging, not discovery.
- **D is wrong:** Archives store events for replay, not for schema discovery. You'd have to parse raw JSON to understand formats.

---

## Q9: Rule Targets and Retries

An EventBridge rule triggers a Lambda function. The Lambda function occasionally fails due to transient errors. Events should not be lost. What should the developer configure?

**A)** Increase the Lambda function timeout to 15 minutes
**B)** Configure a retry policy on the rule (max retries + max age) and a DLQ
**C)** Configure the Lambda function's reserved concurrency to avoid throttling
**D)** Use SNS instead of EventBridge for guaranteed delivery

### Answer: B

**Why:** EventBridge rules support a retry policy (max retries up to 185, max event age up to 24 hours) and a dead-letter queue (SQS). If the Lambda fails, EventBridge retries with exponential backoff. After exhausting retries, the event goes to the DLQ for investigation. This ensures zero event loss.

- **A is wrong:** If the Lambda fails due to a transient error (not a timeout), increasing the timeout won't help. The issue is retry and recovery, not duration.
- **C is wrong:** Reserved concurrency prevents throttling but doesn't help with transient failures from downstream services.
- **D is wrong:** SNS doesn't inherently have better delivery guarantees than EventBridge. Both can lose messages without proper DLQ configuration. EventBridge actually has better retry capabilities.

---

## Q10: Scheduled Events Migration

A company uses 50 CloudWatch Events rules for scheduled tasks (cron jobs triggering Lambda functions). They want to migrate to EventBridge Scheduler for better features. Which benefits do they gain?

**A)** Lower cost for all scheduled invocations
**B)** Time zone support, one-time schedules, flexible time windows, and up to 1 million schedules
**C)** Sub-second scheduling precision
**D)** Built-in event pattern matching on scheduled events

### Answer: B

**Why:** EventBridge Scheduler offers: (1) native time zone support (no more UTC math), (2) one-time schedules (not just recurring), (3) flexible time windows (spread invocations to avoid thundering herd), and (4) up to 1 million schedules per account (vs CloudWatch Events' lower limits). It also supports DLQs for failed invocations — CloudWatch Events doesn't.

- **A is wrong:** Scheduler pricing is comparable. The migration isn't primarily about cost savings.
- **C is wrong:** Both CloudWatch Events and Scheduler have minute-level cron precision. Sub-second scheduling isn't a feature of either.
- **D is wrong:** Scheduler creates events on a schedule — it doesn't pattern-match incoming events. That's what EventBridge rules do, and those are separate from Scheduler.
