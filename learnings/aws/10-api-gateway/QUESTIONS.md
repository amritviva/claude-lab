# API Gateway — Exam Questions

> 12 scenario-based questions mixing SAA-C03, DVA-C02, and SOA-C02 perspectives.

---

### Q1 (SAA) — REST API vs HTTP API

A startup is building a serverless application with Lambda backends. They need JWT-based authentication, low latency, and want to minimize costs. They do NOT need caching, WAF, or usage plans. Which API type should they choose?

A. REST API with Lambda authorizer for JWT validation
B. HTTP API with JWT authorizer
C. REST API with Cognito authorizer
D. HTTP API with Lambda authorizer

**Answer: B**

**Why B is correct:** HTTP API has a native JWT authorizer — no Lambda invocation needed for auth. It's ~70% cheaper than REST API ($1/million vs $3.50/million), has lower latency, and meets all the requirements. Since they don't need caching, WAF, or usage plans (REST-only features), HTTP API is the clear winner. Like choosing the express counter over the full-service reception when you don't need the extras.

**Why A is wrong:** A Lambda authorizer works but adds Lambda invocation cost and latency for every request. REST API is also 3.5x more expensive.

**Why C is wrong:** Cognito authorizer is REST API only, and REST API is more expensive than HTTP API for features they don't need.

**Why D is wrong:** A Lambda authorizer on HTTP API works but is unnecessary when HTTP API has a native JWT authorizer built in. Extra Lambda invocations = extra cost and latency.

---

### Q2 (DVA) — Lambda Proxy Integration CORS

A developer deploys a Lambda function behind API Gateway (Lambda Proxy Integration). A React frontend at `app.example.com` calls the API at `api.example.com`. The browser shows a CORS error. The developer has enabled CORS in the API Gateway console. What is STILL missing?

A. The API Gateway needs a resource policy allowing the origin domain
B. The Lambda function must include CORS headers in its response
C. The CloudFront distribution needs CORS headers configured
D. The browser needs to be configured to allow cross-origin requests

**Answer: B**

**Why B is correct:** With Lambda Proxy Integration, API Gateway passes the entire request to Lambda and returns Lambda's response verbatim. Enabling CORS in the console only configures the OPTIONS preflight response. The actual GET/POST/etc response comes directly from Lambda — and Lambda must include `Access-Control-Allow-Origin` and other CORS headers itself. The receptionist can answer "yes, we accept visitors from that building" (OPTIONS), but the actual department (Lambda) must also stamp its letters with the right headers.

**Why A is wrong:** Resource policies control which AWS accounts or VPCs can call the API. They don't affect CORS.

**Why C is wrong:** CloudFront isn't mentioned in the architecture. Even if it were, CORS headers must come from the origin.

**Why D is wrong:** Browsers enforce CORS by design. You can't configure a browser to skip CORS checks (and you shouldn't).

---

### Q3 (SOA) — Throttling Strategy

A SysOps administrator manages an API Gateway REST API used by 3 partners. Partner A has a premium contract (1,000 req/s), Partner B has standard (100 req/s), and Partner C has basic (10 req/s). How should this be configured?

A. Create 3 separate API Gateway APIs with different throttle settings
B. Create 3 usage plans with API keys, each with different throttle limits
C. Use Lambda authorizer to throttle based on partner identity
D. Create 3 stages (premium, standard, basic) with different throttle limits

**Answer: B**

**Why B is correct:** Usage plans + API keys are purpose-built for this. Each partner gets an API key associated with a usage plan that defines their throttle rate and optional monthly quota. One API, one deployment, three different access tiers. Like giving each partner a different visitor pass that determines how fast the receptionist serves them.

**Why A is wrong:** Maintaining 3 separate APIs triples your management overhead. Same backend, same logic — just different throttle limits.

**Why C is wrong:** Lambda authorizer can identify partners but can't enforce throttle limits. Throttling is an API Gateway feature, not a Lambda feature.

**Why D is wrong:** Stages are for deployment environments (dev/prod), not client tiers. Partners shouldn't call different stages.

---

### Q4 (DVA) — Stage Variables + Lambda Aliases

A developer wants API Gateway's `prod` stage to invoke Lambda function version 5 and the `dev` stage to invoke `$LATEST`. How should this be configured WITHOUT creating separate API configurations?

A. Create two Lambda functions: one for prod, one for dev
B. Use stage variables to reference Lambda aliases; set `prod` stage variable to "live" alias (pointing to v5) and `dev` stage variable to "dev" alias (pointing to $LATEST)
C. Use different integration URIs in each stage
D. Create two deployments with hardcoded Lambda ARNs

**Answer: B**

**Why B is correct:** Stage variables let you parameterize the API configuration per stage. Set a stage variable `lambdaAlias` to "live" in prod and "dev" in dev. In the integration, reference `${stageVariables.lambdaAlias}`. The Lambda alias "live" points to v5, "dev" points to $LATEST. One API definition, stage variables control which Lambda version runs. Like having the same reception desk with a switch that changes which department it calls depending on whether it's the day or night shift.

