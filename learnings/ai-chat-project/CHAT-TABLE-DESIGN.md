# Chat Table Design — Hands On

> Designing `minihub-chat` from scratch with real data, building analogy, and every access pattern.
> This is the table that stores all AI chat sessions and messages for the Hub support chatbot.

---

## Step 0 — What Are We Storing?

Before touching DynamoDB, write down everything in plain English.

```
THINGS THAT EXIST:
  1. A chat SESSION
       → Created when staff opens the chat window
       → Knows: who opened it (staff memberId), which location context,
                what locations they're allowed to see, when it started, status
       → One session = one conversation

  2. A MESSAGE inside a session
       → A staff question ("Why was John charged twice?")
       → An AI answer ("John was charged because...")
       → Knows: who said it (user/assistant), the text, when, which tools AI used

  3. A SUMMARY of a session
       → Generated after chat closes
       → Human-readable snapshot of what was discussed
       → Used for: knowledge building, support team audit, trend analysis
```

Two tables because they have completely different lifecycles (explained in `AI-CHAT-DYNAMODB-DESIGN.md`):

```
minihub-chat          → sessions + messages + summaries  (this doc)
minihub-chat-knowledge → knowledge base + playbooks      (separate doc)
```

---

## Step 1 — Access Patterns First

**Rule: Design the keys around the questions. Not the other way around.**

Write every question the system will ever need to ask:

```
QUESTION 1:  "Load the full conversation for session sess_abc123"
             → Need all messages + session info in one query
             → How: PK = sessionId → all items in that room

QUESTION 2:  "Load only the messages for session sess_abc123"
             → Skip session metadata, just get messages
             → How: PK = sessionId, SK BEGINS_WITH "MSG#"

QUESTION 3:  "Load just the session metadata for sess_abc123"
             → Is it still active? Who owns it? How many messages?
             → How: PK = sessionId, SK = "SESSION"

QUESTION 4:  "Did this session produce a summary yet?"
             → How: PK = sessionId, SK = "SUMMARY"

QUESTION 5:  "Show all sessions created by staff member Chris Nguyen"
             (so Chris can continue a previous conversation)
             → How: GSI — memberId as PK, createdAt as SK

QUESTION 6:  "Show Chris's 5 most recent sessions"
             → How: GSI — memberId as PK, createdAt as SK, sort DESC, limit 5

QUESTION 7:  "Show all sessions at Location Plus Fitness Sydney CBD today"
             (for admin/reporting — what are staff asking at this location?)
             → How: GSI — locationContext as PK, createdAt as SK

QUESTION 8:  "Show all sessions at this location in February 2026"
             → How: GSI — locationContext as PK, createdAt BETWEEN range

QUESTION 9:  "Get messages in this session after 09:03:00 (to paginate)"
             → How: PK = sessionId, SK > "MSG#2026-02-26T09:03:00"

QUESTION 10: "Get the last N messages for context window management"
             → How: PK = sessionId, SK BEGINS_WITH "MSG#", sort DESC, limit N
```

That's 10 access patterns. Now design keys to serve all 10.

---

## Step 2 — Table Design

```
TABLE NAME: minihub-chat

Partition Key: sessionId    (String)
Sort Key:      itemType     (String)

GSI 1: memberSessionsIndex
  PK: memberId      (String)
  SK: createdAt     (String — ISO timestamp, so it sorts correctly)
  Projects: sessionId, locationContext, title, status, messageCount, createdAt

GSI 2: locationSessionsIndex
  PK: locationContext   (String)
  SK: createdAt         (String)
  Projects: sessionId, memberId, memberName, title, status, messageCount, createdAt
```

### The Building Map

```
MAIN BUILDING (minihub-chat)
  Rooms keyed by sessionId → one room per conversation

GSI BUILDING 1 (memberSessionsIndex)
  Rooms keyed by memberId → "all sessions Chris ever started"

GSI BUILDING 2 (locationSessionsIndex)
  Rooms keyed by locationContext → "all sessions at Sydney CBD"
```

---

## Step 3 — The Three Item Types

Every item in the table is one of three shapes.

### Shape 1 — SESSION

