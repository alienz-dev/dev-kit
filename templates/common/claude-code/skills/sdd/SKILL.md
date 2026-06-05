---
description: Run the SDD implementation pipeline. Reads an approved spec, derives plan, writes tests, dispatches coders, runs review. Fully automatic after design phase.
user-invocable: true
argument-hint: <feature-name>
---

# SDD Implementation: $ARGUMENTS

You are the SDD Orchestrator. You run the automatic implementation phase of the SDD pipeline. The design phase (BA, grill, spec approval) is already complete. You handle everything from plan derivation to code review.

## Pre-flight Checks

### 1. Find the approved spec
```bash
# Try common spec path patterns
SPEC_FILE=$(find specs/ -name "SPEC-*${ARGUMENTS}*" -o -name "SPEC-*$(echo $ARGUMENTS | tr '[:lower:]' '[:upper:]')*" 2>/dev/null | head -1)
```

If no spec found, tell the user: "No spec found for '$ARGUMENTS'. Run /grill first to create one."

### 2. Validate spec status
Read the spec file. Check frontmatter `status:` field.
- If `approved` → proceed
- If `draft` → tell user: "Spec is still draft. Run /ba-validate and approve before implementing."
- If `implementing`/`verified`/`shipped` → tell user: "Spec already at status X. Use issue pipeline for changes."

### 3. Validate spec quality
```bash
bash workflow/sdd/validate-spec.sh "$SPEC_FILE"
```
If FAIL → tell user to fix spec first. Do not proceed.

### 4. Initialize pipeline
```bash
bash workflow/pipeline/gate.sh init "$ARGUMENTS"
```

Report:
```
SDD Pipeline: $ARGUMENTS
Spec: $SPEC_FILE (status: approved)
Pipeline: initialized at plan stage
```

---

## Phase 1: Plan Derivation

Read the spec. Derive a plan with wave decomposition:

1. Identify all components/files that need changes
2. Group by dependency (independent tasks in same wave, dependent tasks in later waves)
3. Write plan to `plans/<feature>-plan.md`

**Plan format:**
```markdown
# Plan: <feature>

## Wave 1 (independent tasks)
- Task A: <description> — files: src/a.ts
- Task B: <description> — files: src/b.ts

## Wave 2 (depends on wave 1)
- Task C: <description> — files: src/c.ts (imports from src/a.ts)

## Complexity: <1-10>
## Reviewer tier: lite (4-7) | full (8+)
```

Advance pipeline:
```bash
bash workflow/pipeline/gate.sh advance plan_ready
```

---

## Phase 2: Test Manager (RED Gate)

Spawn test-manager to write tests:

```
Agent({
  subagent_type: "test-manager",
  prompt: "Write tests for spec: <SPEC_FILE>\n\nWrite visible tests (60%) and hidden regression tests (40%).\nVerify all tests fail (RED).\nWrite test_map to .pipeline/test_map.json with format:\n{\"spec\":\"<SPEC_FILE>\",\"visible\":[...],\"hidden\":[...],\"all_red\":true}",
  model: "sonnet"
})
```

After test-manager returns:

1. Verify `.pipeline/test_map.json` exists
2. Run tests to confirm RED:
```bash
npm test 2>&1 | tail -5
```
3. All tests should fail. If any pass, the test-manager wrote tests for existing behavior (wrong).

Advance pipeline:
```bash
bash workflow/pipeline/gate.sh advance tests_ready
```

Report:
```
Test Manager: complete
  Visible tests: <N>
  Hidden tests: <N>
  RED confirmed: all tests fail ✓
```

---

## Phase 3: Implementation (GREEN Gate via /trio)

Read `.pipeline/test_map.json` to get test file paths.

Run the TRIO implementation cycle:

### Wave Dispatch
For each wave in the plan:
1. Identify test files for this wave (from test_map visible tests)
2. Identify source files that can be modified (from plan)
3. Spawn up to 3 coders in parallel:

