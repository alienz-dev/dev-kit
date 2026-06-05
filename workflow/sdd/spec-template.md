---
id: SPEC-NNN
title: "Feature Name"
status: draft | approved | implementing | verified | shipped
version: "1.0"
created: YYYY-MM-DD
approved_by: ""  # Required for P0/P1 and complexity 8+
approval_date: ""  # Set when approved_by is filled
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
<What the system does now — observable, testable>

### Target Behavior (Delta)
<What changes — EARS statements for new behavior>

### Invariants (Must NOT Change)
<Behavior that must remain unchanged — feeds hidden test targets>

### Scope Boundary
<What is explicitly OUT of scope for this change>

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
