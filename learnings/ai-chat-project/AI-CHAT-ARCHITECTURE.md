# AI Support Chat — Real Architecture

> **Status:** Planning
> **Created:** 2026-02-26
> **Related:** [AI-SUPPORT-CHAT-BRD.md](./AI-SUPPORT-CHAT-BRD.md) · [AI-LLM-INTEGRATION-GUIDE.md](./AI-LLM-INTEGRATION-GUIDE.md)

---

## The Core Idea

The LLM (Claude) is a **router + translator**. It receives a question, decides what type of problem it is, follows the right troubleshooting steps, queries the database if needed, and formats a human answer.

The knowledge that makes this work lives in **three places:**

```
┌──────────────────────────────────────────────────────────────┐
│                    THE KNOWLEDGE SYSTEM                        │
│                                                                │
│  ┌────────────────────┐  ┌────────────────┐  ┌────────────┐ │
│  │  1. KNOWLEDGE BASE  │  │  2. PLAYBOOKS   │  │  3. TOOLS   │ │
│  │                     │  │                 │  │             │ │
│  │  "What do I know?"  │  │  "How do I      │  │  "What can  │ │
│  │                     │  │   investigate?"  │  │   I query?" │ │
│  │  • DD rejections    │  │                 │  │             │ │
│  │    come from bank   │  │  • Step 1: find │  │  • search   │ │
│  │  • INSUFFICIENT_    │  │    the member   │  │    _member  │ │
│  │    FUNDS causes     │  │  • Step 2: check│  │  • get_     │ │
│  │  • billing cycles   │  │    payments     │  │    payments │ │
│  │  • how contracts    │  │  • Step 3: check│  │  • get_     │ │
│  │    work             │  │    contract     │  │    contract │ │
│  │  • 100+ FAQ answers │  │  • Step 4: ...  │  │  • get_     │ │
│  │                     │  │                 │  │    rejection│ │
│  │  Answers directly.  │  │  Follows your   │  │             │ │
│  │  No query needed.   │  │  exact steps.   │  │  Pre-built  │ │
│  │                     │  │  Queries data.  │  │  SQL. Safe. │ │
│  └────────────────────┘  └────────────────┘  └────────────┘ │
│                                                                │
│  All stored in DynamoDB. Loaded into system prompt per request. │
│  Managed via admin UI.                                         │
└──────────────────────────────────────────────────────────────┘
```

---

## How the Three Pieces Work Together

A question comes in. Claude reads the system prompt and decides:

```
Question: "Jade says she had money but her DD was rejected"

Claude thinks:
  → This matches Knowledge Base item: "DD Rejection — Member Claims Sufficient Funds"
  → I have a direct answer. No query needed.
  → Respond from knowledge.

────────────────────────────────────────────────────

Question: "Why was member 4521 charged $50 on 15 Feb?"

Claude thinks:
  → This matches Playbook: "Investigate a specific charge"
  → Step 1: Find the member by alias ID → use search_member tool
  → Step 2: Look up payments for that date/amount → use get_payments tool
  → Step 3: Check their contract for billing frequency → use get_contract tool
  → Combine results → format answer

────────────────────────────────────────────────────

Question: "What's the weather today?"

Claude thinks:
  → No matching knowledge base item
  → No matching playbook
  → No relevant tool
  → "I can only help with Hub-related questions."
```

---

## 1. Knowledge Base — Direct Answers

These are answers that don't need database queries. Pure institutional knowledge. The stuff your support team types over and over.

### What a Knowledge Base Entry Looks Like

```json
{
  "id": "kb-001",
  "category": "DD Rejections",
  "title": "Member claims sufficient funds but DD rejected as INSUFFICIENT_FUNDS",
  "triggers": [
    "insufficient funds",
    "had money in account",
    "enough money",
    "bank rejected",
    "direct debit failed funds"
  ],
  "answer": "The rejection reason INSUFFICIENT_FUNDS comes from the member's bank, not from Hub. Hub only receives and displays the rejection code from the financial institution. This can occur even with apparent balance due to: credit limits, pending transactions, uncleared funds, or bank processing timing. This is outside our control. Advise the member to contact their bank directly to clarify the cause.",
  "needsQuery": false,
  "relatedPlaybook": null,
  "createdBy": "amrit.regmi",
  "updatedAt": "2026-02-26T10:00:00Z"
}
```

