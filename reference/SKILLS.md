# Claude Code Skills — Reference Guide

> Skills extend Claude's capabilities by bundling instructions, reference files, and supporting materials into invocable units.

## What Are Skills?

Think of skills as **recipe cards** in the kitchen. Each card has a name, when to use it, what tools are needed, and step-by-step instructions. Claude can grab the right card when the situation fits, or you can hand it one directly with `/skill-name`.

Skills follow the **Agent Skills open standard** (agentskills.io) and work across multiple AI tools.

---

## SKILL.md Structure

Every skill lives in a folder with a `SKILL.md` file:

```
my-skill/
├── SKILL.md           # Main instructions (required)
├── template.md        # Template for Claude to fill (optional)
├── examples/
│   └── sample.md      # Example outputs (optional)
└── scripts/
    └── helper.sh      # Scripts Claude can run (optional)
```

### SKILL.md Format

Two sections — YAML frontmatter + markdown body:

```yaml
---
name: security-review
description: Review code for security vulnerabilities. Use when checking auth, input validation, or data protection.
context: fork
agent: Explore
allowed-tools: Read, Grep, Glob
---

# Security Review

Review the provided code for:

1. **Authentication**: How is identity verified?
2. **Authorization**: Are permissions properly checked?
3. **Input validation**: Are user inputs sanitized?
4. **Data protection**: Are sensitive data encrypted?

For each issue:
- State the location (file:line)
- Explain the risk
- Suggest a fix
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | No (defaults to folder name) | Skill identifier — becomes `/skill-name`. Lowercase, hyphens, max 64 chars |
| `description` | Yes | When Claude should use this skill (drives auto-invocation) |
| `disable-model-invocation` | No | `true` = only you can invoke (not Claude). Use for side-effect skills like `/deploy` |
| `user-invocable` | No | `false` = only Claude can invoke (background knowledge). Won't appear in `/` menu |
| `allowed-tools` | No | Restrict which tools Claude can use: `Read, Grep, Glob` |
| `context` | No | `fork` = run in isolated subagent context |
| `agent` | No | Subagent type: `Explore`, `Plan`, `general-purpose` |
| `argument-hint` | No | Shows expected args in autocomplete: `[component] [framework]` |

---

## Discovery — Where Skills Live

Skills are discovered from four scopes (higher priority overrides lower):

| Scope | Path | Applies To | Priority |
|-------|------|-----------|----------|
| **Enterprise** | Server-managed | All org users | 1 (Highest) |
| **Personal** | `~/.claude/skills/<skill-name>/SKILL.md` | All your projects | 2 |
| **Project** | `.claude/skills/<skill-name>/SKILL.md` | This project only | 3 |
| **Plugin** | `<plugin>/skills/<skill-name>/SKILL.md` | Where plugin is enabled | 4 (Lowest) |

**Monorepo support:** Editing files in subdirectories auto-discovers skills from nested `.claude/skills/` directories.

---

## Invoking Skills

### Manual (you trigger)
```
/skill-name
/skill-name with arguments
/fix-issue 123
```

### Automatic (Claude triggers)
Claude reads all skill descriptions into context. When your request matches a description, Claude loads and uses the skill automatically — unless `disable-model-invocation: true` is set.

### Autocomplete
Type `/` to see available skills, or `/skill-` to filter.

---

## User-Invocable vs Automatic Skills

| Config | You Can Invoke | Claude Can Invoke | Use Case |
|--------|---------------|-------------------|----------|
| Default (no flags) | Yes | Yes | General-purpose skills |
| `disable-model-invocation: true` | Yes | No | Side-effect skills (deploy, commit) |
| `user-invocable: false` | No | Yes | Background knowledge (legacy system context) |

---

## Arguments & Substitutions

Skills accept arguments at invocation time:

```yaml
---
name: fix-issue
description: Fix a GitHub issue by number
---

Fix GitHub issue #$ARGUMENTS following coding standards.
```

Invoke: `/fix-issue 123` → Claude sees "Fix GitHub issue #123..."

### Positional arguments
```yaml
---
name: migrate-component
argument-hint: [component-name] [from-framework] [to-framework]
---

