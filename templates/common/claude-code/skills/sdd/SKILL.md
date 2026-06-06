---
description: Run the SDD implementation pipeline. Reads an approved spec, derives plan, writes tests, dispatches coders, runs review. Fully automatic after design phase.
user-invocable: true
argument-hint: <feature-name>
---

# SDD Implementation: $ARGUMENTS

You are the SDD Orchestrator. You run the automatic implementation phase of the SDD pipeline. The design phase (BA, grill, spec approval) is already complete. You handle everything from plan derivation to code review.

## Resume Mode

If `$ARGUMENTS` starts with "resume", read the pipeline state and continue from where it left off:

```bash
bash workflow/pipeline/gate.sh status
```

1. Read `.pipeline/state.json` to get current stage and feature
2. Read the spec from the feature name
3. Skip to the appropriate phase:
   - If stage is `plan` → start at Phase 1
   - If stage is `test` → start at Phase 2
   - If stage is `sprint` → start at Phase 3
   - If stage is `review` → start at Phase 4
   - If stage is `done` → report complete
4. Resume the pipeline from that phase

## Pre-flight Checks

### 1. Find the approved spec
```bash
# Try common spec path patterns (case-insensitive, strip hyphens)
ARG_UPPER=$(echo "$ARGUMENTS" | tr '[:lower:]' '[:upper:]' | tr -d '-')
ARG_SLUG=$(echo "$ARGUMENTS" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
SPEC_FILE=$(find specs/ -iname "SPEC-*${ARG_UPPER}*" -o -iname "SPEC-*${ARG_SLUG}*" -o -iname "SPEC-*${ARGUMENTS}*" 2>/dev/null | head -1)
```

If no spec found, try: `ls specs/` and look for a match. If still not found, tell the user: "No spec found for '$ARGUMENTS'. Run /grill first to create one, or pass the spec path directly: /sdd specs/SPEC-FOO.md"

### 2. Validate spec status
Read the spec file. Check frontmatter `status:` field.
- If `approved` → proceed
- If `draft` → tell user: "Spec is still draft. Run /approve <spec> to approve it."
- If `implementing`/`verified`/`shipped` → tell user: "Spec already at status X. Use issue pipeline for changes."

### 3. Verify grill occurred
Check if the spec's Clarifications section (§6 or "## Clarifications") has content.
- If non-empty → grill occurred, proceed
- If empty → warn: "Spec has no clarifications. Was a grill session run? Proceeding anyway."

### 4. Validate spec quality
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
2. **Check AC coverage** — verify every EARS acceptance criterion has at least one test:
```bash
bash tools/spec-trace.sh tests/ specs/
```
If uncovered sections found: re-dispatch test-manager with the uncovered list. Only proceed when all sections are covered.
3. **Write AC coverage proof** (required for gate.sh to allow advancing):
```bash
bash workflow/pipeline/gate.sh proof ac_coverage "all sections covered"
```
4. Run tests to confirm RED:
```bash
npm test 2>&1 | tail -5
```
5. All tests should fail. If any pass, the test-manager wrote tests for existing behavior (wrong).

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

## Phase 3: Implementation (Delegate to /trio)

Read `.pipeline/test_map.json` to get test file paths.

Delegate the implementation cycle to the /trio skill:
```
/trio $ARGUMENTS
```

The /trio skill handles:
- Wave dispatch (coder spawning, worktree isolation)
- GREEN gate with escalating retries
- Failure analysis (diagnostic agent after 3 retries)
- Hidden gate
- Post-wave gates (wiring, wave-smoke)

After /trio completes, read the pipeline state:
```bash
bash workflow/pipeline/gate.sh status
```

**Run alignment gate** — verify spec-to-code alignment before review:
```bash
bash workflow/pipeline/alignment-gate.sh "$SPEC_FILE"
```

Exit code handling:
- **0 (ALIGNED)** → proceed to review
- **2 (TEST GAPS)** → re-dispatch test-manager with uncovered ACs, re-run sprint
- **3 (CODE ISSUES)** → dispatch patch wave (see below)
- **4 (SPEC AMBIGUITY)** → flag for user, do not proceed automatically

**Patch wave** (if alignment gate returns 3):
1. Read the alignment report for specific divergences (file:line, expected behavior)
2. Write a scoped patch briefing (includes the specific AC text — info barrier relaxation for this AC only)
3. Spawn coder with patch briefing (max 2 patch waves per issue)
4. Re-run alignment gate after patch
5. If still divergent after 2 patch waves → full re-dispatch

Report:
```
Implementation: complete (via /trio)
  Pipeline stage: <stage>
  Alignment: <ALIGNED|PATCHED|DIVERGENT>
```

---

## Phase 4: Review (Multi-Perspective)

Determine reviewer tier from complexity:
- Complexity 4-7 → reviewer-lite (single reviewer)
- Complexity 8+ → multi-perspective review (3 reviewers in parallel)
- Auto-promote to full if paths match: /auth/, /security/, /crypto/, /api/, /schema/, /migration

### Multi-Perspective Review (complexity 8+)
Spawn 3 reviewers in parallel with different focus. Include the alignment report from Checkpoint C in each reviewer's prompt so they validate pre-found divergences rather than discovering from scratch.

