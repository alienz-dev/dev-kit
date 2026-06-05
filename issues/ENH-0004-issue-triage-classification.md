---
id: ENH-0004
title: "Issue triage classification — auto-route to correct workflow"
status: resolved
priority: high
component: issue-cli
requested_by: ding
date: 2026-06-05
labels: [enhancement, sdd, issue-cli, p0]
---

## Problem Statement

When an issue is created, there's no automated way to determine which SDD workflow it should follow. Currently:
- Bug fixes need no spec (SDD rule 2) — go straight to implementation
- Features touching >1 file need a spec (SDD rule 1) — full SDD pipeline
- Design changes need spec updates — spec-align + re-implement

Without triage, issues sit in `open` status until a human decides the workflow. This delays routing and can lead to wrong workflows (e.g., writing a spec for a simple bug fix, or skipping spec for a complex feature).

## Proposed Solution

Add a `triage` enhancement to issue-cli that:

1. **Auto-classifies** issue type based on title, description, and labels:
   - `bug` → no spec needed, direct to implementation
   - `feature` → BA → spec → plan → TRIO
   - `design-change` → spec-align → validate → re-plan → TRIO
   - `task` → no spec needed, direct to implementation
   - `chore` → no spec needed, no tests needed

2. **Recommends workflow** with specific steps:
   ```
   issue-cli triage ISS-0042
   # Type: design-change
   # Linked spec: SPEC-AUTH-001
   # Recommended flow: spec-align → validate → re-plan → TRIO
   # Affected tests: tests/auth/login.test.ts, tests/auth/session.test.ts
   ```

3. **Links to existing specs** when issue mentions feature areas that have specs

4. **Estimates complexity** (1-10) based on:
   - Number of files mentioned
   - Whether it touches auth/security/crypto
   - Whether it has linked specs
   - Whether it's a cross-cutting concern

## Alternatives Considered

1. **Manual triage only** — rejected because it's slow and inconsistent
2. **LLM-based triage agent** — rejected because classification is deterministic enough for a script + simple LLM call
3. **Labels-only routing** — rejected because labels don't capture workflow state (e.g., "feature" label doesn't say whether spec exists)

## Research Context (3 rounds completed)

### Round 1: Existing Infrastructure

**Current `triage` command** (agent.ts:106-141) is a time-based scanner only:
- Overdue (deadline past), stale (30+ days), ready-to-verify (resolved 7+ days), blocked
- Zero classification logic — does not set type, severity, or route to workflow
- Uses ad-hoc `--json` flag instead of standard `--format` system

**Available classification fields** (types.ts): type, state, severity, scope, assignee, tags, linked_specs, linked_tests, linked_files, deps, parent, milestone, deadline

**State machine** (VALID_TRANSITIONS): open → in_progress → review → resolved → verified → closed. No direct skip to resolved.

**SDD routing rules** (SDD.md):
- Rule 1: Feature touching >1 file → needs spec (BA → spec → plan → TRIO)
- Rule 2: Bug fix → no spec needed, direct to implementation
- Rule 3: Feature touching 1 file → issue is sufficient

**Gaps identified:**
- No type auto-detection (defaults to 'task')
- No severity auto-detection (defaults to 'P2')
- No "needs-spec" determination
- No routing to plan system
- No classification result storage (triage doesn't write back)
- Template selection at creation is disconnected from triage

### Round 2: Industry Patterns

- Jira/Linear auto-classify based on title keywords + description patterns
- Decision tree: type → complexity → workflow routing
- Best practice: triage writes a structured comment recording the decision
- Complexity estimation: file count, cross-cutting concerns, security/auth/crypto touch

### Round 3: CLI Implementation Design

**Existing patterns:**
- Commands registered via flat switch/case on argv[0]
- Helper functions: `flag(name)`, `hasFlag(name)`, `positional(index)`
- Output format system in formats.ts: markdown, compact, plain, ids, json
- `editIssue(ref, updates)` writes back to frontmatter
- `commentIssue(ref, text, type)` records typed comments
- `transitionIssue(ref, state)` enforces state machine

**Implementation plan:**
- Rewrite `triage()` in agent.ts to accept opts: { project, state, format, recommend, start }
- Add classification logic: keyword-based type detection, severity heuristics, SDD routing
- Add `--recommend` mode: pick highest-priority actionable issue
- Add `--start` mode: auto-transition recommended issue to in_progress
- Use formatIssues() from formats.ts for standard output

## Impact

- Who benefits: planners (faster routing), agents (clear workflow path), users (faster resolution)
- Scope: every issue opened
- Effort: ~3h
- Dependencies: None (enhances existing issue-cli)
