# API Gateway — The Reception Desk

> **In the AWS Country, API Gateway is the reception desk at the front of your building.** Every visitor (request) must pass through it. The receptionist checks credentials, applies rules, and routes visitors to the right department (backend service).

---

## ELI10

Imagine a big office building with hundreds of rooms inside. Visitors can't just walk in and wander around. They go to the reception desk first. The receptionist checks their ID, looks up where they need to go, and sends them to the right room. If too many visitors show up at once, the receptionist makes them wait in line. If the same question keeps getting asked, the receptionist writes down the answer so they don't have to bother the office again. That's API Gateway — the front door to your backend.

---

## The Concept

### Three Types of Reception Desks

```
┌─────────────────────────────────────────────────────────────┐
│                    API GATEWAY TYPES                         │
│                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   REST API      │  │   HTTP API      │  │ WebSocket API│ │
│  │                 │  │                 │  │              │ │
│  │ Full-service    │  │ Express counter │  │ Two-way      │ │
│  │ reception       │  │ (~70% cheaper)  │  │ intercom     │ │
│  │                 │  │                 │  │              │ │
│  │ • Caching       │  │ • JWT/OIDC auth │  │ • Persistent │ │
│  │ • WAF           │  │ • CORS auto     │  │   connection │ │
│  │ • Usage plans   │  │ • Lambda/HTTP   │  │ • Chat, game │ │
│  │ • API keys      │  │   integrations  │  │   dashboards │ │
│  │ • Request valid  │  │ • Cheaper       │  │ • Real-time  │ │
│  │ • Canary deploy │  │ • Faster        │  │   updates    │ │
│  │ • Resource      │  │ • No caching    │  │              │ │
│  │   policies      │  │ • No WAF        │  │              │ │
│  │ • Mock integr.  │  │ • No usage plans│  │              │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### REST API vs HTTP API — Exam Decision Table

| Feature | REST API | HTTP API |
|---|---|---|
| Price | $3.50/million | $1.00/million (~70% cheaper) |
| Caching | Yes (0.5-237 GB) | No |
| WAF integration | Yes | No |
| Usage plans + API keys | Yes | No |
| Request validation | Yes | No |
| Request/response transform | Yes | No (limited parameter mapping) |
| Resource policies | Yes | No |
| Mock integrations | Yes | No |
| Canary deployments | Yes | No |
| JWT/OIDC authorizer | No (use Lambda or Cognito) | Yes (native) |
| Private integrations | VPC Link (NLB) | VPC Link (ALB, NLB, Cloud Map) |
| Latency | Higher | Lower |

**Exam rule of thumb:** Use REST API when you need caching, WAF, API keys, or request validation. Use HTTP API when you need simple proxy to Lambda/HTTP backends and want to save cost.

---

### Integration Types

```
Client → API Gateway → Integration (backend)