```
The "header" of a conversation. One per session.

Attributes:
  sessionId         → PK — "sess_abc123"
  itemType          → SK — always "SESSION"
  memberId          → GSI 1 PK — staff member who owns this session
  aliasId           → staff's human-readable ID (e.g., 10045) — for display only
  memberName        → "Chris Nguyen" — denormalised for display speed
  memberRole        → "L3" — their Cognito group at session creation
  locationContext   → GSI 2 PK — which location they were working in when they opened chat
  allowedLocationIds→ ["loc-sydney-cbd-001", "loc-parramatta-001"] — full access list (for audit)
  title             → auto-generated from first question, or "New Chat"
  status            → "ACTIVE" | "CLOSED"
  messageCount      → running counter
  createdAt         → GSI 1 SK, GSI 2 SK — ISO timestamp
  updatedAt         → last activity
  expiresAt         → Unix epoch — TTL (90 days from createdAt)
```

### Shape 2 — MSG#

```
One item per message (both user messages and AI replies).

Attributes:
  sessionId         → PK (same as SESSION item → same room)
  itemType          → SK — "MSG#2026-02-26T09:01:00.000Z#msg001"
                           ↑ timestamp + msgId ensures:
                           (a) alphabetical sort = chronological order
                           (b) uniqueness if two messages arrive at same millisecond
  messageId         → "msg001" — short ID
  role              → "user" | "assistant"
  content           → the actual message text
  toolsCalled       → ["findMember", "getPayments"] — only on assistant messages
  tokensUsed        → 1250 — only on assistant messages (for cost tracking)
  model             → "claude-sonnet-4-6" — which model answered
  createdAt         → ISO timestamp (same as in SK)
  expiresAt         → TTL (same 90-day window as the session)
```

### Shape 3 — SUMMARY

```
Post-session summary. Written when chat is closed. One per session.

Attributes:
  sessionId         → PK (same room as everything else)
  itemType          → SK — always "SUMMARY"
  summary           → paragraph of what was discussed
  topicTags         → ["payment", "direct-debit", "rejection"]
  resolved          → true/false — did the AI answer the question?
  questionsAsked    → 3 — count for analytics
  toolsUsed         → ["findMember", "getPayments", "getRejections"]
  createdAt         → when summary was written
  expiresAt         → TTL
```

---

## Step 4 — 12 Real Data Rows

Three sessions. Real Viva staff. Real questions.