### More Examples

```json
{
  "id": "kb-002",
  "category": "DD Rejections",
  "title": "DD rejected — ACCOUNT_CLOSED",
  "triggers": ["account closed", "bank account closed"],
  "answer": "The ACCOUNT_CLOSED rejection code means the member's bank has informed us that the account used for direct debit is no longer active. The member needs to update their payment method in the Hub or contact their bank to confirm the account status.",
  "needsQuery": false
}

{
  "id": "kb-003",
  "category": "DD Rejections",
  "title": "DD rejected — REFER_TO_CUSTOMER",
  "triggers": ["refer to customer", "refer to cardholder"],
  "answer": "REFER_TO_CUSTOMER means the bank requires the account holder to contact them directly before the transaction can be processed. This is usually a security hold or a flag on the account. The member should contact their bank.",
  "needsQuery": false
}

{
  "id": "kb-004",
  "category": "Billing",
  "title": "Member asking why they were charged — general",
  "triggers": ["why was I charged", "unexpected charge", "didn't expect payment"],
  "answer": null,
  "needsQuery": true,
  "relatedPlaybook": "pb-001"
}

{
  "id": "kb-005",
  "category": "Contracts",
  "title": "How cancellation fees work",
  "triggers": ["cancellation fee", "cancel membership cost", "early termination"],
  "answer": "Cancellation fees depend on the contract type. For fixed-term contracts (e.g., 12 months), an early termination fee may apply — typically the lesser of: the remaining contract value or a fixed fee (usually $50-$100 depending on the brand). Flexi/month-to-month memberships typically require 30 days notice with no fee. Check the specific member's contract for exact terms.",
  "needsQuery": false
}
```

### How Many Do You Need?

Start by reading through your last **100 support tickets**. You'll find:
- ~20-30 unique question types that cover 80% of tickets
- Most have a standard answer or a standard investigation process

That's your starting knowledge base. It grows over time.

---

## 2. Playbooks — Your Troubleshooting Steps

This is the key thing you described: *"whatever I do to find the issue — I look into this table, then look into another table — I have steps I follow."*

A playbook captures **your exact investigation process** so the bot follows the same steps you would.

### What a Playbook Looks Like

```json
{
  "id": "pb-001",
  "name": "Investigate a specific charge",
  "description": "When someone asks why a member was charged a specific amount on a specific date",
  "triggers": [
    "why was charged",
    "what is this charge",
    "payment on date",
    "charged twice",
    "unexpected debit"
  ],
  "steps": [
    {
      "step": 1,
      "action": "Find the member",
      "tool": "search_member",
      "description": "Search by name, email, alias ID, or mobile — whatever info was provided",
      "ifNotFound": "Tell the user you couldn't find the member at their locations. Ask for more details (member ID, email, etc.)"
    },
    {
      "step": 2,
      "action": "Check batch payments",
      "tool": "get_payments",
      "params": { "payment_type": "batch" },
      "description": "Look for batch_payment records matching the date and amount. This covers scheduled direct debits.",
      "whatToLookFor": [
        "Does the amount match?",
        "What's the payment_type (CREDIT_CARD or DIRECT_DEBIT)?",
        "What's the status (APPROVED, DECLINED)?",
        "What card/account was used?"
      ]
    },
    {
      "step": 3,
      "action": "Check transactions",
      "tool": "get_transactions",
      "description": "If no batch payment found, check the transaction table. This covers one-off payments, POS transactions, joining fees, etc.",
      "whatToLookFor": [
        "What type (DEBIT, CREDIT)?",
        "Is this a refund (type = CREDIT)?",
        "What's the payment method (card, EFTPOS, cash)?",
        "Is there an invoice number?"
      ]
    },
    {
      "step": 4,
      "action": "Check member contract",
      "tool": "get_contract",
      "description": "Look at the member's active contract to understand their billing cycle and expected amounts.",
      "whatToLookFor": [
        "What membership type?",
        "What's the billing frequency (weekly, fortnightly, monthly)?",
        "What's the expected amount per billing cycle?",
        "Does the charge match the expected billing?"
      ]
    },
    {
      "step": 5,
      "action": "Formulate answer",
      "tool": null,
      "description": "Combine the findings into a clear answer. Include: what the charge was for, when it was processed, what payment method was used, and whether it looks normal for their billing cycle. If it looks abnormal, suggest escalation."
    }
  ]
}
```

