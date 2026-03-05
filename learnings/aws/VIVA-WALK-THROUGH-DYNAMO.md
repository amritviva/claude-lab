# Viva — Walk Through DynamoDB

> A hands-on walkthrough using real Viva data. Members, Locations, Contracts.
> We'll design tables, walk writes, walk reads, hit real problems, and solve them.

---

## The Cast — Real Viva Entities

From the GraphQL schema, here's what we're working with:

```
Member
  memberId        ← primary key in Amplify
  givenName       ← "Sarah"
  surname         ← "Mitchell"
  email           ← sarah.mitchell@gmail.com
  mobileNumber    ← 0412 345 678
  homeLocationId  ← which gym is her home location
  joinedDateTime  ← when she joined
  type            ← MEMBER or STAFF
  isActive        ← is she an active member
  brandId         ← which brand (e.g. Plus Fitness)
  dob, address, suburb, state, postCode, etc.

Location
  id              ← "loc-sydney-cbd-001"
  name            ← "Plus Fitness Sydney CBD"
  brandId
  state, suburb, status (ACTIVE/INACTIVE/TEMPCLOSED)

MemberContract
  id
  memberId        ← belongs to member
  locationId      ← signed up at this location
  membershipName  ← "Fortnightly DD"
  costPrice       ← $29.95
  isActive
  startDateTime, endDateTime
```

Viva has ~270 locations, ~500,000 members across all brands.

---

## Part 1 — Designing with locationId as the Room

> The user asked: "What if locationId is the partition key (the room)?"
> Let's do exactly that and see what happens — good and bad.

### The Idea

```
TABLE: viva-location-members

Partition Key (PK): locationId    → the ROOM
Sort Key (SK):      memberId      → order of folders in the room
```

```
BUILDING: viva-location-members
│
├── FLOOR 3  (hash of "loc-sydney-cbd-001" lands here)
│   │
│   └── ROOM "loc-sydney-cbd-001"  (Plus Fitness Sydney CBD)
│       │
│       ├── Shelf: MEMBER#mem-001  { givenName: Sarah, surname: Mitchell, email: sarah@... }
│       ├── Shelf: MEMBER#mem-002  { givenName: James, surname: Wong,     email: james@... }
│       ├── Shelf: MEMBER#mem-003  { givenName: Priya, surname: Patel,    email: priya@... }
│       ├── Shelf: MEMBER#mem-004  { givenName: Tom,   surname: Evans,    email: tom@...   }
│       └── ... (2000 more members)
│
├── FLOOR 7  (hash of "loc-broken-hill-001" lands here)
│   │
│   └── ROOM "loc-broken-hill-001"  (Plus Fitness Broken Hill)
│       │
│       ├── Shelf: MEMBER#mem-288  { givenName: Ken, surname: Murray ... }
│       └── ... (50 members)
│
└── FLOOR 1  (hash of "loc-parramatta-001" lands here)
    │
    └── ROOM "loc-parramatta-001"
        └── ... (800 members)
```

### Access Patterns This Answers

```
✅ "Show me all members at Plus Fitness Sydney CBD"
   → PK = "loc-sydney-cbd-001"
   → ONE room. ONE disk read. All 2000 folders returned.

✅ "Show me member mem-003 at Sydney CBD"
   → PK = "loc-sydney-cbd-001" AND SK = "MEMBER#mem-003"
   → ONE shelf. Instant.

✅ "How many members does Broken Hill have?"
   → PK = "loc-broken-hill-001", count folders
   → ONE room.
```

---

## Part 2 — LSI: Same Room, Different Shelf Order

You're a staff member at Sydney CBD. You need two different views:

1. **Member list for check-in:** Show members sorted by **surname** (alphabetical)
2. **New joiner report:** Show members sorted by **joinedDateTime** (newest first)

The main table is sorted by `memberId` — you can't answer either question efficiently.

### What You'd Want

```
MAIN TABLE sorted by memberId:
  MEMBER#mem-001  → Sarah Mitchell  (joined 2023-01-15)
  MEMBER#mem-002  → James Wong      (joined 2024-06-20)
  MEMBER#mem-003  → Priya Patel     (joined 2022-03-10)
  MEMBER#mem-004  → Tom Evans       (joined 2024-11-05)

What you WANT for the check-in screen (sorted by surname):
  Evans, Tom       → mem-004
  Mitchell, Sarah  → mem-001
  Patel, Priya     → mem-003
  Wong, James      → mem-002

What you WANT for the new joiner report (sorted by joinedDateTime):
  2024-11-05  → Tom Evans      (newest)
  2024-06-20  → James Wong
  2023-01-15  → Sarah Mitchell
  2022-03-10  → Priya Patel    (oldest)
```