```
─────────────────────────────────────────────────────────────────────────────
SESSION 1: Chris asks about a member's payment
Staff:  Chris Nguyen | aliasId: 10045 | Role: L3 | Location: Plus Fitness Sydney CBD
─────────────────────────────────────────────────────────────────────────────

ROW 1 — SESSION item
┌────────────────────────────────────────────────────────────────────────┐
│ sessionId:          "sess_abc123"                                       │
│ itemType:           "SESSION"                                           │
│ memberId:           "a1b2c3d4-e5f6-7890-abcd-ef1234567890"             │  ← GSI 1 PK
│ aliasId:            10045                                               │
│ memberName:         "Chris Nguyen"                                      │
│ memberRole:         "L3"                                                │
│ locationContext:    "loc-sydney-cbd-001"                                │  ← GSI 2 PK
│ allowedLocationIds: ["loc-sydney-cbd-001", "loc-parramatta-001"]        │
│ title:              "Why was John Doe charged $50 on 25 Feb?"           │
│ status:             "CLOSED"                                            │
│ messageCount:       4                                                   │
│ createdAt:          "2026-02-26T09:00:00.000Z"                         │  ← GSI 1 SK, GSI 2 SK
│ updatedAt:          "2026-02-26T09:05:30.000Z"                         │
│ expiresAt:          1803672000  (90 days TTL)                           │
└────────────────────────────────────────────────────────────────────────┘

ROW 2 — First user message
┌────────────────────────────────────────────────────────────────────────┐
│ sessionId:    "sess_abc123"                                             │
│ itemType:     "MSG#2026-02-26T09:01:00.000Z#msg001"                    │
│ messageId:    "msg001"                                                  │
│ role:         "user"                                                    │
│ content:      "Why was member John Doe alias 4521 charged $50 on       │
│                25/02/2026?"                                             │
│ createdAt:    "2026-02-26T09:01:00.000Z"                               │
│ expiresAt:    1803672000                                                │
└────────────────────────────────────────────────────────────────────────┘

ROW 3 — First AI reply
┌────────────────────────────────────────────────────────────────────────┐
│ sessionId:    "sess_abc123"                                             │
│ itemType:     "MSG#2026-02-26T09:01:05.000Z#msg002"                    │
│ messageId:    "msg002"                                                  │
│ role:         "assistant"                                               │
│ content:      "Member John Doe (#4521) was charged $50.00 on           │
│                25/02/2026 as part of their fortnightly direct debit.   │
│                Their contract 'Plus Fitness Fortnightly — $50' has     │
│                been active since 10/01/2025 and bills every second     │
│                Thursday via bank account ending 456."                   │
│ toolsCalled:  ["findMemberByAlias", "getMemberContracts",              │
│                "getRecentPayments"]                                     │
│ tokensUsed:   1842                                                      │
│ model:        "claude-sonnet-4-6"                                       │
│ createdAt:    "2026-02-26T09:01:05.000Z"                               │
│ expiresAt:    1803672000                                                │
└────────────────────────────────────────────────────────────────────────┘

ROW 4 — Follow-up message
┌────────────────────────────────────────────────────────────────────────┐
│ sessionId:    "sess_abc123"                                             │
│ itemType:     "MSG#2026-02-26T09:03:00.000Z#msg003"                    │
│ messageId:    "msg003"                                                  │
│ role:         "user"                                                    │
│ content:      "Is there any rejection on their account?"               │
│ createdAt:    "2026-02-26T09:03:00.000Z"                               │
│ expiresAt:    1803672000                                                │
└────────────────────────────────────────────────────────────────────────┘

ROW 5 — AI reply to follow-up
┌────────────────────────────────────────────────────────────────────────┐
│ sessionId:    "sess_abc123"                                             │
│ itemType:     "MSG#2026-02-26T09:03:08.000Z#msg004"                    │
│ messageId:    "msg004"                                                  │
│ role:         "assistant"                                               │
│ content:      "No rejections found. Their last 6 payments have all    │
│                cleared successfully. The most recent was $50.00 on    │
│                25/02/2026."                                             │
│ toolsCalled:  ["getRejections"]                                        │
│ tokensUsed:   620                                                       │
│ model:        "claude-sonnet-4-6"                                       │
│ createdAt:    "2026-02-26T09:03:08.000Z"                               │
│ expiresAt:    1803672000                                                │
└────────────────────────────────────────────────────────────────────────┘

ROW 6 — Summary (written when Chris closed the chat)
┌────────────────────────────────────────────────────────────────────────┐
│ sessionId:       "sess_abc123"                                          │
│ itemType:        "SUMMARY"                                              │
│ summary:         "Staff Chris Nguyen (L3, Sydney CBD) asked about      │
│                   member John Doe #4521's $50 charge on 25/02/2026.   │
│                   Confirmed this was a normal fortnightly DD payment   │
│                   via bank account ending 456. No rejections on        │
│                   account. Query fully resolved by AI."                 │
│ topicTags:       ["payment", "direct-debit", "member-query"]           │
│ resolved:        true                                                   │
│ questionsAsked:  2                                                      │
│ toolsUsed:       ["findMemberByAlias", "getMemberContracts",           │
│                   "getRecentPayments", "getRejections"]                 │
│ createdAt:       "2026-02-26T09:05:30.000Z"                            │
│ expiresAt:       1803672000                                             │
└────────────────────────────────────────────────────────────────────────┘


─────────────────────────────────────────────────────────────────────────────
SESSION 2: Kelly asks about a contract at Parramatta
Staff:  Kelly Tran | aliasId: 20187 | Role: L2 | Location: Plus Fitness Parramatta
─────────────────────────────────────────────────────────────────────────────

ROW 7 — SESSION item
┌────────────────────────────────────────────────────────────────────────┐
│ sessionId:          "sess_def456"                                       │
│ itemType:           "SESSION"                                           │
│ memberId:           "b2c3d4e5-f6a7-8901-bcde-f12345678901"             │  ← GSI 1 PK
│ aliasId:            20187                                               │
│ memberName:         "Kelly Tran"                                        │
│ memberRole:         "L2"                                                │
│ locationContext:    "loc-parramatta-001"                                │  ← GSI 2 PK
│ allowedLocationIds: ["loc-parramatta-001"]                              │
│ title:              "Is Sarah Ahmed's contract still active?"           │
│ status:             "ACTIVE"                                            │  ← still open
│ messageCount:       2                                                   │
│ createdAt:          "2026-02-26T10:15:00.000Z"                         │
│ updatedAt:          "2026-02-26T10:15:45.000Z"                         │
│ expiresAt:          1803672000                                          │
└────────────────────────────────────────────────────────────────────────┘

ROW 8 — User message
┌────────────────────────────────────────────────────────────────────────┐
│ sessionId:    "sess_def456"                                             │
│ itemType:     "MSG#2026-02-26T10:15:10.000Z#msg001"                    │
│ role:         "user"                                                    │
│ content:      "Is Sarah Ahmed's membership contract still active?      │
│                Her email is sarah.ahmed@outlook.com"                   │
│ createdAt:    "2026-02-26T10:15:10.000Z"                               │
│ expiresAt:    1803672000                                                │
└────────────────────────────────────────────────────────────────────────┘

ROW 9 — AI reply
┌────────────────────────────────────────────────────────────────────────┐
│ sessionId:    "sess_def456"                                             │
│ itemType:     "MSG#2026-02-26T10:15:45.000Z#msg002"                    │
│ role:         "assistant"                                               │
│ content:      "Yes, Sarah Ahmed's contract is active. She is on a     │
│                'Monthly — $69.95' membership at Plus Fitness           │
│                Parramatta. Contract started 15/08/2024, no end date   │
│                (ongoing). Next payment due 01/03/2026 — $69.95."      │
│ toolsCalled:  ["findMemberByEmail", "getMemberContracts"]              │
│ tokensUsed:   1105                                                      │
│ model:        "claude-sonnet-4-6"                                       │
│ createdAt:    "2026-02-26T10:15:45.000Z"                               │
│ expiresAt:    1803672000                                                │
└────────────────────────────────────────────────────────────────────────┘


─────────────────────────────────────────────────────────────────────────────
SESSION 3: Chris's earlier session (yesterday) — so we have history to query
Staff:  Chris Nguyen | aliasId: 10045 | Role: L3 | Location: Plus Fitness Sydney CBD
─────────────────────────────────────────────────────────────────────────────

ROW 10 — SESSION item
┌────────────────────────────────────────────────────────────────────────┐
│ sessionId:          "sess_xyz789"                                       │
│ itemType:           "SESSION"                                           │
│ memberId:           "a1b2c3d4-e5f6-7890-abcd-ef1234567890"             │  ← same Chris
│ aliasId:            10045                                               │
│ memberName:         "Chris Nguyen"                                      │
│ memberRole:         "L3"                                                │
│ locationContext:    "loc-sydney-cbd-001"                                │
│ allowedLocationIds: ["loc-sydney-cbd-001", "loc-parramatta-001"]        │
│ title:              "What card does member 9923 have on file?"         │
│ status:             "CLOSED"                                            │
│ messageCount:       2                                                   │
│ createdAt:          "2026-02-25T14:30:00.000Z"                         │  ← yesterday
│ updatedAt:          "2026-02-25T14:32:00.000Z"                         │
│ expiresAt:          1803585600                                          │
└────────────────────────────────────────────────────────────────────────┘

ROW 11 — User message
┌────────────────────────────────────────────────────────────────────────┐
│ sessionId:    "sess_xyz789"                                             │
│ itemType:     "MSG#2026-02-25T14:30:20.000Z#msg001"                    │
│ role:         "user"                                                    │
│ content:      "What payment method does member #9923 have on file?"   │
│ createdAt:    "2026-02-25T14:30:20.000Z"                               │
│ expiresAt:    1803585600                                                │
└────────────────────────────────────────────────────────────────────────┘

ROW 12 — SUMMARY for session 3
┌────────────────────────────────────────────────────────────────────────┐
│ sessionId:       "sess_xyz789"                                          │
│ itemType:        "SUMMARY"                                              │
│ summary:         "Staff Chris Nguyen asked about payment method for    │
│                   member #9923 at Sydney CBD. Member has card ending   │
│                   in 4821 (Mastercard) on file. Query resolved."       │
│ topicTags:       ["payment-method", "card", "member-query"]            │
│ resolved:        true                                                   │
│ questionsAsked:  1                                                      │
│ toolsUsed:       ["findMemberByAlias", "getPaymentInfo"]               │
│ createdAt:       "2026-02-25T14:32:00.000Z"                            │
│ expiresAt:       1803585600                                             │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Step 5 — The Building, Visualised

```
MAIN BUILDING (minihub-chat)
│
├── FLOOR 4  (hash of "sess_abc123")
│   └── ROOM "sess_abc123"          ← Chris's 26 Feb session
│       ├── Shelf: MSG#2026-02-26T09:01:00...#msg001  ← user question 1
│       ├── Shelf: MSG#2026-02-26T09:01:05...#msg002  ← AI answer 1
│       ├── Shelf: MSG#2026-02-26T09:03:00...#msg003  ← user question 2
│       ├── Shelf: MSG#2026-02-26T09:03:08...#msg004  ← AI answer 2
│       ├── Shelf: SESSION                             ← session metadata
│       └── Shelf: SUMMARY                            ← post-session summary
│           (M before S alphabetically → messages first, then SESSION, then SUMMARY)
│
├── FLOOR 7  (hash of "sess_def456")
│   └── ROOM "sess_def456"          ← Kelly's session
│       ├── Shelf: MSG#2026-02-26T10:15:10...#msg001
│       ├── Shelf: MSG#2026-02-26T10:15:45...#msg002
│       └── Shelf: SESSION
│           (No SUMMARY yet — session is still ACTIVE)
│
└── FLOOR 2  (hash of "sess_xyz789")
    └── ROOM "sess_xyz789"          ← Chris's 25 Feb session (yesterday)
        ├── Shelf: MSG#2026-02-25T14:30:20...#msg001
        ├── Shelf: SESSION
        └── Shelf: SUMMARY


