# Pipeline Enforcement

Three-tier enforcement model for pipeline stages, role boundaries, and behavioral constraints.

## Enforcement Model

| Tier | Mechanism | What It Enforces | Strength |
|------|-----------|-----------------|----------|
| **Code-enforced** | `gate.sh` (file-based FSM) | Pipeline stage progression, state tracking | Hard block — cannot bypass without modifying scripts |
| **Code-enforced** | `lefthook` (pre-commit hooks) | Test gate, typecheck, lint before commit | Hard block — git rejects commit on failure |
| **Prompt-enforced** | Agent role definitions | Role boundaries, spawn policies, write scopes | Soft block — agent honors constraint via system prompt |
| **Workflow-enforced** | Orchestration logic in workflow script | Stronger than prompt — script executes deterministically. Handles concurrency, retries, phase tracking. |

### What IS Enforced (Code-Enforced)

- **Pipeline stage progression:** `gate.sh` tracks state in `.pipeline/state.json` and only allows valid transitions per `transitions.json`
- **Pre-commit quality gates:** `lefthook` runs test gate, typecheck, and lint — commit is rejected on failure
- **State file existence:** `gate.sh check` validates current stage before allowing advancement

### What is NOT Enforced (Prompt-Only)

- **Role spawn policies:** Agent role definitions instruct who can spawn whom, but no code blocks invalid spawns
- **Write scope boundaries:** Agent role prompts define which paths each role can write, but enforcement depends on agent compliance
- **Stall detection:** No active monitoring — agents must self-report stalls
- **Stage-gated spawns:** Agent prompts specify which roles are valid at which stages, but no runtime check exists

> **Workflows address some gaps**: Role spawn policies and stage-gated spawns can be
> structurally enforced in workflow scripts. The `wave-dispatch` workflow codifies
> "max 3 coders per wave" and "no file overlap" as script logic rather than prompt instructions.

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

## Role Policies (Prompt-Enforced)

These policies are defined in agent role prompts. Agents honor them by convention, not by runtime enforcement.

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
# File-based pipeline (no daemon required)
bash workflow/pipeline/gate.sh init PROJ-042
bash workflow/pipeline/gate.sh advance tests_ready
bash workflow/pipeline/gate.sh status
bash workflow/pipeline/gate.sh check sprint
```

## Stall Detection (Not Implemented)

There is no active stall detection. If the pipeline stalls, the supervisor must notice and intervene manually.

## Implementation

Pipeline state stored in file-based JSON (no SQLite, no daemon):
```json
{
  "id": "PROJ-042",
  "stage": "sprint",
  "transitions": ["plan→test", "test→sprint"]
}
```

Managed by `gate.sh` commands — no background process required.
