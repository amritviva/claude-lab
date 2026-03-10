# 17 — SQS, SNS & SES: Exam-Style Questions

---

## Q1: Decoupling Architecture

A web application directly calls a payment processing service. During peak hours, the payment service becomes overwhelmed and requests are dropped. What is the BEST way to decouple these components?

- **A)** Add an Application Load Balancer in front of the payment service
- **B)** Place an SQS queue between the web application and the payment service
- **C)** Use SNS to notify the payment service of new payments
- **D)** Increase the payment service's instance size during peak hours

**Correct Answer: B**

**Why:** SQS acts as a buffer — the post office holds letters until the worker is ready. During peak hours, messages queue up safely. The payment service processes them at its own pace, never overwhelmed. No messages are lost, even if the payment service is temporarily down. This is the fundamental decoupling pattern.

- **A is wrong:** An ALB distributes load across instances but doesn't buffer requests. If all instances are overwhelmed, requests still fail.
- **C is wrong:** SNS pushes messages immediately to subscribers. It doesn't buffer. If the payment service can't handle the push, messages fail.
- **D is wrong:** Vertical scaling is a band-aid, not a solution. You'll eventually hit instance size limits, and it doesn't protect against service downtime.

---

## Q2: Standard vs FIFO

An e-commerce platform processes financial transactions where each transaction must be processed exactly once and in the order received. Which SQS configuration should they use?

- **A)** Standard queue with deduplication logic in the consumer
- **B)** FIFO queue with message deduplication enabled
- **C)** Standard queue with long polling enabled
- **D)** FIFO queue with Standard DLQ for failed messages

**Correct Answer: B**

**Why:** The requirements are exactly-once processing AND ordering — both are FIFO features. FIFO queues guarantee exactly-once delivery (via deduplication) and strict ordering (via message group IDs). For financial transactions, you can't afford duplicates (double charges) or out-of-order processing (refund before charge).

- **A is wrong:** Building deduplication in the consumer is complex and error-prone. FIFO handles it natively. Also, Standard queues can't guarantee ordering.
- **C is wrong:** Long polling reduces empty API responses — it has nothing to do with ordering or deduplication.
- **D is wrong:** A FIFO queue's DLQ must also be FIFO. You can't pair a FIFO source with a Standard DLQ.

---

## Q3: Visibility Timeout

A Lambda function processes SQS messages but occasionally takes 5 minutes for complex records. The default visibility timeout is 30 seconds. What problem will occur and how should it be fixed?

- **A)** Messages will be deleted after 30 seconds — increase the message retention period
- **B)** Messages will become visible to other consumers after 30 seconds, causing duplicate processing — increase the visibility timeout to at least 6 minutes
- **C)** Lambda will timeout after 30 seconds — increase the Lambda timeout
- **D)** The queue will throttle after 30 seconds — increase the queue throughput limit

**Correct Answer: B**

**Why:** When Lambda receives a message, it becomes invisible to other consumers for the visibility timeout period (30s default). If Lambda is still processing after 30 seconds, the message reappears in the queue and ANOTHER Lambda invocation picks it up — duplicate processing. The fix: set visibility timeout to at least 6x the expected processing time (6 minutes = 360 seconds). It's like a mail worker keeping a letter on their desk — if they don't finish within the processing window, the post office assumes they lost it and gives a copy to another worker.

- **A is wrong:** Retention period is how long a message STAYS in the queue (max 14 days). It's about storage, not processing windows.
- **C is wrong:** Lambda timeout and visibility timeout are different settings. Even if Lambda times out at 5 minutes, if the visibility timeout is shorter, duplicates still occur. You need to fix BOTH: Lambda timeout and visibility timeout should be aligned.
- **D is wrong:** SQS Standard has nearly unlimited throughput — throttling isn't the issue here.

---

## Q4: SNS + SQS Fan-Out

A company needs to process new order events in three ways simultaneously: update inventory, send confirmation emails, and log to analytics. Each processor works at different speeds. What architecture should they use?

- **A)** One SQS queue with three consumers reading from it
- **B)** SNS topic that fans out to three SQS queues, each with its own consumer
- **C)** Three separate Lambda functions all triggered by the same API Gateway endpoint
- **D)** EventBridge rule that routes to three Lambda functions

**Correct Answer: B**

**Why:** SNS→SQS fan-out is THE pattern for this. The PA system announces "new order" and three separate post office queues receive the message. Each processor works independently at its own speed — if email sending is slow, inventory updates aren't delayed. Each queue has its own DLQ for error handling. This is the most tested messaging pattern in all three AWS exams.

- **A is wrong:** With one SQS queue and three consumers, each message goes to only ONE consumer (SQS is point-to-point). Consumer 1 gets message A, Consumer 2 gets message B. They wouldn't all process every message.
- **C is wrong:** Three Lambda functions at the API Gateway creates tight coupling. If one fails, the API response might fail. No buffering, no retry isolation.
- **D is wrong:** EventBridge→Lambda works but lacks the buffering of SQS queues. If a Lambda fails, there's no queue to hold the message. With SQS, failed messages stay in the queue (or go to DLQ) for retry.

