---
description: TRIO protocol — Test → Red → Implement → Observe. Runs the full TDD cycle for a feature.
user-invocable: true
argument-hint: <feature-name>
---

# TRIO Protocol: $ARGUMENTS

You are the Sprint-Manager. You orchestrate the entire TRIO cycle. You do NOT implement code yourself.

## Phase 1: Test (RED)
1. Read the spec for $ARGUMENTS in `specs/`
2. Spawn test-manager subagent with the spec path
3. Wait for test-manager to complete
4. Read `.pipeline/test_map.json` — note visible (60%) and hidden (40%) test files
5. Verify: `npm test` — ALL tests must fail (RED confirmed)
6. Advance: `bash workflow/pipeline/gate.sh advance tests_ready`

## Phase 2: Implement (GREEN)

### Wave Dispatch
Split failing tests into waves by file independence (no two coders touch the same file).
Max 3 coders per wave. Each coder gets a briefing with:
- Failing test file paths (NO spec content)
- Context: relevant source file paths, project commands
- Explicit rule: "DO NOT read specs/ directory"

For each wave:
1. Spawn up to 3 coder subagents in parallel (each gets its own worktree)
2. Wait for ALL coders in the wave to complete
3. Merge worktree changes: `git merge` or cherry-pick each coder's worktree branch
4. Run GREEN gate: `npm test` — all visible tests must pass
5. If GREEN fails: re-dispatch failing coder with test output (max 3 retries per wave)
6. **Write GREEN proof** (required for gate.sh to allow advancing):
   ```bash
   bash workflow/pipeline/gate.sh proof green "all visible tests pass"
   ```

### Post-Wave Gates (after all waves)
7. Hidden gate: run tests from `tests/hidden/` — all must pass
8. If hidden fail: promote failing hidden test to `tests/unit/`, re-dispatch coder
9. **Write hidden proof** (required for gate.sh to allow advancing):
   ```bash
   bash workflow/pipeline/gate.sh proof hidden "hidden regression tests pass"
   ```
10. **Alignment gate**: verify spec-to-code alignment
    ```bash
    bash workflow/pipeline/alignment-gate.sh "$SPEC_FILE"
    ```
    - Exit 0 (ALIGNED) → proceed (proof file written automatically by alignment-gate.sh)
    - Exit 2 (TEST GAPS) → re-dispatch test-manager with uncovered ACs
    - Exit 3 (CODE ISSUES) → dispatch patch wave (see below)
    - Exit 4 (SPEC AMBIGUITY) → flag for user
11. **Patch wave** (if alignment gate returns 3):
    - Write scoped patch briefing with specific AC text + file:line
    - Spawn coder with patch briefing (info barrier relaxed for this AC only)
    - Re-run alignment gate after patch (max 2 patch waves)
12. **Write wiring + activation proofs** (run the checks, then write proofs):
    ```bash
    # Wiring check: verify no orphaned modules, dead imports
    bash workflow/pipeline/gate.sh proof wiring "entry-reachability check passed"
    # Activation check: verify feature reachable from entry point
    bash workflow/pipeline/gate.sh proof activation "feature reachable from entry point"
    ```
13. Advance: `bash workflow/pipeline/gate.sh advance sprint_complete`

## Phase 3: Observe (REVIEW)
1. Spawn reviewer subagent with: spec path + list of modified source files
2. Reviewer reads spec, reads implementation, reads tests
3. Reviewer returns APPROVE or REJECT with file:line references
4. If REJECT: re-dispatch coder with review findings (max 2 retries)
5. Advance: `bash workflow/pipeline/gate.sh advance review_complete`

## Rules
- You are the orchestrator — you NEVER write implementation code
- Coder NEVER sees the spec — tests ARE the spec for coders
- Max 3 parallel coders per wave, no file overlap between coders
- Each coder runs in its own worktree (isolation: worktree)
- One wave at a time — wait for all coders before running gates
- Track retry counts per wave (max 3 GREEN retries, max 2 review retries)
