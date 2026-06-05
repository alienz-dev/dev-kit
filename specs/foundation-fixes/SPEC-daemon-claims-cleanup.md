---
id: SPEC-005
title: Daemon Claims Cleanup
status: verified
version: 1
created: 2026-06-04
linked_issues: []
test_files: []
---

## Overview

PIPELINE-ENFORCEMENT.md describes a daemon with SQLite registry, role_policies, stall
detection, and stage-gated spawns. No daemon implementation exists. This creates a trust
problem — agents may rely on enforcement that doesn't exist.

**Goal:** Either implement a minimal daemon or replace all daemon claims with honest
documentation of what actually enforces pipeline rules.

## Behavior

### Acceptance Criteria

**AC-1: Documentation Matches Implementation (Ubiquitous)**
WHILE documentation describes enforcement THE system SHALL describe only enforcement
mechanisms that actually exist (gate.sh, lefthook, prompt-based discipline).

**AC-2: PIPELINE-ENFORCEMENT.md Rewritten (Event-driven)**
WHEN PIPELINE-ENFORCEMENT.md is updated THE system SHALL describe the actual enforcement
mechanisms: gate.sh (file-based FSM), lefthook (pre-commit hooks), and agent role
definitions (prompt-based constraints).

**AC-3: ROLES.md Updated (Event-driven)**
WHEN ROLES.md references daemon enforcement THE system SHALL replace with actual
enforcement mechanisms.

**AC-4: TRIO.md Updated (Event-driven)**
WHEN TRIO.md mentions "daemon-enforced" THE system SHALL replace with "gate.sh-enforced"
or "structurally enforced" as appropriate.

**AC-5: No Lost Functionality (Unwanted)**
WHILE removing daemon claims THE system SHALL NOT remove any behavioral rules that are
enforced by other mechanisms (gate.sh, lefthook, agent prompts).

### Change Specification

**Current Behavior:**
- PIPELINE-ENFORCEMENT.md describes daemon with SQLite, role_policies, stall detection
- ROLES.md says "daemon-enforced" for role_policies and deniedPaths
- TRIO.md says "daemon-enforced" for pipeline stages
- No daemon implementation exists

**Target Behavior:**
- PIPELINE-ENFORCEMENT.md describes actual enforcement (gate.sh + lefthook + prompts)
- ROLES.md says "structurally enforced" with explanation of how
- TRIO.md says "gate.sh-enforced" for pipeline stages
- Clear separation: what's enforced by code vs. what's enforced by agent prompts

**Invariants:**
- All behavioral rules preserved (none lost in cleanup)
- Agent role definitions unchanged (same constraints, different enforcement description)
- gate.sh behavior unchanged

**Scope Boundary:**
- Changes: PIPELINE-ENFORCEMENT.md, ROLES.md, TRIO.md, README.md, ARCHITECTURE.md
- Does NOT change: gate.sh, transitions.json, agent role definitions, scaffold.sh

**Non-Goals:**
- Implementing a real daemon
- Removing the concept of enforcement (just honest about what exists)
- Changing agent behavior (only changing documentation)

## Error Handling

| Error | Handling |
|-------|----------|
| Missing documentation files | Skip with warning |
| Conflicting enforcement claims | Resolve to actual mechanism |

## Constraints

- Must not lose any behavioral rules during cleanup
- Must not change agent behavior (only documentation)
- Must clearly distinguish "enforced by code" from "enforced by prompt"

## Clarifications

- "Structurally enforced" means the constraint is in the agent's system prompt/role definition
- "Code-enforced" means gate.sh or lefthook actually blocks the action
- "Prompt-enforced" means the agent is told not to do something (honor system)
