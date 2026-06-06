---
id: HW-005
title: Dogfood your own tools
source: 2026-06-04-foundation-fixes
confidence: medium
applies-to: [planning]
created: 2026-06-04
last-validated: 2026-06-05
times-applied: 0
---

## Pattern
Building tools without using them yourself (dogfooding) misses UX issues and bugs. If you build gate.sh, use gate.sh to track your own pipeline.

## Evidence
- 2026-06-04: Built gate.sh improvements but never used gate.sh to track the foundation-fixes pipeline. The macOS flock bug would have been found during planning, not during verification.
- "Dogfood" step added to planner protocol.

## Application
When building or improving tooling:
1. Use the tool on the current task immediately after building it
2. Track your own pipeline with gate.sh
3. Run your own validation scripts on your own specs
4. File issues found during dogfooding before moving on

## Anti-Pattern
Building tools without testing them on real workflows. Testing only with synthetic data. Deferring dogfooding to "later."
