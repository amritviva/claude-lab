# CloudFront — The Global Post Office Network

> **In the AWS Country, CloudFront is a global post office network.** 300+ local post offices (edge locations) around the world cache and deliver your packages (content) so customers don't have to wait for delivery from the main warehouse (origin server) every time.

---

## ELI10

Imagine you have a candy factory in Sydney. Every time someone in London wants candy, a truck drives all the way from Sydney to London — that's slow. Instead, you set up little candy shops (edge locations) in every city. The first London customer waits for the truck, but the shop keeps extra candy in stock. The next 1,000 London customers get their candy from the local shop instantly. If you make a new flavor, you tell all shops to throw away the old stock (invalidation) and order fresh. That's CloudFront — local shops caching your content worldwide.

---

## The Concept

### How CloudFront Works

```
User in London                   Edge Location (London)
      │                                │
      │ Request: GET /images/logo.png  │
      ├───────────────────────────────▶│
      │                                │
      │                         Cache HIT?
      │                         ┌──────┴──────┐
      │                         │             │
      │                        YES           NO (cache miss)
      │                         │             │
      │                  Return cached    Forward to origin
      │                  (< 10ms)         │
      │                         │         │
      │◀────────────────────────┘         ▼
      │                           ┌──────────────┐
      │                           │ ORIGIN       │
      │                           │ (S3/ALB/EC2) │
      │                           │ (in Sydney)  │
      │                           └──────┬───────┘
      │                                  │
      │                           Response + cache
      │◀─────────────────────────────────┘
      │                           (200ms first time,
      │                            <10ms after cached)
```

### Architecture Components

```
┌──────────────────────────────────────────────────────────────┐
│                  CLOUDFRONT DISTRIBUTION                      │
│                                                              │
│  Domain: d111111.cloudfront.net                              │
│  (or custom: cdn.example.com)                                │
│                                                              │
│  ┌─────────────────────┐                                     │
│  │   ORIGINS            │                                    │
│  │                      │                                    │
│  │  • S3 bucket         │   The main warehouses              │
│  │  • ALB               │   where content lives              │
│  │  • EC2 instance      │                                    │
│  │  • Custom HTTP       │                                    │
│  │  • MediaStore        │                                    │
│  └─────────────────────┘                                     │
│                                                              │
│  ┌─────────────────────┐                                     │
│  │   CACHE BEHAVIORS    │                                    │
│  │                      │                                    │
│  │  /api/*    → ALB origin  (no cache, forward all)          │
│  │  /images/* → S3 origin   (cache 24h, compress)            │
│  │  Default   → S3 origin   (cache 1h)                       │
│  └─────────────────────┘                                     │
│                                                              │
│  ┌─────────────────────┐                                     │
│  │   EDGE LOCATIONS     │                                    │
│  │   300+ worldwide     │   The local post offices           │
│  │                      │                                    │
│  │   Regional Edge      │   Regional distribution hubs       │
│  │   Caches (13)        │   (between edge and origin)        │
│  └─────────────────────┘                                     │
└──────────────────────────────────────────────────────────────┘
```

**Three-tier caching:**
```
Edge Location (300+) → Regional Edge Cache (13) → Origin
   (closest)              (middle tier)           (source)
```

---

### Origins: The Main Warehouses

**S3 Bucket Origin:**
- Most common for static content (images, CSS, JS, videos)
- Use Origin Access Control (OAC) to restrict S3 access to CloudFront only
- S3 Transfer Acceleration is NOT needed when using CloudFront

**ALB / EC2 Origin:**
- Dynamic content (API responses, server-rendered pages)
- Must be publicly accessible (ALB public, EC2 with public IP)
- EC2 security group must allow CloudFront IP ranges

**Custom HTTP Origin:**
- Any HTTP/HTTPS endpoint (on-premises, other cloud)
- Must be accessible from the internet

**Origin Groups (Failover):**
```
Origin Group:
├── Primary Origin: S3 bucket (us-east-1)
└── Secondary Origin: S3 bucket (us-west-2)

If primary returns 5xx → automatically fails over to secondary
```

---

### OAC: Only the Post Office Can Access the Warehouse

**Origin Access Control (OAC)** restricts your S3 bucket so only CloudFront can access it. Users can't bypass CloudFront and go directly to S3.

