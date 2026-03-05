# AI Chat — DynamoDB Schema Design

> **Status:** Planning
> **Created:** 2026-02-26
> **Related:** [AI-CHAT-ARCHITECTURE.md](./AI-CHAT-ARCHITECTURE.md)

---

## Table of Contents

1. [Single Table Design — The Concept](#1-single-table-design--the-concept)
2. [Learning by Example — Multi Table to Single Table](#2-learning-by-example--multi-table-to-single-table)
3. [Chat System — What We're Storing](#3-chat-system--what-were-storing)
4. [Chat Table — Full Design](#4-chat-table--full-design)
5. [Knowledge Table — Full Design](#5-knowledge-table--full-design)
6. [Access Patterns & Queries](#6-access-patterns--queries)
7. [Where They Sit in the Architecture](#7-where-they-sit-in-the-architecture)
8. [CDK Definitions](#8-cdk-definitions)

---

## 0. DynamoDB Fundamentals — Partition Key, Sort Key, and How Records Are Unique

Before anything else, let's build the mental picture.

### The Library Analogy

Imagine DynamoDB is a **library.** Not a small one — a massive one with millions of books.

```
THE LIBRARY (DynamoDB Table)
│
├── FLOOR 1  (one physical server/partition)
│   ├── Shelf A
│   │   ├── Book 1
│   │   ├── Book 2
│   │   └── Book 3
│   └── Shelf B
│       ├── Book 4
│       └── Book 5
│
├── FLOOR 2  (another physical server/partition)
│   ├── Shelf C
│   │   ├── Book 6
│   │   └── Book 7
│   └── Shelf D
│       └── Book 8
│
└── FLOOR 3  (another physical server/partition)
    └── Shelf E
        ├── Book 9
        └── Book 10
```

Now let's map this:

```
LIBRARY        = DynamoDB Table
FLOOR          = Physical partition (a server/disk)
SHELF          = Partition Key value (all items with the same partition key)
BOOK           = One item (one record/row)
BOOK'S SPINE   = Sort Key (how books are ordered on the shelf)
```

### Partition Key = Which Shelf

The **partition key** determines **which shelf** your item goes on. DynamoDB hashes the partition key to decide which physical server stores it.

```
You say: "Give me the shelf for session chat_abc123"

DynamoDB thinks:
  hash("chat_abc123") = 7294817...
  7294817 mod 3 = FLOOR 2
  
  → Goes to Floor 2, finds the shelf labeled "chat_abc123"
```

**All items with the same partition key live on the same shelf.** This is why querying by partition key is fast — DynamoDB goes straight to one shelf on one server.

```
Shelf "chat_abc123":
  ┌──────────────┐
  │ SESSION info │  ← one item
  │ Message 1    │  ← another item  
  │ Message 2    │  ← another item
  │ Message 3    │  ← another item
  │ SUMMARY      │  ← another item
  └──────────────┘
  
  All on ONE shelf. ONE server. ONE disk read.
  This is why it's fast.
```

### Sort Key = The Order of Books on the Shelf

Within a shelf, items are **sorted** by the sort key. Like books ordered alphabetically on a shelf.

```
Shelf "chat_abc123" (partition key = "chat_abc123"):

Sort Key                          │ What it is
──────────────────────────────────┼────────────────────
MSG#2026-02-26T09:01:00Z#m01     │ First message
MSG#2026-02-26T09:01:05Z#m02     │ Second message
MSG#2026-02-26T09:03:00Z#m03     │ Third message
MSG#2026-02-26T09:03:04Z#m04     │ Fourth message
SESSION                           │ Session metadata
SUMMARY                           │ Session summary

Items are sorted alphabetically by sort key.
"MSG#2026..." comes before "SESSION" comes before "SUMMARY"
(because M < S in the alphabet)
```

### How Is a Record Unique?

**Partition key + sort key together = the unique identity of one item.**

Think of it like a street address:

```
STREET ADDRESS:
  Street name = Partition Key     (which street/shelf)
  House number = Sort Key          (which house on that street)
  
  "123 Main Street" is unique because no two houses
  have the same number on the same street.
  
  But "123" alone is NOT unique — there's a 123 on every street.
  And "Main Street" alone is NOT unique — there are many houses on it.
  
  ONLY the combination is unique.
```

In DynamoDB terms:

```
Partition Key: "chat_abc123"    Sort Key: "SESSION"        → ONE unique item
Partition Key: "chat_abc123"    Sort Key: "MSG#...T09:01"  → ONE unique item
Partition Key: "chat_abc123"    Sort Key: "MSG#...T09:03"  → ONE unique item
Partition Key: "chat_abc123"    Sort Key: "SUMMARY"        → ONE unique item

Partition Key: "chat_def456"    Sort Key: "SESSION"        → DIFFERENT unique item
                                                              (different street!)
```

### What Happens When You Query

```
QUERY: "Give me everything on shelf chat_abc123"
  → DynamoDB goes to the right server (via hash)
  → Reads the entire shelf
  → Returns all 6 items
  → ONE disk read. Fast.

QUERY: "Give me everything on shelf chat_abc123 where sort key starts with MSG#"
  → Same shelf
  → But only reads the portion where sort keys start with "MSG#"
  → Returns 4 message items, skips SESSION and SUMMARY
  → Still ONE disk read. Still fast.

QUERY: "Give me the item on shelf chat_abc123 with sort key SESSION"
  → Same shelf
  → Jumps directly to that one item (binary search — items are sorted!)
  → Returns 1 item
  → Fastest possible read.
```

This is why the sort key matters — it lets you:
- **Get one specific item:** `sort key = "SESSION"` (exact match)
- **Get a range:** `sort key BEGINS_WITH "MSG#"` (all messages)
- **Get a range with time:** `sort key BETWEEN "MSG#2026-02-26T09:00" AND "MSG#2026-02-26T10:00"` (messages in a time window)

### What About GSIs?

A GSI is a **second library** with the **same books** but organized on **different shelves.**

```
MAIN LIBRARY (main table):
  Shelves organized by: sessionId
  
  Shelf "chat_abc123" → [session info, messages, summary]
  Shelf "chat_def456" → [session info, messages, summary]

SECOND LIBRARY (GSI: memberSessionsIndex):
  Shelves organized by: memberId
  
  Shelf "gordon-uuid" → [session abc info, session ghi info]
  Shelf "chris-uuid"  → [session def info]
```

Same data, different shelving system. When you write an item to the main table, DynamoDB **automatically copies** the relevant fields to the GSI and puts them on the right shelf there.

**Main table question:** "Give me all messages in session abc-123" → shelved by session ✅
**GSI question:** "Give me all sessions for member Gordon" → shelved by member ✅

You can't answer both questions from one shelving system. That's why you need two.

### The Cost of This Mental Model

```
Partition Key = WHICH SHELF (which server/disk)
Sort Key      = WHERE ON THE SHELF (ordered position)
PK + SK       = EXACT BOOK (unique item)
Query         = "Go to this shelf, read these books"
GSI           = Same books, different shelves, different questions answered
```

Once you see it this way, everything else in DynamoDB follows:

- **Why partition key queries are fast:** You go to ONE shelf on ONE server
- **Why scan is slow:** You're walking through EVERY shelf in the ENTIRE library
- **Why you can't query by non-key attributes:** The books aren't organized by those — you'd have to read every book to check
- **Why GSIs exist:** Different questions need different shelf organizations
- **Why single table works:** Related items on the SAME shelf = one query gets everything

---

## 1. Single Table Design — The Concept

In Postgres, you think in **tables and joins.** In DynamoDB single table design, you think in **access patterns and item collections.**

The analogy:

```
POSTGRES THINKING:
  "I have entities. I'll make a table for each. I'll join them when I need related data."
  
  members table  ←JOIN→  payments table  ←JOIN→  contracts table

DYNAMODB SINGLE TABLE THINKING:
  "I have questions I need to answer. I'll put everything in one table,
   organized so each question is answered by ONE query with no joins."
   
  Everything in one table. The partition key + sort key are designed
  so related items land next to each other.
```

### Why Single Table?

DynamoDB has **no joins.** If you put sessions in one table and messages in another, getting a session with its messages requires **two queries.** In a single table, you get both in **one query** because they share a partition key.

### The Mental Model

Think of a single table as a **filing cabinet:**

```
┌──────────────────────────────────────────────────────────┐
│                    FILING CABINET                          │
│                    (one DynamoDB table)                    │
│                                                            │
│  Drawer: "Chat Session abc-123"     ← partition key       │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  Folder: SESSION_INFO            ← sort key           │ │
│  │  { title, status, memberName, createdAt }             │ │
│  ├──────────────────────────────────────────────────────┤ │
│  │  Folder: MSG#2026-02-26T09:01    ← sort key           │ │
│  │  { role: "user", content: "Why was John charged?" }   │ │
│  ├──────────────────────────────────────────────────────┤ │
│  │  Folder: MSG#2026-02-26T09:01    ← sort key           │ │
│  │  { role: "assistant", content: "John was charged..." }│ │
│  ├──────────────────────────────────────────────────────┤ │
│  │  Folder: MSG#2026-02-26T09:03    ← sort key           │ │
│  │  { role: "user", content: "What card was used?" }     │ │
│  ├──────────────────────────────────────────────────────┤ │
│  │  Folder: SUMMARY                  ← sort key           │ │
│  │  { summary: "Staff asked about member 4521 payment..."}│ │
│  └──────────────────────────────────────────────────────┘ │
│                                                            │
│  Drawer: "Chat Session def-456"     ← different partition │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  Folder: SESSION_INFO                                 │ │
│  │  Folder: MSG#2026-02-26T10:00                         │ │
│  │  Folder: MSG#2026-02-26T10:01                         │ │
│  │  ...                                                   │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                            │
└──────────────────────────────────────────────────────────┘

To get ALL items in session abc-123:
  → Open drawer "abc-123" → read everything
  → ONE query: sessionId = "abc-123"

To get ONLY messages (not session info):
  → Open drawer "abc-123" → read folders starting with "MSG#"
  → ONE query: sessionId = "abc-123" AND sortKey BEGINS_WITH "MSG#"

To get session info only:
  → Open drawer "abc-123" → read the "SESSION_INFO" folder
  → ONE query: sessionId = "abc-123" AND sortKey = "SESSION_INFO"
```

### But Wait — What About "Give Me All Sessions For a Member"?

The partition key is `sessionId`, so you can't query by `memberId` on the main table. That's what a **GSI (Global Secondary Index)** is for — it's a **second filing cabinet** organized differently:

```
MAIN TABLE (filing cabinet organized by session):
  Drawer "session-abc" → [session info, messages, summary]
  Drawer "session-def" → [session info, messages, summary]
  Drawer "session-ghi" → [session info, messages, summary]

GSI: memberSessionsIndex (second cabinet organized by member):
  Drawer "member-gordon" → [session-abc info, session-ghi info]
  Drawer "member-chris"  → [session-def info]

Same data, different organization. DynamoDB maintains both automatically.
```

---

## 2. Learning by Example — Multi Table to Single Table

Let's work through a real example unrelated to chat first, so the pattern clicks.

### The Scenario: A School System

You need to store: **Students, Classes, and Enrollments.**

### Multi-Table Design (The Postgres Way)

```
TABLE: students
┌────────┬──────────┬──────────┬────────────┐
│ id     │ name     │ grade    │ email      │
├────────┼──────────┼──────────┼────────────┤
│ S001   │ Alice    │ 10       │ alice@...  │
│ S002   │ Bob      │ 10       │ bob@...    │
│ S003   │ Charlie  │ 11       │ charlie@...│
└────────┴──────────┴──────────┴────────────┘

TABLE: classes
┌────────┬──────────┬──────────┬────────────┐
│ id     │ name     │ teacher  │ room       │
├────────┼──────────┼──────────┼────────────┤
│ C001   │ Math     │ Dr Smith │ Room 101   │
│ C002   │ English  │ Ms Jones │ Room 205   │
│ C003   │ Science  │ Dr Brown │ Lab 3      │
└────────┴──────────┴──────────┴────────────┘

TABLE: enrollments
┌─────────────┬────────────┬────────────┬────────┐
│ id          │ student_id │ class_id   │ grade  │
├─────────────┼────────────┼────────────┼────────┤
│ E001        │ S001       │ C001       │ A      │
│ E002        │ S001       │ C002       │ B+     │
│ E003        │ S002       │ C001       │ A-     │
│ E004        │ S003       │ C003       │ B      │
└─────────────┴────────────┴────────────┴────────┘

Access patterns:
1. Get a student by ID          → SELECT * FROM students WHERE id = 'S001'
2. Get a class by ID            → SELECT * FROM classes WHERE id = 'C001'
3. Get all classes for a student → SELECT * FROM enrollments JOIN classes ... WHERE student_id = 'S001'
4. Get all students in a class  → SELECT * FROM enrollments JOIN students ... WHERE class_id = 'C001'
```

3 tables, joins everywhere. Works great in Postgres. **Doesn't work in DynamoDB** because there are no joins.

### Single Table Design (The DynamoDB Way)

First, list your **access patterns** (the questions you need to answer):

```
1. Get student details by ID
2. Get class details by ID
3. Get all classes a student is enrolled in
4. Get all students enrolled in a class
5. Get a specific enrollment
```

Now design the keys so each pattern is **one query:**

```
TABLE: school (single table)

Partition Key: entityId          Sort Key: relationType
─────────────────────────────────────────────────────────────────────────
entityId          │ relationType         │ Other attributes
──────────────────┼──────────────────────┼──────────────────────────────
STUDENT#S001      │ PROFILE              │ name=Alice, grade=10, email=alice@...
STUDENT#S001      │ CLASS#C001           │ className=Math, grade=A, enrolledAt=...
STUDENT#S001      │ CLASS#C002           │ className=English, grade=B+, enrolledAt=...
STUDENT#S002      │ PROFILE              │ name=Bob, grade=10, email=bob@...
STUDENT#S002      │ CLASS#C001           │ className=Math, grade=A-, enrolledAt=...
STUDENT#S003      │ PROFILE              │ name=Charlie, grade=11, email=charlie@...
STUDENT#S003      │ CLASS#C003           │ className=Science, grade=B, enrolledAt=...
CLASS#C001        │ DETAILS              │ name=Math, teacher=Dr Smith, room=Room 101
CLASS#C002        │ DETAILS              │ name=English, teacher=Ms Jones, room=Room 205
CLASS#C003        │ DETAILS              │ name=Science, teacher=Dr Brown, room=Lab 3
```

**GSI: classStudentsIndex** (to flip the relationship — find students in a class)

```
GSI Partition Key: relationType    GSI Sort Key: entityId
──────────────────────────────────────────────────────────
relationType       │ entityId          │ Other attributes
───────────────────┼───────────────────┼──────────────────
CLASS#C001         │ STUDENT#S001      │ name=Alice, grade=A
CLASS#C001         │ STUDENT#S002      │ name=Bob, grade=A-
CLASS#C002         │ STUDENT#S001      │ name=Alice, grade=B+
CLASS#C003         │ STUDENT#S003      │ name=Charlie, grade=B
DETAILS            │ CLASS#C001        │ (class details)
PROFILE            │ STUDENT#S001      │ (student details)
```

### Now the Queries

```
Pattern 1: Get student Alice's profile
  Table query: entityId = "STUDENT#S001" AND relationType = "PROFILE"
  → Returns: { name: Alice, grade: 10, email: alice@... }

Pattern 2: Get Math class details
  Table query: entityId = "CLASS#C001" AND relationType = "DETAILS"
  → Returns: { name: Math, teacher: Dr Smith, room: Room 101 }

Pattern 3: Get all classes Alice is enrolled in
  Table query: entityId = "STUDENT#S001" AND relationType BEGINS_WITH "CLASS#"
  → Returns: [
      { className: Math, grade: A },
      { className: English, grade: B+ }
    ]

Pattern 4: Get all students in Math class
  GSI query: relationType = "CLASS#C001" AND entityId BEGINS_WITH "STUDENT#"
  → Returns: [
      { name: Alice, grade: A },
      { name: Bob, grade: A- }
    ]

Pattern 5: Get Alice's enrollment in Math specifically
  Table query: entityId = "STUDENT#S001" AND relationType = "CLASS#C001"
  → Returns: { className: Math, grade: A, enrolledAt: ... }
```

**Every pattern is ONE query. No joins. No scans.**

### The Key Insight

```
In Postgres:  You normalize data, then JOIN at read time.
In DynamoDB:  You denormalize data, organizing it for your READ patterns at write time.

You're trading:
  ✅ Fast reads (every question = one query)
  ❌ Some data duplication (class name stored with each enrollment)
  ❌ More complex writes (update class name = update multiple items)
```

---

## 3. Chat System — What We're Storing

Two DynamoDB tables for the AI chat system:

```
TABLE 1: ChatTable
  Purpose: Chat sessions, messages, and summaries
  Used by: Chat endpoints, conversation history, audit trail

TABLE 2: KnowledgeTable  
  Purpose: Knowledge base entries, playbooks
  Used by: System prompt builder, admin UI
```

### Why Two Tables Instead of One Giant Single Table?

```
ChatTable data:
  - High volume (thousands of messages per day)
  - Has TTL (messages expire after 90 days)
  - Frequently written to (every chat interaction)
  - Access patterns are session-centric and member-centric

KnowledgeTable data:
  - Low volume (maybe 50-200 entries total)
  - No TTL (lives forever, manually managed)
  - Rarely written (admin updates occasionally)
  - Loaded in bulk into system prompt (scan all)
  - Completely different lifecycle

Mixing them would mean TTL accidentally deleting knowledge entries,
or bulk-loading knowledge items would scan through thousands of chat messages.
Separate tables = clean separation of concerns.
```

---

## 4. Chat Table — Full Design

### Access Patterns (The Questions We Need to Answer)

```
1. Get all messages in a session (for conversation history)
2. Get session metadata (title, status, member info)
3. Get the session summary (after chat ends)
4. List all sessions for a specific member (for session sidebar)
5. Get recent sessions for a member (for "continue conversation")
6. Get all sessions for a specific location (for admin/reporting)
7. Count messages in a session (for display)
```

### Key Design

```
Table name: minihub-chat

Partition key: sessionId     (String)
Sort key:     itemType       (String)
```

### Item Types in the Table

```
TABLE: minihub-chat

sessionId              │ itemType                    │ Attributes
───────────────────────┼─────────────────────────────┼─────────────────────────────
chat_abc123            │ SESSION                     │ memberId, memberName, memberRole,
                       │                             │ locationContext, allowedLocationIds,
                       │                             │ title, status, messageCount,
                       │                             │ createdAt, updatedAt, expiresAt
                       │                             │
chat_abc123            │ MSG#2026-02-26T09:01:00#m01 │ messageId, role=user,
                       │                             │ content="Why was John charged?",
                       │                             │ createdAt, expiresAt
                       │                             │
chat_abc123            │ MSG#2026-02-26T09:01:05#m02 │ messageId, role=assistant,
                       │                             │ content="John was charged...",
                       │                             │ toolsCalled, tokensUsed, model,
                       │                             │ createdAt, expiresAt
                       │                             │
chat_abc123            │ MSG#2026-02-26T09:03:00#m03 │ messageId, role=user,
                       │                             │ content="What card was used?",
                       │                             │ createdAt, expiresAt
                       │                             │
chat_abc123            │ MSG#2026-02-26T09:03:04#m04 │ messageId, role=assistant,
                       │                             │ content="Card ending in 9729...",
                       │                             │ toolsCalled, tokensUsed, model,
                       │                             │ createdAt, expiresAt
                       │                             │
chat_abc123            │ SUMMARY                     │ summary="Staff Chris asked about
                       │                             │  member John Doe #4521 payment of
                       │                             │  $50 on 15/02. Normal fortnightly
                       │                             │  billing via card ending 9729.",
                       │                             │  topicTags=["payment","dd","member"],
                       │                             │  questionsAsked=2, toolsUsed=3,
                       │                             │  totalTokens=4200, totalCost=0.05,
                       │                             │  resolvedWithoutEscalation=true,
                       │                             │  createdAt, expiresAt
                       │                             │
───────────────────────┼─────────────────────────────┼─────────────────────────────
chat_def456            │ SESSION                     │ memberId=chris-uuid, ...
chat_def456            │ MSG#2026-02-26T10:00:00#m05 │ ...
chat_def456            │ MSG#2026-02-26T10:00:08#m06 │ ...
chat_def456            │ SUMMARY                     │ ...
```

### GSI: memberSessionsIndex

To answer: "Get all sessions for member Gordon" (Pattern 4 & 5)

```
GSI: memberSessionsIndex

Partition key: memberId    (String)
Sort key:     createdAt    (String — ISO timestamp)

This GSI only projects SESSION items (not messages/summaries)
using a filter or by only writing the GSI attributes on SESSION items.

memberId               │ createdAt                │ Projected attributes
───────────────────────┼──────────────────────────┼─────────────────────
gordon-uuid            │ 2026-02-26T09:00:00Z     │ sessionId=chat_abc123,
                       │                          │ title="Payment inquiry...",
                       │                          │ messageCount=4, status=completed
                       │                          │
gordon-uuid            │ 2026-02-25T14:30:00Z     │ sessionId=chat_xyz789,
                       │                          │ title="Rejection query...",
                       │                          │ messageCount=6, status=completed
                       │                          │
chris-uuid             │ 2026-02-26T10:00:00Z     │ sessionId=chat_def456,
                       │                          │ title="Member balance...",
                       │                          │ messageCount=2, status=active
```

### GSI: locationSessionsIndex

To answer: "Get all sessions from Bondi location" (Pattern 6 — admin/reporting)

```
GSI: locationSessionsIndex

Partition key: locationContext    (String — primary location ID)
Sort key:     createdAt          (String)

locationContext         │ createdAt                │ Projected attributes
───────────────────────┼──────────────────────────┼─────────────────────
loc-bondi-uuid         │ 2026-02-26T09:00:00Z     │ sessionId, memberId,
                       │                          │ memberName, title, messageCount
loc-bondi-uuid         │ 2026-02-26T10:00:00Z     │ ...
loc-surry-hills-uuid   │ 2026-02-26T11:00:00Z     │ ...
```

### Querying Each Access Pattern

```typescript
// Pattern 1: Get all messages in a session
const messages = await dynamoDB.send(new QueryCommand({
  TableName: "minihub-chat",
  KeyConditionExpression: "sessionId = :sid AND begins_with(itemType, :prefix)",
  ExpressionAttributeValues: {
    ":sid": "chat_abc123",
    ":prefix": "MSG#"
  },
  ScanIndexForward: true  // oldest first (chronological)
}));

// Pattern 2: Get session metadata
const session = await dynamoDB.send(new QueryCommand({
  TableName: "minihub-chat",
  KeyConditionExpression: "sessionId = :sid AND itemType = :type",
  ExpressionAttributeValues: {
    ":sid": "chat_abc123",
    ":type": "SESSION"
  }
}));

// Pattern 3: Get session summary
const summary = await dynamoDB.send(new QueryCommand({
  TableName: "minihub-chat",
  KeyConditionExpression: "sessionId = :sid AND itemType = :type",
  ExpressionAttributeValues: {
    ":sid": "chat_abc123",
    ":type": "SUMMARY"
  }
}));

// Pattern 4: List all sessions for a member (most recent first)
const memberSessions = await dynamoDB.send(new QueryCommand({
  TableName: "minihub-chat",
  IndexName: "memberSessionsIndex",
  KeyConditionExpression: "memberId = :mid",
  ExpressionAttributeValues: {
    ":mid": "gordon-uuid"
  },
  ScanIndexForward: false,  // newest first
  Limit: 20
}));

// Pattern 5: Get recent sessions for a member (last 7 days)
const recentSessions = await dynamoDB.send(new QueryCommand({
  TableName: "minihub-chat",
  IndexName: "memberSessionsIndex",
  KeyConditionExpression: "memberId = :mid AND createdAt > :since",
  ExpressionAttributeValues: {
    ":mid": "gordon-uuid",
    ":since": "2026-02-19T00:00:00Z"
  },
  ScanIndexForward: false
}));

// Pattern 6: Get all sessions for a location (admin)
const locationSessions = await dynamoDB.send(new QueryCommand({
  TableName: "minihub-chat",
  IndexName: "locationSessionsIndex",
  KeyConditionExpression: "locationContext = :loc AND createdAt > :since",
  ExpressionAttributeValues: {
    ":loc": "loc-bondi-uuid",
    ":since": "2026-02-01T00:00:00Z"
  },
  ScanIndexForward: false
}));

// Pattern 7: Get EVERYTHING in a session (metadata + messages + summary in one call)
const everything = await dynamoDB.send(new QueryCommand({
  TableName: "minihub-chat",
  KeyConditionExpression: "sessionId = :sid",
  ExpressionAttributeValues: {
    ":sid": "chat_abc123"
  }
}));
// Then split in code:
// const session = items.find(i => i.itemType === "SESSION");
// const messages = items.filter(i => i.itemType.startsWith("MSG#"));
// const summary = items.find(i => i.itemType === "SUMMARY");
```

### Writing Items

```typescript
// Creating a new session
await dynamoDB.send(new PutItemCommand({
  TableName: "minihub-chat",
  Item: marshall({
    sessionId: "chat_abc123",
    itemType: "SESSION",
    memberId: "gordon-uuid",
    memberName: "Gordon Smith",
    memberRole: "L3",
    locationContext: "loc-bondi-uuid",
    allowedLocationIds: ["loc-bondi-uuid", "loc-surry-hills-uuid"],
    title: "New conversation",
    status: "active",
    messageCount: 0,
    createdAt: "2026-02-26T09:00:00Z",
    updatedAt: "2026-02-26T09:00:00Z",
    expiresAt: Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60)  // TTL: 90 days
  })
}));

// Adding a message
await dynamoDB.send(new PutItemCommand({
  TableName: "minihub-chat",
  Item: marshall({
    sessionId: "chat_abc123",
    itemType: "MSG#2026-02-26T09:01:00Z#m01",
    messageId: "m01",
    role: "user",
    content: "Why was member John Doe charged $50 on 15 Feb?",
    createdAt: "2026-02-26T09:01:00Z",
    expiresAt: Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60)
  })
}));

// Adding assistant response with metadata
await dynamoDB.send(new PutItemCommand({
  TableName: "minihub-chat",
  Item: marshall({
    sessionId: "chat_abc123",
    itemType: "MSG#2026-02-26T09:01:05Z#m02",
    messageId: "m02",
    role: "assistant",
    content: "John Doe (Member #4521) was charged $50.00 on 15/02/2026...",
    toolsCalled: ["search_member", "get_payments"],
    tokensUsed: { input: 5200, output: 150 },
    model: "claude-sonnet-4-20250514",
    costUsd: 0.018,
    createdAt: "2026-02-26T09:01:05Z",
    expiresAt: Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60)
  })
}));

// Saving session summary (when chat ends or after inactivity)
await dynamoDB.send(new PutItemCommand({
  TableName: "minihub-chat",
  Item: marshall({
    sessionId: "chat_abc123",
    itemType: "SUMMARY",
    summary: "Staff member Chris at Plus Fitness Bondi asked about a $50 charge for member John Doe (#4521) on 15/02/2026. It was identified as a normal fortnightly direct debit via credit card ending in 9729. Status: Approved. Chris also asked what card was used. Resolved without escalation.",
    topicTags: ["payment", "direct-debit", "member-query"],
    questionsAsked: 2,
    toolsUsed: ["search_member", "get_payments", "get_payment_methods"],
    totalTokens: 8500,
    totalCostUsd: 0.048,
    resolvedWithoutEscalation: true,
    knowledgeBaseHits: [],
    playbooksUsed: ["pb-001"],
    createdAt: "2026-02-26T09:05:00Z",
    expiresAt: Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60)
  })
}));
```

### The Summary — How & When

The summary is generated by the LLM when a session ends (user closes chat, or 30 minutes of inactivity). One final API call:

```typescript
const summaryResponse = await anthropic.messages.create({
  model: "claude-sonnet-4-20250514",
  max_tokens: 500,
  system: "Summarise this support chat conversation in 2-3 sentences. Include: who asked, what they asked about, what member/payment was involved, and whether it was resolved. This summary will be shown in a session list.",
  messages: [
    { role: "user", content: `Here is the conversation:\n\n${allMessagesAsText}` }
  ]
});
```

Cost: ~$0.005 (half a cent). The summary is useful for:
- Session list sidebar ("Payment inquiry for John Doe #4521 — Resolved")
- Admin reporting (what topics are most common?)
- Quick context if the user returns to an old session

---

## 5. Knowledge Table — Full Design

### Access Patterns

```
1. Get all knowledge base entries (to build system prompt)
2. Get all playbooks (to build system prompt)
3. Get entries by category (for admin UI filtering)
4. Get a specific entry by ID (for admin edit)
5. Get all entries created by a specific admin (audit)
```

### Key Design

```
Table name: minihub-chat-knowledge

Partition key: category      (String)
Sort key:     entryId        (String)
```

### Item Types

```
TABLE: minihub-chat-knowledge

category               │ entryId                     │ Attributes
───────────────────────┼─────────────────────────────┼─────────────────────────────
KB#DD_REJECTIONS       │ kb-001                      │ type=KNOWLEDGE
                       │                             │ title="INSUFFICIENT_FUNDS -
                       │                             │  member claims had money"
                       │                             │ triggers=["insufficient funds",
                       │                             │  "had money in account", ...]
                       │                             │ answer="The rejection reason..."
                       │                             │ needsQuery=false
                       │                             │ relatedPlaybook=null
                       │                             │ createdBy="amrit.regmi"
                       │                             │ updatedAt="2026-02-26"
                       │                             │
KB#DD_REJECTIONS       │ kb-002                      │ type=KNOWLEDGE
                       │                             │ title="ACCOUNT_CLOSED"
                       │                             │ triggers=["account closed", ...]
                       │                             │ answer="The ACCOUNT_CLOSED..."
                       │                             │
KB#DD_REJECTIONS       │ kb-003                      │ type=KNOWLEDGE
                       │                             │ title="REFER_TO_CUSTOMER"
                       │                             │ ...
                       │                             │
KB#BILLING             │ kb-004                      │ type=KNOWLEDGE
                       │                             │ title="Why was I charged"
                       │                             │ needsQuery=true
                       │                             │ relatedPlaybook="pb-001"
                       │                             │
KB#CONTRACTS           │ kb-005                      │ type=KNOWLEDGE
                       │                             │ title="Cancellation fees"
                       │                             │ ...
                       │                             │
───────────────────────┼─────────────────────────────┼─────────────────────────────
PB#PAYMENTS            │ pb-001                      │ type=PLAYBOOK
                       │                             │ name="Investigate a charge"
                       │                             │ triggers=["why was charged",
                       │                             │  "what is this charge", ...]
                       │                             │ steps=[
                       │                             │   { step: 1, action: "Find
                       │                             │     member", tool: "search_
                       │                             │     member", ... },
                       │                             │   { step: 2, action: "Check
                       │                             │     batch payments", ... },
                       │                             │   ...
                       │                             │ ]
                       │                             │ createdBy="amrit.regmi"
                       │                             │ updatedAt="2026-02-26"
                       │                             │
PB#PAYMENTS            │ pb-002                      │ type=PLAYBOOK
                       │                             │ name="Investigate duplicate"
                       │                             │ ...
                       │                             │
PB#PAYMENTS            │ pb-003                      │ type=PLAYBOOK
                       │                             │ name="Identify payment method"
                       │                             │ ...
                       │                             │
PB#MEMBERS             │ pb-010                      │ type=PLAYBOOK
                       │                             │ name="Check member status"
                       │                             │ ...
```

### GSI: entryTypeIndex

To answer: "Get ALL knowledge entries" or "Get ALL playbooks" (for loading into system prompt)

```
GSI: entryTypeIndex

Partition key: type          (String — "KNOWLEDGE" or "PLAYBOOK")
Sort key:     updatedAt      (String — ISO timestamp)

type                   │ updatedAt                │ Projected attributes
───────────────────────┼──────────────────────────┼─────────────────────
KNOWLEDGE              │ 2026-02-20T10:00:00Z     │ all attributes
KNOWLEDGE              │ 2026-02-24T15:00:00Z     │ all attributes
KNOWLEDGE              │ 2026-02-26T10:00:00Z     │ all attributes
PLAYBOOK               │ 2026-02-22T09:00:00Z     │ all attributes
PLAYBOOK               │ 2026-02-26T11:00:00Z     │ all attributes
```

### Querying Knowledge Table

```typescript
// Pattern 1: Get ALL knowledge base entries (for system prompt)
const allKnowledge = await dynamoDB.send(new QueryCommand({
  TableName: "minihub-chat-knowledge",
  IndexName: "entryTypeIndex",
  KeyConditionExpression: "#type = :type",
  ExpressionAttributeNames: { "#type": "type" },   // "type" is reserved word
  ExpressionAttributeValues: { ":type": "KNOWLEDGE" }
}));

// Pattern 2: Get ALL playbooks (for system prompt)
const allPlaybooks = await dynamoDB.send(new QueryCommand({
  TableName: "minihub-chat-knowledge",
  IndexName: "entryTypeIndex",
  KeyConditionExpression: "#type = :type",
  ExpressionAttributeNames: { "#type": "type" },
  ExpressionAttributeValues: { ":type": "PLAYBOOK" }
}));

// Pattern 3: Get entries by category (admin UI)
const ddRejections = await dynamoDB.send(new QueryCommand({
  TableName: "minihub-chat-knowledge",
  KeyConditionExpression: "category = :cat",
  ExpressionAttributeValues: { ":cat": "KB#DD_REJECTIONS" }
}));

// Pattern 4: Get specific entry (admin edit)
const entry = await dynamoDB.send(new QueryCommand({
  TableName: "minihub-chat-knowledge",
  KeyConditionExpression: "category = :cat AND entryId = :id",
  ExpressionAttributeValues: {
    ":cat": "KB#DD_REJECTIONS",
    ":id": "kb-001"
  }
}));

// Loading everything for system prompt (called at startup, cached for 5 min)
async function loadAllKnowledgeForPrompt(): Promise<string> {
  const [knowledge, playbooks] = await Promise.all([
    queryAllKnowledge(),
    queryAllPlaybooks()
  ]);
  
  let prompt = "<knowledge_base>\n";
  for (const kb of knowledge) {
    prompt += `### ${kb.title}\n`;
    prompt += `Category: ${kb.category.replace("KB#", "")}\n`;
    if (kb.answer) {
      prompt += `Answer: ${kb.answer}\n`;
    }
    if (kb.relatedPlaybook) {
      prompt += `Investigation required: Follow playbook ${kb.relatedPlaybook}\n`;
    }
    prompt += "\n";
  }
  prompt += "</knowledge_base>\n\n";
  
  prompt += "<playbooks>\n";
  for (const pb of playbooks) {
    prompt += `### Playbook: ${pb.name}\n`;
    prompt += `When to use: ${pb.triggers.join(", ")}\n`;
    prompt += `Steps:\n`;
    for (const step of pb.steps) {
      prompt += `  ${step.step}. ${step.action}`;
      if (step.tool) prompt += ` → use tool: ${step.tool}`;
      prompt += `\n     ${step.description}\n`;
    }
    prompt += "\n";
  }
  prompt += "</playbooks>";
  
  return prompt;
}
```

---

## 6. Access Patterns — Complete Reference

### Chat Table

| # | Pattern | Key Used | Query |
|---|---------|----------|-------|
| 1 | Get messages in session | Main: `sessionId` + `begins_with(itemType, "MSG#")` | Chronological message list |
| 2 | Get session metadata | Main: `sessionId` + `itemType = "SESSION"` | Single item |
| 3 | Get session summary | Main: `sessionId` + `itemType = "SUMMARY"` | Single item |
| 4 | List member's sessions | GSI `memberSessionsIndex`: `memberId` | Newest first, paginated |
| 5 | Recent sessions for member | GSI `memberSessionsIndex`: `memberId` + `createdAt > X` | Last 7 days |
| 6 | Sessions by location | GSI `locationSessionsIndex`: `locationContext` + `createdAt > X` | Admin reporting |
| 7 | Everything in one session | Main: `sessionId` (no sort key filter) | Returns SESSION + all MSGs + SUMMARY |

### Knowledge Table

| # | Pattern | Key Used | Query |
|---|---------|----------|-------|
| 1 | All knowledge entries | GSI `entryTypeIndex`: `type = "KNOWLEDGE"` | For system prompt |
| 2 | All playbooks | GSI `entryTypeIndex`: `type = "PLAYBOOK"` | For system prompt |
| 3 | Entries by category | Main: `category = "KB#DD_REJECTIONS"` | Admin UI filter |
| 4 | Specific entry | Main: `category` + `entryId` | Admin edit |
| 5 | All entries by type sorted by last updated | GSI `entryTypeIndex`: `type` + `updatedAt` | Admin list view |

---

## 7. Where They Sit in the Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        MINIHUB                               │
│                                                              │
│  Request comes in                                            │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────────┐                                            │
│  │ Auth + Route │                                            │
│  └──────┬──────┘                                            │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                CHAT SERVICE                            │  │
│  │                                                        │  │
│  │  Step 1: Load from KnowledgeTable ──────────────┐     │  │
│  │          (cached in memory for 5 min)            │     │  │
│  │                                                   │     │  │
│  │  Step 2: Load conversation from ChatTable ──┐    │     │  │
│  │          (sessionId → messages)              │    │     │  │
│  │                                              │    │     │  │
│  │  Step 3: Build system prompt ◄───────────────┴────┘     │  │
│  │          identity + rules + knowledge + playbooks       │  │
│  │          + data model + user context                    │  │
│  │                                                        │  │
│  │  Step 4: Call Anthropic API                             │  │
│  │          system prompt + tools + messages               │  │
│  │                │                                        │  │
│  │                ▼                                        │  │
│  │  Step 5: Tool execution loop ◄──────────────────┐     │  │
│  │          LLM says "call search_member"           │     │  │
│  │          → run pre-built SQL on Postgres ────────┼──── │──── Postgres
│  │          → send result back to LLM               │     │  │   (READ ONLY)
│  │          → repeat until LLM gives text answer ───┘     │  │
│  │                │                                        │  │
│  │                ▼                                        │  │
│  │  Step 6: Save to ChatTable ──────────────────────────── │──── DynamoDB
│  │          - user message (MSG# item)                     │  │   ChatTable
│  │          - assistant response (MSG# item)               │  │
│  │          - update session messageCount                  │  │
│  │                │                                        │  │
│  │                ▼                                        │  │
│  │  Step 7: If session ending:                             │  │
│  │          - Generate summary via LLM                     │  │
│  │          - Save SUMMARY item to ChatTable               │  │
│  │          - Update session status = "completed"          │  │
│  │                │                                        │  │
│  │                ▼                                        │  │
│  │  Step 8: Return response to frontend                    │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │            ADMIN ENDPOINTS (Phase 2)                   │  │
│  │                                                        │  │
│  │  CRUD operations on KnowledgeTable                     │  │
│  │  → Add/edit/delete KB entries and playbooks            │  │
│  │  → Invalidates the in-memory cache                     │  │
│  │  → Changes reflected in next chat request              │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 8. CDK Definitions

Add to the existing CDK stack in `infra/`:

```typescript
// infra/lib/infra-stack.ts — add these to the existing stack

import * as dynamodb from "aws-cdk-lib/aws-dynamodb";

// Chat Table
const chatTable = new dynamodb.Table(this, "ChatTable", {
  tableName: "minihub-chat",
  partitionKey: {
    name: "sessionId",
    type: dynamodb.AttributeType.STRING,
  },
  sortKey: {
    name: "itemType",
    type: dynamodb.AttributeType.STRING,
  },
  billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
  timeToLiveAttribute: "expiresAt",
  removalPolicy: cdk.RemovalPolicy.RETAIN,
  pointInTimeRecoveryEnabled: true,
});

chatTable.addGlobalSecondaryIndex({
  indexName: "memberSessionsIndex",
  partitionKey: {
    name: "memberId",
    type: dynamodb.AttributeType.STRING,
  },
  sortKey: {
    name: "createdAt",
    type: dynamodb.AttributeType.STRING,
  },
  projectionType: dynamodb.ProjectionType.INCLUDE,
  nonKeyAttributes: [
    "sessionId", "title", "status", "messageCount",
    "memberName", "memberRole", "locationContext"
  ],
});

chatTable.addGlobalSecondaryIndex({
  indexName: "locationSessionsIndex",
  partitionKey: {
    name: "locationContext",
    type: dynamodb.AttributeType.STRING,
  },
  sortKey: {
    name: "createdAt",
    type: dynamodb.AttributeType.STRING,
  },
  projectionType: dynamodb.ProjectionType.INCLUDE,
  nonKeyAttributes: [
    "sessionId", "memberId", "memberName", "title", "messageCount"
  ],
});

// Knowledge Table
const knowledgeTable = new dynamodb.Table(this, "KnowledgeTable", {
  tableName: "minihub-chat-knowledge",
  partitionKey: {
    name: "category",
    type: dynamodb.AttributeType.STRING,
  },
  sortKey: {
    name: "entryId",
    type: dynamodb.AttributeType.STRING,
  },
  billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
  removalPolicy: cdk.RemovalPolicy.RETAIN,
  pointInTimeRecoveryEnabled: true,
});

knowledgeTable.addGlobalSecondaryIndex({
  indexName: "entryTypeIndex",
  partitionKey: {
    name: "type",
    type: dynamodb.AttributeType.STRING,
  },
  sortKey: {
    name: "updatedAt",
    type: dynamodb.AttributeType.STRING,
  },
  projectionType: dynamodb.ProjectionType.ALL,
});

// Add to aws-resources.ts
// CHAT: "minihub-chat",
// CHAT_KNOWLEDGE: "minihub-chat-knowledge",
```

### Estimated Cost

```
DynamoDB (pay-per-request):

Chat Table:
  Writes: ~500 messages/day × 1 WCU each = 500 WCUs/day
  Reads:  ~200 queries/day × ~5 RCU each = 1,000 RCUs/day
  Storage: ~100KB/day × 90 days retention = ~9MB
  Cost: < $2/month

Knowledge Table:
  Writes: ~5 updates/week (admin edits)
  Reads:  ~1 scan every 5 min (prompt cache refresh) = ~288/day
  Storage: < 1MB
  Cost: < $0.50/month

Total DynamoDB: ~$2-3/month
```

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────────┐
│  TABLE: minihub-chat                                             │
│  Partition: sessionId    Sort: itemType                          │
│                                                                  │
│  Item types:                                                     │
│    SESSION                    → session metadata                 │
│    MSG#<timestamp>#<id>       → individual message               │
│    SUMMARY                    → AI-generated session summary     │
│                                                                  │
│  GSI: memberSessionsIndex    (memberId → createdAt)             │
│  GSI: locationSessionsIndex  (locationContext → createdAt)      │
│  TTL: expiresAt (90 days)                                       │
├─────────────────────────────────────────────────────────────────┤
│  TABLE: minihub-chat-knowledge                                   │
│  Partition: category    Sort: entryId                            │
│                                                                  │
│  Item types:                                                     │
│    KNOWLEDGE (category=KB#*)  → FAQ answer, may link to playbook│
│    PLAYBOOK  (category=PB#*)  → step-by-step investigation      │
│                                                                  │
│  GSI: entryTypeIndex    (type → updatedAt)                      │
│  No TTL (permanent data)                                        │
└─────────────────────────────────────────────────────────────────┘
```
