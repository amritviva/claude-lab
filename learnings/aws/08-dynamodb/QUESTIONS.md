# DynamoDB — Exam Questions

> 13 scenario-based questions mixing SAA-C03, DVA-C02, and SOA-C02 perspectives. Heavy on WCU/RCU math.

---

### Q1 (DVA) — RCU Calculation: Strongly Consistent

An application reads 80 items per second from a DynamoDB table. Each item is 6 KB. All reads are **strongly consistent**. How many RCUs are needed?

A. 80
B. 120
C. 160
D. 240

**Answer: C**

**Why C is correct:**
```
Item size = 6 KB → ceil(6/4) = 2 (each read consumes 2 RCU)
Strongly consistent: 2 x 80 = 160 RCU
```
Each RCU gives you 1 strongly consistent read of up to 4 KB. A 6 KB item needs 2 RCU per read. 80 reads/s x 2 = 160.

**Why A is wrong:** 80 assumes 1 RCU per read — only true for items <= 4 KB.
**Why B is wrong:** 120 would be the eventually consistent answer (160/2 = 80, not 120 — so this is just a distractor).
**Why D is wrong:** 240 would be if each item were > 8 KB (needing 3 RCU per read).

---

### Q2 (DVA) — WCU Calculation

An application writes 15 items per second. Each item is 3.2 KB. How many WCUs are needed?

A. 15
B. 45
C. 48
D. 60

**Answer: D**

**Why D is correct:**
```
Item size = 3.2 KB → ceil(3.2) = 4 KB (round UP to nearest 1 KB)
WCU = 4 x 15 = 60
```
Each WCU handles 1 write of up to 1 KB. A 3.2 KB item rounds up to 4 KB, costing 4 WCU per write.

**Why A is wrong:** 15 assumes 1 WCU per write — only true for items <= 1 KB.
**Why B is wrong:** 45 uses 3 WCU per write (rounding down 3.2 to 3).
**Why C is wrong:** 48 = 3.2 x 15 without rounding up.

---

### Q3 (DVA) — RCU Calculation: Eventually Consistent

Same scenario as Q1: 80 items/second, 6 KB each, but now reads are **eventually consistent**. How many RCUs?

A. 40
B. 80
C. 120
D. 160

**Answer: B**

**Why B is correct:**
```
Item size = 6 KB → ceil(6/4) = 2
Eventually consistent: 2 x 80 / 2 = 80 RCU
```
Eventually consistent reads cost half of strongly consistent. Same item size calculation, then divide by 2.

**Why A is wrong:** 40 divides by 2 twice.
**Why C is wrong:** 120 is a distractor — doesn't match any formula.
**Why D is wrong:** 160 is the strongly consistent answer (from Q1).

---

### Q4 (DVA) — Transactional Write Cost

An application uses `TransactWriteItems` to write 10 items per second. Each item is 2.5 KB. How many WCUs are needed?

A. 25
B. 30
C. 50
D. 60

**Answer: D**

**Why D is correct:**
```
Item size = 2.5 KB → ceil(2.5) = 3 KB → 3 WCU per write
Standard WCU: 3 x 10 = 30
Transactional: 30 x 2 = 60 WCU
```
Transactions cost 2x normal capacity. The item rounds up to 3 KB (3 WCU), 10 writes/s = 30, doubled for transaction = 60.

**Why A is wrong:** 25 doesn't follow any valid calculation.
**Why B is wrong:** 30 is the non-transactional answer — forgot the 2x multiplier.
**Why C is wrong:** 50 = 2.5 x 10 x 2 without rounding up.

---

### Q5 (SAA) — DAX vs ElastiCache

An application frequently reads the same DynamoDB items with microsecond latency requirements. A solutions architect also has a separate Redis-based session store. Which caching solution should be used for DynamoDB reads?

A. ElastiCache Redis for both DynamoDB caching and session store
B. DAX for DynamoDB reads and ElastiCache Redis for session store
C. DAX for both DynamoDB caching and session store
D. CloudFront for DynamoDB reads and ElastiCache for session store

**Answer: B**

**Why B is correct:** DAX is purpose-built for DynamoDB — API-compatible, microsecond latency, no code changes beyond endpoint. ElastiCache Redis is a general-purpose cache ideal for session stores. Use each tool for what it's designed for. DAX is the speed desk in the DynamoDB building lobby; ElastiCache is a general-purpose speed desk you can put anywhere.

**Why A is wrong:** ElastiCache CAN cache DynamoDB data, but requires custom caching logic in your application. DAX is transparent — same API, no code changes.

**Why C is wrong:** DAX only works with DynamoDB. It cannot be used as a general-purpose session store.

