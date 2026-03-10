# Kinesis — Exam Practice Questions

---

## Q1: Kinesis vs SQS

A company processes online orders. Each order must be processed exactly once and in the order received. The system processes about 100 orders per minute. If processing fails, the order should be retried. Which service should they use?

**A)** Kinesis Data Streams
**B)** SQS Standard Queue
**C)** SQS FIFO Queue
**D)** Kinesis Data Firehose

### Answer: C

**Why:** The requirements are: exactly-once processing, strict ordering, moderate volume (100/min), and retry on failure. SQS FIFO provides exactly-once delivery and strict ordering. This is a messaging pattern (discrete orders), not a streaming pattern. Kinesis provides ordering within a shard but guarantees at-least-once (not exactly-once) and is overkill for 100 messages/minute.

- **A is wrong:** Kinesis is for high-throughput streaming, not discrete message processing. It guarantees at-least-once, not exactly-once. Ordering is per-shard only.
- **B is wrong:** SQS Standard doesn't guarantee ordering and provides at-least-once delivery, not exactly-once.
- **D is wrong:** Firehose delivers data to destinations (S3, Redshift) — it doesn't process individual orders or support retry logic.

---

## Q2: Data Streams vs Firehose

A company needs to collect application logs from 500 servers and store them in S3 for analysis. They want the LEAST operational overhead and can tolerate a 60-second delay. Which Kinesis service should they use?

**A)** Kinesis Data Streams with a Lambda consumer writing to S3
**B)** Kinesis Data Firehose with S3 as the destination
**C)** Kinesis Data Streams with KCL application on EC2
**D)** Kinesis Data Analytics writing to S3

### Answer: B

**Why:** Firehose is the delivery truck — fully managed, auto-scales, delivers directly to S3. No shards to manage, no consumers to build, no infrastructure. A 60-second buffer is well within Firehose's near-real-time capability. "Least operational overhead" for S3 delivery = Firehose, every time.

- **A is wrong:** Works but high operational overhead — you manage shards, Lambda code, error handling, and S3 write logic.
- **C is wrong:** Maximum operational overhead — KCL app on EC2 means managing EC2 instances, KCL code, DynamoDB checkpoint table, and S3 writes.
- **D is wrong:** Analytics is for running SQL on streaming data, not for simple log delivery to S3. Overkill and wrong tool.

---

## Q3: Hot Shard / Partition Key

A developer uses Kinesis Data Streams with 4 shards. They use the current date (e.g., "2026-03-11") as the partition key. During peak hours, they get `ProvisionedThroughputExceededException`. What is the root cause?

**A)** The stream needs more shards
**B)** All records go to the same shard because the partition key has low cardinality
**C)** The consumer is reading too slowly
**D)** The record size exceeds 1 MB

### Answer: B

**Why:** Using the date as partition key means ALL records in a single day hash to the SAME shard. 4 shards are useless if 100% of traffic hits one shard. The partition key is the sorting hat — a low-cardinality key (one value per day) creates a "hot shard." The fix: use a high-cardinality key like `user_id`, `device_id`, or append a random suffix.

- **A is wrong:** Adding shards doesn't help if the partition key still routes everything to one shard. The new shards would be idle.
- **C is wrong:** `ProvisionedThroughputExceededException` is a WRITE error (producer side). Slow consumers would show high `IteratorAgeMilliseconds`, not throughput exceptions.
- **D is wrong:** Oversized records would get a different error. The throughput exception means too many records/bytes per second on one shard.

---

## Q4: Enhanced Fan-Out

A Kinesis Data Stream has 10 shards and serves 5 different consumer applications. Each consumer needs to read ALL data with minimal latency. Consumers are experiencing high `ReadProvisionedThroughputExceeded` errors. What should the architect do?

**A)** Double the number of shards to 20
**B)** Register each consumer as an enhanced fan-out consumer
**C)** Increase the stream's retention period
**D)** Use Kinesis Data Firehose instead

### Answer: B