### Another Playbook: "Member says charged twice"

```json
{
  "id": "pb-002",
  "name": "Investigate duplicate charge",
  "triggers": ["charged twice", "double charge", "duplicate payment", "two payments"],
  "steps": [
    {
      "step": 1,
      "action": "Find the member",
      "tool": "search_member"
    },
    {
      "step": 2,
      "action": "Get all payments this billing period",
      "tool": "get_payments",
      "description": "Pull all batch_payment records for the current month. Look for multiple charges.",
      "whatToLookFor": [
        "How many payments this month?",
        "Are they the same amount?",
        "What are the debit dates?",
        "Could this be a normal fortnightly billing? (2 payments/month is normal for fortnightly)"
      ]
    },
    {
      "step": 3,
      "action": "Check for rejections + retries",
      "tool": "get_rejections",
      "description": "Check if one payment was rejected and retried. A rejection + retry looks like a double charge but isn't.",
      "whatToLookFor": [
        "Was there a rejection on a similar date?",
        "Was the rejection retried?",
        "Does rejected amount + successful amount explain what the member sees?"
      ]
    },
    {
      "step": 4,
      "action": "Check contract billing frequency",
      "tool": "get_contract",
      "description": "Confirm the billing cycle. If fortnightly, two debits per month is expected."
    },
    {
      "step": 5,
      "action": "Answer",
      "description": "Explain what you found. Common outcomes: (a) Normal fortnightly billing, (b) Rejection + retry, (c) Actual duplicate — escalate to support."
    }
  ]
}
```

### Another Playbook: "What card was used for a payment"

```json
{
  "id": "pb-003",
  "name": "Identify payment method for a charge",
  "triggers": ["what card", "which card", "payment method used", "bank account used"],
  "steps": [
    {
      "step": 1,
      "action": "Find the member",
      "tool": "search_member"
    },
    {
      "step": 2,
      "action": "Find the specific payment",
      "tool": "get_payments",
      "description": "Find the batch_payment or transaction matching the date/amount"
    },
    {
      "step": 3,
      "action": "Get payment information",
      "tool": "get_payment_methods",
      "description": "Look up the payment_information record linked to the payment via the token field. Return MASKED card number only (last 4 digits).",
      "important": "NEVER show full card number. Only last 4 digits."
    }
  ]
}
```

---

## 3. Tools — The Database Queries

These are the pre-built, safe SQL queries the bot can use. Each tool is a function in your MiniHub codebase.

### Tool Registry

```typescript
// tools/index.ts — all tools the LLM can call

export const TOOLS = {
  search_member: {
    description: "Find a member by name, email, mobile, or alias ID",
    // SQL is pre-written. LLM only provides search parameters.
  },
  get_payments: {
    description: "Get batch payments for a member, optionally filtered by date and amount",
  },
  get_rejections: {
    description: "Get rejection payments for a member",
  },
  get_transactions: {
    description: "Get transactions for a member",
  },
  get_contract: {
    description: "Get active contracts and billing details for a member",
  },
  get_payment_methods: {
    description: "Get payment methods on file for a member (masked card/account numbers only)",
  },
  get_member_balance: {
    description: "Get outstanding balance and recent billing credits for a member",
  },
  get_location_stats: {
    description: "Get basic stats for a location (active member count, etc.)",
  },
  escalate: {
    description: "Escalate to human support when you can't resolve the question",
  }
};
```

Each tool has pre-written SQL. The LLM never sees or writes SQL. Example:

