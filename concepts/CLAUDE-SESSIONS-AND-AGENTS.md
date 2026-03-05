# Claude — Sessions, State, and the Agent Network

> Answers to: what is a session, how does the LLM get context,
> who controls what, and how to build a multi-project agent team.
> Written for: Amrit Regmi | Last updated: 2026-02-27

---

## 1. What Is a "Session"?

A **session** is the entire conversation thread — from when you type `claude`
until you `/clear` or close the terminal.

```
claude                          ← SESSION STARTS
  You: "explain the auth flow"      ← turn 1 (message)
  Me:  "Here's how..."              ← turn 1 response
  You: "what about refresh tokens?" ← turn 2 (message)
  Me:  "Refresh tokens work by..."  ← turn 2 response
  You: "now fix the bug"            ← turn 3 (message)
  Me:  [reads file, edits it]       ← turn 3 response
/clear                          ← SESSION ENDS → new session starts
```

**A "turn" or "message" = one prompt + one response.**
**A "session" = the whole conversation until cleared.**

Session is saved to: `~/.claude/sessions/<session-id>.json`

---

## 2. The LLM Is Stateless — Claude Code Manages Everything

This is the most important thing to understand.

**The LLM (Claude model) has ZERO memory between API calls.**

Every time you type a message, Claude Code:
1. Builds a **complete package** (system prompt + full conversation history + your new message)
2. Sends the entire package to the API
3. Gets a response
4. Appends it to the conversation history
5. Waits for your next message

```
YOU TYPE: "What about refresh tokens?"

Claude Code sends to API:
┌─────────────────────────────────────────────┐
│ System Prompt:                              │
│   - CLAUDE.md content                       │
│   - All .claude/rules/ content              │
│   - MEMORY.md content                       │
│                                             │
│ Conversation History:                       │
│   Turn 1: "explain the auth flow"           │
│   Turn 1 reply: "Here's how..."             │
│   Turn 2: "what about refresh tokens?" ← you│
└─────────────────────────────────────────────┘

API responds → Claude Code appends to history
```

**Without Claude Code rebuilding this package every time,
the LLM would forget your name mid-conversation.**

---

## 3. Who Controls What — Two Distinct Layers

This confuses most people. Here's the clean separation:

```
┌──────────────────────────────────────────────────────┐
│  YOU CONTROL (the recipe book)                       │
│                                                      │
│  CLAUDE.md              ← you write this             │
│  .claude/rules/*.md     ← you write these            │
│  .claude/settings.json  ← you configure this         │
│  ~/.claude/settings.json← your global config         │
│  ~/.claude/CLAUDE.md    ← your global preferences    │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│  CLAUDE WRITES (the chef's notebook)                 │
│                                                      │
│  ~/.claude/projects/.../memory/MEMORY.md             │
│       ← I write this to remember across sessions     │
│                                                      │
│  ~/.claude/sessions/<id>.json                        │
│       ← Claude Code writes the full session log      │
└──────────────────────────────────────────────────────┘
```

**Rule of thumb:**
- If YOU write it → it's an instruction to me
- If I write it → it's my memory / notes

---

## 4. Prompt Caching — Why It Doesn't Cost Full Price Every Turn

Sending the full CLAUDE.md + rules every API call would be expensive.
This is where **prompt caching** comes in.

```
Turn 1:  Send system prompt (25K tokens) + history (0) + message
         Cost: full price for 25K tokens
         Cache: system prompt stored for 5 minutes

Turn 2:  Send system prompt (CACHED) + history (500 tokens) + message
         Cost: fraction of a cent for cache hit + new tokens only

Turn 3+: Same — system prompt is cached, only new content costs full price
```

**The system prompt (CLAUDE.md + rules) costs ~$0.003 once,
then is essentially free for the next 5 minutes of conversation.**

This is why chat sessions should target a reasonable length —
prompt caching breaks at ~5 minutes of inactivity.

---

## 5. Agents — The Multi-Kitchen Network

### How Agents Work

