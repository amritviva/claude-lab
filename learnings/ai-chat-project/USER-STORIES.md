# AI Support Chat — User Stories

> **Status:** Planning
> **Phase:** Pre-implementation
> **Scope:** Hub-specific (MiniHub + vivareact + vivaamplify)
> **Last Updated:** 2026-02-27

---

## The Actors

| Actor | Who they are | What they care about |
|-------|-------------|----------------------|
| **Staff (L1–L3)** | Front desk, trainers, club staff | Quick answers about members at their location |
| **Manager (L4–L5)** | Club manager, area manager | Their location(s) — may manage 1–4 clubs |
| **Admin** | Brand-level admin | All sessions across their brand, costs, quality |
| **Super-admin** | Viva IT/ops | Everything across all brands and locations |

All actors who use the chat = **Staff role** in stories below.
Admin and Super-admin have chat access AND reporting access.

---

## Epic 1 — Opening the Chat

> The staff member opens the Hub, navigates to the chat, and sees their context before asking anything.

---

### Story 1.1 — Welcome Screen with My Context

```
As a staff member,
When I open the chat window,
I want to see my name, my role, and the locations I have access to,
So that I know the chat understands who I am and what I can ask about.
```

**Acceptance Criteria:**
- [ ] Chat window displays: "Hi [First Name]" on load
- [ ] Displays staff role label (e.g., "Club Manager — L4")
- [ ] Displays location access count: "You have access to 3 locations"
- [ ] Lists location names (or first 3 with "+N more" if many)
- [ ] Displays a brief description of what the bot can help with
- [ ] No chat has started yet — this is the pre-conversation state

**Example UI:**
```
┌──────────────────────────────────────────┐
│  Hi Chris 👋                              │
│                                          │
│  Club Manager (L4)                       │
│  Access: Plus Fitness Sydney CBD         │
│          Plus Fitness Parramatta         │
│          Plus Fitness Chatswood          │
│                                          │
│  I can help you look up member details,  │
│  payment history, contracts, and         │
│  rejection reasons. Just ask me.         │
│                                          │
│  [  Type your question...           ]    │
└──────────────────────────────────────────┘
```

---

### Story 1.2 — First Message Starts a Session

```
As a staff member,
When I type and send my first message,
I want a session to be created automatically,
So that the conversation is tracked and I can return to it later.
```

**Acceptance Criteria:**
- [ ] Session is created on first message send (not on page load)
- [ ] Session gets a generated title from the first question
- [ ] Session appears in the session history sidebar/list
- [ ] Staff does not need to manually "start" a session — it's automatic

---

### Story 1.3 — Typing a Question

```
As a staff member,
I want to type a natural language question about a member or payment,
And receive a clear, plain-English answer,
So that I can resolve the query without raising a support ticket.
```

**Acceptance Criteria:**
- [ ] Text input accepts free-form questions
- [ ] Submit on Enter or button press
- [ ] AI response appears within a reasonable time (loading indicator shown)
- [ ] Response is in plain English — no raw SQL, no JSON, no technical output
- [ ] If the AI uses member data, it cites what it found (e.g., "Member John Doe #4521")
- [ ] Sensitive data is masked (card ending in XXXX, not full number)

**Example Questions the Bot Should Handle:**
```
"Why was member 4521 charged $50 on the 25th?"
"Does Sarah Mitchell have an active contract?"
"What card does James Wong have on file?"
"Are there any rejections on account 9923?"
"When does Tom Evans' membership expire?"
```

---

## Epic 2 — During the Conversation

> The staff member is mid-conversation, asking follow-up questions and navigating the response.

---

### Story 2.1 — Ask a Follow-Up Question

```
As a staff member,
I want to ask a follow-up question without repeating the member's name,
So that the conversation feels natural and not like filling out a form every time.
```

**Acceptance Criteria:**
- [ ] The bot retains context from earlier messages in the same session
- [ ] "What card did they use?" after already discussing a member → bot knows who "they" is
- [ ] Context is maintained for the entire session duration
- [ ] If context is unclear, bot asks a clarifying question rather than guessing

---

### Story 2.2 — Bot Cannot Answer

```
As a staff member,
When the bot cannot find an answer or the question is outside its scope,
I want to receive a clear message saying it cannot help,
With a suggestion to contact support,
So that I know to escalate rather than keep trying.
```

**Acceptance Criteria:**
- [ ] Bot explicitly says it cannot answer (does not hallucinate an answer)
- [ ] Response includes: "Please contact the support team at [email/channel]"
- [ ] Bot does not apologise excessively — one clear sentence is enough
- [ ] Session is still saved even if unresolved

