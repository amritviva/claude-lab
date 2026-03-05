# Claude Code Setup Checklist — Report Card & Action Items

> Current setup assessment, gaps identified, and prioritised actions.

## Current Setup Summary

| Component | Status | Location |
|-----------|--------|----------|
| API key helper | Done | `~/.claude/api-key-helper.sh` |
| Model | `opus[1m]` (Opus 4.6, 1M context) | `~/.claude/settings.json` |
| Status line | Configured | `~/.claude/statusline-command.sh` |
| Global CLAUDE.md | Done | `~/.claude/CLAUDE.md` |
| Project CLAUDE.md | Done | `./CLAUDE.md` |
| Local CLAUDE.md | Done | `./CLAUDE.local.md` |
| Project rules (7 files) | Done | `.claude/rules/001-007` |
| Auto-memory | Active | `memory/MEMORY.md` (~100 lines) |
| Permission deny rules | 26 patterns | `~/.claude/settings.json` |
| IDE integration (MCP) | VS Code connected | `ide` MCP server |

---

## Report Card

### What's Working Well

| Area | Grade | Notes |
|------|-------|-------|
| **Permission denies** | A | 26 deny rules covering destructive ops, AWS prod safety |
| **Project rules** | A | 7 modular rule files covering read-only, soft-delete, location scoping, sensitive data, code patterns |
| **CLAUDE.md hierarchy** | A | Global + project + local all in place |
| **Model selection** | A | Opus 4.6 with 1M context — best available |
| **Auto-memory** | A | Active, well-organised, ~100 lines (under 200 limit) |
| **Status line** | A | Custom script configured |
| **Documentation** | A | 31+ docs in docs-internal/ |

### Gaps Identified

| Area | Grade | Gap |
|------|-------|-----|
| **Permission allows** | C | No explicit allow rules = permission prompts for safe operations (npm, git diff, Read) |
| **Hooks** | D | No hooks configured. Missing auto-format, context reminders, notifications |
| **Custom skills** | D | No project skills in `.claude/skills/`. Built-in only |
| **Custom agents** | D | No custom subagents in `.claude/agents/` |
| **MCP servers** | C | Only `ide`. No GitHub, no external tools |
| **Keybindings** | C | No custom keybindings. Using defaults only |
| **Sandbox** | C | Not enabled. No filesystem/network isolation |
| **Path-scoped rules** | B | All 7 rules are unconditional. Could scope chat rules to `services/chat/` when it exists |

---

## Action Items (Prioritised)

### Priority 1: High Impact, Quick Wins (< 5 min each)

#### 1.1 Add Permission Allow Rules

**Why:** Eliminates repetitive permission prompts for safe operations. Currently you get prompted for every `git diff`, `npm test`, `Read`, etc.

**Action:** Add to `~/.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(npm run *)",
      "Bash(npm test*)",
      "Bash(npm install*)",
      "Bash(git diff*)",
      "Bash(git log*)",
      "Bash(git status*)",
      "Bash(git branch*)",
      "Bash(git checkout*)",
      "Bash(ls *)",
      "Bash(cat *)",
      "Bash(node *)",
      "Read",
      "Edit",
      "Glob",
      "Grep"
    ]
  }
}
```

#### 1.2 Add Context Reminder Hook (After Compaction)

**Why:** When context compacts, Claude can forget critical rules like "Postgres is read-only." This re-injects them.

**Action:** Add to `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'CRITICAL REMINDERS: Postgres is read-only. Always include soft-delete filters. Always include location scoping. DynamoDB is source of truth. Never write to Postgres.'"
          }
        ]
      }
    ]
  }
}
```

#### 1.3 Add macOS Notification Hook

**Why:** Get notified when Claude needs your input (especially useful when backgrounding tasks).

**Action:** Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "osascript -e 'display notification \"Claude Code needs your attention\" with title \"Claude Code\"'"
          }
        ]
      }
    ]
  }
}
```

---

### Priority 2: Medium Impact (10-30 min each)

#### 2.1 Create First Custom Skill: `/pg-query-review`

**Why:** Automatically verify that Postgres queries follow our rules (read-only, parameterised, soft-delete, location-scoped, LIMIT).

**Action:** Create `.claude/skills/pg-query-review/SKILL.md`:

```yaml
---
name: pg-query-review
description: Review Postgres queries against project rules. Use when writing or reviewing SQL queries.
allowed-tools: Read, Grep, Glob
---

Review the Postgres query for compliance:

1. Is it read-only? (SELECT only — no INSERT, UPDATE, DELETE, DDL)
2. Is it parameterised? ($1, $2 — no string concatenation)
3. Does every table have a soft-delete filter?
   - Hevo tables: __hevo__marked_deleted IS NULL OR __hevo__marked_deleted = false
   - App tables: is_deleted IS NULL OR is_deleted = false
