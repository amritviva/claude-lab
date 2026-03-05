# Interview Pattern — Let Claude Be the Consultant

> Don't write a massive prompt. Let Claude ask the hard questions.

## The Analogy

```
BAD architect:                      GOOD architect:
━━━━━━━━━━━━━                       ━━━━━━━━━━━━━━
You: "I want a house"               You: "I want a house"
*immediately starts drawing*         "Before I draw —
Result: 3 beds (needed 5),            How many people?
no garage, wrong style                Work from home?
                                      How many cars?
                                      Budget? Style?"
                                    Result: Exactly right, first time
```

The good architect interviews you before touching paper.

## How It Works

Give Claude a brief description + say "interview me":

```
You:    "I want to build the AI chat system for minihub.
         Interview me about it. Ask about implementation,
         edge cases, security, and tradeoffs.
         Keep going until we've covered everything."

Claude: "Let me dig in:
         1. Who are the users — all staff or specific roles?
         2. Should chat history persist across sessions?
         3. What happens when a tool returns no results?
         4. Rate limiting — per user? Per location?
         5. Can staff ask about members at OTHER locations?"

You:    [Answer each one]

Claude: "Follow-ups:
         6. Area managers who oversee 10 locations?
         7. Tool query timeout — retry or apologise?
         8. Log questions the system couldn't answer?"

[...3-4 rounds...]

Claude: "Complete picture. Writing spec."
        → Writes SPEC.md
```

## Why It's Powerful

```
Traditional:                        Interview:
━━━━━━━━━━━━                        ━━━━━━━━━━
YOU think of everything             CLAUDE asks the hard questions
You miss edge cases                 Claude probes the gaps
Huge prompt upfront                 Short answers to focused questions
Gaps found mid-build                Gaps found before code is written
Cost: rework                        Cost: 10 minutes of Q&A
```

You know your business deeply but can't think of everything upfront. Claude has seen thousands of systems — it knows which questions to ask.

## The Prompt Template

```
"I want to build [brief description].

Interview me in detail. Ask about:
- Implementation approach
- Edge cases and error handling
- Security and access control
- Performance and scaling
- User experience

Don't ask obvious questions — dig into the hard parts.
Keep interviewing until we've covered everything,
then write a complete spec to SPEC.md."
```

## When to Use vs Skip

```
USE when:                           SKIP when:
━━━━━━━━                            ━━━━━━━━━
New feature with unknowns           Bug fix
Vision but not details              Fully specified task
Multiple decisions to make          Following existing pattern
Want to catch edge cases early      Simple CRUD
Starting a BRD or architecture      Adding a field
```

## Real Example: Chat Tool Design

```
You:    "Building search_member tool. Interview me about edge cases."

Claude: "1. Partial name search? How fuzzy?
         2. 50 matches for 'John Smith' — paginate or cap?
         3. All locations or just theirs?
         4. Inactive members — show or hide?
         5. Full profile or summary fields?
         6. Can LLM chain: search → get_transactions?
         7. Sensitive notes — appear in results?"

Every answer = a design decision made BEFORE code exists.
Every decision = a rework prevented.
```

## Combining with Plan Mode

```
Phase 1: Interview (Normal Mode)
  "Interview me about the search_member tool"
  → 3-4 rounds of Q&A
  → Claude writes spec

Phase 2: Plan (Plan Mode — Shift+Tab)
  "Based on the spec, plan the implementation"
  → Claude reads codebase, proposes approach

Phase 3: Build (Normal Mode — Shift+Tab)
  "Implement it"
  → Clean implementation, no wrong turns
```

Interview → Plan → Build. Questions → Strategy → Action.
