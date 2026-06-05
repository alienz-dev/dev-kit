---
id: ENH-0011
title: "Human Gate for Spec Approval — require sign-off for high-severity"
status: resolved
priority: low
component: hook
requested_by: ding
date: 2026-06-05
labels: [enhancement, sdd, hook, p3]
---

## Problem Statement

Specs can advance from `draft` to `approved` without human sign-off. For low-complexity features this is fine, but for high-severity (P0/P1) or high-complexity (8+) features, a human should review and approve the spec before implementation begins.

Currently the grill protocol is interactive (human-in-the-loop), but it's a session, not a gate. A planner could theoretically approve a spec without running grill.

## Proposed Solution

### 1. Claude Code Hook (hooks/check-spec-approval.sh)
PreToolUse hook on Agent tool that checks:
- If the agent is trying to advance spec status to `approved`
- If the spec is P0/P1 severity or complexity 8+
- Block the advance and require human approval
- Log the approval request

### 2. Spec Frontmatter Addition
Add `approved_by` field to spec frontmatter:
```yaml
approved_by: ding  # or empty if not yet approved
approval_date: 2026-06-05
```

### 3. validate-spec.sh Enhancement
Check that `approved_by` is non-empty when status is `approved`.

## Alternatives Considered

1. **Always require human approval** — rejected because too heavyweight for low-complexity features
2. **Never require human approval** — rejected because P0 changes need human oversight
3. **Soft gate (warning only)** — rejected because warnings are ignored

## Research Context

- Anthropic: "human-in-the-loop gates for high-severity changes"
- dev-kit grill protocol: already human-in-the-loop but not enforced as a gate
- Claude Code hooks: PreToolUse hook can block agent actions

## Impact

- Who benefits: users (safety net for high-severity changes)
- Scope: P0/P1 specs and complexity 8+ features
- Effort: ~2h
- Dependencies: None (standalone hook)
