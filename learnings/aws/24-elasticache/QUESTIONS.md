# ElastiCache — Exam Practice Questions

---

## Q1: Redis vs Memcached

A company needs an in-memory cache for their web application. Requirements: data must survive node restarts, the application needs read replicas for high availability, and they need sorted sets for a real-time leaderboard. Which ElastiCache engine should they use?

**A)** Memcached with multi-AZ
**B)** Redis with cluster mode disabled
**C)** Memcached with replication
**D)** Redis with Global Datastore

### Answer: B

**Why:** The requirements — persistence (survive restarts), read replicas, and sorted sets — are ALL Redis-only features. Memcached has none of these. Cluster mode disabled with read replicas is sufficient for this use case (no mention of scaling writes).

- **A is wrong:** Memcached doesn't support Multi-AZ failover or persistence. If a node dies, the data is gone.
- **C is wrong:** Memcached doesn't support replication at all. Each node is independent.
- **D is wrong:** Global Datastore is for cross-region replication — overkill when the requirement is just read replicas and HA within one region.

---

## Q2: Caching Strategy

A developer implements caching for a product catalog. Products rarely change but are read millions of times per day. Occasionally, a product price updates and users see the old price for several minutes. Which caching strategy combination should the developer use?

**A)** Lazy Loading only
**B)** Write-Through only
**C)** Lazy Loading with TTL
**D)** Write-Through with TTL

### Answer: D

**Why:** Write-Through ensures that when a product is updated, the cache is updated immediately — no stale data. TTL provides a safety net: even if the write-through somehow fails, old data expires automatically. This gives you fresh data (write-through) plus automatic cleanup (TTL). The current problem (seeing old prices) means they're using Lazy Loading without Write-Through.

- **A is wrong:** Lazy Loading alone is the current problem — data is only refreshed on cache miss, so stale prices persist until the TTL expires or the cache entry is evicted.
- **B is wrong:** Write-Through alone wastes cache space by caching every write, even for products nobody reads. Adding TTL cleans up unused entries.
- **C is wrong:** This is better than A alone, but the stale window still exists between writes and TTL expiration. Users see old prices until TTL expires.

---

## Q3: Cluster Mode Decision

A real-time analytics platform processes 500,000 writes per second to Redis. A single Redis primary node can handle 100,000 writes per second. What should the solutions architect configure?

**A)** Redis cluster mode disabled with 5 read replicas
**B)** Redis cluster mode enabled with at least 5 shards
**C)** Memcached cluster with 5 nodes
**D)** Redis cluster mode disabled with a larger node type

### Answer: B

**Why:** Cluster mode enabled **partitions data across shards**, and each shard has its own primary node handling writes. 5 shards = 5 primary nodes = 500,000 writes/second capacity. Cluster mode disabled only has ONE primary node — adding replicas only scales reads, not writes.

- **A is wrong:** Read replicas don't handle writes. All writes still go to the single primary node (100K/s max). This scales reads, not writes.
- **C is wrong:** Memcached lacks persistence, replication, and failover. For a real-time analytics platform with 500K writes/second, data loss would be catastrophic.
- **D is wrong:** A single node has hardware limits. Even the largest node type can't handle 500K writes/second. You need horizontal scaling (sharding), not vertical scaling.

---

## Q4: ElastiCache vs DAX

A team has a DynamoDB table serving a high-traffic API. They want to add caching to reduce read latency from 5ms to sub-millisecond with the LEAST code changes. Which solution should they use?

**A)** ElastiCache for Redis with Lazy Loading
**B)** DynamoDB DAX
**C)** ElastiCache for Memcached
**D)** CloudFront caching

### Answer: B

**Why:** DAX is a **drop-in replacement** for DynamoDB reads. It uses the same DynamoDB API — you just change the endpoint. Your existing `GetItem`, `Query`, and `Scan` calls work without code changes. ElastiCache would require rewriting read logic to check Redis first, then DynamoDB on miss.

- **A is wrong:** Redis requires adding a Redis client, writing cache-check logic, handling misses, serializing/deserializing data. Significant code changes.
- **C is wrong:** Same as A but with even fewer features. Significant code changes required.
- **D is wrong:** CloudFront caches HTTP responses at edge locations. It's for API responses, not database query results. Wouldn't help with direct DynamoDB reads from backend code.

---

## Q5: Monitoring Cache Performance

A SysOps admin notices that an ElastiCache Redis cluster has high `Evictions` and low `CacheHitRate`. What is the BEST course of action?

**A)** Increase the TTL on all cache entries
**B)** Scale up to a larger node type with more memory
**C)** Switch from Redis to Memcached
**D)** Enable cluster mode and add shards

### Answer: B

**Why:** High evictions = the cache is full and kicking out entries to make room. Low cache hit rate = the data you need isn't in cache (likely because it was evicted). The root cause is **insufficient memory**. Scaling up to a larger node type gives more RAM to hold more cached data.

- **A is wrong:** Increasing TTL keeps data longer, which makes the memory problem WORSE. More data + same memory = even more evictions.
- **C is wrong:** Switching engines doesn't solve a memory capacity problem. Memcached with the same memory would have the same issue.
- **D is wrong:** Adding shards distributes data across more nodes (which does add memory), but if you don't need write scaling, simply using a larger node is simpler and more cost-effective.

---

## Q6: Security — Encryption

A compliance requirement states that all cached data must be encrypted at rest and in transit. The team uses ElastiCache for Redis. What must they configure?