---

### Story 2.3 — Loading / Thinking State

```
As a staff member,
While the bot is processing my question,
I want to see a visual indicator that something is happening,
So that I know the system is working and haven't lost my message.
```

**Acceptance Criteria:**
- [ ] Typing/loading indicator appears after message is sent
- [ ] Indicator disappears when response arrives
- [ ] If response takes >10s, show a secondary message: "Still looking, one moment..."

---

### Story 2.4 — Streaming Response (Nice to Have)

```
As a staff member,
I want to see the bot's response appear word-by-word as it's generated,
So that the experience feels fast even for longer answers.
```

**Acceptance Criteria:**
- [ ] Response streams token-by-token into the chat window
- [ ] Full response is saved to DynamoDB only after streaming completes
- [ ] Partial responses are not saved (avoid saving incomplete data)

---

## Epic 3 — Managing Sessions

> The staff member manages their conversation history.

---

### Story 3.1 — View My Previous Sessions

```
As a staff member,
I want to see a list of my previous chat sessions,
So that I can continue a conversation I started earlier or refer back to an answer.
```

**Acceptance Criteria:**
- [ ] Session list shows: session title, date, status (Active/Closed)
- [ ] Sessions are sorted newest first
- [ ] Clicking a session loads the full conversation history
- [ ] Sessions older than 90 days are not shown (expired)

---

### Story 3.2 — Continue a Previous Session

```
As a staff member,
I want to click on a previous session and continue the conversation,
So that I don't have to repeat context from earlier.
```

**Acceptance Criteria:**
- [ ] Previous messages load correctly with timestamps
- [ ] Typing a new message continues the same session (same sessionId)
- [ ] Bot has access to the prior conversation context
- [ ] Session status changes back to "Active" when a message is sent

---

### Story 3.3 — Start a New Session

```
As a staff member,
I want to start a fresh conversation at any time,
So that I can ask an unrelated question without confusing the bot with old context.
```

**Acceptance Criteria:**
- [ ] "New Chat" button always visible
- [ ] Clicking it clears the current chat window and starts a new session on first message
- [ ] Previous sessions are not deleted — they remain in history
- [ ] New session starts from the welcome screen (Story 1.1)

---

### Story 3.4 — Close / End a Session

```
As a staff member,
When I'm done with a conversation,
I want to close it,
So that it's marked as complete and a summary is generated.
```

**Acceptance Criteria:**
- [ ] "End Chat" or close button visible during an active session
- [ ] On close: session status → CLOSED, summary is generated asynchronously
- [ ] Closed session still visible in history (read-only)
- [ ] If staff navigates away without closing, session auto-closes after 30 min inactivity

---

### Story 3.5 — Session Auto-Closes on Inactivity

```
As a system behaviour,
If a session has had no activity for 30 minutes,
The session should auto-close and a summary should be generated,
So that sessions don't remain perpetually open when staff forget to close them.
```

**Acceptance Criteria:**
- [ ] Inactivity timer: 30 minutes after last message
- [ ] Auto-close triggers the same summary generation as manual close
- [ ] If staff returns to an auto-closed session, they start a new session (not append)
- [ ] Session history still shows the auto-closed session as CLOSED

---

## Epic 4 — Admin: Viewing All Sessions

> Admin and super-admin users can see all chat sessions across their scope.

---

### Story 4.1 — View All Sessions (Admin Dashboard)

```
As an admin,
I want to see all chat sessions across my brand/scope,
So that I can monitor how the chatbot is being used and by whom.
```

**Acceptance Criteria:**
- [ ] Admin sees a table/list of all sessions: staff name, location, date, status, message count
- [ ] Default view: all sessions, sorted by most recent
- [ ] Super-admin sees across all brands; admin sees their brand only
- [ ] Resolved and unresolved sessions are both visible (with a filter option)

---

### Story 4.2 — Filter Sessions by Location

```
As an admin,
I want to filter chat sessions by location,
So that I can see what questions staff at a specific club are asking.
```

**Acceptance Criteria:**
- [ ] Location filter dropdown shows all locations within admin's scope
- [ ] Selecting a location filters the session list to that location's sessions
- [ ] Location filter shows the count of sessions: "Sydney CBD (14 sessions)"
- [ ] Filter is clearable

---

### Story 4.3 — Filter Sessions by Staff Member

```
As an admin,
I want to filter chat sessions by staff member,
So that I can review a specific staff member's usage.
```

