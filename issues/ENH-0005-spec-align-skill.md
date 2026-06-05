---
id: ENH-0005
title: "Spec-Align Skill — spec ↔ code reconciliation"
status: resolved
priority: medium
component: skill
requested_by: ding
date: 2026-06-05
labels: [enhancement, sdd, skill, p1]
---

## Problem Statement

When code diverges from spec (SDD rule 5: "update one or the other"), there's no automated way to:
1. Compare spec vs current code behavior
2. Identify what changed and what needs updating
3. Produce a spec patch (not a full rewrite)
4. Flag test files that need updating

Currently this is a manual process: the planner reads both spec and code, identifies deltas, and updates one or both. This is slow, error-prone, and doesn't scale.

## Proposed Solution

Create a Claude Code skill `spec-align` that:

1. **Diffs spec vs code**: Reads the spec's acceptance criteria, then reads the implementation, and identifies:
   - Criteria that are satisfied by current code
   - Criteria that are violated by current code
   - Code behaviors not covered by any criterion (undocumented behavior)
   - Spec criteria with no corresponding code (unimplemented behavior)

2. **Produces a spec patch**: For each divergence, suggests either:
   - Update spec to match code (if code is correct)
   - Update code to match spec (if spec is correct)
   - Flag for human decision (if ambiguous)

3. **Identifies affected tests**: Cross-references divergences with test files using `@spec` annotations

4. **Generates change specification**: If spec needs updating, produces the Change Specification section (Current Behavior, Target Behavior, Invariants, Scope Boundary)

Invocation: `/spec-align <spec-file> [issue-description]`

Output:
- Divergence report (PASS/FAIL per criterion)
- Recommended action per divergence
- Affected test files
- Draft Change Specification (if spec update is recommended)

## Alternatives Considered

1. **Extend spec-trace.sh** — rejected because spec-trace only checks test annotations, not code behavior
2. **Manual process** — rejected because it's the current state and it's too slow
3. **Full BA agent** — this is a subset of the BA agent (ENH-0006); skill is built first because it's reusable

## Research Context (3 rounds completed)

### Round 1: Existing Infrastructure

**Critical finding: Zero @spec annotations exist in the codebase.** spec-trace.sh has been built but never used. No test file links to any spec section.

**Four gaps identified:**
- No spec-to-code comparison (code can ignore spec, no tool catches it)
- No code-to-spec comparison (undocumented behavior accumulates silently)
- No invariant enforcement (invariants are aspirational text, not enforced)
- No divergence resolution workflow (SDD rule 5 has no mechanism)

**Change Specification pattern:** Every brownfield spec has Current Behavior, Target Behavior (Delta), Invariants (Must NOT Change), Scope Boundary. Invariants are the regression surface.

### Round 2: Industry Patterns

- Contract testing (Specmatic, Pact) validates code matches API spec — same pattern for behavioral specs
- Best practice: three recommendation categories (update-spec / update-code / flag-for-human)
- Impact analysis: when spec changes, identify affected tests and code files
- Delta specs vs full rewrites: incremental Change Specification is preferred

### Round 3: Implementation Design

**Three-phase skill (mirrors ba-validate):**
- Phase 1 (Bash): Extract EARS criteria, run validate-spec.sh, run spec-trace.sh
- Phase 2 (LLM): Read code, compare each criterion against implementation, classify as ALIGNED/DIVERGENT/UNIMPLEMENTED/OVER-IMPLEMENTED
- Phase 3 (LLM): Produce reconciliation report with paste-ready Change Specification

**Key design decisions:**
- EARS criteria are the unit of comparison (each `THE system SHALL` line is atomic)
- Skill is advisory only (report + recommendations, no auto-fix)
- Issue description narrows scope when provided
- Affected test files from both test-files frontmatter and @spec annotations

## Impact

- Who benefits: planners (faster reconciliation), coders (clear targets when fixing divergence)
- Scope: every spec that has an implementation
- Effort: ~4h
- Dependencies: None (standalone skill, but complements ENH-0003 ba-validate)
