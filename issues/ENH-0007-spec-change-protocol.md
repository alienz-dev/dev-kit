---
id: ENH-0007
title: "Spec Change Protocol — formalize review_to_specced flow"
status: resolved
priority: medium
component: workflow
requested_by: ding
date: 2026-06-05
labels: [enhancement, sdd, workflow, p1]
---

## Problem Statement

When a design change is needed mid-implementation, there's no documented protocol for how to handle it. The `transitions.json` has `review_to_specced` transition, but:
- No documentation on when to trigger it
- No documentation on what steps to follow
- No documentation on how to update tests after spec change
- No documentation on how to resume the sprint after spec change

This leads to ad-hoc handling: sometimes the spec is updated without updating tests, sometimes the sprint is abandoned and restarted, sometimes code diverges from spec silently.

## Proposed Solution

Document the spec change protocol in `workflow/sdd/SPEC-CHANGE.md`:

### 1. Trigger Conditions
- Design mismatch discovered during implementation
- Requirement change from stakeholder
- Edge case found that invalidates spec assumptions
- Performance/security constraint discovered

### 2. Protocol Steps
```
1. Sprint-Manager pauses sprint (hold state)
2. Issue created/updated with spec-change label
3. Architect reviews the change (5-lens critique)
4. Planner updates spec:
   - Version bump
   - Change Specification section (Current, Target, Invariants, Scope)
   - New/modified acceptance criteria in EARS
5. Spec validation (ba-validate skill, ENH-0003)
6. Test-Manager updates tests:
   - New RED for changed behavior
   - Hidden tests for regression
   - spec-trace.sh verifies coverage
7. Sprint-Manager resumes with updated tests
8. Reviewer verifies delta matches updated spec
9. Issue resolved
```

### 3. Anti-patterns to Document
- Updating spec without updating tests
- Skipping ba-validate after spec change
- Resuming sprint without new RED gate
- Not bumping spec version on behavioral change

### 4. Gate Integration
- gate.sh should support `retreat review_to_specced` for this flow
- Pipeline state should record spec version at each stage

## Alternatives Considered

1. **No protocol, handle ad-hoc** — rejected because current state leads to spec/code drift
2. **Full re-plan on every spec change** — rejected because too heavyweight for small changes
3. **Automate everything** — rejected because spec changes need human judgment on what's correct

## Research Context

- transitions.json already has `review_to_specced` signal — just needs documentation
- TRIO.md has backward transitions but no detailed protocol
- Industry: most AI coding tools don't handle spec changes at all — this is a differentiator

## Impact

- Who benefits: planners (clear process), sprint-managers (know when to pause/resume), reviewers (know what to verify)
- Scope: every feature that has a mid-implementation design change
- Effort: ~2h
- Dependencies: ENH-0003 (ba-validate) should exist first