### Adding LSIs

You install **two extra sets of shelves** in each room at table creation time.

```
TABLE: viva-location-members

Main PK: locationId    Main SK: memberId

LSI 1: surnameIndex
  PK: locationId (same room!)   SK: surname#memberId
  (reason for surname#memberId: if two members share a surname, we still need uniqueness)

LSI 2: joinedDateTimeIndex
  PK: locationId (same room!)   SK: joinedDateTime
```

Now the room looks like this:

```
ROOM "loc-sydney-cbd-001"

  MAIN SHELVES (sorted by memberId):
    MEMBER#mem-001  │ Sarah Mitchell  │ joined 2023-01-15
    MEMBER#mem-002  │ James Wong      │ joined 2024-06-20
    MEMBER#mem-003  │ Priya Patel     │ joined 2022-03-10
    MEMBER#mem-004  │ Tom Evans       │ joined 2024-11-05

  LSI 1 SHELVES (sorted by surname#memberId):
    Evans#mem-004   │ Tom Evans       │ ...
    Mitchell#mem-001│ Sarah Mitchell  │ ...
    Patel#mem-003   │ Priya Patel     │ ...
    Wong#mem-002    │ James Wong      │ ...

  LSI 2 SHELVES (sorted by joinedDateTime):
    2022-03-10      │ Priya Patel     │ mem-003
    2023-01-15      │ Sarah Mitchell  │ mem-001
    2024-06-20      │ James Wong      │ mem-002
    2024-11-05      │ Tom Evans       │ mem-004
```

**Same room. Same physical server. Same floor. Three shelf arrangements.**

### Querying with an LSI

```
Check-in screen: "All members at Sydney CBD sorted by surname"
  LSI query: PK = "loc-sydney-cbd-001" (same room)
             Use surnameIndex shelf order
  → Evans, Mitchell, Patel, Wong  ✅

New joiner report: "Most recent 10 joiners at Sydney CBD"
  LSI query: PK = "loc-sydney-cbd-001" (same room)
             Use joinedDateTimeIndex, sort DESC, limit 10
  → Tom Evans, James Wong, Sarah Mitchell, Priya Patel...  ✅
```

No scan. No extra network hop. Just using a different set of shelves in the same room.

### LSI Limits — The 10GB Rule

Here's the thing. All shelf sets in a room (main + LSIs) share the **same physical space** on that floor.

```
ROOM "loc-sydney-cbd-001":
  Main shelves:  2000 members × 2KB each = ~4MB
  LSI 1 shelves: 2000 copies × 1KB each = ~2MB   (projected attributes only)
  LSI 2 shelves: 2000 copies × 1KB each = ~2MB

  Total room size: ~8MB  ← well under 10GB. Fine.
```

But your hypothetical "1 billion members in one room":

```
ROOM "loc-giant-001":
  1,000,000,000 members × 2KB = 2,000,000,000 KB = ~2TB

  DynamoDB stops accepting writes at 10GB per partition.
  You'd be dead at ~5,000,000 members in one location.
```

In practice, Viva's largest location might have 10,000 members:
```
10,000 × 2KB = 20MB → totally fine. 10GB is a generous limit.
```

But the rule is: **the more data per partition key value, the less headroom you have.** If you chose `brandId` as your PK instead of `locationId`, and Plus Fitness has 400,000 members in one brand room — now you're at 800MB and approaching risk.

**Lesson:** Pick a partition key that distributes data evenly across many rooms. `locationId` is good. `brandId` is too broad. `memberId` is the most granular (each member gets their own room).

---

## Part 3 — GSI: A New Building for a New Question

The questions LSIs can't answer: ones that need a **completely different entry point.**

```
A staff member gets a phone call from someone saying:
"Hi, I'm Sarah Mitchell. My email is sarah.mitchell@gmail.com.
 I was charged twice this month."

Staff looks up: "Find the member with this email."

The main table is organised by locationId. Sarah's email isn't on any shelf label.
You'd have to open EVERY folder in EVERY room to find her.

→ That's a SCAN. Expensive. Slow.
→ You need a GSI.
```

### GSI 1: Find Member by Email

