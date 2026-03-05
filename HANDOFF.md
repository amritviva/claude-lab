# Handoff — Claude Lab

> Read this at the START of every new session to pick up where we left off.

## Last Session: Session 3 (2026-03-05)

### What We Did
1. **Fixed GitHub MCP** — old HTTP/OAuth was broken, swapped to stdio (`gh mcp` via `shuymn/gh-mcp` extension)
2. **Created keybindings** — `~/.claude/keybindings.json` with Ctrl+K chords for commit/explain/pg-query + Ctrl+P for plan mode
3. **Completed Brown Belt** — all 18 concepts documented in 11 concept docs
4. **Updated minihub CLAUDE.md** with:
   - Verification rules (always-on)
   - Interview rule (auto-triggers on "I want to build...")
   - 6-step workflow: Interview → Trace → Plan → Reference → Build → Verify
   - Session handoff rule (HANDOFF-CHAT.md)
   - Black Belt training section with 10 challenges + coaching rules
5. **Created `CLAUDE-CODE-STRATEGY.md`** in minihub docs-internal/

### Current State
- **Belt Status:** White ✅ → Yellow ✅ → Green ✅ → Blue ✅ → Brown ✅ → **Black Belt NEXT**
- **Black Belt:** 0/10 challenges — all hands-on, tracked in minihub CLAUDE.md
- **Tracker file:** `BELT-TRACKER.md` (full progress + summary + cheat card)
- **Context usage this session:** 109K/1M (11%) — plenty of room left

### Concept Docs Created (11 total this session)
- `PLAN-MODE-THE-WAR-ROOM.md`
- `VERIFICATION-THE-EYES.md`
- `INTERVIEW-THE-CONSULTANT.md`
- `POWERPOINT-TRACE-THE-SLIDES.md`
- `REFERENCE-PATTERNS-THE-HOMEWORK.md`
- `CONTEXT-THE-DESK.md`
- `SESSION-BRIDGES-THE-HANDOFF.md`
- `REWIND-THE-TIME-MACHINE.md`
- `ADVANCED-MODES-THE-HEAVY-WEAPONS.md`
- `DECISION-TREE-WHICH-WEAPON.md`
- `CLAUDEMD-VS-MESSAGE-RULEBOOK-VS-STICKY.md`

### What's Next
- **Black Belt** unlocks in minihub — build chat tools using the full workflow
- First task: search_member tool using Interview → Plan → Build pattern
- Build `chat-builder.md` per-topic agent when starting chat implementation
- Push commits to remote (3 commits unpushed on main)

### Commits This Session (unpushed)
```
42be38e docs(concepts): add Brown Belt concept docs + belt tracker
c597b66 docs(concepts): complete Brown Belt — all 18 concepts documented
9d28ea9 docs: mark Brown Belt as DONE, Black Belt as NEXT
```
