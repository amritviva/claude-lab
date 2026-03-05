# Deep Dive: How LLM Agents Actually Work — Level by Level

> This document is a living learning journal. Each level builds on the previous one.
> Started: 2 March 2026
> Last updated: 2 March 2026

---

## The Setup

Amrit has 4 repos that need to work together for an AI chat feature:
- `vivareact` — React frontend (The Hub staff portal)
- `minihubvone` — Express/TypeScript backend (AI chat API)
- `hub-insights` — Reporting REST API (auth middleware reference)
- `vivaamplify` — AppSync/GraphQL backend (Cognito auth source of truth)

Before writing any code, we're understanding how LLM agents think, remember, and coordinate — so we can build the system properly from the ground up.

---

## Level 1 — The Empty Desk (Dump Everything in Context)

### Status: DONE

### The Analogy

A brand new contractor walks into an empty office every morning with amnesia. You hand them your entire company's documentation — 500 pages — and say "build me a chat feature." Their desk holds 200 pages. Papers fall off. They can't tell what's important vs noise.

### What's Actually Happening

When you send a message to Claude, everything gets packed into a **context window**:

```
┌─────────────────────────────────────────┐
│           CONTEXT WINDOW (the desk)     │
│                                         │
│  System prompt (instructions)    ~2K tk │
│  CLAUDE.md files (project context) ~10K │
│  Conversation history        (growing)  │
│  Tool results (file reads)   (growing)  │
│  Your latest message                    │
│                                         │
│  Total capacity: ~200K-1M tokens        │
│  1 token ≈ ¾ of a word                  │
└─────────────────────────────────────────┘
```

The LLM has **no hard drive, no memory, no brain between sessions**. Everything it knows comes from what's physically on the desk right now. New chat = empty desk = amnesia.

### Why Level 1 Fails

4 repos × thousands of lines = blows through the context window. The desk is finite. Dumping everything wastes space on irrelevant info and pushes important stuff off the edge.

### Key Insight

The fundamental constraint: **finite desk, no persistent memory, everything loaded at once.**

---

## Level 2 — The Filing Cabinet (Manual Modular Loading)

### Status: DONE

### The Analogy

Instead of dumping 500 pages, you buy a filing cabinet with labelled drawers: FRONTEND, BACKEND, AUTH, REPORTS. When someone says "fix the chat UI", the contractor opens only the FRONTEND drawer. 450 pages stay filed away.

### What This Looks Like in Practice

| File | What it holds | Analogy |
|------|--------------|---------|
| `~/.claude/CLAUDE.md` | Global rules, all 4 repo paths | Office directory — taped to the wall, always visible |
| `vivareact/CLAUDE.md` | Auth flow, components, ChatWindow plan | "Frontend" drawer |
| `minihubvone/CLAUDE.md` | API architecture, tools, knowledge base | "Backend" drawer |
| `hub-insights/CLAUDE.md` | Auth middleware, Prisma, routes | "Reports/Auth Reference" drawer |
| `vivaamplify/CLAUDE.md` | Cognito config, DynamoDB schema | "Auth Source of Truth" drawer |

### How Claude Code Loads These

Claude Code auto-loads exactly 2 files per session:
1. `~/.claude/CLAUDE.md` — always, every session, every repo
2. `<current-repo>/CLAUDE.md` — the project file for whichever repo you're in

```
Session in vivareact:   global + vivareact/CLAUDE.md
Session in minihubvone: global + minihubvone/CLAUDE.md
They don't share a desk. Different offices.
```

To know what's in another repo, the agent must physically go read those files with tools — like walking to a different room's cabinet.

### The Limitation

**You are the filing clerk.** You decide what goes where. When the API contract changes in minihubvone, you have to manually update vivareact's CLAUDE.md. Nothing syncs itself.

### Key Insight

Organized, modular context. Way better than Level 1. But manual maintenance — **you** are the brain that keeps the drawers up to date.

---

## Level 3 — The Smart Secretary (Keyword Routing)

### Status: DONE

### The Analogy

You hire a secretary who sits between you and the contractor. You say "fix the payment flow in the chat." She hears those words, reasons about them, and pulls the right drawers without you telling her which ones.

### What's Actually Happening — Claude Code's Tool System

When you type a prompt, the LLM itself acts as the router:

```
You: "wire up ChatWindow to call the minihub API"

Step 1: Read CLAUDE.md files (auto-loaded — Level 2)
Step 2: LLM DECIDES which tools to use based on your words
        "ChatWindow" → Glob for ChatWindow.jsx
        "minihub API" → read the API route in minihubvone
        "wire up" → read apiConfig.js to match the pattern
Step 3: Call tools, results land on the desk
Step 4: Write code based on everything on the desk
```

