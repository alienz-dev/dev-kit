# Plan: Gate Scripts Audit — Implement or Remove

> Derived from SPEC-002. Defines HOW + ORDER.

## Approach

Implement the five missing gate scripts as simple bash scripts. Each script performs a
single check and exits 0 (pass) or 1 (fail). Keep them minimal — the goal is to have
working gates, not complex tooling.

## Steps

### Step 1: Create quality/gates/ directory
**Files:** `quality/gates/`
**Action:** `mkdir -p quality/gates`

### Step 2: Implement entry-reachability.sh (wiring gate)
**Files:** `quality/gates/entry-reachability.sh`
**Action:** Grep all exported symbols from src/ and check each is imported somewhere.
Simple approach: `grep -r "export " src/ | grep -oP "(?<=export )\w+" | sort -u` then
for each symbol, check `grep -r "import.*$symbol" src/ tests/`.
Print pass/fail with count of unreachable exports.

### Step 3: Implement wave-smoke.sh
**Files:** `quality/gates/wave-smoke.sh`
**Action:** Run `npx vitest run --reporter=verbose` on the test directory.
Exit 0 if all pass, 1 if any fail. Print test count and pass/fail summary.

### Step 4: Implement activation-gate.sh
**Files:** `quality/gates/activation-gate.sh`
**Action:** Two checks: (1) all tests pass (re-run vitest), (2) no TODO/FIXME in files
changed since last commit (`git diff --name-only HEAD~1 | xargs grep -l "TODO\|FIXME"`).
Print each check result. Exit 0 only if both pass.

### Step 5: Implement review-precheck.sh
**Files:** `quality/gates/review-precheck.sh`
**Action:** Check: (1) diff is under 500 lines (`git diff --stat HEAD~1`), (2) no banned
patterns (`grep -rn "rm -rf\|force push\|git push -f" src/`). Print each check result.

### Step 6: Implement ui-visual-check.sh (graceful skip)
**Files:** `quality/gates/ui-visual-check.sh`
**Action:** Check if tools/ui-visual-check submodule is initialized. If yes, run the tool.
If no, print "skipped — ui-visual-check submodule not available" and exit 0.

### Step 7: Make all scripts executable
**Action:** `chmod +x quality/gates/*.sh`

### Step 8: Update TRIO.md and ARCHITECTURE.md
**Files:** `workflow/trio/TRIO.md`, `docs/ARCHITECTURE.md`
**Action:** Verify all gate script paths match the actual file locations. Update if needed.

## Test Strategy

1. Run each script individually and verify it exits cleanly
2. `bash -n quality/gates/*.sh` — syntax check all scripts
3. Run `quality/gates/entry-reachability.sh` in the dev-kit repo (should pass or report results)
4. Run `quality/gates/wave-smoke.sh` — should report "no tests found" (dev-kit has no vitest)
5. Verify all scripts complete in under 30 seconds

## Risks

- **Risk:** entry-reachability.sh false positives (type exports, re-exports)
  **Mitigation:** Only check `export function` and `export const`, skip `export type` and `export *`
- **Risk:** wave-smoke.sh fails in dev-kit (no vitest config)
  **Mitigation:** Print "no test config found" and exit 0 gracefully