```
User → CloudFront (d111111.cloudfront.net) → S3 bucket (private)
                                               │
                                        Bucket policy:
                                        Allow: CloudFront distribution
                                        Deny: everything else
```

**OAC vs OAI:**
- **OAI (Origin Access Identity)** = old way (legacy)
- **OAC (Origin Access Control)** = new way (recommended)
- OAC supports: SSE-KMS encryption, all S3 regions, PUT/DELETE methods
- OAI doesn't support SSE-KMS or newer S3 features
- **Always pick OAC on the exam** if both are options

---

### Cache Behaviors: Delivery Rules

Cache behaviors define how CloudFront handles requests matching a path pattern.

```
Distribution: cdn.example.com
│
├── Behavior: /api/*
│   ├── Origin: ALB
│   ├── Cache: disabled (forward everything)
│   ├── Allowed methods: GET, POST, PUT, DELETE
│   └── Viewer protocol: HTTPS only
│
├── Behavior: /images/*
│   ├── Origin: S3 bucket
│   ├── Cache: 86400s (24 hours)
│   ├── Compress: Yes (Gzip + Brotli)
│   └── Viewer protocol: Redirect HTTP → HTTPS
│
└── Default behavior: *
    ├── Origin: S3 bucket
    ├── Cache: 3600s (1 hour)
    └── Viewer protocol: HTTPS only
```

**Cache key components (what makes a cache entry unique):**
- URL path
- Query strings (configurable: none, whitelist, all)
- Headers (configurable: none, whitelist, all)
- Cookies (configurable: none, whitelist, all)

**Best practice:** Minimize cache key components for better hit ratio. Forward only what the origin needs.

---

### TTL Configuration

```
CloudFront TTL priority (highest to lowest):
1. Cache-Control: max-age header from origin
2. Cache-Control: s-maxage header from origin
3. Expires header from origin
4. Default TTL in cache behavior (if no origin headers)

Ranges:
  Minimum TTL: 0 seconds (default)
  Default TTL: 86,400 seconds (24 hours)
  Maximum TTL: 31,536,000 seconds (365 days)
```

---

### Signed URLs and Signed Cookies: VIP Access

**Signed URL = VIP ticket for one specific package**
- Time-limited access to a specific file
- Includes: URL, expiration time, IP range (optional), key pair
- Use case: paid content, temporary download links

**Signed Cookie = VIP pass for multiple packages**
- Time-limited access to multiple files
- Set cookie once, access many resources
- Use case: subscriber content, premium areas of a site

**When to use which:**

| Feature | Signed URL | Signed Cookie |
|---|---|---|
| Access scope | One file per URL | Multiple files |
| Client changes | URL changes per file | Cookie set once |
| RTMP streaming | Required (legacy) | Not supported |
| Use case | Single file download | Premium content area |

**Key Signers:**
- **Trusted Key Group** (recommended) — manage keys via API
- **CloudFront Key Pair** (legacy) — requires root account, not recommended

---

### Geo-Restriction: Block Deliveries to Certain Countries

```
Whitelist: ONLY allow access from Australia, NZ, UK
  OR
Blacklist: Block access from Country X, Country Y
```

- Uses GeoIP database
- Returns 403 Forbidden to blocked countries
- Use case: content licensing, compliance, sanctions

---

### Lambda@Edge and CloudFront Functions

```
Viewer Request → CloudFront Function or Lambda@Edge
                         │
                    Cache check
                         │
                    Cache miss?
                         │
Origin Request → Lambda@Edge only
                         │
                    Origin response
                         │
Origin Response → Lambda@Edge only
                         │
                    Cache + respond
                         │
Viewer Response → CloudFront Function or Lambda@Edge
```

| Feature | CloudFront Functions | Lambda@Edge |
|---|---|---|
| Runtime | JavaScript | Node.js, Python |
| Execution location | 300+ edge locations | Regional edge caches (13) |
| Memory | 2 MB | 128 MB (viewer) / 10 GB (origin) |
| Timeout | 1 ms | 5s (viewer) / 30s (origin) |
| Network access | No | Yes |
| File system | No | Yes (read-only) |
| Request body access | No | Yes (origin events) |
| Cost | 1/6th of Lambda@Edge | Higher |
| Triggers | Viewer request/response | All 4 events |
| Max package | 10 KB | 1 MB (viewer) / 50 MB (origin) |

