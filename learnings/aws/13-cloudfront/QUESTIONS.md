# CloudFront — Exam Questions

> 12 scenario-based questions mixing SAA-C03, DVA-C02, and SOA-C02 perspectives.

---

### Q1 (SAA) — S3 + CloudFront with OAC

A company hosts a static website in an S3 bucket. They want to serve it globally via CloudFront but ensure users CANNOT access the S3 bucket directly. Which configuration is correct?

A. Make the S3 bucket public and add a CloudFront distribution
B. Create an Origin Access Control (OAC), update the S3 bucket policy to allow only the CloudFront distribution, and block public access
C. Create an Origin Access Identity (OAI) and enable S3 static website hosting
D. Use S3 Transfer Acceleration instead of CloudFront

**Answer: B**

**Why B is correct:** OAC is the recommended way to restrict S3 access to CloudFront only. Create the OAC, associate it with the CloudFront distribution, then update the S3 bucket policy to allow `s3:GetObject` only from the CloudFront distribution's service principal. Block all public access to S3. Users MUST go through CloudFront. Like locking the warehouse and giving only the post office network the key.

**Why A is wrong:** Making S3 public means anyone with the S3 URL can bypass CloudFront. No access restriction.

**Why C is wrong:** OAI is the legacy method. OAC is recommended and supports SSE-KMS, newer S3 features, and all regions. On the exam, always prefer OAC.

**Why D is wrong:** S3 Transfer Acceleration speeds up uploads to S3. It's not a CDN and doesn't cache content at edge locations.

---

### Q2 (DVA) — Cache Key Optimization

A developer's CloudFront distribution has poor cache hit ratio (20%). Investigation shows the cache behavior forwards ALL query strings, ALL headers, and ALL cookies to the origin. What should the developer do to improve the hit ratio?

A. Increase the TTL to 365 days
B. Forward only the query strings, headers, and cookies the origin actually needs
C. Enable compression to reduce response sizes
D. Add more origins to the distribution

**Answer: B**

**Why B is correct:** Every unique combination of query strings, headers, and cookies creates a separate cache entry. Forwarding ALL of them means almost every request is a unique cache key — terrible hit ratio. Only forward what the origin needs (e.g., whitelist specific query params like `?page=` and `?size=`). Each unique cache key is like a separate shelf in the post office — fewer unique keys = more people getting served from the same shelf.

**Why A is wrong:** Higher TTL keeps cached items longer but doesn't help if every request has a unique cache key. You'd cache millions of unique entries.

**Why C is wrong:** Compression reduces transfer size but doesn't affect cache hit ratio.

**Why D is wrong:** More origins doesn't improve caching. The problem is the cache key cardinality.

---

### Q3 (SAA) — Signed URLs vs Signed Cookies

A media company serves premium video content. Subscribers should access all videos in the `/premium/` path. Non-subscribers should be blocked. The team wants a single authentication mechanism that works for all premium content. Which approach is BEST?

A. Signed URLs for each video
B. Signed Cookies for the `/premium/` path
C. S3 pre-signed URLs for each video
D. Geo-restriction to block non-subscribing countries

**Answer: B**

**Why B is correct:** Signed Cookies apply to multiple resources under a path pattern. Set the cookie once when the user logs in, and ALL requests to `/premium/*` are authorized. No need to generate individual URLs per video. Like giving subscribers a VIP pass — flash it once and access everything in the VIP section.

**Why A is wrong:** Signed URLs work per-file. For a library of thousands of videos, you'd need to generate a unique signed URL for each video request. Operational nightmare.

**Why C is wrong:** S3 pre-signed URLs bypass CloudFront entirely — users access S3 directly. No CDN benefit, no edge caching, higher latency.

**Why D is wrong:** Geo-restriction blocks by country, not by subscription status. A non-subscriber in an allowed country would still get access.

---

### Q4 (DVA) — CloudFront Functions vs Lambda@Edge

A development team needs to add A/B testing to their website. 50% of users should see version A (from origin-a.example.com) and 50% should see version B (from origin-b.example.com). The routing must be sticky (same user always sees the same version). Which edge compute option should they use?

A. CloudFront Functions on viewer request
B. Lambda@Edge on origin request
C. CloudFront Functions on origin request
D. Lambda@Edge on viewer request

**Answer: B**

**Why B is correct:** Lambda@Edge on origin request can dynamically change which origin the request goes to. It can check for a cookie (stickiness), and if absent, randomly assign version A or B and set a cookie. Origin request events can modify the origin — CloudFront Functions cannot. The origin request fires only on cache misses, so this is efficient. Like a sorting office that looks at your loyalty card and sends your package to warehouse A or B.

**Why A is wrong:** CloudFront Functions can't modify the origin. They run at the viewer level and have no access to origin selection.

**Why C is wrong:** CloudFront Functions only trigger on viewer request/response events, NOT origin events.

