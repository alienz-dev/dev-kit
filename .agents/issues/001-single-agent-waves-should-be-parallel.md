---
id: 1
project: dev-kit
type: enhancement
state: open
severity: P2
scope: work
assignee: kiro
tags:
  - process
  - trio
linked_files: []
links: []
created: '2026-06-04T12:25:31.255+00:00'
updated: '2026-06-04T12:25:47.042+00:00'
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

## Comments
- 2026-06-04T12:25:47.042+00:00 (kiro): Wave execution dispatches single agents per wave. Should be 2-3 parallel agents with exclusive file ownership. Wave-execution.md defines the protocol but execution doesn't follow it.