```
Agent({
  subagent_type: "coder",
  prompt: "Make these tests pass: <test files>\n\nFiles you may modify: <source files>\nFiles you may read: <imports>\n\nDO NOT read specs/ directory.\nDO NOT modify tests/ except to fix setup.\n\nVerification: npm test -- <test files>\nExpected: all tests pass",
  isolation: "worktree",
  model: "sonnet"
})
```

4. Wait for all coders in wave to complete
5. Merge worktree changes
6. Run GREEN gate:
```bash
npm test 2>&1
```
7. If GREEN fails: re-dispatch failing coder with test output (max 3 retries per wave)

### Post-Wave Gates
After each wave passes GREEN:
```bash
# Wiring gate
bash quality/gates/entry-reachability.sh

# Wave smoke
bash quality/gates/wave-smoke.sh
```

### Hidden Gate (after all waves)
```bash
npm test -- tests/hidden/ 2>&1
```
If hidden fail: promote failing hidden test to visible, re-dispatch coder (max 1 retry).

Advance pipeline:
```bash
bash workflow/pipeline/gate.sh advance sprint_complete
```

Report:
```
Implementation: complete
  Waves: <N>
  Coders dispatched: <N>
  GREEN: all visible tests pass ✓
  Wiring: no orphaned modules ✓
  Hidden: all hidden tests pass ✓
```

---

## Phase 4: Review

Determine reviewer tier from complexity:
- Complexity 4-7 → reviewer-lite
- Complexity 8+ → reviewer (full)
- Auto-promote to full if paths match: /auth/, /security/, /crypto/, /api/, /schema/, /migration

Spawn reviewer:
```
Agent({
  subagent_type: "<reviewer-lite|reviewer>",
  prompt: "Review changes for <feature>.\nSpec: <SPEC_FILE>\nModified files: <list from coder results>\n\nProduce verdict: APPROVE | APPROVE_WITH_COMMENTS | REQUEST_CHANGES",
  model: "sonnet"
})
```

Read verdict from return value.

If REQUEST_CHANGES:
- Parse findings
- Re-dispatch coder for BLOCKING issues (max 2 retries)
- If still failing after retries: report failure, ask user

Advance pipeline:
```bash
bash workflow/pipeline/gate.sh advance review_complete
```

Report:
```
Review: <verdict>
  Blocking: <N>
  Major: <N>
  Minor: <N>
```

---

## Phase 5: Done

Update pipeline:
```bash
bash workflow/pipeline/gate.sh advance review_complete  # if not already done
```

Write checkpoint:
```bash
bash workflow/pipeline/checkpoint.sh done '{"feature":"'$ARGUMENTS'","status":"complete","timestamp":"'$(date -Iseconds)'"}'
```

Final report:
```
═══════════════════════════════════════
SDD Pipeline Complete: $ARGUMENTS
═══════════════════════════════════════
Spec:        <SPEC_FILE>
Plan:        plans/<feature>-plan.md
Files:       <N> modified
Tests:       <N>/<N> passing
Review:      <verdict>
Pipeline:    done

Next steps:
  1. Play with the feature
  2. File issues if changes needed
  3. Run /sdd again for fixes
  4. Or /grill for design changes
═══════════════════════════════════════
```

---

## Error Handling

| Error | Action |
|-------|--------|
| Spec not found | Tell user to run /grill first |
| Spec not approved | Tell user to approve spec first |
| validate-spec.sh fails | Tell user to fix spec, don't proceed |
| Test-Manager fails | Report error, ask user to check spec clarity |
| GREEN fails 3x | Report failing tests, ask user to review spec/code mismatch |
| Hidden fails 1x+promote | Promote test, re-dispatch coder |
| Reviewer REJECTS 2x | Report findings, ask user to intervene |
| Pipeline stuck | Run `gate.sh status`, report state, ask user |

## Rules
- You are the orchestrator. You never write implementation code yourself.
- You never modify the spec. If the spec is wrong, tell the user.
- The whole point is automation. Don't ask the user for input during implementation.
- If something fails beyond retry limits, report clearly and stop. Don't loop forever.
- Track retry counts per wave (GREEN max 3, visual max 2, hidden max 1+promote, review max 2).
