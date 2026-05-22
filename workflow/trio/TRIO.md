# TRIO Protocol

**T**est → **R**ed → **I**mplement → **O**bserve

## Why

Agents skip testing, write tests after code, or write tests that don't verify behavior. TRIO enforces the correct order with external gates that cannot be bypassed.

## The Iron Law

```
The coder NEVER sees the spec. They only see failing tests.
```

This prevents "implement to spec" shortcuts where the coder reads the spec and writes code that satisfies the words but not the intent. When they only have tests, they must make the tests pass — which IS the intent.

## State Machine

```
open → specced → tests_written → red_verified → implementing → green → reviewing → closed
```

## Gates

| From | To | Gate | Verified By |
|------|----|------|-------------|
| open | specced | Spec file exists and is linked | Supervisor |
| specced | tests_written | Test files exist with ≥1 assertion | Test-manager |
| tests_written | red_verified | ALL tests fail (RED confirmed) | Automated |
| red_verified | implementing | Coder spawned with tests-only briefing | Supervisor |
| implementing | green | All visible tests pass | Automated |
| green | reviewing | Reviewer spawned with spec access | Supervisor |
| reviewing | closed | Reviewer approves AND hidden tests pass | Automated + Reviewer |

## Backward Transitions (Rework)

| From | To | When |
|------|----|------|
| reviewing → specced | Spec needs revision (unfreezes spec) |
| reviewing → red_verified | New tests needed (reviewer found gap) |
| green → implementing | Hidden regression tests failed |
| implementing → tests_written | Approach fundamentally wrong |

## Roles in TRIO

### Supervisor (orchestrator)
- Creates issues, writes specs
- Spawns test-manager, monitors gates
- Never writes source code

### Test-Manager (persistent)
- Owns the full RED→GREEN cycle
- Writes test files from spec
- Verifies RED (all fail)
- Spawns coder with tests-only briefing
- Verifies GREEN (all pass)
- Runs hidden regression tests

### Coder (ephemeral)
- Receives: failing test files + project context
- Does NOT receive: spec, design docs, or "what it should do" prose
- Writes minimal code to make tests pass
- Self-closes when done

### Reviewer (ephemeral)
- Receives: spec + implementation + test results
- Verifies implementation matches spec intent
- Can reject (→ rework) or approve (→ closed)

## Constitution File

```yaml
# constitution.yml — placed in project root
forward_transitions:
  - from: open
    to: specced
    gate: spec_linked
  - from: specced
    to: tests_written
    gate: tests_exist
  - from: tests_written
    to: red_verified
    gate: all_tests_fail
  - from: red_verified
    to: implementing
    gate: coder_assigned
  - from: implementing
    to: green
    gate: visible_tests_pass
  - from: green
    to: reviewing
    gate: reviewer_assigned
  - from: reviewing
    to: closed
    gate: approved_and_hidden_pass

backward_transitions:
  - from: reviewing
    to: specced
    gate: reason_required
    unfreezes_spec: true
  - from: reviewing
    to: red_verified
    gate: new_tests_fail
  - from: green
    to: implementing
    gate: hidden_promoted
  - from: implementing
    to: tests_written
    gate: reason_required
```

## Hidden Tests

Hidden tests are regression tests the coder never sees. They verify:
- Edge cases the spec mentions but tests don't explicitly cover
- Integration behavior across module boundaries
- Invariants that should never break

Hidden tests only run at the `reviewing → closed` gate. If they fail, the issue goes back to `implementing`.

## Example Flow

1. **Supervisor** creates issue `PROJ-042: Add pagination to /users`
2. **Supervisor** writes `specs/pagination.spec.md` → issue status: `specced`
3. **Supervisor** spawns test-manager
4. **Test-manager** reads spec, writes `tests/unit/pagination.test.ts` → status: `tests_written`
5. **Test-manager** runs tests, confirms all fail → status: `red_verified`
6. **Test-manager** spawns coder with briefing: "Make these tests pass: [test file paths]"
7. **Coder** reads tests, implements `src/routes/users.ts` → status: `implementing`
8. **Test-manager** runs tests, all pass → status: `green`
9. **Supervisor** spawns reviewer with spec + code
10. **Reviewer** approves, hidden tests pass → status: `closed`

## Anti-Patterns

- ❌ Coder reads the spec → implements to words, not intent
- ❌ Tests written after code → tests verify implementation, not behavior
- ❌ Skipping RED verification → tests might already pass (testing nothing)
- ❌ Single agent does everything → no external verification
- ❌ "I'll add tests later" → never happens