GSI BUILDING 1 (memberSessionsIndex)
Rooms keyed by memberId
│
├── ROOM "a1b2c3d4-e5f6-7890-abcd-ef1234567890"   ← Chris's room
│   ├── Shelf: 2026-02-25T14:30:00.000Z  → sess_xyz789 (yesterday)
│   └── Shelf: 2026-02-26T09:00:00.000Z  → sess_abc123 (today)
│       (sorted by createdAt → chronological order)
│
└── ROOM "b2c3d4e5-f6a7-8901-bcde-f12345678901"   ← Kelly's room
    └── Shelf: 2026-02-26T10:15:00.000Z  → sess_def456


GSI BUILDING 2 (locationSessionsIndex)
Rooms keyed by locationContext
│
├── ROOM "loc-sydney-cbd-001"
│   ├── Shelf: 2026-02-25T14:30:00.000Z  → sess_xyz789 (Chris yesterday)
│   └── Shelf: 2026-02-26T09:00:00.000Z  → sess_abc123 (Chris today)
│
└── ROOM "loc-parramatta-001"
    └── Shelf: 2026-02-26T10:15:00.000Z  → sess_def456 (Kelly today)
```

---

## Step 6 — Every Access Pattern Answered

### Pattern 1: Load full conversation for the AI (send history to Claude)

```
Query:  PK = "sess_abc123"
        SK BEGINS_WITH "MSG#"
        Sort: ascending (oldest first)

