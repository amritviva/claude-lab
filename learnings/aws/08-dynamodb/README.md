# DynamoDB — The Building with Floors, Rooms, and Shelves

> **In the AWS Country, DynamoDB is a massive building.** Each floor is a partition, each room is a partition key value, each shelf is a sort key, and each folder on the shelf is an item. No janitor needed — AWS handles everything.

---

## ELI10

Imagine a giant building with hundreds of floors. When you want to store a folder, you tell the elevator your name and it takes you to your floor (that's the partition key — it decides which floor). On your floor, folders are arranged on shelves in order (that's the sort key). You can grab one folder, or scan an entire shelf. The building never closes, never runs out of space, and you never have to fix anything. DynamoDB is that building.

---

## Existing Deep Dives

Before reading this doc, check Amrit's existing DynamoDB walkthroughs:
- **`WALK-LIKE-DYNAMODB.md`** — Mental model: walk through the building as the query engine
- **`VIVA-WALK-THROUGH-DYNAMO.md`** — Hands-on with real Viva data (Members, Locations, Contracts)

**This doc focuses on exam-specific topics NOT covered in those files:** Streams, DAX, Global Tables, TTL, Transactions, Capacity, Backups, and the WCU/RCU math the exam loves.

---

## The Concept

### Quick Analogy Refresher

| Building Analogy | DynamoDB Concept |
|---|---|
| Building | Table |
| Floor | Physical Partition |
| Room (PK value) | Partition Key value |
| Shelf order | Sort Key |
| Folder | Item (max 400 KB) |
| Folder contents | Attributes |
| Building directory (GSI) | Global Secondary Index |
| Floor directory (LSI) | Local Secondary Index |

---

### DynamoDB Streams: Security Cameras

Streams record every change (insert, modify, delete) to your table in order. Like security cameras recording who enters, leaves, and moves things in the building.

```
┌─────────────────┐       ┌──────────────────────┐
│   DynamoDB      │       │   DynamoDB Stream     │
│   Table         │──────▶│   (24-hour log)       │
│                 │       │                        │
│  INSERT item    │       │  ┌─ Record: INSERT ──┐│
│  UPDATE item    │       │  │  Keys only         ││
│  DELETE item    │       │  │  New image          ││
│                 │       │  │  Old image          ││
│                 │       │  │  New + Old image    ││
│                 │       │  └────────────────────┘│
└─────────────────┘       └───────────┬────────────┘
                                      │
                          ┌───────────┼───────────┐
                          ▼           ▼           ▼
                      Lambda      Kinesis     Application
                     (trigger)    (KCL)       (consumer)
```

**Stream View Types (what the camera records):**
| View Type | What's Recorded |
|---|---|
| `KEYS_ONLY` | Just the partition key and sort key |
| `NEW_IMAGE` | Entire item after the change |
| `OLD_IMAGE` | Entire item before the change |
| `NEW_AND_OLD_IMAGES` | Both before and after (most detailed) |

**Key facts:**
- Records retained for **24 hours**
- Ordered by time within each partition key
- Commonly triggers Lambda functions (event source mapping)
- Use cases: replication, audit trail, materialized views, analytics pipeline
- **Kinesis Data Streams for DynamoDB** = alternative with longer retention (up to 1 year) and more consumers

---

### DAX: Speed Cache in Front of the Building

DynamoDB Accelerator (DAX) is a fully managed in-memory cache that sits in front of DynamoDB. Like having a speed desk in the building lobby — if the answer is cached there, you don't even need to take the elevator.

```
┌────────────┐     ┌───────────────┐     ┌──────────────┐
│ Application│────▶│   DAX Cluster │────▶│  DynamoDB    │
│            │     │  (in-memory)  │     │  Table        │
│            │     │               │     │              │
│ GetItem()  │     │ Hit? Return   │     │              │
│            │     │ Miss? Query   │────▶│              │
│            │     │ DynamoDB      │     │              │
└────────────┘     └───────────────┘     └──────────────┘
                   Microseconds            Milliseconds
```

