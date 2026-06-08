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

Every criterion MUST match exactly one pattern. Each statement = one test case.

| Pattern | Template | When to use |
|---------|----------|-------------|
| Ubiquitous | `THE system SHALL [behavior]` | Always-active behavior, no trigger needed |
| Event-driven | `WHEN [trigger] THE system SHALL [response]` | Responding to a discrete, detectable event |
| State-driven | `WHILE [state] THE system SHALL [behavior]` | Behavior while in a specific mode/state |
| Unwanted | `IF [condition] THEN THE system SHALL [recovery]` | Error handling, fault scenarios, edge cases |
| Optional | `WHERE [feature] THE system SHALL [behavior]` | Behavior tied to a config/feature flag |

Compound patterns are allowed: `WHILE [state] WHEN [trigger] THE system SHALL [response]`

**Examples:**
- THE system SHALL expose a health endpoint at /healthz
- WHEN user clicks "Next" THE system SHALL load page N+1
- WHILE loading THE system SHALL show skeleton UI
- IF API returns 500 THEN THE system SHALL show retry button
- WHERE dark mode is enabled THE system SHALL use dark color tokens

**Coverage rule:** For each behavior, include at least one happy-path (WHEN or Ubiquitous) AND at least one error-path (IF/THEN). Use the pattern checklist: "What events trigger it? What states constrain it? What errors can occur? What optional features affect it?"

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

### Non-Functional Requirements (SHALL/MUST)

Use RFC 2119 language for non-functional requirements. Each NFR MUST be measurable.

| Category | Template | Example |
|----------|----------|---------|
| Performance | `The system SHALL [action] within [N] [unit]` | The system SHALL respond to API requests within 200ms (p95) |
| Security | `The system SHALL NOT [action]` / `The system MUST [action]` | The system MUST sanitize all user input before rendering |
| Compatibility | `The system SHALL support [target]` | The system SHALL support Node.js 20+ |
| Availability | `The system SHALL maintain [metric] of [value]` | The system SHALL maintain 99.9% uptime per calendar month |
| Capacity | `The system SHALL handle [N] [unit] simultaneously` | The system SHALL handle 1000 concurrent WebSocket connections |

**Rules:**
- SHALL = absolute requirement. SHOULD = recommended. MAY = optional.
- Every NFR must have a measurable threshold (no "fast", "efficient", "scalable")
- Security constraints: specify what the system MUST NOT do (attack surface reduction)
- If no NFRs apply, write "None — default project constraints apply"

### Additional Constraints
<Compatibility requirements, platform constraints, regulatory requirements>

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

## §8 Debugging & Observability

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
