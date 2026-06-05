# Spec Change Protocol

When a spec needs to change mid-implementation, follow this protocol. It ensures the spec-test-code triangle stays consistent.

## When to Trigger

A spec change is needed when:
- A design mismatch is discovered during implementation
- A stakeholder changes a requirement
- An edge case invalidates spec assumptions
- A performance/security constraint is discovered that changes behavior
- The coder finds that the spec's acceptance criteria are untestable or contradictory

**Do NOT trigger for:** bugs in implementation (fix the code), typos in spec (fix the spec), or missing test coverage (add tests).

## Protocol Steps

### 1. Pause the Sprint
The Sprint-Manager holds the current state. No new coder dispatches until the spec change is resolved.

### 2. Create/Update an Issue
File an issue with the `spec-change` label documenting:
- What divergence was found
- Which spec sections are affected
- Why the current spec or code is wrong

### 3. Run Spec Alignment
Use the `/spec-align` skill to get a structured divergence report:
```
/spec-align specs/SPEC-FOO.md "description of the divergence"
```
This produces a reconciliation report with specific recommendations per criterion.

### 4. Review the Change (if architectural impact)
If the change touches architecture (new services, data models, API contracts), spawn an Architect agent for a 5-lens critique. Skip for minor behavioral changes.

### 5. Update the Spec
The Planner updates the spec:
- **Version bump** — increment the `version` field in frontmatter
- **Status** — set to `draft` (re-approval needed)
- **Change Specification** — update all four subsections:
  - **Current Behavior** — what the code actually does now
  - **Target Behavior (Delta)** — what needs to change (new/modified EARS criteria)
  - **Invariants** — what must NOT change (feeds hidden regression tests)
  - **Scope Boundary** — what is explicitly out of scope for this change
- **Acceptance Criteria** — add/modify/remove EARS criteria for the delta

### 6. Validate the Updated Spec
Run `/ba-validate` on the updated spec:
```
/ba-validate specs/SPEC-FOO.md
```
Fix any BLOCKING issues before proceeding.

### 7. Update Tests
The Test-Manager updates tests for the delta:
- **New RED** — write tests for changed/new acceptance criteria
- **Hidden tests** — write regression tests for invariants
- **Verify coverage** — run `spec-trace.sh` to confirm all spec sections are covered
- **Verify RED** — all new tests must fail against current code

### 8. Resume the Sprint
The Sprint-Manager dispatches coders with the updated failing tests. Coders see only the tests, never the spec changes.

### 9. Review the Delta
The Reviewer verifies that the implementation matches the updated spec's delta (not the original spec). Focus on:
- New/modified acceptance criteria are satisfied
- Invariants are preserved
- No regressions in existing behavior

### 10. Resolve
Mark the spec-change issue as resolved. Update spec status to `implementing` → `verified` → `shipped` as the pipeline progresses.

## Gate Integration

The `review_to_specced` transition in `transitions.json` handles the pipeline retreat:

```bash
# Retreat from review to plan (spec needs changes)
bash workflow/pipeline/gate.sh retreat review_to_specced
```

This moves the pipeline from `review` back to `plan`, allowing the full test → sprint → review cycle to re-run with updated specs and tests.

## Anti-patterns

| Anti-pattern | Why it's wrong | Correct approach |
|-------------|---------------|-----------------|
| Update spec without updating tests | Tests pass but don't verify new behavior | Always run Test-Manager after spec change |
| Skip ba-validate after spec change | Spec may have structural errors | Always validate before re-entering pipeline |
| Resume sprint without new RED gate | Coders have no failing tests to fix | All new tests must fail before coder dispatch |
| Not bumping spec version | Can't track which version of spec code matches | Always increment version on behavioral change |
| Update code without updating spec | Spec and code silently diverge | Either update spec or fix code, never let them drift |
| Re-plan from scratch for small changes | Wastes effort, loses context | Use delta spec (Change Specification) for incremental changes |

## Example: Spec Change Mid-Sprint

```
1. Coder discovers: spec says "THE system SHALL return 400 for invalid email"
   but the code returns 422 (which is actually correct per HTTP standards)

2. Sprint-Manager pauses sprint

3. Issue created: "Spec-change: HTTP status code for validation errors"

4. /spec-align produces:
   DIV-1: DIVERGENT — spec says 400, code does 422
   Recommendation: UPDATE SPEC (422 is correct per HTTP standards)

5. Planner updates spec:
   - Version: 1.0 → 1.1
   - AC-1: "WHEN invalid email THE system SHALL return 422" (was 400)
   - Change Specification: Current=400, Target=422, Invariant=validation errors return 4xx

6. /ba-validate passes

7. Test-Manager updates test: expect(response.status).toBe(422)
   Hidden test: "validation errors always return 4xx"

8. Sprint resumes — coder makes test pass (code already does 422)

9. Reviewer verifies: delta matches updated spec

10. Issue resolved, spec status → verified
```
