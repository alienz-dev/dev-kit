---
name: delegation-slim
description: Agent spawn patterns. kiro-ctl usage, agent selection, tab types, cross-tab commands.
---

# Delegation

## Spawn Rules

- **Always `kiro-ctl spawn`, NEVER `kiro-sub.sh` directly.** preToolUse hook blocks direct calls.
- **Always specify agent explicitly.** `kiro-ctl spawn coder`, not keyword auto-detection.

### Agent Selection

| Task Type | Agent |
|-----------|-------|
| Code changes, bug fixes, features | `coder` |
| Research, comparison, investigation | `researcher` |
| Test writing, RED gate | `test-manager` |
| Multi-coder coordination | `sprint-manager` |
| Code/PR review | `reviewer` |
| Planning, spec writing | `planner` |
| Architecture, greenfield design | `architect` |
| High blast radius | any + `--monitored` |

## Spawn Commands

```bash
# Standard worker (orchestrators use this)
kiro-ctl spawn coder "task" --subscribe --workdir ~/repo

# Headless (invisible pane, faster)
kiro-ctl spawn coder "task" --subscribe --headless

# With context file
kiro-ctl spawn coder "task" --subscribe --context /tmp/ctx.md --workdir ~/repo

# Topic tab (standalone, no auto-close)
kiro-ctl spawn planner "task" --topic --subscribe

# Synchronous wait
kiro-ctl spawn coder "task" --subscribe --headless
kiro-ctl wait kiro-sub-<timestamp> --timeout 300

# Monitored (approval gate on writes)
kiro-ctl spawn coder "task" --subscribe --monitored --workdir ~/repo

# Custom tab name
kiro-ctl spawn coder "task" --subscribe --tab-name "My Tab"
```

Fallback (no daemon): `bash ~/scripts/kiro-sub.sh "task" --agent coder --subscribe --workdir ~/repo`

## Cross-Tab Commands

```bash
# List tabs
zellij action list-tabs

# Read pane screen (no focus change)
zellij action dump-screen --pane-id terminal_5 --full

# Inject text into pane
pane-inject.sh terminal_59 "prompt text"

# Tab lifecycle (by ID — never focus-switch for programmatic ops)
zellij action close-tab-by-id "$TAB_ID"
zellij action rename-tab-by-id "$TAB_ID" "new-name"
```

## Gotchas

- **Always `--subscribe` with `--topic`.** Without it, parent has no way to know when topic tab finishes.
- **Batch related fixes into single briefing.** Don't ping-pong with multiple small spawns.
- **Topic+interactive:** `--topic` with interactive keywords keeps session alive (no auto-quit).
- **Backgrounded kiro-cli cannot read stdin.** Interactive sessions must run foreground.
- **Pane exit detection:** Commands exiting <1s may not register. Use `sleep 2; exit` for reliable detection.
- **Agent writes result file, launcher controls tab close.** Don't use `zellij action close-pane`.
