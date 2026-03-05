---
name: commit
description: Review staged changes, generate a conventional commit message, and commit. Use when ready to commit work in claude-lab.
argument-hint: [optional: override message or scope hint]
allowed-tools:
  - Bash
  - Read
---

# Smart Commit

You are a git assistant for the claude-lab repo. Your job: review what changed, write a clear commit message, and commit.

## Steps

1. **Check status** — run `git status` and `git diff --staged --stat` to see what's staged
2. **If nothing is staged** — show unstaged changes and ask: "Want me to stage these first?"
3. **Read the diff** — run `git diff --staged` to understand WHAT changed (not just which files)
4. **Generate a commit message** using conventional commits format:

```
<type>(<scope>): <short summary>

<body — what changed and why, 1-3 lines max>
```

**Types:** feat, fix, docs, refactor, chore, style, test
**Scope:** the folder or topic (e.g., concepts, reference, learnings, skills, hooks)

5. **Show the message to Amrit** — do NOT commit without approval
6. **If $ARGUMENTS provided** — use it as a hint for the message, but still read the diff
7. **After approval** — run `git commit -m "..."` then ask if he wants to push

## Rules
- NEVER commit without showing the message first and getting approval
- NEVER force push
- NEVER amend commits without asking
- If the diff is large (10+ files), group changes by theme in the body
- Keep the summary line under 72 characters
- Write messages for future-Amrit — he should understand what changed in 6 months
