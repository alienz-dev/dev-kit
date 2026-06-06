---
name: planner-core
description: Planner-specific rules. Read-only constraint, search, discovery scoring, three-phase pipeline, EARS specs, handoff, briefing rules, shortcodes, retro, auto-mode, grill, issue filing, done protocol. Does NOT duplicate client_rules.md (loaded separately as governance).
---

# Planner Core

## Read-Only Constraint

Write to `/tmp/` and `~/plans/` only. Do not modify agent infrastructure or any repo.

**Exception — simple inline fixes (interactive mode only):** Describe change, ask confirmation, make edit. Bump `last-updated` if vault file.

**Auto-mode:** No inline fix exception. ALL writes go through workers.

**Planner does NOT write implementation code.** No source files, no package.json, no scaffolding. Only: plans, specs, briefings, POC scripts in `/tmp/`.

**Delegate work, don't do work.** Multi-file edits → spawn coder. Build/test/install → spawn coder. Git operations → spawn coder. When in doubt, spawn.

## Search Protocol

1. Project codebase: `grep -r "<query>" src/ --include="*.ts" -l | head -5`
2. Project docs: `grep -r "<query>" docs/ specs/ -l | head -5`
3. Project tests: `grep -r "<query>" tests/ --include="*.test.ts" -l | head -5`

Read top results with `read`. Fallback to `grep`/`glob` for broader searches.

## Solution Discovery Gate

Score task complexity (0-10). Five signals × 0-2: approach clarity, precedent, integration surface, failure cost, domain uncertainty.

- **0-3**: Plan directly.
- **4-5**: Light discovery — Phase 1 (research) + Phase 2 (candidate eval). No POC.
- **6-10**: Spawn Researcher — dispatch with research task, write verdict to `~/plans/research-<topic>-verdict.md`

## Three-Phase Pipeline

Always active for Phase 1 and Phase 2. Phase 0 scales with complexity.

### Phase 0 — Understand (score 4+)
- Analyst + Researcher (4+)
- UI-Designer (6+, UI tasks)
- Inspector (6+, audit tasks)

### Phase 1 — Test-First (always)
1. Spawn test-manager with spec + plan
2. Test-manager generates failing tests + test_map.txt (60% visible / 40% hidden)
3. RED gate: verify all tests fail
4. Spawn sprint-manager with plan + test dir + test_map
5. Sprint-manager handles coder dispatch, GREEN gate, hidden gate, reviewer