→ Goes to Room "sess_abc123"
→ Reads only the MSG# shelves (skips SESSION and SUMMARY)
→ Returns 4 message items in chronological order
→ Feed directly into Claude's messages[] array  ✅
```

### Pattern 2: Load session header (is it still active? who owns it?)

```
Query:  PK = "sess_abc123"
        SK = "SESSION"

→ One shelf. Direct jump. Returns session metadata only.
→ Use to check: is this session still ACTIVE? Does this memberId own it?  ✅
```

### Pattern 3: Check if a session has a summary already

```
Query:  PK = "sess_abc123"
        SK = "SUMMARY"

→ If item exists → summary is written → return it
→ If item not found → chat still open or summary not yet generated  ✅
```

### Pattern 4: Load everything about a session in one shot

```
Query:  PK = "sess_abc123"
        (no SK filter)

→ Returns ALL 6 items: 4 messages + SESSION + SUMMARY
→ Used by the admin review screen  ✅
```

### Pattern 5: Show Chris's session history (sidebar)

```
GSI Query:  memberSessionsIndex
            PK = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
            Sort: descending (newest first)

→ Goes to GSI Building 1
→ Chris's room: sess_abc123 (today) + sess_xyz789 (yesterday)
→ Returns most recent sessions at top  ✅
```

### Pattern 6: Show Chris's last 5 sessions only

```
GSI Query:  memberSessionsIndex
            PK = "a1b2c3d4-..."
            Sort: descending
            Limit: 5

