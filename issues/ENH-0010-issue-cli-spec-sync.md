---
id: ENH-0010
title: "Issue-CLI spec-sync — validate specs when resolving issues"
status: resolved
priority: low
component: issue-cli
requested_by: ding
date: 2026-06-05
labels: [enhancement, sdd, issue-cli, p2]
---

## Problem Statement

issue-cli has `linked_specs` field in issue frontmatter, but there's no automation around it. When resolving an issue that has linked specs, there's no check that:
- The linked specs are still valid (validate-spec.sh)
- The linked specs have test coverage (spec-trace.sh)
- The implementation matches the spec (spec-align)

This means issues can be resolved even when their linked specs are stale, untested, or diverged from implementation.

## Proposed Solution

Add `spec-sync` command to issue-cli:

### 1. `issue-cli spec-sync <project#id>`
When resolving an issue with linked specs, automatically:
- Run validate-spec.sh on each linked spec
- Run spec-trace.sh to check test coverage
- Report any uncovered sections
- Exit 1 if validation fails (blocks resolution)

### 2. `issue-cli resolve <project#id> --spec-sync`
Same as above but integrated into the resolve command. Resolution is blocked if spec validation fails.

### 3. `issue-cli spec-sync --fix <project#id>`
Auto-fix what can be fixed:
- Generate test stubs for uncovered sections (spec-to-test.sh)
- Update spec frontmatter (test-files field)
- Report what needs manual attention

## Alternatives Considered

1. **Manual spec validation** — rejected because it's the current state and it's forgotten often
2. **CI integration** — good idea but separate issue; this is the CLI-level check
3. **Full spec-align skill** — ENH-0005 handles the deep comparison; this is the lighter validation-only check

## Research Context

- validate-spec.sh exists but isn't wired into issue lifecycle
- spec-trace.sh exists but isn't wired into issue lifecycle
- issue-cli already has `linked_specs` field — just needs automation

## Impact

- Who benefits: planners (spec quality), reviewers (less to check), users (fewer stale specs)
- Scope: every issue with linked_specs
- Effort: ~3h
- Dependencies: validate-spec.sh and spec-trace.sh already exist
