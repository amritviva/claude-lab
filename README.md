# claude-lab

**Amrit Regmi's portable brain** — personal knowledge base, learning docs, and experimentation repo for Claude Code and software engineering.

## Why This Exists

Learning materials shouldn't live scattered across work repos. This repo is the single source of truth for:
- **What I know** — documented learnings from real projects
- **How I think** — mental models, analogies, visual frameworks
- **What I've mastered** — Claude Code features, AWS, TypeScript, APIs
- **Where my gaps are** — so Claude can teach at the right level

When I open a Claude session here — even with a new API key, new company, or new laptop — Claude immediately knows me: my style, my knowledge, my gaps, and how to help me best.

## Structure

```
claude-lab/
│
├── concepts/                    Mental models & deep dives
│   ├── CLAUDE-THE-KITCHEN.md    Kitchen analogy for how Claude Code works
│   ├── CLAUDE-SESSIONS-AND-AGENTS.md   Sessions, context, multi-project agents
│   ├── CLAUDE-CODE-EYE.md       Visual map of Claude Code's file structure
│   └── DEEP-DIVE-LLM-AGENT-LEVELS.md  10 levels of agent architecture
│
├── reference/                   Claude Code feature reference
│   ├── SKILLS.md                Skills system (SKILL.md, discovery, invocation)
│   ├── MEMORY-SYSTEM.md         CLAUDE.md scopes, rules, auto-memory, @imports
│   ├── TOOLS-AND-AGENTS.md      All tools, subagents, MCP, agent teams
│   ├── HOOKS.md                 Hook events, types, configuration
│   ├── PROMPTING-STRATEGIES.md  Plan mode, batch, verification patterns
│   └── SETUP-CHECKLIST.md       Setup report card & action items
│
├── learnings/
│   ├── devops/                  Docker, CI/CD, deployments, cron jobs, env vars
│   │   ├── DOCKER-EXPLAINED.md
│   │   ├── CICD-EXPLAINED.md
│   │   ├── DEPLOYMENT-SUMMARY-EXPLAINED.md
│   │   ├── MANUAL-DEPLOYMENT-EXPLAINED.md
│   │   ├── PRE-DEPLOYMENT-CHECKLIST-EXPLAINED.md
│   │   ├── HEALTH-CHECK-EXPLAINED.md
│   │   ├── CRON-JOBS-GUIDE-EXPLAINED.md
│   │   ├── CRON-NOTIFICATION-FLOW-EXPLAINED.md
│   │   ├── ENV-VARIABLES-EXPLAINED.md
│   │   ├── SETUP-HUSKY-EXPLAINED.md
│   │   ├── WORKSPACES-EXPLAINED.md
│   │   ├── POSTMAN-SETUP-EXPLAINED.md
│   │   └── UPDATE-GITHUB-SECRETS-EXPLAINED.md
│   │
│   ├── api-design/              API patterns, naming, versioning, architecture
│   │   ├── API-KEYS-GUIDE-EXPLAINED.md
│   │   ├── API-NAMING-CONVENTIONS-EXPLAINED.md
│   │   ├── API-VERSIONING-GUIDE-EXPLAINED.md
│   │   ├── ARCHITECTURE-EXPLAINED.md
│   │   ├── ADDING-PACKAGES-EXPLAINED.md
│   │   └── HOW-TO-CREATE-API-KEYS-EXPLAINED.md
│   │
│   ├── aws/                     CDK, DynamoDB walkthroughs
│   │   ├── CDK-VERIFICATION-EXPLAINED.md
│   │   ├── VIVA-WALK-THROUGH-DYNAMO.md
│   │   └── WALK-LIKE-DYNAMODB.md
│   │
│   └── ai-chat-project/         Full AI chat feature documentation
│       ├── AI-SUPPORT-CHAT-BRD.md
│       ├── AI-CHAT-ARCHITECTURE.md
│       ├── AI-CHAT-DYNAMODB-DESIGN.md
│       ├── AI-LLM-INTEGRATION-GUIDE.md
│       ├── CHAT-TABLE-DESIGN.md
│       └── USER-STORIES.md
│
├── experiments/                 Sandbox for testing skills, hooks, agents
│   ├── skills/hello-world/      Starter example skill
│   ├── hooks/                   Hook scripts to test
│   └── agents/                  Agent definitions to test
│
└── .claude/
    └── rules/lab-rules.md       Safety rules for experimentation
```

## Usage

```bash
# Work directly in the lab
cd ~/Desktop/mrt_repo/claude-lab && claude

# Reference from any other project
claude --add-dir ~/Desktop/mrt_repo/claude-lab
```

## Origin

These docs were written while building production systems (gym management platform, 270+ locations). Moved here from work repo `docs-internal/` to separate personal learning from office project code — so the knowledge travels with me, not with the company repo.
