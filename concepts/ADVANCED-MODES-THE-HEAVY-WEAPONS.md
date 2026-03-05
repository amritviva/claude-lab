# Advanced Modes — The Heavy Weapons

> Batch, worktree, background tasks, task system. Claude Code's power tools for scale.

## 1. Batch Mode — The Assembly Line

### Analogy
```
Repaint 20 rooms in a building.
Without batch: 1 painter, 1 room at a time = 40 hours
With batch:    20 painters, 1 each, simultaneous = 2 hours
Each painter opens a PR when done.
```

### How It Works
```
/batch Add soft-delete filters to all 15 query files

Step 1: RESEARCH   — Claude reads codebase, finds all targets
Step 2: DECOMPOSE  — splits into 5-30 independent work units
Step 3: APPROVE    — shows plan, you approve or adjust
Step 4: SPAWN      — one agent per unit, each in its own worktree/branch
Step 5: PRs        — each agent opens a PR when done
```

### When to Use
```
USE when:                          SKIP when:
Same change across 5+ files        Changing 1-3 files
Files are independent               Changes depend on each other
Pattern is repeatable               Each change is unique/complex
Migration or bulk refactor           New feature design
```

### Minihub Examples
```
/batch Add soft-delete filters to all query files in queries/
/batch Add location scoping to all 12 service functions
/batch Add input validation to all handler files
```

---

## 2. Worktree Mode — Parallel Desks

### Analogy
```
You have ONE desk working on Feature A.
Boss says "fix Bug B."

Without worktree: shove A aside, context mixed up
With worktree:    walk to SECOND desk, fix B, walk back. A is untouched.
```

### How to Use
```bash
claude --worktree feature-chat
```
Creates `.claude/worktrees/feature-chat/` — isolated checkout, own branch, own session.
Main working directory untouched.

### When to Use
```
USE when:                          SKIP when:
2+ features in parallel             Just one thing at a time
Need branch isolation                Quick fix on current branch
/batch uses these automatically     Single-file change
Want to experiment without risk
```

---

## 3. Background Tasks — The Oven Timer

### Analogy
```
Cooking dinner. Oven timer running.
You don't watch the oven — you do other things.
Timer beeps when done.
```

### How to Use
```
You:    "Run all the tests"
        *tests start...*
        *press Ctrl+B*
        *prompt returns, you keep working*

System: "Background task completed: all tests passed ✅"
```

### When to Use
```
Long-running: npm test, npm run build, docker build
Parallel:     Run tests while reviewing code
Waiting:      Deployment running while you do other work
```

---

## 4. Task System — The IKEA Checklist

### Analogy
```
IKEA furniture, 15 steps in the booklet.
Check off each step as you go.
That's the task system.
```

### How to Use
Claude auto-creates tasks for multi-step work. View with `Ctrl+T`.

```
"Build chat endpoint:
 1. Create cognito auth middleware
 2. Create message handler
 3. Create chat service
 4. Write LLM integration
 5. Add tests"
```

### Persistent Across Sessions
```bash
CLAUDE_CODE_TASK_LIST_ID=chat-system claude
```
Same ID next session = picks up where you left off.
Combines with handoff docs for full session continuity.

---

## How They Connect

```
Task System:      WHAT to build (checklist)
Batch Mode:       Build MANY things at once (parallel agents)
Worktree:         Build in ISOLATION (parallel branches)
Background:       Build while WAITING (multitask)

Together:
  Task list tracks 15 items.
  /batch spawns agents for 10 independent ones.
  Each agent works in a worktree.
  You Ctrl+B the batch and keep working on item 11 manually.
```
