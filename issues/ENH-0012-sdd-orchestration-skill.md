---
id: ENH-0012
title: "SDD Orchestration Skill — interactive design, automatic implementation"
status: resolved
priority: high
component: skill
requested_by: ding
date: 2026-06-05
labels: [enhancement, sdd, skill, p0]
---

## Problem Statement

The SDD pipeline has two distinct phases with different interaction models:

1. **Design phase** (interactive) — requires user decisions: BA gathering requirements, grill session for design choices, spec approval
2. **Implementation phase** (automatic) — should run without human intervention: plan → tests → coders → review → done

Currently the user must manually invoke each step: spawn BA, write spec, run /grill, run /ba-validate, spawn test-manager, run /trio. There's no single command that says "after design is done, run everything automatically until implementation is complete."

## User Workflow Vision

```
User: "add dark mode"
  ↓
[INTERACTIVE] Design session
  - BA gathers requirements (may ask clarifying questions)
  - Grill session (user makes design decisions)
  - Spec written and validated
  - User approves spec
  ↓
User: "go" (or /sdd dark-mode)
  ↓
[AUTOMATIC] Implementation pipeline
  - Plan derived from spec
  - Test-Manager writes tests (RED)
  - Coder waves implement (GREEN)
  - Gates pass (wiring, visual, hidden, activation)
  - Reviewer approves
  - Pipeline reaches "done"
  ↓
User: reviews results, plays with feature
  - If issues found → file issues for next round
  - If satisfied → ship
  - If design change needed → new design session
```

## Proposed Solution

Create a `/sdd <feature>` skill that runs the **automatic implementation phase**:

### What /sdd Does (Automatic)

1. **Read the approved spec** from `specs/SPEC-<FEATURE>.md`
2. **Derive plan** — write to `plans/<feature>-plan.md`
3. **Spawn Test-Manager** — writes tests + `.pipeline/test_map.json`
4. **Verify RED** — all tests fail
5. **Run /trio** — coder waves, gates, review
6. **Report completion** — what was built, what tests pass, review verdict

### What /sdd Does NOT Do (Interactive)

These happen BEFORE /sdd is invoked:
- Requirements gathering (BA agent or user writes directly)
- Design decisions (grill session)
- Spec writing and validation
- User approval

### Invocation

```
# After design session is complete and spec is approved:
/sdd dark-mode

# Or with explicit spec path:
/sdd specs/SPEC-DARKMODE.md
```

### What the User Sees

```
/sdd dark-mode

Reading spec: specs/SPEC-DARKMODE.md (status: approved)
Deriving plan...
  Wave 1: theme toggle, CSS variables (independent)
  Wave 2: component updates (depends on wave 1)

Spawning Test-Manager...
  Writing 8 visible tests, 4 hidden tests
  Verifying RED... all 12 tests fail ✓

Running /trio...
  Wave 1: dispatching 2 coders (worktree-isolated)
    coder-1: src/theme.ts ✓
    coder-2: src/components/Toggle.tsx ✓
  GREEN gate: 8/8 visible tests pass ✓
  Wiring gate: no orphaned modules ✓
  Hidden gate: 4/4 hidden tests pass ✓

  Wave 2: dispatching 1 coder
    coder-3: src/components/Card.tsx, src/components/Modal.tsx ✓
  GREEN gate: 12/12 tests pass ✓

  Spawning reviewer-lite...
    Verdict: APPROVE (0 blocking, 0 major, 2 minor)

Pipeline complete: dark-mode
  Files modified: 5
  Tests: 12/12 passing
  Review: APPROVE (2 minor findings)
  Status: done

Next: play with the feature, file issues if needed.
```

### Post-Implementation Loop

After /sdd completes, the user reviews:
1. **Play with feature** — manual testing, visual inspection
2. **File issues** — if bugs found or changes needed
3. **Run /sdd again** — if issues require implementation changes
4. **New design session** — if fundamental design change needed (back to /grill)

```
User: "the toggle doesn't animate smoothly"
  → File issue: ENH-0013 "add transition animation to dark mode toggle"
  → /sdd picks up the issue, runs implementation cycle
```

## Key Design Decisions

1. **Spec must be approved before /sdd runs.** Status must be `approved`. If `draft`, /sdd tells user to run /grill first.

2. **Spec path convention:** `specs/SPEC-<UPPER-TITLE>.md`. /sdd finds it by feature name.

3. **test_map format:** `.pipeline/test_map.json` — Test-Manager writes, /trio reads.

4. **Complexity determines reviewer tier:** 4-7 → reviewer-lite, 8+ → reviewer (full).

5. **No human intervention during implementation.** The whole point is automation. If something fails, the pipeline retries per existing rules (GREEN 3x, visual 2x, hidden 1x+promote).

6. **Issues are the feedback mechanism.** User files issues for next round, not mid-pipeline interruptions.

## Alternatives Considered

1. **Manual step-by-step invocation** — rejected because too many steps, user must know the sequence
2. **Fully autonomous (no design phase)** — rejected because design decisions need human input
3. **Background execution** — possible but user wants to see progress in terminal

## Research Context

- /trio skill already handles Sprint-Manager mode (coder dispatch, gates, review)
- /grill skill handles design interview (interactive)
- /ba-validate handles spec validation
- Missing: the glue that chains design → automatic implementation
- Industry: Harper Reed's workflow is "brainstorm → plan → execute" — same pattern

## Impact

- Who benefits: users (single command after design), agents (clear automation boundary)
- Scope: every feature implemented via SDD
- Effort: ~4h
- Dependencies: ENH-0003 through ENH-0008 (all resolved), /trio skill (exists)