```typescript
// tools/search-member.ts

export async function searchMember(
  params: { search_term: string; search_type: "name" | "email" | "mobile" | "alias_id" },
  context: { allowedLocationIds: string[] }
) {
  const { search_term, search_type } = params;
  
  let sql: string;
  let queryParams: any[];

  switch (search_type) {
    case "name":
      sql = `
        SELECT m.id, m.given_name, m.surname, m.alias_member_id, m.email,
               m.mobile_number, m.is_active, m.outstanding_balance,
               m.home_location_id, l.name as location_name
        FROM member m
        LEFT JOIN location l ON l.id = m.home_location_id
        WHERE (m.given_name || ' ' || m.surname) ILIKE $1
          AND m.home_location_id = ANY($2)
          AND (m.__hevo__marked_deleted IS NULL OR m.__hevo__marked_deleted = false)
          AND (l.__hevo__marked_deleted IS NULL OR l.__hevo__marked_deleted = false)
        LIMIT 10`;
      queryParams = [`%${search_term}%`, context.allowedLocationIds];
      break;

    case "alias_id":
      sql = `
        SELECT m.id, m.given_name, m.surname, m.alias_member_id, m.email,
               m.mobile_number, m.is_active, m.outstanding_balance,
               m.home_location_id, l.name as location_name
        FROM member m
        LEFT JOIN location l ON l.id = m.home_location_id
        WHERE m.alias_member_id = $1
          AND m.home_location_id = ANY($2)
          AND (m.__hevo__marked_deleted IS NULL OR m.__hevo__marked_deleted = false)
        LIMIT 10`;
      queryParams = [parseInt(search_term), context.allowedLocationIds];
      break;

    // ... email, mobile cases
  }

  const result = await postgres.query(sql, queryParams);
  return result.rows;
}
```

**The LLM never sees this SQL.** It just says "call search_member with name = John Doe" and gets back the rows.

---

