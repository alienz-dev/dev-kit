---
id: HW-006
title: Reviewer must be adversarial
source: 2026-06-04-foundation-fixes
confidence: high
applies-to: [review]
created: 2026-06-04
last-validated: 2026-06-05
times-applied: 0
---

## Pattern
Reviewers that only run verification commands and report pass/fail miss edge cases. An adversarial reviewer tries to BREAK things — circular inputs, double operations, malformed data, empty directories.

## Evidence
- 2026-06-04: Reviewer ran verification commands and reported pass/fail. Missed edge cases like circular retreat, double retreat, malformed transitions.json, empty directory handling.
- Adversarial reviewer prompt created with explicit "try to break this" instructions.

## Application
Reviewer prompts must include:
- "Try to BREAK things, not validate"
- "Check: circular inputs, double operations, malformed data, empty states"
- "What happens on error paths? What happens on boundary conditions?"
- Specific edge cases from the spec's Error Handling table

## Anti-Pattern
Reviewer that only checks happy paths. Reviewer that validates instead of challenges. Reviewer prompt without explicit adversarial instructions.