**Acceptance Criteria:**
- [ ] Staff member filter: search by name or alias ID
- [ ] Shows all sessions created by that staff member
- [ ] Sessions from all their locations are included (not location-scoped)
- [ ] Filter is clearable

---

### Story 4.4 — View Full Session Transcript

```
As an admin,
I want to click into any session and read the full conversation,
So that I can review the quality of responses and identify training gaps.
```

**Acceptance Criteria:**
- [ ] Clicking a session shows the full message thread
- [ ] Messages show: role (staff/bot), content, timestamp
- [ ] Tools called by the bot are visible to admin (e.g., "Used: findMember, getPayments")
- [ ] Admin is read-only — cannot reply to or modify the conversation
- [ ] Sensitive data rules still apply (cards masked even for admin)

---

### Story 4.5 — View Session Summary

```
As an admin,
I want to see the auto-generated summary of a closed session,
So that I can quickly understand what the conversation was about without reading every message.
```

**Acceptance Criteria:**
- [ ] Summary is displayed prominently at the top (or bottom) of the transcript view
- [ ] Summary shows: topic tags, resolved status, tools used, question count
- [ ] If session has no summary yet (still active or summary pending), show "Summary not yet available"

---

## Epic 5 — Admin: Usage & Cost Reporting

> Admin can track token usage and costs to monitor spend and justify the feature.

---

### Story 5.1 — Total Token Usage Overview

```
As an admin,
I want to see total token usage across all sessions in a date range,
So that I can monitor API costs and forecast spend.
```

**Acceptance Criteria:**
- [ ] Summary view: total input tokens, total output tokens, total cost (AUD estimated)
- [ ] Date range filter: today, this week, this month, custom range
- [ ] Cost is calculated based on model pricing (shown as estimate, not exact invoice)
- [ ] Breakdown by model (if multiple models are used)

---

### Story 5.2 — Token Usage by Location

```
As an admin,
I want to see token usage broken down by location,
So that I can identify which clubs are using the chatbot most.
```

**Acceptance Criteria:**
- [ ] Table: location name | session count | total messages | total tokens | estimated cost
- [ ] Sortable by any column
- [ ] Covers the selected date range

---

### Story 5.3 — Token Usage by Staff Member

```
As an admin,
I want to see token usage per staff member,
So that I can identify heavy users and optimise usage patterns.
```

**Acceptance Criteria:**
- [ ] Table: staff name | alias ID | location | session count | message count | tokens used
- [ ] Sortable by tokens or session count

---

### Story 5.4 — Unresolved Session Alert

```
As an admin,
I want to see a count of sessions marked as unresolved (bot could not answer),
So that I can identify knowledge gaps and improve the bot's coverage.
```

**Acceptance Criteria:**
- [ ] Dashboard shows: "X sessions unresolved this week" (with link to filtered list)
- [ ] Unresolved sessions are flagged in the session list
- [ ] Admin can filter to see only unresolved sessions
- [ ] Topic tags on unresolved sessions help identify common gaps

---

### Story 5.5 — Most Asked Topics

```
As an admin,
I want to see which topics are being asked about most,
So that I can prioritise knowledge base improvements.
```

**Acceptance Criteria:**
- [ ] Tag frequency chart: which topic tags appear most in summaries
- [ ] Top 10 topics shown for the selected date range
- [ ] Clicking a topic filters the session list to sessions with that tag

---

## Epic 6 — Security & Access Control

> The system enforces that users only see and ask about data they're permitted to access.

---

### Story 6.1 — Location-Scoped Answers

```
As a staff member,
When I ask about a member,
I should only be able to get answers about members at my permitted locations,
So that I cannot access member data I'm not authorised to see.
```

**Acceptance Criteria:**
- [ ] Every query the bot runs is scoped to the staff member's `allowedLocationIds`
- [ ] If a member exists but is at a different location, bot responds: "I can't find that member in your locations"
- [ ] Staff cannot override location scoping through any prompt phrasing
- [ ] Location scope is derived from Cognito auth, never from user input

---

### Story 6.2 — Bot Does Not Expose Raw Data

```
As any user,
The bot should never return raw system data, SQL results, or internal IDs,
So that responses are appropriate for a support context.
```

**Acceptance Criteria:**
- [ ] No raw JSON in responses
- [ ] No SQL queries shown to users
- [ ] Card numbers masked (ending in XXXX only)
- [ ] Bank accounts masked (ending in XXX only)
- [ ] BSBs shown as XXX-XXX or omitted
- [ ] Internal UUIDs (memberId, contractId) are not shown to staff (use aliasId instead)

