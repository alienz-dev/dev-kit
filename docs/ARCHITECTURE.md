# Architecture

## How the Pieces Fit Together

```
┌─────────────────────────────────────────────────────────────┐
│                    Terminal (WezTerm)                         │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Zellij (multiplexer, locked mode)          │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ │  │
│  │  │supervisor │ │test-mgr  │ │sprint-mgr│ │ coder×N │ │  │
│  │  │  (tab)   │ │  (tab)   │ │  (tab)   │ │ (tabs)  │ │  │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬────┘ │  │
│  └───────┼────────────┼────────────┼────────────┼───────┘  │
└──────────┼────────────┼────────────┼────────────┼───────────┘
           │            │            │            │
     ┌─────▼────────────▼────────────▼────────────▼──────┐
     │         kiro-sessiond (REQUIRED daemon)            │
     │  - Registry (who's running, what state)            │
     │  - EventBus (--subscribe, completion signals)      │
     │  - Pipeline FSM (stage enforcement)                │
     │  - Role policies (spawn permission matrix)         │
     │  - Hang detection (idle timeout, error loop)       │
     │  - Tab replacement (kill hung, respawn)            │
     └─────────────────────┬─────────────────────────────┘
                           │
     ┌─────────────────────▼─────────────────────────────┐
     │         kiro-ctl (CLI interface to daemon)         │
     │  - spawn <agent> "task" --subscribe --workdir      │
     │  - pipeline create/advance/get                     │
     │  - status, kill, list                              │
     └─────────────────────┬─────────────────────────────┘
                           │
     ┌─────────────────────▼─────────────────────────────┐
     │         Coding Agent CLI (kiro-cli --tui)          │
     │  - TUI mode (stdin/stdout isolation)               │
     │  - Tools: read, write, shell, grep, glob           │
     │  - Agent JSON (role, model, prompt, deniedPaths)   │
     │  - Alt: claude-code, aider, cursor-agent           │
     └───────────────────────────────────────────────────┘
```

## Data Flow: Feature Implementation

```
1. User describes feature to Supervisor
2. Supervisor writes spec (specs/SPEC-NNN.md)
3. Supervisor spawns Test-Manager (--topic, persistent)
4. Test-Manager reads spec, writes tests
5. Test-Manager verifies RED (all tests fail)
6. Test-Manager signals tests_ready
7. Supervisor spawns Sprint-Manager (--subscribe, ephemeral)
8. Sprint-Manager dispatches Coder×N (max 3 parallel, no file overlap)
   - Briefing: test file paths ONLY (no spec)
9. Coder reads tests, implements, verifies GREEN, writes result
10. Sprint-Manager runs gate sequence:
    GREEN → WIRING → VISUAL → wave-smoke (per wave)
    HIDDEN → ACTIVATION (after all waves)
11. Sprint-Manager spawns Reviewer (tier 2 or 3)
12. Reviewer approves or rejects
13. Supervisor updates issue status → closed
```

## Data Flow: Research (ARIA v2)

```
1. Supervisor identifies research need (complexity score 6+)
2. Supervisor spawns Researcher (ARIA v2 orchestrator)
3. Researcher spawns 2-4 Explorers in parallel (each: one angle)
4. Explorers write findings to /tmp/, self-close
5. Researcher synthesizes findings
6. Researcher spawns Research-Critic (fresh context, adversarial)
7. Critic challenges assumptions, writes critique
8. Researcher incorporates critique → final verdict
9. Writes ~/plans/research-<topic>-verdict.md
```

## Communication Patterns

### Daemon EventBus (primary)
```bash
# Spawn with completion tracking
kiro-ctl spawn coder "task" --subscribe --workdir ~/projects/app

# Parent receives notification when child completes:
# [system] [DONE] coder completed. Result: /tmp/kiro-sub-<id>-result.md
# [system] [ERROR] coder failed. Result: /tmp/kiro-sub-<id>-result.md
# [system] [HUNG] coder idle >300s. Pane: <id>
```

No polling needed — daemon injects `[system]` notifications into parent's TUI queue.

### Result Files
```
/tmp/kiro-sub-<id>-result.md
```

### State Files (persistent)
```
~/.local/share/crew/
  ├── crew-session.db      # Session registry (SQLite WAL)
  ├── kiro-sessiond.log    # Daemon log
  └── messages/            # Legacy message queue
```

## Key Design Decisions

| Decision | Alternative | Why This |
|----------|-------------|----------|
| kiro-sessiond required | Optional daemon | Agents skip gates without enforcement; EventBus eliminates polling |
| kiro-ctl spawn | spawn.sh direct | Daemon tracks lifecycle, enforces role_policies, provides --subscribe |
| TUI mode (--tui) | Classic mode | Structural stdin/stdout isolation, no < /dev/null needed |
| Sprint-manager dispatches coders | Test-manager dispatches | Separation of concerns: RED vs GREEN ownership |
| Daemon role_policies | Trust-based | planner→coder=NEVER enforced structurally |
| Pipeline FSM | Ad-hoc state | Stages enforced, stall detection, recovery transitions |
| Pluggable agent interface | Hardcoded to one CLI | Teams use different tools; adapter pattern keeps core generic |
| SQLite WAL state | Redis/Postgres | Zero setup, concurrent reads, portable |
| Zellij tabs | Docker containers | Lower overhead, shared filesystem, visible to user |
| Per-role deniedPaths | Trust-based | Agents WILL write outside scope without enforcement |

## Quality Gates (Full Pipeline)

```
RED → GREEN → WIRING → VISUAL → HIDDEN → ACTIVATION → REVIEW
```

| Gate | Tool | Owner | What It Catches |
|------|------|-------|-----------------|
| RED | vitest (all fail) | Test-Manager | Tests verify behavior, not existence |
| GREEN | vitest (all pass) | Sprint-Manager | Implementation satisfies tests |
| WIRING | `entry-reachability.sh` | Sprint-Manager | Orphaned modules, dead imports |
| VISUAL | `ui-visual-check.sh --gate` | Sprint-Manager | CSS regressions, token drift, layout breaks |
| HIDDEN | vitest (hidden tests) | Sprint-Manager | Behavioral invariants, contract violations |
| ACTIVATION | `activation-gate.sh` | Sprint-Manager | Feature reachable from entry point |
| REVIEW | reviewer-lite or reviewer | Sprint-Manager | Spec compliance, security, design quality |

The VISUAL gate only runs when changeset includes UI files (.tsx, .jsx, .vue, .svelte, .css, .scss, .html, .ejs, .hbs).

## Tiered Review

| Tier | Agent | Complexity | Timeout | Sections |
|------|-------|:----------:|:-------:|:--------:|
| 1 | Planner inline | ≤3 | N/A | Sanity check |
| 2 | reviewer-lite | 4-7 | 540s | 3 (Bug Hunter + Security + Design) |
| 3 | reviewer | 8+ | 900s | 11 (full review) |

Auto-promote to Tier 3: paths matching `/auth/`, `/security/`, `/crypto/`, `/api/`, `/schema/`, `/migration`

Review is advisory — timeout is non-blocking, never halts pipeline.