┌─────────────────────────────────────────────────────────────┐
│                    INTEGRATION TYPES                         │
│                                                              │
│  LAMBDA PROXY (most common)                                  │
│  ┌─────────┐   entire request    ┌──────────┐               │
│  │ API GW  │───────────────────▶│ Lambda   │               │
│  │         │◀───────────────────│ Function │               │
│  └─────────┘   Lambda formats   └──────────┘               │
│                response itself                               │
│                                                              │
│  LAMBDA CUSTOM                                               │
│  ┌─────────┐   transformed req   ┌──────────┐               │
│  │ API GW  │──── mapping ───────▶│ Lambda   │               │
│  │         │◀─── template ──────│ Function │               │
│  └─────────┘   API GW transforms └──────────┘               │
│                request/response                              │
│                                                              │
│  HTTP PROXY                                                  │
│  ┌─────────┐   pass-through      ┌──────────┐               │
│  │ API GW  │───────────────────▶│ HTTP     │               │
│  │         │◀───────────────────│ endpoint │               │
│  └─────────┘                     └──────────┘               │
│                                                              │
│  AWS SERVICE                                                 │
│  ┌─────────┐   direct call       ┌──────────┐               │
│  │ API GW  │───────────────────▶│ SQS/SNS/ │               │
│  │         │◀───────────────────│ DynamoDB │               │
│  └─────────┘   no Lambda needed! └──────────┘               │
│                                                              │
│  MOCK                                                        │
│  ┌─────────┐   returns fixed     (no backend)               │
│  │ API GW  │   response                                     │
│  └─────────┘                                                 │
└─────────────────────────────────────────────────────────────┘
```

**Lambda Proxy Integration** (exam favorite):
- API Gateway sends the ENTIRE request (headers, body, path, query params) as a JSON event to Lambda
- Lambda MUST return response in a specific format: `{ statusCode, headers, body }`
- Most common pattern — "receptionist hands the entire envelope to the department"
- No request/response transformation in API Gateway

**AWS Service Integration** (direct integration):
- Skip Lambda entirely — API Gateway calls AWS services directly
- Example: POST /messages → puts message directly into SQS queue
- Reduces cost and latency (no Lambda invocation)
- Requires mapping templates (VTL — Velocity Template Language)

---

### Stages: Different Reception Desks

Stages are named references to a deployment. Like having separate reception desks for different purposes.

```
https://abc123.execute-api.us-east-1.amazonaws.com/dev/users
https://abc123.execute-api.us-east-1.amazonaws.com/staging/users
https://abc123.execute-api.us-east-1.amazonaws.com/prod/users
                                                    ^^^^
                                                    stage
```

**Key facts:**
- Each stage has its own URL
- Stage variables = environment-specific config (like which Lambda alias to invoke)
- Stage variables can reference Lambda aliases: `${stageVariables.lambdaAlias}`
- Deployment = snapshot of API config. Stage = pointer to a deployment.
- Can enable canary on a stage: route X% of traffic to canary deployment

### Canary Deployments

```
Stage: prod
├── Main deployment (90% traffic) → Lambda:v3
└── Canary deployment (10% traffic) → Lambda:v4

After validation:
└── Promote canary → 100% traffic → Lambda:v4
```

---

### Usage Plans + API Keys: Visitor Passes

Control who can access your API and how much they can use it.

```
┌───────────────────────────────────────────────────┐
│                 USAGE PLAN                         │
│                                                    │
│  Name: "Premium Plan"                              │
│  Throttle: 100 req/s, burst 200                    │
│  Quota: 10,000 req/month                           │
│  Associated stages: prod                           │
│                                                    │
│  API Keys attached:                                │
│  ┌──────────────────┐  ┌──────────────────┐        │
│  │ Key: partner-A   │  │ Key: partner-B   │        │
│  │ abc123...        │  │ def456...        │        │
│  └──────────────────┘  └──────────────────┘        │
└───────────────────────────────────────────────────┘
```

**Key facts:**
- API Keys are NOT for authentication (they're for tracking/throttling)
- API Key sent via `x-api-key` header
- Usage plans define throttle limits and quotas per key
- For authentication, use Authorizers (IAM, Cognito, Lambda)

---

### Throttling

```
Account-level: 10,000 req/s across all APIs
                5,000 burst limit
                │
Stage-level:    Can set lower limits per stage
                │
Method-level:   Can set lower limits per method
                │
Usage plan:     Per-client throttle via API key
```

**Key numbers:**
- **10,000 requests/second** soft limit (account level, per region)
- **5,000 burst** capacity
- 429 Too Many Requests = throttled
- Can request limit increase via AWS Support

---

### Caching (REST API Only)

Cache responses at the API Gateway level to reduce calls to your backend.

```
Client ──▶ API Gateway ──▶ Cache HIT? ──▶ Return cached response
                              │
                              NO (cache MISS)
                              │
                              ▼
                         Backend (Lambda/HTTP)
                              │
                              ▼
                         Store in cache + return response