Migrate the $0 component from $1 to $2.
```

Invoke: `/migrate-component SearchBar React Vue`

### Available variables

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | All arguments as a single string |
| `$ARGUMENTS[N]` or `$N` | Specific argument by 0-based index |
| `${CLAUDE_SESSION_ID}` | Current session ID |

If no `$ARGUMENTS` placeholder exists, Claude Code appends `ARGUMENTS: <input>` automatically.

---

## Tool Restrictions

Limit what Claude can do inside a skill:

```yaml
allowed-tools: Read, Grep, Glob
```

Common patterns:
- **Read-only exploration:** `Read, Grep, Glob`
- **Safe code writing:** `Read, Write, Edit, Bash(npm run test)`
- **No web access:** `Read, Grep, Glob, Bash(npm *, git *)`
- **Web research only:** `WebFetch, WebSearch, Read`

Wildcard supported: `Bash(npm *)` matches all npm commands. Your deny rules always override skill permissions.

---

## Built-In Skills

Claude Code ships with these:

| Skill | What It Does |
|-------|-------------|
| `/simplify` | Reviews changed files for code reuse, quality, and efficiency — then fixes issues. Spawns 3 parallel review agents |
| `/batch <instruction>` | Orchestrates large-scale changes across a codebase in parallel using isolated worktree agents (5–30 units). Creates one PR per unit |
| `/debug [description]` | Troubleshoots your Claude Code session by reading the debug log |

The **Developer Platform Skill** activates automatically when your code imports the Anthropic SDK.

---

## Dynamic Context Injection

Use `!`command`` syntax to run shell commands *before* Claude sees the skill:

```yaml
---
name: pr-context
context: fork
agent: Explore
---

PR title: !`gh pr view $ARGUMENTS --json title --jq '.title'`

Changed files:
!`gh pr diff $ARGUMENTS --name-only`
```

Shell commands run immediately, output replaces the placeholder, then Claude gets the fully-rendered prompt.

---

## Running Skills in Subagents

Use `context: fork` to isolate a skill in its own conversation:

```yaml
---
name: deep-research
context: fork
agent: Explore
---

Research $ARGUMENTS thoroughly and summarize findings.
```

The subagent gets its own context window. Results are summarized and returned to your main conversation.

---

## Examples

### Example 1: Read-Only Exploration

```yaml
---
name: analyze-performance
description: Analyze code for performance issues
allowed-tools: Read, Grep, Glob
---

Analyze for performance bottlenecks:
1. Algorithmic complexity
2. Memory usage
3. I/O operations
4. Database queries (N+1 problems?)
5. Caching opportunities
```

### Example 2: Skill with Supporting Files

```yaml
---
name: api-review
description: Review API design against our conventions
allowed-tools: Read, Grep, Glob
---

Review this code against our API conventions in [conventions.md](conventions.md).
Use the checklist in [review-checklist.md](review-checklist.md).
```

Claude loads supporting files only when it needs them.

### Example 3: Deployment Skill (User-Only)

```yaml
---
name: deploy-staging
description: Deploy to staging environment
disable-model-invocation: true
context: fork
agent: general-purpose
---

Deploy to staging:
1. Run full test suite — fail if any break
2. Build the application
3. Deploy to staging
4. Run smoke tests
5. Report deployment URL

Do NOT deploy to production.
```

---

## Tips

- **Descriptions matter** — Specific, action-oriented descriptions drive better auto-invocation
- **Keep SKILL.md focused** — Move detailed reference to supporting files
- **Use `disable-model-invocation: true`** for anything with side effects
- **Test skills manually** with `/skill-name` before relying on auto-invocation
- **Context budget** — Skill descriptions use max 2% of context window (override with `SLASH_COMMAND_TOOL_CHAR_BUDGET=50000`)
- **Share via git** — Project skills in `.claude/skills/` are team-shareable

---

## Our Setup (minihubvone)

Currently we have **no custom project skills** in `.claude/skills/`.

Available built-in skills:
- `/simplify` — review code quality
- `/batch` — parallel large-scale changes
- `/debug` — troubleshoot sessions
- `/keybindings-help` — customize keyboard shortcuts

**Future candidates for custom skills:**
- `/chat-tool` — scaffold a new chat tool (pre-built query + service)
- `/pg-query-review` — verify Postgres queries follow our rules (read-only, soft-delete, location-scoped, parameterized, LIMIT)
