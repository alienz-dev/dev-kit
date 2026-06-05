---
id: SPEC-AIDLC-001
title: "AIDLC Best Practices Implementation"
status: verified
version: "1.0"
created: 2026-06-05
linked_issues: []
test-files: []
---

# AIDLC Best Practices Implementation

## §1 Overview

Implement the three critical gaps identified in the AIDLC best practices research:
1. Context management — reduce governance overhead from 69% to <33%
2. Missing gate scripts — implement or remove 5 documented gates
3. Worktree isolation — enable true parallel execution for coders

This change addresses the #1 constraint in agentic coding (context window management) and enables faster multi-file changes.

## §2 Behavior

### 2.1 Context Management

**Goal:** Reduce governance context from 16.5KB to <8KB per session.

WHEN an agent session starts THE system SHALL load governance rules from a single deduplicated source.

WHILE loading context THE system SHALL use skills-based on-demand loading for domain-specific knowledge.

THE system SHALL provide a compaction strategy document for agents to use between tasks.

### 2.2 Gate Scripts

**Goal:** Either implement missing gates or simplify pipeline to match reality.

WHEN a gate is referenced in transitions.json THE system SHALL have a corresponding script in quality/gates/.

IF a gate script does not exist THEN THE system SHALL either:
- Implement the script, OR
- Remove the gate from transitions.json and update documentation

### 2.3 Worktree Isolation

**Goal:** Enable true parallel execution for coders.

WHEN sprint-manager dispatches multiple coders THE system SHALL create isolated git worktrees for each coder.

WHILE coders work in parallel THE system SHALL prevent merge conflicts via worktree isolation.

WHEN all coders complete THE system SHALL merge worktrees sequentially into the main branch.

## §3 Change Specification

### Current Behavior
- Governance rules duplicated across 3+ files (agents/rules/, templates/common/, workflow/)
- Five gates documented in ARCHITECTURE.md but scripts missing:
  - quality/gates/entry-reachability.sh (WIRING)
  - quality/gates/ui-visual-check.sh (VISUAL)
  - quality/gates/wave-smoke.sh (wave completion)
  - quality/gates/activation-gate.sh (ACTIVATION)
  - quality/gates/review-precheck.sh (REVIEW)
- Coders share working directory, cannot run in parallel safely

### Target Behavior (Delta)
- Single governance source at agents/rules/CONSOLIDATED.md (<8KB)
- Skills loaded on-demand via agents/skills/ directory
- All gates in transitions.json have corresponding scripts
- Documentation matches implemented gates
- Sprint-manager creates worktrees before dispatching coders

### Invariants (Must NOT Change)
- TRIO protocol (RED→GREEN gate sequence)
- Information barrier (coder never sees spec)
- Tiered review system (3 tiers)
- EARS notation for acceptance criteria
- Hidden regression tests pattern

### Scope Boundary
- NOT changing agent role definitions
- NOT changing spec format or EARS notation
- NOT implementing CI/CD integration templates (future work)
- NOT implementing structured cross-session learning (future work)

## §4 Error Handling

| Scenario | Expected | Rationale |
|----------|----------|-----------|
| Worktree creation fails | Fall back to sequential execution | Graceful degradation |
| Gate script missing | Log error, skip gate with warning | Don't block pipeline for missing tooling |
| Context >8KB after consolidation | Review and trim further | Hard constraint for context management |

## §5 Constraints

- **Context budget:** <8KB governance per session (from 16.5KB)
- **Backward compatibility:** Existing projects must work without changes
- **Performance:** Worktree creation <500ms per coder
- **Safety:** No force-push, no reset --hard in worktree scripts

## §6 Clarifications (from grill session)

- Q: How should we consolidate governance rules? → A: Hybrid approach — core rules (execution safety, verification, anti-destruction) stay in governance, domain-specific rules move to skills for on-demand loading
- Q: Should we keep separate locations or consolidate? → A: Single source file at `agents/rules/CONSOLIDATED.md` that templates reference during scaffold
- Q: What to do about missing gate scripts? → A: Implement all 5 gates (WIRING, VISUAL, wave-smoke, ACTIVATION, REVIEW) for full pipeline integrity
- Q: How to isolate parallel coders? → A: Git worktrees — faster than cloning, shares git history, native feature
- Q: What implementation order? → A: Sequential — context management → gate scripts → worktree isolation
- Q: How to verify changes? → A: Automated tests for gate scripts, manual verification for context size and worktree isolation
- Q: How to merge worktrees? → A: Rebase and merge — keeps linear history, each coder's work is a distinct commit
- Q: Should we expand scope? → A: Add compaction strategy documentation (quick win, directly addresses context management)

## §7 Visual Acceptance Criteria

N/A — no UI changes in this spec.
