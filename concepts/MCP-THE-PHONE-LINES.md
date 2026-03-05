# MCP = Phone Lines to the Outside World

## The Problem

Your kitchen has built-in equipment:

```
Built-in equipment (tools that came with the kitchen):
  Read     → fridge (open and look at ingredients)
  Edit     → knife (modify ingredients)
  Bash     → the stovetop (cook/run things)
  Grep     → the ingredient scanner
  Glob     → the pantry inventory
```

These work on **things inside the kitchen** — your files, your terminal, your codebase.

But the outside world? Head Chef has to walk outside and do it manually via Bash:

```
Want GitHub PRs?   → Bash("gh pr list")       → raw text, parse it yourself
Want DB query?     → Bash("psql -c 'SELECT'") → raw text, hope it's right
Want Slack?        → Can't. No connection.
```

It works, but it's clunky. Like a chef personally driving to the fish market every time they need salmon.

## The Solution: Install Phone Lines

**MCP (Model Context Protocol)** installs direct phone lines in your kitchen to external services.

```
BEFORE MCP:
┌──────────────────────────────┐
│  THE KITCHEN                 │
│                              │
│  Head Chef has:              │
│    - Built-in equipment      │
│    - A stovetop (Bash)       │     🚶 walks outside
│    - No phone                │ ──→ manually via CLI
│                              │
└──────────────────────────────┘

AFTER MCP:
┌──────────────────────────────┐
│  THE KITCHEN                 │
│                              │
│  Head Chef has:              │
│    - Built-in equipment      │
│    - A stovetop (Bash)       │
│    - Phone bank on the wall: │
│       Line 1 → GitHub        │
│       Line 2 → Postgres      │
│       Line 3 → Slack         │
│                              │
│  "I need to check the PR"   │
│  *picks up Line 1*           │
│  "Give me PR #42 details"   │
│  *gets answer instantly*     │
└──────────────────────────────┘
```

Each phone line = one **MCP server**.
Each server provides **tools** Head Chef can call, just like built-in tools.

## What's an MCP Server?

A program running outside Claude that says:

> "Hey, I'm the GitHub server. I can do these things:
> - `list_pull_requests`
> - `create_issue`
> - `get_file_contents`
>
> Call me whenever you need them."

Claude sees these as **extra tools** alongside Read, Edit, Bash:

```
Head Chef's tool belt after installing MCP servers:

BUILT-IN:                     FROM MCP SERVERS:
  Read                          mcp__github__list_pull_requests
  Edit                          mcp__github__create_issue
  Write                         mcp__postgres__query
  Bash                          mcp__slack__send_message
  Grep                          mcp__ide__getDiagnostics
  Glob                          mcp__ide__executeCode
```

Notice the naming: `mcp__<server>__<tool>`.
That's how you know it came from a phone line, not built-in.

## Tools vs Permissions vs MCP — The Full Picture

These three things look similar but do completely different jobs:

```
TOOLS = the equipment itself (what EXISTS)
  Read, Edit, Bash, Grep, Glob...
  Built into Claude Code. Always there.
  You can't add or remove them.
  Like: the fridge came with the kitchen.

PERMISSIONS = safety rules about using equipment (what's ALLOWED)
  "deny": ["Bash(rm -rf *)"]
  "allow": ["Read"]
  YOUR rules in settings.json.
  Don't create tools — control access to existing tools.
  Like: "never leave the gas on unattended"

MCP = the ONLY way to add NEW tools
  Install a server → new tools appear in the belt.
  Like: installing a phone line gives you a new capability.
```

Three layers of control over tools:

```
┌─────────────────────────────────────────────────┐
│  1. PERMISSIONS (settings.json)                 │
│     Global safety rules for ALL tools           │
│     deny: Bash(rm -rf *) → always blocked       │
│     allow: Read → never asks                    │
│                                                 │
│  2. SKILLS restrict tools per-recipe            │
│     /pg-query-review → only Read, Grep, Glob    │
│                                                 │
│  3. AGENTS restrict tools per-hire              │
│     security-reviewer → only Read, Grep, Glob   │
│                                                 │
│  MCP doesn't restrict — it ADDS.                │
│  It's the only way to grow the tool belt.       │
└─────────────────────────────────────────────────┘
```

## What a Phone Line Can Deliver

```
1. TOOLS — functions Head Chef can call
   "list_pull_requests", "query_database"
   → Appear in Head Chef's tool belt
   → This is what you'll use 95% of the time

2. RESOURCES — reference data via @ mentions
   @github:repo/file.ts → injects file content
   → Like a supplier's catalogue you can browse

3. PROMPTS — reusable prompt templates
   /mcp__github__review_pr → pre-written workflow
   → Like a supplier's pre-made meal kit
```

