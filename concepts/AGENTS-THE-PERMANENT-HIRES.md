# Custom Agents = Permanent Specialist Hires

## The Analogy

You already have temp workers (built-in sous chefs — Explore, Plan, general-purpose). They show up, you explain the job, they do it, they leave. Next time? Full briefing again.

**Custom agents are permanent hires.** They arrive with a training manual already memorised. You don't explain the job — they know it.

```
You:    "Review the chat tool files for security issues"
Head Chef → pages Rosa (security-reviewer)
Rosa:   *reads files, checks 5 categories, reports with file:line references*

No briefing. No explaining what to check. Rosa knows.
```

## Temp Workers vs Permanent Hires

```
TEMP WORKERS (built-in sous chefs)          PERMANENT HIRES (custom agents)
─────────────────────────────────           ──────────────────────────────────
Show up generic                             Arrive already trained
You brief them every time                   They read their own training manual
No memory of last shift                     Can have their own notebook (memory)
Can use any tool                            Tool belt locked to their role
Same access level as Head Chef              Own access level (can be restricted)
All cost the same                           Can assign cheaper/faster model
```

## Your Current Team

```
┌──────────────────────────────────────────────────────────────┐
│                  THE PERMANENT HIRES                          │
│                                                              │
│  Rosa — security-reviewer                                    │
│     Checks: SQL injection, access control, data exposure,    │
│             input validation, soft-delete bypass             │
│     Tools: Read, Grep, Glob (LOOK only — no touching)        │
│     Model: Sonnet (fast, cheap — pattern matching)           │
│     Access: plan mode (hard lock — cannot edit)              │
│     Lives: everywhere (personal scope)                       │
│                                                              │
│  [Next hire: chat-tool-tester — project scope, minihubvone]  │
│  [Next hire: doc-reviewer — checks docs against code]        │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Anatomy of a Permanent Hire

Every hire has a **personnel file** — a single `.md` file with two parts:

```
agents/security-reviewer.md = The personnel file

┌─────────────────────────────────────────┐
│  --- (frontmatter = HR paperwork)       │
│  name: security-reviewer  ← name badge  │
│  description: ...   ← when to page them │
│  tools: Read, Grep  ← tool belt         │
│  model: sonnet      ← pay grade         │
│  permissionMode: plan ← access level    │
│  maxTurns: 15       ← shift length      │
│  memory: project    ← own notebook      │
│  background: true   ← works while you   │
│                       do other things    │
│  ---                                    │
│                                         │
│  # Training Manual   ← what they know   │
│  ## What to Check    ← their checklist  │
│  ## Output Format    ← how they report  │
│  ## Rules            ← boundaries       │
│  └─────────────────────────────────────┘
```

## The HR Paperwork (Frontmatter Fields)

| Field | Kitchen Analogy | What It Does |
|-------|----------------|--------------|
| `name` | Name badge | How Head Chef pages them |
| `description` | "Call this person when..." | Triggers auto-delegation |
| `tools` | Tool belt | What they can pick up (Read, Bash, etc.) |
| `model` | Pay grade | `opus` (senior), `sonnet` (mid), `haiku` (junior) |
| `permissionMode` | Access level | `plan` = look only, `dontAsk` = full autonomy |
| `maxTurns` | Shift length | Max steps before they clock out |
| `memory` | Their own notebook | `user`, `project`, or `local` — persists between shifts |
| `background` | Works while you chat | `true` = Head Chef doesn't wait for them |
| `isolation` | Own copy of the kitchen | `worktree` = isolated git branch |
| `skills` | Pre-loaded recipe cards | Array of skill names they start with |

## Where Permanent Hires Live

```
Personal hires (follow you to every kitchen):
  ~/.claude/agents/
    security-reviewer.md     ← Rosa, available everywhere

Project hires (stay in one kitchen only):
  .claude/agents/
    chat-tool-tester.md      ← only exists in minihubvone
```

**Same scoping logic as skills:**
- Personal = `~/.claude/agents/` → all projects
- Project = `.claude/agents/` → one repo only

## How to Call Them

### Option A: Start a session AS the agent
```bash
claude --agent security-reviewer
```
You're now talking directly to Rosa. She has her own context, her own rules. When you're done, exit and you're back to normal.

### Option B: Head Chef delegates automatically
```
You: "Check the payment handler for security vulnerabilities"

Head Chef reads Rosa's description:
  "Review code for security vulnerabilities..."
  → Match! Pages Rosa.

Rosa works in her own context, reports back to Head Chef.
You see Rosa's findings in your main conversation.
```

### Option C: Ask Head Chef explicitly
```
You: "Use the security-reviewer agent to check services/tools/"
Head Chef: *spawns Rosa with that specific task*
```

## Skills vs Agents — When to Use Which

```
SKILLS (Robots)                    AGENTS (Permanent Hires)
──────────────────                 ──────────────────────────
YOU call them (/commit)            HEAD CHEF calls them (or you)
Run in YOUR context                Run in THEIR OWN context
Use YOUR whiteboard                Get their OWN whiteboard
Quick tasks (1-3 steps)            Multi-step investigations
No persistent memory               Can have their own notebook
Instant — no overhead              Heavier — separate process
Best for: format, commit, review   Best for: audit, test, research
```

**Rule of thumb:**
- If it's a quick recipe → Skill (robot)
- If it needs to investigate, read many files, reason across them → Agent (permanent hire)

## Building a New Permanent Hire

1. **Pick the scope** — personal (`~/.claude/agents/`) or project (`.claude/agents/`)?
2. **Create the `.md` file** — frontmatter (HR paperwork) + body (training manual)
3. **Choose the model** — does this job need senior (opus) or is mid-level (sonnet) enough?
4. **Lock the tool belt** — what tools does this role actually need? Less = safer.
5. **Set access level** — should they be able to edit? Usually no for reviewers.
6. **Restart session** — agents load at startup, like skills
7. **Test it** — `claude --agent name` or ask Head Chef to delegate

## Managing Your Team

```bash
/agents              # View, create, edit, delete agents in-session
claude --agent name  # Start session as specific agent
```