**Why A is wrong:** Duplicate functions means duplicate code, duplicate config, duplicate maintenance. Stage variables avoid this.

**Why C is wrong:** You can't have different integration URIs per stage directly. Stage variables are the mechanism for this.

**Why D is wrong:** Hardcoded Lambda ARNs means you'd need a new deployment every time a version changes. Stage variables decouple API deployment from Lambda versions.

---

### Q5 (SAA) — Reducing Lambda Invocations

A REST API receives thousands of identical GET requests per minute for product catalog data that changes only once per hour. The API invokes Lambda for every request, causing high costs. What is the MOST cost-effective solution?

A. Enable API Gateway caching with a 1-hour TTL
B. Put CloudFront in front of API Gateway
C. Use DynamoDB DAX to cache product data
D. Increase Lambda memory to process requests faster

**Answer: A**

**Why A is correct:** API Gateway caching stores responses and returns cached data for identical requests. With a 1-hour TTL matching the data refresh rate, the Lambda function is invoked once per hour instead of thousands of times. Massive cost reduction. Like the receptionist writing down the answer and telling the next 1,000 visitors the same thing without calling the office.

**Why B is wrong:** CloudFront could help but adds architectural complexity and another layer to manage. API Gateway caching is built-in and simpler for this use case. (Note: on the real exam, if API Gateway caching isn't an option, CloudFront would be the next best.)

**Why C is wrong:** DAX caches DynamoDB reads, but the Lambda function is still invoked for every request. You reduce DynamoDB cost but not Lambda invocation cost.

**Why D is wrong:** Faster Lambda execution reduces per-invocation cost but doesn't reduce the number of invocations.

---

### Q6 (DVA) — AWS Service Integration

A developer needs to accept form submissions and queue them for processing. The current architecture (API Gateway → Lambda → SQS) works but the Lambda function only transforms the request and puts it in SQS. How can this be simplified?

A. Replace Lambda with Step Functions
B. Use API Gateway direct integration with SQS (AWS service integration)
C. Replace API Gateway with an ALB
D. Use Lambda Destinations to route to SQS

**Answer: B**

**Why B is correct:** API Gateway can integrate directly with AWS services. Configure a mapping template (VTL) to transform the HTTP request into an SQS SendMessage action. No Lambda needed — eliminates the middleman, reduces cost and latency. The receptionist can put mail directly into the mailbox instead of calling an assistant to do it.

**Why A is wrong:** Step Functions adds complexity. The problem is a simple passthrough — you want LESS infrastructure, not more.

**Why C is wrong:** ALB can't integrate directly with SQS. You'd still need Lambda or a backend server.

**Why D is wrong:** Destinations route Lambda output after execution. The goal is to eliminate Lambda entirely.

---

### Q7 (SOA) — Troubleshooting 504 Errors

Users are intermittently receiving 504 Gateway Timeout errors from an API Gateway REST API backed by Lambda. CloudWatch shows Lambda executions completing in 25-35 seconds. What is the root cause?

A. Lambda is hitting its 15-minute timeout
B. API Gateway's integration timeout of 29 seconds is being exceeded
C. The client is timing out before the response arrives
D. API Gateway's throttle limit is causing requests to queue too long

**Answer: B**

**Why B is correct:** API Gateway has a **hard limit of 29 seconds** for ALL integration types (including Lambda). If Lambda takes 30+ seconds, API Gateway returns 504 before Lambda finishes. Lambda completes successfully (no Lambda error), but the response never reaches the client. Like the receptionist hanging up the phone after 29 seconds — even if the department answers at second 30.

**Why A is wrong:** Lambda functions are completing in 25-35 seconds, well within the 15-minute limit. Lambda isn't timing out.

**Why C is wrong:** The error is 504 from API Gateway, not a client-side timeout. The problem is between API Gateway and Lambda.

**Why D is wrong:** Throttling returns 429 (Too Many Requests), not 504 (Gateway Timeout).

---

### Q8 (SAA) — Authorizer Selection

A company has an existing Active Directory for employee authentication. They need to protect an API that's called by an internal dashboard. Users sign in via SAML federation to an OIDC-compatible identity provider. Which authorizer type is BEST?

A. IAM authorizer with temporary STS credentials
B. Cognito authorizer with a User Pool
C. Lambda authorizer that validates tokens against Active Directory
D. JWT authorizer on HTTP API (validating OIDC tokens)

**Answer: D**

**Why D is correct:** Since they already have an OIDC-compatible identity provider (via SAML federation), HTTP API's native JWT authorizer can validate tokens directly. No extra infrastructure needed — just configure the issuer URL and audience. Cheapest and simplest option. Like the reception desk having a hotline to verify government IDs directly.

**Why A is wrong:** IAM authorizer requires SigV4 signing, which means the frontend would need AWS credentials. More complex than JWT for a web dashboard.

**Why B is wrong:** Cognito User Pool would be a separate identity system. They already have Active Directory — adding Cognito creates redundancy.

**Why C is wrong:** Lambda authorizer works but adds Lambda invocation cost for every request. The native JWT authorizer on HTTP API is free (no extra compute).

---

### Q9 (DVA) — Request Validation

A developer's REST API receives a POST /orders endpoint with a JSON body. Many Lambda invocations fail because clients send incomplete data (missing `productId` or `quantity`). How can the developer reduce wasted Lambda invocations?

A. Add validation logic in the Lambda handler
B. Configure request validation with a JSON Schema model in API Gateway
C. Use a Lambda authorizer to validate request bodies
D. Add a WAF rule to block malformed requests

**Answer: B**

**Why B is correct:** API Gateway request validation checks the request body against a JSON Schema model BEFORE invoking Lambda. Invalid requests get a 400 Bad Request immediately — Lambda never sees them. Saves Lambda invocations and cost. Like the receptionist checking if the visitor has all required documents before letting them in.

**Why A is wrong:** Lambda validation works but the invocation still happens (and you pay for it). The goal is to PREVENT unnecessary invocations.

**Why C is wrong:** Lambda authorizers are for authentication/authorization, not request body validation.

**Why D is wrong:** WAF rules inspect request patterns for security threats (SQL injection, XSS), not business logic validation.

---

### Q10 (SAA) — 29-Second Limit Workaround

An API endpoint triggers a long-running process (2-3 minutes). The API Gateway 29-second timeout makes synchronous invocation impossible. What is the BEST architecture?

A. Increase the API Gateway timeout to 5 minutes
B. Use API Gateway → Lambda → start Step Functions execution, return execution ARN immediately
C. Use WebSocket API for long-running requests
D. Use API Gateway → SQS → Lambda with a separate status check endpoint

**Answer: D**

**Why D is correct:** The async pattern: (1) API Gateway receives the request and puts it in SQS (or invokes Lambda async). (2) Return a 202 Accepted with a job ID immediately (under 29s). (3) Lambda processes the job in the background. (4) Client polls a separate GET /status/{jobId} endpoint. This decouples the response time from the processing time. Like the receptionist giving you a ticket number and saying "come back in 5 minutes" instead of making you wait.

Note: Option B is also a valid pattern (Step Functions for orchestration). But D is simpler and more common for straightforward async processing. On the real exam, read both options carefully.

**Why A is wrong:** The 29-second limit is a HARD limit. It cannot be increased.

**Why B is wrong:** This is a valid pattern but more complex than needed for a single long-running task. Step Functions are better for multi-step workflows.

**Why C is wrong:** WebSocket is for real-time bidirectional communication, not for working around timeout limits on REST-style operations.

---

### Q11 (SOA) — Cache Invalidation

A SysOps administrator has API Gateway caching enabled with a 1-hour TTL. A critical product price change needs to be reflected immediately. How can the cache be invalidated?

A. Restart the API Gateway stage
B. Send a request with `Cache-Control: max-age=0` header (requires proper IAM authorization)
C. Delete and recreate the stage
D. Wait for the TTL to expire

**Answer: B**

**Why B is correct:** Clients can invalidate the cache by sending `Cache-Control: max-age=0`. However, API Gateway requires the caller to have IAM authorization to invalidate the cache (to prevent abuse). You can also require `Authorization` header for cache invalidation in the stage settings. Like telling the receptionist "throw away that memo and get a fresh one" — but only authorized staff can make that request.

**Why A is wrong:** You can't "restart" an API Gateway stage. It's serverless — there's no instance to restart.

**Why C is wrong:** Destructive and causes downtime. This is like burning down the reception desk to clear a memo.

**Why D is wrong:** Waiting up to 1 hour for a critical price change is unacceptable.

---

### Q12 (DVA) — Mock Integration

A frontend team needs to start development against API endpoints that haven't been built yet. The backend team will deliver the Lambda functions in 2 weeks. What is the BEST approach?

A. Deploy placeholder Lambda functions that return hardcoded responses
B. Configure Mock integrations in API Gateway that return sample responses
C. Use a separate mock server (e.g., json-server) running on EC2
D. Have the frontend team hardcode mock data in the React app

**Answer: B**

**Why B is correct:** Mock integrations return predefined responses without any backend. Define the response using mapping templates — the frontend team can develop against real API Gateway endpoints with realistic responses. When the backend is ready, swap Mock integration for Lambda integration. Zero infrastructure to manage. Like the receptionist giving out a pre-written FAQ sheet instead of calling the office.

**Why A is wrong:** Deploying placeholder Lambdas works but adds unnecessary cost and complexity. You're paying for Lambda invocations to return hardcoded data.

**Why C is wrong:** Running a mock server on EC2 means managing infrastructure for temporary test data.

**Why D is wrong:** Hardcoded frontend mocks don't test the actual API contract (headers, status codes, error handling). Mock integrations provide a more realistic development experience.
