# Claude — The Restaurant Kitchen

> A mental model for understanding how Claude Code works, how context is managed,
> and how agents (the kitchen team) collaborate.
> Written for: Amrit Regmi | Last updated: 2026-02-27

---

## The Big Picture

```
┌─────────────────────────────────────────────────────────────────┐
│                    THE RESTAURANT                               │
│                                                                 │
│  DINING ROOM          │  FRONT KITCHEN      │  BACK OF HOUSE   │
│  (Your Terminal)      │  (The Project)      │  (~/.claude/)    │
│                       │                     │                  │
│  You place the order  │  Chefs cook here    │  Staff room,     │
│  You receive the dish │  Tools are here     │  recipe archive, │
│                       │  Ingredients here   │  HR files,       │
│                       │  (your codebase)    │  chef's notebook │
└─────────────────────────────────────────────────────────────────┘
```

You are the **customer and restaurant owner** combined.
You decide what gets cooked. You also wrote the kitchen rules.

---

## The Kitchen Team

### The Head Chef — Claude (Main LLM)

The **Head Chef** is Claude itself — the brain of the operation.

- Reads all the recipe books and rules before service starts
- Receives your order (your prompt)
- Decides HOW to execute it — what tools to use, in what order
- Calls on the kitchen team when needed
- Plates the final dish (your answer)

**Key trait:** The Head Chef does NOT improvise against the rules.
If your `.claude/rules/001-read-only.md` says "never write INSERT statements",
the chef will never do it — it's in the recipe book they read every morning.

---

### The Kitchen Equipment — Tools

The chef can't cook with their hands alone. They use equipment:

| Tool | Kitchen Equivalent | What it does |
|------|--------------------|--------------|
| `Read` | Opening the fridge | Reads a file from your codebase |
| `Edit` / `Write` | Plating / assembling | Modifies or creates a file |
| `Bash` | The stovetop | Runs a shell command (`npm test`, `git log`) |
| `Grep` | The ingredient scanner | Searches file contents by pattern |
| `Glob` | The pantry inventory | Finds files by name pattern |
| `WebFetch` | The delivery order | Fetches content from a URL |
| `Task` | **Calling a Sous Chef** | Spins up a specialist agent (see below) |

Every time the chef uses a tool, you can **see it happen in real time**
in the terminal — like watching the chef work through a glass kitchen.

---

### The Sous Chefs — Agents

This is where it gets powerful.

The Head Chef can **call specialist sous chefs** for specific tasks.
Each sous chef:
- Gets their **own fresh whiteboard** (separate context window)
- Has a **specialisation** (exploring code, planning, research)
- Works **in parallel** with other sous chefs if needed
- Reports back to the Head Chef with results
- Then **disappears** — their whiteboard is wiped

```
HEAD CHEF (you talking to me)
    │
    ├── calls → Explore Sous Chef
    │           "Go read every file in services/ and tell me the patterns"
    │           [works independently, returns summary]
    │
    ├── calls → Plan Sous Chef
    │           "Design the architecture for the chat module"
    │           [works independently, returns plan]
    │
    └── calls → General Purpose Sous Chef
                "Run the tests and report failures"
                [works independently, returns results]
```

#### Available Sous Chefs (Agent Types)

| Sous Chef | Speciality | When Head Chef calls them |
|-----------|-----------|--------------------------|
| `general-purpose` | Anything — multi-step research, code search | Complex investigations, parallel tasks |
| `Explore` | Fast codebase exploration | "Find all files matching this pattern", "How do API routes work here?" |
| `Plan` | Architecture + implementation planning | "Design the approach before we write code" |
| `claude-code-guide` | Expert on Claude Code itself | "How does prompt caching work?" |
| `statusline-setup` | Configuring the status bar | Specific tool config task |

#### Why Sous Chefs Are Powerful

**Problem:** The Head Chef's whiteboard (context window) is big but not infinite.
If a task requires reading 50 files, it fills up the whiteboard.

**Solution:** Send a sous chef.
- Sous chef gets their own **fresh 200K token whiteboard**
- They do the deep work, summarise the key findings
- They report back to Head Chef — just the summary, not all 50 files
- Head Chef's whiteboard stays clean

**Another power:** Parallel cooking.

