# Architecture

## How the Pieces Fit Together

```
┌─────────────────────────────────────────────────────────────┐
│                    Terminal (WezTerm/iTerm2)                  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Zellij (multiplexer)                       │  │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐    │  │
│  │  │supervisor│ │test-mgr │ │  coder  │ │ reviewer│    │  │
│  │  │  (tab)  │ │  (tab)  │ │  (tab)  │ │  (tab)  │    │  │
│  │  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘    │  │
│  └───────┼───────────┼───────────┼───────────┼──────────┘  │
└──────────┼───────────┼───────────┼───────────┼──────────────┘
           │           │           │           │
     ┌─────▼───────────▼───────────▼───────────▼─────┐
     │            Agent Launcher (spawn.sh)            │
     │  - Creates tabs with --close-on-exit           │
     │  - Injects briefing                            │
     │  - Monitors result files                       │
     │  - Notifies parent on completion               │
     └─────────────────────┬──────────────────────────┘
                           │
     ┌─────────────────────▼──────────────────────────┐
     │           Session Daemon (optional)             │
     │  - Registry (who's running, what state)        │
     │  - Hang detection (idle timeout)               │
     │  - Message queue (file-based)                  │
     │  - Tab replacement (kill hung, respawn)        │
     └─────────────────────┬──────────────────────────┘
                           │
     ┌─────────────────────▼──────────────────────────┐
     │         Coding Agent CLI (pluggable)            │
     │  - Default: kiro-cli (--classic --agent <role>) │
     │  - Alt: claude-code, aider, cursor-agent       │
     │  - Interface: briefing in → result file out    │
     └────────────────────────────────────────────────┘
```

## Data Flow: Feature Implementation

```
1. User describes feature to Supervisor
2. Supervisor writes spec (specs/SPEC-NNN.md)
3. Supervisor spawns Test-Manager (--topic, persistent)
4. Test-Manager reads spec, writes tests
5. Test-Manager verifies RED (all tests fail)
6. Test-Manager spawns Coder (ephemeral)
   - Briefing: test file paths ONLY (no spec)
7. Coder reads tests, implements, verifies GREEN
8. Coder writes result file, tab auto-closes
9. Test-Manager verifies GREEN + hidden tests
10. Supervisor spawns Reviewer (ephemeral)
    - Briefing: spec + implementation + test results
11. Reviewer approves or rejects
12. Supervisor updates issue status → closed
```

## Communication Patterns

### File-Based Messaging
```
/tmp/agents-msg/<pane-id>/inbox/
  ├── 001-from-supervisor.md
  ├── 002-from-test-manager.md
  └── ...
```

Agents check inbox at start of each turn. No polling, no network.

### Result Files
```
/tmp/kiro-sub-<id>-result.md
```

Launcher watches for result file creation → triggers parent notification.

### State Files (persistent)
```
~/.local/share/crew/
  ├── crew-session.db      # Session registry
  ├── kiro-sessiond.log    # Daemon log
  └── messages/            # Message queue
```

## Key Design Decisions

| Decision | Alternative | Why This |
|----------|-------------|----------|
| Kiro as default agent | Claude Code, Aider | Tool-use native, agent JSON, deniedPaths enforcement, resources |
| Pluggable agent interface | Hardcoded to one CLI | Teams use different tools; adapter pattern keeps core generic |
| File messaging | WebSocket/HTTP | Survives crashes, no server needed, agent-readable |
| SQLite state | Redis/Postgres | Zero setup, WAL for concurrency, portable |
| Zellij tabs | Docker containers | Lower overhead, shared filesystem, visible to user |
| Launcher controls lifecycle | Agent self-closes | Agent crash doesn't leave orphan tabs |
| Locked mode default | Normal mode | Agents can't accidentally trigger keybinds |
| Per-role deniedPaths | Trust-based | Agents WILL write outside scope without enforcement |