```

**Key facts:**
- Cache size: **0.5 GB to 237 GB**
- Default TTL: **300 seconds** (5 min), max 3,600 seconds (1 hour)
- Per-stage configuration
- Can invalidate cache with `Cache-Control: max-age=0` header (requires IAM authorization)
- Cache key: method + resource path (can include headers, query strings)
- Costs extra (cache instance runs 24/7)
- NOT available on HTTP API

---

### CORS: Permission for Visitors from Other Buildings

Cross-Origin Resource Sharing — when a browser on domain A calls your API on domain B.

```
Browser (app.example.com) → API Gateway (api.example.com)
                             │
                             Must return CORS headers:
                             Access-Control-Allow-Origin
                             Access-Control-Allow-Methods
                             Access-Control-Allow-Headers
```

**For Lambda Proxy Integration:**
- API Gateway does NOT add CORS headers automatically
- Lambda function MUST return CORS headers in its response
- Enable CORS on API Gateway for preflight (OPTIONS) requests

**For Lambda Custom / HTTP integrations:**
- API Gateway can add CORS headers via the console configuration

---

### Authorizers

```
┌─────────────────────────────────────────────────────────────┐
│                    AUTHORIZER TYPES                           │
│                                                              │
│  IAM AUTHORIZER                                              │
│  • Uses SigV4 signed requests                                │
│  • Best for: AWS-to-AWS calls, internal services             │
│  • Checks IAM policy attached to caller                      │
│                                                              │
│  COGNITO AUTHORIZER (REST API)                               │
│  • Validates JWT token from Cognito User Pool                │
│  • Best for: user-facing apps with Cognito auth              │
│  • No custom code needed                                     │
│                                                              │
│  LAMBDA AUTHORIZER (custom)                                  │
│  • Your Lambda function validates token/params               │
│  • Returns IAM policy document                               │
│  • Best for: third-party auth, custom logic                  │
│  • Two types:                                                │
│    - TOKEN: receives auth header                             │
│    - REQUEST: receives headers, query params, context        │
│  • Can cache auth policy (default 300s)                      │
│                                                              │
│  JWT AUTHORIZER (HTTP API only)                              │
│  • Native JWT validation (Cognito or any OIDC provider)      │
│  • Simpler than Lambda authorizer                            │
│  • No Lambda invocation cost                                 │
└─────────────────────────────────────────────────────────────┘
```

---

### Request/Response Transformation (REST API)

Using **mapping templates** (VTL — Velocity Template Language):
- Transform request before sending to backend
- Transform response before returning to client
- Used with non-proxy integrations
- Example: flatten a nested JSON, rename fields, add default values

### Request Validation (REST API)

- Validate request parameters and body BEFORE invoking backend
- Returns 400 Bad Request if validation fails
- Reduces unnecessary Lambda invocations
- Can validate: required query params, headers, body against JSON Schema

---

### Custom Domain Names

```
Instead of: https://abc123.execute-api.us-east-1.amazonaws.com/prod/
Use:        https://api.mycompany.com/v1/

Requires:
1. ACM certificate (in us-east-1 for edge-optimized, same region for regional)
2. Custom domain name in API Gateway
3. Base path mapping: /v1 → API + stage
4. Route 53 alias record (or CNAME with other DNS)
```

**Endpoint types:**
- **Edge-optimized:** CloudFront in front, ACM cert must be in us-east-1
- **Regional:** No CloudFront, ACM cert in same region
- **Private:** Only accessible from within a VPC (via VPC endpoint)

---

### Binary Payloads

- API Gateway can handle binary data (images, PDFs, etc.)
- Must configure `binaryMediaTypes` in API settings
- Content-Type header determines if payload is binary
- Base64 encoding/decoding for Lambda proxy integration

---

## Architecture Diagram: Full API Gateway Setup

```
                    Internet
                       │
              ┌────────┴────────┐
              │   Custom Domain │
              │  api.myco.com   │
              │  (Route 53 +   │
              │   ACM cert)    │
              └────────┬────────┘
                       │
              ┌────────┴────────┐
              │   API Gateway   │
              │                 │
              │ ┌─Authorizer──┐ │
              │ │ Cognito/IAM │ │
              │ │ Lambda      │ │
              │ └─────────────┘ │
              │                 │
              │ ┌─Throttle────┐ │
              │ │ 10K req/s   │ │
              │ │ Usage plans │ │
              │ └─────────────┘ │
              │                 │
              │ ┌─Cache────────┐│
              │ │ 0.5-237 GB  ││
              │ │ TTL 300s    ││
              │ └─────────────┘│
              │                 │
              │  Stage: /prod   │
              └──┬────┬────┬───┘
                 │    │    │
          ┌──────┘    │    └──────┐
          ▼           ▼           ▼
     ┌─────────┐ ┌─────────┐ ┌─────────┐
     │ Lambda  │ │  HTTP   │ │  AWS    │
     │ Proxy   │ │ Backend │ │ Service │
     │         │ │ (ALB)   │ │ (SQS)  │
     └─────────┘ └─────────┘ └─────────┘
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- REST API vs HTTP API selection criteria
- API Gateway + Lambda = serverless architecture
- Caching to reduce Lambda invocations and cost
- Authorizer selection (IAM vs Cognito vs Lambda)
- Throttling strategy for multi-tenant APIs
- Custom domain + ACM certificate configuration
- Edge-optimized vs Regional vs Private endpoints
- Direct AWS service integration (skip Lambda)

