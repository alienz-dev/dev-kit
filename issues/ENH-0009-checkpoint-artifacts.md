---
id: ENH-0009
title: "Checkpoint Artifacts — persistent state between pipeline stages"
status: resolved
priority: low
component: pipeline
requested_by: ding
date: 2026-06-05
labels: [enhancement, sdd, pipeline, p2]
---

## Problem Statement

gate.sh tracks pipeline stage progression but doesn't persist stage-specific artifacts. When an agent resumes after a crash or context compaction, it must re-read the entire codebase to understand what was done. This wastes context and can lead to inconsistencies.

Currently:
- No record of which test files were written during test stage
- No record of which spec sections are covered by which tests
- No record of which waves ran during sprint stage
- No record of reviewer findings from previous review attempts

## Proposed Solution

Add checkpoint artifact writing to pipeline stages:

### 1. Test Stage Checkpoint
```json
// .pipeline/checkpoint-tests.json
{
  "stage": "test",
  "timestamp": "2026-06-05T10:00:00Z",
  "visible_tests": ["tests/auth/login.test.ts"],
  "hidden_tests": ["tests/auth/hidden-regression.test.ts"],
  "spec_coverage": {
    "SPEC-AUTH-001": ["S1", "S2.1", "S2.3", "S3"]
  },
  "all_red": true
}
```

### 2. Sprint Stage Checkpoint
```json
// .pipeline/checkpoint-sprint.json
{
  "stage": "sprint",
  "timestamp": "2026-06-05T11:00:00Z",
  "waves": [
    {"wave": 1, "coders": ["coder-1", "coder-2"], "status": "green"},
    {"wave": 2, "coders": ["coder-3"], "status": "green"}
  ],
  "gates_passed": ["green", "wiring", "visual", "wave-smoke"],
  "hidden_status": "passed"
}
```

### 3. Review Stage Checkpoint
```json
// .pipeline/checkpoint-review.json
{
  "stage": "review",
  "timestamp": "2026-06-05T12:00:00Z",
  "reviewer": "reviewer-lite",
  "tier": 2,
  "findings": {"blocking": 0, "major": 1, "minor": 3},
  "verdict": "pass-with-minor"
}
```

## Alternatives Considered

1. **Single checkpoint file** — rejected because different stages have different artifact shapes
2. **Database-backed checkpoints** — rejected because overkill; JSON files are sufficient and human-readable
3. **No checkpoints, re-read codebase** — rejected because wastes context and is slow

## Research Context

- Anthropic "Building Effective Agents": agents should "gain ground truth from the environment at each step"
- gate.sh already writes state.json — checkpoints extend this pattern
- issue-cli scratch notes are a similar concept but per-issue, not per-pipeline

## Impact

- Who benefits: agents (faster resume), users (less context waste), debugging (audit trail)
- Scope: every pipeline run
- Effort: ~3h
- Dependencies: None (extends gate.sh)
