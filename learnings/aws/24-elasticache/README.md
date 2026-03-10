# ElastiCache — Speed Cache

> **ElastiCache is a speed-reading room with photocopied popular books. Instead of walking to the library (database) every time, you read the photocopy on your desk. Redis is the full-featured room. Memcached is the simple one.**

---

## ELI10

Imagine the school library is really slow — it takes 5 minutes to find any book. So the teacher photocopies the most popular books and puts them in a speed-reading room next to your classroom. Now you check the speed room first. If the book is there (cache hit), you grab it instantly. If not (cache miss), you walk to the library, get the book, make a photocopy, and leave it in the speed room for next time. Redis is a fancy speed room with shelves, labels, and a backup system. Memcached is just a table with loose papers — fast but basic.

---

## The Concept

### ElastiCache = In-Memory Data Store

ElastiCache puts frequently accessed data in **RAM** instead of on disk. RAM is ~1000x faster than disk-based databases. Two engines: **Redis** and **Memcached**.

```
┌─────────────────────────────────────────────────────┐
│                  Application                         │
│                      │                               │
│              ┌───────┴───────┐                       │
│              │ Check cache?  │                       │
│              └───────┬───────┘                       │
│                 HIT? │ MISS?                         │
│              ┌───────┴───────┐                       │
│              v               v                       │
│     ┌──────────────┐  ┌──────────────┐              │
│     │ ElastiCache  │  │   RDS /      │              │
│     │ (microsecs)  │  │   DynamoDB   │              │
│     │              │  │   (millisecs)│              │
│     └──────────────┘  └──────┬───────┘              │
│                              │                       │
│                     Store in cache                    │
│                     for next time                     │
└─────────────────────────────────────────────────────┘
```

### Redis vs Memcached — Decision Tree

```
                    Need caching?
                         │
                    ┌────┴────┐
                    │ Complex │
                    │ data?   │
                    └────┬────┘
               Yes ──────┼────── No
                │                 │
                v                 v
             REDIS          MEMCACHED
     ┌──────────────┐   ┌──────────────┐
     │ Persistence  │   │ Multi-thread │
     │ Replication  │   │ Simple K/V   │
     │ Pub/Sub      │   │ No persist   │
     │ Sorted Sets  │   │ No replicate │
     │ Lua Scripts  │   │ Auto-discover│
     │ Geospatial   │   │ Scale out    │
     │ Streams      │   │              │
     │ Cluster Mode │   │ Great for:   │
     │ Backup/AOF   │   │ • Simple     │
     │              │   │   sessions   │
     │ Great for:   │   │ • HTML cache │
     │ • Sessions   │   │ • Disposable │
     │ • Leaders    │   │   data       │
     │ • Real-time  │   │              │
     │ • Queues     │   │ If data loss │
     │ • Geo queries│   │ is OK → this │
     └──────────────┘   └──────────────┘
```

| Feature | Redis | Memcached |
|---------|-------|-----------|
| Data structures | Strings, lists, sets, sorted sets, hashes, streams | Strings only |
| Persistence | Yes (RDB snapshots + AOF) | No |
| Replication | Yes (read replicas, up to 5 per shard) | No |
| Multi-AZ failover | Yes (automatic) | No |
| Pub/Sub | Yes | No |
| Lua scripting | Yes | No |
| Geospatial | Yes | No |
| Multi-threaded | No (single-threaded) | Yes |
| Cluster mode | Yes (sharding) | Yes (auto-discovery) |
| Backup & restore | Yes | No |
| Encryption | At-rest + in-transit | At-rest + in-transit |
| Auth | Redis AUTH + IAM | SASL |

### Caching Strategies

```
┌────────────────────────────────────────────────────────────┐
│                                                             │
│  LAZY LOADING (Cache-Aside / Read-Through)                  │
│  ═══════════════════════════════════════                     │
│  1. App checks cache                                        │
│  2. Cache MISS → read from DB                               │
│  3. Store result in cache                                   │
│  4. Next read → cache HIT (fast!)                           │
│                                                             │
│  Pros: Only caches what's needed, resilient to cache fail   │
│  Cons: Cache miss = 3 trips (check, read DB, write cache)   │
│        Data can be STALE (updated in DB but not cache)      │
│                                                             │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  WRITE-THROUGH                                              │
│  ═══════════════                                            │
│  1. App writes to DB                                        │
│  2. ALSO writes to cache immediately                        │
│  3. Cache always has latest data                            │
│                                                             │
│  Pros: Data never stale, every read is a HIT (eventually)  │
│  Cons: Write penalty (2 writes per update)                  │
│        Caches data that may NEVER be read (waste)           │
│                                                             │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  TTL (Time-To-Live)                                         │
│  ══════════════════                                         │
│  Set expiration on cached data (e.g., 5 minutes)            │
│  Best of both worlds: use Lazy Loading + TTL                │
│  Stale data auto-expires, fresh data fetched on next miss   │
│                                                             │
│  Best practice: Lazy Loading + Write-Through + TTL          │
│  (cache on miss, update on write, expire old data)          │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

### Redis Cluster Mode

```
┌──────────────────────────────────────────────────────────┐
│  CLUSTER MODE DISABLED (Single Shard)                     │
│                                                           │
│  ┌───────────┐                                            │
│  │  Primary  │ ←── All writes go here                     │
│  └─────┬─────┘                                            │
│        │ replication                                      │
│   ┌────┴────┬────────┐                                    │
│   v         v        v                                    │
│ Replica 1  Replica 2  Replica 3   ← Read replicas (0-5)  │
│                                                           │
│ • 1 shard, up to 5 read replicas                          │
│ • Scale READS (more replicas = more read throughput)      │
│ • All data fits in one node                               │
│ • Multi-AZ failover: replica promoted to primary          │
├──────────────────────────────────────────────────────────┤
│  CLUSTER MODE ENABLED (Multi-Shard)                       │
│                                                           │
│  Shard 1          Shard 2          Shard 3                │
│  ┌────────┐       ┌────────┐       ┌────────┐            │
│  │Primary │       │Primary │       │Primary │            │
│  │Keys A-H│       │Keys I-P│       │Keys Q-Z│            │
│  └───┬────┘       └───┬────┘       └───┬────┘            │
│      │                 │                 │                 │
│  ┌───┴───┐         ┌──┴────┐        ┌──┴────┐            │
│  │Replica│         │Replica│        │Replica│            │
│  └───────┘         └───────┘        └───────┘            │
│                                                           │
│ • Data PARTITIONED across shards (hash slots)             │
│ • Scale WRITES (more shards = more write throughput)      │
│ • Up to 500 nodes per cluster                             │
│ • Each shard can have 0-5 replicas                        │
│ • Online resharding supported                             │
└──────────────────────────────────────────────────────────┘
```

### Global Datastore (Redis Only)

```
┌────────────────────┐         ┌────────────────────┐
│  Primary Region    │  async  │ Secondary Region   │
│  (ap-southeast-2)  │ ──────> │  (us-east-1)       │
│                     │  <1ms   │                     │
│  Read + Write       │ typical │  Read-only          │
│                     │         │  (promote for DR)   │
└────────────────────┘         └────────────────────┘