## The Complete Flow — Real Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          FRONTEND (vivareact)                        │
│                                                                      │
│  Staff types: "Jade says she had money but DD was rejected"         │
│  POST /api/v1/chat/message  { message: "...", sessionId: "..." }    │
│  Authorization: Bearer <cognito-jwt>                                 │
└──────────────────────────────────┬──────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          MINIHUB (Express)                            │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ 1. COGNITO AUTH MIDDLEWARE                                     │  │
│  │    Verify JWT → extract memberId, role, groups                │  │
│  └──────────────────────────┬────────────────────────────────────┘  │
│                              │                                       │
│  ┌──────────────────────────▼────────────────────────────────────┐  │
│  │ 2. CHAT SERVICE                                                │  │
│  │                                                                │  │
│  │  a) Resolve user's allowed locations (from Postgres)           │  │
│  │                                                                │  │
│  │  b) Load conversation history (from DynamoDB)                  │  │
│  │                                                                │  │
│  │  c) Build the system prompt:                                   │  │
│  │     ┌─────────────────────────────────────────────────────┐   │  │
│  │     │              SYSTEM PROMPT                           │   │  │
│  │     │                                                      │   │  │
│  │     │  Identity      (~200 tokens)  - who you are         │   │  │
│  │     │  Rules         (~500 tokens)  - read only, scoping  │   │  │
│  │     │  Knowledge Base (~1500 tokens) - loaded from DynamoDB│   │  │
│  │     │  Playbooks     (~1000 tokens) - loaded from DynamoDB│   │  │
│  │     │  Data Model    (~500 tokens)  - table relationships │   │  │
│  │     │  User Context  (~100 tokens)  - name, role, locs    │   │  │
│  │     │                                                      │   │  │
│  │     │  Total: ~3,800 tokens (~$0.01, or $0.001 cached)    │   │  │
│  │     └─────────────────────────────────────────────────────┘   │  │
│  │                                                                │  │
│  │  d) Call Anthropic API with:                                   │  │
│  │     - system prompt (cached)                                   │  │
│  │     - tool definitions (9 tools)                               │  │
│  │     - conversation history                                     │  │
│  │     - new user message                                         │  │
│  └──────────────────────────┬────────────────────────────────────┘  │
│                              │                                       │
│  ┌──────────────────────────▼────────────────────────────────────┐  │
│  │ 3. LLM DECISION                                                │  │
│  │                                                                │  │
│  │  Claude reads the system prompt and the question.              │  │
│  │  Claude decides ONE of three things:                           │  │
│  │                                                                │  │
│  │  ┌──────────────────────────────────────────────────────────┐ │  │
│  │  │  OPTION A: Knowledge Base Answer                          │ │  │
│  │  │                                                            │ │  │
│  │  │  "This matches a known pattern. I can answer directly."   │ │  │
│  │  │                                                            │ │  │
│  │  │  → Returns text response immediately                      │ │  │
│  │  │  → No tools called                                        │ │  │
│  │  │  → Cheapest path (1 API call)                             │ │  │
│  │  │                                                            │ │  │
│  │  │  Example: "Jade's DD was rejected as INSUFFICIENT_FUNDS.  │ │  │
│  │  │  This comes from the bank, not Hub..."                    │ │  │
│  │  └──────────────────────────────────────────────────────────┘ │  │
│  │                                                                │  │
│  │  ┌──────────────────────────────────────────────────────────┐ │  │
│  │  │  OPTION B: Follow a Playbook (needs data)                 │ │  │
│  │  │                                                            │ │  │
│  │  │  "This needs investigation. I'll follow the steps."       │ │  │
│  │  │                                                            │ │  │
│  │  │  → Calls tools in sequence (your code runs the SQL)       │ │  │
│  │  │  → Each tool result comes back, Claude continues          │ │  │
│  │  │  → 2-4 API calls total                                    │ │  │
│  │  │                                                            │ │  │
│  │  │  Example: "Why was member 4521 charged $50?"              │ │  │
│  │  │  → search_member(4521) → get_payments(...) → answer      │ │  │
│  │  └──────────────────────────────────────────────────────────┘ │  │
│  │                                                                │  │
│  │  ┌──────────────────────────────────────────────────────────┐ │  │
│  │  │  OPTION C: Can't Help                                     │ │  │
│  │  │                                                            │ │  │
│  │  │  "This is outside what I can do."                         │ │  │
│  │  │                                                            │ │  │
│  │  │  → Returns escalation message                             │ │  │
│  │  │  → Suggests contacting support@vivaleisure.com.au         │ │  │
│  │  │                                                            │ │  │
│  │  │  Example: "Can you cancel this member's contract?"        │ │  │
│  │  └──────────────────────────────────────────────────────────┘ │  │
│  │                                                                │  │
│  └──────────────────────────┬────────────────────────────────────┘  │
│                              │                                       │
│  ┌──────────────────────────▼────────────────────────────────────┐  │
│  │ 4. TOOL EXECUTION LOOP (only for Option B)                     │  │
│  │                                                                │  │
│  │  Claude: "Call search_member({ alias_id: '4521' })"           │  │
│  │      │                                                         │  │
│  │      ▼                                                         │  │
│  │  Your code: Validates params → runs pre-built SQL → returns   │  │
│  │      │                                                         │  │
│  │      ▼                                                         │  │
│  │  Claude: "Got it. Now call get_payments({ member_id: '...' })"│  │
│  │      │                                                         │  │
│  │      ▼                                                         │  │
│  │  Your code: Validates → runs SQL → returns                    │  │
│  │      │                                                         │  │
│  │      ▼                                                         │  │
│  │  Claude: "I have all the data. Here's the answer: ..."        │  │
│  └──────────────────────────┬────────────────────────────────────┘  │
│                              │                                       │
│  ┌──────────────────────────▼────────────────────────────────────┐  │
│  │ 5. SAVE & RESPOND                                              │  │
│  │                                                                │  │
│  │  • Save user message + bot response to DynamoDB                │  │
│  │  • Save metadata (tools called, tokens used, cost)             │  │
│  │  • Return response to frontend                                 │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Where Everything is Stored

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DynamoDB                                     │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Table: minihub-chat-knowledge                               │   │
│  │                                                               │   │
│  │  Knowledge Base entries (FAQ answers)                         │   │
│  │  PK: KB#<category>    SK: <id>                               │   │
│  │                                                               │   │
│  │  { id, category, title, triggers, answer, needsQuery,        │   │
│  │    relatedPlaybook, createdBy, updatedAt }                    │   │
│  │                                                               │   │
│  │  Playbook entries (troubleshooting steps)                     │   │
│  │  PK: PB#<category>    SK: <id>                               │   │
│  │                                                               │   │
│  │  { id, name, triggers, steps[], createdBy, updatedAt }       │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Table: minihub-chat-messages                                │   │
│  │                                                               │   │
│  │  Chat sessions & messages (audit trail)                       │   │
│  │  PK: SESSION#<id>    SK: META | MSG#<timestamp>#<id>         │   │
│  │  GSI1: MEMBER#<id>   GSI1SK: SESSION#<createdAt>             │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                     Postgres (READ ONLY)                              │
│                                                                      │
│  member, location, brand, batch_payment, rejection_payment,          │
│  transaction, payment_information, member_contract,                   │
│  member_contract_billing, group_staff, group, group_location          │
│                                                                      │
│  ⛔ NEVER WRITTEN TO BY THE CHAT SYSTEM                              │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                     Anthropic API (External)                          │
│                                                                      │
│  Called via HTTP from MiniHub. Stateless.                             │
│  API key in env vars. Prompt caching enabled.                        │
└─────────────────────────────────────────────────────────────────────┘
```

---

## The Admin UI — Managing Knowledge & Playbooks

You mentioned wanting a UI to add conditions and troubleshooting steps. Here's what that looks like:

### Admin Endpoints (Future — Phase 2)

```
POST   /api/v1/chat/admin/knowledge          — Add a knowledge base entry
PUT    /api/v1/chat/admin/knowledge/:id       — Update an entry
DELETE /api/v1/chat/admin/knowledge/:id       — Remove an entry
GET    /api/v1/chat/admin/knowledge           — List all entries