```
# Without sous chefs (sequential — slow)
Head Chef reads vivareact/ ... done
Head Chef reads hub-insights/ ... done
Head Chef reads vivaamplify/ ... done

# With sous chefs (parallel — fast)
Sous Chef A → reads vivareact/         ↘
Sous Chef B → reads hub-insights/       → all running at the same time
Sous Chef C → reads vivaamplify/       ↗
Head Chef gets 3 reports simultaneously
```

---

## The Kitchen Premises

### The Front Kitchen — Your Project (minihubvone/)

```
minihubvone/
├── CLAUDE.md              ← THE RECIPE BOOK (see below)
├── CLAUDE.local.md        ← Your personal sticky note on the recipe book
├── .claude/
│   ├── settings.json      ← Kitchen operating rules (permissions, hooks)
│   └── rules/             ← DEPARTMENT MANUALS
│       ├── 001-read-only.md        "Never use the gas on the left burner"
│       ├── 002-soft-delete.md      "Always check if ingredient is expired"
│       ├── 003-location-scoping.md "Only cook for your assigned tables"
│       ├── 004-sensitive-data.md   "Never show the full card number"
│       ├── 005-existing-code.md    "Don't touch the other chef's station"
│       ├── 006-patterns.md         "Always plate this way"
│       └── 007-chat-module.md      "Chat feature rules"
├── app/src/               ← The Ingredients (your codebase)
├── docs-internal/         ← The Reference Shelf
└── infra/                 ← The Building Plans
```

**Every morning when you type `claude`:**
The chef walks in, reads ALL the department manuals and recipe book
**before taking a single order**. This is why the rules are always respected.

---

### The Back of House — `~/.claude/` (Home Folder)

This is the **staff room, archives, and chef's personal storage**.
It's NOT inside your project — it's in your home directory.
You won't see it in VS Code unless you navigate there manually.

```
~/.claude/
├── settings.json          ← Global kitchen rules (apply to ALL restaurants)
├── CLAUDE.md              ← Chef's personal preferences (all projects)
├── keybindings.json       ← Custom shortcuts (remapped knife grips)
│
├── projects/
│   └── -Users-amrit-...-minihubvone/
│       └── memory/
│           └── MEMORY.md  ← THE CHEF'S PERSONAL NOTEBOOK ← ← ←
│                             "Last session we were here, open questions are..."
│
└── sessions/
    └── <session-id>.json  ← Full recording of every conversation
                              (not auto-read next session — that's MEMORY.md's job)
```

---

## The Recipe Book — CLAUDE.md

This is the **most important document in the kitchen**.

The chef reads it **every single session** before taking any orders.
It contains:
- What this restaurant is (MiniHub, Express API)
- Who the customers are (Amrit, gym staff, admins)
- What the kitchen can and can't do
- Where other kitchens are (vivareact, hub-insights, vivaamplify)
- The domain model (brands → locations → members → contracts)

**CLAUDE.md is the reason I don't need re-briefing every session.**

---

## The Department Manuals — `.claude/rules/*.md`

Each `.md` file in `.claude/rules/` is a **department manual** for a specific concern.
They are ALL loaded every session. They are cumulative — not one replacing another.

```
Rule 001: "The left stove is read-only — never write to Postgres"
Rule 002: "Always check the expiry sticker — soft delete filters"
Rule 003: "Only serve tables in your section — location scoping"
Rule 004: "Never show the full card number to customers"
Rule 005: "Don't touch another chef's prep station — existing code"
Rule 006: "Follow the house plating style — code patterns"
Rule 007: "The chat module has its own special rules"
```

---

## The Chef's Personal Notebook — MEMORY.md

This is what **I write to myself** between sessions.

```
~/.claude/projects/.../memory/MEMORY.md
```

Think of it as the chef's **end-of-shift notes**:
- "We're building the AI chat feature"
- "We finished user stories today"
- "These 6 questions are still open"
- "Amrit decided X about the DynamoDB design"

**Auto-loaded every session (first 200 lines).**
Without this, every session I arrive with amnesia — I know the rules
but not what WE have been working on together.

---

## The Whiteboard — Context Window

The **context window** is the chef's whiteboard during service.

Everything visible on the whiteboard = everything I can reason about RIGHT NOW.

