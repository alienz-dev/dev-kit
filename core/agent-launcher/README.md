# Agent Launcher

## Problem

Spawning agents requires: tab creation, briefing injection, context setup, result monitoring, cleanup. Without a launcher, each spawn is manual and error-prone.

## Core Script: spawn.sh

```bash
spawn.sh "<task description>" \
  --role <role>           # supervisor|coder|tester|reviewer|planner
  --workdir <path>        # Working directory for the agent
  [--context <file>]      # Additional context file to include in briefing
  [--topic]               # Persistent tab (no auto-close)
  [--headless]            # Invisible floating pane
  [--tab-name <name>]     # Custom tab name
  [--result <path>]       # Where agent writes result (enables parent notification)
  [--parent <pane-id>]    # Parent pane to notify on completion
```

## Lifecycle

```
spawn.sh called
  → Generate unique ID
  → Create briefing file (/tmp/<id>-briefing.md)
  → Create launcher script (/tmp/<id>-launch.sh)
  → Create zellij tab (--close-on-exit)
  → Launcher starts agent CLI with briefing
  → Agent works...
  → Agent writes result file
  → Launcher detects result → notifies parent → exits (tab closes)
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

**Key insight:** The LAUNCHER controls tab lifecycle, not the agent.

```
Tab created with --close-on-exit
  └── Launcher script is the tab process
        ├── Agent CLI runs inside launcher
        ├── On success: agent writes result → launcher exits 0 → tab closes
        ├── On crash: launcher detects, waits 5s, exits 1 → tab closes
        ├── On timeout: launcher kills agent, exits 1 → tab closes
        └── On user interrupt (Ctrl+C): exec bash → tab stays open
```

## Parent Notification

When `--result` and `--parent` are specified:
1. Agent writes result to `--result` path
2. Launcher detects file creation
3. Launcher injects message into parent pane:
   ```bash
   pane-inject.sh <parent-pane-id> "check /tmp/<id>-result.md"
   ```
4. Launcher exits (tab closes)

If parent is busy (not at prompt), injection is skipped but result file remains on disk.

## Fire-and-Forget vs Interactive

| Mode | Tab Closes | User Input | Use Case |
|------|-----------|------------|----------|
| Fire-and-forget | On completion | None | Coder, tester, reviewer |
| Interactive | Never (--topic) | Yes | Test-manager, planner |

## Cleanup

On exit (success or failure):
- Remove briefing file
- Remove launcher script
- Remove generated agent JSON (if throwaway)
- Keep result file (parent needs it)
- Keep stderr log (for debugging)

## Error Handling

| Failure | Detection | Action |
|---------|-----------|--------|
| Agent crashes | Non-zero exit | Write crash report to result path, notify parent |
| Agent hangs | Timeout (configurable) | Kill agent, write timeout report |
| Tab killed externally | Launcher trap | Best-effort cleanup |
| Agent writes no result | Timeout | Write "no result" to result path |
