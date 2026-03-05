# Plan Mode — The War Room

> Scout the battlefield before sending troops. Measure twice, cut once.

## The Analogy

```
WAR ROOM (Plan Mode)              BATTLEFIELD (Normal Mode)
━━━━━━━━━━━━━━━━━━━━              ━━━━━━━━━━━━━━━━━━━━━━━━
Maps on the wall                  Real combat
Intel reports                     Troops deployed
"What if" scenarios               Bullets fired
Debate strategy                   Things explode
NOTHING gets destroyed            No going back

You LOOK and PLAN here.           You ACT here.
```

## What It Is

Plan Mode restricts Claude to **read-only operations**. Claude can explore files, search code, ask questions, and propose plans — but cannot edit files, write new ones, or run destructive commands.

## Why It Matters

Without Plan Mode (complex task):
```
"Refactor auth" → starts editing → wrong approach → 15 turns wasted → /rewind → start over
```

With Plan Mode:
```
"Refactor auth" → reads everything → proposes 3 options → you pick B → switch to Normal → implements cleanly → done in 5 turns
```

**Plan Mode saves more time than it costs.** It feels slower because you're "not coding yet." But it prevents the 20-turn debugging spiral when Claude guesses wrong.

## How to Enter/Exit

```
Enter Plan Mode:
  1. Start in it:      claude --permission-mode plan
  2. During session:    Shift+Tab → cycle to "Plan"
  3. Command:           /plan

Exit Plan Mode (go to battlefield):
  Shift+Tab → cycle to "Normal" or "Auto-Accept"
```

## The Four-Phase Workflow

```
┌──────────────────────────────────────────────┐
│  PHASE 1: EXPLORE (Plan Mode)                │
│  Read the codebase. Map what exists.         │
│  "Read services/ — how do DB queries work?"  │
│                                              │
├──────────────────────────────────────────────┤
│  PHASE 2: PLAN (Still Plan Mode)             │
│  Propose approaches. Compare tradeoffs.      │
│  "Create a plan for search_member tool."     │
│  Review, adjust, approve the plan.           │
│                                              │
├──────────────────────────────────────────────┤
│  PHASE 3: IMPLEMENT (Switch to Normal Mode)  │
│  Shift+Tab → Normal                          │
│  "Implement the plan."                       │
│  Claude already knows exactly what to do.    │
│                                              │
├──────────────────────────────────────────────┤
│  PHASE 4: VERIFY (Normal Mode)               │
│  "Run tests. Does it work?"                  │
│  Fix issues. Commit.                         │
└──────────────────────────────────────────────┘
```

## When to Use vs Skip

```
USE Plan Mode when:                 SKIP Plan Mode when:
━━━━━━━━━━━━━━━━━━━                 ━━━━━━━━━━━━━━━━━━━━
Not sure how to approach            Can describe the diff in 1 sentence
Multiple files will change          Single file, obvious change
Unfamiliar codebase                 Code you wrote yesterday
Big feature (chat system)           Fix a typo
Want to compare approaches          Only one way to do it
```

## Key Insight

```
Measure twice, cut once.    ← Plan Mode, then Normal Mode
Measure zero, cut five.     ← Normal Mode from the start on complex tasks
```
