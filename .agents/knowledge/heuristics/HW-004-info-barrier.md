---
id: HW-004
title: Enforce information barrier for coders
source: 2026-06-04-foundation-fixes
confidence: high
applies-to: [implementation]
created: 2026-06-04
last-validated: 2026-06-05
times-applied: 0
---

## Pattern
When implementers receive full spec + plan context, they implement to the spec's words rather than its intent. The information barrier (coders only see failing tests) forces them to understand behavior, not just satisfy text.

## Evidence
- 2026-06-04: All 5 implementation agents received full spec + plan context. The reviewer caught issues that proper information barriers would have prevented at the test level.
- Briefing template created with barrier enforcement.

## Application
Coder briefings must contain ONLY:
- Failing test file paths (what to make pass)
- File ownership list (what they can modify)
- Verification commands (how to confirm success)
- NO spec text, NO acceptance criteria rationale, NO design docs

## Anti-Pattern
Passing full spec to coders. Including "what it should do" prose in briefings. Allowing coders to read specs/ directory.
