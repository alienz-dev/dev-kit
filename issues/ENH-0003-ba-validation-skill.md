---
id: ENH-0003
title: "BA Validation Skill — spec completeness checker"
status: resolved
priority: high
component: skill
requested_by: ding
date: 2026-06-05
labels: [enhancement, sdd, skill, p0]
---

## Problem Statement

There is no automated gate between spec `draft` and `approved` status. A spec can advance to the planning stage with missing acceptance criteria, undefined error handling, ambiguous language, or absent scope boundaries. The grill protocol catches some of this interactively, but there's no reusable, stateless check that any agent can invoke.

Currently `validate-spec.sh` only checks structural presence (frontmatter fields, section headings). It does NOT validate:
- Whether acceptance criteria follow EARS patterns
- Whether error handling paths are defined (IF/THEN patterns)
- Whether scope boundaries are explicit
- Whether banned words ("should", "appropriately", "properly", "correctly") are present
- Whether every behavior section has at least one acceptance criterion

## Proposed Solution

Create a Claude Code skill `ba-validate` that performs deep semantic validation on spec files:

1. **EARS compliance**: Every acceptance criterion must match one of the 5 EARS patterns (Ubiquitous, Event-driven, State-driven, Unwanted, Optional)
2. **Error handling coverage**: Every behavior that can fail must have an IF/THEN criterion
3. **Scope boundary check**: Change Specification must have explicit "Must NOT Change" invariants
4. **Language quality**: Flag banned words (should, appropriately, properly, correctly) and suggest EARS-compliant replacements
5. **Coverage check**: Every S2 Behavior subsection must have at least one acceptance criterion
6. **Testability check**: Each criterion must be independently testable (no compound criteria with AND/OR chains)

Invocation: `/ba-validate <spec-file>`

Output: Structured report with PASS/FAIL per check, specific line references, and suggested fixes.

## Alternatives Considered

1. **Extend validate-spec.sh** — rejected because semantic validation (checking if language is ambiguous) requires LLM reasoning, not just regex
2. **Add to grill protocol** — rejected because grill is interactive and human-in-the-loop; validation should be automatable
3. **Make it a full BA agent** — rejected for this issue; agent is P1 (ENH-0006), skill is P0 because it's stateless and reusable

## Research Context (3 rounds completed)

### Round 1: Existing Infrastructure Analysis

**validate-spec.sh** only checks:
- Frontmatter exists with id, title, status fields
- `## 1 Overview` and `## 2 Behavior` headings present
- Warning if no `THE system SHALL` string (but doesn't validate EARS patterns)
- Warning if no test-files or linked_issues fields

**Gaps found by analyzing all 9 existing specs:**
- Rules-cleanup specs (SPEC-C1, C2, C3) missing Error Handling, Constraints, Clarifications sections
- Inconsistent field names: `test-files:` (template) vs `test_files:` (foundation-fixes specs)
- Inconsistent section numbering: `## 1 Overview` (template) vs `## Overview` (foundation-fixes)
- Banned words ("should") appear in Clarifications sections (acceptable in Q&A format)
- planner-core.md has banned words list + quality gate checklist but only in the prompt, not enforced

### Round 2: Industry Patterns

- EARS has 5 formal patterns with regex signatures
- ISO 29148 defines requirements quality attributes (unambiguous, verifiable, traceable)
- Contract testing (Specmatic, Pact) validates code matches spec — same pattern needed for internal specs
- Linting for natural language specs: detect vague language, passive voice, unquantified terms

### Round 3: Implementation Design

**Skill structure:** Single `SKILL.md` at `templates/common/claude-code/skills/ba-validate/`

**Three phases:**
1. Structural (bash) — runs validate-spec.sh, checks frontmatter, sections, banned words
2. Coverage (bash) — runs spec-trace.sh, checks @spec annotation coverage
3. Semantic (LLM) — EARS compliance, ambiguity detection, testability, completeness, consistency

**11 automated checks (bash):**
- Frontmatter completeness (id, title, status, version, test-files, linked_issues)
- Status value validation (draft/approved/implementing/verified/shipped)
- Required sections (1 Overview, 2 Behavior, 4 Error Handling, 5 Constraints)
- Section numbering consistency
- EARS pattern syntax (5 regex patterns + compounds)
- Banned words in acceptance criteria (should, appropriately, properly, correctly)
- Placeholder detection (TBD, TODO, "add appropriate")
- Non-Goals presence (2-5 bullets per planner-core.md)
- Error handling table format
- test-files field (handle both hyphen and underscore variants)
- Field name consistency

**7 LLM checks (semantic):**
- EARS criterion testability (no compound AND/OR chains)
- Error path coverage (each failure mode has IF/THEN)
- Scope boundary adequacy (invariants specific enough for hidden tests)
- Non-Goals quality (2-5, specific)
- Coverage (each behavior subsection has ≥1 criterion)
- Name consistency across spec
- Clarifications adequacy

## Impact

- Who benefits: planners (faster spec review), coders (clearer acceptance criteria), reviewers (fewer ambiguities to flag)
- Scope: affects every spec written for every feature
- Effort: ~2h (skill only), ~4h (skill + validate-spec.sh enhancements)
- Dependencies: None (standalone skill)
- Blocks: ENH-0006 (BA agent uses this skill), ENH-0007 (spec change protocol uses this skill)
