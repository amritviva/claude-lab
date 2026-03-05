# Prompting Strategies for Claude Code — Reference Guide

> How to get the best results: plan mode, batch mode, verification patterns, context management, and the PowerPoint trace technique.

## Mental Model: Directing a Movie

Prompting Claude Code is like **directing a movie**:

- **Bad director:** "Make a good scene." (vague, no verification criteria)
- **Good director:** "Scene 3: John enters from the left, picks up the phone, delivers line X. We'll know it's right when the audience laughs." (specific, verifiable)

The better your direction, the fewer re-takes you need.

---

## Plan Mode

### What Is It?

Plan Mode restricts Claude to **read-only operations**. Claude can explore, ask questions, and create plans — but can't edit files or run destructive commands.

Think of it as **scouting the battlefield before sending troops.**

### When to Use

- Complex multi-file refactors
- Unfamiliar codebase exploration
- Evaluating different approaches before committing
- Tasks with uncertainty about the best path

### When to Skip

- Single-line fixes (typos, renames)
- You can describe the entire diff in one sentence
- You're confident about the approach

### How to Use

```bash
# Start in plan mode
claude --permission-mode plan

# Switch during session
# Press Shift+Tab to cycle: Normal → Auto-Accept → Plan → ...

# Enter plan mode via command
/plan
```

### Typical Workflow

```
Phase 1: Explore (Plan Mode)
> Read src/auth/ and explain the current session flow.

Phase 2: Plan (Plan Mode)
> Create a detailed plan for adding Google OAuth.
> What files change? What's the new flow?
# Press Ctrl+G to edit the plan in your editor

Phase 3: Implement (Switch to Normal Mode — Shift+Tab)
> Implement the OAuth flow from your plan.
> Write tests first, then code. Run tests to verify.

Phase 4: Commit (Normal Mode)
> Commit with a descriptive message and open a PR.
```

---

## Batch Mode (`/batch`)

### What It Does

`/batch` orchestrates **large-scale parallel changes** across your codebase:

1. Claude researches the codebase
2. Decomposes work into 5–30 independent units
3. Presents a plan for your approval
4. Spawns one agent per unit in isolated git worktrees
5. Each agent implements its unit and opens a PR

### When to Use

- Large migrations (React 17 → 18 across 100 files)
- Bulk refactors (callback-based → async/await across all services)
- Systematic improvements (add JSDoc to all public functions)
- Adding a requirement to all endpoints

### Examples

```
/batch Migrate all API endpoints from callback-based to async/await
/batch Add TypeScript strict mode to all 45 service files
/batch Add missing soft-delete filters to all Postgres queries
```

---

## The #1 Best Practice: Give Claude a Way to Verify

Claude performs dramatically better when it can **check its own work**.

### Pattern: Test Cases

```
Bad:  "implement email validation"
Good: "implement validateEmail. Test: user@example.com → true,
       invalid → false, user@.com → false. Run tests after."
```

### Pattern: Visual Verification

```
[paste screenshot]
> Implement this design. Take a screenshot of the result,
> compare to the original. List differences and fix them.
```

### Pattern: Root Cause

```
Bad:  "the build is failing"
Good: "the build fails with [paste error]. Fix it and verify
       the build succeeds. Address the root cause, don't suppress."
```

---

## Effective Prompting Patterns

### Be Specific Upfront

```
Bad:  "add tests for foo.py"
Good: "write a test for foo.py covering the edge case where
       the user is logged out. Avoid mocks."
```

### Reference Existing Patterns

```
> Look at how existing handlers are structured in
> src/routes/api/handlers/payment.handler.ts.
> Follow the same pattern for the new endpoint.
```

### Scope the Location

```
Bad:  "why does ExecutionFactory have a weird API?"
Good: "look through ExecutionFactory's git history and
       summarize how its API came to be"
```

### Describe the Symptom

```
Bad:  "fix the login bug"
Good: "users report login fails after session timeout.
       Check auth flow in src/auth/, especially token refresh.
       Write a failing test first, then fix."
```

---

## The PowerPoint Trace

A step-by-step visualization of how a request flows through your system.

### How to Use

```
> Walk me through a request as if presenting slides.
> Trace what happens when a user makes a payment.
>
> Start: user clicks "Pay Now" in vivareact
> End: transaction recorded in DynamoDB and Postgres
>
> For each step:
> - Where the code is (file path)
> - What it does
> - What data passes to the next step
```

### Example Output

```
Slide 1: User clicks "Pay Now" in checkout
- File: vivareact/src/components/checkout/Checkout.jsx
- Calls minihubvone API

Slide 2: Frontend calls POST /api/payment
- File: minihubvone/app/src/routes/api/handlers/payment.handler.ts
- Validates JWT, checks location scoping

Slide 3: Handler calls PaymentService
- File: minihubvone/app/src/services/payment-service.ts
- Runs pre-written SQL against Postgres
...
```

### Why It's Useful