When I call a **Task agent** (sous chef), here's what actually happens:

```
Main Claude (Head Chef) → spawns → Subagent process
                                        │
                                        ├── Gets its OWN context window (fresh 200K)
                                        ├── Has access to tools (Read, Bash, etc.)
                                        ├── Does NOT share conversation history with me
                                        ├── Can work in any directory I tell it to
                                        │
                                        └── Returns ONE message back to Head Chef
```

**The subagent's entire conversation is invisible to you.**
You only see the Head Chef's summary of what the subagent found.

### Subagent Types Available

| Type | Speciality | Best used for |
|------|-----------|---------------|
| `general-purpose` | Anything — research, code, multi-step | Complex parallel tasks |
| `Explore` | Fast codebase reading | "Find all files matching X", "How does Y work?" |
| `Plan` | Architecture + strategy | Pre-implementation planning |
| `claude-code-guide` | Expert on Claude Code itself | "How do I set up hooks?" |

### Agents in Parallel — The Real Power

```
Without agents:
  Head Chef reads vivareact/  (5 min)
  Head Chef reads hub-insights/ (5 min)
  Head Chef reads vivaamplify/ (5 min)
  Total: 15 minutes, whiteboard 70% full

With agents (parallel):
  Sous Chef A → vivareact/     ↘
  Sous Chef B → hub-insights/   → all at the same time → 5 minutes total
  Sous Chef C → vivaamplify/   ↗
  Head Chef: fresh whiteboard, 3 summaries, ready to plan
```

---

## 6. Multi-Project Agent Setup — The Viva Kitchen Network

You have 4 repos. Each one can be a specialised kitchen.

### The Vision

```
minihubvone (The Main Kitchen — Head Chef lives here)
    │
    ├── calls agent → vivareact/      (Frontend Kitchen)
    │                  reads ChatWindow, understands API contract needed
    │
    ├── calls agent → hub-insights/   (Auth Reference Kitchen)
    │                  reads Cognito middleware, extracts the pattern
    │
    └── calls agent → vivaamplify/    (Schema Kitchen)
                       reads GraphQL schema, finds Member/Auth types
```

### Step 1 — Give Each Kitchen Its Own Recipe Book

Each repo should have a `CLAUDE.md` describing its purpose and key files.

**vivareact/CLAUDE.md** (to create):
```markdown
# vivareact — React Frontend for The Hub
- Framework: React + TypeScript
- Auth: Cognito via Amplify (AuthProvider in src/auth/)
- Chat: placeholder ChatWindow in src/components/Chat/
- Hub connects to minihubvone API for chat endpoints
- Key file: src/components/Chat/ChatWindow.tsx
```

**hub-insights/CLAUDE.md** (to create):
```markdown
# hub-insights — Reporting API (Cognito JWT reference)
- Framework: Express/TypeScript
- Auth: Cognito JWT middleware in app/src/middleware/authorization.ts
- This is the REFERENCE implementation for Cognito auth
- minihubvone should mirror this auth pattern for chat endpoints
```

**vivaamplify/CLAUDE.md** (to create):
```markdown
# vivaamplify — Amplify/AppSync GraphQL Backend
- Framework: AWS Amplify + AppSync
- Source of truth for: Cognito groups (L0-L5, admin, super-admin)
- Source of truth for: Member schema, auth rules
- Key files: amplify/backend/auth/, amplify/data/schema.graphql
```

### Step 2 — From minihubvone, Call Agents Into Other Repos

```
You: "Read the Cognito auth in hub-insights and
      plan how we replicate it in minihubvone"

Head Chef calls agent:
  "Go to ~/Desktop/viva/hub-insights/
   Find the authorization middleware.
   Read it completely.
   Return: the exact pattern used for JWT validation,
   what it extracts from the token, and how it handles errors."

Agent returns summary.
Head Chef uses it to plan minihubvone's implementation.
```

### Step 3 — Run All Three in Parallel for Planning