```
# Security reviewer
Agent({
  subagent_type: "reviewer",
  prompt: "Review for SECURITY issues only.\nSpec: <SPEC_FILE>\nModified files: <list>\nAlignment report: <ALIGNMENT_REPORT>\n\nFocus: injection, auth bypass, data leaks, input validation, secrets handling.\nValidate any security-related divergences from the alignment report.\nIgnore style, naming, minor issues.\nVerdict: APPROVE | REQUEST_CHANGES",
  model: "sonnet"
})

# Correctness reviewer
Agent({
  subagent_type: "reviewer",
  prompt: "Review for CORRECTNESS issues only.\nSpec: <SPEC_FILE>\nModified files: <list>\nAlignment report: <ALIGNMENT_REPORT>\n\nFocus: logic errors, edge cases, error handling, off-by-one, null handling.\nValidate any correctness-related divergences from the alignment report.\nIgnore style, naming, minor issues.\nVerdict: APPROVE | REQUEST_CHANGES",
  model: "sonnet"
})

# Performance reviewer
Agent({
  subagent_type: "reviewer",
  prompt: "Review for PERFORMANCE issues only.\nSpec: <SPEC_FILE>\nModified files: <list>\nAlignment report: <ALIGNMENT_REPORT>\n\nFocus: N+1 queries, missing indexes, unnecessary allocations, blocking I/O.\nValidate any performance-related divergences from the alignment report.\nIgnore style, naming, minor issues.\nVerdict: APPROVE | REQUEST_CHANGES",
  model: "sonnet"
})
```

Aggregate verdicts:
- Any REQUEST_CHANGES → REQUEST_CHANGES (with combined findings)
- All APPROVE → APPROVE

### Single Reviewer (complexity 4-7)
Spawn reviewer-lite (adversarial). Include alignment report:
```
Agent({
  subagent_type: "reviewer-lite",
  prompt: "Review changes for <feature>. Be adversarial — try to find bugs, not validate.\nSpec: <SPEC_FILE>\nModified files: <list>\nAlignment report: <ALIGNMENT_REPORT>\n\nCheck: edge cases, error paths, security, concurrency.\nValidate any divergences from the alignment report.\nVerdict: APPROVE | APPROVE_WITH_COMMENTS | REQUEST_CHANGES",
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

Update pipeline (advances to retro stage, not done):
```bash
bash workflow/pipeline/gate.sh advance review_complete
```

Write checkpoint:
```bash
bash workflow/pipeline/checkpoint.sh done '{"feature":"'$ARGUMENTS'","status":"complete","timestamp":"'$(date -Iseconds)'"}'
```

---

## Phase 5.5: Retro (Lightweight, Automatic, Mandatory)

Pipeline is now at the `retro` stage. This phase is **mandatory** — the pipeline cannot advance to `done` without it.

### Step 1: Extract retro from pipeline artifacts
```bash
bash workflow/pipeline/retro-runner.sh "$ARGUMENTS" --lightweight
```
This reads `.pipeline/state.json`, checkpoints, and git log to produce a retro skeleton at `workflow/retro/YYYY-MM-DD-<feature>.md`.

### Step 2: Read the generated retro file
Read the retro file. Review the auto-extracted metrics and findings.

### Step 3: Classify findings
For each finding, classify into one of three types:

| Type | Definition | Action |
|------|-----------|--------|
| **Heuristic** | Process/agent behavior fix | Write to `.agents/knowledge/heuristics/HW-NNN.md`, add to index |
| **Issue** | Code/tooling bug | `issue open "..." --project <slug> --type bug --severity P2 --tags "retro"` |
| **Drop** | One-off, already known, too generic | Note in retro file, no further action |

### Step 4: Execute actions
- Heuristics: create individual file in `.agents/knowledge/heuristics/`, update `.agents/knowledge/heuristics.md` index
- Issues: file via `issue open` CLI
- Drops: note in retro file's Classifications table

### Step 5: Update retro file
Fill in the Classifications table and Forward Plan section of the retro file.

### Step 6: Write retro proof and advance to done
```bash
bash workflow/pipeline/gate.sh proof retro "lightweight retro complete"
bash workflow/pipeline/gate.sh advance retro_complete
```

---

## Phase 5.6: Full Retro (Conditional)

**Only runs if ANY of these conditions are met:**
- Feature complexity >= 8
- More than 2 retries occurred across any gate (check `.pipeline/state.json` backward transitions)
- User explicitly requests full retro
- Session touched multiple features

If conditions are met, run the full retro protocol from `workflow/retro/RETRO.md`:
1. Deep conversation analysis — extract errors, corrections, decisions, dead ends
2. Full classification table with evidence
3. Heuristic creation with detailed Pattern/Evidence/Application/Anti-Pattern sections
4. Forward plan with specific next actions
5. Route outputs: hot memory, project knowledge, workspace state, issue tracker

If conditions are NOT met, skip — the lightweight retro from Phase 5.5 is sufficient.

---

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
Alignment:   <ALIGNED|PATCHED|DIVERGENT>
Retro:       workflow/retro/<date>-<feature>.md
Heuristics:  <N> new | <N> updated
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
