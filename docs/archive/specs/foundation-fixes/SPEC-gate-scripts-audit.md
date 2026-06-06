---
id: SPEC-002
title: Gate Scripts Audit — Implement or Remove
status: verified
version: 1
created: 2026-06-04
linked_issues: []
test_files: []
---

## Overview

Five gate scripts referenced in TRIO.md, ARCHITECTURE.md, and ROLES.md do not exist.
Agents following the documented pipeline hit "file not found" and cannot distinguish
"gate I need to run" from "gate that doesn't exist."

**Goal:** Either implement each gate script or remove it from documentation and simplify
the gate sequence to what actually works.

## Behavior

### Acceptance Criteria

**AC-1: Every Referenced Gate Script Exists or Is Removed (Ubiquitous)**
WHILE documentation references a gate script THE system SHALL either provide the script
at the documented path OR remove the reference from all documentation.

**AC-2: Gate Scripts Are Executable (Ubiquitous)**
WHILE a gate script exists THE system SHALL be executable (chmod +x) and exit 0 on
success, non-zero on failure.

**AC-3: Gate Scripts Report Clear Results (Event-driven)**
WHEN a gate script runs THE system SHALL print a human-readable pass/fail message
with the gate name.

**AC-4: Visual Gate Marked as Optional (Unwanted)**
WHILE the visual gate requires the ui-visual-check submodule THE system SHALL NOT require it
for non-UI projects.

**AC-5: Wiring Gate Simplified (Ubiquitous)**
WHILE the wiring gate checks entry reachability THE system SHALL use a simple grep-based
approach (check that all src/ exports are imported somewhere) rather than a full AST analysis.

### Change Specification

**Current Behavior:**
- `quality/gates/entry-reachability.sh` — referenced in TRIO.md, does not exist
- `quality/gates/ui-visual-check.sh` — referenced in TRIO.md, does not exist
- `quality/gates/wave-smoke.sh` — referenced in TRIO.md, does not exist
- `quality/gates/activation-gate.sh` — referenced in TRIO.md, does not exist
- `quality/gates/review-precheck.sh` — referenced in TRIO.md, does not exist

**Target Behavior:**
- Each gate script exists at its documented path OR documentation is updated to remove it
- Gate scripts are simple bash scripts (not complex tooling)
- Visual gate script checks for submodule availability and skips gracefully if missing

**Invariants:**
- gate.sh advance commands continue to work unchanged
- Gate scripts do not modify source code — they only check and report
- Gate scripts exit 0 on pass, 1 on fail

**Scope Boundary:**
- Changes: quality/gates/*.sh, TRIO.md, ARCHITECTURE.md, ROLES.md
- Does NOT change: gate.sh, transitions.json, agent role definitions

**Non-Goals:**
- Building a full AST analysis tool for wiring checks
- Implementing automated visual regression (screenshot comparison)
- Creating a CI/CD integration for gate scripts

## Error Handling

| Error | Handling |
|-------|----------|
| Script not found | Documentation updated to remove reference |
| Script fails | Exit 1 with descriptive error message |
| Submodule missing (visual gate) | Print "skipped — submodule not available" and exit 0 |

## Constraints

- Each script must be self-contained (no external dependencies beyond bash + standard tools)
- Scripts must complete in under 30 seconds
- Scripts must not modify any files

## Clarifications

- The wiring gate (entry-reachability) should check: "is every export in src/ imported
  by at least one file?" — a simple grep, not AST parsing.
- The activation gate should check: "do all tests pass AND no TODO/FIXME in changed files?"
- The review precheck should check: "is the diff under N lines AND no banned patterns?"