---

## Q5: Dead Letter Queue

An SQS queue has a DLQ configured with maxReceiveCount=3. A message is received by a consumer, processing fails, and the message returns to the queue. This happens two more times. What happens next?

- **A)** The message stays in the source queue forever until manually deleted
- **B)** The message is moved to the DLQ after the third failed attempt
- **C)** The message is automatically deleted after the third failed attempt
- **D)** The message is moved to the DLQ after the fourth failed attempt

**Correct Answer: B**

**Why:** maxReceiveCount=3 means after 3 receive attempts (all failed), the message is moved to the DLQ. The message was received 3 times (and returned to the queue 3 times due to visibility timeout expiring or explicit failure). On the 3rd return, SQS moves it to the DLQ instead of making it visible again. It's like a letter that's been attempted 3 times — the post office gives up and puts it in the undeliverable pile.

- **A is wrong:** Without a DLQ, the message would stay in the queue and keep being retried (wasteful). But WITH a DLQ configured, it's moved after maxReceiveCount failures.
- **C is wrong:** SQS never automatically deletes messages based on processing failures. It either keeps retrying (no DLQ) or moves to DLQ.
- **D is wrong:** maxReceiveCount=3 means 3 receives total, not 3 retries after the first attempt. The message moves after 3 receives, not 4.

---

## Q6: Lambda Partial Batch Failure

A Lambda function processes a batch of 10 SQS messages. 8 succeed and 2 fail. By default, what happens?

- **A)** The 8 successful messages are deleted, and the 2 failed messages return to the queue
- **B)** All 10 messages return to the queue and are reprocessed (including the 8 that already succeeded)
- **C)** All 10 messages are deleted, and the 2 failures are logged to CloudWatch
- **D)** Lambda automatically retries only the 2 failed messages

**Correct Answer: B**

**Why:** By DEFAULT, Lambda treats the entire batch as a unit. If any message in the batch fails, the ENTIRE batch is considered failed and all 10 messages return to the queue. This means the 8 already-processed messages get processed AGAIN (duplicate processing). To fix this, enable `ReportBatchItemFailures` in the event source mapping — then Lambda only returns the 2 failed messages to the queue.

- **A is wrong:** This is what happens WHEN you enable `ReportBatchItemFailures`, not the default behavior. The default is all-or-nothing.
- **C is wrong:** Lambda never deletes messages from a failed batch. Failure means all messages go back to the queue.
- **D is wrong:** Lambda doesn't automatically retry individual messages. It processes batches. The queue handles retries by making the messages visible again.

---

## Q7: SNS Message Filtering

An SNS topic receives order events from multiple regions. The analytics SQS queue subscriber only wants orders from ap-southeast-2. The payment SQS queue wants ALL orders. How should this be configured?

- **A)** Create two separate SNS topics — one for ap-southeast-2 and one for all regions
- **B)** Apply a subscription filter policy on the analytics queue's subscription to only receive ap-southeast-2 messages. The payment queue subscription has no filter (receives all).
- **C)** Configure the SNS topic to only send ap-southeast-2 messages
- **D)** Have the analytics Lambda function discard messages from other regions after receiving them

**Correct Answer: B**

**Why:** SNS message filtering lets each subscriber define which messages it wants. The filter policy is on the SUBSCRIPTION, not the topic. The analytics subscription gets a filter `{"region": ["ap-southeast-2"]}`. The payment subscription has no filter and receives everything. This way, the publisher doesn't need to know about subscriber preferences. It's like subscribing to a PA channel but only tuning in when they announce your region.

- **A is wrong:** Multiple topics add complexity and require the publisher to route messages to the correct topic. Filtering is simpler and more flexible.
- **C is wrong:** Topic-level filtering would affect ALL subscribers. The payment queue needs all messages, so you can't filter at the topic level.
- **D is wrong:** This wastes resources — Lambda would be invoked for every message just to discard most of them. SNS filtering prevents unwanted messages from being delivered at all.

---

## Q8: Long Polling vs Short Polling

A team notices their SQS bill is high due to a large number of ReceiveMessage API calls, most of which return empty. What should they do?

- **A)** Switch to SNS instead of SQS to avoid polling
- **B)** Enable long polling by setting WaitTimeSeconds to 20 on the ReceiveMessage calls
- **C)** Increase the message retention period so messages are available longer
- **D)** Use a FIFO queue instead of a Standard queue

**Correct Answer: B**

**Why:** Short polling (default) returns immediately even if no messages are available — causing many empty API calls that still cost money. Long polling makes the consumer WAIT at the counter for up to 20 seconds for a message to arrive. This drastically reduces the number of empty responses and API calls. Set `WaitTimeSeconds` = 20 (max) for best results. It's like waiting patiently at the post office counter vs walking in and out every second asking "any mail?"

