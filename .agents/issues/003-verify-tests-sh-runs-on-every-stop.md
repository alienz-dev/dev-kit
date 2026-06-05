---
id: 3
project: dev-kit
type: task
state: open
severity: P2
scope: work
reporter: unknown
assignee: kiro
tags:
  - hook
  - verify-tests
linked_specs: []
linked_tests: []
linked_files: []
links: []
deps: []
created: '2026-06-04T12:25:31.464+00:00'
updated: '2026-06-05T10:20:48.243+00:00'
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
- 2026-06-05T10:20:48.242+00:00 — edited fields: type

## Comments
- 2026-06-04T12:25:47.255+00:00 (kiro): verify-tests.sh runs npx vitest on every Stop event. Should only run when test files changed. Added git diff check but needs verification.
- 2026-06-05T10:20:48.243+00:00 (unknown): [triage] Triage: type enhancement → task, complexity 2/10, workflow: direct