• Cross-region replication for Redis
• Sub-second replication lag (typically <1ms)
• Up to 2 secondary regions
• Promote secondary to primary for disaster recovery
```

### ElastiCache for Redis vs DynamoDB DAX

| | ElastiCache Redis | DynamoDB DAX |
|---|---|---|
| What it caches | Anything (any data source) | DynamoDB only |
| Protocol | Redis protocol | DynamoDB-compatible API |
| Code changes | Need Redis client code | Drop-in replacement (same API) |
| Data structures | Rich (lists, sets, sorted sets) | Key-value (DynamoDB items) |
| Use case | General-purpose cache | DynamoDB acceleration |
| Latency | Microseconds | Microseconds |
| Cluster | Managed | Managed |

---

## Use Cases

| Use Case | Why ElastiCache |
|----------|-----------------|
| **Session store** | User sessions in Redis = fast, persistent, shared across servers |
| **Database caching** | Cache frequent queries = reduce DB load by 80%+ |
| **Leaderboards** | Redis sorted sets = real-time ranking with O(log N) operations |
| **Real-time analytics** | Redis HyperLogLog, streams = count unique visitors, process events |
| **Message queues** | Redis lists/streams = lightweight pub/sub and queuing |
| **Geospatial** | Redis geospatial indexes = "find restaurants within 5km" |
| **Rate limiting** | Redis INCR + EXPIRE = "max 100 requests per minute per user" |

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- **Redis vs Memcached decision** — persistence, replication, data structures → Redis. Simple, disposable → Memcached.
- **Caching strategies** — Lazy Loading vs Write-Through vs TTL
- **Cluster mode** enabled vs disabled — scale reads (replicas) vs scale writes (shards)
- **Global Datastore** for cross-region disaster recovery
- **ElastiCache vs DAX** — general cache vs DynamoDB-specific

### DVA-C02 (Developer)
- **Caching patterns in code** — Lazy Loading + TTL is the default recommendation
- **Session management** — store sessions in Redis for stateless applications
- **Redis data structures** — sorted sets for leaderboards, pub/sub for messaging
- **Connection** — must be in same VPC or peered VPC (no public access by default)

### SOA-C02 (SysOps)
- **Monitoring** — CacheHitRate, CurrConnections, EngineCPUUtilization, Evictions
- **Scaling** — add read replicas (reads), add shards (writes), scale up node type (more memory)
- **Failover** — Multi-AZ with automatic failover (Redis only)
- **Maintenance** — maintenance windows, engine version upgrades, patching
- **Encryption** — at-rest (KMS), in-transit (TLS)

---

## Key Numbers

| Fact | Value |
|------|-------|
| Redis max node types | Up to 635 GB RAM (r6g.16xlarge) |
| Redis read replicas per shard | Up to 5 |
| Redis cluster mode shards | Up to 500 nodes total |
| Redis backup retention | 1-35 days |
| Redis Global Datastore secondary regions | Up to 2 |
| Memcached max nodes per cluster | 40 |
| Memcached max node size | 635 GB RAM |
| Default Redis port | 6379 |
| Default Memcached port | 11211 |
| Sub-millisecond latency | Both engines |

---

## Cheat Sheet

- **Redis = full-featured.** Persistence, replication, pub/sub, sorted sets, streams, Lua, geospatial.
- **Memcached = simple.** Multi-threaded, no persistence, no replication. Good for disposable cache.
- **Need persistence or replication? → Redis.** Need multi-threading? → Memcached.
- **Lazy Loading** = cache on read miss (safe, but stale data possible)
- **Write-Through** = cache on every write (fresh data, but write penalty)
- **TTL** = set expiration. Use with Lazy Loading for best results.
- **Cluster mode disabled** = 1 shard + read replicas. Scale reads.
- **Cluster mode enabled** = multiple shards. Scale writes. Data is partitioned.
- **Global Datastore** = cross-region Redis replication for DR.
- **DAX is for DynamoDB ONLY.** ElastiCache is for anything.
- **DAX is a drop-in replacement** (same API). ElastiCache requires code changes.
- **ElastiCache is VPC-only** — no public internet access by default.
- **Evictions metric** = cache is full, data being kicked out. Scale up or add nodes.
- **CacheHitRate** = how effective your cache is. Low = bad caching strategy.
