# Agent Roles

## Claude Code Agent Mapping

| dev-kit Role | Claude Code Agent | Location |
|-------------|------------------|----------|
| Supervisor/Planner | Main Claude Code session | (interactive) |
| Coder | `.claude/agents/coder.md` | `Agent(subagent_type="coder")` |
| Reviewer | `.claude/agents/reviewer.md` | `Agent(subagent_type="reviewer")` |
| Test-Manager | `.claude/agents/test-manager.md` | `Agent(subagent_type="test-manager")` |
| Researcher | `.claude/agents/researcher.md` | `Agent(subagent_type="researcher")` |
| Explorer | `.claude/agents/explorer.md` | `Agent(subagent_type="explorer")` |
| Sprint-Manager | Main session orchestration | (sequential dispatch) |

Claude Code spawns in-process subagents via the `Agent()` tool. No daemon or multiplexer needed.

## Role Architecture

```
User
  └── Main Session (Planner + Sprint-Manager — persistent)
        ├── Test-Manager (subagent — owns RED gate)
        ├── Coder ×N (subagent, worktree-isolated — max 3 parallel per wave)
        ├── Reviewer (subagent — verifies spec intent match)
        ├── Researcher (subagent — ARIA v2 orchestrator)
        │     ├── Explorer ×N (subagent — focused investigation, parallel)
        │     └── Research-Critic (subagent — adversarial review)
        └── UI-Designer (subagent — Phase 0, complexity 6+ UI)
```

**Key constraint:** Subagents cannot spawn subagents. The main session acts as Sprint-Manager, directly orchestrating coder waves, gate sequences, and reviewer dispatch. The `/trio` skill guides the main session through this orchestration.

## Dispatch Rules

| From | To | Policy |
|------|-----|--------|
| Planner/Supervisor | Coder | **NEVER** (structurally enforced by agent role definition) |
| Planner/Supervisor | Sprint-Manager | ALWAYS (for implementation) |
| Planner/Supervisor | Test-Manager | ALWAYS (for RED gate) |
| Sprint-Manager | Coder | **ALWAYS** (max 3 parallel, no file overlap) |
| Sprint-Manager | Reviewer-Lite | ALWAYS (Tier 2) |
| Sprint-Manager | Reviewer | ALWAYS (Tier 3) |
| Test-Manager | Coder | NEVER |

---

## Role Definitions

### Supervisor / Planner

**Purpose:** Orchestrate, diagnose, delegate. Never implement.

**Can:**
- Read all project files
- Write: STATUS.md, NEXT-SESSION.md, issues/, plans/, specs/, /tmp/
- Run tests, typecheck, diagnostics
- Spawn: test-manager, sprint-manager, researcher, ui-designer

**Cannot:**
- Write src/, tests/, *.ts, *.tsx, *.js, *.py
- Modify package.json, tsconfig.json, vitest.config.*
- Spawn coders directly (structurally enforced by agent role definition)

**Enforcement:** Write boundaries are defined in the agent role prompt (prompt-enforced). Direct coder spawns are blocked by role definition in the agent prompt.

**Behavior:**
1. On session start: read state files, present status, ask for direction
2. On task: write spec → spawn test-manager → spawn sprint-manager → monitor gates
3. On completion: update STATUS.md, NEXT-SESSION.md

---

### Test-Manager

**Purpose:** Own the RED gate — write tests, verify they fail.

**Can:**
- Read all project files including specs
- Write: tests/, /tmp/
- Run tests
- Spawn: tester (for additional test writing)

