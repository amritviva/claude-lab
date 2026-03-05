# CLAUDE.md — Amrit's Brain (Portable Knowledge Base)

## Who Am I?

**Name:** Amrit Regmi
**Based in:** Sydney, Australia (AEST/AEDT)
**Machine:** macOS Apple Silicon, Node.js v25.6.1

## Why This Repo Exists

This is my **portable brain**. When I start a Claude session here — even with a new API key, new company, or new machine — you should immediately know:
- Who I am and how I think
- What I already know (and where the gaps are)
- How to teach me new things effectively
- What I've built before so you don't re-explain basics

**Think of it as:** My memory shelf. Everything I've learned, organised so you can pick up right where I left off — anywhere, anytime.

## How I Learn (IMPORTANT — Follow This)

- **First principles thinker** — I reason from analogies to architecture. Don't skip the "why."
- **Visual mental models** — Explain with diagrams, analogies (kitchen, office, war room, city), and `code` blocks. Not walls of text.
- **Real-life analogies first** — Before technical jargon, ground it in something physical I can picture.
- **Show me the landscape, then let me pick what to build** — I'm a systems thinker. I need the full picture before zooming in.
- **Be direct** — No filler phrases, no "Great question!", no hedging. Just tell me.
- **Explain the "why" not just the "how"** — I won't accept "just do X" without understanding the reasoning.
- **When uncertain, ask** — Don't guess what I want. Ask first.

## What I Know (My Current Knowledge Level)

### Strong Areas
- **TypeScript / Node.js / Express** — daily driver, comfortable building APIs from scratch
- **AWS ecosystem** — DynamoDB, Lambda, App Runner, Cognito, S3, CloudWatch, Secrets Manager
- **PostgreSQL** — complex queries, JOINs, Prisma ORM, parameterised queries
- **Claude Code** — advanced user: rules, memory, skills, hooks, subagents, multi-project agents, plan mode
- **LLM Agent Architecture** — studied all 10 levels from dump-everything to continuous learning agent
- **DynamoDB design** — single-table design, GSIs, access patterns, TTL
- **CI/CD** — GitHub Actions, Docker, AWS App Runner deployments
- **Cognito auth** — JWT validation, user pools, groups (L0-L5), custom attributes

### Growing Areas (Teach at Intermediate Level)
- **CDK / CloudFormation** — can read and verify, learning to write from scratch
- **React** — can read components, understand hooks, building towards full ownership
- **GraphQL / AppSync** — understand the concepts, haven't built resolvers myself
- **Docker** — understand images/containers/compose, learning multi-stage builds
- **Knowledge graphs** — built one (1,226 nodes, 2,938 edges), learning traversal patterns

### Gaps (Teach from Fundamentals)
- **Kubernetes** — know what it is, haven't used it
- **Terraform** — zero hands-on, know it's IaC
- **Frontend testing** — Jest basics, no deep experience with React Testing Library
- **WebSockets / real-time** — conceptual understanding only
- **ML/AI model training** — I use LLMs, I don't train them

## What I've Built (Portfolio Context)

### AI Support Chat System (In Progress)
- LLM-powered support chatbot using Anthropic Claude via Tool Use
- Architecture: LLM routes questions → calls pre-built tools → returns answers
- LLM never writes SQL — it calls typed functions that run pre-written queries
- Full docs in `learnings/ai-chat-project/`

### Knowledge Graph (Complete)
- 1,226 nodes, 2,938 edges across multiple repos
- SCOUT + SAGE two-agent query system
- Maps: endpoints, handlers, services, cron jobs, DB tables, Prisma models

### Production API
- Express/TypeScript API with 12 endpoints, 10 handlers, 15 services, 7 cron jobs
- Runs on AWS App Runner

## Repo Structure

```
claude-lab/
├── CLAUDE.md                    ← YOU ARE HERE — my identity + knowledge map
├── README.md                    ← Repo overview
│
├── concepts/                    ← Mental models & deep dives
│   ├── CLAUDE-THE-KITCHEN.md    ← Kitchen analogy for Claude Code
│   ├── CLAUDE-SESSIONS-AND-AGENTS.md ← Sessions, turns, multi-project agents
│   ├── CLAUDE-CODE-EYE.md       ← Visual map of Claude Code structure
│   └── DEEP-DIVE-LLM-AGENT-LEVELS.md ← All 10 agent architecture levels
│
├── reference/                   ← Claude Code feature reference
│   ├── SKILLS.md                ← Skills system
│   ├── MEMORY-SYSTEM.md         ← CLAUDE.md, rules, auto-memory, @imports
│   ├── TOOLS-AND-AGENTS.md      ← All tools, subagents, MCP, agent teams
│   ├── HOOKS.md                 ← Hook events, types, examples
│   ├── PROMPTING-STRATEGIES.md  ← Plan mode, batch, verification patterns
│   └── SETUP-CHECKLIST.md       ← Setup report card + action items
│
├── learnings/
│   ├── devops/                  ← Docker, CI/CD, deployments, cron, env vars
│   ├── api-design/              ← API keys, naming, versioning, architecture
│   ├── aws/                     ← CDK, DynamoDB walkthroughs
│   └── ai-chat-project/         ← Full AI chat feature docs (BRD, architecture, DynamoDB design)
│
├── experiments/                 ← Sandbox for testing
│   ├── skills/                  ← Experimental skill definitions
│   ├── hooks/                   ← Hook scripts to test
│   └── agents/                  ← Agent definitions to test
│
└── .claude/
    └── rules/
        └── lab-rules.md         ← Safety rules for experiments
```

## How to Use This Repo

**When working in claude-lab directly:**
```bash
cd ~/Desktop/mrt_repo/claude-lab && claude
```
You'll have full context of who I am and everything I've learned.

**When referencing from another project:**
```bash
claude --add-dir ~/Desktop/mrt_repo/claude-lab
```

## When I Ask You Something Here

1. **Check my knowledge level** — Read the "What I Know" section above before explaining
2. **Read relevant learnings/** — If I ask about Docker, read `learnings/devops/DOCKER-EXPLAINED.md` first to see what I already understand
3. **Build on what I know** — Don't re-explain things I've already documented
4. **Fill gaps with analogies** — Use the style from `concepts/` — that's how I learn best
5. **Update docs when we learn** — If we cover new ground, add it to the right folder

## My Communication Preferences

- Short, direct answers unless I ask for depth
- Code blocks over prose
- Diagrams (ASCII) over descriptions
- Real examples over abstract explanations
- Ask me if you're unsure — don't assume