- Exposes hidden assumptions and missing steps
- Reveals bugs in logic flow
- Great for onboarding new developers
- Preparation before complex changes

---

## Context Management

### The Problem

Claude's context window is finite. Everything — conversation, files read, command output — consumes tokens. Performance degrades as context fills.

### Track Usage

```
/context    # Visualize context as a coloured grid
/cost       # Show token usage statistics
```

### Strategies

| Strategy | How | When |
|----------|-----|------|
| `/clear` between tasks | Resets conversation | When switching to unrelated work |
| `/compact` with focus | Summarizes conversation | When context is getting full mid-task |
| Subagents for investigation | Explores in isolated context | When research would bloat main context |
| Small CLAUDE.md | Keep under 200 lines | Always |
| Skills over CLAUDE.md | Load on demand | For infrequent workflows |

### What Uses Context

| Content | Cost | When Loaded |
|---------|------|------------|
| CLAUDE.md + rules | High | Every session |
| Auto memory | Medium (200 lines) | Every session |
| Skill descriptions | Low | Every session |
| MCP tool definitions | High (can hit 10%) | Every session |
| File contents (Read) | High | When files are read |
| Command output | Medium | Accumulates |
| Conversation history | Medium | Compacted when full |

---

## The "Interview" Pattern

For large features, have Claude interview you before building:

```
> I want to build [brief description]. Interview me in detail.
>
> Ask about implementation, UI/UX, edge cases, and tradeoffs.
> Don't ask obvious questions — dig into the hard parts.
>
> Keep interviewing until we've covered everything,
> then write a complete spec to SPEC.md.
```

---

## The "Test-First" Pattern

```
> For the batch payment processor:
>
> 1. Write comprehensive tests FIRST covering:
>    - Normal: 10 payments, all succeed
>    - Partial: 3 of 10 fail, others succeed
>    - All fail: network error, max retries
>    - Edge: duplicate payment, zero amount
>
> 2. Run tests (they'll fail)
> 3. Implement the feature
> 4. Run tests (they should pass)
```

---

## The "Investigate with Subagents" Pattern

Keep your main context clean by delegating exploration:

```
> Use subagents to investigate:
> - How our auth handles token refresh
> - Whether we have existing OAuth utilities
> - Where sessions are stored
>
> Report back your findings.
```

Subagents explore in separate context windows, return summaries.

---

## Rewind for Course Correction

If Claude goes down the wrong path, press `Esc + Esc` (or `/rewind`):

Options:
- Restore conversation only (undo changes, keep history)
- Restore code only (undo changes, keep conversation)
- Restore both (go back to a previous point)
- Summarize from here (compact forward)

Much faster than manually undoing.

---

## Task System

Claude creates task lists for tracking multi-step work:

```
> Build a payment system:
> 1. Validate card input
> 2. Create transaction in DynamoDB
> 3. Call payment processor API
> 4. Send confirmation email
```

Claude creates tasks and tracks progress. View with `Ctrl+T`.

Share task list across sessions:
```bash
CLAUDE_CODE_TASK_LIST_ID=my-project claude
```

---

## Worktree Mode

Run isolated Claude Code sessions on separate branches:

```bash
claude --worktree feature-auth
```

Creates `.claude/worktrees/feature-auth/` with its own branch. Auto-deleted if no changes made.

Use for:
- Parallel work on independent features
- Isolation to prevent branch conflicts
- `/batch` uses worktrees automatically

---

## CLAUDE.md vs Per-Message Instructions

### Put in CLAUDE.md (persistent, every session)

- Build commands Claude can't guess
- Code style rules that differ from defaults
- Testing instructions
- Architecture decisions
- Environment quirks
- Common gotchas

### Put in your prompt (one-off)

- Task-specific context
- Temporary overrides of rules
- Clarifications about a specific request
- One-off preferences

### Size Rule

Keep CLAUDE.md under **200 lines**. Move detailed content to:
- `@path` imports
- `.claude/rules/` files
- Skills (load on demand)

---

## Decision Tree: Which Mode?

```
Is the task unclear or complex?
  → YES: Plan Mode first
  → NO: Normal Mode

Does it affect 5+ files with the same pattern?
  → YES: /batch
  → NO: Normal Mode

Am I working on multiple independent features?
  → YES: Worktree mode
  → NO: Normal Mode

Can I describe the diff in one sentence?
  → YES: Just do it
  → NO: Plan first
```

---

## Key Takeaways

1. **Verification is paramount** — Tests, screenshots, assertions. Claude does best when it can check its own work.
2. **Plan before coding** — For complex changes, use Plan Mode (`Shift+Tab` twice).
3. **Be specific upfront** — Reference files, provide test cases, point to examples.
4. **Manage context actively** — `/clear` between tasks, subagents for investigation.
5. **Use the right mode** — Plan for research, Batch for scale, Worktree for parallel, Normal for daily coding.
6. **Iterate naturally** — Claude Code is conversational. You don't need perfect prompts.
7. **Explore before implementing** — Especially for unfamiliar codebases.
