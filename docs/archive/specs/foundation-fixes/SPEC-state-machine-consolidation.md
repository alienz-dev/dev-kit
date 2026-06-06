---
id: SPEC-001
title: State Machine Consolidation
status: verified
version: 1
created: 2026-06-04
linked_issues: []
test_files: []
---

## Overview

The dev-kit currently has four overlapping but inconsistent state machines that define
pipeline and issue lifecycle stages. This causes agent confusion when trying to determine
what state an issue is in and what transition is valid.

**Goal:** Consolidate into a single source of truth in `transitions.json` that all other
files reference.

## Behavior

### Acceptance Criteria

**AC-1: Single Source of Truth (Ubiquitous)**
WHILE transitions.json exists THE system SHALL define all pipeline stages and their
valid transitions in transitions.json ONLY.

**AC-2: gate.sh Reads From transitions.json (Ubiquitous)**
WHILE gate.sh runs THE system SHALL read stage ordering from transitions.json
instead of hardcoding the stage array.

**AC-3: TRIO.md References transitions.json (Ubiquitous)**
WHILE TRIO.md documents the pipeline THE system SHALL reference transitions.json
for stage definitions rather than maintaining a separate state list.

**AC-4: constitution.yml Removed (Unwanted)**
WHILE constitution.yml exists THE system SHALL NOT duplicate transitions already
defined in transitions.json.

**AC-5: LIFECYCLE.md Aligned (Ubiquitous)**
WHILE LIFECYCLE.md defines issue states THE system SHALL map them explicitly to
pipeline stages in transitions.json.

### Change Specification

**Current Behavior:**
- `transitions.json`: 6 stages (plan, test, sprint, review, done, failed)
- `TRIO.md`: 11 states (open, specced, tests_written, red_verified, implementing, green, wiring_verified, visual_verified, hidden_verified, activation_verified, reviewing, closed)
- `LIFECYCLE.md`: 7 states (backlog, planned, open, in_progress, review, resolved, verified, closed)
- `constitution.yml`: 8 states (open, specced, tests_written, red_verified, implementing, green, reviewing, closed)
- `gate.sh`: hardcodes `("plan" "test" "sprint" "review" "done" "failed")` in `stage_index()`

**Target Behavior:**
- `transitions.json` is the single source of truth with the full state set
- `gate.sh` reads stages from transitions.json
- `TRIO.md` references transitions.json for state definitions
- `constitution.yml` is removed (or reduced to non-state config)
- `LIFECYCLE.md` maps its states to transitions.json stages

**Invariants:**
- gate.sh init/advance/status/check commands continue to work unchanged
- All existing transitions (plan_ready, tests_ready, etc.) remain valid
- The pipeline state file format (.pipeline/state.json) is unchanged

**Scope Boundary:**
- Changes: transitions.json, gate.sh, TRIO.md, LIFECYCLE.md, constitution.yml, ARCHITECTURE.md
- Does NOT change: scaffold.sh, agent role definitions, template files

**Non-Goals:**
- Implementing a real daemon
- Changing the pipeline stage vocabulary (plan/test/sprint/review/done/failed remain)
- Merging TRIO sub-states into gate.sh (sub-states are documentation-only)

## Error Handling

| Error | Handling |
|-------|----------|
| transitions.json missing | gate.sh falls back to hardcoded defaults (current behavior) |
| transitions.json malformed | gate.sh prints error and exits 1 |
| Stage not found in transitions.json | gate.sh prints "unknown stage: X" and exits 1 |

## Constraints

- Backward compatible: existing .pipeline/state.json files must continue to work
- No new dependencies (bash + jq/grep only)
- transitions.json must be valid JSON

## Clarifications

- TRIO's sub-states (wiring_verified, visual_verified, etc.) are documentation of gates
  WITHIN the sprint stage, not separate pipeline stages. They should be documented as
  gate checks within TRIO.md, not as stages in transitions.json.
- LIFECYCLE.md's states map to pipeline stages: backlog=pre-pipeline, planned=plan,
  open=plan, in_progress=sprint, review=review, resolved=done, verified=done, closed=done.
