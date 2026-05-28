# Pipeline Enforcement

Daemon-enforced FSM that prevents agents from skipping stages or spawning outside their authority.

## Pipeline Stages

```
plan → test → sprint → review → done | failed
```

## Transitions and Signals

| From | To | Signal | Triggered By |
|------|-----|--------|-------------|
| plan | test | `plan_ready` | Supervisor completes spec |
| test | sprint | `tests_ready` | Test-manager confirms RED |
| sprint | review | `sprint_complete` | Sprint-manager passes all gates |
| review | done | `review_complete` | Reviewer approves |
| any | failed | `stage_failed` | Max retries exhausted |

## Recovery Transitions

| From | To | Signal | When |
|------|-----|--------|------|
| failed | plan | `retry_plan` | Spec needs revision |
| failed | test | `retry_test` | Tests need rewriting |
| failed | sprint | `retry_sprint` | Implementation retry |

## Role Policies (Daemon-Enforced)

| Spawner | Target | Policy | Rationale |
|---------|--------|--------|-----------|
| planner/supervisor | coder | **NEVER** | Must go through sprint-manager |
| planner/supervisor | sprint-manager | ALWAYS | Delegates implementation |
| planner/supervisor | test-manager | ALWAYS | Delegates RED gate |
| sprint-manager | coder | **ALWAYS** | Owns GREEN gate |
| sprint-manager | reviewer-lite | ALWAYS | Tier 2 review |
| sprint-manager | reviewer | ALWAYS | Tier 3 review |
| test-manager | coder | NEVER | Doesn't own implementation |
| test-manager | tester | ALWAYS | Help writing tests |

**Deny-by-default:** If a role_policy doesn't explicitly ALLOW a spawn, it's blocked. Stage-gated policy + no active pipeline = blocked.

## Stage-Gated Spawns

Some spawns are only allowed during specific pipeline stages:

| Spawn | Allowed During | Blocked During |
|-------|---------------|----------------|
| coder | sprint | plan, test, review |
| reviewer | review | plan, test, sprint |
| test-manager | test | sprint, review |

## Pipeline CLI

```bash
# Create a pipeline for a feature
kiro-ctl pipeline create --feature PROJ-042

# Advance to next stage (with signal)
kiro-ctl pipeline advance --signal tests_ready

# Get current state
kiro-ctl pipeline get

# Auto-advance on spawn completion (--pipeline-topic flag)
kiro-ctl spawn sprint-manager "task" --subscribe --pipeline-topic PROJ-042
```

## Stall Detection

If no `pipeline advance` occurs within 600s, daemon signals stall:
- Injects `[system] [STALL] Pipeline PROJ-042 stuck at stage: sprint (600s no-advance)` into supervisor pane
- Does NOT auto-kill — supervisor decides next action

## Implementation

Pipeline state stored in daemon's SQLite registry. Each pipeline record:
```json
{
  "id": "PROJ-042",
  "stage": "sprint",
  "created_at": "2026-05-28T10:00:00Z",
  "last_advance": "2026-05-28T10:15:00Z",
  "history": ["plan→test (10:05)", "test→sprint (10:15)"],
  "active_agents": ["sprint-manager-abc123", "coder-def456"]
}
```
