# Plan: Daemon Claims Cleanup

> Derived from SPEC-005. Defines HOW + ORDER.

## Approach

Replace all "daemon-enforced" claims with honest documentation of actual enforcement
mechanisms: gate.sh (file-based FSM), lefthook (pre-commit hooks), and agent prompts
(behavioral constraints).

## Steps

### Step 1: Rewrite PIPELINE-ENFORCEMENT.md
**Files:** `workflow/pipeline/PIPELINE-ENFORCEMENT.md`
**Action:** Replace daemon description with:
- gate.sh: file-based FSM that tracks pipeline state
- lefthook: pre-commit hooks that enforce test gates
- Agent prompts: role definitions that constrain behavior
- What IS enforced (test gates, stage progression)
- What is NOT enforced (role_policies, stall detection, deniedPaths)

### Step 2: Update ROLES.md
**Files:** `agents/roles/ROLES.md`
**Action:** Replace "daemon-enforced" with:
- "structurally enforced by agent role definition" for prompt-based constraints
- "gate.sh-enforced" for pipeline stage constraints
- "lefthook-enforced" for pre-commit constraints
Keep all behavioral rules — just change the enforcement description.

### Step 3: Update TRIO.md
**Files:** `workflow/trio/TRIO.md`
**Action:** Replace "daemon-enforced" with "gate.sh-enforced" throughout.
Keep all pipeline stage descriptions — just change the enforcement claim.

### Step 4: Update README.md
**Files:** `README.md`
**Action:** Change "Pipeline (Daemon-Enforced)" to "Pipeline (gate.sh + lefthook)".
Update the pipeline description to reflect actual enforcement.

### Step 5: Update ARCHITECTURE.md
**Files:** `docs/ARCHITECTURE.md`
**Action:** Update enforcement section to describe actual mechanisms.
Remove daemon references.

## Test Strategy

1. `grep -rn "daemon" docs/ agents/ workflow/ README.md` — should find no daemon claims
2. `grep -rn "enforced" docs/ agents/ workflow/` — should find "gate.sh-enforced" and "structurally enforced"
3. Verify all behavioral rules in ROLES.md are preserved (diff check)
4. Verify TRIO.md pipeline stages are preserved (diff check)

## Risks

- **Risk:** Losing behavioral rules during cleanup
  **Mitigation:** Diff before/after — every rule must have a corresponding entry in new docs
- **Risk:** Confusion about what's actually enforced
  **Mitigation:** Clear three-tier model: code-enforced (gate.sh, lefthook), prompt-enforced (agent roles), honor-system (everything else)
