# Walk Like DynamoDB

> A mental model for understanding DynamoDB from the inside — as if you ARE the query engine walking through a physical building.

---

## The Building Analogy

Forget filing cabinets. Let's build a proper mental image.

```
THE BUILDING = One DynamoDB Table
```

Every DynamoDB table is a building. One building, one table. That's it.

---

## Level 1 — The Floors (Physical Partitions)

When you write an item to DynamoDB, the first thing DynamoDB does is ask:

> "Which floor does this belong on?"

It answers that question by **hashing the Partition Key.**

```
You write:  { PK: "STUDENT#S001", SK: "PROFILE", name: "Alice" }

DynamoDB:   hash("STUDENT#S001") = 8,291,847
            8,291,847 mod 10 = FLOOR 7

→ This item lives on Floor 7.
```

The floor is a **physical server** — actual RAM and disk. You don't choose which floor. DynamoDB does, based on the hash. This is why:

- Items with the **same Partition Key** always land on the **same floor**
- Items with **different Partition Keys** may land on different floors
- You can't control it. You just trust it.

```
FLOOR 2  ← hash("STUDENT#S002") lands here
FLOOR 4  ← hash("CLASS#C001") lands here
FLOOR 7  ← hash("STUDENT#S001") lands here
FLOOR 7  ← hash("STUDENT#S001") is always floor 7 — same PK, same floor, always
```

**Why this matters:** When you query by Partition Key, DynamoDB goes **directly to one floor.** No walking around. No checking other floors. One network hop. That's why it's fast.

---

## Level 2 — The Room (Partition Key Value)

You arrive on the correct floor. Now what?

Each floor has **rooms.** Each room belongs to **one Partition Key value.**

```
FLOOR 7
│
├── Room "STUDENT#S001"    ← all items where PK = "STUDENT#S001"
├── Room "STUDENT#S099"    ← different student, same floor (hash collision — fine)
└── Room "BRAND#B001"      ← totally different entity, same floor (fine — DynamoDB handles it)
```

> Think of the room as: "everything belonging to this one entity."

When you query `PK = "STUDENT#S001"`, you walk to Floor 7, find the room labelled `STUDENT#S001`, and step inside. Everything in this room belongs to Alice.

---

## Level 3 — The Shelves (Sort Key Order)

You're inside Alice's room. Now you see **shelves along the walls.**

The shelves are not random. They are **alphabetically/numerically ordered by Sort Key**, from left to right, top to bottom.

```
Alice's Room (PK = "STUDENT#S001")
│
│  ← SHELF ORDER (left to right, alphabetical by Sort Key)
│
├── [EMERGENCY#E001]   ← "E" comes before "P" before "S" in the alphabet
├── [EMERGENCY#E002]
├── [EMERGENCY#E003]
├── [PROFILE]
└── [SUBJECT#MATH]
    [SUBJECT#SCIENCE]
```

The shelves are sorted. This means you can:

- **Jump to a specific shelf:** `SK = "PROFILE"` → go directly there (binary search — instant)
- **Read a range of shelves:** `SK BEGINS_WITH "EMERGENCY#"` → read all emergency contacts only
- **Read everything:** no SK filter → read all shelves left to right

This is the Sort Key's entire purpose: **to let you navigate within a room without reading the whole thing.**

---

## Level 4 — The Folder (The Item Itself)

On each shelf, there is **one folder.** The folder is the actual item — the record.

```
Shelf: EMERGENCY#E001
Folder contents:
  {
    PK:        "STUDENT#S001",
    SK:        "EMERGENCY#E001",
    name:      "Margaret Smith",
    relation:  "Mother",
    phone:     "0411 222 333",
    createdAt: "2026-02-26T09:00:00Z"
  }
```

The folder can have **any attributes you want.** Different item types (different SKs) can have completely different attributes. The PROFILE folder has different fields than the EMERGENCY folder. That's fine. DynamoDB doesn't enforce a schema.

---

## The Full Walk-Through — As If You ARE the Query Engine