**Use CloudFront Functions for:**
- Cache key normalization
- Header manipulation
- URL rewrites/redirects
- JWT validation (simple)

**Use Lambda@Edge for:**
- Complex request processing
- A/B testing with different origins
- Image resizing/transformation
- Bot detection (needs network)
- Dynamic origin selection

---

### Price Classes

Not all edge locations cost the same. Price classes let you trade coverage for cost.

| Price Class | Coverage | Cost |
|---|---|---|
| Price Class All | All 300+ edge locations | Highest |
| Price Class 200 | Excludes most expensive (South America, Australia) | Medium |
| Price Class 100 | Only cheapest regions (NA, EU) | Lowest |

---

### Invalidation: Tell Post Offices to Dump Cached Copies

When content changes, cached copies at edge locations are stale. Invalidation forces removal.

```
aws cloudfront create-invalidation \
  --distribution-id EDFDVBD6EXAMPLE \
  --paths "/images/*" "/index.html"
```

**Key facts:**
- First 1,000 invalidation paths per month: free
- Additional: $0.005 per path
- Wildcards supported: `/images/*`
- Takes **1-2 minutes** to propagate globally
- **Alternative:** use versioned file names (`logo-v2.png`) — better than invalidation (free, instant, cacheable)

---

### Field-Level Encryption

Encrypt sensitive fields (like credit card numbers) at the edge, BEFORE reaching the origin.

```
User → CloudFront edge → Encrypt field "cc_number" → Forward to origin
                           (RSA public key)           (origin can't decrypt)
                                                       │
                                                   Only specific
                                                   microservice with
                                                   private key can
                                                   decrypt
```

- Additional layer beyond HTTPS
- Protects against compromised origin
- Use case: PCI compliance, sensitive personal data

---

### HTTPS Configuration

**Viewer Protocol Policy:**
- HTTP and HTTPS
- Redirect HTTP to HTTPS (most common)
- HTTPS only

**Origin Protocol Policy:**
- HTTP only
- HTTPS only
- Match viewer

**SSL Certificates:**
- Default CloudFront certificate (*.cloudfront.net)
- Custom SSL certificate (ACM, must be in **us-east-1**)
- SNI (Server Name Indication) — recommended, free
- Dedicated IP — for old clients that don't support SNI ($600/month)

---

### WAF Integration

Attach AWS WAF web ACL to a CloudFront distribution.

