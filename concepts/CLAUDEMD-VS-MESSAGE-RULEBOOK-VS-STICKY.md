# CLAUDE.md vs Per-Message — Rulebook vs Sticky Note

> Permanent rules go in CLAUDE.md. One-off instructions go in your message.

## The Analogy

```
RULEBOOK (CLAUDE.md)                    STICKY NOTE (per-message)
━━━━━━━━━━━━━━━━━━━                     ━━━━━━━━━━━━━━━━━━━━━━━━
"Always wash hands"                     "Table 5 wants no onions today"
"Nut allergies = separate prep"         "We're out of salmon, push steak"
"Close kitchen at 10pm"                 "VIP at 7, extra attention"

Permanent. Every shift. Every chef.     Temporary. This shift only.
```

## What Goes Where

### CLAUDE.md (always true, every session)

```
✅ Build/test commands       "npm run build", "npm test"
✅ Code patterns             "async/await, not callbacks"
✅ Safety rules              "Postgres is read-only"
✅ Architecture decisions    "LLM never writes SQL"
✅ Verification rules        "Always run tests"
✅ Workflow patterns          "Interview → Trace → Plan → Build → Verify"
✅ Environment quirks         "DynamoDB=camelCase, Postgres=snake_case"
```

### Your Message (specific to this task)

```
✅ Task context              "Working on search_member tool"
✅ Temporary overrides       "Skip tests, just prototype"
✅ One-off preferences       "Use verbose logging"
✅ Scope limits              "Only change files in services/chat/"
✅ Clarifications            "'member' = gym member not staff"
```

## The Golden Rule

```
Every session    → CLAUDE.md
This session     → your message
Sometimes        → skill (load on demand)
```

## Context Cost Rule

CLAUDE.md is always on the desk (fixed cost per turn). Keep it under 200 lines.

Move detailed stuff to:
- `.claude/rules/` — per-project rules (loaded automatically)
- Skills — loaded on demand when invoked
- `@imports` — loaded when referenced
- `docs-internal/` — read when needed (not automatic)
