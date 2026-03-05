# Claude Code Hooks — Reference Guide

> Hooks are user-defined scripts that execute automatically at specific lifecycle points. They give you **deterministic control** — guaranteed to run, not dependent on the LLM deciding to.

## Mental Model: Motion Sensors

Hooks are like **motion sensors** in a building:

- You place sensors at doors (lifecycle events)
- When someone passes through, the sensor triggers an action (your script)
- Some sensors sound an alarm and lock the door (blocking hooks, exit code 2)
- Others just log the event (non-blocking hooks, exit code 0)
- You choose which doors to monitor and what to trigger

---

## Hook Events (17 Total)

| Event | When It Fires | Can Block? | Matcher Filters |
|-------|---------------|-----------|----------------|
| `SessionStart` | Session begins or resumes | No | `startup`, `resume`, `clear`, `compact` |
| `UserPromptSubmit` | You submit a prompt, before Claude processes it | Yes | None (always fires) |
| `PreToolUse` | Before a tool call executes | Yes | Tool name (`Bash`, `Edit\|Write`, etc.) |
| `PermissionRequest` | When a permission dialog appears | Yes | Tool name |
| `PostToolUse` | After a tool call succeeds | No | Tool name |
| `PostToolUseFailure` | After a tool call fails | No | Tool name |
| `Notification` | Claude sends a notification (needs input) | No | `permission_prompt`, `idle_prompt` |
| `SubagentStart` | Subagent is spawned | No | Agent type |
| `SubagentStop` | Subagent finishes | Yes | Agent type |
| `Stop` | Claude finishes responding | Yes | None |
| `TeammateIdle` | Agent team teammate going idle | Yes | None |
| `TaskCompleted` | Task marked as completed | Yes | None |
| `ConfigChange` | Settings file changes during session | Yes | `user_settings`, `project_settings`, etc. |
| `WorktreeCreate` | Worktree being created | Yes | None |
| `WorktreeRemove` | Worktree being removed | No | None |
| `PreCompact` | Before context compaction | No | `manual`, `auto` |
| `SessionEnd` | Session terminates | No | `clear`, `logout`, etc. |

---

## Hook Types

### 1. Command Hooks (`type: "command"`)

Run a shell script. Input arrives on stdin as JSON. Communicate back via exit code + stdout/stderr.

```json
{
  "type": "command",
  "command": "jq -r '.tool_input.file_path' | xargs npx prettier --write"
}
```

**Best for:** Most use cases — formatting, validation, logging, blocking.

### 2. HTTP Hooks (`type: "http"`)

POST the event JSON to an HTTP endpoint. Response body contains decisions.

```json
{
  "type": "http",
  "url": "http://audit.company.local/hooks/tool-use",
  "timeout": 30,
  "headers": { "Authorization": "Bearer $AUDIT_TOKEN" },
  "allowedEnvVars": ["AUDIT_TOKEN"]
}
```

**Best for:** Centralized audit logging, webhooks, cloud functions.

### 3. Prompt Hooks (`type: "prompt"`)

Send a single-turn prompt to a Claude model for judgment-based decisions. Returns `{"ok": true}` or `{"ok": false, "reason": "..."}`.

```json
{
  "type": "prompt",
  "prompt": "Check if all tasks are complete. Respond with JSON.",
  "model": "claude-opus-4-6"
}
```

**Best for:** Decisions requiring judgment, not deterministic rules.

### 4. Agent Hooks (`type: "agent"`)

Spawn a subagent that can use tools (Read, Grep, Bash) to verify conditions. Longer timeout (60s default).

```json
{
  "type": "agent",
  "prompt": "Run the test suite and verify all tests pass.",
  "timeout": 120
}
```

**Best for:** Complex verification requiring file inspection or command execution.

---

## Configuration

### Where to Configure

| Location | Scope | Shared |
|----------|-------|--------|
| `~/.claude/settings.json` | All your projects | No |
| `.claude/settings.json` | This project | Yes (git) |
| `.claude/settings.local.json` | This project, you only | No |
| Managed policy | Organization-wide | Yes (IT-deployed) |
| Skill/agent frontmatter | While component active | Depends |