- **A is wrong:** SNS serves a different purpose (pub/sub broadcasting). If the architecture needs queuing, you need SQS.
- **C is wrong:** Retention period is how long messages STAY in the queue. It doesn't reduce the number of API calls — the consumer still polls at the same frequency.
- **D is wrong:** FIFO vs Standard doesn't affect polling behavior. Both queue types support long polling.

---

## Q9: Message Size Limit

An application needs to send 5 MB images through SQS for processing. What approach should they use?

- **A)** Split the image into 20 chunks of 256 KB each and send them as separate messages
- **B)** Use the SQS Extended Client Library to store the image in S3, and send a reference through SQS
- **C)** Increase the SQS message size limit to 5 MB via the queue settings
- **D)** Base64 encode the image to reduce its size below 256 KB

**Correct Answer: B**

**Why:** SQS has a hard limit of 256 KB per message. The Extended Client Library (available for Java, Python, etc.) automatically stores the large payload in S3 and sends a pointer/reference through SQS. The consumer uses the same library to transparently fetch the payload from S3. It's like the post office saying "your package is too big for a mailbox — we'll store it in the warehouse and give you a claim ticket."

- **A is wrong:** Splitting creates ordering, reassembly, and error handling complexity. What if chunk 15 of 20 goes to the DLQ?
- **C is wrong:** 256 KB is a hard limit — you cannot increase it. There's no queue setting to change this.
- **D is wrong:** Base64 encoding INCREASES size by ~33%, not decreases it. A 5 MB image would become ~6.7 MB.

---

## Q10: FIFO High-Throughput Mode

A FIFO queue processes 300 messages per second, but the team needs to handle 50,000 messages per second while maintaining order within customer groups. What should they do?

- **A)** Switch to a Standard queue and implement ordering in the consumer application
- **B)** Enable FIFO high-throughput mode and use message group IDs per customer
- **C)** Create 170 FIFO queues and distribute messages across them
- **D)** Use Kinesis Data Streams instead, which supports higher throughput with ordering

**Correct Answer: B**

**Why:** FIFO high-throughput mode increases throughput from 300 msg/s to up to 70,000 msg/s. Combined with message group IDs (one per customer), ordering is maintained WITHIN each customer while processing is parallelized ACROSS customers. This is exactly what FIFO queues were designed for — ordered processing per group, massive parallelism across groups.

- **A is wrong:** Building ordering logic in the consumer defeats the purpose of FIFO and is complex to get right. FIFO high-throughput mode solves this natively.
- **C is wrong:** Managing 170 queues is an operational nightmare. Routing logic, monitoring, DLQs per queue... FIFO high-throughput is a single setting change.
- **D is wrong:** While Kinesis supports high throughput with ordering, it's a different paradigm (data streaming, not message queuing). SQS FIFO with high-throughput mode meets the requirement without changing the architecture.

---

## Q11: SQS Scaling with Auto Scaling

A fleet of EC2 instances processes messages from an SQS queue. During peak hours, messages pile up and processing falls behind. What metric should be used to trigger Auto Scaling?

- **A)** CPUUtilization of the EC2 instances
- **B)** ApproximateNumberOfMessagesVisible (queue depth)
- **C)** NumberOfMessagesSent per minute
- **D)** ApproximateAgeOfOldestMessage

**Correct Answer: B**

**Why:** `ApproximateNumberOfMessagesVisible` shows how many messages are waiting in the queue. When this number grows, you need more workers. This is a custom metric-based scaling policy: "When queue depth > 1000, add instances." The best approach is actually `backlog per instance` = queue depth / number of instances — scale when each instance has too many messages to handle.

- **A is wrong:** CPU might be low even when the queue is deep (if instances are waiting on I/O, not CPU-bound). Queue depth is a more direct indicator of work backlog.
- **C is wrong:** Messages sent measures the INPUT rate, not the BACKLOG. A high send rate doesn't necessarily mean processing is behind.
- **D is wrong:** `ApproximateAgeOfOldestMessage` is great for alerting on processing DELAYS but not ideal for scaling decisions. A message could be old because it's the only one waiting — you don't need more instances for one message.

---

## Q12: SNS FIFO Limitations

A developer creates an SNS FIFO topic and tries to add an SQS Standard queue as a subscriber. What happens?

- **A)** The subscription succeeds and messages are delivered in order to the Standard queue
- **B)** The subscription fails — SNS FIFO topics can only have SQS FIFO queue subscribers
- **C)** The subscription succeeds but ordering is not guaranteed in the Standard queue
- **D)** The subscription succeeds but deduplication is disabled for the Standard queue

**Correct Answer: B**

**Why:** SNS FIFO topics can ONLY fan out to SQS FIFO queues. You can't mix FIFO and Standard. If the PA system guarantees ordered announcements, every listener must be capable of maintaining that order. A Standard queue would break the ordering guarantee, so SNS doesn't allow it. FIFO→FIFO only.

- **A is wrong:** Standard queues don't maintain strict ordering. Allowing this would break FIFO's guarantee.
- **C is wrong:** The subscription doesn't succeed at all. SNS validates the queue type when creating the subscription.
- **D is wrong:** Same as C — the subscription is rejected outright.
