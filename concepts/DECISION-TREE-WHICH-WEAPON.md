# Decision Tree — Which Weapon?

> One mental flowchart. Don't memorise features — follow the tree.

## Step 1: How Big Is the Task?

```
                    ┌─────────────────────┐
                    │  How big is the task? │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                 ▼
         ONE thing        SEVERAL things     MANY things
         (1-2 files)      (3-10 files)       (10+ files, same pattern)
              │                │                 │
              ▼                ▼                 ▼
         Just do it.      Plan Mode          /batch
         Normal Mode.     (war room first)   (assembly line)
```

## Step 2: Am I Doing More Than One Thing?

```
         ┌──────────────────────────────┐
         │ Multiple tasks in parallel?   │
         └──────────┬───────────────────┘
                    │
         ┌──────────┼──────────┐
         ▼          ▼          ▼
        NO       YES, same    YES, different
                 branch       branches
         │          │            │
         ▼          ▼            ▼
     Normal     Background    Worktree
     (one       (Ctrl+B       (--worktree
      thing      tests while   separate
      at a       you code)     desks)
      time)
```

## Step 3: Is This a Multi-Step Project?

```
         ┌───────────────────────────┐
         │  More than 3 steps?       │
         └──────────┬────────────────┘
                    │
              ┌─────┼─────┐
              ▼           ▼
             NO          YES
              │           │
              ▼           ▼
         Just do it.   Task list (Ctrl+T)
                       + handoff doc at end
```

## The Cheat Card

```
┌─────────────────────────────────────────────────────┐
│  CLAUDE CODE — WHICH WEAPON?                        │
│                                                     │
│  Small (1-2 files)     → Just do it (Normal Mode)   │
│  Medium (3-10 files)   → Plan Mode first (Shift+Tab)│
│  Large (10+ same)      → /batch (assembly line)     │
│                                                     │
│  Running tests?        → Ctrl+B (background)        │
│  Two features?         → --worktree (parallel desk) │
│  Multi-step project?   → Ctrl+T (task list)         │
│                                                     │
│  New feature?          → Interview → Trace → Plan   │
│  Wrong path?           → Esc+Esc (rewind)           │
│  New session?          → Read HANDOFF.md first      │
│  End session?          → "update handoff"           │
│  Switching tasks?      → /clear                     │
│  Context heavy?        → /compact                   │
│  Need research?        → Subagent (send an intern)  │
└─────────────────────────────────────────────────────┘
```

## Quick Reference: All Shortcuts

| Shortcut | Action |
|----------|--------|
| Shift+Tab | Cycle modes: Normal → Auto → Plan |
| Ctrl+B | Send task to background |
| Ctrl+T | Toggle task list |
| Ctrl+P | Toggle plan mode (custom keybinding) |
| Ctrl+K, Ctrl+C | /commit (custom keybinding) |
| Ctrl+K, Ctrl+E | /explain (custom keybinding) |
| Ctrl+K, Ctrl+Q | /pg-query-review (custom keybinding) |
| Esc+Esc | Rewind (time machine) |
| Alt+P | Switch model |
| Alt+T | Toggle extended thinking |

## Quick Reference: All Slash Commands

| Command | When to Use |
|---------|-------------|
| /clear | Switching to unrelated task |
| /compact | Context getting heavy mid-task |
| /context | Check how full your desk is |
| /cost | See token usage and spend |
| /plan | Enter plan mode |
| /batch | Large-scale parallel changes |
| /diff | Review changes before committing |
| /rewind | Go back to a checkpoint |
| /model | Switch model (opus ↔ sonnet ↔ haiku) |
| /memory | View/edit memory files |
