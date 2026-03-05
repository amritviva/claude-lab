# Session Bridges — The Handoff Problem

> Every new session starts with an empty desk. How do you carry context forward without wasting half the session re-explaining?

## The Problem

```
Session 1: Build search_member tool. 40 turns of context. Session ends.
Session 2: Empty desk. "Continue building chat tools."
           Claude: "What chat tools? What decisions?"
           10 turns just catching up = desk already 30% full
```

CLAUDE.md and auto-memory help, but they carry WHO you are and HOW to work — not WHERE you left off on a specific task.

## The Solutions

### 1. Handoff Docs — Session Bridges (simplest)

Before ending a session, write a handoff doc:

```
"Write docs-internal/HANDOFF-CHAT.md capturing:
 - What we built this session
 - Decisions made
 - What's left
 - Current state of each file"
```

Next session:
```
"Read docs-internal/HANDOFF-CHAT.md and continue"
```

One file, ~2K tokens, full context. Much cheaper than 10 turns of re-explaining.

### 2. Per-Topic Agents — Domain Experts

Create agents scoped to specific work domains:

```
~/.claude/agents/
├── chat-builder.md        ← chat system context
├── cron-debugger.md       ← cron job context
├── security-reviewer.md   ← security review context
```

Each agent file contains persistent domain context:

```markdown
# chat-builder.md
---
name: chat-builder
description: Build AI chat tools for minihub
tools: Read, Edit, Write, Bash, Glob, Grep
model: opus
---

You are building the AI chat system for minihubvone.

## Current State
- search_member: ✅ DONE
- get_transactions: 🔄 IN PROGRESS
- get_contract: ⬜ NOT STARTED

## Key Decisions
- Tool Use pattern (LLM never writes SQL)
- Soft-delete + location scoping on every query
- Chat history in DynamoDB

## Reference Files
- Architecture: docs-internal/AI-CHAT-ARCHITECTURE.md
- Handler pattern: handlers/payment.handler.ts
```

Invoke with:
```bash
claude "continue building chat tools" --agent chat-builder
```

Update the agent file at the end of each session.

### 3. Persistent Task Lists

```bash
CLAUDE_CODE_TASK_LIST_ID=chat-system claude
```

Task list survives across sessions. Claude sees what's done and what's left.

### 4. The Power Combo (all three together)

```
Per-topic agent   → knows the domain, decisions, patterns (WHO)
Handoff doc       → captures where you stopped (WHERE)
Task list         → tracks progress (WHAT'S LEFT)

New session = structured context loaded in 3K tokens
            vs rebuilt through 10 turns = 30K tokens wasted
```

## The Analogy

```
Without bridges:
  Every day you walk into the office, your desk is wiped clean.
  You spend the first hour finding your files and remembering
  what you were doing yesterday.

With bridges:
  You left a sticky note on your desk: "Working on X.
  Files are here. Next step is Y. Decision log in folder Z."
  You sit down and start working in 2 minutes.
```

## When to Use Which

| Scenario | Solution |
|----------|----------|
| Quick continuation next session | Handoff doc |
| Long-running project (weeks) | Per-topic agent + handoff |
| Tracking multi-step task | Task list |
| Multiple parallel workstreams | Per-topic agents (one per stream) |

## Session End Habit

Before ending any work session, say:
```
"Update the handoff doc with what we did and what's next"
```

This takes 30 seconds and saves 10 minutes next session.
