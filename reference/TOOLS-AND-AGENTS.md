# Claude Code Tools & Agents — Reference Guide

> Every tool Claude has access to, the subagent system, MCP servers, and when to use what.

## Mental Model: The Workshop

Think of Claude Code as a **well-equipped workshop**:

- **Tools** = Individual instruments (hammer, drill, saw). Each does one thing well.
- **Subagents** = Apprentices you send on errands. They work in their own corner, come back with results.
- **MCP Servers** = External suppliers. They provide specialty tools Claude doesn't have built-in.
- **Agent Teams** = Multiple apprentices collaborating on a big project, sharing a task board.

---

## Built-In Tools

### File Operations

| Tool | Purpose | Key Notes |
|------|---------|-----------|
| **Read** | Read file contents | Supports images, PDFs (max 20 pages), notebooks. Use instead of `cat` |
| **Write** | Create new files / full rewrites | Must Read first for existing files. Use instead of `echo >` |
| **Edit** | Modify specific sections | Sends only the diff. Preferred over Write for existing files |
| **Glob** | Find files by pattern | `**/*.ts`, `src/**/*.tsx`. Use instead of `find` or `ls` |

### Search

| Tool | Purpose | Key Notes |
|------|---------|-----------|
| **Grep** | Search file contents with regex | Uses ripgrep. Modes: `content`, `files_with_matches`, `count`. Supports multiline. Use instead of `grep`/`rg` |

### Execution

| Tool | Purpose | Key Notes |
|------|---------|-----------|
| **Bash** | Run shell commands | Can background with `Ctrl+B`. Subject to permission deny rules |

### Web Access

| Tool | Purpose | Key Notes |
|------|---------|-----------|
| **WebFetch** | Fetch and analyze a URL | HTML → markdown, 15-min cache |
| **WebSearch** | Search the web | Returns formatted results with source URLs |

### Agent Orchestration

| Tool | Purpose | Key Notes |
|------|---------|-----------|
| **Agent** | Spawn subagents for delegated work | Isolated context, can run in background or foreground |
| **AskUserQuestion** | Pause and ask for input | 1-4 questions, with options |

### Task Management

| Tool | Purpose |
|------|---------|
| **TaskCreate** | Create a tracked task |
| **TaskUpdate** | Update status, add dependencies |
| **TaskList** | List all tasks |
| **TaskGet** | Get full task details |

### IDE Integration

| Tool | Purpose |
|------|---------|
| **mcp__ide__getDiagnostics** | Get language diagnostics from VS Code |
| **mcp__ide__executeCode** | Run code in Jupyter kernel |

---

## Decision Tree: Which Tool?

```
Read existing file?         → Read
Create new file?            → Write
Modify existing file?       → Edit
Find files by name/pattern? → Glob
Search file contents?       → Grep
Run a command?              → Bash
Fetch a URL?                → WebFetch
Search the web?             → WebSearch
Delegate a task?            → Agent
Ask user a question?        → AskUserQuestion
```

