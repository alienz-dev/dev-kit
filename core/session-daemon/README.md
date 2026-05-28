# Session Daemon (kiro-sessiond)

## Status: REQUIRED (production, v0.13.0, 426 tests)

The session daemon is **required infrastructure** — not optional. It provides agent lifecycle management, pipeline enforcement, EventBus completion tracking, and role policy enforcement.

## Problem

Without the daemon:
- Agents skip gates (no enforcement)
- Planners spawn coders directly (no role_policies)
- No completion tracking (must poll for result files)
- Hung agents consume resources indefinitely
- No pipeline stage enforcement

## Architecture

```
kiro-sessiond (TypeScript, Zellij WASM plugin)
├── Registry (SQLite WAL)
│   ├── Active sessions (pane ID, role, task, start time)
│   ├── Pipeline state (stage, transitions, history)
│   └── Health signals (last activity, error count)
├── EventBus
│   ├── --subscribe completion tracking
│   ├── [system] notification injection into parent TUI
│   └── Signals: DONE, ERROR, HUNG, STALL
├── Role Policies
│   ├── Spawn permission matrix (ALWAYS/NEVER/stage-gated)
│   ├── Deny-by-default enforcement
│   └── Pipeline stage gating
├── Pipeline FSM
│   ├── Stage transitions (plan→test→sprint→review→done)
│   ├── Stall detection (600s no-advance)
│   └── Recovery transitions (failed→retry_*)
├── Hang Detector
│   ├── Idle check (no output for N seconds)
│   ├── Error pattern detection
│   └── OOM detection
└── CLI: kiro-ctl
    ├── spawn <agent> "task" --subscribe --workdir
    ├── pipeline create/advance/get
    ├── status, kill, list
    └── Port: /tmp/kiro-sessiond-<session>.port
```

## CLI: kiro-ctl

```bash
# Spawn agent with completion tracking
kiro-ctl spawn coder "Make tests pass" --subscribe --workdir ~/projects/app

# Pipeline management
kiro-ctl pipeline create --feature PROJ-042
kiro-ctl pipeline advance --signal tests_ready
kiro-ctl pipeline get

# Session management
kiro-ctl status          # List active agents
kiro-ctl kill <pane-id>  # Kill hung agent
kiro-ctl list            # All sessions
```

## EventBus Notifications

When parent spawns with `--subscribe`, daemon injects notifications:

```
[system] [DONE] coder completed. Result: /tmp/kiro-sub-<id>-result.md
[system] [ERROR] coder failed. Result: /tmp/kiro-sub-<id>-result.md
[system] [HUNG] coder idle >300s. Pane: <id>
[system] [STALL] Pipeline PROJ-042 stuck at stage: sprint (600s)
```

Notifications are `[system]` prefixed and injected into TUI queue — no polling needed.

## Configuration

```json
// ~/.config/crew/daemon.json
{
  "poll_interval": 10,
  "idle_timeout": 300,
  "max_parallel": 3,
  "role_policies": {
    "planner→coder": "NEVER",
    "sprint-manager→coder": "ALWAYS",
    "test-manager→coder": "NEVER"
  }
}
```

## Installation

```bash
# Systemd user service (auto-start on login)
cp infra/systemd/kiro-sessiond.service ~/.config/systemd/user/
systemctl --user enable --now kiro-sessiond

# Verify
kiro-ctl status
```

## State Storage

```
~/.local/share/crew/
  ├── crew-session.db      # Session registry + pipeline state (SQLite WAL)
  ├── kiro-sessiond.log    # Daemon log
  └── messages/            # Legacy message queue (deprecated, use EventBus)
```
