# Spec-Driven Development (SDD)

## Why

Agents implement wrong things without a contract. Code without a spec is a guess. Specs are the single source of truth — if code diverges from spec, one must be updated.

## Lifecycle

```
Idea → Spec (draft) → Grill → Spec (approved) → Plan (derived) → Implement (TDD) → Verify → Ship
```

### Workflow-Based Implementation

The "Implement (TDD)" step can be driven by dynamic workflows instead of manual orchestration:

- **sdd-test-gen**: Generates tests from spec, verifies RED gate, checks AC coverage
- **wave-dispatch**: Dispatches coders in parallel worktrees, runs GREEN gate, post-wave gates
- **sdd-review**: Multi-perspective review with adversarial verification
- **sdd-retro**: Automated retro with classification and routing

The `/sdd` skill delegates to these workflows automatically. For a fully automated run:
`ultracode: implement <spec-path>` uses the `sdd-implement` meta-workflow.

See `workflow/dynamic-workflows-guide.md` for the complete guide.

## Rules

1. Every feature touching >1 file MUST have a spec before implementation.
2. Bug fixes use issues only — no spec needed.
3. Specs define WHAT + WHY. Plans define HOW + ORDER.
4. Plans are derived from specs — never the reverse.
5. Spec is the contract. If code diverges from spec, either update spec or fix code.
6. Tests are executable assertions of spec sections.
7. Acceptance criteria MUST use EARS notation (see below).

## EARS Notation (Mandatory for Acceptance Criteria)

Every acceptance criterion uses one of these 5 patterns:

| Pattern | Template | Example |
|---------|----------|---------|
| Ubiquitous | THE system SHALL [behavior] | THE system SHALL display pagination controls |
| Event-driven | WHEN [trigger] THE system SHALL [response] | WHEN user clicks "Next" THE system SHALL load page N+1 |
| State-driven | WHILE [state] THE system SHALL [behavior] | WHILE loading THE system SHALL show skeleton UI |
| Unwanted | IF [error] THEN THE system SHALL [recovery] | IF API returns 500 THEN THE system SHALL show retry button |
| Optional | WHERE [config] THE system SHALL [behavior] | WHERE pagination is enabled THE system SHALL show page count |

**Rule:** Each EARS statement = one test case for test-manager.

### Compound Criteria

Combine patterns when needed:
```
WHILE authenticated WHEN user navigates to /admin THE system SHALL display admin panel
IF session expires WHILE user is editing THEN THE system SHALL save draft locally
```

### Pattern Coverage (Completeness Checklist)

For each feature, verify you have BOTH:
- At least one happy-path criterion (WHEN or Ubiquitous)
- At least one error-path criterion (IF/THEN)

Use this checklist when writing or reviewing acceptance criteria:
- [ ] What events trigger the feature? → WHEN
- [ ] What states constrain behavior? → WHILE
- [ ] What errors can occur? → IF/THEN
- [ ] What optional features affect it? → WHERE
- [ ] What always applies? → THE (ubiquitous)

A pattern category with zero entries should have a note explaining why (not applicable vs. missed).

### Non-Functional Requirements (SHALL/MUST)

Functional requirements use EARS patterns above. Non-functional requirements use RFC 2119 language with measurable thresholds:

| Category | Template | Example |
|----------|----------|---------|
| Performance | `The system SHALL [action] within [N] [unit]` | The system SHALL respond within 200ms (p95) |
| Security | `The system MUST [action]` / `The system SHALL NOT [action]` | The system MUST sanitize all user input |
| Compatibility | `The system SHALL support [target]` | The system SHALL support Node.js 20+ |
| Capacity | `The system SHALL handle [N] [unit]` | The system SHALL handle 1000 concurrent connections |

Rules:
- SHALL = absolute requirement. SHOULD = recommended. MAY = optional.
- Every NFR must have a measurable threshold — no "fast", "efficient", "scalable"
- NFRs go in §5 Constraints, not in §2 Acceptance Criteria

## Change Specification (Brownfield Changes)

For changes to existing behavior, include these sections:

```markdown
## Change Specification

### Current Behavior
<What the system does now — observable, testable>

### Target Behavior (Delta)
<What changes — EARS statements for new behavior>

### Invariants (Must NOT Change)
<Behavior that must remain unchanged — feeds hidden test targets>

### Scope Boundary
<What is explicitly OUT of scope for this change>
```

**Invariants** are critical — they feed the hidden regression tests that the coder never sees.

## Spec Format

