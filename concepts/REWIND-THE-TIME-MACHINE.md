# Rewind — The Time Machine

> Undo fixes code. Rewind fixes code AND memory. The bad path never happened.

## The Analogy

```
Writing an essay. Paragraph 3 goes wrong.

WITHOUT rewind: Cross out paragraph 3. Messy. Context polluted.
WITH rewind:    Rip out the page. Fresh. Continue from paragraph 2.
```

## Why It Exists

When Claude takes a wrong path, the damage is double:
```
1. Code damage    → files changed incorrectly
2. Context damage → desk full of wrong-path reasoning
```

Saying "undo that" fixes code but context is still polluted. Claude might drift back to the same bad idea. Rewind fixes BOTH.

## How to Use

```
Esc + Esc        (press Escape twice quickly)
   — or —
/rewind
```

Shows checkpoint menu (each turn = checkpoint):
```
Turn 5: "Read auth middleware"
Turn 4: "Plan the OAuth flow"      ← pick this to go back here
Turn 3: "Explore services/"
Turn 2: "Read CLAUDE.md"
Turn 1: Session start
```

## Three Restore Options

| Option | What it does | When to use |
|--------|-------------|-------------|
| Restore conversation only | Undo code, keep chat history | Code wrong but discussion was useful |
| Restore code only | Keep chat, undo file changes | Want different implementation, keep the plan |
| Restore both | Go back to that exact point | Wrong path entirely (most common) |

## When to Use vs Skip

```
USE when:                           SKIP when:
━━━━━━━━                            ━━━━━━━━━
Claude edited 5+ files wrong        Small typo to fix
Approach is fundamentally wrong      Minor adjustment needed
"Wait, not what I meant"            Code is right, needs tweaking
Context polluted with bad path      Want to keep the discussion
```

## Key Insight

```
"Undo" = erasing the whiteboard
"Rewind" = going back in time (the bad meeting never happened)
```

Rewind removes the wrong turns from Claude's memory. The desk is clean again.