**Why:** Without enhanced fan-out, all 5 consumers share the 2 MB/s read capacity per shard. That's ~0.4 MB/s per consumer per shard — too little. Enhanced fan-out gives each registered consumer a **dedicated** 2 MB/s per shard via HTTP/2 push. 5 consumers × 2 MB/s = 10 MB/s per shard total read capacity.

- **A is wrong:** Doubling shards doubles total throughput but consumers still SHARE the per-shard capacity. 5 consumers sharing 2 MB/s per shard = same problem.
- **C is wrong:** Retention period controls how long data is kept, not read throughput. Irrelevant to the error.
- **D is wrong:** Firehose delivers to specific destinations — it doesn't support multiple custom consumer applications reading the same data in real-time.

---

## Q5: Lambda Error Handling with Kinesis

A Lambda function processes records from a Kinesis Data Stream. One poisonous record causes the Lambda to fail. The shard is now stuck — no new records are being processed. What is the BEST way to handle this?

**A)** Increase the Lambda timeout to 15 minutes
**B)** Configure bisect batch on function error, maximum retry attempts, and an on-failure destination
**C)** Delete the Kinesis stream and recreate it
**D)** Manually remove the bad record using the AWS CLI

### Answer: B

**Why:** When Lambda fails on a Kinesis batch, it retries the SAME batch indefinitely, blocking the shard. The solution is: (1) **Bisect batch on error** — splits the batch in half to isolate the bad record, (2) **Maximum retry attempts** — stops retrying after N attempts, (3) **On-failure destination** — sends the failed record to SQS/SNS for investigation. This unblocks the shard while preserving the poisonous record for debugging.

- **A is wrong:** The Lambda isn't timing out — it's failing on a bad record. More time doesn't fix bad data.
- **C is wrong:** Destructive and unnecessary. You lose ALL data in the stream. The poisonous record problem would recur with new bad data.
- **D is wrong:** You can't delete individual records from Kinesis. Records are immutable and expire based on retention period.

---

## Q6: Firehose Transformation

A company uses Kinesis Data Firehose to deliver JSON logs to S3. They want to convert the data to Parquet format for cost-effective Athena queries and add a field to each record. Which approach requires the LEAST effort?

**A)** Use a Firehose Lambda transformation to add the field and enable record format conversion to Parquet
**B)** Write a custom KCL application to transform and convert data before writing to S3
**C)** Use Kinesis Data Analytics to transform the data, then deliver via Firehose
**D)** Process data after delivery using an S3 event-triggered Lambda

### Answer: A

**Why:** Firehose natively supports both: (1) Lambda transformations — add/modify/filter records inline, and (2) Record format conversion — convert JSON to Parquet/ORC using a Glue Data Catalog table schema. Both are built-in Firehose features, configured in the delivery stream settings.

- **B is wrong:** KCL application on EC2 is maximum effort — manage infrastructure, write transformation code, handle S3 writes, manage Parquet serialization.
- **C is wrong:** Analytics adds unnecessary complexity and cost. Firehose can do the transformation and conversion natively.
- **D is wrong:** Post-delivery processing adds latency, requires another Lambda, and means storing JSON temporarily in S3 before converting. More moving parts.

---

## Q7: KCL and Scaling

A Kinesis Data Stream has 6 shards. A KCL application runs on 4 EC2 instances. The team adds 2 more EC2 instances (6 total). How will the KCL distribute the work?

**A)** All 6 instances will each process 1 shard
**B)** The original 4 instances keep their shards; the 2 new instances remain idle
**C)** KCL will automatically rebalance — each instance processes 1 shard
**D)** The application will throw an error because you can't have more instances than shards

### Answer: C

**Why:** KCL automatically rebalances when instances join or leave. With 6 shards and 6 instances, each instance gets exactly 1 shard. KCL uses a DynamoDB lease table to coordinate — when new instances appear, they claim leases from existing instances. The key rule: max KCL instances = number of shards. Having exactly 6 = 1:1 mapping.

