# Agent Launcher

## Status: Complete (production)

Agent spawning is handled by `kiro-ctl` (daemon CLI) as the primary method, with `kiro-sub.sh` as a low-level fallback when the daemon is unavailable.

## Problem

Spawning agents requires: tab creation, briefing injection, context setup, result monitoring, cleanup. Without a launcher, each spawn is manual and error-prone.

## Primary: kiro-ctl spawn

```bash
kiro-ctl spawn <agent> "<task description>" \
  --subscribe              # Get notified on completion via EventBus
  --workdir <path>         # Working directory for the agent
  [--context <file>]       # Additional context file
  [--topic]                # Persistent tab (no auto-close)
  [--headless]             # Invisible floating pane
```

### Completion Tracking (--subscribe)

With `--subscribe`, the daemon's EventBus notifies the parent when the child:
- Completes: `[system] [DONE] <agent> completed. Result: /tmp/kiro-sub-<id>-result.md`
- Errors: `[system] [ERROR] <agent> failed. Result: /tmp/kiro-sub-<id>-result.md`
- Hangs: `[system] [HUNG] <agent> idle >300s. Pane: <id>`

No polling needed — notifications injected into parent's TUI queue.

## Low-Level Fallback: kiro-sub.sh

When daemon is unavailable (e.g., fresh machine setup before daemon installed):

```bash
kiro-sub.sh "<task description>" \
  --role <role>           # supervisor|coder|tester|reviewer|planner
  --workdir <path>        # Working directory for the agent
  [--context <file>]      # Additional context file
  [--topic]               # Persistent tab (no auto-close)
  [--result <path>]       # Where agent writes result
  [--parent <pane-id>]    # Parent pane to notify on completion
```

## Lifecycle

```
kiro-ctl spawn called
  → Daemon generates unique ID
  → Daemon creates briefing file (/tmp/<id>-briefing.md)
  → Daemon creates zellij tab (--close-on-exit)
  → kiro-cli --tui --agent <role> starts in tab
  → Briefing injected as first user message
  → Agent works...
  → Agent writes result file
  → Daemon detects result → notifies parent via EventBus → tab closes
```

## Briefing Format

```markdown
# Task
<task description>

## Context
<injected from --context file or auto-generated>

## Constraints
- Working directory: <workdir>
- Role: <role>
- Write paths: <allowed paths for this role>
- Result path: <where to write result>

## Rules
- <role-specific rules>
- Write result to: <result path>
- Do NOT modify files outside your write paths
```

## Tab Lifecycle Control

The DAEMON controls tab lifecycle, not the agent:

```
Tab created with --close-on-exit
  └── kiro-cli --tui is the tab process
        ├── On success: agent writes result → daemon detects → notifies parent → tab closes
        ├── On crash: daemon detects, logs error, notifies parent
        ├── On timeout: daemon kills agent, notifies parent
        └── On hang: daemon detects idle, notifies parent
```

## Fire-and-Forget vs Persistent

| Mode | Tab Closes | User Input | Use Case |
|------|-----------|------------|----------|
| Fire-and-forget | On completion | None | Coder, reviewer, explorer |
| Persistent (--topic) | Never | Yes | Test-manager, planner |
| Headless (--headless) | On completion | None | Reviewer-lite, background tasks |

## Error Handling

| Failure | Detection | Action |
|---------|-----------|--------|
| Agent crashes | Non-zero exit | Write crash report, notify parent |
| Agent hangs | Idle timeout (300s) | Notify parent, optionally kill + respawn |
| Tab killed externally | Daemon registry check | Mark as failed, notify parent |
| Agent writes no result | Timeout | Write "no result" report, notify parent |