**Why D is wrong:** CloudFront is a CDN for HTTP content, not a DynamoDB cache.

---

### Q6 (SAA) — Global Tables Use Case

A company operates in the US, Europe, and Asia. They need their DynamoDB-based application to have single-digit millisecond reads in ALL regions with the ability to write from any region. What should they use?

A. DynamoDB with cross-region Read Replicas
B. DynamoDB Global Tables
C. DynamoDB with DAX in each region
D. Three separate DynamoDB tables with application-level sync

**Answer: B**

**Why B is correct:** Global Tables provide active-active multi-region replication. Write in any region, read in any region, all with DynamoDB's native single-digit millisecond latency. Like having the same building in three countries — walk into any one and everything is up to date.

**Why A is wrong:** DynamoDB doesn't have "cross-region Read Replicas" as a feature. That's an RDS concept. Streams + Lambda could replicate, but Global Tables is the native solution.

**Why C is wrong:** DAX provides microsecond reads but only caches within one region. It doesn't replicate data across regions.

**Why D is wrong:** Application-level sync is complex, error-prone, and doesn't provide the consistency guarantees of Global Tables.

---

### Q7 (DVA) — DynamoDB Streams + Lambda

A developer needs to send a welcome email whenever a new user is created in a DynamoDB table. The email should contain the user's name and email address. Which Stream view type is needed?

A. KEYS_ONLY
B. NEW_IMAGE
C. OLD_IMAGE
D. NEW_AND_OLD_IMAGES

**Answer: B**

**Why B is correct:** NEW_IMAGE gives you the complete item after the change. For a new insert, that's all the user's attributes (name, email). The Lambda function receives the full new item and can extract what it needs. Like the security camera recording who just walked in with all their details.

**Why A is wrong:** KEYS_ONLY gives you just the PK/SK — no name or email. You'd have to do an extra GetItem call.

**Why C is wrong:** OLD_IMAGE gives you the item BEFORE the change. For an INSERT, there is no old image — this would be empty.

**Why D is wrong:** NEW_AND_OLD_IMAGES works but is overkill. For inserts, OLD_IMAGE is null. You'd be paying for unnecessary data. NEW_IMAGE is sufficient and more efficient.

---

### Q8 (SOA) — Hot Partition Troubleshooting

A SysOps administrator notices that a DynamoDB table with 1000 WCU provisioned is experiencing throttling. CloudWatch shows ConsumedWriteCapacityUnits averaging only 300 WCU. What is the MOST LIKELY cause?

A. The table needs more WCU provisioned
B. The partition key has low cardinality, causing a hot partition
C. The table's auto scaling is misconfigured
D. The table has too many GSIs consuming WCU

**Answer: B**

**Why B is correct:** 300 WCU average with 1000 provisioned but still throttling = hot partition. The traffic is concentrated on one floor of the building while other floors are empty. One partition can only handle 1,000 WCU max, and if all traffic hits the same partition key, the table throttles even though total capacity is available. Adaptive capacity helps but can't fix fundamentally bad key design.

**Why A is wrong:** The table has 1000 WCU but only uses 300 average. Adding more WCU won't help if it's a hot partition — the extra capacity goes to cold partitions.

**Why C is wrong:** Auto scaling adjusts total table capacity based on utilization. It can't redistribute traffic across partitions.

**Why D is wrong:** GSIs have their own capacity settings. GSI throttling wouldn't show up as table-level throttling.

---

### Q9 (DVA) — Conditional Writes

A developer is building an inventory system where multiple Lambda functions might try to decrement the same item's `quantity` simultaneously. How should they prevent overselling (quantity going below zero)?

A. Use DynamoDB Transactions for all writes
B. Use a conditional expression: `SET quantity = quantity - 1` with `ConditionExpression: "quantity > 0"`
C. Use DAX to serialize writes
D. Enable DynamoDB Streams and roll back invalid writes

**Answer: B**

**Why B is correct:** Conditional expressions provide optimistic locking at the item level. The write only succeeds if the condition is true at the moment of execution. If quantity is already 0, the write fails with a ConditionalCheckFailedException. Like a shelf lock that only opens if there's at least one folder — preventing an empty shelf from going negative.

**Why A is wrong:** Transactions are for multi-item atomicity. For a single-item conditional update, a conditional expression is simpler and cheaper (no 2x cost).

**Why C is wrong:** DAX is a read cache — it doesn't serialize or coordinate writes.

**Why D is wrong:** Rollbacks after the fact are too late — you've already oversold. The conditional expression prevents the bad write from happening.

---

### Q10 (SAA) — TTL Use Case

A web application stores session data in DynamoDB. Sessions should expire after 24 hours. The team wants to archive expired sessions to S3 before deletion. What is the BEST approach?

