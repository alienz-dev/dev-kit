---
id: HW-003
title: Always grill specs before approval
source: 2026-06-04-foundation-fixes
confidence: high
applies-to: [planning]
created: 2026-06-04
last-validated: 2026-06-05
times-applied: 0
---

## Pattern
Specs written by the planner and immediately marked "approved" without adversarial review miss design gaps. Grill sessions catch ambiguities and edge cases before implementation begins.

## Evidence
- 2026-06-04: Specs were approved without grill. Questions like "Should retreat work from sprint stage? From done?" and "What happens on circular retreat?" were never asked.
- Grill checklist template created (`agents/rules/grill-checklist.md`) to prevent this.

## Application
Before marking any spec "approved":
1. Run grill session with at least 3 questions per spec
2. Challenge design decisions against the checklist
3. Ask about edge cases, error paths, and boundary conditions
4. Update spec with clarifications from grill
5. Only then approve

## Anti-Pattern
Skipping grill for "simple" specs. Grill with only surface-level questions. Approving spec without updating clarifications section.