**A)** Enable encryption at rest (KMS) and encryption in transit (TLS) when creating the cluster
**B)** Encrypt data in the application before writing to Redis
**C)** Use a VPN connection between the application and ElastiCache
**D)** Enable SSL on the Redis AUTH password only

### Answer: A

**Why:** ElastiCache for Redis supports native encryption at rest (using KMS keys) and encryption in transit (TLS). Both must be enabled **at cluster creation time** — they cannot be enabled on an existing cluster. This is a managed, built-in feature.

- **B is wrong:** Application-level encryption works but doesn't encrypt at rest in the ElastiCache node's memory. And it doesn't encrypt data in transit between app and Redis unless you also use TLS.
- **C is wrong:** A VPN encrypts the network tunnel but doesn't encrypt data at rest in the cache. Also, ElastiCache is VPC-only — a VPN is unnecessary for app-to-cache communication within a VPC.
- **D is wrong:** Redis AUTH is for authentication (password protection), not encryption. It doesn't encrypt data at rest or in transit.

---

## Q7: Global Datastore

A company runs a gaming platform with users worldwide. They use ElastiCache for Redis to cache player profiles. They need sub-millisecond read latency in both Asia-Pacific and US regions. What should the solutions architect configure?

**A)** ElastiCache for Redis with Global Datastore — primary in ap-southeast-2, secondary in us-east-1
**B)** Two independent ElastiCache clusters, one in each region, synced by application code
**C)** ElastiCache for Memcached with cross-region replication
**D)** DynamoDB Global Tables with DAX in each region

### Answer: A

**Why:** Global Datastore provides **automatic cross-region replication** for Redis. The primary cluster handles writes, and secondary clusters in other regions serve local reads with sub-millisecond latency. Replication lag is typically under 1 second.

- **B is wrong:** Application-level sync is complex, error-prone, and doesn't guarantee consistency. Global Datastore handles replication automatically.
- **C is wrong:** Memcached doesn't support cross-region replication or any replication at all.
- **D is wrong:** DynamoDB Global Tables + DAX would work architecturally, but the question says they're already using ElastiCache Redis. Global Datastore is the native solution — no need to migrate to a different data store.

---

## Q8: Session Management

A web application runs on multiple EC2 instances behind an ALB. Users report being logged out randomly when their requests hit different instances. The application stores sessions in memory on each EC2 instance. What is the BEST solution?

**A)** Enable sticky sessions on the ALB
**B)** Store sessions in ElastiCache for Redis
**C)** Store sessions in S3
**D)** Store sessions on an EFS volume shared across instances

### Answer: B

**Why:** ElastiCache Redis is the standard solution for shared session storage. All instances read/write sessions from the same Redis cluster. Sessions persist across instance failures (Redis persistence), support TTL for automatic expiration, and provide sub-millisecond access. This makes the application truly stateless.

- **A is wrong:** Sticky sessions work but create uneven load distribution. If the pinned instance dies, the user loses their session. It's a band-aid, not a solution.
- **C is wrong:** S3 is object storage — too slow for session lookups (tens to hundreds of milliseconds). Sessions need sub-millisecond access.
- **D is wrong:** EFS is a file system. Storing sessions as files is complex, doesn't support TTL, and has higher latency than Redis. It's not designed for key-value access patterns.

---

## Q9: Memcached Use Case

A content platform needs to cache rendered HTML pages. The cached data is disposable (can be regenerated from the database), doesn't need persistence, and the workload is heavily multi-threaded. Which ElastiCache solution is BEST?

**A)** Redis with cluster mode enabled
**B)** Redis with cluster mode disabled
**C)** Memcached
**D)** Redis with persistence disabled

### Answer: C

**Why:** The requirements — disposable data, no persistence needed, multi-threaded workload — perfectly match Memcached. Memcached is **multi-threaded** (uses all CPU cores), handles simple key-value caching well, and has lower overhead than Redis when advanced features aren't needed.

- **A is wrong:** Redis cluster mode is for scaling writes and complex data structures. Overkill for disposable HTML cache.
- **B is wrong:** Redis is single-threaded — the multi-threaded requirement specifically favors Memcached.
- **D is wrong:** Even with persistence disabled, Redis is still single-threaded. You lose the multi-threading advantage. Memcached is the right tool when simplicity and multi-threading are priorities.

---

## Q10: Scaling Strategy

An ElastiCache Redis cluster (cluster mode disabled) handles 1 million reads per second but only 50,000 writes per second. Read traffic is growing 20% monthly. Write traffic is stable. What is the MOST cost-effective scaling approach?

**A)** Enable cluster mode and add shards
**B)** Add more read replicas (up to 5)
**C)** Scale up to a larger node type
**D)** Switch to Memcached for better read performance

### Answer: B

**Why:** Write traffic is stable (no need to scale writes). Read traffic is growing. With cluster mode disabled, you can add **read replicas** (up to 5) to distribute read load. Each replica handles reads independently, so 5 replicas = ~5x read capacity. This is the most cost-effective approach since you only add what's needed (read capacity).

- **A is wrong:** Cluster mode enabled scales WRITES by adding shards. Writes are stable at 50K/s, so sharding is unnecessary cost and complexity.
- **C is wrong:** Scaling up (bigger node) costs more than scaling out (more replicas), and you hit a ceiling with vertical scaling. Adding replicas is more cost-effective for read-heavy workloads.
- **D is wrong:** Memcached is multi-threaded but lacks replication, persistence, and failover. Switching engines for read performance doesn't make sense when Redis read replicas solve the problem directly.
