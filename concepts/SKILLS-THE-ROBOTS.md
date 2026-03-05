# Skills = Specialist Robots

## The Analogy

You have a team of specialist robots. Each one is trained for **one job** and does it well. You don't explain the job every time — you just call the robot by name and hand it the input.

```
You:    "/commit"
Robot:  *reads your changes, writes a message, asks before committing*

You:    "/explain DynamoDB single table"
Robot:  *breaks it down with analogies and ASCII diagrams*
```

No small talk. No confusion. The robot knows its job because you wrote its instruction manual once.

## Your Robot Team

```
┌──────────────────────────────────────────────────────────────┐
│                     THE ROBOT TEAM                            │
│                                                              │
│  /explain          — The Teacher Robot                        │
│     Takes anything → explains with analogies + diagrams       │
│     Tools: unrestricted (can read, search, anything)          │
│     Lives: everywhere (personal scope)                        │
│                                                              │
│  /pg-query-review  — The Inspector Robot                      │
│     Takes a query → finds security, performance, correctness  │
│     Tools: Read, Glob, Grep only (LOOK but don't TOUCH)       │
│     Lives: everywhere (personal scope)                        │
│                                                              │
│  /commit           — The Git Robot                            │
│     Takes your changes → writes commit message → asks → commits│
│     Tools: Bash, Read only (git commands + read files)         │
│     Lives: claude-lab (project scope)                         │
│                                                              │
│  /chat-tool        — The Scaffolding Robot                    │
│     Takes a tool name → generates full tool file + registry    │
│     Tools: Read, Write, Glob, Grep (needs Write to create)    │
│     Lives: minihubvone only (project scope)                   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Anatomy of a Robot

Every robot is defined by a single file: `SKILL.md`

```
SKILL.md = The robot's instruction manual

┌─────────────────────────────────────────┐
│  --- (frontmatter)                      │
│  name: commit          ← robot's name   │
│  description: ...      ← when to call it│
│  argument-hint: ...    ← what to hand it│
│  allowed-tools:        ← what it can use│
│    - Bash                               │
│    - Read                               │
│  ---                                    │
│                                         │
│  # Instructions        ← the job spec   │
│  ## Steps              ← step-by-step   │
│  ## Rules              ← boundaries     │
└─────────────────────────────────────────┘
```

## Key Concepts Mapped to the Analogy

| Concept | Robot Analogy |
|---------|--------------|
| `SKILL.md` | The robot's instruction manual |
| `allowed-tools` | What tools the robot is allowed to pick up |
| `$ARGUMENTS` | What you hand the robot when you call it |
| `Personal scope` | Robot follows you to every workshop |
| `Project scope` | Robot stays in one specific workshop |
| Frontmatter `name` | The robot's name (how you call it) |
| Frontmatter `description` | When the robot should be activated |

## Where Robots Live

```
Personal robots (follow you everywhere):
  ~/.claude/skills/
    explain/SKILL.md
    pg-query-review/SKILL.md

Project robots (stay in their workshop):
  ~/Desktop/mrt_repo/claude-lab/.claude/skills/
    commit/SKILL.md

  ~/Desktop/viva/minihubvone/.claude/skills/
    chat-tool/SKILL.md
```

## Building a New Robot

1. Pick the scope — does it belong everywhere or just one project?
2. Create `SKILL.md` in the right location
3. Write the frontmatter (name, tools, description)
4. Write the instructions (steps, rules, output format)
5. Restart session (robots load at startup)
6. Call it: `/robot-name arguments`
