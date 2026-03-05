# Context Management — The Brain Budget

> Claude has a desk, not infinite storage. Everything goes on the desk. Manage it or drown.

## The Analogy

```
Claude has a DESK — not infinite, just really big (1M tokens for Opus).
Everything goes ON the desk:

┌─────────────────────────────────────────────────────┐
│                    CLAUDE'S DESK                     │
│                                                     │
│  📋 CLAUDE.md + rules        (always on desk)       │
│  📋 Auto-memory              (always on desk)       │
│  📋 Skill descriptions       (always on desk)       │
│  📋 MCP tool definitions     (always on desk)       │
│                                                     │
│  📄 Files you asked to read   (piles up)            │
│  📄 Command output            (piles up)            │
│  📄 Conversation history      (piles up)            │
│  📄 Tool call results         (piles up)            │
│                                                     │
│  When desk is FULL → compaction (old stuff summarised) │
│  Summarised = details lost                          │
└─────────────────────────────────────────────────────┘
```

## What Eats Your Budget

### Fixed Costs (every session, can't avoid)

| What | Cost | Analogy |
|------|------|---------|
| CLAUDE.md + rules | ~2-5K tokens | Rent — always due |
| Auto-memory (200 lines) | ~1-2K tokens | Utilities |
| Skill descriptions | ~500 tokens | Cheap — just names |
| MCP tool definitions | ~5-15K tokens | Can be expensive! |

### Variable Costs (grow as you work)

| What | Cost | Notes |
|------|------|-------|
| Reading a file | ~1-10K tokens | Depends on file size |
| Each conversation turn | ~500-2K tokens | Adds up over 50 turns |
| Command output | ~1-5K tokens | Test output can be huge |
| Subagent results | ~1-3K tokens | Summaries come back |

## The Real Killer: Accumulation

```
Turn 1:    Read 3 files                    = 15K tokens
Turn 15:   Debugging, lots of output       = 150K tokens
Turn 30:   Context getting heavy           = 400K tokens ⚠️
Turn 40:   Compaction happens              = summarised to 200K
Turn 45:   "What was the auth flow?"       = Claude forgot details
```

This is why Claude "forgets" mid-session. Not because it's broken — because old turns got compacted into summaries.

## How to Check

```
/context    → visual grid showing desk fullness
/cost       → token counts and money spent
```

## The Five Strategies

### 1. /clear — Wipe the Desk
```
When:  Switching to a completely different task
Why:   Old context wastes space
How:   /clear
```
CLAUDE.md stays (bolted down), everything else goes.

### 2. /compact — Summarise and Continue
```
When:  Mid-task, desk getting full, not done yet
Why:   Compresses old turns, keeps working
How:   /compact
       /compact "focus on auth changes"  (with focus hint)
```
Like summarising meeting notes into bullet points. Lose detail, keep decisions.

### 3. Subagents — Send an Intern to Research
```
When:  Need to explore without filling YOUR desk
Why:   Subagent has its OWN desk, returns summary only
How:   "Use a subagent to investigate how auth middleware works"
```
Intern reads 50 pages, returns 1-page summary. Your desk stays clean.

### 4. Small CLAUDE.md — Keep Rent Low
```
Rule:  Under 200 lines
Why:   Loaded EVERY turn — bloated = expensive
How:   Move details to skills or @imports
```

### 5. /clear Between Unrelated Tasks — THE BIG ONE
```
BAD:  Feature A → debug B → review C (one session, context full of A's files)
GOOD: Feature A → /clear → debug B → /clear → review C (fresh each time)
```
Single highest-impact habit. Most people never /clear and wonder why Claude gets confused.

## Key Insight

Context isn't just "memory" — it's a budget. Every file read, every command run, every turn of conversation SPENDS tokens. Manage the budget or performance degrades.
