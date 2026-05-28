# Agent Resource Sets

Defines which context files each agent role loads at startup. Optimized for minimal context consumption while preserving essential rules.

## Governance Layer (ALL agents)

Every agent loads these — non-negotiable:

| File | Size | Purpose |
|------|------|---------|
| client_rules.md | 8.7KB | Safety, verification, anti-hallucination, context discipline |
| amazonq.md | 3.8KB | Corporate infrastructure safety (org-specific, optional) |
| user-profile.md | 1.5KB | Communication style preferences |
| hot-memory-current.md | ~2.5KB | Workspace-specific state and gotchas |

## Role-Specific Resources

| Role | Resources (beyond governance) | Total ~KB |
|------|-------------------------------|-----------|
| Coder | coder-safety.md, coder-workflow.md | 24 |
| Planner/Supervisor | planner-core.md, delegation-slim.md | 29 |
| Default (router) | agent-routing, session-routing, file-management, delegation-slim, skills/index.md | 68 |
| Researcher | deep-research.md, RESEARCH-REPORT-TEMPLATE.md | 25 |
| Reviewer | code-review.md, security-threat-model.md | 24 |
| Test-Manager | test-engineer.md, delegation-slim.md | 24 |
| Sprint-Manager | delegation-slim.md, issue-filing.md | 24 |
| Debugger | systematic-debugging.md, debugger-knowledge.md, debug-history.md, coder-workflow.md, issue-filing.md | 37 |

## Design Principles

1. **Governance is non-negotiable** — every agent gets client_rules + amazonq
2. **Bake in frequently-used protocols** — don't rely on briefings or hot-memory
3. **On-demand for rare protocols** — endgame, interaction-design read from disk when triggered
4. **Replace bloated files with digests** — delegation 14KB→2.6KB, coding-conventions 11.5KB→4.3KB
5. **Full files preserved on disk** — available for on-demand loading, not preloaded
6. **Role determines resources** — coders don't need spawn rules, planners don't need coding style

## What Was Removed (and why)

| Removed | Size | Reason |
|---------|------|--------|
| claimgraph | 3.4KB | Rarely used by any agent |
| session-lifecycle (full) | 5KB | Done protocol baked into session-routing or role-specific files |
| sub-task-rules | 7.7KB | Only orchestrators spawn; covered by delegation-slim |
| coding-conventions (full) | 11.5KB | Condensed into coder-workflow (4.3KB) |
| delegation (full) | 14KB | Condensed into delegation-slim (2.6KB); historical gotchas removed |
| skills/index.md | 42KB | Only default agent (the router) needs it; others grep at runtime |
