---
name: resource-sets
description: Agent resource sets — which files each role loads at session start. Adapted for Claude Code native mechanisms.
---

# Resource Sets

Defines what context each agent role loads. In Claude Code, agent definitions live in `.claude/rules/` and are auto-loaded based on the agent's role.

## Loading Mechanism

Claude Code uses `.claude/rules/` for automatic context injection:

- **Agent definitions** are placed in `.claude/rules/` and loaded as rules for matching agents
- **Context files** (session-routing, user-profile) are referenced from agent definitions and loaded on demand
- **Project memory** is loaded via the `memory: project` field in agent frontmatter

## Resource Sets by Role

### Planner
- `.claude/rules/planner-core.md` — planning methodology, design-tree protocol
- `.claude/rules/delegation-slim.md` — delegation rules for sub-agents
- `agents/context-files/session-routing.md` — session shortcodes and prefixes

### Coder
- `.claude/rules/coder-safety.md` — safety constraints, anti-patterns
- `templates/common/claude-code/agents/coder.md` — six-phase loop, debugging rules, testing rules
- Project test files (from briefing)

### Reviewer
- `templates/common/claude-code/agents/reviewer.md` — adversarial review protocol, edge case checklist, severity levels
- Project spec (from briefing)

### Researcher
- `agents/roles/RESEARCHER-ARIA.md` — ARIA research protocol
- Vault knowledge files (on demand)

## File Hierarchy (loaded in order)

1. `.claude/rules/client_rules.md` — Universal safety rules (every session)
2. `.claude/rules/<role>.md` — Role-specific rules
3. User profile — Communication style, preferences
4. Hot memory — Per-workspace curated patterns (3000 char budget)
5. Project state — STATUS.md, NEXT-SESSION.md, CONTEXT.md, DECISIONS.md
6. Knowledge — `.agents/knowledge/*.md` (project-specific)
7. Skills — On-demand skill files loaded by topic

## paths: Frontmatter

Agent definitions may include a `paths:` field to declare which files they own:

```yaml
paths:
  - templates/common/claude-code/agents/coder.md
  - .claude/rules/coder-safety.md
```

This is optional — Claude Code loads rules from `.claude/rules/` automatically based on agent type.