```
┌──────────────────────────────────────────────────┐
│ WHITEBOARD (200,000 tokens ≈ ~150,000 words)     │
│                                                  │
│ [System Prompt — always here]                    │
│ [CLAUDE.md + all rules — loaded at start]        │
│ [MEMORY.md — loaded at start]                    │
│ [Conversation so far this session]               │
│ [File contents I've read]                        │
│ [Tool outputs I've received]                     │
│ [Your current message]                           │
│                                ← fills up →      │
└──────────────────────────────────────────────────┘
```

**When the whiteboard gets full:**
- Old tool outputs get erased first
- Old conversation turns get summarised
- Recent work and rules are always kept
- You might see a "context compacted" notice

**Why sous chefs help:** They have their OWN whiteboard.
Sending a sous chef to read 50 files doesn't touch the Head Chef's whiteboard.

---

## Does Location Matter? — Which Kitchen You Walk Into

**Yes — completely.**

```bash
# Walk into minihubvone kitchen
cd ~/Desktop/viva/minihubvone && claude
→ Loads minihubvone/CLAUDE.md
→ Loads minihubvone/.claude/rules/ (all 7 files)
→ Loads minihubvone memory (MEMORY.md)
→ Reads git status of minihubvone

# Walk into vivareact kitchen (different restaurant)
cd ~/Desktop/viva/vivareact && claude
→ Loads vivareact/CLAUDE.md (if it exists, otherwise nothing)
→ Loads vivareact/.claude/rules/ (if any)
→ Completely different context — no memory of minihubvone work

# Walk in from home (no restaurant)
cd ~ && claude
→ Only loads ~/.claude/settings.json and ~/.claude/CLAUDE.md
→ No project context at all
→ Chef arrives with no kitchen, no recipe book
```

**Rule of thumb: always `cd` into your project before typing `claude`.**

---

## The Full Order Journey — From Prompt to Answer

```
YOU TYPE: "Why was member 4521 rejected last week?"
                          │
                          ▼
┌─────────────────────────────────────┐
│  1. HOOKS CHECK                     │
│  Any rules before chef sees this?   │
│  (UserPromptSubmit hooks)           │
└─────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────┐
│  2. CONTEXT BUNDLE ASSEMBLED        │
│  System prompt                      │
│  + CLAUDE.md + all rules            │
│  + MEMORY.md (first 200 lines)      │
│  + This session's conversation      │
│  + Your message                     │
│  = Everything on the whiteboard     │
└─────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────┐
│  3. CHEF REASONS (LLM thinking)     │
│  "I need rejection data for 4521.   │
│   I have a tool for that.           │
│   Let me also check payment info."  │
└─────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────┐
│  4. TOOL LOOP (repeats as needed)   │
│                                     │
│  Chef calls tool →                  │
│    Permissions check →              │
│    Tool executes →                  │
│    Result added to whiteboard →     │
│    Chef reasons again →             │
│    Needs more tools? Loop.          │
│    Done? Move on.                   │
└─────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────┐
│  5. FINAL ANSWER DELIVERED          │
│  Plain English. Masked card data.   │
│  No raw SQL. No JSON.               │
└─────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────┐
│  6. SESSION SAVED                   │
│  ~/.claude/sessions/<id>.json       │
│  Full conversation recorded.        │
│  I update MEMORY.md if needed.      │
└─────────────────────────────────────┘
```

---

## The Agents — Real Examples From Your Project

### Scenario A: "Go research how Cognito auth works in hub-insights"

```
Head Chef → calls Explore Sous Chef:
  "Go to ~/Desktop/viva/hub-insights/
   Find the auth middleware.
   Tell me how JWT validation works."

Explore Sous Chef:
  - Finds authorization.ts
  - Reads it
  - Finds related config files
  - Returns: "Here's how it works: ..."

Head Chef:
  - Gets the summary
  - Whiteboard barely used
  - Can now build the same pattern in minihubvone
```

### Scenario B: "Plan the Phase 1 implementation before we write any code"

```
Head Chef → calls Plan Sous Chef:
  "Read the BRD, architecture doc, DynamoDB design,
   and user stories. Design the Phase 1 implementation plan."

Plan Sous Chef:
  - Reads 4 docs in parallel
  - Analyses the architecture
  - Returns: step-by-step plan with file names, dependencies

Head Chef:
  - Reviews plan with you
  - You approve
  - Head Chef implements following the plan
```

