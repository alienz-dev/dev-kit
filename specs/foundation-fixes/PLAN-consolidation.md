# Plan: State Machine Consolidation

> Derived from SPEC-001. Defines HOW + ORDER.

## Approach

Consolidate the four state machines by making `transitions.json` the single source of truth.
gate.sh reads from it instead of hardcoding stages. Documentation references it instead of
maintaining separate lists.

## Steps

### Step 1: Expand transitions.json
**Files:** `workflow/pipeline/transitions.json`
**Action:** Add the full state set including TRIO sub-states as gate checks within the sprint stage.
Keep the 6 top-level stages (plan, test, sprint, review, done, failed) but add a `gates` object
documenting the sub-gates within sprint (wiring, visual, hidden, activation).

### Step 2: Update gate.sh to read from transitions.json
**Files:** `workflow/pipeline/gate.sh`
**Action:** Replace the hardcoded `stage_index()` function with one that reads the `stages` array
from transitions.json. Use jq if available, fall back to grep/sed.

### Step 3: Update TRIO.md to reference transitions.json
**Files:** `workflow/trio/TRIO.md`
**Action:** Replace the inline state list with a reference to transitions.json. Keep the gate
descriptions but note they are sub-gates within the sprint stage.

### Step 4: Update LIFECYCLE.md with explicit mapping
**Files:** `workflow/issue-lifecycle/LIFECYCLE.md`
**Action:** Add a mapping table: issue states → pipeline stages. Remove any states that don't map.

### Step 5: Remove or reduce constitution.yml
**Files:** `scaffold.sh` (the section that generates constitution.yml)
**Action:** Remove state definitions from constitution.yml generation. Keep only non-state config
(project name, constraints) if any.

### Step 6: Update ARCHITECTURE.md
**Files:** `docs/ARCHITECTURE.md`
**Action:** Update the pipeline section to reference transitions.json as the single source of truth.

## Test Strategy

1. Run `bash -n gate.sh` — syntax check
2. Run `gate.sh init test-feature && gate.sh status` — verify it reads from transitions.json
3. Run `gate.sh advance plan_ready && gate.sh status` — verify forward transitions work
4. Verify transitions.json is valid JSON: `jq . transitions.json`
5. Grep TRIO.md, LIFECYCLE.md, ARCHITECTURE.md for state lists that duplicate transitions.json — should find none

## Risks

- **Risk:** Existing .pipeline/state.json files reference stages not in new transitions.json
  **Mitigation:** Keep the same 6 top-level stages — only add documentation, not change vocabulary
- **Risk:** gate.sh jq fallback breaks on complex JSON
  **Mitigation:** Keep the gates object flat and simple