**Key facts:**
- **Microsecond** read latency (vs single-digit millisecond for DynamoDB)
- API-compatible — just change the endpoint, same code
- Supports **eventually consistent reads only** (not strongly consistent)
- Write-through cache: writes go to DynamoDB first, then cache updates
- **Item cache** (individual GetItem/PutItem) + **Query cache** (query results)
- Multi-AZ (minimum 3 nodes recommended for production)
- Must be in the same VPC as your application
- NOT suitable for: write-heavy workloads, strongly consistent reads

---

### Global Tables: Same Building in Multiple Countries

Global Tables replicate your DynamoDB table across multiple AWS regions. Like having the exact same building in Sydney, London, and New York — write in any of them, and the change appears everywhere.

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  us-east-1   │◄───▶│  eu-west-1   │◄───▶│ ap-southeast-2│
│  (Table)     │     │  (Table)     │     │  (Table)      │
│              │     │              │     │               │
│  Read/Write  │     │  Read/Write  │     │  Read/Write   │
└──────────────┘     └──────────────┘     └───────────────┘
        ▲                   ▲                    ▲
        └───── Active-Active Multi-Region ───────┘
              (async replication, < 1 second)
```

**Key facts:**
- **Active-active** — read AND write in any region
- Replication typically **under 1 second**
- Requires DynamoDB Streams enabled (NEW_AND_OLD_IMAGES)
- Last writer wins (conflict resolution)
- Must use on-demand capacity OR have auto scaling enabled
- Table must be empty when you add a new region
- Supports up to 5 regions (exam may say unlimited — check question context)

---

### TTL: Expiry Date on Folders

Time to Live automatically deletes items after a specified timestamp. Like putting an expiry date sticker on a folder — when the date passes, the janitor throws it out.

```
Item: { PK: "SESSION#abc", SK: "DATA", ttl: 1735689600, ... }
                                              │
                                    Unix timestamp (epoch)
                                    When this moment passes,
                                    DynamoDB deletes the item
                                    (within 48 hours — not instant!)
```

**Key facts:**
- TTL attribute must be a **Number** type containing a **Unix epoch timestamp**
- Deletion is background process — can take **up to 48 hours** after expiry
- Expired items still appear in queries until actually deleted (filter them!)
- Deleted items appear in Streams (so you can process them)
- No extra cost — free deletion
- Use cases: session data, temporary tokens, logs, cache entries

---

### Transactions: All-or-Nothing Operations

DynamoDB Transactions let you group multiple reads/writes that either ALL succeed or ALL fail. Like moving a folder from one room to another — you need to remove it from room A AND add it to room B. If either fails, neither happens.

**Two APIs:**
- `TransactWriteItems` — up to 100 items (or 4 MB)
- `TransactGetItems` — up to 100 items (or 4 MB)

**Key facts:**
- ACID transactions across multiple items and tables
- **2x the cost** — transactions consume 2x WCU/RCU (prepare + commit)
- Idempotent with client token
- Use cases: financial transfers, inventory management, user registration (create user + create profile atomically)

---

### Capacity Modes: On-Demand vs Provisioned

**On-Demand Mode (Pay-per-request)**
- No capacity planning needed
- Pay per read/write request
- Scales instantly to any traffic level
- 2.5x more expensive per request than provisioned
- Best for: unpredictable traffic, new tables, spiky workloads

**Provisioned Mode (Pre-set capacity)**
- You specify RCU and WCU
- Cheaper per request if traffic is predictable
- Can use Auto Scaling to adjust automatically
- Can purchase Reserved Capacity for additional savings
- Best for: predictable traffic, cost optimization

**You can switch between modes once every 24 hours.**

---

### WCU/RCU Calculations — Exam Favorite!

This is bread and butter for all three exams. Memorize the formulas.

**Write Capacity Unit (WCU):**
- 1 WCU = 1 write per second for an item up to **1 KB**
- Item > 1 KB? Round UP to nearest KB

```
Formula: WCU = (item size in KB, rounded up) x (writes per second)

