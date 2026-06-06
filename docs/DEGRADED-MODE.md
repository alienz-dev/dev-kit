# Degraded Mode Levels

Two operational levels depending on available infrastructure.

## Level 1: Claude Code Native

Full experience with Claude Code's built-in multi-agent support.

- Subagents spawn in-process via `Agent()` tool
- Pipeline state in `.pipeline/state.json` (managed by `gate.sh`)
- Lefthook hooks enforce gates on commit
- Agent definitions in `.claude/agents/*.md`
- Rules in `.claude/rules/*.md` (path-scoped)
- Skills in `.claude/skills/*/SKILL.md`

## Level 2: Direct (any AI tool)

Bare minimum. Human drives workflow manually.

- AGENTS.md provides rules inline (any AI tool reads it)
- Lefthook hooks still enforce test/typecheck gates
- Manual stage tracking via `gate.sh`
- No parallel agent execution

## Decision Tree

```
Is Claude Code available?
  YES → Level 1 (Claude Code Native)
  NO  → Level 2 (Direct — any AI tool reads AGENTS.md)
```

## Commands

| Command | L1 | L2 |
|---------|----|----|
| `gate.sh init <feature>` | ✓ | ✓ |
| `gate.sh advance <signal>` | ✓ | ✓ |
| `gate.sh status` | ✓ | ✓ |
| `gate.sh check <stage>` | ✓ | ✓ |
| `lefthook run pre-commit` | auto | manual |
| `Agent()` subagent dispatch | ✓ | — |
| `/trio` skill | ✓ | — |
| `/grill` skill | ✓ | — |
| `ultracode: <task>` | ✓ | — | Requires Claude Code v2.1.154+ with workflows enabled |
| `/adversarial-review` | ✓ | — | Multi-angle code review workflow |
| `/wave-implement` | ✓ | — | TRIO wave dispatch workflow |
| `/deep-audit` | ✓ | — | Comprehensive audit workflow |
| `/research-crosscheck` | ✓ | — | Research with cross-check workflow |
| `/migration-sweep` | ✓ | — | Migration pipeline workflow |
| `/sdd-implement` | ✓ | — | Full SDD implementation workflow |