---

### Story 6.3 — Chat Only Available to Authenticated Hub Users

```
As the system,
The chat endpoint should only be accessible to authenticated Hub users,
So that anonymous requests cannot access member data.
```

**Acceptance Criteria:**
- [ ] Chat API requires valid Cognito JWT (same auth as Hub)
- [ ] Expired tokens are rejected with 401
- [ ] Role must be L1 or above to use chat
- [ ] L0 members (regular gym members) cannot access the chat

---

## Epic 7 — System Behaviour (Non-Functional)

> These are system-level expectations that cross all user stories.

---

### Story 7.1 — Chat History Expires After 90 Days

```
As the system,
Chat sessions and messages should be automatically deleted after 90 days,
So that data is not retained indefinitely.
```

**Acceptance Criteria:**
- [ ] DynamoDB TTL set on all items (SESSION, MSG#, SUMMARY)
- [ ] 90 days from `createdAt`
- [ ] Expired sessions no longer appear in history views
- [ ] Deletion is automatic (no manual process required)

---

### Story 7.2 — Session Summary Generated Asynchronously

```
As the system,
When a session is closed,
A summary should be generated without blocking the user,
So that closing the chat is instant.
```

**Acceptance Criteria:**
- [ ] Closing a chat returns immediately to the user
- [ ] Summary generation happens in the background (async)
- [ ] If summary generation fails, session is still marked CLOSED
- [ ] Summary appears in admin view once generated (eventually consistent)

---

### Story 7.3 — Graceful Degradation

```
As a staff member,
If the AI service is unavailable,
I should see a clear error message rather than a broken interface,
So that I know to raise a support ticket or try again later.
```

**Acceptance Criteria:**
- [ ] If Anthropic API is unreachable: "The assistant is temporarily unavailable. Please try again in a few minutes."
- [ ] If DynamoDB is unavailable: same message, session not created
- [ ] No raw error messages or stack traces exposed
- [ ] Error is logged internally for ops monitoring

---

## Story Map — Sequenced for Implementation

```
PHASE 1 — Core Chat (MVP)
  ✦ Story 1.1  Welcome screen with user context
  ✦ Story 1.2  First message starts a session
  ✦ Story 1.3  Ask a question, get a plain-English answer
  ✦ Story 2.1  Follow-up questions with context
  ✦ Story 2.2  Bot cannot answer → escalate message
  ✦ Story 2.3  Loading indicator
  ✦ Story 3.3  Start a new session
  ✦ Story 6.1  Location-scoped answers
  ✦ Story 6.2  No raw data exposure
  ✦ Story 6.3  Cognito auth only

PHASE 2 — Session Management
  ✦ Story 3.1  View my previous sessions
  ✦ Story 3.2  Continue a previous session
  ✦ Story 3.4  Close / end a session
  ✦ Story 3.5  Auto-close on inactivity
  ✦ Story 7.1  90-day TTL
  ✦ Story 7.2  Async summary generation

PHASE 3 — Admin Visibility
  ✦ Story 4.1  View all sessions dashboard
  ✦ Story 4.2  Filter by location
  ✦ Story 4.3  Filter by staff member
  ✦ Story 4.4  View full transcript
  ✦ Story 4.5  View session summary

PHASE 4 — Reporting
  ✦ Story 5.1  Token usage overview
  ✦ Story 5.2  Usage by location
  ✦ Story 5.3  Usage by staff member
  ✦ Story 5.4  Unresolved session alerts
  ✦ Story 5.5  Most asked topics

PHASE 5 — Polish
  ✦ Story 2.4  Streaming responses
  ✦ Story 7.3  Graceful degradation
```

---

## Open Questions

| # | Question | Why it matters |
|---|----------|----------------|
| 1 | Does the chat live inside the Hub frontend (vivareact) or as a separate page? | Affects how auth token is passed and where the UI sits |
| 2 | Should staff see token/cost info, or is that admin-only? | Scope of Phase 3 admin dashboard |
| 3 | Is "end chat" an explicit button or does it auto-close only? | Affects session lifecycle UX |
| 4 | What is the escalation path when bot can't answer? Email? Slack? Just a message? | Story 2.2 acceptance criteria |
| 5 | Should admin see sessions in real-time (live) or is a refresh/periodic load acceptable? | Real-time = WebSockets or polling complexity |
| 6 | Are topic tags on summaries AI-generated, or from a predefined list? | Affects consistency of Story 5.5 reporting |