Example: 10 writes/second, item size = 2.5 KB
WCU = 3 (round 2.5 up to 3) x 10 = 30 WCU
```

**Transactional writes: multiply by 2**
```
Same example with transactions: 30 x 2 = 60 WCU
```

**Read Capacity Unit (RCU):**
- 1 RCU = 1 **strongly consistent** read per second for an item up to **4 KB**
- 1 RCU = 2 **eventually consistent** reads per second for an item up to **4 KB**
- Item > 4 KB? Round UP to nearest 4 KB

```
Strongly Consistent:
RCU = (item size / 4 KB, rounded up) x (reads per second)

Eventually Consistent:
RCU = (item size / 4 KB, rounded up) x (reads per second) / 2

Example: 20 reads/second, item size = 6 KB, eventually consistent
RCU = ceil(6/4) x 20 / 2 = 2 x 20 / 2 = 20 RCU

Strongly consistent same scenario:
RCU = ceil(6/4) x 20 = 2 x 20 = 40 RCU
```

**Transactional reads: multiply by 2**
```
Strongly consistent transactional: 40 x 2 = 80 RCU
```

**Quick reference table:**

| Operation | Unit Size | Consistency | Formula |
|---|---|---|---|
| Write | 1 KB per WCU | N/A | ceil(itemKB) x writes/s |
| Transactional Write | 1 KB per WCU | N/A | ceil(itemKB) x writes/s x 2 |
| Read (strong) | 4 KB per RCU | Strong | ceil(itemKB/4) x reads/s |
| Read (eventual) | 4 KB per RCU | Eventual | ceil(itemKB/4) x reads/s / 2 |
| Transactional Read | 4 KB per RCU | Strong | ceil(itemKB/4) x reads/s x 2 |

---

### Backups

**On-Demand Backup:**
- Full table backup at any time
- No impact on performance
- Retained until you delete it
- Can restore to a new table (same or different region)

**Point-in-Time Recovery (PITR):**
- Continuous backups with **35-day** retention
- Restore to any second within the 35-day window
- Must be explicitly enabled (not on by default)
- Restores to a new table
- Like CCTV for the building — rewind to any moment in the last 35 days

---

### Partition Key Design (Exam Traps)

**Hot partition** = one floor getting all the traffic while others sit empty.

**Bad partition keys:**
- Date (all today's data hits one partition)
- Status (if 90% of items are "ACTIVE")
- Boolean values

**Good partition keys:**
- User ID (high cardinality, even distribution)
- Device ID
- Composite keys (e.g., `TENANT#<id>`)

