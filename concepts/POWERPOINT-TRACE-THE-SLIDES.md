# PowerPoint Trace — The Slide Deck

> Walk through a request flow one hop at a time, like presenting slides to your boss.

## The Analogy

```
Present a request flow as SLIDES — one step per slide:

  Slide 1: User clicks "Search Member"
  Slide 2: Frontend calls POST /api/chat/message
  Slide 3: Handler validates JWT, extracts locationIds
  Slide 4: LLM receives message + tool definitions
  Slide 5: LLM decides to call search_member tool
  Slide 6: Tool runs parameterised SQL query
  Slide 7: Results returned to LLM
  Slide 8: LLM formats human-readable answer
  Slide 9: Response sent back to frontend
```

Each slide = one hop. You can SEE the full journey.

## Why It Matters

A single chat message in minihub touches:
```
vivareact → minihubvone → Anthropic LLM → Postgres/DynamoDB → back through all layers
```

Without a trace: you hold this in your head. Bugs hide in the gaps between layers.
With a trace: every hop is visible. Gaps are obvious.

## The Prompt

```
"Walk me through a request as if presenting slides.

Trace: staff member asks 'show me John Smith's payments'

Start: user types in chat window (vivareact)
End:   payment list displayed in chat

For each slide:
- Where the code is (file:line)
- What it does
- What data passes to the next step
- What could go wrong"
```

## When to Use vs Skip

```
USE when:                           SKIP when:
━━━━━━━━                            ━━━━━━━━━
Debugging across multiple layers    Bug is in one file
Onboarding to unfamiliar code       You wrote the code
Planning a new feature flow         Simple CRUD
Reviewing for security gaps         Adding a config value
Before a big refactor               Renaming a variable
```

## The Power Move: Trace BEFORE Building

Before building a feature, trace the flow and flag what doesn't exist yet:

```
"Trace: user asks 'find member John Smith'
 Show every step from React to database and back.
 Flag anything that doesn't exist yet."

Claude: "Slide 3: cognitoAuth middleware
         → STATUS: ❌ DOESN'T EXIST YET

         Slide 5: search_member tool
         → STATUS: ❌ DOESN'T EXIST YET

         Slide 6: SQL query for member search
         → STATUS: ❌ MISSING"
```

Every "doesn't exist" slide = a task. You now have a build list.

## Combining with Other Patterns

```
Interview:    "What should this feature do?"          (decisions)
Trace:        "Walk me through the full request flow"  (visibility)
Plan Mode:    "Plan the implementation"                (strategy)
Build:        "Implement it"                           (action)
Verification: "Run tests, verify it works"             (confirmation)
```

Five layers of "measure before you cut."