```
You: "Plan Phase 1 of the chat module.
      I need to understand the frontend contract,
      the auth pattern, and the schema before we write code."

Head Chef runs 3 agents simultaneously:
  Agent A: "Read vivareact ChatWindow — what API endpoints does it expect?"
  Agent B: "Read hub-insights auth — extract the JWT middleware pattern"
  Agent C: "Read vivaamplify schema — find Member, Group, Auth types"

All 3 finish → Head Chef synthesises → full Phase 1 plan ready
```

---

## 7. Global Safety Rules (Already Set Up)

The following rules are now active across ALL your projects.

### ~/.claude/settings.json — Hard Denials (Cannot Override)

These commands are **permanently blocked** — I cannot run them even if you ask:

```
rm -rf *          ← recursive force delete
rm -f *           ← force delete any file
git push --force  ← force push (can overwrite teammates' work)
git branch -D     ← hard delete a branch
git reset --hard  ← wipe local changes
git clean -f      ← delete untracked files
DROP TABLE        ← database drops
TRUNCATE          ← database truncate
pkill / kill -9   ← force kill processes
```

### ~/.claude/CLAUDE.md — Behavioural Rules (All Projects)

Before ANY bash command I run, I will:
1. Say what the command is
2. Say WHY I'm running it
3. Say what the expected output is
4. Wait for confirmation if it modifies anything

---

## 8. Using Agents in Planning Phase Right Now

Yes — even in the planning phase, agents are powerful.

**Example: "Pre-flight check before building Phase 1"**

```
You: "Before we plan Phase 1,
      go check what vivareact's ChatWindow expects,
      check hub-insights Cognito pattern,
      and check our DynamoDB design doc.
      Then tell me if the Phase 1 plan is complete."

What happens:
  Agent 1 (Explore) → reads vivareact/src/components/Chat/
  Agent 2 (Explore) → reads hub-insights/app/src/middleware/
  Agent 3 (Explore) → reads docs-internal/AI-CHAT-DYNAMODB-DESIGN.md

  All parallel. All return findings.
  Head Chef: "Here are 3 gaps in the current plan..."
```

**The planning agents don't touch code.**
In `plan` mode (`/plan`), agents can only read — never write.
Perfect for pre-implementation discovery.

---

## 9. The Analogy Extended — Mini Kitchen Inside a Big Kitchen

You said it perfectly:

> "Having a mini kitchen inside a big kitchen,
>  or mini recipe to make inside a big recipe"

Exactly right. Think of it like a **restaurant group**:

```
THE RESTAURANT GROUP
│
├── Main Kitchen (minihubvone) ← Head Chef sits here
│   ├── Recipe Book (CLAUDE.md)
│   ├── Department Manuals (.claude/rules/)
│   └── Chef's Notebook (MEMORY.md)
│
├── Pastry Kitchen (vivareact)
│   └── Recipe Book (CLAUDE.md) ← to create
│
├── Prep Kitchen (hub-insights)
│   └── Recipe Book (CLAUDE.md) ← to create
│
└── Sourcing Kitchen (vivaamplify)
    └── Recipe Book (CLAUDE.md) ← to create
```

When the Head Chef needs pastry, they call the pastry sous chef
who goes to the pastry kitchen, does the work, and brings back the result.

The Head Chef never needs to leave the main kitchen.
They stay focused on the big picture.

**That's exactly how multi-project agents work.**

---

## Quick Reference — Key Commands for Agents

```bash
# Start main session (Head Chef in main kitchen)
cd ~/Desktop/viva/minihubvone && claude

# In conversation, ask me to use agents:
"Read the Cognito auth in hub-insights and summarise the pattern"
"Check all 3 frontend components and tell me what APIs they call"
"Plan the Phase 1 implementation using all 4 repos as context"

# Plan mode (read-only — agents can only look, not touch)
/plan

# See what's in your context window right now
/context

# Start fresh session
/clear
```

---

*This document: `docs-internal/CLAUDE-SESSIONS-AND-AGENTS.md`*
*Related: `docs-internal/CLAUDE-THE-KITCHEN.md`*