POST   /api/v1/chat/admin/playbooks           — Add a playbook
PUT    /api/v1/chat/admin/playbooks/:id       — Update a playbook
DELETE /api/v1/chat/admin/playbooks/:id       — Remove a playbook
GET    /api/v1/chat/admin/playbooks           — List all playbooks
```

**Restricted to L5 / admin / super-admin only.**

### What the Admin UI Would Look Like

```
┌─────────────────────────────────────────────────────────────┐
│  AI Support Chat — Knowledge Base Manager                    │
│                                                              │
│  [Knowledge Base]  [Playbooks]  [Chat Logs]  [Settings]     │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ + Add Knowledge Entry                                  │  │
│  │                                                         │  │
│  │ Category: [ DD Rejections          ▼ ]                 │  │
│  │ Title:    [ Member claims sufficient funds           ] │  │
│  │                                                         │  │
│  │ Trigger phrases (one per line):                        │  │
│  │ ┌───────────────────────────────────────────────────┐ │  │
│  │ │ insufficient funds                                 │ │  │
│  │ │ had money in account                               │ │  │
│  │ │ enough money                                       │ │  │
│  │ │ bank rejected                                      │ │  │
│  │ └───────────────────────────────────────────────────┘ │  │
│  │                                                         │  │
│  │ Answer:                                                 │  │
│  │ ┌───────────────────────────────────────────────────┐ │  │
│  │ │ The rejection reason INSUFFICIENT_FUNDS comes     │ │  │
│  │ │ from the member's bank, not from Hub. Hub only    │ │  │
│  │ │ receives and displays the rejection code...       │ │  │
│  │ └───────────────────────────────────────────────────┘ │  │
│  │                                                         │  │
│  │ ☐ Requires database query                               │  │
│  │ Related playbook: [ None                       ▼ ]     │  │
│  │                                                         │  │
│  │                              [ Cancel ]  [ Save ]      │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                              │
│  Existing entries:                                           │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ 📋 DD Rejections                                       │ │
│  │    • INSUFFICIENT_FUNDS — member claims had money    ✏ │ │
│  │    • ACCOUNT_CLOSED                                  ✏ │ │
│  │    • REFER_TO_CUSTOMER                               ✏ │ │
│  │                                                        │ │
│  │ 📋 Billing                                             │ │
│  │    • Why was I charged — general                     ✏ │ │
│  │    • Charged twice — general                         ✏ │ │
│  │                                                        │ │
│  │ 📋 Contracts                                           │ │
│  │    • Cancellation fees                               ✏ │ │
│  │    • Suspension rules                                ✏ │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Playbook Editor

```
┌─────────────────────────────────────────────────────────────┐
│  Playbook: Investigate a specific charge                     │
│                                                              │
│  Trigger phrases:                                            │
│  [ why was charged, what is this charge, payment on date ]  │
│                                                              │
│  Steps:                                                      │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Step 1: Find the member                               │  │
│  │ Tool:  [ search_member  ▼ ]                           │  │
│  │ Notes: Search by whatever info was provided           │  │
│  │ If not found: Ask for more details                    │  │
│  │                                             [↑] [↓] [✕]│  │
│  ├───────────────────────────────────────────────────────┤  │
│  │ Step 2: Check batch payments                          │  │
│  │ Tool:  [ get_payments   ▼ ]                           │  │
│  │ Notes: Match date and amount. Check payment_type,     │  │
│  │        status, card used.                             │  │
│  │                                             [↑] [↓] [✕]│  │
│  ├───────────────────────────────────────────────────────┤  │
│  │ Step 3: Check contract billing                        │  │
│  │ Tool:  [ get_contract   ▼ ]                           │  │
│  │ Notes: Verify billing frequency matches charges       │  │
│  │                                             [↑] [↓] [✕]│  │
│  ├───────────────────────────────────────────────────────┤  │
│  │ + Add Step                                            │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                              │
│                              [ Cancel ]  [ Save Playbook ]  │
└─────────────────────────────────────────────────────────────┘
```

