# Tiered Review System

Sprint-manager selects review tier based on complexity and auto-promotion signals.

## Tier Classification

| Tier | Agent | Complexity | Timeout | Sections | Blocking |
|------|-------|:----------:|:-------:|:--------:|:--------:|
| 1 | Planner inline | ≤3 | N/A | Sanity check | No |
| 2 | reviewer-lite | 4-7 | 540s | 3 | No |
| 3 | reviewer | 8+ | 900s | 11 | No |

**All reviews are advisory — timeout is non-blocking, never halts pipeline.**

## Auto-Promotion to Tier 3

Regardless of complexity score, auto-promote when changeset touches:
- `/auth/` — authentication
- `/security/` — security controls
- `/crypto/` — cryptographic operations
- `/api/` — API surface changes
- `/schema/` — database schema
- `/migration` — data migrations

## Reviewer-Lite Pipeline (Tier 2)

```
1. Pre-check: review-precheck.sh --diff HEAD
2. LLM Review (3 sections):
   - Bug Hunter: logic errors, edge cases, null handling
   - Security: injection, auth bypass, data exposure
   - Design & Quality: naming, structure, maintainability
3. Report: verdict + findings
```

## Full Reviewer Pipeline (Tier 3)

```
1. Pre-check: review-precheck.sh --diff HEAD
2. LLM Review (11 sections):
   - Bug Hunter, Security, Design & Quality (same as Tier 2)
   - Performance, Concurrency, Error Handling
   - API Contract, Test Coverage, Documentation
   - Accessibility, Backwards Compatibility
3. Signal filtering (suppress known FPs from review memory)
4. Feedback capture (update review memory)
5. Report: verdict + findings + recommendations
```

## Pre-Check Script

`review-precheck.sh` runs static analysis before LLM review:

| Language | Tool | Check |
|----------|------|-------|
| TypeScript | tsc | Type errors |
| Python | py_compile | Syntax errors |
| Java | mvn compile | Compilation |
| Shell | shellcheck | Shell script issues |

**Output format:** `FILE:LINE:SEVERITY:TOOL:MESSAGE`

Pre-check failures are included in the review report but don't block the LLM review step.

## Verdict Rules

| Signals | Verdict |
|---------|---------|
| Any 🔴 | REQUEST_CHANGES |
| 🟠 + 🟡 (no 🔴) | APPROVE_WITH_COMMENTS |
| 🟡 only | APPROVE |
| No findings | APPROVE |

## Review Memory

Persistent learning at `~/vault/state/review-memory.md`:

```markdown
## False Positives (suppress these)
- "unused import" in test files (test utilities imported for side effects)
- "magic number" for HTTP status codes (200, 404, 500 are universally understood)

## Team Preferences
- Prefer explicit returns over implicit
- Allow single-letter variables in lambda/arrow functions

## Project-Specific Patterns
- watchdog: vitest pool must be 'threads' (not a bug)
- neo-ui: CSS modules use camelCase (not kebab-case)
```

Reviewer loads review memory and suppresses known false positives before generating findings.

## Sprint-Manager Dispatch Logic

Sprint-manager reads `## Review Tier: N` from its briefing (set by supervisor based on complexity score). If not specified, defaults to Tier 2.

```bash
# Tier 2
kiro-ctl spawn reviewer-lite "Review wave 1 changes" --subscribe --headless

# Tier 3
kiro-ctl spawn reviewer "Full review for PROJ-042" --subscribe --headless
```

## Timeout Behavior

- Tier 2 timeout (540s): sprint-manager logs "review timed out" and proceeds
- Tier 3 timeout (900s): sprint-manager logs "review timed out" and proceeds
- Review findings (if any arrived before timeout) are still captured
- Pipeline never blocks on review — it's advisory quality signal
