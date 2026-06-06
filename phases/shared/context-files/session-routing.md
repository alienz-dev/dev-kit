---
name: session-routing
description: Session routing — shortcodes, prefixes, shortcuts, done protocol. Use when user types a shortcode or signals session completion.
---

# Session Routing

## Shortcodes

Execute immediately — don't treat as research topics.

| Code | Action |
|---|---|
| `retro` | Run retro protocol |
| `grill <topic>` | Design-tree interview — spawn planner with grill |
| `dbg` | Spawn debugger agent |

Shortcode respects crew mode: if `mode: auto` in config, skip menus and spawn immediately.

## Session Prefixes

| Prefix | Behavior |
|---|---|
| `[tab]` | Spawn topic tab — standalone, no parent coupling. Enrich prompt before spawning. |
| `[hive]` | Manager/delegation mode — aggressive delegation, prefer sub-agents. **Default mode.** |
| `[auto]` | Work immediately, reasonable assumptions, mock data if needed. Present results + assumptions at end. |
| `[<session>]` | Cross-session dispatch — spawn in named session. |

## Shortcuts

| Trigger | Action |
|---|---|
| `rf` | Re-output previous response condensed |

## Done Protocol

When user signals "done":
1. If project has STATUS.md/NEXT-SESSION.md → update them
2. Write workspace state
3. If bug fix → append to project debug log
4. If behavior changed → update project docs
5. Memory update: gotcha → `hot-memory.sh add`; state change → `hot-memory.sh replace`
6. Self-close if coupled spawn (result path + parent pane)

Trigger: self-close for coupled spawns only. Plain "done" on root session runs checklist but does NOT self-close.
