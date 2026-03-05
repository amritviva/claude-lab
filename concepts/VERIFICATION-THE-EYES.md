# Verification Patterns — Giving Claude Eyes

> Claude performs dramatically better when it can check its own work.

## The Analogy

```
WITHOUT eyes:                       WITH eyes:
━━━━━━━━━━━━━                       ━━━━━━━━━━
"Paint my house blue"               "Paint my house blue.
                                     Here's a photo of the house.
*paints something*                   Take a photo when done.
"Wrong blue"                         Compare. Fix differences."
"Missed a wall"
"Trim should be white"              *paints, checks, self-corrects*
= 5 rounds of feedback              = done in 1 round
```

A builder who checks with a level after each wall vs one who eyeballs it.

## The Three Patterns

### Pattern 1: Test Cases (most common)

```
Bad:  "Implement search_member tool"

Good: "Implement search_member tool.
       Test cases:
       - memberId '12345' → returns 1 member with name, email, location
       - memberId 'nonexistent' → returns empty array
       - no location scoping → should fail validation
       Run tests after implementing."
```

Claude writes code + tests. Runs tests. If they fail, it fixes. Self-correcting loop.

### Pattern 2: Root Cause (for bugs)

```
Bad:  "The build is failing"

Good: "The build fails with: [paste exact error]
       Fix the root cause — don't suppress the error.
       Verify the build passes after your fix."
```

Give Claude the exact error + tell it to verify. Prevents it from commenting out failing code.

### Pattern 3: Reference Comparison

```
Bad:  "Add a new handler"

Good: "Add a handler for GET /api/chat/history.
       Follow the exact pattern in payment.handler.ts.
       Compare your output to that file — same structure,
       same error handling, same auth checks."
```

Claude compares its work against a known-good example. Pattern matching > guessing.

## How to Make It Automatic (Not Just Prompting)

There's no setting to toggle. Verification is a prompting strategy. But you can encode it so it's always-on:

```
Three levels of automation:
━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Per-message (manual)
   → You write test cases in your prompt
   → Relies on your discipline to remember

2. CLAUDE.md rules (automatic — every session)
   → "After implementing any tool, write tests"
   → "Never say 'done' without running tests"
   → Claude follows this WITHOUT you asking

3. Skills (on-demand, structured)
   → /pg-query-review — structured checklist against queries
   → /tool-verify — could check chat tools against all rules
   → Verification baked into the recipe
```

### CLAUDE.md Example (always-on verification)

```markdown
## Verification Rules
- After implementing any new tool: write tests for happy path, empty result, invalid input
- After fixing a bug: run the failing test to confirm the fix
- After writing a query: check soft-delete, location scoping, parameterisation, LIMIT
- Never say "done" without running tests
```

### The Key Insight

**The prompt IS the configuration.** Claude has no "verify mode" toggle. Instead:
- Write verification rules in CLAUDE.md → automatic
- Build verification into skills → on-demand
- Add test cases in prompts → per-task

The more you encode into CLAUDE.md and skills, the less you need to type per-message.
