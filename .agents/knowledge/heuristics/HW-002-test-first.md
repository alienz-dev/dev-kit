---
id: HW-002
title: Always write test scripts first
source: 2026-06-04-foundation-fixes
confidence: high
applies-to: [implementation]
created: 2026-06-04
last-validated: 2026-06-05
times-applied: 0
---

## Pattern
Implementation agents that read specs directly and implement are prone to rubber-stamping — they satisfy the words but not the intent. Writing verification scripts first forces implementers to understand what the command does.

## Evidence
- 2026-06-04: All 5 implementation agents received full spec + plan context. TRIO's iron law ("coder NEVER sees the spec") was violated completely.
- Implementers who read "AC-4 requires review_to_test signal" just add it. Implementers who read "make this test pass: `gate.sh retreat review_to_test`" must understand the command.

## Application
Before spawning implementers:
1. Test-manager writes verification scripts (e.g., `test-retreat.sh`)
2. Scripts implement the spec's acceptance criteria as runnable checks
3. Implementers work from test scripts, not specs
4. RED gate: verify all tests fail before implementation begins

## Anti-Pattern
Writing tests after code. Tests that verify existence not behavior (`expect(result).toBeDefined()`). Skipping RED verification.
