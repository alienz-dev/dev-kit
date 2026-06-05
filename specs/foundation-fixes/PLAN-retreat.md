# Plan: gate.sh Retreat Command

> Derived from SPEC-003. Defines HOW + ORDER.

## Approach

Add a `retreat` command to gate.sh that validates retreat signals against transitions.json
and moves the pipeline backward. Add retreat signal definitions to transitions.json.

## Steps

### Step 1: Add retreat signals to transitions.json
**Files:** `workflow/pipeline/transitions.json`
**Action:** Add new transition signals:
- `review_to_test`: { from: "review", to: "test" }
- `review_to_specced`: { from: "review", to: "plan" }
- `green_to_implementing`: { from: "sprint", to: "sprint" } (re-run sprint stage)

### Step 2: Add cmd_retreat function to gate.sh
**Files:** `workflow/pipeline/gate.sh`
**Action:** Add a `cmd_retreat()` function that:
1. Reads the signal from $1
2. Looks up the signal in transitions.json
3. Validates "from" matches current stage
4. Updates state to "to" stage
5. Appends to history with "direction: backward" marker
6. Prints warning emoji + retreat message

### Step 3: Add retreat case to main dispatch
**Files:** `workflow/pipeline/gate.sh`
**Action:** Add `retreat)` case in the main command dispatch that calls `cmd_retreat`.

### Step 4: Update help text
**Files:** `workflow/pipeline/gate.sh`
**Action:** Add retreat to the usage/help section.

## Test Strategy

1. `bash -n gate.sh` — syntax check
2. `gate.sh init test && gate.sh advance plan_ready && gate.sh advance tests_ready && gate.sh advance sprint_complete` — get to review stage
3. `gate.sh retreat review_to_test` — verify it moves back to test
4. `gate.sh status` — verify stage is "test"
5. `gate.sh retreat review_to_test` — should fail (not in review stage)
6. Verify history contains "direction: backward" marker

## Risks

- **Risk:** Existing scripts that parse state.json break on new history format
  **Mitigation:** History entries are append-only; existing parsers ignore unknown fields
- **Risk:** Retreat from wrong stage corrupts state
  **Mitigation:** Strict "from" validation before any state change
