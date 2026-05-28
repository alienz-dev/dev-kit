# TRIO Protocol

**T**est → **R**ed → **I**mplement → **O**bserve

## Why

Agents skip testing, write tests after code, or write tests that don't verify behavior. TRIO enforces the correct order with external gates that cannot be bypassed.

## The Iron Law

```
The coder NEVER sees the spec. They only see failing tests.
```

This prevents "implement to spec" shortcuts where the coder reads the spec and writes code that satisfies the words but not the intent. When they only have tests, they must make the tests pass — which IS the intent.

## Role Separation

| Role | Responsibility | Spawns |
|------|---------------|--------|
| Supervisor/Planner | Writes spec, spawns test-manager + sprint-manager | test-manager, sprint-manager |
| Test-Manager | Writes tests, verifies RED | tester (for help) |
| Sprint-Manager | Dispatches coders, runs all gates, spawns reviewer | coder ×N, reviewer-lite, reviewer |
| Coder | Makes tests pass | — |

**Critical:** Test-manager does NOT spawn coders. Sprint-manager does NOT write tests. This separation is daemon-enforced via role_policies.

## Pipeline Stages (Daemon-Enforced)

```
plan → test → sprint → review → done | failed
```

Signals: `plan_ready` → `tests_ready` → `sprint_complete` → `review_complete`

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
| red_verified | implementing | Sprint-manager dispatches coder | Sprint-manager |
| implementing | green | All visible tests pass | Automated (GREEN gate) |
| green | wiring_verified | Entry-reachability check passes | Automated (wiring gate) |
| wiring_verified | visual_verified | UI visual check passes (UI only) | Automated (visual gate) |
| visual_verified | hidden_verified | Hidden regression tests pass | Automated (hidden gate) |
| hidden_verified | activation_verified | Activation gate passes | Automated |
| activation_verified | reviewing | Reviewer spawned | Sprint-manager |
| reviewing | closed | Reviewer approves | Reviewer |

### Gate Sequence Per Wave

```
trio-preflight.sh → [coder dispatch] → GREEN → wiring → visual → wave-smoke.sh
```

After all waves complete:
```
hidden → activation → review
```

### Visual Gate (UI projects only)

After GREEN, if the changeset includes UI files (.tsx, .jsx, .vue, .svelte, .css, .scss, .html, .ejs, .hbs):

```bash
ui-visual-check.sh --gate --baseline <project>/screenshots/baselines \
  --url <dev-server-url> --files <changed> --design DESIGN.md
```

**Pass:** `--save-baseline`, proceed to next gate.
**Fail:** Re-dispatch coder with visual findings (max 2 visual retries).
**No dev server:** `--files` only (Layer 1 static lint).

## Backward Transitions (Rework)

| From | To | When |
|------|----|------|
| reviewing → specced | Spec needs revision (unfreezes spec) |
| reviewing → red_verified | New tests needed (reviewer found gap) |
| green → implementing | Hidden regression tests failed |
| implementing → tests_written | Approach fundamentally wrong |

## Failure Handling

| Gate | Max Retries | On Exhaust |
|------|-------------|------------|
| GREEN | 3 | Pipeline status → failed |
| Visual | 2 | Pipeline status → failed |
| Hidden | 1 | Promote hidden test to visible, re-dispatch coder |

## Roles in TRIO

### Supervisor (orchestrator)
- Creates issues, writes specs
- Spawns test-manager and sprint-manager
- Never writes source code
- Never spawns coders directly (daemon-enforced)

### Test-Manager (persistent, owns RED)
- Writes test files from spec (visible + hidden)
- Verifies RED (all fail for the right reasons)
- Signals `tests_ready` when RED confirmed
- After sprint: runs hidden regression tests
- Does NOT spawn coders

### Sprint-Manager (ephemeral, owns GREEN→REVIEW)
- Receives plan + test_map
- Dispatches coders in waves (max 3 parallel, no file overlap)
- Runs gate sequence after each wave
- Spawns reviewer (tier 2 or 3 based on complexity)
- Reports result to supervisor

### Coder (ephemeral)
- Receives: failing test files + project context from sprint-manager
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
    gate: sprint_manager_dispatched
  - from: implementing
    to: green
    gate: visible_tests_pass
  - from: green
    to: wiring_verified
    gate: entry_reachability_pass
  - from: wiring_verified
    to: visual_verified
    gate: ui_visual_check_pass
    condition: changeset_includes_ui_files
  - from: visual_verified
    to: hidden_verified
    gate: hidden_tests_pass
  - from: hidden_verified
    to: activation_verified
    gate: activation_gate_pass
  - from: activation_verified
    to: reviewing
    gate: reviewer_assigned
  - from: reviewing
    to: closed
    gate: approved

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

Hidden tests run at the hidden gate (after all waves complete). If they fail:
1. Sprint-manager promotes the failing hidden test to visible
2. Re-dispatches coder with the now-visible test

## Example Flow

1. **Supervisor** creates issue `PROJ-042: Add pagination to /users`
2. **Supervisor** writes `specs/pagination.spec.md` → issue status: `specced`
3. **Supervisor** spawns test-manager: `kiro-ctl spawn test-manager "Own RED gate for PROJ-042" --topic`
4. **Test-manager** reads spec, writes `tests/unit/pagination.test.ts` → status: `tests_written`
5. **Test-manager** runs tests, confirms all fail → status: `red_verified`, signals `tests_ready`
6. **Supervisor** spawns sprint-manager: `kiro-ctl spawn sprint-manager "GREEN→REVIEW for PROJ-042" --subscribe`
7. **Sprint-manager** dispatches coder: `kiro-ctl spawn coder "Make these tests pass" --subscribe`
8. **Coder** reads tests, implements `src/routes/users.ts`, writes result, self-closes
9. **Sprint-manager** runs GREEN gate → pass → wiring gate → pass → visual gate → pass
10. **Sprint-manager** runs hidden gate → pass → activation gate → pass
11. **Sprint-manager** spawns reviewer-lite (Tier 2)
12. **Reviewer** approves → status: `closed`

## Anti-Patterns

- ❌ Coder reads the spec → implements to words, not intent
- ❌ Tests written after code → tests verify implementation, not behavior
- ❌ Skipping RED verification → tests might already pass (testing nothing)
- ❌ Single agent does everything → no external verification
- ❌ Planner spawns coder directly → bypasses sprint-manager gates
- ❌ Test-manager spawns coder → role confusion, no gate enforcement
- ❌ Tests verify existence not behavior → `expect(result).toBeDefined()` passes for any return value
- ❌ Silent partial success → "all tests pass" when 2 were silently skipped

## Gate Enforcement

Production observation: agents skip gates unless explicitly mandated in their prompts.

### Fix Applied
- Daemon role_policies: `planner→coder = NEVER`, `sprint-manager→coder = ALWAYS`
- Sprint-manager prompt: "Mandatory Gate Sequence (DO NOT SKIP)" with explicit exit-code handling
- Gates positioned at exact workflow step (not in a separate section)

### Lesson
Writing gates in a protocol doc is insufficient. Gates must be:
1. In the agent's prompt (not just a referenced doc)
2. Phrased as "DO NOT SKIP" with explicit exit-code handling
3. Positioned at the exact workflow step where they run
4. Daemon-enforced where possible (role_policies)