**Why D is wrong:** Lambda@Edge on viewer request could set cookies and modify request headers, but it can't change the origin. Origin selection happens at the origin request event.

---

### Q5 (SOA) — Invalidation vs Versioned URLs

A SysOps administrator manages a CloudFront distribution. The team frequently updates JavaScript files and needs changes reflected immediately for all users. Currently they create invalidations, which cost money and take 1-2 minutes. What is a MORE cost-effective approach?

A. Set TTL to 0 for JavaScript files
B. Use versioned file names (e.g., app-v2.3.js) and update HTML references
C. Use CloudFront Functions to add no-cache headers
D. Delete and recreate the CloudFront distribution after each update

**Answer: B**

**Why B is correct:** Versioned file names are the gold standard. `app-v2.3.js` is a different cache key than `app-v2.2.js`. When HTML references the new version, CloudFront fetches it fresh (cache miss). The old version stays cached but nobody requests it anymore. Zero invalidation cost, instant propagation, and the old version is still cached for users who haven't refreshed yet. Like giving each batch of candy a different label — the shop knows "v2.3" is new and orders it from the factory.

**Why A is wrong:** TTL=0 means CloudFront checks with the origin on EVERY request (conditional GET). This defeats the purpose of caching and increases origin load.

**Why C is wrong:** CloudFront Functions adding no-cache headers would prevent caching entirely — same problem as TTL=0.

**Why D is wrong:** Deleting a distribution causes downtime and takes 15-30 minutes to deploy a new one. Absurd for a file update.

---

### Q6 (SAA) — Origin Failover

A company serves a critical web application through CloudFront with an S3 origin in us-east-1. They want automatic failover to an S3 bucket in eu-west-1 if the primary origin returns errors. What should they configure?

A. Route 53 failover routing between two CloudFront distributions
B. A CloudFront origin group with us-east-1 as primary and eu-west-1 as secondary
C. Lambda@Edge to catch errors and redirect to the backup origin
D. S3 Cross-Region Replication with a single CloudFront origin

**Answer: B**

**Why B is correct:** CloudFront origin groups provide automatic failover. Configure primary (us-east-1) and secondary (eu-west-1) origins. If the primary returns 5xx errors or times out, CloudFront automatically retries with the secondary origin. Transparent to users, no DNS propagation delay. Like the post office trying the main warehouse first, and if it's closed, automatically going to the backup warehouse.

**Why A is wrong:** Two separate CloudFront distributions with Route 53 failover adds DNS TTL delay (minutes). Origin groups provide instant failover at the CloudFront level (seconds).

**Why C is wrong:** Lambda@Edge could do this but adds complexity, latency, and cost. Origin groups are the native, simpler solution.

**Why D is wrong:** S3 CRR replicates objects but doesn't provide automatic origin failover. You'd still need origin groups for CloudFront to switch.

---

### Q7 (SOA) — Cache Hit Ratio Monitoring

A SysOps administrator wants to monitor how effectively CloudFront is caching content. Which CloudWatch metrics should they monitor?

A. CacheHitRate and CacheMissRate
B. Requests and BytesDownloaded
C. 4xxErrorRate and 5xxErrorRate
D. TotalErrorRate and OriginLatency

**Answer: A**

**Why A is correct:** CacheHitRate directly shows the percentage of requests served from cache. CacheMissRate shows requests forwarded to origin. Together they tell you how effective your caching is. A low CacheHitRate means too many requests hit the origin — check your cache key configuration, TTL settings, and query string/header forwarding.

**Why B is wrong:** Requests and BytesDownloaded measure traffic volume, not caching effectiveness.

**Why C is wrong:** Error rates measure failures, not cache performance.

**Why D is wrong:** OriginLatency measures origin response time. Useful for troubleshooting but doesn't indicate cache effectiveness.

---

### Q8 (SAA) — Custom SSL Certificate

A company wants to serve their CloudFront distribution at `cdn.example.com` with HTTPS. Where must the SSL certificate be provisioned?

A. ACM in the same region as the S3 origin
B. ACM in us-east-1 (N. Virginia)
C. ACM in any region — CloudFront will replicate it
D. Upload the certificate directly to CloudFront

**Answer: B**

**Why B is correct:** CloudFront requires SSL certificates to be in **ACM us-east-1** specifically. This is a hard requirement regardless of where your origin is. CloudFront is a global service, and us-east-1 is where it manages certificates. Like the ministry of foreign affairs requiring all passports to be issued from the capital office.

**Why A is wrong:** The origin's region is irrelevant to CloudFront's certificate requirement.

**Why C is wrong:** CloudFront does NOT replicate certificates from other regions. Must be us-east-1.

**Why D is wrong:** While you CAN import certificates via IAM (legacy method), ACM in us-east-1 is the recommended and modern approach.

---

### Q9 (DVA) — Dynamic vs Static Content

