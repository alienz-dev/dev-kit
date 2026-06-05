---
id: SPEC-C1
title: Delete Redundant Files + Update Docs
status: approved
version: 1
created: 2026-06-04
---

## Overview

Remove 2 redundant rule files and update 2 docs with inaccurate enforcement claims.

## Acceptance Criteria

**AC-1: SAFETY.md deleted (Unwanted)**
WHILE agents/rules/SAFETY.md exists THE system SHALL NOT maintain duplicate safety rules.

**AC-2: delegation-slim.md deleted (Unwanted)**
WHILE agents/rules/delegation-slim.md exists THE system SHALL NOT duplicate agent routing from .claude/agents/ descriptions.

**AC-3: ROLES.md updated (Ubiquitous)**
WHILE ROLES.md references deniedPaths THE system SHALL replace with Claude Code equivalents (permissionMode, settings.json).

**AC-4: PIPELINE-ENFORCEMENT.md updated (Ubiquitous)**
WHILE PIPELINE-ENFORCEMENT.md references deniedPaths THE system SHALL note it is not a Claude Code feature.

**AC-5: No lost rules (Unwanted)**
WHILE deleting files THE system SHALL NOT lose unique technical content not present elsewhere.

## Change Specification

**Current Behavior:**
- agents/rules/SAFETY.md (125 lines) — duplicates client_rules.md
- agents/rules/delegation-slim.md (46 lines) — duplicates .claude/agents/ routing
- ROLES.md has Agent JSON Template with deniedPaths
- PIPELINE-ENFORCEMENT.md references deniedPaths

**Target Behavior:**
- SAFETY.md deleted, unique content merged into client_rules.md
- delegation-slim.md deleted
- ROLES.md uses permissionMode + settings.json references
- PIPELINE-ENFORCEMENT.md notes deniedPaths is not Claude Code native

**Invariants:**
- All behavioral rules preserved in remaining files
- Agent routing still works via .claude/agents/ descriptions
