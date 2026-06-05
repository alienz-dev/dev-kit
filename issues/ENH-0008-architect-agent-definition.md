---
id: ENH-0008
title: "Architect Agent — system design and component boundaries"
status: resolved
priority: medium
component: agent
requested_by: ding
date: 2026-06-05
labels: [enhancement, sdd, agent, p2]
---

## Problem Statement

The toolkit has UI-Designer for visual design but no system design agent. When a feature touches architecture (new services, data models, API contracts, integration points), the planner handles design decisions implicitly during spec writing. This means:
- Design decisions aren't documented separately from specs
- Component boundaries aren't explicitly defined before implementation
- Interface contracts (function signatures, API schemas) emerge ad-hoc during coding
- Architecture Decision Records (ADRs) aren't created for non-obvious choices

## Proposed Solution

Create an Architect agent definition:

### 1. Architect Role (agents/roles/ARCHITECT.md)
- Takes a spec and outputs architectural decisions
- Responsibilities:
  - Component decomposition (what modules, what boundaries)
  - Interface contracts (function signatures, API schemas, data models)
  - Data flow diagrams (markdown-based)
  - Integration point mapping (what connects to what)
  - ADR for non-obvious choices
- Runs between spec approval and plan derivation
- Adversarial: challenges spec assumptions from an architecture perspective

### 2. Architect Claude Code Agent (.claude/agents/architect.md)
- Model: sonnet (architecture review doesn't need opus)
- Max turns: 20
- Tools: Read, Grep, Glob (codebase analysis)
- Isolation: none (needs full project context)
- Output: architecture.md with component diagram, interface contracts, ADRs

### 3. Architect Skill (agents/skills/architect-review.md)
- Reusable skill for adversarial plan review
- 5-lens critique: correctness, security, performance, maintainability, testability
- Can be invoked by any agent

## Alternatives Considered

1. **Merge into Planner** — rejected because planner already overloaded (spec + plan + wave management)
2. **Skip architect, let coders decide** — rejected because architecture should be decided before coding, not during
3. **Full architect agent for every feature** — rejected because only needed for complexity 8+; simpler features use planner's implicit design

## Research Context

- dev-kit agents/rules/planner-core.md: Solution Discovery Gate (0-10 scoring) already evaluates architecture implicitly
- dev-kit agents/roles/ROLES.md: UI-Designer exists for visual design; Architect is the system design equivalent
- Industry: CrewAI has specialized agent roles; Anthropic recommends role separation

## Impact

- Who benefits: planners (design decisions documented), coders (clear contracts), reviewers (architecture baseline)
- Scope: every feature with complexity 8+
- Effort: ~2h for agent definition, ~3h for full implementation
- Dependencies: None (standalone)
