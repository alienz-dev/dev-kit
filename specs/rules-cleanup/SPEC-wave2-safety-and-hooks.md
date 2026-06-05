---
id: SPEC-C2
title: Consolidate Safety Rules + Create Hooks
status: approved
version: 1
created: 2026-06-04
---

## Overview

Merge 3 safety files into 1 consolidated .claude/rules/safety.md. Create hook scripts for structural enforcement of critical safety rules.

## Acceptance Criteria

**AC-1: Single safety file (Unwanted)**
WHILE agents/rules/SAFETY.md and agents/rules/client_rules.md and templates/.../safety.md all exist THE system SHALL NOT maintain 3 separate safety files.

**AC-2: Consolidated file is global rule (Ubiquitous)**
WHILE .claude/rules/safety.md exists THE system SHALL have no `paths:` frontmatter (loads at session start).

**AC-3: block-dangerous.sh hook exists (Event-driven)**
WHEN a dangerous command (rm -rf, git push --force, --pool forks, git reset --hard, git clean) is attempted THE system SHALL block it via PreToolUse hook.

**AC-4: verify-tests.sh hook exists (Event-driven)**
WHEN Claude is about to stop THE system SHALL verify tests pass via Stop hook.

**AC-5: scaffold.sh generates hooks (Event-driven)**
WHEN scaffold.sh creates .claude/ THE system SHALL include hook scripts and settings.json hook configuration.

**AC-6: Hooks are executable (Ubiquitous)**
WHILE hook scripts exist THE system SHALL be executable (chmod +x).

## Change Specification

**Current Behavior:**
- 3 safety files with overlapping content
- No hook scripts for enforcement
- scaffold.sh generates minimal settings.json

**Target Behavior:**
- 1 consolidated .claude/rules/safety.md
- .claude/hooks/block-dangerous.sh (PreToolUse)
- .claude/hooks/verify-tests.sh (Stop)
- scaffold.sh generates settings.json with hooks configured

**Invariants:**
- All safety rules preserved in consolidated file
- Hooks block dangerous commands regardless of Claude's decisions
- scaffold.sh still works on fresh projects
