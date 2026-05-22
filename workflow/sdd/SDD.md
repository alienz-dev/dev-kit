# Spec-Driven Development (SDD)

## Why

Agents implement wrong things without a contract. Code without a spec is a guess. Specs are the single source of truth — if code diverges from spec, one must be updated.

## Lifecycle

```
Idea → Spec (draft) → Spec (approved) → Plan (derived) → Implement (TDD) → Verify → Ship
```

## Rules

1. Every feature touching >1 file MUST have a spec before implementation.
2. Bug fixes use issues only — no spec needed.
3. Specs define WHAT + WHY. Plans define HOW + ORDER.
4. Plans are derived from specs — never the reverse.
5. Spec is the contract. If code diverges from spec, either update spec or fix code.
6. Tests are executable assertions of spec sections.

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
<Detailed behavior specification with acceptance criteria>

### Acceptance Criteria
- GIVEN <precondition> WHEN <action> THEN <result>
- GIVEN <precondition> WHEN <action> THEN <result>

## §3 Error Handling
<What happens when things go wrong>

| Input | Expected | Rationale |
|-------|----------|-----------|
| null | 400 error | Explicit validation |
| empty | default behavior | Graceful degradation |

## §4 Constraints
<Performance, security, compatibility requirements>
```

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
| approved | Ready for planning | Reviewer/supervisor |
| implementing | Plan derived, coders active | Supervisor |
| verified | All tests pass, spec covered | Test gate |
| shipped | Deployed | CI/CD |

## When No Spec Exists

- Bug fix → file an issue, implement, done
- Feature (1 file only) → issue is sufficient
- Feature (>1 file) → write spec first, do not implement without one
