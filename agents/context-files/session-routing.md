---
name: session-routing
description: Session routing — shortcodes, prefixes, shortcuts, done protocol. Use when user types a shortcode or signals session completion.
---

# Session Routing

## Shortcodes

Execute immediately — don't treat as research topics.

| Code | Action |
|---|---|
| `krew` | krew-cli project session — see krew-project skill |
| `krew wd` | Watchdog dev session — `cd ~/projects/watchdog && krew session start watchdog-dev` |
| `krew kh` | Knowledge Hub — `cd ~/projects/knowledge-hub && krew session start kh` |
| `krew ar` | Auto-research — `cd ~/workspaces/auto-research && krew session start auto-research` |
| `wd` | Watchdog workflow — see watchdog-session skill |
| `watchdog` | Watchdog workspace — `cd ~/workspaces/watchdog && krew session start` |
| `neo` | Neo-UI — autonomous spec-driven TDD session |
| `sprint` | Sprint workspace — `cd ~/workspaces/sprint && krew session start` |
| `hs` | StudentHS crew session |
| `retro` | Run retro protocol |
| `retro <sprint>` | `krew heuristic list --sprint "<sprint>"` |
| `retro query <desc>` | `krew heuristic query "<desc>"` |
| `bmc` | `~/scripts/brendon-messages.sh -h 1` — last hour |
| `bm` | `~/scripts/brendon-messages.sh 2` — last 2 work days. Optional: `bm 5` |
| `up` | Morning update — see morning-update skill |
| `tutor` | Load `~/plans/plan-ai-tutor-learning-session.md` |
| `learn` | Learning plan session |
| `res` | `python3 ~/scripts/conversation-anchor.py --list` |
| `res <kw>` | `python3 ~/scripts/conversation-anchor.py --resume <kw>` |
| `anchore` | `python3 ~/scripts/conversation-anchor.py --save` |
| `rc` | Tab resume — `python3 ~/vault/skills/tab-resume/scripts/tab-resume.py` |
| `handoff` | Write handoff file + spawn continuation tab |
| `grill <topic>` | Design-tree interview — spawn planner with grill |
| `dbg` | Spawn debugger agent tab |

Shortcode respects crew mode: if `mode: auto` in config, skip menus and spawn immediately.

## Session Prefixes

| Prefix | Behavior |
|---|---|
| `[tab]` | Spawn topic tab — standalone, no parent coupling. Enrich prompt before spawning. |
| `[hive]` | Manager/delegation mode — aggressive delegation, prefer sub-agents. **Default mode.** |
| `[auto]` | Work immediately, reasonable assumptions, mock data if needed. Present results + assumptions at end. |
| `[<session>]` | Cross-session dispatch — spawn in named session (sprint, watchdog, comms, learn, taxintell, infra, vault). |

## Shortcuts

| Trigger | Action |
|---|---|
| `rf` | Re-output previous response condensed |

## Done Protocol

When user signals "done":
1. If project has STATUS.md/NEXT-SESSION.md → update them
2. Write `~/.kiro/state/<workspace>.md` (workspace state)
3. If bug fix → append to `~/vault/knowledge/debug-log/debug-log.md`
4. If behavior changed → update vault docs (grep for script/service name)
5. Memory update: gotcha → `hot-memory.sh add`; state change → `hot-memory.sh replace`
6. Self-close if coupled spawn (result path + parent pane)

Trigger: self-close for coupled spawns only. Plain "done" on root session runs checklist but does NOT self-close.
