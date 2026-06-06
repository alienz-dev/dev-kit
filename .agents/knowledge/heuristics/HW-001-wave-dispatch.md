---
id: HW-001
title: Always use wave dispatch, never all-at-once
source: 2026-06-04-foundation-fixes
confidence: high
applies-to: [planning, multi-spec]
created: 2026-06-04
last-validated: 2026-06-05
times-applied: 0
---

## Pattern
Dispatching all agents at once (one giant wave) causes dependency violations and prevents learning between batches. Tasks must be grouped by dependency into waves, with retros between waves.

## Evidence
- 2026-06-04: SPEC-003 depended on SPEC-001 but ran in parallel. Reviewer had to catch missing signals that proper wave ordering would have prevented.
- Wave execution protocol created (`agents/rules/wave-execution.md`) to prevent this.

## Application
When planning multi-spec tasks:
1. Analyze dependency graph between specs/tasks
2. Group into waves where wave N tasks are independent
3. Wave N+1 depends on wave N outputs
4. Max 3-4 agents per wave
5. Retro between waves before dispatching next

## Anti-Pattern
All-at-once dispatch. Skipping dependency analysis. Waves larger than 4 agents without exclusive file ownership.
