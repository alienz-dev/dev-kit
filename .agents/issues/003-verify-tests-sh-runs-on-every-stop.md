---
id: 3
project: dev-kit
type: enhancement
state: open
severity: P2
scope: work
assignee: kiro
tags:
  - hook
  - verify-tests
linked_files: []
links: []
created: '2026-06-04T12:25:31.464+00:00'
updated: '2026-06-04T12:25:47.255+00:00'
---
# verify-tests.sh runs on every stop

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
- 2026-06-04T12:25:31.464+00:00 — opened (kiro)

## Comments
- 2026-06-04T12:25:47.255+00:00 (kiro): verify-tests.sh runs npx vitest on every Stop event. Should only run when test files changed. Added git diff check but needs verification.