```
SECOND BUILDING: emailIndex
  PK: email           → the new room label
  SK: memberId        → order of shelves in the email room
  Projected: givenName, surname, homeLocationId, isActive, mobileNumber
```

```
SECOND BUILDING (emailIndex)
│
├── FLOOR 6  (hash of "sarah.mitchell@gmail.com")
│   └── ROOM "sarah.mitchell@gmail.com"
│       └── Shelf: mem-001  { givenName: Sarah, surname: Mitchell, homeLocationId: loc-sydney-cbd-001 }
│
├── FLOOR 2  (hash of "james.wong@hotmail.com")
│   └── ROOM "james.wong@hotmail.com"
│       └── Shelf: mem-002  { givenName: James, surname: Wong, homeLocationId: loc-sydney-cbd-001 }
│
└── ...one room per email address across all 500,000 members...
```

**Query:**
```
"Find member with email sarah.mitchell@gmail.com"
  GSI query: emailIndex, PK = "sarah.mitchell@gmail.com"
  → Floor 6 → Room "sarah.mitchell@gmail.com" → Sarah's folder
  → Returns: memberId = mem-001, homeLocationId = loc-sydney-cbd-001
  → Then use memberId to fetch full details from main table if needed
```

### GSI 2: Find Member by Mobile

Same pattern. Different building.

```
THIRD BUILDING: mobileIndex
  PK: mobileNumber
  SK: memberId

ROOM "0412 345 678"
  → mem-001: Sarah Mitchell  ✅
```

### GSI 3: Find Members by Brand (with type filter)

From the schema: `memberByBrandId` index with sort key `type`.

```
FOURTH BUILDING: brandMembersIndex
  PK: brandId
  SK: type (MEMBER or STAFF)

ROOM "brand-plus-fitness"
  Shelf: MEMBER#mem-001  → Sarah Mitchell
  Shelf: MEMBER#mem-002  → James Wong
  ...
  Shelf: STAFF#mem-501   → Chris (staff member)
  Shelf: STAFF#mem-502   → Kelly (staff member)
```

**Query:**
```
"List all staff at Plus Fitness brand"
  GSI query: brandMembersIndex
             PK = "brand-plus-fitness"
             SK BEGINS_WITH "STAFF"
  → Returns only staff members  ✅
```

---

## Part 4 — Writing to the Table (The INSERT Walk)

> You understand reads. But what happens when you CREATE a new member?

### The New Member: Tom Evans joins Plus Fitness Sydney CBD

```javascript
// Your code calls DynamoDB PutItem:
{
  TableName: "viva-location-members",
  Item: {
    locationId:      "loc-sydney-cbd-001",   // PK
    memberId:        "MEMBER#mem-004",        // SK
    givenName:       "Tom",
    surname:         "Evans",
    email:           "tom.evans@gmail.com",
    mobileNumber:    "0499 111 222",
    joinedDateTime:  "2024-11-05T10:30:00Z",
    isActive:        true,
    brandId:         "brand-plus-fitness",
    type:            "MEMBER"
  }
}
```

### What DynamoDB Does — Step by Step

**Step 1 — Route to the correct floor (main table)**
```
hash("loc-sydney-cbd-001") = FLOOR 3
→ Go to Floor 3
```

**Step 2 — Find or create the room**
```
Room "loc-sydney-cbd-001" already exists (2003 other members are there)
→ Enter the room
```

**Step 3 — Place the folder on the main shelf**
```
SK = "MEMBER#mem-004"
Shelves are sorted. Find the correct alphabetical position.
MEMBER#mem-001, MEMBER#mem-002, MEMBER#mem-003, [MEMBER#mem-004 goes here], MEMBER#mem-...
→ Folder placed  ✅
```

**Step 4 — Update LSI shelf sets IN THE SAME ROOM**
```
LSI 1 (surnameIndex):
  DynamoDB reads: surname = "Evans", memberId = "mem-004"
  Shelf key = "Evans#mem-004"
  Find correct alphabetical position in the surname shelf set.
  Before: ...Evans#mem-004 doesn't exist...
  After:  Evans#mem-004 is placed between  → sorted correctly  ✅

LSI 2 (joinedDateTimeIndex):
  DynamoDB reads: joinedDateTime = "2024-11-05T10:30:00Z"
  Places it at the correct chronological position in the datetime shelf set  ✅
```