```markdown
---
id: SPEC-NNN
title: "Feature Name"
status: draft | approved | implementing | verified | shipped
version: "1.0"
created: YYYY-MM-DD
linked_issues: [PROJECT-NNN]
test-files:
  - tests/unit/feature.test.ts
---

# Feature Name

## §1 Overview
<What this feature does and why it exists>

## §2 Behavior
<Detailed behavior specification>

### Acceptance Criteria (EARS)
- WHEN [trigger] THE system SHALL [response]
- WHILE [state] THE system SHALL [behavior]
- IF [error] THEN THE system SHALL [recovery]

## §3 Change Specification (if brownfield)
### Current Behavior
### Target Behavior (Delta)
### Invariants (Must NOT Change)
### Scope Boundary

## §4 Error Handling
| Input | Expected | Rationale |
|-------|----------|-----------|
| null | 400 error | Explicit validation |
| empty | default behavior | Graceful degradation |

## §5 Constraints
<Performance, security, compatibility requirements>

## §6 Clarifications (from grill session)
<Questions raised during grill and their answers>

## §7 Visual Acceptance Criteria (if UI)
<See Visual Acceptance Criteria section below>

## §8 Debugging & Observability
<Diagnostic commands, error messages, failure modes, logging, debugging AC>
<See Debugging & Observability section below>
```

## Visual Acceptance Criteria (UI Features)

WHEN a plan modifies UI files (.tsx, .jsx, .vue, .svelte, .css, .scss, .html), include:

```markdown
## §7 Visual Acceptance Criteria

### Design Reference
- DESIGN.md: <path to design system file>
- Pages: <list of pages/routes affected>

### Criteria (EARS)
- WHEN page loads THE system SHALL render layout matching DESIGN.md grid spec
- WHILE viewport < 768px THE system SHALL stack sidebar below content
- THE system SHALL use only design tokens (no hardcoded colors/spacing)

### Visual QA Targets
<Passed to sprint-manager for visual gate>
- Page: /dashboard — check: layout, token usage, responsive
- Page: /settings — check: form alignment, spacing
```

**Flow:** Planner criteria → test-manager targets → sprint-manager visual gate

## Debugging & Observability (All Features)

Every spec MUST include §8 with these subsections. This is not optional — features without
debugging acceptance criteria create unmaintainable code.

### Diagnostic Commands
| Command | What it proves | Expected output |
|---------|---------------|-----------------|
| <command> | <what working state looks like> | <expected> |

### Error Messages (EARS)
- IF <failure condition> THEN THE system SHALL display "<specific actionable message>"
- WHEN <error occurs> THE system SHALL log <what to log, structured format>

### Failure Modes
| Failure | Symptom | How to identify | How to fix |
|---------|---------|-----------------|------------|
| <mode> | <what user sees> | <diagnostic step> | <remedy> |

### Logging & Output
- WHAT is logged: <events, decisions, errors>
- FORMAT: <structured JSON / human-readable / both>
- WHERE: <stdout / file / both>

### Debugging Acceptance Criteria (EARS)
- WHEN <operation> fails THE system SHALL log <context needed to diagnose>
- IF <silent failure mode> THEN THE system SHALL <surface the problem>
- THE system SHALL provide a < --dry-run / --verbose / status > command for troubleshooting

**Grill prompt:** "When this fails at 2am, what does the user see? What log output proves it's
working? What are the 3 most likely failure modes and how to identify each?"

## Spec-to-Test Traceability

Tests reference spec sections:
```typescript
// @spec feature.spec.md §2 Behavior
describe('feature behavior', () => {
  it('should do X when Y', () => { ... });
});
```

A spec section without a referencing test is **uncovered** — this is tracked.

## Plan Format (derived from spec)

```markdown
# Plan: Feature Name
Derived from: SPEC-NNN

## Approach
<Technical approach chosen>

## Steps (ordered)
1. [ ] Step 1 — <what to do>
2. [ ] Step 2 — <what to do>

## Test Strategy
- Unit: <what to test at unit level>
- Integration: <what to test at integration level>

## Risks
- <Risk 1>: mitigation
```

## Status Values

| Status | Meaning | Who advances |
|--------|---------|--------------|
| draft | Written, not reviewed | Author |
| approved | Ready for planning (post-grill) | Reviewer/supervisor |
| implementing | Plan derived, coders active | Supervisor |
| verified | All tests pass, spec covered | Test gate |
| shipped | Deployed | CI/CD |

## When No Spec Exists

- Bug fix → file an issue, implement, done
- Feature (1 file only) → issue is sufficient
- Feature (>1 file) → write spec first, do not implement without one

---

## Implementation Protocol (absorbed from TRIO)

The implementation phase follows the TRIO protocol: **T**est → **R**ed → **I**mplement → **O**bserve.

### The Iron Law

```
The coder NEVER sees the spec. They only see failing tests.
```