This is smarter than keyword matching — the LLM understands meaning. "Make the bot respond to staff questions" still routes to ChatWindow and minihub, even though neither word was said.

### The Limitation

The secretary can only route to things she **already knows exist** (from CLAUDE.md or previous tool results). Each file read eats desk space. Chains of discovery (file A references file B which references file C) fill the desk unpredictably. **Routing is reactive, not predictive.**

### Where Amrit Is Now

Between Level 2 and 3. CLAUDE.md files provide the filing system (Level 2). Claude Code's tool system provides the smart routing (Level 3). The CLAUDE.md files pre-load cross-repo knowledge to reduce cross-office trips.

### Key Insight

The LLM itself is the router. But it can't anticipate chains of dependencies it hasn't seen yet. It discovers the path as it walks it.

---

## Level 4 — The Human Brain (Memory Layers)

### Status: DONE

### The Analogy

Your brain runs three memory systems simultaneously:
1. **Always know** — your name, your job, your stack. Instant. Always there.
2. **Remember from experience** — "last Tuesday the auth refactor broke sidebar for 2 hours." Tagged by time/context. Floods back when triggered.
3. **Holding right now** — this conversation, the code on screen. Gone in 3 weeks unless encoded deeper.

LLMs at Level 1-3 only have type 3 (working memory). Level 4 gives them all three.

### The Three Memory Tiers

```
┌──────────────────────────────────────────────────────────┐
│  CORE MEMORY (Identity) — always loaded, rarely changes  │
│  ~500 tokens. "4 repos. React frontend. Cognito auth."   │
│  Your: ~/.claude/CLAUDE.md                                │
├──────────────────────────────────────────────────────────┤
│  EPISODIC MEMORY (Past sessions) — loaded selectively    │
│  ~200-500 tokens per episode. Summaries, not full logs.  │
│  "2 Mar: Explored agent levels 1-4. No code written."   │
│  Your: NOTHING EXISTS HERE YET. This is the gap.         │
├──────────────────────────────────────────────────────────┤
│  WORKING MEMORY (Right now) — the context window         │
│  This conversation. Files just read. Current task.       │
│  Your: automatic — it's just the current chat            │
└──────────────────────────────────────────────────────────┘
```

### The Gap in Amrit's Setup

Core (CLAUDE.md) = solid. Working (context window) = automatic. **Episodic = missing.** Every new session starts with amnesia about past sessions. The contractor remembers the office layout but has zero memory of what happened yesterday.

### The MemGPT / Letta Connection

MemGPT (now Letta) gives LLMs explicit tools to self-manage memory:
- `core_memory_update()` — update identity facts
- `episodic_memory_search()` — "when did we change the auth flow?"
- `archival_memory_insert()` — save detailed logs for later
- `archival_memory_search()` — retrieve old context by meaning

The LLM decides when to save and search — like how your brain decides what's worth remembering.

### Why This Matters for ATLAS