A. Use a scheduled Lambda function to scan and delete expired sessions every hour
B. Enable TTL on the session table and use DynamoDB Streams + Lambda to archive to S3 before TTL deletes
C. Enable TTL on the session table — expired items are automatically sent to S3
D. Use a GSI on the TTL attribute and query for expired items

**Answer: B**

**Why B is correct:** TTL deletion generates a Stream record (marked as system delete). A Lambda function triggered by the Stream can read the old image and archive it to S3 before the item is permanently removed. Like the building janitor putting expired folders in a separate box (stream) before throwing them away, and a clerk archives the box contents to long-term storage (S3).

**Why A is wrong:** Scanning is expensive (reads every item), doesn't scale well, and has timing gaps between scans.

**Why C is wrong:** TTL does NOT automatically send items to S3. That's not a DynamoDB feature.

**Why D is wrong:** You can't create a GSI on a TTL attribute for this purpose. GSIs don't help with scheduled cleanup.

---

### Q11 (SOA) — Backup Strategy

A compliance requirement mandates that a DynamoDB table must be recoverable to any point within the last 30 days. Which feature meets this requirement?

A. On-demand backups taken every 6 hours
B. DynamoDB Streams with a consumer that logs all changes
C. Point-in-Time Recovery (PITR)
D. AWS Backup with a 30-day retention policy

**Answer: C**

**Why C is correct:** PITR provides continuous backups with 35-day retention. You can restore the table to any second within the retention window. It's CCTV for the building — rewind to any moment in the last 35 days (covers the 30-day requirement). Restores create a new table.

**Why A is wrong:** On-demand backups every 6 hours give you 6-hour recovery granularity at best — not "any point." You'd lose up to 6 hours of data.

**Why B is wrong:** Streams only retain data for 24 hours. You'd need to build a complex replay system to reconstruct 30 days of changes.

**Why D is wrong:** AWS Backup for DynamoDB uses the same PITR mechanism under the hood. While it works, the question asks which DynamoDB feature meets the requirement — PITR is the direct answer. (Note: on the real exam, if both C and D are options, read carefully whether they're asking about DynamoDB-native features vs AWS Backup.)

---

### Q12 (DVA) — Filter Expression Trap

A developer writes a Scan operation with a FilterExpression that matches only 10 items out of 100,000 in the table. Each item is 2 KB. How much read capacity is consumed?

A. RCU for 10 items (20 KB)
B. RCU for 100,000 items (200,000 KB / 200 MB)
C. RCU for 1 MB (Scan page limit), repeated until all items scanned
D. No RCU — FilterExpression eliminates items before reading

**Answer: C**

**Why C is correct:** FilterExpression is applied AFTER the data is read from the table. DynamoDB reads up to 1 MB per Scan call, applies the filter, returns matching items, then you paginate for the next 1 MB. You consume RCU for ALL items read, not just the ones returned. It's like opening every drawer on every floor, looking at the folder, and only keeping 10 — but you still spent the effort opening all drawers. With 200 MB of data, that's ~200 Scan calls at 1 MB each.

**Why A is wrong:** This would be true only if you used a Query with the right key conditions. Scan reads everything.

**Why B is wrong:** Close to right in total, but Scan is paginated at 1 MB — it doesn't consume all 200 MB in one call.

**Why D is wrong:** This is the critical trap. Filters do NOT reduce RCU consumption. They're post-read filters.

---

### Q13 (SAA) — On-Demand vs Provisioned Selection

A startup is launching a new application. They have no idea what the traffic patterns will look like. After 3 months, they expect to understand the patterns well. The CTO wants to minimize costs both now and later. What capacity mode strategy should they use?

A. Start with provisioned mode at minimum capacity, use auto scaling
B. Start with on-demand mode, switch to provisioned with auto scaling after 3 months
C. Use on-demand mode permanently for simplicity
D. Start with provisioned mode with reserved capacity for maximum savings

**Answer: B**

**Why B is correct:** On-demand mode is perfect for unknown workloads — no risk of throttling, no capacity planning needed. After 3 months, when patterns are clear, switch to provisioned with auto scaling for cost savings (provisioned is ~2.5x cheaper per request). You can switch modes once per 24 hours. It's like renting a flexible office space first, then signing a lease once you know how much space you need.

**Why A is wrong:** Provisioned at minimum capacity might throttle during unexpected traffic spikes. For a new app with unknown patterns, this risks poor user experience.

**Why C is wrong:** On-demand permanently is 2.5x more expensive than provisioned for predictable workloads. After 3 months with known patterns, this wastes money.

**Why D is wrong:** Reserved capacity requires a 1-3 year commitment. Committing before understanding traffic patterns is premature and risky.