- **A is correct conceptually** but C is more precise because it emphasizes the automatic rebalancing behavior.
- **B is wrong:** KCL doesn't stick to the original assignment — it dynamically rebalances leases.
- **D is wrong:** Having instances equal to shards is fine. An error would only occur if... actually, KCL doesn't error with more instances — extra instances just stay idle with no leases.

### Corrected: A and C are both valid. Answer: C (emphasizes the rebalancing mechanism)

---

## Q8: Monitoring Kinesis

A SysOps admin notices that the `IteratorAgeMilliseconds` metric for a Kinesis Data Stream is steadily increasing. What does this indicate and what should they do?

**A)** Producers are sending too much data — reduce the production rate
**B)** Consumers are falling behind — add more shards or optimize consumer processing
**C)** The stream's retention period is about to expire — increase retention
**D)** The stream needs encryption enabled

### Answer: B

**Why:** `IteratorAgeMilliseconds` measures how far behind the consumer is from the latest record in the stream. Increasing age = consumers can't keep up with the production rate. The river analogy: boats (consumers) are falling further behind the current flow. Solutions: optimize consumer code, add shards (more parallel processing), or use enhanced fan-out for dedicated throughput.

- **A is wrong:** The metric measures consumer lag, not producer throughput. Producers might be fine — it's the consumers that are slow.
- **C is wrong:** IteratorAge has nothing to do with retention period. It measures real-time lag, not historical data age.
- **D is wrong:** Encryption doesn't affect processing speed or consumer lag.

---

## Q9: Firehose vs Data Streams Cost

A startup processes 10 GB of clickstream data per day. They need to store it in S3 and don't need real-time processing — a 5-minute delay is acceptable. They want to minimize cost. Which approach is MOST cost-effective?

**A)** Kinesis Data Streams with 10 shards and a Lambda consumer writing to S3
**B)** Kinesis Data Firehose delivering directly to S3
**C)** Kinesis Data Streams with 2 shards and a KCL application on EC2
**D)** Direct PUT to S3 from each application server

### Answer: B

**Why:** Firehose charges per GB ingested (~$0.029/GB in us-east-1). No shard costs, no compute costs, no code to maintain. For 10 GB/day = ~$0.29/day. Data Streams charges per shard-hour ($0.015/shard-hour × 24 hours × 10 shards = $3.60/day) PLUS per PUT payload. Since real-time isn't needed and a 5-minute delay is fine, Firehose is cheaper and simpler.

- **A is wrong:** 10 shards at $0.015/shard-hour = $3.60/day in shard costs alone, plus Lambda costs. 12x more expensive than Firehose.
- **C is wrong:** EC2 instance costs + shard costs + KCL DynamoDB table costs. Most expensive option.
- **D is wrong:** Sounds simple but requires each server to handle batching, retries, S3 multipart uploads, and failure handling. Firehose does all of this for you.

---

## Q10: Data Streams Retention

A financial services company uses Kinesis Data Streams for trade processing. Regulations require them to be able to replay the last 30 days of trades for audit purposes. How should they configure the stream?

**A)** Set stream retention to 30 days (720 hours)
**B)** Default 24-hour retention is sufficient — use CloudWatch Logs for audit
**C)** Use Firehose to deliver to S3 and replay from S3 when needed
**D)** Set stream retention to 365 days for maximum compliance coverage

### Answer: A

**Why:** Kinesis Data Streams supports retention from 24 hours (default) up to 365 days. Setting it to 30 days allows direct replay from the stream for the required audit window. Extended retention (>24 hours) costs extra ($0.023 per shard-hour for 7+ days) but provides native replay capability.

- **B is wrong:** 24 hours is far too short for a 30-day audit requirement. CloudWatch Logs is for log data, not stream replay.
- **C is wrong:** This works architecturally (Firehose → S3 → replay) but doesn't provide native Kinesis stream replay. If the question asks about stream replay, you need extended retention. However, in practice, C is a valid and cheaper pattern — but the exam wants you to know about extended retention.
- **D is wrong:** 365 days is valid but unnecessarily expensive. The requirement is 30 days — don't over-provision. Extended retention pricing scales with duration.
