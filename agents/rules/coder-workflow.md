---
name: coder-workflow
description: Coder agent workflow, coding conventions, testing, debugging, and git standards.
---

> **Briefing** = a markdown file containing: your task description, test file paths to make pass, owned files you may modify, and the result file path to write when done.

# Coder Workflow

## Six-Phase Loop

1. **ORIENT** — Read AGENTS.md (if present). Read briefing context file. Understand project commands and boundaries.
2. **CONTEXT** — Read Owned Files + Read-Only Files from briefing. Knowledge lookup if domain terms unclear (max 2 lookups: `grep -r "<term>" ~/vault/knowledge/ -l | head -5`).
3. **IMPLEMENT** — One logical change at a time per briefing scope.
4. **VERIFY** — Run verification command + linter/type-checker. Check exit codes.
5. **REFLECT** — Does change solve the stated problem? Edge cases handled? Could it break something?
6. **RESULT** — Write result file: Summary, Changes, Verification Output, Deviations, Files Modified.

## TRIO Glossary (for cold-start agents)
- **RED**: All tests fail (expected — you haven't implemented yet)
- **GREEN**: All tests pass (your goal)
- **Gate**: Automated check that must pass before advancing (e.g., tests pass, typecheck clean)
- **Briefing**: Task file with test paths + constraints + result path (see definition above)
- **Result file**: Markdown you write when done — summary, changes, verification output

## Deviation Protocol

When diverging from plan, log in result file:

| Plan said | I did | Reason |
|-----------|-------|--------|

Deviations are expected. Just document them.

## Quality Gates

- Linter/type-check per project: Java `mvn compile -pl <module>` | Node `npm run lint && npm test` | Python `mypy` | Go `go vet`
- One change → verify → next change. Never stack unverified.
- Isolate errors: module-level build, not full project.

## Testing Rules

**TDD when briefing includes test files in Owned Files or task is complex/risky:**
1. RED — Write one failing test. One behavior per test. Clear name.
2. Verify RED — Run it, confirm it fails because feature is missing (not typo/setup).
3. GREEN — Minimal code to pass. Nothing more.
4. Verify GREEN — New test passes AND existing tests pass.
5. REFACTOR — Only after green. Keep tests green.

**Bug fixes:** Write failing test reproducing bug → verify fails → fix → verify passes → verify no regressions.

**Test quality:**
- Tests verify behavior, not existence. `expect(result).toBeDefined()` alone is banned.
- Every assertion must be falsifiable — if implementation is wrong, test must fail.
- Dangerous input ≠ bad input. Test `days=0` (deletes everything), empty string matching all — valid but harmful.

## Debugging Rules

**No fixes without root cause investigation first.**

1. **Root Cause** — Read errors completely. Reproduce consistently. Check `git diff`. In multi-component systems, add diagnostic at each boundary BEFORE proposing fixes. Trace data flow backward from symptom to source.
2. **Hypothesis** — Form specific hypothesis ("X causes Y because Z"). Confirm with temporary diagnostic BEFORE implementing fix. If diagnostic doesn't confirm → new hypothesis, don't implement.
3. **Fix** — Single fix addressing root cause. One variable at a time.
4. **If 3+ fixes fail** — STOP. It's architectural. Note in result file, don't keep trying.

## Coding Style

**Naming:** Full words over abbreviations. `processPayment()` not `procPay()`. Booleans: `isAuthenticated`, `hasExpired`.

**Types:** Strict mode always. No `any`/`object` — use `unknown` + guards. Return types on all public functions. Discriminated unions for state machines.

**Structure:** Flat > deep. Co-locate related code. Limit barrel re-exports. Vertical slice > layer-based.

**Abstraction:** Justify every layer. No metaprogramming for control flow. No dynamic dispatch when static works. Write the dumbest thing that works.

**Errors:** Every public function handles errors explicitly. Error messages include diagnostic context (actual values). No silent swallowing.

**Agent-specific:** Write for grep, not cleverness. Moderate duplication > abstraction agents can't trace.

## Git Conventions

- Commit format: `[branch_name]: <message>` — atomic, one logical change
- Type prefixes: `feat`/`fix`/`chore`/`refactor`/`docs`
- Branch: Jira ticket ID prefix. TaxIntell: `-xcode1-` suffix for Jenkins.
- PR title: `[TICKET-ID]: Short description`
- No debug code in commits (`console.log`, `System.out.println`, TODO/FIXME)

## Context Boundaries

- Only modify Owned Files from briefing.
- No scope creep. No "while I'm here" improvements.
- No broad repo exploration — orient is structured.

## Context Exhaustion

- When context feels constrained (large test output, many file reads): write partial result with `status: PARTIAL`, list remaining work in `## Remaining Tasks`.
- Sprint-manager detects PARTIAL and spawns continuation.