```
YOU ARE: DynamoDB, receiving a query.

QUERY:
  Table: school
  PK = "STUDENT#S001"
  SK BEGINS_WITH "EMERGENCY#"

STEP 1 — Which floor?
  hash("STUDENT#S001") = FLOOR 7
  → Walk to Floor 7.

STEP 2 — Which room?
  PK = "STUDENT#S001"
  → Enter Room "STUDENT#S001"

STEP 3 — Which shelves?
  SK BEGINS_WITH "EMERGENCY#"
  → Using sorted order, jump to the first shelf that starts with "EMERGENCY#"
  → Read shelves: EMERGENCY#E001, EMERGENCY#E002, EMERGENCY#E003
  → Stop when shelves no longer start with "EMERGENCY#"
  → Skip: PROFILE, SUBJECT#MATH (not your problem today)

STEP 4 — Return the folders
  → Pick up the 3 folders
  → Return their contents to the caller

TOTAL DISK READS: 1 (one room, contiguous shelves)
TOTAL TIME: Milliseconds
```

Compare that to a SCAN (no partition key specified):

```
QUERY:
  Table: school
  Filter: name = "Margaret Smith"   ← not a key attribute

STEP 1 — Which floor?
  ??? You didn't give a PK.
  → I have to visit EVERY floor.

STEP 2 — Which room?
  ??? No PK means I must check EVERY room on EVERY floor.

STEP 3 — Which shelves?
  → I must open EVERY folder in EVERY room and read the "name" attribute.

STEP 4 — Return matches
  → Return only items where name = "Margaret Smith"

TOTAL DISK READS: ALL OF THEM
TOTAL TIME: Could be seconds. Costs money. Hurts performance.
```

**This is why scans are bad.** You're physically walking the entire building.

---

## Your Emergency Contact Question — Answered

> "A student can have multiple emergency contacts — mom, dad, aunt. How do I model this?"

You nailed it. Here's exactly how:

```
Room: "STUDENT#S001" (Alice's room)

Shelf: EMERGENCY#E001
  { name: "Margaret Smith", relation: "Mother", phone: "0411 222 333" }

Shelf: EMERGENCY#E002
  { name: "Robert Smith", relation: "Father", phone: "0422 444 555" }

Shelf: EMERGENCY#E003
  { name: "Aunty Sue", relation: "Aunt", phone: "0433 666 777" }

Shelf: PROFILE
  { name: "Alice Smith", grade: 10, email: "alice@..." }
```

**Get all emergency contacts for Alice:**
```
PK = "STUDENT#S001"
SK BEGINS_WITH "EMERGENCY#"
→ Returns 3 folders. One room visit. Done.
```

**Get just Alice's profile:**
```
PK = "STUDENT#S001"
SK = "PROFILE"
→ Returns 1 folder. Direct shelf grab.
```

**Get Alice's profile AND all emergency contacts:**
```
PK = "STUDENT#S001"
(no SK filter)
→ Returns 4 folders. Still one room visit.
```

---

## The `#` Prefix — What It's Actually Doing

The `#` is just a **naming convention.** DynamoDB doesn't care about `#`. It's for YOU.

It does two things:

### 1. Namespaces the entity type

```
"STUDENT#S001"   → you know this is a student
"CLASS#C001"     → you know this is a class
"EMERGENCY#E001" → you know this is an emergency contact
```

Without the prefix, you'd have `S001` and not know what it is.

### 2. Enables range queries by type

Because sort keys are **alphabetically sorted**, everything with the same prefix clusters together on the shelves:

```
Shelf order in Alice's room:
  EMERGENCY#E001   ← "E" items grouped
  EMERGENCY#E002
  EMERGENCY#E003
  PROFILE          ← "P" items
  SUBJECT#MATH     ← "S" items grouped
  SUBJECT#SCIENCE
```

`BEGINS_WITH "EMERGENCY#"` works because DynamoDB can do a **binary search** to the first "EMERGENCY#" shelf and read forward until the prefix stops matching. It's like a bookmark.

---

## The Building — Full Picture