### Configuration Format

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path' | xargs npx prettier --write"
          }
        ]
      }
    ]
  }
}
```

### Using `/hooks` Command

Type `/hooks` to open the interactive hooks manager: view, add, delete, or toggle all hooks.

---

## Exit Codes

| Exit Code | Meaning | Effect |
|-----------|---------|--------|
| `0` | Success | Parse stdout for decisions/context |
| `2` | Block | Stop the action, send stderr to Claude as error |
| Other | Non-blocking error | Log stderr, continue normally |

### What Exit Code 2 Does Per Event

| Event | Effect of Exit 2 |
|-------|-------------------|
| `PreToolUse` | Blocks the tool call |
| `PermissionRequest` | Denies the permission |
| `UserPromptSubmit` | Blocks prompt processing, erases prompt |
| `Stop` | Prevents Claude from stopping — continues conversation |
| `TaskCompleted` | Prevents task from being marked complete |
| `WorktreeCreate` | Causes worktree creation to fail |
| `PostToolUse`, `Notification`, `SessionStart/End` | Non-blockable — stderr shown but action proceeds |

---

## Matchers

Matchers are **regex patterns** that filter when a hook fires.

### Examples

| Matcher | Matches |
|---------|---------|
| `Bash` | Bash tool only |
| `Edit\|Write` | Edit OR Write tool |
| `mcp__memory__.*` | All tools from Memory MCP server |
| `mcp__.*__write.*` | Any "write" tool from any MCP server |
| `""` or omitted | All occurrences |

Matchers are **case-sensitive**. `bash` won't match `Bash`.

---

## Hook Input (JSON on stdin)

All hooks receive JSON with common fields:

```json
{
  "session_id": "abc123",
  "cwd": "/home/user/my-project",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": { "command": "npm test" }
}
```

### Event-Specific Fields

| Event | Extra Fields |
|-------|-------------|
| `PreToolUse` | `tool_name`, `tool_input` |
| `PostToolUse` | `tool_name`, `tool_input`, `tool_output` |
| `UserPromptSubmit` | `prompt` |
| `SessionStart` | `source` (startup/resume/clear/compact) |
| `Stop` | `stop_hook_active` (true if Stop hook already triggered once) |

---

## Practical Examples

### 1. Auto-Format After Edits

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path' | xargs npx prettier --write"
          }
        ]
      }
    ]
  }
}
```

### 2. Block Edits to Protected Files

**Script:** `.claude/hooks/protect-files.sh`

```bash
#!/bin/bash
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

PROTECTED_PATTERNS=(".env" "package-lock.json" ".git/")

for pattern in "${PROTECTED_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    echo "Blocked: $FILE_PATH matches protected pattern '$pattern'" >&2
    exit 2
  fi
done

exit 0
```

**Config:**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/protect-files.sh" }
        ]
      }
    ]
  }
}
```

### 3. Desktop Notifications (macOS)

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

### 4. Re-inject Context After Compaction

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Reminder: Postgres is read-only. Always include soft-delete filters. Current sprint: AI chat module.'"
          }
        ]
      }
    ]
  }
}
```

### 5. Block Dangerous Bash Commands

```bash
#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

if echo "$COMMAND" | grep -iE '(DROP TABLE|TRUNCATE|rm -rf|git reset --hard|git push --force)'; then
  echo "Blocked: dangerous command" >&2
  exit 2
fi
exit 0
```

### 6. Verify Tests Before Stopping

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "agent",
            "prompt": "Run the test suite. If any fail, return {\"ok\": false, \"reason\": \"X tests failed\"}.",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

---

## UserPromptSubmit (Special Case)

This hook fires **before** Claude processes your prompt. Two special abilities:

1. **Block the prompt** — exit code 2 erases the prompt
2. **Inject context** — stdout (exit 0) is added as context for that turn

```bash
#!/bin/bash
# Inject reminder with every prompt
echo "Remember: Postgres is read-only. DynamoDB is source of truth."
exit 0
```

### Block Prompts Containing Secrets

```bash
#!/bin/bash
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt')

if echo "$PROMPT" | grep -iE '(password|api_key|secret)='; then
  echo "Prompt blocked: contains secret patterns" >&2
  exit 2
fi
exit 0
```

---

## Async Hooks

For long-running operations, run hooks in background:

```json
{
  "type": "command",
  "command": "npm run lint",
  "async": true,
  "timeout": 300
}
```

Execution continues immediately. Failures logged but don't block Claude.

---

## Preventing Infinite Stop Loops

If a `Stop` hook blocks Claude from stopping, check `stop_hook_active`:

```bash
#!/bin/bash
INPUT=$(cat)
if [ "$(echo "$INPUT" | jq -r '.stop_hook_active')" = "true" ]; then
  exit 0  # Allow Claude to stop (don't loop forever)
fi
# ... rest of hook logic
```

---

## Environment Variables in Hooks

| Variable | Available To |
|----------|-------------|
| `$CLAUDE_PROJECT_DIR` | All command hooks |
| `${CLAUDE_PLUGIN_ROOT}` | Plugin hooks |
| `$CLAUDE_CODE_REMOTE` | All hooks (set to "true" in web) |

HTTP hooks: only variables listed in `allowedEnvVars` are available.

---

## Security Best Practices

1. **Validate input** — Parse JSON safely with `jq`, not string operations
2. **Test locally first** — `echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | ./my-hook.sh`
3. **Use absolute paths** — `$CLAUDE_PROJECT_DIR/.claude/hooks/script.sh`
4. **Guard shell profile output** — Wrap `~/.zshrc` echoes in `if [[ $- == *i* ]]; then`
5. **Log sensitive operations** — Audit tool use in shared environments
6. **Use HTTPS for HTTP hooks** — Validate auth headers, rate-limit endpoints

---

## Our Setup (minihubvone)

### Currently Configured

#### 1. macOS Notification Hook ✅ (Implemented 2026-03-05)

**Event:** `Notification` — fires when Claude needs your input (permission prompt or idle)
**Location:** `~/.claude/settings.json` (global — works in all projects)
**What it does:** Pops a native macOS notification so you know Claude is waiting

