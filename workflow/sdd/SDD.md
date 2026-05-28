# Spec-Driven Development (SDD)

## Why

Agents implement wrong things without a contract. Code without a spec is a guess. Specs are the single source of truth — if code diverges from spec, one must be updated.

## Lifecycle

```
Idea → Spec (draft) → Grill → Spec (approved) → Plan (derived) → Implement (TDD) → Verify → Ship
```

## Rules

1. Every feature touching >1 file MUST have a spec before implementation.
2. Bug fixes use issues only — no spec needed.
3. Specs define WHAT + WHY. Plans define HOW + ORDER.
4. Plans are derived from specs — never the reverse.
5. Spec is the contract. If code diverges from spec, either update spec or fix code.
6. Tests are executable assertions of spec sections.
7. Acceptance criteria MUST use EARS notation (see below).

## EARS Notation (Mandatory for Acceptance Criteria)

Every acceptance criterion uses one of these 5 patterns:

| Pattern | Template | Example |
|---------|----------|---------|
| Ubiquitous | THE system SHALL [behavior] | THE system SHALL display pagination controls |
| Event-driven | WHEN [trigger] THE system SHALL [response] | WHEN user clicks "Next" THE system SHALL load page N+1 |
| State-driven | WHILE [state] THE system SHALL [behavior] | WHILE loading THE system SHALL show skeleton UI |
| Unwanted | IF [error] THEN THE system SHALL [recovery] | IF API returns 500 THEN THE system SHALL show retry button |
| Optional | WHERE [config] THE system SHALL [behavior] | WHERE pagination is enabled THE system SHALL show page count |

**Rule:** Each EARS statement = one test case for test-manager.

### Compound Criteria

Combine patterns when needed:
```
WHILE authenticated WHEN user navigates to /admin THE system SHALL display admin panel
IF session expires WHILE user is editing THEN THE system SHALL save draft locally
```

## Change Specification (Brownfield Changes)

For changes to existing behavior, include these sections:

```markdown
## Change Specification

### Current Behavior
<What the system does now — observable, testable>

### Target Behavior (Delta)
<What changes — EARS statements for new behavior>

### Invariants (Must NOT Change)
<Behavior that must remain unchanged — feeds hidden test targets>

### Scope Boundary
<What is explicitly OUT of scope for this change>
```

**Invariants** are critical — they feed the hidden regression tests that the coder never sees.

## Spec Format

```markdown
---
id: SPEC-NNN
title: "Feature Name"
status: draft | approved | implementing | verified | shipped
version: "1.0"
created: YYYY-MM-DD
linked_issues: [PROJECT-NNN]
test-files:
  - tests/unit/feature.test.ts
---

# Feature Name

## §1 Overview
<What this feature does and why it exists>

## §2 Behavior
<Detailed behavior specification>

### Acceptance Criteria (EARS)
- WHEN [trigger] THE system SHALL [response]
- WHILE [state] THE system SHALL [behavior]
- IF [error] THEN THE system SHALL [recovery]

## §3 Change Specification (if brownfield)
### Current Behavior
### Target Behavior (Delta)
### Invariants (Must NOT Change)
### Scope Boundary

## §4 Error Handling
| Input | Expected | Rationale |
|-------|----------|-----------|
| null | 400 error | Explicit validation |
| empty | default behavior | Graceful degradation |

## §5 Constraints
<Performance, security, compatibility requirements>

## §6 Clarifications (from grill session)
<Questions raised during grill and their answers>

## §7 Visual Acceptance Criteria (if UI)
<See Visual Acceptance Criteria section below>
```

## Visual Acceptance Criteria (UI Features)

WHEN a plan modifies UI files (.tsx, .jsx, .vue, .svelte, .css, .scss, .html), include:

```markdown
## §7 Visual Acceptance Criteria

### Design Reference
- DESIGN.md: <path to design system file>
- Pages: <list of pages/routes affected>

### Criteria (EARS)
- WHEN page loads THE system SHALL render layout matching DESIGN.md grid spec
- WHILE viewport < 768px THE system SHALL stack sidebar below content
- THE system SHALL use only design tokens (no hardcoded colors/spacing)

### Visual QA Targets
<Passed to sprint-manager for visual gate>
- Page: /dashboard — check: layout, token usage, responsive
- Page: /settings — check: form alignment, spacing
```

**Flow:** Planner criteria → test-manager targets → sprint-manager visual gate

## Spec-to-Test Traceability

Tests reference spec sections:
```typescript
// @spec feature.spec.md §2 Behavior
describe('feature behavior', () => {
  it('should do X when Y', () => { ... });
});
```

A spec section without a referencing test is **uncovered** — this is tracked.

## Plan Format (derived from spec)

```markdown
# Plan: Feature Name
Derived from: SPEC-NNN

## Approach
<Technical approach chosen>

## Steps (ordered)
1. [ ] Step 1 — <what to do>
2. [ ] Step 2 — <what to do>

## Test Strategy
- Unit: <what to test at unit level>
- Integration: <what to test at integration level>

## Risks
- <Risk 1>: mitigation
```

## Status Values

| Status | Meaning | Who advances |
|--------|---------|--------------|
| draft | Written, not reviewed | Author |
| approved | Ready for planning (post-grill) | Reviewer/supervisor |
| implementing | Plan derived, coders active | Supervisor |
| verified | All tests pass, spec covered | Test gate |
| shipped | Deployed | CI/CD |

## When No Spec Exists

- Bug fix → file an issue, implement, done
- Feature (1 file only) → issue is sufficient
- Feature (>1 file) → write spec first, do not implement without one