The "Shared Memory Layer" in the ATLAS multi-agent vision IS Level 4:
- Core section each agent reads (what's the project)
- Episodic section (what happened across all agents in past sessions)
- Working memory per agent (each agent's current conversation)

### Key Insight

The missing layer is **episodic memory**. Core tells the agent what the project IS. Working memory is the current moment. Nothing bridges sessions together. Level 4 fills that gap and is the foundation for everything above.

---

## Level 5 — The Library with a Search Engine (Semantic Search)

### Status: DONE

### The Analogy

The secretary (Level 3) only finds files she's been told about. Now replace her with a **librarian** who has read every file in every repo. She writes a summary card for each — not in English, but as a list of 384 numbers (a "vector embedding") that captures meaning in mathematical space.

When you ask "find me the code that handles expired memberships", she doesn't search for the word "expired." She converts your question into numbers, then finds the files whose numbers are closest. Files with related *meaning* surface — even if they share zero keywords with your question.

### How It Works

```
INDEXING (done once, updated on changes):
  All code files → Embedding Model → Vector Database (pgvector/Pinecone/ChromaDB)

QUERYING (every prompt):
  Your prompt → Same Embedding Model → Vector DB finds nearest matches → Returns files
```

The embedding model is NOT the LLM. It's small, fast, cheap. Its only job: text → numbers.

### Level 3 vs Level 5

| | Level 3 (Secretary) | Level 5 (Librarian) |
|---|---|---|
| Finds files by | LLM reasoning + known paths | Mathematical similarity of meaning |
| Knows about | Only what's in CLAUDE.md | Every file in all repos (pre-indexed) |
| Cross-repo | Must manually read other repos | All repos in same database |
| Cost per search | Expensive (LLM call) | Cheap (vector math, milliseconds) |

### What This Means for ATLAS

ATLAS queries vector DB across all 4 repos simultaneously. One question → relevant files from vivareact, minihubvone, hub-insights, vivaamplify — ranked by meaning, not by filename.

### Key Insight

Replaces "what files do I know about?" with "what files are related to this meaning?" The cost is infrastructure — embedding model, vector DB, indexing pipeline.

---

## Level 6 — The War Room (Agentic Task Decomposition)

### Status: DONE

### The Analogy

Stop using one contractor. Build a team. A General (Planner) reads your request, decomposes it into subtasks, assigns specialists, and assembles the result. Each specialist has their own clean desk with only relevant files.

### Why It's Better

One agent doing everything = cluttered desk, spread attention, 51K+ tokens used.
Three specialists = 10-14K each, 100% focused on their layer. Cleaner desks = better output.

### How Claude Code Already Does This

The Agent tool spawns sub-agents with fresh context windows. Sub-agent does all the searching, fills its own desk, sends back a summary. The summary lands on the main agent's desk (~500 tokens instead of 30K). Sub-agent's full desk is thrown away.

### The Hard Part — Orchestration

The General must: decompose tasks, scope context per agent, coordinate dependencies, establish shared contracts, assemble results, and validate the whole.

**#1 failure mode**: agents making different assumptions in isolation (e.g., one calls it `session_id`, another calls it `sessionId`). Solution: General defines the API contract FIRST, gives it to all agents.

### Maps to ATLAS

```
ATLAS (General) → decomposes → establishes contracts
  NOVA (vivareact agent)     — own desk, UI focus
  FORGE (minihubvone agent)  — own desk, API focus
  ECHO (hub-insights agent)  — own desk, data focus
ATLAS assembles and validates
```

### Key Insight

Multi-agent = cleaner desks, not more brains. The hard part is the General's coordination, not the soldiers' capability.

---

## Level 7 — The Self-Running Office (Persistent External Memory)

### Status: DONE

### The Analogy

Hire a night crew. When everyone leaves, the Journalist summarizes what happened, the Archivist files it in a searchable database (tagged by date/feature/repo), and the Briefing Officer puts relevant past summaries on each desk before the next session starts. Nobody asked them. It's automatic.

### Level 4 vs Level 7

| | Level 4 (Manual) | Level 7 (Auto) |
|---|---|---|
| Who writes summary? | You ask Claude | Automatic on session end |
| Where stored? | Markdown file you remember to load | Vector DB, searchable by meaning |
| Who loads next session? | You paste or reference it | Auto-queried based on new prompt |
| Cross-agent? | Each agent's own notes | Shared DB — NOVA reads what FORGE did |

### Tech Stack Needed

- **Summarizer**: Cheap LLM (Haiku) reads transcript → structured JSON
- **Embedding Model**: Converts summaries to vectors (OpenAI embed-3 or Cohere)
- **Vector Database**: pgvector in Supabase (already know Postgres)
- **Session Hook**: Triggers summary on session end (Claude Code hooks or git hook)
- **Context Loader**: Queries DB on session start, injects relevant summaries

### The 80% Shortcut (Level 4.5)

No infrastructure needed:
1. Claude Code hook on session end → writes `session-log-YYYY-MM-DD.md`
2. CLAUDE.md instruction: "read last 3 session logs on startup"
3. Just markdown files + Read tool. Gets most of the benefit.

### Key Insight

Level 7 = Level 4 (episodic) + Level 5 (semantic search) + automation. The system writes its own memories, stores them searchably, loads by relevance. No human in the loop.

---

## Level 8 — The Living Blueprint (Codebase as Knowledge Graph)

### Status: DONE

### The Analogy

Your codebase isn't a pile of files. It's a city. A knowledge graph maps every node (component, function, route, DB table) and every edge (imports, calls, queries, authenticates). Touch one node → traverse edges → see the full blast radius across all repos.

### Why a Graph Beats File Search

Level 5 finds files *about* your topic. Level 8 finds files *connected* to your target. The difference:
- Vector search: "location permissions" → finds files that mention it
- Graph traversal: touch `locationAccess` → follows 3 hops → finds cognito-auth.ts in minihubvone, group_staff table in Postgres, Sidebar/Dashboard/MemberList in vivareact — even if they never use the word "permission"

### How It's Built

Two approaches combined:
1. **Static analysis** — parse ASTs, import trees. Fast, precise, catches explicit code structure.
2. **LLM-assisted** — feed each file to small LLM to identify implicit relationships. Catches semantic connections.

Store in graph database (Neo4j) or relational tables in Postgres.

### The Killer Feature

**Blast radius analysis.** "What would break if I change X?" → traversal returns every affected file across all repos, ordered by dependency depth. ATLAS can then assign each subgraph slice to the right agent.

### Where This Exists

CodeGraph (Microsoft Research), Sourcegraph, IntelliJ's "find usages", Nx monorepo project graph. None fully integrated with LLM agents yet — bleeding edge.

### Key Insight

Files are flat. Code is a graph. Level 8 replaces "find relevant files" with "traverse the dependency map." Static analysis + LLM = the way to build it.

---

## Level 9 — The Clone (Model Fine-Tuned on Your Codebase)

### Status: DONE (Skipped for implementation — not ideal for small teams)

### The Analogy

Instead of giving a contractor your project docs, you clone yourself. Fine-tuning bakes your code patterns, naming conventions, and domain language into the model's weights. It doesn't need CLAUDE.md to know you use `useAuthContext()` — it just *knows*.

### Why It's Not For Us

- Frozen at training time — can't see current code state
- Overkill for 4 repos / small team
- CLAUDE.md + Levels 2-7 give 90% of the benefit at zero cost
- Makes sense at scale: 100K+ lines, 10+ devs, sub-second response needs

### Key Insight

Fine-tuning = instincts, not knowledge. Good for massive teams. For small teams, context loading wins.

---

## Level 10 — The Immortal Colleague (Continuous Learning Agent)

### Status: DONE

### The Analogy

Not a contractor. A permanent team member who never sleeps. Watches every git commit, PR, deploy, error log. Doesn't wait for you to ask — speaks up proactively. "You're about to break something." "You tried this before and it failed." "Your repos are out of sync."

### Level 7 vs Level 10

| | Level 7 (Self-Running Office) | Level 10 (Immortal Colleague) |
|---|---|---|
| Active when | During sessions | Always — 24/7 |
| Triggered by | You opening a terminal | Git pushes, deploys, errors, cron |
| Direction | You ask → it answers | It tells you → you decide |
| Mode | Reactive | Proactive |

### Three Superpowers

1. **Regression Detection** — PR merged → agent queries knowledge graph → finds downstream breakage → alerts you before deploy
2. **Pattern Memory** — "You tried caching member lookups in June 2025. It was rolled back because cache invalidation on location changes wasn't wired up. Same risk applies here."
3. **Drift Detection** — nightly cron compares schemas across repos, flags mismatches (e.g., vivaamplify added a field that minihubvone's sync doesn't copy)

### Architecture

```
Event Watchers (git hooks, CI/CD, CloudWatch, cron)
  → Event Processor (Lambda / App Runner)
    → Knowledge Brain (Graph L8 + Vectors L5 + Episodes L7)
      → Reasoning Core (LLM): "is this worth telling Amrit?"
        → Action Engine (Slack, GitHub Issue, PR, fix code)
```

### What's Buildable Now

- GitHub Action on PR merge → Claude API → post Slack message (exists today)
- Nightly cron for schema drift checking (buildable)
- Session summary hooks (Level 7 foundation — buildable)

### What Doesn't Exist Yet

- Full cross-repo continuous learning — research stage
- Self-updating CLAUDE.md — would build custom
- "You tried this before" with full history correlation — would build on Level 7

### Key Insight

Level 10 combines ALL previous levels into an always-on agent. It doesn't fully exist as a product yet, but pieces are buildable today. It's the north star, not the starting point.

---

## The Full Stack — All 10 Levels

```
Level 10: Continuous Learning Agent     ← watches live, proactive
Level 9:  Fine-Tuned Model             ← skip for now (not for small teams)
Level 8:  Knowledge Graph              ← AMRIT'S TARGET — blast radius
Level 7:  Persistent Auto-Memory       ← night crew, session summaries
Level 6:  Multi-Agent War Room         ← ATLAS / NOVA / FORGE / ECHO
Level 5:  Semantic Vector Search       ← find by meaning
Level 4:  Memory Tiers                 ← core / episodic / working
Level 3:  Smart Routing (LLM tools)    ← CURRENT (Claude Code tool system)
Level 2:  Manual Modular (CLAUDE.md)   ← CURRENT (your files)
Level 1:  Dump Everything              ← where you started
```

### Practical Roadmap (Suggested Build Order)

1. **Level 4.5** — Session log markdown files + CLAUDE.md instruction to read them (this week)
2. **Level 7** — Auto-summarizer hook + vector storage in Supabase (next)
3. **Level 6** — Formalize ATLAS orchestration with Claude Code agents (parallel with 7)
4. **Level 5** — Embed all repos into pgvector for semantic search (feeds into 8)
5. **Level 8** — Build knowledge graph from AST parsing + LLM (the target)
6. **Level 10** — Wire up GitHub webhooks + cron for proactive monitoring (aspirational)

---

## Session Log

| Date | What We Covered | Key Insight |
|------|----------------|-------------|
| 2 Mar 2026 | All 10 levels completed | Level 8 (Knowledge Graph) is the target. Build order: 4.5 → 7 → 6 → 5 → 8 → 10. Skip Level 9. |