### Scenario C: "Build the chat module while checking the React frontend too"

```
Head Chef runs TWO sous chefs IN PARALLEL:

Sous Chef A (background):               Sous Chef B (background):
"Read vivareact ChatWindow              "Read hub-insights auth
 component, understand the              middleware, extract the
 props and API calls needed"            JWT validation pattern"
        ↓                                       ↓
Both return at the same time
        ↓
Head Chef: now has BOTH pieces of context
          and can wire them together correctly
```

---

## The Permissions System — Kitchen Safety Rules

Not everything the chef *can* do, they're *allowed* to do.

```
settings.json controls:
  ✅ Allow: Read any file
  ✅ Allow: Run npm test
  ✅ Allow: Edit files in app/src/
  ❓ Ask me: Push to git
  ❌ Never: Drop database tables
  ❌ Never: Modify infra/ without approval
```

Think of it as the **health & safety board** on the kitchen wall.
The chef reads it and follows it — no argument.

**Three permission modes:**
- `default` — ask before risky actions (git push, deleting files)
- `auto` — trust the chef, run most things automatically
- `plan` — chef can only LOOK (read files, plan), cannot ACT (no edits, no bash)

---

## Hooks — Automated Kitchen Processes

Hooks are **automatic kitchen procedures** that fire at specific moments.

```
Event                  → Hook fires               → What happens
──────────────────────────────────────────────────────────────────
You press Enter        → UserPromptSubmit hook    → Log the question
Before file edit       → PreToolUse (Edit) hook   → Check if file is protected
After file edit        → PostToolUse (Edit) hook  → Auto-run Prettier
Chef finishes          → Stop hook                → Run lint check
Session starts         → SessionStart hook        → Print today's context
```

Our project's hooks are configured in `.claude/settings.json`.

---

## Slash Commands — Talking to the Kitchen Manager

Some things you say to the **kitchen manager** (Claude Code itself),
not to the Head Chef (the LLM). These start with `/`.

| Command | What it does |
|---------|-------------|
| `/clear` | Wipe the whiteboard, start fresh session |
| `/compact` | Summarise old conversation to free whiteboard space |
| `/model opus` | Switch to a more expensive, more capable chef |
| `/plan` | Put kitchen in read-only mode — chef can look but not touch |
| `/memory` | Edit the recipe book (CLAUDE.md) |
| `/cost` | See how much this session cost in tokens |
| `/rewind` | Go back in time — undo recent changes |

These are **not sent to Claude** — the kitchen manager intercepts them directly.

---

## What Makes Me Consistent — The Full Stack

```
Layer 1: ~/.claude/settings.json     ← Global rules, always apply
Layer 2: ~/.claude/CLAUDE.md         ← Your personal chef preferences
Layer 3: minihubvone/CLAUDE.md       ← This project's identity + context
Layer 4: .claude/rules/*.md (x7)     ← Specific department rules
Layer 5: CLAUDE.local.md             ← Your private sticky notes
Layer 6: MEMORY.md                   ← What we built together last session
Layer 7: This conversation           ← What we're doing right now
```

The more complete layers 1–6 are, the more consistent and autonomous I am.
The more you have to tell me in layer 7, the more context is being lost between sessions.

**Goal: everything important lives in layers 1–6 so layer 7 is just "let's continue".**

---

## Quick Reference Card

```
OPEN TERMINAL
    │
    ▼
cd ~/Desktop/viva/minihubvone    ← which kitchen
    │
    ▼
claude                            ← chef arrives
    │
    ├── reads CLAUDE.md           ← recipe book
    ├── reads .claude/rules/      ← department manuals
    ├── reads MEMORY.md           ← last session notes
    │
    ▼
You type your question            ← place the order
    │
    ├── Chef reasons
    ├── Chef calls tools (loop)
    ├── Chef may call sous chefs (agents)
    │
    ▼
Answer delivered                  ← dish served
    │
    ▼
Session saved                     ← shift notes written
```

---

*This document: `docs-internal/CLAUDE-THE-KITCHEN.md`*
*Related: `docs-internal/USER-STORIES.md`, `CLAUDE.md`, `.claude/rules/`*