```json
"hooks": {
  "Notification": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "osascript -e 'display notification \"Claude needs your attention\" with title \"Claude Code\"'"
        }
      ]
    }
  ]
}
```

**How we built it:**
1. Read existing `~/.claude/settings.json` to see what was there (permissions, statusLine, model)
2. Added `hooks` key with `Notification` event — no matcher needed (fires for all notification types)
3. Used `osascript` (macOS AppleScript runner) for native notifications
4. No exit code handling needed — this is non-blocking (just a notification, doesn't stop anything)

**Key learnings:**
- Simplest hook = one event + one inline command, no script file needed
- `osascript` is the macOS way to trigger native notifications from CLI
- No `matcher` means "fire for everything under this event"
- Non-blocking hook: exit 0 (default), no exit 2 logic needed

#### 2. Context Reminder After Compaction ✅ (Implemented 2026-03-05)

**Event:** `SessionStart` with `matcher: "compact"` — fires ONLY after context compaction
**Location:** `~/.claude/settings.json` (global — works in all projects)
**What it does:** Re-injects critical rules after Claude's memory gets compressed

```json
"SessionStart": [
  {
    "matcher": "compact",
    "hooks": [
      {
        "type": "command",
        "command": "echo 'COMPACTION REMINDER: Postgres is read-only replica. DynamoDB is source of truth. Never write to prod account. Current project context: AI chat module.'"
      }
    ]
  }
]
```

**How we built it:**
1. Identified the problem: compaction causes Claude to forget session-specific context
2. Used `SessionStart` event with `matcher: "compact"` to target only compaction (not startup/resume/clear)
3. Used `echo` — stdout from exit 0 hooks gets injected as context for Claude's next turn
4. No script file needed — inline `echo` is sufficient

**Key learnings:**
- `matcher` is a regex filter — only fires when the event source matches the pattern
- `SessionStart` has 4 sources: `startup`, `resume`, `clear`, `compact`
- **stdout = context injection** — this is how you "whisper" to Claude after compaction
- CLAUDE.md rules survive compaction automatically, but ad-hoc reminders don't — this hook fills that gap

**Difference from Hook #1:**
- Hook #1 output didn't matter (side effect only — macOS popup)
- Hook #2 output IS the point — the echoed text becomes Claude's context

#### 3. Block Protected Files ✅ (Implemented 2026-03-05)

**Event:** `PreToolUse` with `matcher: "Edit|Write"` — fires BEFORE any file edit/write
**Location:** `~/.claude/settings.json` (global) → points to script in claude-lab
**Script:** `~/Desktop/mrt_repo/claude-lab/experiments/hooks/protect-files.sh`
**What it does:** Checks if the file being edited matches a protected pattern. If yes → exit 2 (BLOCK).

**Settings config:**
```json
"PreToolUse": [
  {
    "matcher": "Edit|Write",
    "hooks": [
      {
        "type": "command",
        "command": "/Users/amrit.regmi/Desktop/mrt_repo/claude-lab/experiments/hooks/protect-files.sh"
      }
    ]
  }
]
```

**Protected patterns:**
`.env`, `package-lock.json`, `yarn.lock`, `.git/`, `credentials`, `secrets`, `id_rsa`, `id_ed25519`, `.pem`

**How we built it:**
1. Created a bash script (needed logic — can't do if/then in a one-liner)
2. Script reads JSON from stdin (`INPUT=$(cat)`) — Claude pipes tool info as JSON
3. Extracts file path with `jq -r '.tool_input.file_path // empty'`
4. Loops through protected patterns, checks if file path contains any
5. If match → `echo "reason" >&2` + `exit 2` (block)
6. If no match → `exit 0` (allow)
7. Made script executable with `chmod +x`
8. Tested locally by piping fake JSON into the script
9. Wired it into settings.json under `PreToolUse` with `matcher: "Edit|Write"`

**Key learnings:**
- **stdin** = JSON note slipped under the door. Claude tells the hook what it's trying to do
- **`cat`** reads everything from stdin into a variable
- **`jq`** parses JSON — essential for hooks that need to inspect tool inputs
- **exit 2** = the ONLY exit code that blocks an action. All other codes allow it
- **stderr (`>&2`)** = where you write the reason. Claude sees this as the error message
- **PreToolUse vs PostToolUse**: Pre = bouncer (blocks BEFORE). Post = janitor (reacts AFTER)
- **Testing locally**: `echo '{"tool_input":{"file_path":".env"}}' | ./script.sh` simulates what Claude does
- **`chmod +x`** = required or the script can't execute

**Test results:**
```
.env       → BLOCKED (exit 2) ✅
index.ts   → Allowed (exit 0) ✅
```

---

### Recommended Hooks to Add (Next)

| Hook | Event | Purpose | Difficulty |
|------|-------|---------|------------|
| Auto-format | `PostToolUse` (Edit\|Write) | Run Prettier on edited files | Intermediate |
| Dangerous command guard | `PreToolUse` (Bash) | Extra layer beyond permission denies | Advanced |

### Priority
- **Low:** Auto-format, dangerous command guard (already covered by permission denies)