**Adaptive Capacity:** DynamoDB automatically redistributes throughput to hot partitions (but can't fix fundamentally bad key design).

---

### Batch Operations

| API | Max Items | Notes |
|---|---|---|
| `BatchWriteItem` | 25 items (or 16 MB) | Put + Delete (no Update) |
| `BatchGetItem` | 100 items (or 16 MB) | Reads across multiple tables |

- Batch operations are NOT transactions — individual items can fail
- Failed items returned in `UnprocessedItems` / `UnprocessedKeys`
- Use exponential backoff for retries

---

## Architecture Diagram: Full DynamoDB Ecosystem

```
┌──────────────────────────────────────────────────────────────┐
│                    APPLICATION LAYER                          │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │ Lambda  │  │   EC2   │  │   ECS   │  │ AppSync │        │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘        │
└───────┼─────────────┼───────────┼─────────────┼──────────────┘
        │             │           │             │
        ▼             ▼           ▼             ▼
┌──────────────────────────────────────────────────────────────┐
│                     DAX (optional cache)                      │
│                     Microsecond reads                         │
└──────────────────────────┬───────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│                    DynamoDB TABLE                             │
│  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐            │
│  │ Part.1 │  │ Part.2 │  │ Part.3 │  │ Part.N │            │
│  │(Floor) │  │(Floor) │  │(Floor) │  │(Floor) │            │
│  └────────┘  └────────┘  └────────┘  └────────┘            │
│                                                              │
│  GSI: Building Directory    LSI: Floor Directory             │
│  (any PK, any SK)          (same PK, different SK)           │
│  (eventual consistent)     (strong or eventual)              │
│  (own RCU/WCU)            (shares table's RCU/WCU)          │
└──────────────────────────┬───────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│                    DynamoDB Streams                           │
│                    (24-hour change log)                       │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                   │
│  │  Lambda  │  │ Kinesis  │  │ Analytics│                   │
│  │ Trigger  │  │ Adapter  │  │ Pipeline │                   │
│  └──────────┘  └──────────┘  └──────────┘                   │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│              Global Table (Multi-Region)                      │
│  us-east-1 ◄──────▶ eu-west-1 ◄──────▶ ap-southeast-2      │
│  (active)            (active)            (active)            │
└──────────────────────────────────────────────────────────────┘
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- On-Demand vs Provisioned (when to use each)
- DAX vs ElastiCache (DAX = DynamoDB only, ElastiCache = general)
- Global Tables for multi-region active-active
- DynamoDB Streams + Lambda for event-driven architecture
- WCU/RCU calculations
- GSI vs LSI design tradeoffs
- TTL for session/temporary data

### DVA-C02 (Developer)
- WCU/RCU calculations (heavy on this exam)
- Batch operations and error handling (UnprocessedItems)
- Transactions (TransactWriteItems/TransactGetItems)
- DynamoDB Streams + Lambda event source mapping
- DAX integration in code (SDK change)
- Conditional writes (optimistic locking with version number)
- ProjectionExpression, FilterExpression, KeyConditionExpression

### SOA-C02 (SysOps)
- Auto Scaling configuration for provisioned tables
- CloudWatch metrics: ConsumedReadCapacityUnits, ThrottledRequests
- Backup and restore (on-demand + PITR)
- Global Tables setup and monitoring
- Contributor Insights (identify hot keys)
- Capacity planning and reserved capacity

---

## Key Numbers

| Metric | Value |
|---|---|
| Max item size | 400 KB |
| Max partition throughput | 3,000 RCU + 1,000 WCU |
| Max GSI per table | 20 |
| Max LSI per table | 5 (must be created at table creation) |
| BatchWriteItem max | 25 items or 16 MB |
| BatchGetItem max | 100 items or 16 MB |
| TransactWriteItems max | 100 items or 4 MB |
| TransactGetItems max | 100 items or 4 MB |
| Query/Scan max response | 1 MB per call (paginate) |
| DynamoDB Streams retention | 24 hours |
| PITR retention | 35 days |
| TTL deletion delay | Up to 48 hours |
| Global Tables replication | Typically < 1 second |
| DAX node types | r-family (memory optimized) |
| DAX cluster min nodes | 1 (3+ recommended for production) |
| On-Demand → Provisioned switch | Once per 24 hours |
| 1 WCU | 1 write/s up to 1 KB |
| 1 RCU (strong) | 1 read/s up to 4 KB |
| 1 RCU (eventual) | 2 reads/s up to 4 KB |
| Reserved capacity term | 1 or 3 years |

---

## Cheat Sheet

- DynamoDB = serverless NoSQL. No servers, no patching, unlimited scale.
- 1 WCU = 1 write/s for 1 KB. 1 RCU = 1 strong read/s for 4 KB (or 2 eventual).
- Transactions cost 2x capacity (prepare + commit phase).
- DAX = in-memory cache, microsecond reads, eventually consistent only.
- Global Tables = multi-region active-active, needs Streams enabled.
- Streams = 24-hour change log, 4 view types (KEYS, NEW, OLD, BOTH).
- TTL = auto-delete after Unix timestamp, up to 48 hours delay.
- PITR = 35-day continuous backup. On-demand = manual snapshot, kept forever.
- Hot partition = bad key design. Fix: high-cardinality PK, composite keys.
- GSI = new PK+SK view (20 max, own capacity). LSI = same PK, new SK (5 max, at creation only).
- BatchWrite = 25 items. BatchGet = 100 items. Neither is transactional.
- Item max 400 KB. Query/Scan returns max 1 MB per call.
- On-Demand = no planning, 2.5x cost. Provisioned = cheaper, needs planning.
- Adaptive capacity helps hot partitions, but can't fix bad key design.
- Strongly consistent reads cost 2x eventually consistent.
- Filter expressions happen AFTER read — they still consume RCU.