```
┌────────────────────────────────────────────────────────────┐
│                    THE BUILDING (table: school)             │
│                                                             │
│  FLOOR 7                                                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Room "STUDENT#S001"  (Alice)                        │   │
│  │                                                      │   │
│  │  Shelf: EMERGENCY#E001  │ { name: Margaret, ... }   │   │
│  │  Shelf: EMERGENCY#E002  │ { name: Robert, ... }     │   │
│  │  Shelf: EMERGENCY#E003  │ { name: Aunty Sue, ... }  │   │
│  │  Shelf: PROFILE         │ { name: Alice, grade: 10 }│   │
│  │  Shelf: SUBJECT#MATH    │ { grade: A, teacher: ... }│   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  FLOOR 2                                                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Room "STUDENT#S002"  (Bob)                          │   │
│  │  Shelf: EMERGENCY#E001  │ { name: Bob's mum, ... }  │   │
│  │  Shelf: PROFILE         │ { name: Bob, grade: 10 }  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  FLOOR 4                                                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Room "CLASS#C001"  (Math class)                     │   │
│  │  Shelf: DETAILS         │ { teacher: Dr Smith, ... }│   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

---

## Summary — The 4 Levels

| Level | Physical analogy | DynamoDB concept | Set by |
|-------|-----------------|-----------------|--------|
| 1 | **Floor** | Physical partition (server) | Hash of Partition Key — automatic |
| 2 | **Room** | All items sharing a Partition Key value | You choose the PK value |
| 3 | **Shelf** | Position within the room | Sort Key — sorted, enables range queries |
| 4 | **Folder** | The item itself | Your attributes |

**Query = "Go to this floor, this room, these shelves, open those folders."**

When you give DynamoDB a Partition Key, you tell it the floor AND the room. When you add a Sort Key filter, you tell it which shelves. The more specific you are, the less it has to walk.

---

## Secondary Indexes — GSI vs LSI

Sometimes the main building can't answer a question efficiently. You need a different way in. That's what indexes are for. There are two kinds, and they are **fundamentally different.**

---

### GSI — Global Secondary Index (A Whole New Building)

> **"Same data. Different city. Different streets. Different rooms. Different entry point."**

A GSI is a **completely separate building** — its own floors, its own rooms, its own shelves — but populated with copies of the same folders (or a subset of their pages).

```
MAIN BUILDING  (table: school)
Organized by: PK = studentId

  FLOOR 7 → Room "STUDENT#S001"
    Shelf: EMERGENCY#E001  { name: Margaret, phone: 0411..., relation: Mother }
    Shelf: EMERGENCY#E002  { name: Robert,   phone: 0422..., relation: Father }
    Shelf: PROFILE         { name: Alice, grade: 10 }

  FLOOR 2 → Room "STUDENT#S002"
    Shelf: EMERGENCY#E001  { name: Bob's mum, phone: 0433... }
    Shelf: PROFILE         { name: Bob, grade: 10 }


GSI BUILDING  (index: contactPhoneIndex)
Organized by: PK = phone number, SK = studentId

  FLOOR 3 → Room "0411 222 333"
    Shelf: STUDENT#S001    { name: Margaret, relation: Mother }

  FLOOR 9 → Room "0422 444 555"
    Shelf: STUDENT#S001    { name: Robert, relation: Father }

  FLOOR 1 → Room "0433 666 777"
    Shelf: STUDENT#S002    { name: Bob's mum }
```

**The question the GSI answers:**
> "Someone called 0411 222 333 — which student does this belong to?"

You can't answer that from the main building without scanning every room in every floor. But in the GSI building, you walk straight to Room "0411 222 333" and get your answer instantly.

**Key facts about GSI:**

```
✅ Completely different partition key (different floors, different rooms)
✅ Can be added to an existing table at any time
✅ You choose which attributes to copy ("project") into the GSI building
   → You can copy all attributes, or just the keys + a few fields
   → Copying less = cheaper + faster
⚠️  Eventually consistent — the GSI building is a copy
   → There's a tiny delay (milliseconds usually) between writing to the
      main building and the GSI building catching up
   → Like a courier taking your folder to the second building — near-instant, not instant
