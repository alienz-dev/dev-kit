# Issue Lifecycle

## Problem

Scattered tracking across Jira, TODO files, and mental notes. Agents need a unified, file-based, machine-readable issue system.

## Design

- Issues are **markdown files** with YAML frontmatter
- SQLite index is **derived** (rebuilt from markdown via `reindex`)
- Per-project numbering: `project#N`
- Git-trackable, RAG-indexable, agent-readable

## Lifecycle

```
backlog → planned → open → in_progress → review → resolved → (7d) → verified → closed
                                                 → wontfix → closed
                                                 → blocked → open (when unblocked)
```

## Issue Format

```markdown
---
id: PROJECT-NNN
title: "Issue title"
severity: P0 | P1 | P2 | P3 | P4
status: open
type: feature | bug | task | epic | chore
labels: [label1, label2]
created: "YYYY-MM-DDTHH:MM:SS"
linked_specs: [SPEC-NNN]
linked_tests: [tests/path.test.ts]
linked_files: [src/path.ts]
parent: PROJECT-NNN | null
---

# Issue Title

## Description
<What needs to happen>

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Notes
<Additional context>
```

## CLI Commands

```bash
# CRUD
issue open "title" --project <name> --type bug --severity P1
issue list --project <name>
issue show <name>#N
issue edit <name>#N --severity P0

# Lifecycle
issue start <name>#N          # → in_progress
issue review <name>#N         # → review
issue resolve <name>#N        # → resolved
issue verify <name>#N         # → verified (7-day window)
issue close <name>#N          # → closed
issue block <name>#N --reason "waiting on X"
issue wontfix <name>#N --reason "by design"

# Agent integration
issue brief <name>#N          # dump for agent briefing
issue triage                  # surface actionable items
issue stats                   # counts by state/severity
issue reindex                 # rebuild SQLite from markdown
```

## Severity

| Level | Meaning | Response Time |
|-------|---------|---------------|
| P0 | Critical — system down | Immediate |
| P1 | High — major feature broken | Same day |
| P2 | Medium — degraded experience | This sprint |
| P3 | Low — minor inconvenience | Backlog |
| P4 | Backlog — nice to have | When convenient |

## Types

| Type | Use |
|------|-----|
| feature | New capability |
| bug | Defect in existing code |
| task | Work item (not a code change) |
| epic | Parent grouping multiple features |
| chore | Maintenance, cleanup, deps |

## Directory Structure

```
project/
└── issues/
    ├── index.json          # Derived index (rebuilt via reindex)
    ├── PROJECT-001.md
    ├── PROJECT-002.md
    └── ...
```

## Mapping to Pipeline Stages

Issue states map to the pipeline stages defined in
[`transitions.json`](../pipeline/transitions.json) (single source of truth):

| Issue State | Pipeline Stage | Notes |
|-------------|---------------|-------|
| backlog | (pre-pipeline) | Not yet in pipeline |
| planned | plan | Spec being written |
| open | plan | Spec exists, awaiting test phase |
| in_progress | sprint | Implementation in progress |
| review | review | Under review |
| resolved | done | Implementation complete |
| verified | done | Post-merge verification complete |
| closed | done | Issue closed |
| wontfix | done | Closed without implementation |
| blocked | (stalls current stage) | Remains at current pipeline stage until unblocked |

## Integration with TRIO

Issues link to specs and tests:
```yaml
linked_specs: [SPEC-042]
linked_tests: [tests/unit/pagination.test.ts]
linked_files: [src/routes/users.ts]
```

Advancing an issue requires passing the corresponding gate defined in `transitions.json`.
