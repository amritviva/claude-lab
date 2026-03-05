# AI Support Chat — Business Requirements Document

> **Status:** Draft / Planning Phase
> **Author:** Amrit Regmi
> **Created:** 2026-02-26
> **Last Updated:** 2026-02-26
> **Version:** 0.1

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Statement](#2-problem-statement)
3. [Proposed Solution](#3-proposed-solution)
4. [Scope & Boundaries](#4-scope--boundaries)
5. [Architecture Overview](#5-architecture-overview)
6. [Authentication & Authorization](#6-authentication--authorization)
7. [Data Access & Safety Rules](#7-data-access--safety-rules)
8. [Database Schema — Chat Storage](#8-database-schema--chat-storage)
9. [API Design](#9-api-design)
10. [LLM Integration](#10-llm-integration)
11. [Domain Model Reference](#11-domain-model-reference)
12. [Frontend Integration](#12-frontend-integration)
13. [Infrastructure & Deployment](#13-infrastructure--deployment)
14. [Security Considerations](#14-security-considerations)
15. [Scalability & Future Scope](#15-scalability--future-scope)
16. [Open Questions & Decisions](#16-open-questions--decisions)
17. [Risks & Mitigations](#17-risks--mitigations)
18. [Appendix](#appendix)

---

## 1. Executive Summary

We propose adding an AI-powered support chatbot to The Hub, hosted within the MiniHub Express API. The chatbot allows club staff (managers, area managers, etc.) to ask natural language questions about members, payments, contracts, and billing — and receive instant answers backed by real database queries.

The goal is to **reduce the volume of support tickets** flowing into the support channel by giving staff a self-service interface where they can get answers immediately. If the chatbot cannot answer, it directs the user to contact support via email.

**Key constraints:**
- **Read-only.** The system will NEVER write to, update, or delete any existing Hub data.
- **Role-scoped.** Every query is scoped to the user's permitted locations.
- **Auditable.** Every conversation is stored for review and compliance.

---

## 2. Problem Statement

- ~270 club locations generate a high volume of support tickets.
- Many tickets are routine data lookups: "Why was this member charged $X?", "What card was used?", "Is this contract active?"
- Support staff spend significant time on queries that could be answered by reading the database.
- Club staff don't have direct database access and rely on support for data they should be able to self-serve.

**Desired outcome:** A single interface where club staff can ask questions and get answers before escalating to support.

---

## 3. Proposed Solution

An AI chat module integrated into MiniHub that:

1. Accepts natural language questions from authenticated Hub users
2. Understands the user's role and location access
3. Generates read-only SQL queries against the Hub's Postgres replica
4. Returns human-readable answers
5. Stores all conversations in DynamoDB for audit and continuity
6. Escalates to human support when it cannot answer

---

## 4. Scope & Boundaries

### In Scope (Phase 1)

| Feature | Description |
|---------|-------------|
| Natural language Q&A | Staff ask questions, get answers from database |
| Member lookups | Search by name, email, alias ID, mobile |
| Payment inquiries | Batch payments, rejections, transactions, card details |
| Contract status | Active/cancelled/suspended, billing details |
| Location-scoped access | Users only see data for their permitted locations |
| Conversation history | Stored in DynamoDB, retrievable per user |
| Escalation | Clear path to email support when bot can't help |

### Out of Scope (explicitly excluded)

| Feature | Reason |
|---------|--------|
| Any write/update/delete operations | Safety — read-only by design |
| Refund processing | Requires write access + business logic |
| Member creation or modification | Handled by existing Hub flows |
| Door access / key card management | Separate system |
| Class booking management | Separate module |
| Automated email sending | Out of scope for Phase 1 |
| Modifications to vivareact or vivaamplify repos | Isolated to minihub only |

---

## 5. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     THE HUB (vivareact)                          │
│                                                                  │
│  ┌──────────────┐     ┌───────────────────────────────────┐     │
│  │ Cognito Auth  │     │  ChatWindow Component              │     │
│  │ (existing)    │────▶│  - Conversation UI                 │     │
│  │ JWT token     │     │  - Message input                   │     │
│  └──────────────┘     │  - History sidebar                 │     │
│                        │  - "Contact Support" button        │     │
│                        └──────────────┬────────────────────┘     │
│                                       │                           │
│                     POST /api/v1/chat │                           │
│                     Auth: Bearer <JWT>│                           │
└───────────────────────────────────────┼─────────────────────────┘
                                        │
                                        │ HTTPS
                                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                   MINIHUB (Express API — App Runner)              │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  Cognito JWT Auth Middleware (NEW)                          │ │
│  │  - Verify JWT via JWKS (same pattern as hub-insights)      │ │
│  │  - Extract: memberId, cognito:groups, role                 │ │
│  │  - Resolve allowed locations (from Postgres)               │ │
│  └──────────────────────────┬─────────────────────────────────┘ │
│                              │                                    │
│  ┌──────────────────────────▼─────────────────────────────────┐ │
│  │  Chat Module (NEW)                                          │ │
│  │                                                              │ │
│  │  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐  │ │
│  │  │ Chat Handler │─▶│ Chat Service  │─▶│ LLM Service       │  │ │
│  │  │ (routes)     │  │ (business    │  │ (Anthropic/OpenAI)│  │ │
│  │  └─────────────┘  │  logic)       │  └────────┬─────────┘  │ │
│  │                    └──────┬───────┘           │              │ │
│  │                           │                    │              │ │
│  │                    ┌──────▼───────┐    ┌──────▼─────────┐  │ │
│  │                    │ Query        │    │ SQL Validator   │  │ │
│  │                    │ Executor     │    │ (SELECT only)   │  │ │
│  │                    └──────┬───────┘    └────────────────┘  │ │
│  │                           │                                  │ │
│  └───────────────────────────┼──────────────────────────────────┘ │
│                              │                                    │
│  ┌───────────────────────────▼──────────────────────────────────┐ │
│  │  Data Layer                                                    │ │
│  │                                                                │ │
│  │  ┌─────────────────────┐    ┌──────────────────────────┐     │ │
│  │  │ Postgres (READ ONLY) │    │ DynamoDB                  │     │ │
│  │  │ Hevo Replica         │    │ chat_sessions table (NEW) │     │ │
│  │  │                      │    │ chat_messages table (NEW) │     │ │
│  │  │ • member             │    │                            │     │ │
│  │  │ • location           │    │ Stores all conversations  │     │ │
│  │  │ • brand              │    │ for audit & continuity    │     │ │
│  │  │ • batch_payment      │    └──────────────────────────┘     │ │
│  │  │ • rejection_payment  │                                      │ │
│  │  │ • transaction        │                                      │ │
│  │  │ • payment_information│                                      │ │
│  │  │ • member_contract    │                                      │ │
│  │  │ • member_contract_   │                                      │ │
│  │  │   billing            │                                      │ │
│  │  │ • group_staff        │                                      │ │
│  │  │ • group_location     │                                      │ │
│  │  └─────────────────────┘                                      │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │  External: LLM Provider API (Anthropic Claude / OpenAI)        │ │
│  │  Called server-side only. API key stored in env vars.          │ │
│  └────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

### Request Flow (Sequence)

```
User                Frontend            MiniHub             LLM              Postgres       DynamoDB
 │                    │                   │                  │                  │               │
 │ "Why was John     │                   │                  │                  │               │
 │  charged $50?"    │                   │                  │                  │               │
 │──────────────────▶│                   │                  │                  │               │
 │                    │ POST /api/v1/chat │                  │                  │               │
 │                    │ + JWT Bearer      │                  │                  │               │
 │                    │──────────────────▶│                  │                  │               │
 │                    │                   │                  │                  │               │
 │                    │                   │ 1. Verify JWT    │                  │               │
 │                    │                   │ 2. Extract memberId, role          │               │
 │                    │                   │──────────────────────────────────▶│               │
 │                    │                   │ 3. Resolve allowed locations       │               │
 │                    │                   │◀──────────────────────────────────│               │
 │                    │                   │                  │                  │               │
 │                    │                   │──────────────────────────────────────────────────▶│
 │                    │                   │ 4. Load conversation history from DynamoDB        │
 │                    │                   │◀──────────────────────────────────────────────────│
 │                    │                   │                  │                  │               │
 │                    │                   │──────────────────────────────────────────────────▶│
 │                    │                   │ 5. Save user message to DynamoDB                  │
 │                    │                   │◀──────────────────────────────────────────────────│
 │                    │                   │                  │                  │               │
 │                    │                   │ 6. Build prompt  │                  │               │
 │                    │                   │   + schema ref   │                  │               │
 │                    │                   │   + location IDs │                  │               │
 │                    │                   │   + history      │                  │               │
 │                    │                   │─────────────────▶│                  │               │
 │                    │                   │                  │                  │               │
 │                    │                   │ 7. LLM returns   │                  │               │
 │                    │                   │   SQL + answer   │                  │               │
 │                    │                   │◀─────────────────│                  │               │
 │                    │                   │                  │                  │               │
 │                    │                   │ 8. Validate SQL (SELECT only)      │               │
 │                    │                   │──────────────────────────────────▶│               │
 │                    │                   │ 9. Execute query                   │               │
 │                    │                   │◀──────────────────────────────────│               │
 │                    │                   │                  │                  │               │
 │                    │                   │ 10. Format       │                  │               │
 │                    │                   │   results        │                  │               │
 │                    │                   │─────────────────▶│                  │               │
 │                    │                   │◀─────────────────│                  │               │
 │                    │                   │                  │                  │               │
 │                    │                   │──────────────────────────────────────────────────▶│
 │                    │                   │ 11. Save assistant message to DynamoDB            │
 │                    │                   │◀──────────────────────────────────────────────────│
 │                    │                   │                  │                  │               │
 │                    │ 12. Response JSON │                  │                  │               │
 │                    │◀──────────────────│                  │                  │               │
 │ "John was charged  │                   │                  │                  │               │
 │  $50 on 15/02 for │                   │                  │                  │               │
 │  his DD billing..." │                  │                  │                  │               │
 │◀──────────────────│                   │                  │                  │               │
```

---

## 6. Authentication & Authorization

### Authentication: Cognito JWT (No API Key Exposure)

The frontend will **NOT** use the existing MiniHub API key. Instead, it will pass the user's Cognito JWT token (which the frontend already has from the existing auth flow).

MiniHub will add a **new Cognito JWT verification middleware** (following the same pattern already used in hub-insights):

```
Frontend (vivareact)
  → Already authenticates via Cognito
  → Already has JWT token (Auth.currentSession().getIdToken().getJwtToken())
  → Sends: Authorization: Bearer <JWT>

MiniHub (new middleware)
  → Fetches JWKS from Cognito User Pool
  → Verifies JWT signature
  → Extracts: custom:memberId, cognito:groups
  → Attaches to request object
```

**Reference implementation:** `hub-insights/app/src/middleware/authorization.ts`

### Authorization: Location-Scoped Access

After JWT verification, the system resolves the user's allowed locations:

```sql
-- Resolve staff's allowed locations via group membership
SELECT DISTINCT gl.location_id
FROM group_staff gs
JOIN "group" g ON g.id = gs.group_id
JOIN group_location gl ON gl.group_id = g.id
WHERE gs.member_id = $1  -- the authenticated user's memberId
  AND (gs.__hevo__marked_deleted IS NULL OR gs.__hevo__marked_deleted = false)
  AND (gl.__hevo__marked_deleted IS NULL OR gl.__hevo__marked_deleted = false)
```

These location IDs are injected into **every** database query the LLM generates.

### Role Hierarchy

| Role | Level | Chat Access | Scope |
|------|-------|-------------|-------|
| L0 | Member app user | ❌ No chat access | — |
| L1 | Basic staff | ✅ Read-only queries | Own location(s) via groups |
| L2 | Staff + | ✅ Read-only queries | Own location(s) via groups |
| L3 | Manager | ✅ Read-only queries | Own location(s) via groups |
| L4 | Area Manager | ✅ Read-only queries | Multiple locations via groups |
| L5 | Senior Admin | ✅ Read-only queries | All assigned locations |
| admin | Admin | ✅ Read-only queries | Broad access |
| super-admin | Super Admin | ✅ Read-only queries | All locations |

**Minimum role for chat access:** L1 (configurable)

---

## 7. Data Access & Safety Rules

### ⛔ MANDATORY RULES — NON-NEGOTIABLE

These rules are enforced at **every layer** of the system:

#### Rule 1: READ-ONLY — SELECT ONLY

```
The system MUST NEVER execute any SQL statement other than SELECT.
No INSERT, UPDATE, DELETE, DROP, ALTER, TRUNCATE, CREATE, or any DDL/DML.
```

**Enforcement layers:**
1. **Postgres user** — connected with a read-only database user (SELECT grants only)
2. **SQL validator** — parses every generated query; rejects non-SELECT statements
3. **LLM system prompt** — instructs the model to generate only SELECT queries
4. **Query allowlist** — only queries against known tables are permitted

#### Rule 2: ALWAYS FILTER SOFT-DELETED RECORDS

```
Every query MUST include soft-delete filters.
Tables use one of two patterns:

Pattern A (Hevo-replicated tables):
  WHERE (__hevo__marked_deleted IS NULL OR __hevo__marked_deleted = false)

Pattern B (App-managed tables):
  WHERE (is_deleted IS NULL OR is_deleted = false)
```

**Known table → soft-delete mapping:**

| Table | Soft Delete Column | Filter |
|-------|--------------------|--------|
| member | `__hevo__marked_deleted` | `IS NULL OR = false` |
| location | `__hevo__marked_deleted` | `IS NULL OR = false` |
| brand | `__hevo__marked_deleted` | `IS NULL OR = false` |
| batch_payment | `__hevo__marked_deleted` | `IS NULL OR = false` |
| rejection_payment | `__hevo__marked_deleted` | `IS NULL OR = false` |
| transaction | `__hevo__marked_deleted` | `IS NULL OR = false` |
| member_contract | `__hevo__marked_deleted` | `IS NULL OR = false` |
| member_contract_billing | `__hevo__marked_deleted` | `IS NULL OR = false` |
| payment_information | `is_deleted` | `IS NULL OR = false` |
| group_staff | `__hevo__marked_deleted` | `IS NULL OR = false` |
| group_location | `__hevo__marked_deleted` | `IS NULL OR = false` |

#### Rule 3: ALWAYS SCOPE TO USER'S LOCATIONS

```
Every query MUST filter by the authenticated user's allowed location IDs.
No user can see data from locations they don't have access to.

Exception: super-admin role may query across all locations (configurable).
```

#### Rule 4: NEVER EXPOSE SENSITIVE DATA

```
The following data MUST be masked or excluded from responses:

- Full card numbers (only last 4 digits)
- Full bank account numbers (only last 3 digits)
- BSB numbers (mask as XXX-XXX or omit)
- Card CVVs (never stored, never returned)
- Passwords or tokens
- Card tokens / payment gateway tokens
- Internal IDs should not be the primary identifier shown to users
```

#### Rule 5: PARAMETERIZED QUERIES ONLY

```
All queries MUST use parameterized values ($1, $2, etc.).
No string concatenation or interpolation of user input into SQL.
```

#### Rule 6: QUERY RESULT LIMITS

```
All queries MUST include a LIMIT clause.
Default: LIMIT 50
Maximum: LIMIT 200
The LLM must be instructed to always include limits.
```

---

## 8. Database Schema — Chat Storage

Chat history is stored in **DynamoDB** (not Postgres) to keep the Postgres connection 100% read-only and leverage DynamoDB's existing infrastructure in the AWS account.

### DynamoDB Table Design (Single Table)

**Table name:** `minihub-chat`

#### Primary Key Design

| Attribute | Type | Description |
|-----------|------|-------------|
| `PK` | String (Partition Key) | `SESSION#<sessionId>` |
| `SK` | String (Sort Key) | `MSG#<timestamp>#<messageId>` |

#### GSI-1: Query by Member

| Attribute | Type | Description |
|-----------|------|-------------|
| `GSI1PK` | String (Partition Key) | `MEMBER#<memberId>` |
| `GSI1SK` | String (Sort Key) | `SESSION#<createdAt>` |

#### Item Types

**Session Item:**
```json
{
  "PK": "SESSION#abc-123",
  "SK": "META",
  "GSI1PK": "MEMBER#f633550a-1e27-4b81-81af-a78558a2d38b",
  "GSI1SK": "SESSION#2026-02-26T09:00:00Z",
  "type": "SESSION",
  "sessionId": "abc-123",
  "memberId": "f633550a-1e27-4b81-81af-a78558a2d38b",
  "memberName": "Gordon Smith",
  "memberRole": "L3",
  "locationContext": "Plus Fitness Bondi",
  "allowedLocationIds": ["loc-1", "loc-2", "loc-3"],
  "title": "Payment inquiry for member John Doe",
  "status": "active",
  "messageCount": 12,
  "createdAt": "2026-02-26T09:00:00Z",
  "updatedAt": "2026-02-26T09:15:00Z",
  "ttl": 1751270400
}
```

**Message Item:**
```json
{
  "PK": "SESSION#abc-123",
  "SK": "MSG#2026-02-26T09:01:00Z#msg-456",
  "type": "MESSAGE",
  "messageId": "msg-456",
  "sessionId": "abc-123",
  "role": "user",
  "content": "Why was member John Doe charged $50 on 15 Feb?",
  "metadata": {
    "sqlGenerated": "SELECT bp.amount, bp.debit_date ... WHERE ...",
    "sqlExecutionTimeMs": 45,
    "tokensUsed": { "input": 1200, "output": 350 },
    "model": "claude-sonnet-4-20250514",
    "resultRowCount": 3,
    "locationIdsQueried": ["loc-1"]
  },
  "createdAt": "2026-02-26T09:01:00Z",
  "ttl": 1751270400
}
```

#### TTL Strategy

- Chat messages expire after **90 days** by default (configurable)
- TTL attribute: `ttl` (Unix timestamp)
- DynamoDB automatically cleans up expired items

#### Access Patterns

| Access Pattern | Key Condition |
|----------------|---------------|
| Get all messages in a session | `PK = SESSION#<id>` AND `SK BEGINS_WITH MSG#` |
| Get session metadata | `PK = SESSION#<id>` AND `SK = META` |
| List sessions for a member | `GSI1PK = MEMBER#<id>` AND `GSI1SK BEGINS_WITH SESSION#` |
| Get recent sessions for a member | Same as above, `ScanIndexForward = false, Limit = 20` |

---

## 9. API Design

### New Endpoints

All chat endpoints are under `/api/v1/chat/` and require **Cognito JWT authentication** (not API key).

#### POST /api/v1/chat/message

Send a message and receive an AI-generated response.

**Request:**
```json
{
  "sessionId": "abc-123",        // optional — omit to start new session
  "message": "Why was member John Doe charged $50 on 15 Feb?"
}
```

**Response:**
```json
{
  "sessionId": "abc-123",
  "messageId": "msg-789",
  "response": "John Doe (Member #4521) was charged $50.00 on 15 February 2026 as part of his fortnightly direct debit for his Plus Fitness Bondi membership (12 Month Flexi). The payment was processed via credit card ending in 9729 and was successful.",
  "sources": [
    {
      "table": "batch_payment",
      "description": "Direct debit record"
    }
  ],
  "confidence": "high",
  "canEscalate": false,
  "timestamp": "2026-02-26T09:01:05Z"
}
```

**Error response (can't answer):**
```json
{
  "sessionId": "abc-123",
  "messageId": "msg-790",
  "response": "I wasn't able to find specific information about this charge. This might require investigation by the support team.",
  "confidence": "low",
  "canEscalate": true,
  "escalation": {
    "email": "support@vivaleisure.com.au",
    "suggestedSubject": "Payment inquiry - Member #4521 - $50 charge on 15/02/2026"
  },
  "timestamp": "2026-02-26T09:02:00Z"
}
```

#### GET /api/v1/chat/sessions

List the user's chat sessions.

**Query params:** `?limit=20&lastKey=<base64>`

**Response:**
```json
{
  "sessions": [
    {
      "sessionId": "abc-123",
      "title": "Payment inquiry for John Doe",
      "messageCount": 12,
      "createdAt": "2026-02-26T09:00:00Z",
      "updatedAt": "2026-02-26T09:15:00Z"
    }
  ],
  "lastKey": null
}
```

#### GET /api/v1/chat/sessions/:sessionId/messages

Get messages for a session.

**Query params:** `?limit=50&lastKey=<base64>`

**Response:**
```json
{
  "sessionId": "abc-123",
  "messages": [
    {
      "messageId": "msg-456",
      "role": "user",
      "content": "Why was John Doe charged $50?",
      "createdAt": "2026-02-26T09:01:00Z"
    },
    {
      "messageId": "msg-789",
      "role": "assistant",
      "content": "John Doe was charged $50.00 on...",
      "createdAt": "2026-02-26T09:01:05Z"
    }
  ],
  "lastKey": null
}
```

### Routes Registry Entry

```typescript
// To be added to routes-registry.ts
{
  method: "POST",
  path: "/api/v1/chat/message",
  description: "Send a message to the AI support chat and receive a response",
  handler: "src/routes/api/handlers/chat.handler.ts",
  authRequired: true,  // Cognito JWT (not API key)
  tags: ["AI Chat", "Support"],
},
{
  method: "GET",
  path: "/api/v1/chat/sessions",
  description: "List authenticated user's chat sessions",
  handler: "src/routes/api/handlers/chat.handler.ts",
  authRequired: true,
  tags: ["AI Chat", "Support"],
},
{
  method: "GET",
  path: "/api/v1/chat/sessions/:sessionId/messages",
  description: "Get messages for a specific chat session",
  handler: "src/routes/api/handlers/chat.handler.ts",
  authRequired: true,
  tags: ["AI Chat", "Support"],
},
```

---

## 10. LLM Integration

### Approach: SQL Generation + Answer Formatting (Two-Step)

**Step 1 — Generate SQL:**
The LLM receives the user's question, schema reference, allowed locations, and conversation history. It returns a parameterized SELECT query.

**Step 2 — Format Answer:**
The query results are sent back to the LLM with the original question. The LLM formats a human-readable answer.

### System Prompt (Core Rules)

```
You are a support assistant for The Hub, a gym management platform.
You help club staff answer questions about members, payments, contracts, and billing.

## ABSOLUTE RULES (NEVER VIOLATE)

1. Generate ONLY SELECT queries. Never INSERT, UPDATE, DELETE, DROP, ALTER, CREATE, or TRUNCATE.
2. Every query MUST filter soft-deleted records:
   - Hevo tables: WHERE (__hevo__marked_deleted IS NULL OR __hevo__marked_deleted = false)
   - App tables: WHERE (is_deleted IS NULL OR is_deleted = false)
3. Every query MUST include: WHERE <table>.location_id IN (<allowed_locations>)
   or scope via member.home_location_id IN (<allowed_locations>).
4. Every query MUST include a LIMIT clause (max 200).
5. Use parameterized values ($1, $2, etc.) — NEVER concatenate strings.
6. NEVER return full card numbers, bank account numbers, BSBs, CVVs, or tokens.
   Show only last 4 digits of cards, last 3 of bank accounts.
7. If you cannot answer, say so. Do not guess or fabricate data.
8. If the question requires a write operation, explain that you can only read data.

## CONTEXT

The user has access to the following locations: {allowedLocationIds}
The user's role is: {userRole}

## SCHEMA REFERENCE

{schemaReference}
```

### Schema Reference

Instead of exposing the full database schema, we provide a **curated reference** to the LLM — only the tables and columns relevant to support queries, with descriptions:

```
Tables available for queries:

member (m):
  - id (UUID, PK)
  - alias_member_id (INT, legacy member number — staff use this to identify members)
  - given_name, surname, email, mobile_number
  - home_location_id (FK → location)
  - brand_id (FK → brand)
  - is_active (BOOLEAN)
  - outstanding_balance (FLOAT)
  - joined_date_time (TIMESTAMP)
  - type (ENUM: MEMBER, STAFF)
  - Soft delete: __hevo__marked_deleted

location (l):
  - id (UUID, PK)
  - name, short_name
  - alias_id (INT, legacy location code)
  - brand_id (FK → brand)
  - status (ENUM: ACTIVE, INACTIVE, TEMPCLOSED, PERMCLOSED)
  - state, suburb, post_code
  - Soft delete: __hevo__marked_deleted

brand (b):
  - id (UUID, PK)
  - name (e.g., "Plus Fitness", "Brand Name")
  - Soft delete: __hevo__marked_deleted

batch_payment (bp):
  - id (UUID, PK)
  - member_id (FK → member)
  - location_id (FK → location)
  - brand_id (FK → brand)
  - member_contract_id, member_contract_billing_id
  - token (payment token reference)
  - amount (FLOAT), currency
  - debit_date (DATE)
  - payment_type (STRING: CREDIT_CARD, DIRECT_DEBIT)
  - status, result
  - gateway_code, acquirer_code, acquirer_message
  - card (last digits)
  - settlement_date
  - Soft delete: __hevo__marked_deleted

rejection_payment (rp):
  - id (UUID, PK)
  - member_id, location_id
  - batch_payment_id (FK → batch_payment)
  - amount, old_amount
  - debit_date, payment_type
  - status, result, gateway_code
  - rejection_count, rejection_fee
  - outstanding_balance, billing_credit
  - Soft delete: __hevo__marked_deleted

transaction (t):
  - id (UUID, PK)
  - transaction_id (composite string)
  - member_id, location_id, member_contract_id
  - amount, currency, type (DEBIT, CREDIT, SUSPENSION_CREDIT)
  - debit_date, payment_type, payment_method
  - card_number (last 4 only)
  - status, message
  - refund_id, refund_transaction_id
  - invoice_number
  - Soft delete: __hevo__marked_deleted

payment_information (pi):
  - id (UUID, PK)
  - member_id (FK → member)
  - payment_type (ENUM: CREDIT_CARD, DIRECT_DEBIT, CASH, EFTPOS)
  - primary (BOOLEAN)
  - card_number (masked), card_type, card_expiry_date, card_holder_name
  - account_name, bsb, account_number (for bank accounts)
  - Soft delete: is_deleted

member_contract (mc):
  - id (UUID, PK)
  - member_id (FK → member)
  - (contract details - start date, end date, status, membership type, etc.)
  - Soft delete: __hevo__marked_deleted

member_contract_billing (mcb):
  - id (UUID, PK)
  - (billing schedule, frequency, amount, next debit date, etc.)
  - Soft delete: __hevo__marked_deleted
```

### Model Selection

| Option | Pros | Cons |
|--------|------|------|
| **Anthropic Claude Sonnet** | Great at SQL, follows instructions precisely, good safety | Cost per token |
| **OpenAI GPT-4o** | Fast, good at SQL | Slightly less instruction-following than Claude |
| **OpenAI GPT-4o-mini** | Very cheap, fast | May miss edge cases in complex queries |

**Recommendation:** Start with **Claude Sonnet** for accuracy and safety compliance. Evaluate GPT-4o-mini for cost optimization once the system is proven.

---

## 11. Domain Model Reference

```
Brand (e.g., "Plus Fitness")
  │
  ├── Location (e.g., "Plus Fitness Bondi")  ── ~270 total
  │     │
  │     ├── Member (gym member, belongs to home location)
  │     │     │
  │     │     ├── PaymentInformation (card or bank account on file)
  │     │     ├── MemberContract (membership agreement)
  │     │     │     └── MemberContractBilling (billing schedule)
  │     │     ├── Transaction (individual payments/refunds)
  │     │     ├── BatchPayment (scheduled direct debit runs)
  │     │     │     └── RejectionPayment (failed DD attempts)
  │     │     └── CardNumber (physical access card)
  │     │
  │     └── Staff (employees, also in Member table with type=STAFF)
  │           └── StaffLocationAccess / GroupStaff → GroupLocation
  │               (determines which locations staff can see)
  │
  └── Membership types (available at specific locations)

Auth: Cognito → Groups (L0-L5, admin, super-admin)
      Staff → GroupStaff → Group → GroupLocation → Location
      (This chain determines data access scope)
```

---

## 12. Frontend Integration

### Current State

The vivareact frontend already has:
- A `ChatWindow` component (`src/components/chatWindow/ChatWindow.jsx`) — currently a static placeholder with FAQ links
- A chat icon in `App.js` that toggles the ChatWindow visibility
- Full Cognito auth with JWT tokens (`AuthProvider`)
- `axiosClient` pattern for authenticated API calls (`src/api/apiConfig.js`)

### Proposed Changes (Phase 2 — separate to this BRD)

Replace the placeholder `ChatWindow` with a real chat interface that:
1. Uses the existing `Auth.currentSession().getIdToken().getJwtToken()` for auth
2. Calls MiniHub `/api/v1/chat/*` endpoints
3. Displays conversation history
4. Shows escalation options when the bot can't answer

> **Note:** Frontend changes to vivareact are **out of scope for Phase 1**. Phase 1 focuses on the MiniHub backend API. The frontend can be developed independently once the API is stable, or tested via Postman/curl initially.

### Sandbox Testing (Phase 1)

For initial testing without modifying vivareact:
- Use Postman or a simple standalone HTML page
- Authenticate via Cognito to get a JWT
- Call the MiniHub chat API endpoints directly
- Validate responses before building the real UI

---

## 13. Infrastructure & Deployment

### What Changes in MiniHub

| Component | Change | Risk |
|-----------|--------|------|
| `app/src/middleware/` | Add `cognito-auth.ts` middleware | Low — new file, no existing code modified |
| `app/src/routes/api/handlers/` | Add `chat.handler.ts` | Low — new file |
| `app/src/services/` | Add `chat-service.ts`, `llm-service.ts`, `sql-validator.ts` | Low — new files |
| `app/src/config.ts` | Add LLM + Cognito env vars | Low — additive only |
| `infra/config/prod-env.json` | Add new env vars | Low — additive only |
| `package.json` | Add dependencies: `jwks-rsa`, `jsonwebtoken`, `@aws-sdk/client-dynamodb`, LLM SDK | Medium — new dependencies |

### New Environment Variables

```
# Cognito (for JWT verification)
AWS_COGNITO_REGION=ap-southeast-2
AWS_COGNITO_USER_POOL_ID=ap-southeast-2_XXXXXXX

# LLM Provider
LLM_PROVIDER=anthropic              # or "openai"
LLM_API_KEY=sk-...                   # API key for the LLM provider
LLM_MODEL=claude-sonnet-4-20250514            # model to use

# DynamoDB
CHAT_TABLE_NAME=minihub-chat         # DynamoDB table name

# Chat Configuration
CHAT_MAX_HISTORY=20                  # max messages to include in LLM context
CHAT_TTL_DAYS=90                     # days before chat messages expire
CHAT_MIN_ROLE=L1                     # minimum Cognito group required
```

### DynamoDB Table — CDK or Manual

The `minihub-chat` DynamoDB table can be created:

**Option A: Via CDK** (in existing `infra/` stack)
```typescript
const chatTable = new dynamodb.Table(this, 'ChatTable', {
  tableName: 'minihub-chat',
  partitionKey: { name: 'PK', type: dynamodb.AttributeType.STRING },
  sortKey: { name: 'SK', type: dynamodb.AttributeType.STRING },
  billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
  timeToLiveAttribute: 'ttl',
  removalPolicy: cdk.RemovalPolicy.RETAIN,
});

chatTable.addGlobalSecondaryIndex({
  indexName: 'GSI1',
  partitionKey: { name: 'GSI1PK', type: dynamodb.AttributeType.STRING },
  sortKey: { name: 'GSI1SK', type: dynamodb.AttributeType.STRING },
});
```

**Option B: Manual** (via AWS Console or CLI for speed)

### Cost Estimate (Rough)

| Component | Estimated Monthly Cost |
|-----------|----------------------|
| DynamoDB (on-demand, low volume) | $1–5 |
| LLM API (Claude Sonnet, ~1000 queries/day) | $50–200 |
| App Runner (existing, marginal increase) | $0 additional |
| **Total** | **~$50–200/month** |

> Cost is dominated by LLM usage. Can be reduced by caching common queries, using cheaper models for simple lookups, or implementing query templates.

---

## 14. Security Considerations

### Defense in Depth

```
Layer 1: Network      → MiniHub behind App Runner, no public DB access
Layer 2: Auth         → Cognito JWT verification (no API key in frontend)
Layer 3: Authorization → Role check + location scoping
Layer 4: SQL Safety   → Postgres user = SELECT-only grants
Layer 5: SQL Validator → Parse generated SQL, reject non-SELECT
Layer 6: LLM Prompt   → System prompt enforces read-only + scoping rules
Layer 7: Column Filter → Blocklist sensitive columns before returning
Layer 8: Result Limit  → Max 200 rows per query
Layer 9: Audit Trail   → Every query logged to DynamoDB with full metadata
```

### Threat Model

| Threat | Mitigation |
|--------|-----------|
| SQL injection via user question | LLM generates parameterized queries; SQL validator rejects suspicious patterns |
| Prompt injection ("ignore previous instructions") | System prompt hardened; SQL validator as independent safety net |
| User asks for data outside their locations | Location IDs injected server-side from auth context, not from user input |
| LLM generates destructive SQL | Postgres user is read-only; SQL validator rejects non-SELECT; LLM prompt forbids it |
| Sensitive data exposure | Column blocklist; card/account masking enforced at response layer |
| Excessive queries (abuse/cost) | Rate limiting per user; daily query budget per role |
| Chat data leakage | DynamoDB encrypted at rest; TTL auto-cleanup; access scoped to user's own sessions |

### Rate Limiting

| Role | Queries per hour | Queries per day |
|------|-----------------|----------------|
| L1–L2 | 20 | 100 |
| L3–L4 | 50 | 250 |
| L5 | 100 | 500 |
| admin/super-admin | 200 | 1000 |

---

## 15. Scalability & Future Scope

### Phase 2 — Possible Enhancements

| Feature | Description |
|---------|-------------|
| Frontend chat UI | Replace placeholder ChatWindow in vivareact |
| Query templates | Pre-built queries for common questions (faster, cheaper) |
| Suggested questions | "Did you mean: Show rejected payments this week?" |
| Streaming responses | SSE/WebSocket for real-time token streaming |
| Multi-turn reasoning | Complex queries that need multiple DB lookups |
| Analytics dashboard | Track common questions, resolution rate, escalation rate |
| Email escalation | Auto-draft and send support emails from chat |
| Knowledge base | FAQ answers without hitting the database |

### Reusability in Other Projects

This architecture is designed to be portable:

1. **The Cognito JWT middleware** is generic — works with any Cognito User Pool
2. **The SQL generation + validation pipeline** is schema-agnostic — swap the schema reference for a different database
3. **The DynamoDB chat storage** is independent — single table design works for any chat application
4. **The LLM service** is provider-agnostic — swap Anthropic for OpenAI or local models

To adapt for another project:
- Update the schema reference
- Update the soft-delete column names
- Update the location-scoping logic
- Update the Cognito User Pool ID
- Everything else stays the same

---

## 16. Open Questions & Decisions

| # | Question | Options | Recommendation | Status |
|---|----------|---------|----------------|--------|
| 1 | Which LLM provider? | Anthropic Claude / OpenAI GPT-4o / GPT-4o-mini | Start with Claude Sonnet for accuracy | ❓ Pending |
| 2 | Should super-admins bypass location scoping? | Yes (all locations) / No (still scoped) | Yes, with audit logging | ❓ Pending |
| 3 | Where to create DynamoDB table? | CDK (infra/) / Manual / Separate stack | CDK in existing stack | ❓ Pending |
| 4 | Minimum role for chat access? | L1 / L2 / L3 | L1 (most inclusive) | ❓ Pending |
| 5 | Chat message retention period? | 30 / 60 / 90 / 365 days | 90 days | ❓ Pending |
| 6 | Should generated SQL be visible to the user? | Yes / No / Only for admin roles | No (internal only, logged in metadata) | ❓ Pending |
| 7 | Should the chat endpoint coexist with API-key-protected routes or be on a separate path? | Same `/api/` with dual auth / Separate `/chat/` prefix | Same `/api/v1/chat/` with Cognito-only middleware | ❓ Pending |
| 8 | Budget for LLM API costs? | $50/mo / $100/mo / $200/mo | Need input from leadership | ❓ Pending |
| 9 | Should we implement query caching? | Yes (common queries cached) / No | Phase 2 optimization | ❓ Pending |
| 10 | hub-insights already has Cognito auth — should chat live there instead? | MiniHub / hub-insights | MiniHub (cleaner separation, already has PG) | ❓ Pending |

---

## 17. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| LLM generates incorrect SQL | Medium | Medium | SQL validator + result verification + "confidence" scoring |
| LLM hallucinates data not in results | Low | High | Two-step approach: generate SQL first, then format actual results |
| Cost overrun from LLM API | Medium | Low | Rate limiting + daily budgets + cheaper model fallback |
| Users over-trust the bot (doesn't escalate) | Medium | Medium | Clear confidence indicators + prominent escalation option |
| Latency too high for good UX | Medium | Medium | Streaming responses + query caching + model selection |
| Postgres schema changes break queries | Low | Medium | Schema reference is curated (not auto-generated) — update when schema changes |
| Data breach via chat history | Low | High | DynamoDB encryption + TTL + user-scoped access + no sensitive data in responses |

---

## Appendix

### A. File Structure (Proposed)

```
app/src/
├── middleware/
│   ├── api-key-auth.ts          # existing
│   └── cognito-auth.ts          # NEW — JWT verification
├── routes/api/handlers/
│   ├── chat.handler.ts          # NEW — chat endpoints
│   └── ...existing handlers...
├── services/
│   ├── chat-service.ts          # NEW — chat business logic
│   ├── llm-service.ts           # NEW — LLM API integration
│   ├── sql-validator.ts         # NEW — SQL safety validation
│   ├── location-resolver.ts     # NEW — resolve user's locations from PG
│   └── postgres.ts              # existing
├── config/
│   ├── schema-reference.ts      # NEW — curated DB schema for LLM
│   └── ...existing config...
└── config.ts                    # existing (add new env vars)
```

### B. Example Queries the Chat Should Handle

| Question | Expected SQL Pattern |
|----------|---------------------|
| "Why was John Doe charged $50 on 15 Feb?" | Join `batch_payment` + `member` + `member_contract` filtered by name, amount, date, location |
| "What card was used for this payment?" | Join `batch_payment` + `payment_information`, return masked card number |
| "Show me all rejected payments this week for Bondi" | Query `rejection_payment` filtered by date range + location |
| "Is member 4521 active?" | Query `member` by `alias_member_id`, check `is_active` |
| "What's the outstanding balance for member Jane Smith?" | Query `member` by name, return `outstanding_balance` |
| "How many active members at Plus Fitness Bondi?" | `COUNT(*)` from `member` where `is_active = true` and `home_location_id = <bondi>` |
| "Show me payments for member with email john@example.com" | Query `transaction` + `member` joined by email |
| "What membership does member 4521 have?" | Join `member_contract` + `member_contract_billing` + membership details |

### C. Related Codebases

| Repo | Purpose | Relevance |
|------|---------|-----------|
| `minihubvone` | Express API (this project) | Where the chat module lives |
| `vivaamplify` | Amplify/AppSync/GraphQL backend | Source of truth for schema + auth rules |
| `vivareact` | React frontend | Future chat UI integration |
| `hub-insights` | Reporting API | Reference for Cognito JWT middleware |

### D. References

- Cognito JWT verification: `hub-insights/app/src/middleware/authorization.ts`
- Postgres connection: `minihubvone/app/src/services/postgres.ts`
- Existing query patterns: `minihubvone/app/src/queries/chargeback-queries.ts`
- Soft delete handling: `minihubvone/app/src/services/fitness-passport-report-service.ts`
- Auth context (frontend): `vivareact/src/contexts/AuthContext/AuthProvider.jsx`
- Location resolution (frontend): `vivareact/src/contexts/AuthContext/AuthProvider.jsx` → `getGroupByStaffId()`
- GraphQL schema (permissions): `vivaamplify/amplify/backend/api/vivaamplify/schema/permission.graphql`
- GraphQL schema (member): `vivaamplify/amplify/backend/api/vivaamplify/schema/member.graphql`
- GraphQL schema (payment): `vivaamplify/amplify/backend/api/vivaamplify/schema/payment.graphql`
- GraphQL schema (location): `vivaamplify/amplify/backend/api/vivaamplify/schema/location.graphql`

---

> **Related Documents:**
> - [AI-LLM-INTEGRATION-GUIDE.md](./AI-LLM-INTEGRATION-GUIDE.md) — Deep dive into how the LLM works, system prompts, tool use, prompt engineering, safety controls, model selection, costs, and the `.md` instruction files that control the bot's behavior.

> **Next Steps:**
> 1. Review this document + the LLM Integration Guide with the team
> 2. Decide on open questions (Section 16)
> 3. Approve LLM budget
> 4. Begin implementation — start with Cognito middleware + DynamoDB table + basic chat endpoint
