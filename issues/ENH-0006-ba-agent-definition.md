---
id: ENH-0006
title: "BA Agent — requirements gathering and stakeholder alignment"
status: resolved
priority: medium
component: agent
requested_by: ding
date: 2026-06-05
labels: [enhancement, sdd, agent, p1]
---

## Problem Statement

The Planner currently does double-duty: gathering requirements AND writing specs. These are different skills with different concerns:
- Requirements gathering: interactive, multi-turn, context-dependent, stakeholder-focused
- Spec writing: structured, EARS-validated, template-driven

Without a dedicated BA agent:
- Requirements are implicit in the planner's head, not documented
- Stakeholder intent isn't captured separately from spec prose
- Complex features (complexity 6+) don't get structured requirements elicitation before grill
- Non-functional requirements (performance, security, accessibility) are often missed

## Proposed Solution

Create a BA agent definition with two components:

### 1. BA Agent Role (agents/roles/BA.md)
- Takes raw stakeholder intent ("we need X because Y")
- Runs structured requirements elicitation:
  - Who uses this? (personas, actors)
  - What does success look like? (outcomes, not features)
  - What are the constraints? (non-functional requirements)
  - What are the edge cases? (empty states, errors, concurrent access)
  - What's explicitly out of scope? (non-goals)
- Outputs: structured requirements document with EARS-ready acceptance criteria
- Hands to Planner for spec writing

### 2. BA Claude Code Agent (.claude/agents/ba.md)
- Model: sonnet (cheaper than planner, requirements gathering doesn't need opus)
- Max turns: 30
- Tools: Read, Grep, Glob, WebSearch (for research)
- Isolation: none (needs project context)
- Output format: structured requirements with EARS criteria

### 3. BA Skill (agents/skills/ba-validation.md)
- Already covered by ENH-0003 (ba-validate skill)
- BA agent invokes ba-validate before handing to planner

## Alternatives Considered

1. **Expand grill protocol** — rejected because grill is interactive (human-in-the-loop), BA should be autonomous for initial pass
2. **Merge into Planner** — rejected because separation of concerns; planner should focus on spec quality and plan derivation
3. **Skip BA, go straight to spec** — rejected because complex features need structured requirements before spec

## Research Context

- Anthropic "Building Effective Agents": agents for stateful/interactive tasks, skills for stateless checks
- Harper Reed workflow: brainstorm spec phase is where requirements are captured
- dev-kit grill protocol: already does design interview, but AFTER requirements are known
- Industry: CrewAI has "backstories" for agents — BA agent could have domain-specific context

## Impact

- Who benefits: planners (cleaner requirements), users (better specs), coders (fewer rework cycles)
- Scope: every feature with complexity 6+
- Effort: ~2h for agent definition, ~4h for full implementation with prompts
- Dependencies: ENH-0003 (ba-validate skill) should be built first