---

## How Knowledge & Playbooks Get Into the System Prompt

At request time, your code loads the knowledge base and playbooks from DynamoDB and injects them into the system prompt:

```typescript
async function buildSystemPrompt(userContext: UserContext): Promise<string> {

  // 1. Static parts (from .md files or constants — never change)
  const identity = IDENTITY_PROMPT;      // "You are Hub Support Assistant..."
  const rules = RULES_PROMPT;            // "Read only, location scoped..."
  const dataModel = DATA_MODEL_PROMPT;   // "member → location → brand..."

  // 2. Dynamic parts (from DynamoDB — editable via admin UI)
  const knowledgeEntries = await loadKnowledgeBase();   // All KB entries
  const playbooks = await loadPlaybooks();               // All playbooks

  // 3. Format knowledge base for the prompt
  const knowledgeSection = knowledgeEntries.map(kb => `
### ${kb.title}
Category: ${kb.category}
${kb.answer ? `Answer: ${kb.answer}` : `Action: Follow playbook ${kb.relatedPlaybook}`}
  `).join("\n");

  // 4. Format playbooks for the prompt
  const playbookSection = playbooks.map(pb => `
### Playbook: ${pb.name}
When to use: ${pb.triggers.join(", ")}
Steps:
${pb.steps.map(s => `  ${s.step}. ${s.action} → use ${s.tool || 'no tool'}: ${s.description}`).join("\n")}
  `).join("\n");

  // 5. User context (changes every request)
  const context = `
User: ${userContext.name} (${userContext.role})
Allowed locations: ${userContext.locationIds.join(", ")}
Date: ${new Date().toISOString().split("T")[0]}
  `;

  // 6. Combine everything
  return [
    identity,
    rules,
    `<knowledge_base>\n${knowledgeSection}\n</knowledge_base>`,
    `<playbooks>\n${playbookSection}\n</playbooks>`,
    dataModel,
    `<context>\n${context}\n</context>`
  ].join("\n\n");
}
```

### Caching Strategy

You don't want to load from DynamoDB on every single request. Cache the knowledge base and playbooks in memory:

```typescript
let knowledgeCache: KnowledgeEntry[] | null = null;
let playbookCache: Playbook[] | null = null;
let lastCacheRefresh = 0;

const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

async function loadKnowledgeBase(): Promise<KnowledgeEntry[]> {
  if (knowledgeCache && Date.now() - lastCacheRefresh < CACHE_TTL) {
    return knowledgeCache;
  }
  // Load from DynamoDB
  knowledgeCache = await queryDynamoDB(/* ... */);
  lastCacheRefresh = Date.now();
  return knowledgeCache;
}
```

Plus, Anthropic's **prompt caching** means the system prompt itself is cached on their side for 5 minutes. So:

```
Request 1:  Load KB from DynamoDB → build prompt → send to Anthropic (full price)
Request 2-N (within 5 min): Read from memory cache → send to Anthropic (90% discount on system prompt)
```

---

## Token Budget Breakdown (Real Numbers)

For a typical question:

```
SYSTEM PROMPT (cached after first request):
  Identity & rules:         ~700 tokens
  Knowledge base (30 entries): ~1,500 tokens
  Playbooks (10 playbooks):  ~1,000 tokens
  Data model:                ~500 tokens
  User context:              ~100 tokens
  ─────────────────────────────────────
  Subtotal:                  ~3,800 tokens

  First request cost:  3,800 × $3/M = $0.0114
  Cached cost:         3,800 × $0.30/M = $0.00114  (90% cheaper)

CONVERSATION + RESPONSE:
  History (last 10 msgs):   ~2,000 tokens input
  Tool definitions:          ~800 tokens input
  User message:             ~100 tokens input
  Response:                 ~500 tokens output
  ─────────────────────────────────────
  Input subtotal:           ~2,900 tokens × $3/M = $0.0087
  Output subtotal:          ~500 tokens × $15/M = $0.0075

TOTAL PER REQUEST (with caching):
  System (cached): $0.00114
  Conversation:    $0.0087
  Response:        $0.0075
  ──────────────────────────
  Total:           ~$0.017 per question  (~1.7 cents)

  100 questions/day = $1.70/day = ~$51/month
  500 questions/day = $8.50/day = ~$255/month
```