**Step 5 — Copy projected attributes to EACH GSI building**
```
GSI: emailIndex
  hash("tom.evans@gmail.com") → FLOOR 9 of the emailIndex building
  Room "tom.evans@gmail.com" → Place folder:
    { memberId: mem-004, givenName: Tom, surname: Evans, homeLocationId: ..., isActive: true }
  → Done  ✅

GSI: mobileIndex
  hash("0499 111 222") → FLOOR 2 of the mobileIndex building
  Room "0499 111 222" → Place folder:
    { memberId: mem-004, givenName: Tom, ... }
  → Done  ✅

GSI: brandMembersIndex
  hash("brand-plus-fitness") → some floor
  Room "brand-plus-fitness"
  SK = "MEMBER#mem-004"
  → Folder placed  ✅
```

**All of this is ONE PutItem call. DynamoDB maintains every shelf set and every building automatically.**

```
Your code: 1 PutItem
DynamoDB:  1 main table write
           2 LSI shelf updates (same room, fast)
           3 GSI building writes (async, near-instant)
```

### The Cost of GSIs on Writes

Every GSI you add means DynamoDB does more work on every write. For every item you put/update/delete:
- Each GSI gets a copy written to it
- You're charged write capacity units for the main table AND each GSI

This is why you don't add GSIs you don't need. Every GSI is "buying" fast reads by paying on writes.

```
GSI = Pay a little extra on every WRITE
      to make certain READs instant
```

---

## Part 5 — Updating a Member (What Happens to Indexes)

Sarah Mitchell changes her email from `sarah.mitchell@gmail.com` to `sarah.mitchell@icloud.com`.

```javascript
DynamoDB UpdateItem:
  PK: "loc-sydney-cbd-001"
  SK: "MEMBER#mem-001"
  SET email = "sarah.mitchell@icloud.com"
```

### What DynamoDB Does

**Main table:** Goes to Floor 3, Room "loc-sydney-cbd-001", Shelf "MEMBER#mem-001" — updates the email attribute. ✅

**LSI:** Email isn't a sort key in any LSI → nothing to update in LSIs. ✅

**GSI: emailIndex (the email building):**
```
OLD email was the room key → "sarah.mitchell@gmail.com" room
DynamoDB must:
  1. DELETE Sarah's folder from room "sarah.mitchell@gmail.com"  ← old room gone
  2. CREATE Sarah's folder in room "sarah.mitchell@icloud.com"   ← new room

This is an automatic re-shelving. DynamoDB handles it.
Cost: 2 write operations on the GSI (one delete, one put)
```

**This is why GSI partition keys should be stable fields.** If you use a field that changes constantly (like `lastLoginDate`) as a GSI partition key, you're paying for a delete + put on that GSI every single update. Email is fairly stable. Phone number changes occasionally. Good enough.

---

## Part 6 — The Hot Partition Problem

> The user asked: "if we put 1 billion members in one room, we have a problem, right?"

Yes. Two problems actually.

### Problem 1 — The 10GB Size Limit

```
LOC#loc-sydney-cbd-001 with 5,000,000 members:
  5,000,000 × 2KB = 10GB → DynamoDB stops accepting writes.
  Error: "Item collection size limit exceeded"
```

Real Viva numbers:
```
270 locations × 2000 avg members = 540,000 members total
Largest location: maybe 10,000 members × 2KB = 20MB
Far, far under 10GB. You're safe with locationId as PK.
```

### Problem 2 — The Hot Partition (Throughput Bottleneck)

This is the more real-world concern. It's not about size, it's about **traffic**.

```
DynamoDB has a default limit of 3000 read requests/second per partition.

If your busiest location "loc-sydney-cbd-001" is getting 500 check-ins per minute
during the 6am morning rush → ~8 requests/second → fine.

But if you had ONE partition for ALL members (like if you used brandId):
  "brand-plus-fitness" → 400,000 members
  Monday morning rush across ALL Plus Fitness locations:
  5,000 members checking in at the same time → queries all hitting ONE partition
  → Throttling. Slow responses.
```

**The fix:** Spread traffic by choosing a partition key that naturally distributes load.

```
BAD partition key:   brandId     → all traffic for Plus Fitness hits one partition
OKAY partition key:  locationId  → traffic spread across 270 location partitions
BEST partition key:  memberId    → traffic spread across 500,000 member partitions
```

The more "rooms" you have, the more floors DynamoDB can spread them across, and the more servers share the load.

---

## Part 7 — How Viva Actually Does It (Real Amplify Schema)