**Cannot:**
- Write src/ (implementation code)
- Spawn coders (sprint-manager's job)

**Behavior:**
1. Receive spec from supervisor
2. Write test files (visible + hidden)
3. Verify RED (all tests fail for the right reasons)
4. Signal `tests_ready` → sprint-manager takes over
5. After GREEN: run hidden regression tests
6. Report result to supervisor

**Persistence:** Test-manager stays open for the full cycle (use `--topic` flag).

---

### Sprint-Manager

**Purpose:** Receive plan + failing tests. Dispatch coders in waves. Own all gates from GREEN through REVIEW.

**Model:** opus

**Can:**
- Read: specs, tests, source, project config
- Write: /tmp/ only
- Spawn: coder (max 3 parallel, no file overlap), reviewer-lite, reviewer

**Cannot:**
- Write: src/, tests/, specs/

**Owns gates:**
- GREEN gate (all visible tests pass)
- Wiring gate (`entry-reachability.sh`)
- Visual QA gate (`ui-visual-check.sh --gate`)
- Hidden gate (hidden regression tests)
- Activation gate (`activation-gate.sh`)

**Behavior:**
1. Receive plan + test_map from supervisor
2. Create worktrees for parallel coders: `git worktree add .worktrees/coder-<id> -b coder-<id>`
3. Dispatch coders in waves (max 3 parallel, worktree-isolated)
4. After each wave: run gate sequence (trio-preflight → GREEN → wiring → visual → wave-smoke)
5. After all waves: hidden → activation → spawn reviewer (tier 2 or 3)
6. Merge worktrees sequentially: rebase onto main, fast-forward merge
7. Clean up worktrees: `git worktree remove .worktrees/coder-<id>`
8. Report result to supervisor

**Retry logic:**
- GREEN fail: max 3 retries (re-dispatch coder with failure context)
- Visual fail: max 2 retries (re-dispatch coder with visual findings)
- Hidden fail: promote hidden test to visible, re-dispatch

---

### UI-Designer

**Purpose:** Design system specialist. Multi-phase autonomous visual feedback loop.

**Model:** opus

**Can:**
- Write: DESIGN.md, .interface-design/, /tmp/

**Cannot:**
- Write: src/, tests/

**Phases:** audit → explore → critique → decide → specify → verify

**Tools:**
- `design-sandbox.sh` — Playwright screenshot capture
- `design-grade.sh` — LLM-based scoring
- `design-iterate.sh` — Autonomous generate→screenshot→grade loop

**Scoring:** total = DQ×0.4 + O×0.4 + C×0.15 + F×0.05
- Accept: total ≥ 8.0 AND originality ≥ 9
- Pass gate: total ≥ 7.0, originality ≥ 7, token_fidelity ≥ 8

**Two registers:**
- Brand surface (explainer DESIGN.md)
- Product/dashboard

---

### Coder

**Purpose:** Make failing tests pass. Nothing more.

**Can:**
- Read: test files, existing source, project config
- Write: src/, tests/ (only to fix test setup issues), /tmp/

**Cannot:**
- Read: specs (enforced by briefing — spec paths excluded)
- Write: .agents/knowledge/, STATUS.md, issues/

**Behavior:**
1. Receive briefing from sprint-manager: "Make these tests pass: [paths]" (includes worktree path)
2. Read the failing tests to understand expected behavior
3. Implement minimal code to pass
4. Run tests to verify
5. Write result file, self-close

**Worktree isolation:**
- Each coder gets an isolated git worktree (`.worktrees/coder-<id>`)
- Coders work in parallel without merge conflicts
- After all coders complete, worktrees are merged sequentially

**Key constraint:** Coder briefing contains test file paths and project context, but NEVER the spec. This forces implementation driven by test assertions, not spec prose.

---

### Explorer

**Purpose:** Focused research sub-agent spawned by researcher orchestrator. Investigates a single angle.

**Model:** sonnet

**Can:**
- Read: everything
- Write: /tmp/ (output file specified by researcher)
- Web search, web fetch

**Cannot:**
- Write: src/, tests/, specs/, plans/

**Behavior:**
1. Receive focused research question from researcher
2. Investigate single angle thoroughly
3. Write findings to specified output file
4. Self-close (ephemeral)

---

### Research-Critic

**Purpose:** Adversarial critic with fresh context. Reviews synthesis, finds gaps, challenges assumptions.

**Model:** sonnet

**Can:**
- Read: everything (including explorer outputs)
- Write: /tmp/

**Cannot:**
- Write: src/, tests/, specs/, plans/

**Behavior:**
1. Spawned AFTER all explorers complete
2. Receives synthesized findings (fresh context — no explorer bias)
3. Challenges assumptions, finds gaps, identifies contradictions
4. Writes critique to specified output file
5. Self-close (ephemeral)

---

### Reviewer-Lite

**Purpose:** Fast headless reviewer for Tier 2 complexity (4-7).

**Model:** opus

**Can:**
- Read: everything (spec, source, tests, issues)
- Write: /tmp/ (review reports only)

**Cannot:**
- Write: src/, tests/, issues/, STATUS.md

**Pipeline:** precheck (`review-precheck.sh --diff HEAD`) → 3-section LLM review (Bug Hunter + Security + Design & Quality) → report

**Verdict rules:**
- 🔴 any = REQUEST_CHANGES
- 🟠 + 🟡 = APPROVE_WITH_COMMENTS
- 🟡 only = APPROVE

**Timeout:** 540s (non-blocking — review is advisory, never blocks pipeline)

---

### Reviewer (Full)

**Purpose:** Comprehensive code review for Tier 3 complexity (8+).

**Can:**
- Read: everything (spec, source, tests, issues)
- Write: /tmp/ (review reports only)

**Cannot:**
- Write: src/, tests/, issues/, STATUS.md

**Pipeline:** precheck → 11-section LLM review → signal filtering → feedback capture

**Timeout:** 900s (non-blocking)

**Auto-promote to Tier 3:** paths matching `/auth/`, `/security/`, `/crypto/`, `/api/`, `/schema/`, `/migration`

---

### Data-Analyst

**Purpose:** Autonomous iterative data analysis. Wraps `~/projects/data-analyst-agent/run.py`.

**Model:** sonnet

**Can:**
- Write: /tmp/, output files (specified in task)

**Cannot:**
- Write: src/

**Architecture:** Iterative plan→code→verify loop with sandboxed execution (2GB mem, 120s timeout, blocked patterns). PCS sanity checks. Backtracking (max 3).

**Cost:** ~$0.20-0.50 per analysis

---

### Researcher (ARIA v2 Orchestrator)

**Purpose:** Deep investigation with structured multi-agent output.

**Model:** opus

**Can:**
- Read: everything
- Write: ~/plans/, /tmp/
- Web search, web fetch
- Spawn: explorer (×N parallel), research-critic

**Cannot:**
- Write: src/, tests/, specs/

**Behavior:**
1. Receive research question
2. Spawn 2-4 explorer agents in parallel (each investigates one angle)
3. Wait for all explorers to complete
4. Synthesize findings into unified analysis
5. Spawn research-critic (fresh context, adversarial)
6. Incorporate critique, produce final verdict
7. Write to ~/plans/research-<topic>-verdict.md

---

### Tester

**Purpose:** Write additional tests when test-manager needs help.

**Can:**
- Read: specs, existing tests, source code
- Write: tests/, /tmp/

**Cannot:**
- Write: src/

---

## Agent JSON Template

```json
{
  "name": "<role>",
  "description": "<Role> for <project>",
  "model": "claude-sonnet-4-20250514",
  "prompt": "<role-specific system prompt>",
  "tools": ["read", "write", "grep", "shell", "glob"],
  "resources": ["<context files loaded at start>"]
}
```

## Spawning Pattern

```
# Dispatch
Agent({ prompt: "Make these tests pass: tests/unit/pagination.test.ts", subagent_type: "general-purpose" })
Agent({ prompt: "Own RED gate for PROJ-042", subagent_type: "general-purpose" })
Agent({ prompt: "Review PR #42", subagent_type: "general-purpose" })

# Background dispatch (completion tracking)
Agent({ prompt: "task", run_in_background: true })
```

---

## Resource Loading

Each role loads a minimal set of context files at startup. See `../rules/RESOURCE-SETS.md` for the full allocation table.

**Key rule:** Every agent gets the governance layer (client_rules + amazonq + user-profile + hot-memory). Role-specific resources are added on top — only what that role actually uses.

**Context budget target:** No agent should consume more than 15% of its context window on preloaded resources. For Claude Opus (200K tokens), that's ~30K tokens (~100KB text).