⚠️  Costs extra read/write capacity (you're maintaining two buildings)
```

**Walking into a GSI:**

```
QUERY:
  GSI: contactPhoneIndex
  PK = "0411 222 333"

YOU ARE DYNAMODB:
  Step 1 — "Which building?"   → contactPhoneIndex building (not the main one)
  Step 2 — "Which floor?"      → hash("0411 222 333") = FLOOR 3
  Step 3 — "Which room?"       → Room "0411 222 333"
  Step 4 — "Which shelves?"    → (no SK filter, return all)
  Step 5 — Return folders

One walk. One floor. One room. Fast.
```

---

### LSI — Local Secondary Index (A Second Set of Shelves in the Same Room)

> **"Same building. Same floor. Same room. But a second set of shelves, sorted differently."**

An LSI is not a new building. It's not even a new room. It's a **second shelf arrangement bolted onto the same room.**

Remember Alice's room is sorted by Sort Key alphabetically:
```
Alice's Room — MAIN SHELF ORDER (SK = itemType)
  EMERGENCY#E001
  EMERGENCY#E002
  EMERGENCY#E003
  PROFILE
  SUBJECT#MATH
  SUBJECT#SCIENCE
```

What if you also need to ask: *"Show me Alice's items ordered by when they were created?"*

The main shelves are sorted by `itemType` — you can't re-sort them. But with an LSI, you install a **second set of shelves in the same room**, sorted by `createdAt`:

```
Alice's Room — LSI SHELF ORDER (SK = createdAt)
  2026-01-15T08:00  ← PROFILE (created first)
  2026-02-01T10:30  ← EMERGENCY#E001 (added later)
  2026-02-10T14:00  ← SUBJECT#MATH (added later still)
  2026-02-20T09:15  ← EMERGENCY#E002
  2026-02-22T11:00  ← SUBJECT#SCIENCE
  2026-02-25T16:45  ← EMERGENCY#E003 (most recent)
```

Same folders. Same room. Same floor. Just a different ordering of the shelves so you can walk them chronologically.

**Key facts about LSI:**

```
✅ Same partition key — you're still in the same room (same floor, same physical server)
✅ Strongly consistent — because you're physically in the same room,
   there is NO copy lag. You read the latest data, period.
✅ Automatically maintained — DynamoDB updates both shelf orders on every write
❌ Must be created when the table is first built — you CANNOT add an LSI later
   → Like installing a second shelving system before the room is furnished
   → Once the room has stuff in it, you can't bolt in new shelves
❌ Size limit — 10GB per partition key value
   → If Alice's room fills up past 10GB, the LSI breaks
   → Rarely a problem for most use cases
```

**Walking into an LSI:**

```
QUERY:
  LSI: createdAtIndex
  PK = "STUDENT#S001"
  SK (createdAt) BETWEEN "2026-02-01" AND "2026-02-28"

YOU ARE DYNAMODB:
  Step 1 — "Which building?"   → SAME main building (LSI is inside it)
  Step 2 — "Which floor?"      → hash("STUDENT#S001") = FLOOR 7  (same as always)
  Step 3 — "Which room?"       → Room "STUDENT#S001"  (same room)
  Step 4 — "Which shelves?"    → Use the LSI shelf order (createdAt)
                                  Jump to Feb 1, read until Feb 28
  Step 5 — Return folders

Same room. Different shelf set. Consistent data.
```

---

### GSI vs LSI — Side by Side

```
                        GSI                         LSI
                        ──────────────────────────  ──────────────────────────
Building?               New building entirely       Same main building
Floor?                  Different floor             Same floor (same PK hash)
Room?                   Different room (new PK)     Same room (same PK value)
Shelves?                New sort key                New sort key in same room
Consistency?            Eventually consistent       Strongly consistent
                        (copy lag, ms usually)      (same physical location)
Add after creation?     ✅ Yes, anytime             ❌ No, table creation only
Size limit?             No per-partition limit       10GB per partition key
Use when?               Need a completely           Need different sort order
                        different entry point        for the same "owner"
                        (different PK)               (same PK, different SK)
```

---

### The One-Line Memory Aid

```
GSI = "I need to enter the building from a different street entirely"
      → Different partition key. New building. Different floor.

LSI = "I'm already in the right room, I just need the shelves sorted differently"
      → Same partition key. Same room. Second shelf order.
```

---

### Real Example From Our Project

In `minihub-chat`, we use two GSIs:

```
MAIN TABLE — Partition Key: sessionId
  → "Give me all messages in session chat_abc123"
  → Go to Room "chat_abc123", read shelves starting with "MSG#"

GSI: memberSessionsIndex — Partition Key: memberId
  → "Give me all sessions for member gordon-uuid"
  → New building. Go to Room "gordon-uuid". See all his sessions listed there.
  → Can't do this from the main table — there's no "gordon-uuid" room there.

GSI: locationSessionsIndex — Partition Key: locationContext
  → "Give me all sessions from Location L042"
  → New building. Go to Room "L042". See all sessions from that location.
```

No LSIs in our chat table — because all our secondary queries need a **completely different partition key**, not just a different sort order on the same session. LSIs would be useful if, say, we needed to query messages by session AND sort them by sentiment score instead of timestamp — same room (`sessionId`), different shelf order.

