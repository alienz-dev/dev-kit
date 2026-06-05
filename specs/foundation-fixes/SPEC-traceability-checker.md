---
id: SPEC-004
title: Spec-Test Traceability Checker
status: verified
version: 1
created: 2026-06-04
linked_issues: []
test_files: []
---

## Overview

SDD.md requires `@spec feature.spec.md §2 Behavior` annotations in test files, but no
tooling parses or enforces them. Spec sections can go uncovered with no detection.

**Goal:** Build a simple grep-based tool that checks spec-test coverage and reports
uncovered sections.

## Behavior

### Acceptance Criteria

**AC-1: Parse @spec Annotations (Event-driven)**
WHEN the traceability checker runs THE system SHALL scan all test files for `@spec`
comments and extract (spec-file, section) pairs.

**AC-2: Parse Spec Sections (Event-driven)**
WHEN the traceability checker runs THE system SHALL parse the spec file's markdown
headings as sections (## Behavior, ### AC-1, etc.).

**AC-3: Report Uncovered Sections (Event-driven)**
WHEN analysis completes THE system SHALL print a table showing each spec section and
whether it has a referencing test (covered/uncovered).

**AC-4: Exit Code Reflects Coverage (Unwanted)**
WHILE uncovered sections exist THE system SHALL exit 1 (non-zero).

**AC-5: Support Multiple Spec Files (Ubiquitous)**
WHILE multiple spec files exist in specs/ THE system SHALL check coverage across all of them.

**AC-6: Support glob patterns for test directories (Ubiquitous)**
WHILE the checker is invoked THE system SHALL accept a test directory glob as an argument
(default: tests/).

### Change Specification

**Current Behavior:**
- `@spec` convention documented in SDD.md
- No tooling parses or enforces it
- Spec sections can be uncovered without detection

**Target Behavior:**
- `tools/spec-trace.sh` script that scans test files and spec files
- Outputs a coverage table (section → covered/uncovered)
- Exits 0 if all sections covered, 1 otherwise

**Invariants:**
- Does not modify any files (read-only analysis)
- Works with existing @spec comment format
- Handles missing spec files gracefully

**Scope Boundary:**
- Changes: new file tools/spec-trace.sh
- Does NOT change: SDD.md, test files, spec files

**Non-Goals:**
- Auto-generating tests for uncovered sections
- Parsing complex @spec formats (keep it simple: `@spec <file> §<section>`)
- Integration with CI (future work)

## Error Handling

| Error | Handling |
|-------|----------|
| Spec file not found | Print "spec not found: X" and skip |
| No test files found | Print "no tests found in X" and exit 1 |
| No @spec annotations found | Print "no @spec annotations found" and exit 0 (not an error) |

## Constraints

- Pure bash implementation (grep, sed, awk — no new dependencies)
- Completes in under 10 seconds
- Read-only — never modifies files

## Clarifications

- @spec format: `@spec <spec-file.md> §<section-name>` (section matches markdown heading)
- A section is "covered" if at least one test file contains an @spec annotation referencing it
- The tool should work even if specs/ directory doesn't exist (just report "no specs found")