- Rate limiting
- IP blacklisting/whitelisting
- SQL injection / XSS protection
- Geo-blocking (more granular than CloudFront's built-in)
- Bot control

---

### Compression

- Gzip and Brotli compression supported
- Must be enabled in cache behavior
- Only compresses files between **1,000 bytes and 10 MB**
- Content-Type must be compressible (text, HTML, CSS, JS, JSON, etc.)
- Brotli is newer, better compression ratio

---

### Real-Time Logs

- Send logs to Kinesis Data Streams in real-time
- Choose which fields to log
- Can sample (e.g., log only 10% of requests)
- More granular than standard access logs (which go to S3)

---

## Architecture Diagram: Full CloudFront Setup

```
              Users Worldwide
              │   │   │   │
     ┌────────┘   │   │   └────────┐
     ▼            ▼   ▼            ▼
┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│ Edge    │ │ Edge    │ │ Edge    │ │ Edge    │
│ London  │ │ Tokyo   │ │ Sydney  │ │ NY      │
│         │ │         │ │         │ │         │
│ CF Func │ │ CF Func │ │ CF Func │ │ CF Func │
└────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘
     │           │           │           │
     └─────┬─────┘           └─────┬─────┘
           ▼                       ▼
    ┌──────────────┐      ┌──────────────┐
    │ Regional     │      │ Regional     │
    │ Edge Cache   │      │ Edge Cache   │
    │ (EU)         │      │ (AP)         │
    └──────┬───────┘      └──────┬───────┘
           │                     │
           └──────────┬──────────┘
                      ▼
           ┌─────────────────────┐
           │  ORIGIN GROUP       │
           │  ┌───────────────┐  │
           │  │ Primary: S3   │  │
           │  │ (us-east-1)   │  │
           │  ├───────────────┤  │
           │  │ Failover: S3  │  │
           │  │ (us-west-2)   │  │
           │  └───────────────┘  │
           └─────────────────────┘

  Security layers:
  WAF → CloudFront → OAC → S3 (private)
  Signed URLs/Cookies for premium content
  Geo-restriction for compliance
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- OAC vs OAI (always pick OAC for new builds)
- CloudFront + S3 for static website hosting
- Origin failover (origin groups)
- Signed URLs vs Signed Cookies
- SSL certificate must be in us-east-1 for CloudFront
- CloudFront vs S3 Transfer Acceleration (CloudFront for broad CDN, S3TA for upload acceleration)
- Price classes for cost optimization
- Field-level encryption for sensitive data
- Geo-restriction for content licensing

### DVA-C02 (Developer)
- Cache key configuration (query strings, headers, cookies)
- CloudFront Functions vs Lambda@Edge (selection criteria)
- Invalidation vs versioned URLs
- Signed URL generation in code (using key pair)
- Cache behavior configuration for different content types
- Viewer/origin protocol policies

### SOA-C02 (SysOps)
- Cache hit/miss ratio monitoring (CloudWatch)
- Invalidation management and cost
- Real-time logs to Kinesis Data Streams
- Standard access logs to S3
- WAF integration and rule management
- SSL certificate rotation (ACM auto-renewal)
- Price class selection for cost control
- Compression configuration and troubleshooting
- Error page customization (403, 404, 500)

---

## Key Numbers

| Metric | Value |
|---|---|
| Edge locations | 300+ globally |
| Regional edge caches | 13 |
| Default TTL | 86,400 seconds (24 hours) |
| Max TTL | 31,536,000 seconds (365 days) |
| Max file size | 30 GB (with multipart, otherwise 20 GB) |
| Free invalidation paths/month | 1,000 |
| Invalidation propagation | 1-2 minutes |
| CloudFront Functions timeout | 1 ms |
| CloudFront Functions memory | 2 MB |
| CloudFront Functions package | 10 KB |
| Lambda@Edge viewer timeout | 5 seconds |
| Lambda@Edge origin timeout | 30 seconds |
| Lambda@Edge viewer memory | 128 MB |
| Lambda@Edge origin memory | 10 GB |
| Compression range | 1,000 bytes — 10 MB |
| SSL cert location | us-east-1 (ACM) |
| Dedicated IP SSL cost | ~$600/month |
| Origin response timeout | 1-60 seconds (default 30) |
| Max origins per distribution | 25 |
| Max cache behaviors per distribution | 25 |
| Max alternate domain names | 100 per distribution |
| OAC (recommended) | Supports SSE-KMS, all regions |
| OAI (legacy) | Does NOT support SSE-KMS |

---

## Cheat Sheet

- CloudFront = CDN with 300+ edge locations. Caches content close to users.
- Origin = source (S3, ALB, EC2, custom HTTP). Can have multiple per distribution.
- OAC = restrict S3 access to CloudFront only. Replaces OAI. Always pick OAC.
- Cache behavior = rules per path pattern (/api/*, /images/*, default *).
- Cache key = URL + optional query strings/headers/cookies. Minimize for better hit ratio.
- TTL: origin headers win. Default 24h. Max 365 days.
- Signed URL = one file, time-limited. Signed Cookie = many files, time-limited.
- Geo-restriction = whitelist or blacklist countries.
- CloudFront Functions = lightweight JS, 1ms, viewer events only, 1/6 cost.
- Lambda@Edge = full runtime, 5s/30s, all 4 events, network access.
- Invalidation = force remove cached content. 1,000 free/month. Use versioned URLs instead.
- Price classes: All (global), 200 (skip expensive), 100 (cheapest regions only).
- SSL cert must be in us-east-1 for CloudFront.
- Origin groups = failover. Primary 5xx → automatic switch to secondary.
- Field-level encryption = encrypt sensitive fields at edge (above HTTPS).
- WAF attaches directly to CloudFront distribution.
- Compression: Gzip + Brotli. 1KB-10MB files only. Enable in cache behavior.
- Real-time logs → Kinesis Data Streams. Standard logs → S3.
- Viewer protocol: redirect HTTP→HTTPS is most common setting.
- S3 Transfer Acceleration != CloudFront. S3TA is for uploads. CloudFront is for downloads/caching.