This prevents "implement to spec" shortcuts where the coder reads the spec and writes code that satisfies the words but not the intent. When they only have tests, they must make the tests pass — which IS the intent.

### Role Separation

| Role | Responsibility | Spawns |
|------|---------------|--------|
| Supervisor/Planner | Writes spec, spawns test-manager + sprint-manager | test-manager, sprint-manager |
| Test-Manager | Writes tests, verifies RED | tester (for help) |
| Sprint-Manager | Dispatches coders, runs all gates, spawns reviewer | coder ×N, reviewer-lite, reviewer |
| Coder | Makes tests pass | — |

**Critical:** Test-manager does NOT spawn coders. Sprint-manager does NOT write tests.

### Pipeline Stages

Stages and transitions are defined in [`transitions.json`](../pipeline/transitions.json) (single source of truth).

Top-level stages: `plan → test → sprint → review → retro → done | failed`

### Sprint Sub-Gates

The sprint stage contains sub-gates defined in `transitions.json` `gates.sprint`:

| Gate | What It Checks |
|------|---------------|
| green | All visible tests pass |
| wiring | Entry-reachability check passes (orphaned modules, dead imports) |
| visual | UI visual check passes (UI projects only) |
| hidden | Hidden regression tests pass (behavioral invariants, contract violations) |
| alignment | Spec-to-code alignment check passes |
| activation | Feature reachable from entry point |

**Gate sequence per wave:**
```
[coder dispatch] → GREEN → wiring → visual → wave-smoke.sh
```

**After all waves complete:**
```
hidden → alignment → activation → review
```

### Visual Gate (UI projects only)

After GREEN, if the changeset includes UI files (.tsx, .jsx, .vue, .svelte, .css, .scss, .html):

The composed gate runs three layers:
1. **Layer 1: Static Analysis** — `ui-visual-check.sh` (always runs, <5s, no browser)
2. **Layer 2: Visual Regression** — `visual-regression.sh` (Playwright screenshots, needs dev server)
3. **Layer 3: Accessibility** — `accessibility-check.sh` (axe-core WCAG checks, needs dev server)

**Pass:** All layers pass. **Fail:** Re-dispatch coder (max 2 visual retries). **No dev server:** Layer 1 only.

### Backward Transitions (Rework)

| From | To | When |
|------|----|------|
| review → plan | Spec needs revision |
| review → test | New tests needed (reviewer found gap) |
| sprint → test | Alignment patch needed |
| sprint → sprint | Patch wave for targeted fix |

### Patch Waves

A patch wave is a targeted fix for alignment issues. Unlike a full re-dispatch, it is scoped to specific files and ACs.

**When to use:** Alignment gate reports DIVERGENT/UNIMPLEMENTED for 1-3 files, code structure is sound, one behavior is wrong.

**When NOT to use:** Fundamental approach wrong, multiple interdependent files, spec ambiguity requires re-interpretation.

**Patch briefing** relaxes the information barrier for the specific divergent AC only:
- Includes the specific AC text (not the full spec)
- Includes file:line of the divergence
- Includes expected behavior (quoted from spec)

**Limits:** Max 2 patch waves per alignment issue → full re-dispatch → report failure to user.

### Failure Handling

| Gate | Max Retries | On Exhaust |
|------|-------------|------------|
| GREEN | 3 | Pipeline status → failed |
| Visual | 2 | Pipeline status → failed |
| Hidden | 1 | Promote hidden test to visible, re-dispatch coder |

### Hidden Tests

Hidden tests are regression tests the coder never sees. They verify:
- Edge cases the spec mentions but tests don't explicitly cover
- Integration behavior across module boundaries
- Invariants that should never break

Hidden tests run at the hidden gate (after all waves complete). If they fail:
1. Sprint-manager promotes the failing hidden test to visible
2. Re-dispatches coder with the now-visible test

### Gate Enforcement

Production observation: agents skip gates unless explicitly mandated in their prompts.

**Rules:**
1. Gates must be in the agent's prompt (not just a referenced doc)
2. Phrased as "DO NOT SKIP" with explicit exit-code handling
3. Positioned at the exact workflow step where they run
4. Enforced at the appropriate tier (code-enforced via gate.sh/lefthook, or prompt-enforced via role definitions)

### Anti-Patterns

- ❌ Coder reads the spec → implements to words, not intent
- ❌ Tests written after code → tests verify implementation, not behavior
- ❌ Skipping RED verification → tests might already pass (testing nothing)
- ❌ Single agent does everything → no external verification
- ❌ Planner spawns coder directly → bypasses sprint-manager gates
- ❌ Test-manager spawns coder → role confusion, no gate enforcement