→ Same room, just stop after 5 items  ✅
```

### Pattern 7: All sessions at Sydney CBD today (admin dashboard)

```
GSI Query:  locationSessionsIndex
            PK = "loc-sydney-cbd-001"
            SK BETWEEN "2026-02-26T00:00:00.000Z" AND "2026-02-26T23:59:59.000Z"

→ Goes to GSI Building 2
→ Room "loc-sydney-cbd-001"
→ Reads shelves within today's date range
→ Returns sess_xyz789 + sess_abc123  ✅
```

### Pattern 8: All sessions at Sydney CBD in February 2026

```
GSI Query:  locationSessionsIndex
            PK = "loc-sydney-cbd-001"
            SK BETWEEN "2026-02-01T00:00:00.000Z" AND "2026-02-28T23:59:59.000Z"

→ Same room, wider date range  ✅
```

### Pattern 9: Get messages after a certain timestamp (pagination)

```
Query:  PK = "sess_abc123"
        SK > "MSG#2026-02-26T09:03:00.000Z"

→ Room "sess_abc123"
→ Reads only shelves that sort AFTER that timestamp
→ Returns msg003 + msg004 (the two messages after 09:03)  ✅
```

### Pattern 10: Get last 20 messages for context (AI context window)

```
Query:  PK = "sess_abc123"
        SK BEGINS_WITH "MSG#"
        Sort: descending
        Limit: 20

→ Room "sess_abc123"
→ Reads MSG# shelves only, newest first, max 20
→ Reverse to put back in chronological order before sending to Claude  ✅
```

---

## Step 7 — The Write Walkthrough

### Creating a new session (staff opens chat)

Your code calls `PutItem`:

```javascript
{
  TableName: "minihub-chat",
  Item: {
    sessionId:          "sess_def456",        // PK
    itemType:           "SESSION",            // SK
    memberId:           "b2c3d4...",          // GSI 1 PK
    aliasId:            20187,
    memberName:         "Kelly Tran",
    memberRole:         "L2",
    locationContext:    "loc-parramatta-001", // GSI 2 PK
    allowedLocationIds: ["loc-parramatta-001"],
    title:              "New Chat",
    status:             "ACTIVE",
    messageCount:       0,
    createdAt:          "2026-02-26T10:15:00.000Z",  // GSI 1 SK + GSI 2 SK
    updatedAt:          "2026-02-26T10:15:00.000Z",
    expiresAt:          1803672000
  }
}
```

DynamoDB does:
```
1. hash("sess_def456") → FLOOR 7
2. Create Room "sess_def456" on Floor 7
3. Place SESSION folder on shelf "SESSION"
4. Copy { memberId, sessionId, locationContext, title, status, createdAt }
   to GSI Building 1 Room "b2c3d4..." shelf "2026-02-26T10:15:00.000Z"
5. Copy { locationContext, sessionId, memberId, title, status, createdAt }
   to GSI Building 2 Room "loc-parramatta-001" shelf "2026-02-26T10:15:00.000Z"

Cost: 1 main write + 2 GSI writes = 3 write units total
```

### Adding a message to a session

```javascript
{
  TableName: "minihub-chat",
  Item: {
    sessionId:   "sess_def456",
    itemType:    "MSG#2026-02-26T10:15:10.000Z#msg001",
    messageId:   "msg001",
    role:        "user",
    content:     "Is Sarah Ahmed's membership contract still active?",
    createdAt:   "2026-02-26T10:15:10.000Z",
    expiresAt:   1803672000
  }
}
```

DynamoDB does:
```
1. hash("sess_def456") → FLOOR 7  (same floor as the SESSION item — same room)
2. Find Room "sess_def456"
3. Place MSG folder on shelf "MSG#2026-02-26T10:15:10.000Z#msg001"
   → Inserted in alphabetical order between existing shelves
