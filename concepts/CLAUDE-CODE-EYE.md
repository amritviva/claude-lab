```
   minihubvone/
   ├── CLAUDE.md                          ← Project memory (shared via git)
   │                                        Full context: what MiniHub is, the AI chat
   │                                        feature, architecture decisions, domain model,
   │                                        soft delete patterns, related repos
   │
   ├── CLAUDE.local.md                    ← Your personal prefs (gitignored)
   │                                        Your name, timezone, local paths,
   │                                        communication preferences
   │
   ├── .claude/
   │   ├── settings.json                  ← Project settings
   │   └── rules/
   │       ├── 001-read-only.md           ← NEVER write to Postgres
   │       ├── 002-soft-delete.md         ← Always filter __hevo__marked_deleted / is_deleted
   │       ├── 003-location-scoping.md    ← Always scope queries to user's locations
   │       ├── 004-sensitive-data.md      ← Never expose card numbers, BSBs, tokens
   │       ├── 005-existing-code.md       ← Don't modify existing files, chat is additive
   │       ├── 006-patterns.md            ← Follow existing handler/service/DynamoDB patterns
   │       └── 007-chat-module.md         ← Chat-specific: Tool Use, DynamoDB tables, auth, prompts
   │
   ├── docs-internal/
   │   ├── AI-SUPPORT-CHAT-BRD.md        ← Business requirements (referenced from CLAUDE.md)
   │   ├── AI-LLM-INTEGRATION-GUIDE.md   ← How LLMs work
   │   ├── AI-CHAT-ARCHITECTURE.md       ← Knowledge base, playbooks, tools
   │   └── AI-CHAT-DYNAMODB-DESIGN.md    ← DynamoDB schema design
```