---

## The Feedback Loop — Getting Better Over Time

```
┌─────────────────────────────────────────────────────────────┐
│                     THE IMPROVEMENT CYCLE                     │
│                                                              │
│  1. Staff asks question                                      │
│     ↓                                                        │
│  2. Bot answers (or can't answer)                            │
│     ↓                                                        │
│  3. Everything is logged in DynamoDB                         │
│     ↓                                                        │
│  4. Admin reviews chat logs weekly                           │
│     ↓                                                        │
│  5. Finds patterns:                                          │
│     • "Bot answered this wrong" → fix knowledge base entry   │
│     • "Bot couldn't answer this" → add new KB entry          │
│     • "Bot took wrong steps" → update playbook               │
│     • "New question type" → create new playbook + tools      │
│     ↓                                                        │
│  6. Update via Admin UI → changes take effect in 5 minutes   │
│     ↓                                                        │
│  7. Bot handles it correctly next time                       │
│                                                              │
│  No code deployment needed for knowledge/playbook changes.   │
│  Only need deployment for new tools (new SQL queries).       │
└─────────────────────────────────────────────────────────────┘
```

---

## File Structure — What Gets Built

```
app/src/
├── middleware/
│   ├── api-key-auth.ts              # existing (unchanged)
│   └── cognito-auth.ts              # NEW — JWT verification
│
├── routes/api/handlers/
│   ├── chat.handler.ts              # NEW — chat endpoints
│   ├── chat-admin.handler.ts        # NEW — KB/playbook management (Phase 2)
│   └── ...existing handlers...
│
├── services/
│   ├── chat/
│   │   ├── chat-service.ts          # NEW — orchestration
│   │   ├── llm-service.ts           # NEW — Anthropic API calls
│   │   ├── knowledge-service.ts     # NEW — load KB from DynamoDB
│   │   ├── playbook-service.ts      # NEW — load playbooks from DynamoDB
│   │   ├── prompt-builder.ts        # NEW — assemble system prompt
│   │   └── location-resolver.ts     # NEW — resolve user's locations
│   │
│   ├── tools/                        # NEW — pre-built database queries
│   │   ├── tool-registry.ts         # Tool definitions for LLM
│   │   ├── tool-executor.ts         # Receives tool call, runs query
│   │   ├── search-member.ts
│   │   ├── get-payments.ts
│   │   ├── get-rejections.ts
│   │   ├── get-transactions.ts
│   │   ├── get-contract.ts
│   │   ├── get-payment-methods.ts
│   │   ├── get-member-balance.ts
│   │   ├── get-location-stats.ts
│   │   └── escalate.ts
│   │
│   ├── postgres.ts                   # existing (unchanged)
│   └── dynamodb.ts                   # existing (unchanged)
│
├── prompts/                           # NEW — static prompt parts
│   ├── identity.md                   # Bot personality (rarely changes)
│   ├── rules.md                      # Hard rules (rarely changes)
│   └── data-model.md                 # Table relationships (when schema changes)
│
└── config.ts                          # MODIFIED — add new env vars
```

---

## Summary — One Page

```
WHAT:     AI support chat for Hub staff
WHERE:    MiniHub Express API (new module, no existing code changed)
HOW:      Anthropic Claude API (stateless HTTP calls from your server)

KNOWLEDGE LIVES IN:
  • Knowledge Base (DynamoDB) — FAQ answers, no query needed
  • Playbooks (DynamoDB)      — step-by-step troubleshooting with queries
  • Tools (TypeScript code)   — pre-built SQL, safe, tested

THE LLM DOES:
  ✅ Understands the question (natural language → intent)
  ✅ Picks the right knowledge base answer OR playbook
  ✅ Calls your tools in the right sequence
  ✅ Formats results into human-friendly answers

THE LLM DOES NOT:
  ❌ Write SQL
  ❌ Access the database directly
  ❌ Remember anything between requests
  ❌ Answer questions outside Hub scope
  ❌ Modify any data

COST: ~$0.02 per question ($50-250/month depending on volume)
SAFETY: 8 layers, Postgres read-only user as final backstop
MANAGEMENT: Admin UI to add/edit knowledge & playbooks (no deploys needed)
```