4. MSG items don't have memberId or locationContext attributes
   → GSI buildings are NOT updated (nothing to copy)

Cost: 1 write unit. Cheap.
```

Then a separate `UpdateItem` to bump `messageCount` on the SESSION item:
```
UpdateItem:
  PK = "sess_def456", SK = "SESSION"
  SET messageCount = messageCount + 1
  SET updatedAt = "2026-02-26T10:15:10.000Z"
```

---

## Step 8 — The memberId vs aliasId Question

**You asked: should we use aliasId as the GSI key instead of memberId (UUID)?**

```
memberId  → "a1b2c3d4-e5f6-7890-abcd-ef1234567890"  (36 chars, UUID)
aliasId   → 10045                                     (5 chars, integer)
```

**Use memberId. Here's why:**

```
REASON 1 — Cognito gives us memberId, not aliasId
  When staff logs in, the JWT contains: custom:memberId = "a1b2c3d4..."
  To get aliasId, we'd need an extra database lookup on login.
  Extra lookup = extra latency on every request. Not worth it.

REASON 2 — aliasId can be null
  From the schema: "aliasMemberId: Int" — it's optional.
  If a member has no aliasId, they'd have no room in the GSI.
  memberId is required (it's the Cognito sub). Always exists.

REASON 3 — UUID length doesn't hurt performance
  DynamoDB hashes the key regardless of length.
  "a1b2c3d4-..." hashes just as fast as "10045".
  No performance difference.

REASON 4 — aliasId is for HUMANS, not machines
  Store aliasId as an attribute for display (e.g., "Staff #10045")
  Use memberId as the key for DynamoDB operations.

  Best of both worlds:
    memberId:  "a1b2c3d4..."    ← DynamoDB key
    aliasId:   10045            ← stored as attribute, shown in UI
```

---

## Step 9 — Location Scoping in the Session

```
locationContext    = "loc-parramatta-001"
                     ↑ the location Kelly is CURRENTLY WORKING IN
                     ↑ used as GSI PK for location-based admin queries
                     ↑ ONE location per session

allowedLocationIds = ["loc-parramatta-001"]
                     ↑ ALL locations Kelly has access to
                     ↑ stored for audit and passed to query tools
                     ↑ ARRAY — could be ["loc-a", "loc-b", "loc-c"] for area managers

Why both?

  locationContext  → answers "what was this session about?" (reporting)
  allowedLocationIds → enforces "what data can the AI query?" (security)

  An area manager (L4) at Sydney CBD:
    locationContext:    "loc-sydney-cbd-001"  (where they are right now)
    allowedLocationIds: ["loc-sydney-cbd-001", "loc-parramatta-001",
                         "loc-chatswood-001", "loc-bondi-001"]
                        (all 4 locations in their area)

  The AI uses allowedLocationIds to scope every SQL query.
  The admin dashboard uses locationContext to group sessions by location.
```

---

## Summary — Design Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Table structure | Single table, 3 item types | All session data in one room → one query |
| Partition key | sessionId | Natural grouping — all messages belong to one session |
| Sort key | itemType (SESSION / MSG#timestamp / SUMMARY) | Enables filtering by type + chronological order |
| Message sort key | `MSG#timestamp#msgId` | Timestamp = chronological sort; msgId = uniqueness |
| GSI 1 PK | memberId (UUID) | From Cognito JWT, never null, no lookup needed |
| GSI 2 PK | locationContext | Admin dashboard by location |
| GSI sort keys | createdAt (ISO string) | ISO strings sort correctly as strings |
| aliasId | Stored as attribute, not a key | For display only; could be null |
| allowedLocationIds | Array attribute on SESSION | Security scoping for AI query tools |
| TTL | 90 days on expiresAt | Auto-cleanup, keeps table size bounded |
| Summary timing | Written on chat close | Async — don't block the user |
