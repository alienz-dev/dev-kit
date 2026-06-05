---
id: 2
project: dev-kit
type: bug
state: open
severity: P1
scope: work
assignee: kiro
tags:
  - hook
  - block-dangerous
linked_files: []
links: []
created: '2026-06-04T12:25:31.360+00:00'
updated: '2026-06-04T12:25:47.149+00:00'
---
# rm -rf /tmp/build was falsely blocked by hook

## Problem
<!-- What's broken? Include error messages, unexpected behavior. -->

## Reproduction
<!-- Exact steps to trigger. Include commands, inputs, environment. -->
1.
2.
3.

## Expected Behavior
<!-- What should happen instead? -->

## Affected Files
<!-- Which files/modules are likely involved? -->
-

## Root Cause Hypothesis
<!-- Best guess at why. Helps coder focus investigation. -->

## Verification
<!-- Exact command that proves the fix works. Copy-pasteable. -->
Command: ``
Expected output: ``

## Acceptance Criteria
- [ ]

## History
- 2026-06-04T12:25:31.360+00:00 — opened (kiro)

## Comments
- 2026-06-04T12:25:47.149+00:00 (kiro): [progress] FIXED: rm -rf /tmp/build was matched by rm -rf / pattern. Regex now checks for bare / not /path. Verified with 17 test cases.
