## Retrospective: 2026-06-04 — Phase 1 Foundation Fixes

### Metrics
- Duration: ~2h | Turns: ~15 | Specs: 5 | Implementations: 5 | Errors caught: 1
- Files changed: 39 | Insertions: 643 | Deletions: 5790
- Subagents spawned: 14 (2 researchers, 5 implementers, 1 reviewer, 5 spec writers, 1 verifier)

### What Worked
1. **Parallel research** — 2 researchers (internal analysis + industry survey) ran concurrently, produced complementary findings
2. **EARS specs** — 26 acceptance criteria across 5 specs, each maps to a verification command
3. **Self-contained agent prompts** — each implementer knew exactly what to do, no back-and-forth
4. **Reviewer caught real bug** — SPEC-003 AC-4 (missing retreat signals) was genuinely broken
5. **Spec → Plan → Implement → Verify flow** — the overall structure was correct

### What Went Wrong

#### 1. No Waves — All 5 Agents at Once
**What happened:** Dispatched all 5 implementation agents simultaneously as one giant wave.
**What should have happened:** 3 waves with retros between:
- Wave 1: SPEC-001 (state machine) + SPEC-005 (daemon cleanup) — low-risk docs/config
- Retro: Did state consolidation cause conflicts?
- Wave 2: SPEC-003 (retreat) — depends on SPEC-001's transitions.json
- Retro: Does retreat interact correctly with advance?
- Wave 3: SPEC-002 (gate scripts) + SPEC-004 (traceability) — independent tools
- Retro: Are gate scripts useful on the real repo?
**Why it matters:** SPEC-003 depended on SPEC-001 but ran in parallel. The reviewer had to catch the missing signals that proper wave ordering would have prevented.

#### 2. No Test-First (RED Phase)
**What happened:** Implementation agents read specs + plans directly and implemented.
**What should have happened:** Test-manager writes verification scripts first (e.g., `test-retreat.sh` that runs `gate.sh retreat review_to_test` and checks output). Implementers work from test scripts, not specs.
**Why it matters:** TRIO's iron law — "coder NEVER sees the spec" — exists to prevent rubber-stamping. We violated it completely.

#### 3. No Grill Session
**What happened:** Specs written by planner, immediately marked "approved", no adversarial review.
**What should have happened:** Grill session asking:
- Should retreat work from sprint stage? From done?
- Should spec-trace.sh support `@spec` with no section?
- Should gate scripts have `--verbose` flag?
- What happens on circular retreat (review→test→sprint→review)?
**Why it matters:** Grill catches design gaps before implementation, not after.

#### 4. Never Used gate.sh
**What happened:** Built gate.sh improvements but never used gate.sh to track our own pipeline.
**What should have happened:** `gate.sh init foundation-fixes` at start, advance through stages as we progressed.
**Why it matters:** Dogfooding catches UX issues. We'd have found the macOS flock bug during planning, not during verification.

#### 5. Reviewer Not Truly Adversarial
**What happened:** Reviewer ran verification commands and reported pass/fail.
**What should have happened:** Reviewer tries to BREAK things:
- What happens on circular retreat?
- What happens on double retreat?
- What if transitions.json is malformed?
- What if spec-trace.sh runs on empty directory?
**Why it matters:** Verification that only checks happy paths misses edge cases.

#### 6. Information Barrier Violated
**What happened:** All 5 implementation agents received full spec + plan context.
**What should have happened:** Implementers receive only:
- Failing test scripts (what to make pass)
- File ownership list (what they can modify)
- Verification commands (how to confirm success)
- NO spec text, NO acceptance criteria rationale
**Why it matters:** When an implementer reads "AC-4 requires review_to_test signal", they just add it. When they read "make this test pass: `gate.sh retreat review_to_test`", they have to understand what the command does.

### Corrections (Process Improvements)

1. **Always use waves** — group specs by dependency, retro between waves
2. **Always write test scripts first** — even for shell/docs work, write verification scripts before implementation
3. **Always grill specs** — at least 3 questions per spec challenging design decisions
4. **Always use gate.sh** — dogfood the pipeline on every multi-spec task
5. **Reviewer must be adversarial** — prompt with "try to break this, find edge cases, check error paths"
6. **Enforce information barrier** — implementers get test scripts + file lists, not specs

### Dead Ends
- Tried to run `flock` on macOS — doesn't exist. Fixed with PID-based fallback.
- Tried to read `workflow/retro/` as a file — it's a directory. Used `ls` instead.

### Forward Plan
- Wave execution protocol needs to be written into planner-core.md
- Agent briefing templates need information barrier enforcement
- Grill checklist needs to be created for tool/kit specs
- Reviewer prompt template needs adversarial instructions

### Classifications
| Finding | Type | Action |
|---------|------|--------|
| No waves used | Heuristic | Update planner-core.md with wave protocol |
| No test-first | Heuristic | Update TRIO.md with tool/script test guidance |
| No grill | Heuristic | Create grill checklist template |
| macOS flock bug | Issue | Fixed in gate.sh (PID-based fallback) |
| Info barrier violated | Heuristic | Create briefing template with barrier enforcement |
| gate.sh not dogfooded | Heuristic | Add "dogfood" step to planner protocol |
