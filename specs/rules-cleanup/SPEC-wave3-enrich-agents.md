---
id: SPEC-C3
title: Enrich Agent Definitions + Update Resource Sets
status: approved
version: 1
created: 2026-06-04
---

## Overview

Merge rule content into agent definitions to make them self-contained. Update RESOURCE-SETS.md to reflect Claude Code's actual loading mechanisms.

## Acceptance Criteria

**AC-1: reviewer.md enriched (Ubiquitous)**
WHILE .claude/agents/reviewer.md exists THE system SHALL include adversarial review protocol (edge cases, severity levels, "invert the question").

**AC-2: coder.md enriched (Ubiquitous)**
WHILE .claude/agents/coder.md exists THE system SHALL include six-phase loop, debugging rules, deviation protocol.

**AC-3: adversarial-reviewer.md deleted (Unwanted)**
WHILE agents/rules/adversarial-reviewer.md exists THE system SHALL NOT maintain separate file after merging into reviewer.md.

**AC-4: coder-workflow.md deleted (Unwanted)**
WHILE agents/rules/coder-workflow.md exists THE system SHALL NOT maintain separate file after merging into coder.md.

**AC-5: RESOURCE-SETS.md updated (Ubiquitous)**
WHILE RESOURCE-SETS.md describes custom loading THE system SHALL reflect Claude Code's actual mechanisms (rules with paths, agent defs, CLAUDE.md @imports).

**AC-6: No lost methodology (Unwanted)**
WHILE merging files THE system SHALL NOT lose unique methodology content.

## Change Specification

**Current Behavior:**
- reviewer.md: 31 lines, simple workflow
- coder.md: 33 lines, basic workflow
- adversarial-reviewer.md: 95 lines, standalone
- coder-workflow.md: 100 lines, standalone
- RESOURCE-SETS.md describes custom resource-set loading

**Target Behavior:**
- reviewer.md: ~100 lines, self-contained with adversarial protocol
- coder.md: ~80 lines, self-contained with six-phase loop
- adversarial-reviewer.md deleted
- coder-workflow.md deleted
- RESOURCE-SETS.md reflects Claude Code mechanisms

**Invariants:**
- All methodology preserved in agent definitions
- Agent behavior unchanged (same rules, different location)
