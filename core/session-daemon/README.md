# Session Daemon

## Problem

Agent sessions hang, crash, or need coordination. Without a daemon:
- Hung agents consume resources indefinitely
- No registry of what's running
- No inter-agent messaging
- No automatic recovery

## Architecture

```
crew-sessiond (Python, single process)
├── Registry (SQLite)
│   ├── Active sessions (pane ID, role, task, start time)
│   ├── Message queue (sender, recipient, content, status)
│   └── Health signals (last activity, error count)
├── Hang Detector (polling loop)
│   ├── Idle check (no output for N seconds)
│   ├── Error pattern detection (regex on pane output)
│   └── Health limit detection (rate limit, daily cap)
├── Dispatcher
│   ├── Tab creation (zellij action new-tab)
│   ├── Briefing injection (write-chars)
│   └── Result collection (file watcher)
└── Message Queue
    ├── File-based inbox per pane
    ├── Delivery on next agent turn
    └── Dead letter queue (undeliverable)
```

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| SQLite WAL mode | Concurrent reads from multiple agents |
| File-based messaging | Survives crashes, no network needed |
| PID file singleton | Only one daemon per machine |
| Polling (not events) | Simpler, more reliable, works across all terminals |
| Python (no deps) | Available everywhere, easy to modify |

## Configuration

```json
// ~/.config/crew/daemon.json
{
  "poll_interval": 10,
  "idle_timeout": 300,
  "max_parallel": 3,
  "hang_detection": {
    "idle_threshold_seconds": 120,
    "error_threshold": 5,
    "health_limit_action": "pause"
  }
}
```

## Systemd Service

```ini
[Unit]
Description=Crew Session Daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /path/to/crew-sessiond.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
```

## Health Signals

| Signal | Detection | Action |
|--------|-----------|--------|
| Idle | No pane output for idle_timeout | Log warning |
| Stuck | Same prompt line for 2× idle_timeout | Kill + respawn |
| Error loop | N errors in M seconds | Pause, notify user |
| Rate limited | "daily usage limit" in output | Pause all sessions |
| OOM | Process killed by kernel | Restart with reduced parallelism |

## Message Queue

```bash
# Send
agents-msg.sh send terminal_<id> "message" --role "sender-role"

# Creates file:
# ~/.local/share/crew/messages/<recipient-pane-id>/<timestamp>-<sender>.md

# Delivery: agent's shell hook checks inbox at prompt display
# Dead letter: messages older than 1h without delivery → DLQ
```

## Implementation Status

This is the most complex module. Implement incrementally:
1. **Phase 1:** Registry only (track what's running)
2. **Phase 2:** Hang detection (idle timeout, kill stuck)
3. **Phase 3:** Message queue (file-based)
4. **Phase 4:** Auto-recovery (respawn crashed agents)