## Why Not Just Use Bash?

```
VIA BASH (walking to the fish market):
  Head Chef: "I need PR details"
  → Constructs: Bash("gh pr view 42 --json title,body")
  → Parses raw JSON output
  → Hopes the format is right
  → No schema, no validation

VIA MCP (picking up the phone):
  Head Chef: "I need PR details"
  → Calls: mcp__github__get_pull_request(number=42)
  → Gets structured, typed response
  → Schema tells Chef exactly what fields exist
  → Error handling built in
```

MCP tools are typed, structured, and self-documenting.
Bash is raw and freeform.
MCP = professional supplier with a catalogue.
Bash = foraging in the wild.

## Types of Phone Lines

```
TYPE 1: HTTP (supplier has their own warehouse)
  Phone line goes over the internet.
  The server runs on THEIR infrastructure.
  Examples: GitHub MCP, Slack MCP, Asana MCP

  claude mcp add --transport http github https://api.githubcopilot.com/mcp/

TYPE 2: Stdio (specialist works from YOUR building)
  A program runs on YOUR machine.
  Claude talks to it via stdin/stdout.
  Examples: database connector, file indexer, local tools

  claude mcp add --transport stdio db-server -- npx @package/server
```

Think of it as:
- **HTTP** = calling an external delivery service (they run the warehouse)
- **Stdio** = hiring a specialist who works in your back room (runs locally)

## Where Phone Lines Are Configured

Same scoping as everything else in Claude:

```
Personal phone lines (all your kitchens):
  ~/.claude.json
  claude mcp add --scope user github ...

Project phone lines (one kitchen, shared with team via git):
  .mcp.json (in repo root)
  claude mcp add --scope project github ...

Local phone lines (one kitchen, just you):
  ~/.claude.json (project-specific entry)
  claude mcp add --scope local github ...
```

Precedence: local > project > user.

## Managing Phone Lines

```bash
claude mcp list                      # List all installed lines
claude mcp get github                # Details for one line
claude mcp remove github             # Disconnect a line
claude mcp add-from-claude-desktop   # Import from Claude Desktop app
/mcp                                 # In-session: manage and authenticate
```

## The Context Cost Gotcha

Every phone line installed loads its tool descriptions into your whiteboard **every session**. Many servers with many tools = significant whiteboard space before you even ask a question.

```
5 MCP servers x 20 tools each = 100 tool descriptions
= 10%+ of your whiteboard consumed, every session
```

**Solution:** Tool Search loads descriptions on-demand instead of all at once:

```bash
ENABLE_TOOL_SEARCH=auto claude     # Auto-enable when tools hit 10%
ENABLE_TOOL_SEARCH=auto:5 claude   # Custom threshold (5%)
```

## Your Current Setup

```
Phone lines installed:

  Line 1: ide → VS Code integration (project scope)
    Tools: getDiagnostics, executeCode
    Installed automatically by VS Code extension

  Line 2: github → GitHub API (user scope) [Installed 2026-03-05]
    Transport: HTTP (remote — GitHub runs the server)
    URL: https://api.githubcopilot.com/mcp/
    Auth: OAuth (first use → browser login → done)
    Scope: user (all repos, all sessions on this machine)
    Config: ~/.claude.json
```

### GitHub MCP — How We Installed It

```bash
claude mcp add --transport http --scope user github https://api.githubcopilot.com/mcp/
```

Breaking it down:
- `--transport http` → remote server (GitHub runs the warehouse)
- `--scope user` → global phone line (all kitchens, all repos)
- `github` → the name we give this line (shows up as `mcp__github__*`)
- The URL → GitHub's MCP endpoint

### What You Can Do Now

```
"Show me all open PRs in amritviva/minihubvone"
"Create an issue in claude-lab for adding a Docker learning doc"
"What comments are on PR #5?"
"Search my repos for anything with 'viva' in the name"
```

### Key Things to Know

- **First use:** Claude will ask you to authenticate via OAuth (browser popup)
- **Per-machine:** New laptop = run the install command again
- **Any repo you own/can access:** Same permissions as your GitHub account
- **Cost:** Free. Uses your GitHub auth. Only costs tokens (whiteboard space)
- **Restart needed:** New session to see the GitHub tools

### Potential Lines to Add Next

```
Slack   → notifications, messages from Claude
Custom  → your own tools (DynamoDB queries, Postgres, etc.)
```

## Building a Custom Phone Line

You can build your own MCP server — a program that exposes tools via the protocol. This is how you'd give Claude direct access to your DynamoDB or Postgres without going through Bash.

But that's advanced. For now, installing pre-built servers (GitHub, Slack) is the quick win.