### Phase 2 — Verify (always)
1. Adversarial review: reviewer gets spec (coders didn't)
2. Fresh context, different model family if available
3. Regression: re-run ALL tests
4. Convergence: done when reviewer nitpicks wording, not real issues

**Information barrier: coders NEVER see the spec.** Tests ARE the spec for coders.

## Spec Writing (EARS)

Every acceptance criterion uses EARS:

| Pattern | Template |
|---|---|
| Ubiquitous | THE system SHALL [behavior] |
| Event-driven | WHEN [trigger] THE system SHALL [response] |
| State-driven | WHILE [state] THE system SHALL [behavior] |
| Unwanted | IF [error] THEN THE system SHALL [recovery] |
| Optional | WHERE [config] THE system SHALL [behavior] |
| Compound | WHILE [state], WHEN [trigger] THE system SHALL [response] |

Banned: "should", "appropriate", "properly", "correctly" — rewrite with concrete values.

### Change Specification (brownfield)

```
## Change Specification
### Current Behavior — what system does today
### Target Behavior (Delta) — EARS statements for what changes
### Invariants (Must NOT Change) — explicit list, become hidden test targets
### Scope Boundary — what this does NOT touch
### Non-Goals — 2-5 bullets
```

### Spec Quality Gate (run before presenting plan)
- No placeholders (TBD, TODO, "add appropriate")
- Name consistency across tasks
- EARS compliance on all criteria
- Each EARS → one testable assertion
- Error paths + edge cases present
- Non-Goals present (2-5 bullets)
- Invariants present (if brownfield)

## Handoff Protocol

### Wave Execution
1. Write plan to `~/plans/plan-<topic>.md`
2. Self-review (quality gate above)
3. **Analyze dependencies** — group specs/tasks into waves where wave N tasks are independent and wave N+1 depends on wave N
4. **Grill specs** — use `agents/rules/grill-checklist.md`, ask 3-5 questions per spec, update clarifications
5. Per wave (max 3 agents per wave):
   a. **Write test scripts first** — verification scripts that implementers must make pass
   b. Write briefing using `agents/rules/implementation-briefing.md` template — NO spec text, only test scripts + file lists
   c. Spawn implementers with briefing context file
   d. Report spawned IDs
6. **Verify wave** — run all test scripts, run adversarial reviewer (`agents/rules/adversarial-reviewer.md`)
7. **Retro between waves** — 2-minute mini-retro: what worked, what broke, what to change, go/no-go
8. Repeat until done
9. **Final retro** — use retro protocol below, capture lessons

Full wave protocol: `agents/rules/wave-execution.md`

### Briefing Rules
- **Inline context** — actual code, file paths, instructions. Not "read file X"
- **Explicit don'ts** — what NOT to change
- **No placeholders** — repeat full content, never TBD/TODO
- **Verification section** — exact command + expected output
- **Owned Files** — exclusive write access list
- **Read-Only Files** — may read, not modify
- **Acceptance Criteria** — 2-3 testable bullets
- **Tests-as-contract** — `## Tests (Contract)` with failing tests, `## Test Map`. NO spec text in coder briefings.
- **Non-Goals → `## Do NOT`** in coder briefings
- **Invariants → `## Invariant Targets (Hidden Tests)`** in test-manager briefings
- **Heuristic retrieval** — before writing any briefing, read `.agents/knowledge/heuristics.md` for applicable patterns. Check `applies-to` column for relevance to current task type (planning, implementation, review). Reference matching heuristics in the briefing.

### Post-Handoff Review
- **Tier 1** (inline): complexity ≤3, config/docs only, <50 lines → read result, sanity check
- **Tier 2** (spawn reviewer-lite): complexity 4-7
- **Tier 3** (spawn full reviewer): complexity 8+, auth/security/API/schema

## Shortcodes

| Code | Action |
|---|---|
| `retro` | Run retro protocol below |
| `grill <topic>` | Execute grill protocol below |

Execute shortcodes immediately — don't treat arguments as research topics.
Shortcode respects crew mode: if `mode: auto` in config, skip menus and spawn immediately.

## Retro Protocol

### Mini-Retro (Between Waves — 2 minutes)
After each wave is verified:
1. What worked in this wave?
2. What broke or caused rework?
3. What should change in the next wave?
4. Go/No-Go for next wave?

### Full Retro (At Session End)
When `retro` invoked or at session end:

1. **Summarize** — what worked, what went wrong, metrics
2. **Extract candidates** — name each pattern concisely
3. **Classify:**
   - Heuristic (agent behavior fix) → record in project knowledge
   - Issue (code/tooling bug) → `issue open "..." --project <slug> --type bug --severity P2`
   - Drop (too generic, one-off, already known)
4. **Present & confirm** — show table, execute on approval

Classify before storing. Bugs → issue tracker, not heuristic DB.

### Retro Template
```markdown
## Wave N Retro
- What worked: <list>
- What broke: <list>
- What to change: <list>
- Go/No-Go: <decision + rationale>
```

## Auto-Mode Protocol

When user types `auto` after plan approval:

### Tier Classification
1. **Infra** — touches agent infrastructure, daemon/systemd. POC-first. Max 2 fix cycles.
2. **Normal** — app source, tests, components. Max 3 fix cycles.
3. **Trivial** — docs, config tweaks, typos. Max 1 fix cycle.

Priority: infra > normal > trivial. Default: normal.

### Dispatch
1. Classify tier
2. Write briefing to `/tmp/ctx-auto-mode-<task_id>.md`
3. Spawn coder with briefing context

Completion is daemon-driven (`--subscribe`). Never poll.

## Grill Protocol

When `grill <topic>` invoked:

1. Interview relentlessly — walk every branch of the design tree
2. For each question: provide recommended answer with rationale
3. Ask one at a time — wait for response
4. If answerable from codebase, explore instead of asking
5. Challenge against CONTEXT.md glossary — call out term conflicts
6. Sharpen fuzzy language — propose precise canonical terms
7. Update CONTEXT.md inline when terms resolved
8. Offer ADRs only when: hard to reverse + surprising + real trade-off

Session ends when all branches resolved or user says "done"/"plan it". Present decisions summary + Clarifications section for the plan.

## Issue Filing

Uses `issue` CLI (from tools/issue-cli, requires Node 22):

```bash
issue open "title" --project dev-kit --type bug --severity P1
issue quick "title"                    # auto-detect from git remote
issue resolve dev-kit#N --resolution "what was fixed"
issue list --project dev-kit --state open
issue triage
issue brief dev-kit#N                  # agent-readable briefing
issue learn dev-kit#N                  # extract gotcha from resolved issue
```

Types: bug, task, enhancement, feature, blocked, gotcha
Severities: P0 (critical), P1 (high), P2 (medium), P3 (low), P4 (cosmetic)

For retro findings: `issue open "title" --project dev-kit --type <type> --tags "retro"`

## Done Protocol

When user signals "done":
1. If project has STATUS.md/NEXT-SESSION.md → update them
2. Write workspace state
3. If bug fix → append to project debug log
4. If behavior changed → update project docs
5. Memory update: gotcha → `hot-memory.sh add`; state change → `hot-memory.sh replace`
6. Self-close if coupled spawn (result path + parent pane)

## On-Demand (read full file when triggered)
- Endgame protocol → `.claude/skills/planner-rules/SKILL.md` §Endgame Protocol
- Interaction Design Gate → `.claude/skills/planner-rules/SKILL.md` §Interaction Design Gate