A developer's application serves both static assets (images, CSS, JS) from S3 and dynamic API responses from an ALB. They want to use a single CloudFront distribution. How should cache behaviors be configured?

A. Single default behavior caching everything for 24 hours
B. `/api/*` behavior with caching disabled (forward all) pointing to ALB, default behavior with caching enabled pointing to S3
C. Two separate CloudFront distributions — one for static, one for dynamic
D. All traffic to ALB, let the ALB decide whether to serve from S3 or process dynamically

**Answer: B**

**Why B is correct:** Use cache behaviors to route different paths to different origins with appropriate settings. Static content (`/images/*`, `/static/*`, default) goes to S3 with long TTL. Dynamic content (`/api/*`) goes to ALB with caching disabled (or short TTL) and all query strings/headers forwarded. One distribution, two behaviors, two origins. Like the post office having separate counters — packages go to the warehouse shelf, letters go directly to the recipient.

**Why A is wrong:** Caching API responses for 24 hours would serve stale data. Dynamic content often changes per request.

**Why C is wrong:** Two distributions means two domain names (or complex DNS). A single distribution with multiple behaviors is cleaner.

**Why D is wrong:** Routing all traffic through ALB means S3 assets aren't served from cache — unnecessary ALB load and cost.

---

### Q10 (SAA) — Geo-Restriction vs WAF Geo-Blocking

A company needs to block access from a specific list of 5 countries AND rate-limit requests from all other countries. Which combination should they use?

A. CloudFront geo-restriction for all requirements
B. CloudFront geo-restriction for country blocking + AWS WAF rate-based rules for rate limiting
C. AWS WAF geo-match rules for both blocking and rate limiting
D. Lambda@Edge for both geo-blocking and rate limiting

**Answer: B or C (both acceptable; C is more unified)**

**Why B/C is correct:** CloudFront's built-in geo-restriction is a simple whitelist/blacklist — it can block 5 countries but can't rate-limit. AWS WAF provides both geo-match rules (block by country) AND rate-based rules (rate limiting). Option C uses WAF for both, which is cleaner. Option B works too — geo-restriction blocks countries, WAF handles rate limiting.

On the actual exam, if only one of these is available:
- If B and C are both options, pick **C** (WAF handles both, single management plane)
- If only B is available, it's correct

**Why A is wrong:** CloudFront geo-restriction only does block/allow by country. No rate limiting capability.

**Why D is wrong:** Lambda@Edge could do this but adds significant complexity, latency, and cost. WAF is purpose-built for this.

---

### Q11 (DVA) — Invalidation Behavior

A developer deploys a new version of `index.html` to S3 but CloudFront still serves the old version. They create an invalidation for `/index.html`. What happens?

A. CloudFront immediately removes the cached file from all edge locations
B. CloudFront marks the cached file as expired at all edge locations within 1-2 minutes; the next request fetches the new version from origin
C. Only the regional edge caches are invalidated; edge locations keep the old version
D. The S3 object is deleted and replaced

**Answer: B**

**Why B is correct:** Invalidation removes the cached object from CloudFront edge locations (and regional edge caches). It takes approximately **1-2 minutes** to propagate globally. The next request after invalidation triggers a cache miss, fetching the fresh version from S3. CloudFront doesn't proactively push the new content — it waits for the next request. Like telling all post offices "throw away that leaflet" — they do, but they don't go get the new one until someone asks for it.

**Why A is wrong:** Invalidation is NOT immediate. It takes 1-2 minutes to propagate to all 300+ edge locations.

**Why C is wrong:** Invalidation applies to all tiers — both edge locations and regional edge caches.

**Why D is wrong:** CloudFront invalidation doesn't touch the origin (S3). It only affects CloudFront caches.

---

### Q12 (SOA) — Price Class Selection

A SysOps administrator needs to reduce CloudFront costs. The application's users are primarily in North America and Europe. A small number of requests come from Asia, but latency for those users is not critical. What should they configure?

A. Price Class All (keep global coverage)
B. Price Class 200 (exclude most expensive regions)
C. Price Class 100 (North America and Europe only)
D. Remove CloudFront and serve directly from the origin

**Answer: C**

**Why C is correct:** Price Class 100 uses only edge locations in North America and Europe — the cheapest regions. Since the primary user base is in NA and EU, they get low-latency cached content. Asian users will be served from the nearest available edge (likely NA or EU), which adds latency but still works. Cost is significantly lower than Price Class All. Like closing the most expensive regional post offices and having those customers use the nearest available one.

**Why A is wrong:** Price Class All includes all 300+ locations, including expensive regions (South America, Australia, Asia) that few users access. Unnecessary cost.

**Why B is wrong:** Price Class 200 excludes only the MOST expensive regions. It still includes many Asian locations that the admin wants to deprioritize. Not the maximum cost savings.

**Why D is wrong:** Removing CloudFront eliminates CDN benefits entirely — higher latency for ALL users and higher origin load. The goal is cost reduction, not service elimination.