### DVA-C02 (Developer)
- Lambda Proxy integration (event format, response format)
- Stage variables + Lambda aliases (deployment strategy)
- CORS configuration (Lambda must return headers)
- Mapping templates (VTL) for request/response transformation
- Request validation (body model, required parameters)
- API key usage (x-api-key header)
- Binary payload handling (binaryMediaTypes)
- Error handling (Integration Response, Gateway Responses)

### SOA-C02 (SysOps)
- Throttling limits and configuration hierarchy
- CloudWatch metrics: 4XXError, 5XXError, Latency, Count, CacheHitCount, CacheMissCount
- Cache invalidation and TTL configuration
- Usage plan monitoring and reporting
- Access logging and execution logging (CloudWatch Logs)
- WAF integration (REST API only)
- Certificate management for custom domains
- Canary deployment monitoring

---

## Key Numbers

| Metric | Value |
|---|---|
| Account-level throttle | 10,000 req/s (soft limit) |
| Burst limit | 5,000 requests |
| REST API price | $3.50 per million requests |
| HTTP API price | $1.00 per million requests |
| WebSocket API price | $1.00 per million messages + $0.25 per million connection min |
| Cache size | 0.5 GB — 237 GB |
| Cache default TTL | 300 seconds (5 min) |
| Cache max TTL | 3,600 seconds (1 hour) |
| Max payload size | 10 MB |
| Max timeout | 29 seconds (hard limit for all integrations) |
| Lambda authorizer cache TTL | 0-3,600 seconds (default 300s) |
| Max API keys per account | 10,000 |
| Max usage plans per account | 300 |
| Max stages per API | 10 |
| Custom domain base path mappings | 300 per domain |

---

## Cheat Sheet

- API Gateway = managed API front door. REST, HTTP, or WebSocket.
- REST API = full features (cache, WAF, API keys, transforms). HTTP API = cheap & fast.
- Lambda Proxy = most common. Entire request goes to Lambda. Lambda formats response.
- AWS Service integration = skip Lambda, call SQS/DynamoDB/etc directly.
- Stages = deployment environments (dev/staging/prod). Each has own URL.
- Stage variables = per-environment config. Combine with Lambda aliases.
- API Keys = tracking/throttling, NOT authentication.
- Authorizers: IAM (AWS-to-AWS), Cognito (user pools), Lambda (custom), JWT (HTTP API).
- Throttle: 10K req/s account, 5K burst. Per-stage and per-method overrides.
- Cache: 0.5-237 GB, 300s default TTL. REST API only.
- CORS: With Lambda Proxy, Lambda MUST return CORS headers.
- Max timeout: 29 seconds. If backend is slower, use async (SQS).
- Max payload: 10 MB. For larger, use S3 pre-signed URLs.
- Custom domain: ACM cert required. us-east-1 for edge-optimized.
- Canary: route X% to new deployment. Validate before promoting.
- Request validation saves Lambda invocations (returns 400 at gateway level).
- Mock integration = return fixed response, no backend needed.
