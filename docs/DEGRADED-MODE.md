# Degraded Mode Levels

Three operational levels depending on available infrastructure.

## Level 1: Full (daemon + multiplexer)

All infrastructure present: `kiro-sessiond`, Zellij, lefthook.

- Daemon enforces pipeline transitions and role policies
- Agents spawn into multiplexer panes
- Pre-commit hooks run automatically
- Pipeline state managed by daemon

## Level 2: Single-Agent (no daemon)

Multiplexer available but no daemon. File-based state replaces daemon enforcement.

- Pipeline state in `.pipeline/state.json` (managed by `gate.sh`)
- Lefthook hooks enforce gates on commit
- Sequential execution — one agent at a time
- Manual stage advancement via `gate.sh advance <signal>`

## Level 3: Direct (no daemon, no multiplexer)

Bare minimum. Human drives workflow manually.

- AGENTS.md provides rules inline (any AI tool reads it)
- Lefthook hooks still enforce test/typecheck gates
- Manual stage tracking via `gate.sh`
- No parallel agent execution

## Decision Tree

```
Is kiro-sessiond running?
  YES → Level 1 (Full)
  NO  → Is Zellij/multiplexer available?
    YES → Level 2 (Single-Agent)
    NO  → Level 3 (Direct)
```

## Commands by Level

| Command | L1 | L2 | L3 |
|---------|----|----|-----|
| `gate.sh init <feature>` | daemon | manual | manual |
| `gate.sh advance <signal>` | daemon | manual | manual |
| `gate.sh status` | ✓ | ✓ | ✓ |
| `gate.sh check <stage>` | ✓ | ✓ | ✓ |
| `lefthook run pre-commit` | auto | auto | manual |

## Signals Reference

| Signal | Transition |
|--------|-----------|
| `plan_ready` | plan → test |
| `tests_ready` | test → sprint |
| `sprint_complete` | sprint → review |
| `review_complete` | review → done |
| `stage_failed` | any → failed |
| `retry_plan` | failed → plan |
| `retry_test` | failed → test |
| `retry_sprint` | failed → sprint |