The Amplify schema uses `memberId` as the partition key for the Member table — NOT locationId.

```
TABLE: Member (Amplify-managed DynamoDB)
  PK: memberId    → "each member gets their own room"
```

This means:
- Sarah's room: `mem-001` → one folder with all her attributes
- There are no "sort key" items in her room — she IS the whole room
- Fast single-member lookups by ID (the most common operation)

The `homeLocationId` is a **GSI** — a second building where rooms are organized by location:

```
GSI: memberByHomeLocationId
  PK: homeLocationId
  → Room "loc-sydney-cbd-001" → [mem-001, mem-002, mem-003, mem-004, ...]
  → "Give me all members at Sydney CBD" → one GSI query ✅
```

### The @index decorators in the schema = GSIs

```
email: AWSEmail
  @index(name: "memberByEmail", queryField: "getMemberByEmail")
↑
This creates: GSI building "memberByEmail"
              PK = email
              → "Find member by email" → instant ✅

mobileNumber: String
  @index(name: "memberByMobile", queryField: "getMemberByMobile")
↑
GSI building "memberByMobile"
PK = mobileNumber  ✅

surname: String
  @index(name: "memberBySurname", queryField: "getMemberBySurname")
↑
GSI building "memberBySurname"
PK = surname
→ "Find members with surname Mitchell" ✅

brandId: ID
  @index(name: "memberByBrandId", sortKeyFields: ["type"])
↑
GSI building "memberByBrandId"
PK = brandId, SK = type (MEMBER or STAFF)
→ "Give me all STAFF at Plus Fitness brand" → PK + SK filter ✅
```

Every `@index` in the schema = another building DynamoDB maintains automatically. Amplify generates the CDK/CloudFormation for all of this.

---

## Summary — The Full Mental Map

```
┌────────────────────────────────────────────────────────────────┐
│               VIVA MEMBER DATA — DYNAMO BUILDINGS              │
│                                                                  │
│  MAIN BUILDING (table: Member)                                   │
│  Organized by: memberId                                          │
│                                                                  │
│  FLOOR 4 → Room "mem-001"                                        │
│    Shelf: PROFILE  { Sarah Mitchell, email, mobile, ... }        │
│                                                                  │
│  FLOOR 9 → Room "mem-002"                                        │
│    Shelf: PROFILE  { James Wong, email, mobile, ... }            │
│                                                                  │
│  ...500,000 rooms, one per member...                             │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│  GSI BUILDING 1 (memberByHomeLocationId)                         │
│  Organized by: homeLocationId                                    │
│                                                                  │
│  Room "loc-sydney-cbd-001"                                       │
│    → [mem-001, mem-002, mem-003, mem-004, ...]   2000 members    │
│                                                                  │
│  Room "loc-broken-hill-001"                                      │
│    → [mem-288, mem-289, ...]                     50 members      │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│  GSI BUILDING 2 (memberByEmail)                                  │
│  Organized by: email                                             │
│                                                                  │
│  Room "sarah.mitchell@gmail.com" → mem-001                       │
│  Room "james.wong@hotmail.com"   → mem-002                       │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│  GSI BUILDING 3 (memberByMobile)                                 │
│  Organized by: mobileNumber                                      │
│                                                                  │
│  Room "0412 345 678" → mem-001                                   │
│  Room "0412 999 888" → mem-002                                   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘

A staff member calls about "Sarah Mitchell, mobile 0412 345 678":
  → GSI Building 3, Room "0412 345 678"
  → memberId = mem-001
  → Main Building, Room "mem-001"
  → Full member profile  ✅  Two queries. Both instant.
```

---

## Quick Reference Card

| Situation | Tool | Why |
|-----------|------|-----|
| List all members at a location | `locationId` as PK (or GSI) | Same room = one query |
| Find member by email | GSI on email | New entry point = new building |
| Find member by mobile | GSI on mobile | New entry point |
| Members at location sorted by surname | LSI on surname | Same room, different shelves |
| Members at location sorted by join date | LSI on joinedDateTime | Same room, different shelves |
| Member has lots of items (contracts, etc.) | `memberId` as PK, item type as SK | Related items in one room |
| One location gets too busy | Don't use brandId as PK | Hot partition |
| Insert new member | PutItem once | DynamoDB updates all LSIs + GSIs automatically |
| Update member email | UpdateItem once | DynamoDB re-shelves in emailIndex automatically |