4. Is there location scoping? (location_id = ANY($X) or home_location_id = ANY($X))
5. Is there a LIMIT clause? (max 200)

Report: PASS or FAIL for each check, with the specific line that violates.
```

#### 2.2 Create Custom Agent: `chat-tool-tester`

**Why:** Verify chat tools return correct results and follow all rules.

**Action:** Create `.claude/agents/chat-tool-tester.md`:

```markdown
---
name: chat-tool-tester
description: Test chat tools for correctness and rule compliance
tools: Read, Grep, Glob
model: sonnet
permissionMode: plan
---

You are a test reviewer for chat tool implementations.

For each tool, verify:
1. Query is read-only SELECT
2. Parameterised (no string interpolation)
3. Soft-delete filters on every table
4. Location scoping via allowedLocationIds
5. LIMIT clause present (max 200)
6. Sensitive data masked (card numbers, BSB, bank accounts)
7. Return types match interface definition

Report issues with file:line references.
```

#### 2.3 Add GitHub MCP Server

**Why:** Direct access to PRs, issues, and code reviews without `gh` CLI workarounds.

**Action:**
```bash
claude mcp add --transport http --scope user github https://api.githubcopilot.com/mcp/
```

---

### Priority 3: Nice to Have (When Time Permits)

#### 3.1 Custom Keybindings

**Action:** Run `/keybindings` and configure:

```json
{
  "bindings": [
    {
      "context": "Chat",
      "bindings": {
        "ctrl+e": "chat:externalEditor"
      }
    }
  ]
}
```

#### 3.2 Enable Sandbox

**Action:** Add to `.claude/settings.json`:

```json
{
  "sandbox": {
    "enabled": true
  }
}
```

#### 3.3 Path-Scope Chat Rules

When the chat module code exists, scope rule 007 to only load for chat files:

```markdown
---
paths:
  - "app/src/services/chat/**"
  - "app/src/services/tools/**"
  - "app/src/routes/api/handlers/chat*.ts"
  - "app/src/prompts/**"
---
```

#### 3.4 Configure Shift+Enter for Multiline

```
/terminal-setup
```

#### 3.5 Set Up Auto-Format Hook

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path' | xargs npx prettier --write 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
```

---

## Slash Commands Reference

Most useful commands for daily work:

| Command | Purpose | Frequency |
|---------|---------|-----------|
| `/clear` | Reset conversation | Between unrelated tasks |
| `/compact` | Compress context | When context fills mid-task |
| `/context` | Visualise context usage | Check when things feel slow |
| `/cost` | Token usage stats | End of session |
| `/model` | Switch model | When switching task complexity |
| `/plan` | Enter plan mode | Before complex changes |
| `/memory` | View/edit memory files | When updating instructions |
| `/hooks` | Manage hooks | Setup |
| `/agents` | Manage subagents | Setup |
| `/mcp` | Manage MCP servers | Setup |
| `/diff` | Interactive diff viewer | After changes |
| `/rewind` | Undo to checkpoint | When Claude goes wrong |

## Keyboard Shortcuts Reference

| Shortcut | Action |
|----------|--------|
| `Ctrl+B` | Background running task |
| `Ctrl+C` | Cancel current operation |
| `Ctrl+G` | Open in external editor |
| `Ctrl+O` | Toggle verbose output |
| `Ctrl+R` | Reverse history search |
| `Ctrl+T` | Toggle task list |
| `Shift+Tab` | Cycle permission modes |
| `Alt+P` / `Option+P` | Switch model |
| `Alt+T` / `Option+T` | Toggle extended thinking |
| `Esc + Esc` | Rewind to checkpoint |

---

## Environment Variables Worth Setting

Add to `~/.zshrc`:

```bash
# Already configured via settings.json, but good to know:
# export ANTHROPIC_MODEL=opus[1m]

# MCP tool search (useful when adding more MCP servers)
export ENABLE_TOOL_SEARCH=auto:10

# Raise MCP output limit for large results
export MAX_MCP_OUTPUT_TOKENS=50000

# Share task list across sessions (optional)
# export CLAUDE_CODE_TASK_LIST_ID=minihubvone
```

---

## Summary

**Overall Grade: B+**

Strong foundation with excellent rules, memory, and safety configuration. Main gaps are in automation (hooks, skills, agents) — these are quick wins that will significantly improve workflow efficiency.

**Top 3 actions for maximum impact:**
1. Add permission allow rules (stops repetitive prompts)
2. Add compaction context reminder hook (prevents rule amnesia)
3. Create `/pg-query-review` skill (automates query compliance checking)
