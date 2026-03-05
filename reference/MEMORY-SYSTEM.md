# Claude Code Memory & Instructions System — Reference Guide

> How Claude remembers things across sessions: CLAUDE.md scopes, rules, auto-memory, and imports.

## Mental Model: The Filing Cabinet

Think of Claude's memory as a **filing cabinet** with drawers at different levels:

- **Top drawer (Managed Policy)** — Company-wide rules, locked by IT. Can't be overridden.
- **Second drawer (User)** — Your personal preferences across all projects (`~/.claude/CLAUDE.md`)
- **Third drawer (Project)** — Team-shared instructions checked into git (`./CLAUDE.md`)
- **Bottom drawer (Local)** — Your personal overrides for this project only (`./CLAUDE.local.md`)

Every session, Claude opens all drawers and reads everything. More specific drawers override broader ones.

---

## CLAUDE.md Scopes

### Scope Hierarchy (Highest → Lowest Priority)

| Scope | Location | Shared via Git | Loaded |
|-------|----------|---------------|--------|
| **Managed Policy** | `/Library/Application Support/ClaudeCode/CLAUDE.md` (macOS) | IT-deployed | Always (cannot exclude) |
| **Local** | `./CLAUDE.local.md` | No (gitignored) | Every session |
| **Project** | `./CLAUDE.md` or `./.claude/CLAUDE.md` | Yes | Every session |
| **User** | `~/.claude/CLAUDE.md` | No | Every session |

### How Loading Works

1. Claude walks from your working directory **up to root**, loading CLAUDE.md files in each directory
2. Subdirectory CLAUDE.md files load **on demand** when Claude reads files in those directories
3. If both `./CLAUDE.md` and `./CLAUDE.local.md` exist, local takes precedence for conflicting topics

### Our Setup

```
~/.claude/CLAUDE.md                    → Global rules (explain commands, session memory, AWS prod safety)
~/Desktop/viva/minihubvone/CLAUDE.md   → Project memory (architecture, domain model, AI chat context)
~/Desktop/viva/minihubvone/CLAUDE.local.md → Personal prefs (timezone, style, local env)
```

---

## The `.claude/rules/` Directory

For projects that need more than a single CLAUDE.md, rules let you split instructions into modular, topic-specific files.

### Structure

```
.claude/rules/
├── 001-read-only.md          # Postgres is read-only
├── 002-soft-delete.md        # Soft-delete filters mandatory
├── 003-location-scoping.md   # Location-based access control
├── 004-sensitive-data.md     # Card/bank masking rules
├── 005-existing-code.md      # Don't touch existing files
├── 006-patterns.md           # Code patterns to follow
└── 007-chat-module.md        # AI chat module rules
```

### Loading Behaviour

- **Unconditional rules** (no `paths` frontmatter) — load at session start, like CLAUDE.md
- **Path-scoped rules** (with `paths` frontmatter) — load on demand when Claude reads matching files

### Path-Scoped Rules

Scope rules to specific file types using YAML frontmatter:

```markdown
---
paths:
  - "src/api/**/*.ts"
  - "src/api/**/*.tsx"
---

# REST API Rules

- All endpoints must include input validation
- Use standard error response format
```

When Claude reads a file matching `src/api/**/*.ts`, this rule loads automatically.

### Glob Pattern Examples

| Pattern | Matches |
|---------|---------|
| `**/*.ts` | All TypeScript files recursively |
| `src/components/*.tsx` | React components in specific dir (not subdirs) |
| `src/**/*.{ts,tsx}` | TypeScript and TSX under `src/` |
| `tests/**/*.test.ts` | Test files under `tests/` |

### User-Level Rules

Rules in `~/.claude/rules/` apply to every project on your machine. Project rules can override them.

---

## Auto-Memory

Auto-memory is what **Claude** learns about your project. While CLAUDE.md is what *you* write, auto-memory is what *Claude* writes.

### Overview

| Aspect | Details |
|--------|---------|
| **Who writes** | Claude (automatically) |
| **Storage** | `~/.claude/projects/<project>/memory/` |
| **Loaded each session** | First 200 lines of `MEMORY.md` |
| **Persists across** | Sessions, worktrees, branch checkouts (same repo) |

### Storage Structure

```
~/.claude/projects/<project>/memory/
├── MEMORY.md              # Index (first 200 lines loaded every session)
├── debugging.md           # Topic file (loaded on demand)
├── build-commands.md      # Topic file (loaded on demand)
└── patterns.md            # Topic file (loaded on demand)
```

### The 200-Line Limit

- First 200 lines of `MEMORY.md` load at session start
- Content beyond 200 lines is NOT loaded automatically
- Topic files (e.g., `debugging.md`) have no line limit — loaded on demand

**Strategy:** Keep `MEMORY.md` as a concise index, link to topic files for details.

### Managing Auto-Memory

- `/memory` — opens the memory browser (view, toggle, edit)
- Edit files directly at `~/.claude/projects/<project>/memory/`
- Disable globally: `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`
- Disable per project: `"autoMemoryEnabled": false` in `.claude/settings.json`

---

## @Imports in CLAUDE.md

CLAUDE.md files can reference other files using `@path/to/file` syntax:

```markdown
# Project Instructions

See architecture in @README.md

## Dependencies
Available npm commands: @package.json

## API Conventions
@docs/api-conventions.md
```

### How It Works

