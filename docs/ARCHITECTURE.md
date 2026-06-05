# Architecture

## How the Pieces Fit Together

```
┌─────────────────────────────────────────────────────────────┐
│                    Claude Code                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Agent() tool (in-process subagents)                  │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ │  │
│  │  │supervisor │ │test-mgr  │ │sprint-mgr│ │ coder×N │ │  │
│  │  │  (main)  │ │(subagent)│ │(subagent)│ │(subagent│ │  │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬────┘ │  │
│  └───────┼────────────┼────────────┼────────────┼───────┘  │
└──────────┼────────────┼────────────┼────────────┼───────────┘
           │            │            │            │
     ┌─────▼────────────▼────────────▼────────────▼──────┐
     │         Pipeline gate.sh (file-based FSM)           │
     │  - .pipeline/state.json                            │
     │  - transitions.json (single source of truth)       │
     │    stages + gates + valid transitions               │
     │  - Pre-commit hooks (lefthook)                     │
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

### Claude Code (Agent tool)
```javascript
// Spawn with background tracking
Agent({ prompt: "task", run_in_background: true })
// Completion arrives as a notification in the session
```

### Result Files
```
/tmp/agent-<id>-result.md
```

### State Files (persistent)
```
~/.state/
  └── hot-memory-<workspace>.md   # Bounded curated context (3000 chars)
```

## Key Design Decisions

| Decision | Alternative | Why This |
|----------|-------------|----------|
| Sprint-manager dispatches coders | Test-manager dispatches | Separation of concerns: RED vs GREEN ownership |
| Pipeline FSM | Ad-hoc state | Stages enforced via gate.sh (file-based), recovery transitions |
| Pluggable agent interface | Hardcoded to one CLI | Teams use different tools; adapter pattern keeps core generic |
| Per-role deniedPaths | Trust-based | Agents WILL write outside scope without enforcement |

## Quality Gates (Full Pipeline)

Sprint sub-gates are defined in `transitions.json` under `gates.sprint`.
The sequence within the sprint stage:

```
RED → GREEN → WIRING → VISUAL → HIDDEN → ACTIVATION → REVIEW
```

| Gate | Tool | Owner | What It Catches |
|------|------|-------|-----------------|
| RED | vitest (all fail) | Test-Manager | Tests verify behavior, not existence |
| GREEN | vitest (all pass) | Sprint-Manager | Implementation satisfies tests |
| WIRING | `quality/gates/entry-reachability.sh` | Sprint-Manager | Orphaned modules, dead imports |
| VISUAL | `quality/gates/ui-visual-check.sh` | Sprint-Manager | CSS regressions, token drift, layout breaks |
| wave-smoke | `quality/gates/wave-smoke.sh` | Sprint-Manager | Uncommitted changes, merge conflicts, test failures |
| HIDDEN | vitest (hidden tests) | Sprint-Manager | Behavioral invariants, contract violations |
| ACTIVATION | `quality/gates/activation-gate.sh` | Sprint-Manager | Feature reachable from entry point |
| REVIEW | `quality/gates/review-precheck.sh` | Sprint-Manager | TODO/FIXME comments, console.log, type errors |

The VISUAL gate only runs when changeset includes UI files (.tsx, .jsx, .vue, .svelte, .css, .scss, .html, .ejs, .hbs).

## Tiered Review

| Tier | Agent | Complexity | Timeout | Sections |
|------|-------|:----------:|:-------:|:--------:|
| 1 | Planner inline | ≤3 | N/A | Sanity check |
| 2 | reviewer-lite | 4-7 | 540s | 3 (Bug Hunter + Security + Design) |
| 3 | reviewer | 8+ | 900s | 11 (full review) |

Auto-promote to Tier 3: paths matching `/auth/`, `/security/`, `/crypto/`, `/api/`, `/schema/`, `/migration`

Review is advisory — timeout is non-blocking, never halts pipeline.
