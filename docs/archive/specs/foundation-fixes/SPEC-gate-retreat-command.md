---
id: SPEC-003
title: gate.sh Retreat Command
status: verified
version: 1
created: 2026-06-04
linked_issues: []
test_files: []
---

## Overview

TRIO.md documents backward transitions (reviewing→specced, green→implementing, etc.)
but gate.sh can only move forward. There is no way to execute rework loops that the
methodology depends on.

**Goal:** Add a `gate.sh retreat <signal>` command that moves the pipeline backward
to enable rework loops.

## Behavior

### Acceptance Criteria

**AC-1: Retreat Command Exists (Ubiquitous)**
WHILE gate.sh is invoked with `retreat <signal>` THE system SHALL validate the signal
against transitions.json and move the pipeline to the target stage.

**AC-2: Retreat Validates Target Stage (Event-driven)**
WHEN a retreat signal is received THE system SHALL verify the signal's "from" field
matches the current stage before allowing the transition.

**AC-3: Retreat Records History (Event-driven)**
WHEN a retreat occurs THE system SHALL append the retreat event to the state history
with a "direction: backward" marker.

**AC-4: Retreat Signals Defined in transitions.json (Ubiquitous)**
WHILE transitions.json defines transitions THE system SHALL include retreat signals:
retry_plan, retry_test, retry_sprint, and new signals for review→test and review→specced.

**AC-5: Retreat Prints Warning (Event-driven)**
WHEN a retreat occurs THE system SHALL print a warning: "⚠ Pipeline retreated from
<X> to <Y> via <signal>".

### Change Specification

**Current Behavior:**
- gate.sh has: init, advance, status, check commands
- transitions.json has: retry_plan, retry_test, retry_sprint (from failed only)
- No way to go from review→test or review→specced

**Target Behavior:**
- gate.sh has: init, advance, retreat, status, check commands
- transitions.json has additional retreat signals: review_to_test, review_to_specced
- retreat command validates signal, updates state, records history

**Invariants:**
- Existing advance command behavior is unchanged
- State file format is backward compatible
- Only valid retreat signals are accepted

**Scope Boundary:**
- Changes: gate.sh, transitions.json
- Does NOT change: TRIO.md (already documents backward transitions), other gate scripts

**Non-Goals:**
- Automatic retreat triggers (retreat is always manual/explicit)
- Retreat from "done" or "failed" (use retry signals for that)

## Error Handling

| Error | Handling |
|-------|----------|
| Unknown signal | Print "unknown signal: X" and exit 1 |
| Signal doesn't match current stage | Print "cannot retreat: current stage is X, signal requires Y" and exit 1 |
| transitions.json missing | Print error and exit 1 |

## Constraints

- Pure bash implementation (no new dependencies)
- Backward compatible with existing .pipeline/state.json files
- Retreat history is distinguishable from forward advances

## Clarifications

- Retreat is for human-initiated rework, not automatic retry
- The "failed → plan/test/sprint" retry signals already exist and are separate from retreat
- Retreat signals go from review back to earlier stages (review→test, review→specced)