1. `@` references are resolved when CLAUDE.md loads
2. Imported file contents expand inline
3. Everything loads as if it were one file

### Path Resolution

- **Relative paths** — resolved relative to the CLAUDE.md file containing the import
- **Absolute paths** — supported (e.g., `@/home/user/shared-docs/patterns.md`)
- **Home directory** — supported (e.g., `@~/.claude/shared-rules.md`)

### Limits

- **Max depth:** 5 hops (A → B → C → D → E → F is too deep)
- **Circular imports:** detected and handled gracefully
- **Missing files:** skipped with a warning

### First-Time Approval

First time Claude Code sees imports in a project, it shows an approval dialog. You can approve (permanent) or decline.

---

## How Instructions Flow Into the System Prompt

At session start, Claude Code builds the system prompt by concatenating:

1. Claude's core system instructions (internal)
2. Managed policy CLAUDE.md (if exists)
3. User CLAUDE.md (`~/.claude/CLAUDE.md`)
4. Ancestor CLAUDE.md files (parent directories)
5. Project CLAUDE.md (`./CLAUDE.md`)
6. Local CLAUDE.md (`./CLAUDE.local.md`)
7. Unconditional rules (`.claude/rules/` without `paths`)
8. User-level rules (`~/.claude/rules/`)
9. Auto-memory (first 200 lines of MEMORY.md)

**Path-scoped rules** load later, when Claude reads matching files.

---

## Settings Precedence (Separate from CLAUDE.md)

Settings follow a different priority than CLAUDE.md:

| Scope | Location | Priority |
|-------|----------|----------|
| **Command line** | `claude --model opus` | 1 (Highest) |
| **Managed policy** | System-wide settings | 2 |
| **Local project** | `.claude/settings.local.json` | 3 |
| **Shared project** | `.claude/settings.json` | 4 |
| **User** | `~/.claude/settings.json` | 5 (Lowest) |

Permission arrays **merge** across scopes — the most restrictive rule wins.

---

## Best Practices

### Size Guidelines

| Type | Target | Max | Effect of Oversizing |
|------|--------|-----|---------------------|
| CLAUDE.md | < 200 lines | 400 | Context bloat, rules ignored |
| Auto-memory MEMORY.md | < 200 lines | Enforced | Content beyond 200 won't load |
| Rule file | < 150 lines | 300 | Harder to maintain |

### When to Use Each Mechanism

| Mechanism | Use For | Example |
|-----------|---------|---------|
| **CLAUDE.md** | Quick reference, project-wide rules | Build commands, code style, branch naming |
| **`.claude/rules/`** | Topic-specific or path-scoped rules | "REST rules apply to src/api/**" |
| **Auto memory** | Claude's learned insights | Build time, common errors, debugging patterns |
| **Skills** | Repeatable workflows | "fix-issue", "review-pr" |
| **Hooks** | Actions that must happen with zero exceptions | Auto-linting, blocking dangerous ops |

### Monorepo Exclusions

Skip irrelevant ancestor CLAUDE.md files:

```json
// .claude/settings.local.json
{
  "claudeMdExcludes": [
    "**/team-a/CLAUDE.md",
    "/home/user/monorepo/config/CLAUDE.md"
  ]
}
```

---

## Token Cost Reference

| Content | Cost | When Loaded |
|---------|------|------------|
| CLAUDE.md | High (always) | Every session |
| Auto memory (MEMORY.md) | Medium (200 lines) | Every session |
| Skill descriptions | Low | Every session |
| Skill full content | Medium-High | When invoked |
| Unconditional rules | Medium | Every session |
| Path-scoped rules | Medium | On demand |
| Imported files (@) | Varies | Every session |

### Optimization Tips

1. Keep CLAUDE.md under 200 lines
2. Use path-scoped rules to avoid loading irrelevant instructions
3. Move long docs to `@` imports
4. Use skills for workflows (load on demand, not every session)
5. Break one monolithic CLAUDE.md into multiple rule files

---

## Our Current Setup

### Files in Place

| File | Lines | Purpose |
|------|-------|---------|
| `~/.claude/CLAUDE.md` | ~100 | Global rules, AWS safety, personal style |
| `CLAUDE.md` (project) | ~80 | AI chat architecture, domain model |
| `CLAUDE.local.md` | ~20 | Personal prefs, local env |
| `.claude/rules/001-read-only.md` | ~15 | Postgres read-only rule |
| `.claude/rules/002-soft-delete.md` | ~25 | Soft-delete filter patterns |
| `.claude/rules/003-location-scoping.md` | ~20 | Location access control |
| `.claude/rules/004-sensitive-data.md` | ~15 | Card/bank data masking |
| `.claude/rules/005-existing-code.md` | ~30 | Safe files to create/modify |
| `.claude/rules/006-patterns.md` | ~30 | Code patterns to follow |
| `.claude/rules/007-chat-module.md` | ~40 | Chat module specific rules |
| `memory/MEMORY.md` | ~100 | Session history, decisions, next steps |

### What's Working Well

- Rules are modular and topic-specific
- Auto-memory tracks session continuity
- Global CLAUDE.md protects AWS production
- CLAUDE.local.md keeps personal prefs out of git

### Potential Improvements

- Consider **path-scoped rules** when chat module code grows (e.g., chat rules only load when editing `services/chat/`)
- Consider **@imports** for referencing `docs-internal/` architecture docs from CLAUDE.md
- Keep MEMORY.md under 200 lines (currently ~100, healthy)