**Anti-patterns (don't do this):**
- `Bash(cat file.txt)` → use Read
- `Bash(grep pattern)` → use Grep
- `Bash(find . -name)` → use Glob
- `Bash(echo > file)` → use Write
- `Bash(sed -i)` → use Edit

---

## Subagent System

Subagents are specialized AI assistants that run in **isolated context windows**. They complete their task and return results to the main conversation.

### Built-In Subagent Types

| Type | Model | Tools Available | Use For |
|------|-------|----------------|---------|
| **Explore** | Haiku (fast) | Read-only (Read, Glob, Grep, WebFetch, WebSearch) | File discovery, codebase search, analysis |
| **Plan** | Inherited | Read-only | Research phase in plan mode |
| **general-purpose** | Inherited | All tools | Complex multi-step tasks needing exploration + action |
| **claude-code-guide** | Haiku | Read-only + Web | Answering questions about Claude Code |

### When to Use Subagents

- **Quick focused task** → Subagent (isolated, reports back summary)
- **Verbose output** → Subagent (keeps output out of your context)
- **Parallel research** → Multiple subagents launched simultaneously
- **Complex collaboration** → Agent team (experimental)

### Foreground vs Background

| Mode | Behaviour |
|------|-----------|
| **Foreground** (default) | Blocks main conversation. Use when you need results to proceed. |
| **Background** | Runs concurrently. Use when you have independent work to do in parallel. |

Press `Ctrl+B` during execution to background a running subagent.

### Subagent Isolation with Worktrees

```yaml
isolation: worktree
```

Creates a temporary git worktree for the subagent — an isolated copy of the repo. Auto-deleted if no changes made.

### Creating Custom Subagents

Define agents as markdown files with YAML frontmatter:

**User-level:** `~/.claude/agents/<name>.md`
**Project-level:** `.claude/agents/<name>.md`

```markdown
---
name: code-reviewer
description: Expert code reviewer for quality and security
tools: Read, Grep, Glob
model: sonnet
permissionMode: dontAsk
maxTurns: 20
---

You are a senior code reviewer. Focus on:
- Code clarity and readability
- Security vulnerabilities
- Performance issues
- Test coverage
```

### Custom Agent Frontmatter Fields

| Field | Options | Notes |
|-------|---------|-------|
| `name` | lowercase-hyphenated | Unique identifier |
| `description` | Natural language | When Claude should delegate to this agent |
| `tools` | Tool list | Inherited from parent if omitted |
| `disallowedTools` | Tool list | Remove from inherited tools |
| `model` | `sonnet`, `opus`, `haiku`, `inherit` | Defaults to `inherit` |
| `permissionMode` | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` | Controls prompts |
| `maxTurns` | Integer | Max agentic turns before stop |
| `memory` | `user`, `project`, `local` | Persistent cross-session memory |
| `background` | `true`/`false` | Always run in background |
| `isolation` | `worktree` | Run in isolated git worktree |
| `skills` | Array of skill names | Preload skill content into context |

### Subagent Memory (Persistent)

```yaml
memory: user    # ~/.claude/agent-memory/<agent-name>/
memory: project # .claude/agent-memory/<agent-name>/ (git-tracked)
memory: local   # .claude/agent-memory-local/<agent-name>/ (not in git)
```

First 200 lines of `MEMORY.md` load into subagent context.

### Manage Agents

```
/agents              # View, create, edit, delete agent configs
claude --agent name  # Start session with specific agent
```

---

## MCP (Model Context Protocol)

MCP is an open standard for connecting Claude Code to external tools, databases, and APIs.

### What MCP Servers Provide

- **Tools** — Pre-built functions the LLM can call
- **Resources** — Data referenced via `@` mentions
- **Prompts** — Reusable prompt templates as `/mcp__server__prompt`

### Adding MCP Servers

```bash
# HTTP (recommended for remote tools)
claude mcp add --transport http github https://api.githubcopilot.com/mcp/

# SSE (deprecated)
claude mcp add --transport sse asana https://mcp.asana.com/sse

# Stdio (local processes)
claude mcp add --transport stdio db-server -- npx @package/server
```

**Important:** Options must come **before** server name. `--` separates from command args.

### MCP Scopes

| Scope | File | Shared | Command |
|-------|------|--------|---------|
| **Local** | `~/.claude.json` (project entry) | No | `claude mcp add --scope local ...` |
| **Project** | `.mcp.json` (repo root) | Yes (git) | `claude mcp add --scope project ...` |
| **User** | `~/.claude.json` (global) | No | `claude mcp add --scope user ...` |

Precedence: local > project > user.

### MCP Configuration Example

`.mcp.json`:
```json
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "headers": {
        "Authorization": "Bearer ${GITHUB_TOKEN}"
      }
    }
  }
}
```

### Managing MCP Servers

```bash
claude mcp list                    # List all servers
claude mcp get github              # Details for one server
claude mcp remove github           # Delete a server
claude mcp add-from-claude-desktop # Import from Claude Desktop
```

In Claude Code: `/mcp` — manage servers, authenticate OAuth.

### Tool Search (Scaling MCP)

When many MCP servers are configured, tool definitions can consume 10%+ of context. Tool Search loads tools on-demand:

```bash
ENABLE_TOOL_SEARCH=auto claude     # Auto-enable at 10% threshold (default)
ENABLE_TOOL_SEARCH=auto:5 claude   # Custom threshold (5%)
ENABLE_TOOL_SEARCH=true claude     # Always enabled
```

Requires Sonnet 4+ or Opus 4+ (Haiku doesn't support it).

---

## Agent Teams (Experimental)

Agent teams coordinate **multiple Claude Code instances** working together with a shared task list and messaging.

### Subagents vs Agent Teams

| Aspect | Subagents | Agent Teams |
|--------|-----------|-------------|
| Context | Own window, returns summary | Own window, fully independent |
| Communication | Report to main only | Message each other |
| Coordination | Main manages | Shared task list, self-coordinate |
| Cost | Lower | Higher (each = full context) |
| Best for | Quick focused tasks | Complex collaborative work |

### Enable

```bash
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude
```

### Display Modes

| Mode | Behavior | Requirements |
|------|----------|-------------|
| `auto` | Split panes if in tmux, else in-process | Default |
| `in-process` | All teammates in main terminal | Works anywhere |
| `tmux` | Split panes | tmux or iTerm2 |

Navigate: `Shift+Down` to cycle teammates. `Ctrl+T` for task list.

---

## Parallel Execution

### Parallel Tool Calls

Claude can make **multiple tool calls in a single turn** when they don't depend on each other:

```
Read file A  ┐
Read file B  ├── All execute simultaneously
Search for X ┘
```

### Parallel Subagent Launches

Claude can spawn **multiple subagents simultaneously** for independent research areas.

### Background Tasks

Long-running commands can run in background:
- Press `Ctrl+B` during execution
- Or ask Claude to background it
- Use `TaskOutput` to retrieve results later

---

## Permission System

```json
{
  "permissions": {
    "deny": ["Bash(rm -rf *)", "Bash(git push --force*)"],
    "allow": ["Bash(npm run *)", "Read"],
    "ask": ["Bash(git push *)"]
  }
}
```

Evaluation order: `deny` → `ask` → `allow`.

Cycle permission modes with `Shift+Tab`:
1. **Default** — asks for all operations
2. **Auto-accept edits** — skips file edit prompts
3. **Plan mode** — read-only
4. **Bypass** — skip all prompts (dangerous)

---

## Context Cost by Feature

| Feature | Cost | How to Reduce |
|---------|------|---------------|
| MCP tool definitions | Significant (can hit 10%) | Enable Tool Search |
| Loaded skills | Per-skill | Use `disable-model-invocation: true` |
| Subagent results | Summarized only | Use subagents for verbose work |
| Agent team members | Full context each | Limit team size |
| File contents (Read) | Per file | Use Grep to narrow first |
| CLAUDE.md | Always loaded | Keep concise, use skills instead |

---

## Our Setup (minihubvone)

### Current MCP Servers
- `ide` — VS Code integration

### Current Custom Agents
- None defined yet

### Potential Custom Agents
- `chat-tester` — Test chat tools against Postgres with read-only assertions
- `doc-reviewer` — Review docs-internal/ for accuracy against codebase
- `security-auditor` — Check for SQL injection, unmasked data, missing location scoping
