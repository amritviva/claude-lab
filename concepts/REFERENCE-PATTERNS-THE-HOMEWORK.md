# Reference Existing Patterns — Copy the Good Kid's Homework

> Point Claude to existing code. It'll match the style perfectly.

## The Analogy

```
First day at a new job:

BAD:  Boss says "write a report" → you invent your own format → "not how we do it"
GOOD: Boss says "write a report" → you ask for an example → follow the format → "perfect"
```

Your codebase already has working patterns. Don't let Claude invent its own style — point it to an example.

## How It Works

```
Bad:   "Create a handler for chat messages"

Good:  "Create a handler for POST /api/chat/message.
        Follow the exact pattern in:
        app/src/routes/api/handlers/payment.handler.ts
        Same structure, same error handling, same auth pattern."
```

Claude reads the reference, extracts the pattern (imports, validation, try/catch, response format), and applies it. The result looks like the same developer wrote both.

## Minihub Reference Files

```
For new handlers:   Follow handlers/payment.handler.ts
For new services:   Follow services/chargeback-service.ts
For new queries:    Follow queries/member-transactions.ts
For new routes:     Follow routes-registry.ts (add entry)
```

## Prompt Patterns

### New handler:
```
"Add GET /api/chat/history handler.
 Follow the pattern in handlers/payment.handler.ts."
```

### New service:
```
"Create chat-session.service.ts.
 Follow services/chargeback-service.ts.
 Same structure: validate → query → transform → return."
```

### New query:
```
"Write the member search SQL.
 Follow the style in queries/member-transactions.ts."
```

### Consistency check:
```
"Compare my new handler against payment.handler.ts.
 List differences in structure or patterns. Fix them."
```

## Why It Matters

```
Without reference:  Claude writes correct code in ITS style
With reference:     Claude writes correct code in YOUR CODEBASE'S style
```

Both work. But one produces code that belongs, the other creates style drift.

## Combining with Other Patterns

```
Interview:    "What should this feature do?"             (decisions)
Trace:        "Walk through the request flow"             (visibility)
Plan Mode:    "Plan the implementation"                   (strategy)
Reference:    "Follow the pattern in payment.handler.ts"  (consistency)
Build:        "Implement it"                              (action)
Verify:       "Run tests, compare against reference"      (proof)
```
