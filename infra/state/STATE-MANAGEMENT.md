# Workspace State Management

## Problem

Agent sessions are ephemeral. Without persistent state:
- Sessions start cold every time
- Lessons are lost
- Context is rebuilt from scratch (expensive)

## Three Layers of State

### 1. Hot Memory (permanent patterns, bounded)

Per-workspace file with curated, high-signal entries. Budget: 3000 chars.

```markdown
---
workspace: <name>
budget: 3000
char-count: <count>
updated: <ISO timestamp>
---

## Agent Memory

- <Pattern 1 — reusable across sessions>
- <Pattern 2 — footgun to avoid>
- <Shipped feature — version, date>
```

**Operations:**
```bash
hot-memory.sh add "<entry>" <workspace>
hot-memory.sh replace "<old>" "<new>" <workspace>
hot-memory.sh remove "<entry>" <workspace>
```

**Rules:**
- Entries are permanent patterns, not session state
- Trim aggressively — if it's not useful in EVERY session, remove it
- Never duplicate between hot memory and memo

### 2. Memo (transient session state)

What's being worked on RIGHT NOW. Replaced (not appended) each session.

```markdown
---
workspace: <name>
updated: <ISO timestamp>
---

# Memo: <name>

## Current Focus
<What's being worked on — specific, actionable>

## Key Decisions
- <Decision made this session>

## Open Items
- <Unresolved question>
```

### 3. Workspace State (compiled execution plan)

The "next session cold start" file. Written at session end.

```markdown
# State: <workspace>
Updated: <ISO timestamp>
Last commit: <hash> <message>
Tests: <pass> passing, <fail> failing

## Immediate Priority
<Exact next task — specific actionable step>

## Verified State
- <What's confirmed working, with evidence>

## In Progress
- <What's partially done, where it left off>

## Recent Decisions
- <Decision>: <rationale>

## Don't
- <Dead ends discovered this session>
```

## Loading Order (session start)

1. Hot memory (always loaded — permanent patterns)
2. Workspace state (if exists — compiled plan)
3. STATUS.md + NEXT-SESSION.md (project-level state)
4. Memo (if exists — transient focus)

## Update Protocol (session end)

1. Update STATUS.md / NEXT-SESSION.md if project state changed
2. Write workspace state file (compiled plan for next session)
3. Update hot memory if new permanent pattern discovered
4. Replace memo current focus (don't append old sessions)
