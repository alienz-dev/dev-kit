---
id: 1
project: dev-kit
type: task
state: open
severity: P2
scope: work
reporter: unknown
assignee: kiro
tags:
  - process
  - trio
linked_specs: []
linked_tests: []
linked_files: []
links: []
deps: []
created: '2026-06-04T12:25:31.255+00:00'
updated: '2026-06-05T10:20:48.242+00:00'
---
# Single-agent waves should be parallel

## Motivation
<!-- Pain point or opportunity? -->

## Current Behavior
<!-- How does it work today? -->

## Desired Behavior
<!-- How should it work after? -->

## Design Constraints
<!-- Technical constraints, backward compatibility. -->
-

## Affected Files
<!-- Which files/modules will change? -->
-

## Acceptance Criteria
- [ ]

## Verification
<!-- Command that proves it works. -->
Command: ``
Expected output: ``

## History
- 2026-06-04T12:25:31.255+00:00 — opened (kiro)
- 2026-06-05T10:20:48.239+00:00 — edited fields: type

## Comments
- 2026-06-04T12:25:47.042+00:00 (kiro): Wave execution dispatches single agents per wave. Should be 2-3 parallel agents with exclusive file ownership. Wave-execution.md defines the protocol but execution doesn't follow it.
- 2026-06-05T10:20:48.242+00:00 (unknown): [triage] Triage: type enhancement → task, complexity 3/10, workflow: direct
