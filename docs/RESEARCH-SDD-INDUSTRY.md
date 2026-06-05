# SDD Industry Research & Dev-Kit Improvement Plan

> Generated 2026-06-04 from deep analysis of the dev-kit codebase + industry survey of
> 15+ open source AI coding projects (800k+ combined stars).

---

## TL;DR

The dev-kit's **methodology is ahead of the industry** (EARS specs, grill sessions, role
separation, hidden tests). The gaps are in **tooling and automation**, not methodology.
The three highest-ROI improvements are: spec-compliance CI checks, worktree-based parallel
execution, and repository mapping.

---

## Part 1: What the Dev-Kit Already Does Well

These are genuine advantages over most open-source AI coding tools:

| Strength | Why It Matters | Industry Comparison |
|----------|---------------|-------------------|
| **EARS notation** | 5 patterns map 1:1 to test cases — eliminates vague specs | Most AI tools have no formal acceptance criteria |
| **Information barrier** (coder never sees spec) | Prevents rubber-stamping — tests are the oracle | No other tool enforces this |
| **Hidden regression tests** | Coder can't game tests they don't know exist | Rare outside regulated industries |
| **Grill sessions** | Adversarial spec review before implementation | Amazon FAQ pattern, Google design doc review |
| **Change Specifications** | Current/Delta/Invariants/Scope for brownfield | Common in aerospace/medical, rare in open source |
| **Role separation with enforcement** | Test-manager owns RED, coder owns GREEN, structural constraints | CrewAI has roles but no structural enforcement |
| **Tiered review with auto-promotion** | 3 tiers, auto-promote for auth/security/crypto paths | Most tools have flat review |
| **Production-scarred safety rules** | Banned phrases, stdin closure hangs, vitest OOM | Real incident traces, not theoretical |

---

## Part 2: Critical Gaps (Internal Analysis)

### 2.1 State Machine Fragmentation — HIGH SEVERITY

Four overlapping state machines with inconsistent vocabularies:

| Source | States | Vocabulary |
|--------|--------|-----------|
| `TRIO.md` | 11 states | open → specced → tests_written → red_verified → implementing → green → ... |
| `gate.sh` + `transitions.json` | 6 stages | plan → test → sprint → review → done → failed |
| `LIFECYCLE.md` | 7 states | backlog → planned → open → in_progress → review → resolved → verified → closed |
| `constitution.yml` | 8 states | open → specced → tests_written → red_verified → implementing → green → reviewing → closed |

**Problem:** An agent trying to advance an issue has no single source of truth. The gate.sh FSM
is the only one that executes code, but it uses different vocabulary than the issue lifecycle.

**Fix:** Consolidate into one state machine. gate.sh should read stages from transitions.json
instead of hardcoding them. Issue lifecycle and pipeline stages should be the same FSM.

### 2.2 Missing Gate Scripts — HIGH SEVERITY

Five documented gate scripts don't exist:

- `entry-reachability.sh` (wiring gate)
- `ui-visual-check.sh` (visual gate — depends on Bitbucket submodule)
- `wave-smoke.sh` (per-wave smoke test)
- `activation-gate.sh` (activation gate)
- `review-precheck.sh` (review pre-check)

**Problem:** An agent following the documented pipeline hits "file not found" at the first
non-GREEN gate. Agents can't distinguish "gate I need to run" from "gate that doesn't exist."

**Fix:** Either implement the missing scripts or simplify the gate sequence to what actually runs.
Mark the visual gate as requiring the Bitbucket submodule.

### 2.3 No Daemon Despite Claims — MEDIUM SEVERITY

PIPELINE-ENFORCEMENT.md describes a daemon with SQLite, role_policies, and stall detection.
No daemon implementation exists. The actual enforcement is gate.sh (bash) + lefthook (pre-commit).

**Fix:** Remove daemon claims from docs, or implement a minimal daemon. Current state — docs
describing non-existent enforcement — is worse than no enforcement docs at all.

### 2.4 No Spec-Test Traceability Enforcement — MEDIUM SEVERITY

The `@spec feature.spec.md §2 Behavior` convention is documented but never parsed. No gate
checks for uncovered spec sections.

**Fix:** Write a grep-based script that parses `@spec` comments and reports uncovered sections.

### 2.5 Gate.sh Doesn't Use transitions.json — LOW SEVERITY

gate.sh hardcodes `("plan" "test" "sprint" "review" "done" "failed")` in `stage_index()`.
Editing transitions.json has no effect on ordering.

**Fix:** Read stages from transitions.json.

### 2.6 Over-Engineering in Governance Layer — LOW SEVERITY

A coder agent loads ~16.5KB of governance (client_rules.md + amazonq.md + user-profile.md +
hot-memory) before reading any code. For a 24KB target context, that's 69% governance.

**Fix:** Deduplicate safety rules (appear in 3+ files). Make amazonq.md optional by default.

---

## Part 3: Industry Best Practices — What to Borrow

### Tier 1: High-ROI, Adopt Soon

#### 3.1 Spec-Compliance CI Checks (from Continue.dev)

**Source:** [Continue.dev](https://github.com/continuedev/continue) — 33.5k stars

**Pattern:** Define checks as markdown files in `.continue/checks/`. Each check is a natural
language prompt that runs on every PR. Green/red status checks in GitHub.

**Apply to dev-kit:**
```
.dev-kit/spec-checks/
  ├── spec-coverage.md      — "Does this PR cover all acceptance criteria in the spec?"
  ├── invariant-preservation.md — "Does this PR preserve all invariants from the Change Spec?"
  └── no-regressions.md     — "Does this PR avoid breaking existing hidden tests?"
```

Run as GitHub Actions. Each check is a prompt that evaluates the diff against the spec.
This closes the biggest gap: automated spec compliance verification.

#### 3.2 Worktree-Based Parallel Execution (from Cline Kanban)

**Source:** [Cline Kanban](https://github.com/cline/kanban) — 62.7k stars (Cline)

**Pattern:** Each task card gets its own git worktree. Agents work in parallel without merge
conflicts. Dependency chains: task A completes → auto-commits → kicks off task B.

**Apply to dev-kit:**
- Each plan step with no dependencies gets a worktree
- Independent steps run in parallel (e.g., "add model" and "add UI component")
- Merge sequentially after all parallel steps complete
- Symlink `node_modules` to avoid slow installs per worktree

This dramatically speeds up multi-file implementations where the current pipeline is sequential.

#### 3.3 Repository Map / Affected Analysis (from Aider + Nx)

**Source:** [Aider](https://github.com/Aider-AI/aider) — 45.7k stars + [Nx](https://github.com/nrwl/nx) — 28.8k stars

**Pattern:** Aider uses tree-sitter to build a code graph that identifies relevant files for a
given task. Nx's `affected` command only processes changed code.

**Apply to dev-kit:**
- When a spec references "the authentication module," auto-identify relevant files
- When a spec changes, only re-run tests on affected code
- Could be a simple `tools/repo-map/` script using tree-sitter or even grep-based heuristics

### Tier 2: Medium-ROI, Adopt Next Quarter

#### 3.4 Sandbox Mode (from Plandex)

**Source:** [Plandex](https://github.com/plandex-ai/plandex) — 15.4k stars

**Pattern:** AI changes accumulate in a sandbox (worktree). Don't touch project files until
explicitly applied. Step-by-step review with rollback.

**Apply to dev-kit:**
- Coder works in a worktree by default
- Reviewer examines the diff before merge
- Rollback = delete the worktree

#### 3.5 Checkpoint/Resume (from Cline Kanban)

**Pattern:** Save conversation state at each pipeline stage. Resume from any checkpoint.

**Apply to dev-kit:**
- gate.sh already tracks stage in `pipeline.json`
- Extend to save agent context (what tests were written, what spec sections covered)
- On resume, skip completed stages

#### 3.6 MCP Bridge for Tools (from Goose)

**Source:** [Goose](https://github.com/aaif-goose/goose) — 46.4k stars

**Pattern:** Expose tools as MCP servers. Any AI agent can use them.

**Apply to dev-kit:**
- Wrap issue-cli, ui-visual-check, explainer as MCP servers
- Any agent (Claude Code, Aider, Cursor) can invoke them
- Makes the dev-kit truly agent-agnostic

#### 3.7 Agent Backstories (from CrewAI)

**Source:** [CrewAI](https://github.com/crewAIInc/crewAI) — 52.8k stars

**Pattern:** Each agent role gets a narrative description of who they are, what they value,
and their personality. More effective than just listing rules.

**Apply to dev-kit:**
```
# Current (rule-based):
- Never modify test files
- Run tests before committing

# With backstory (narrative):
You are a Senior Coder who values correctness over speed. You've been burned
by untested code before — you always run the full test suite before committing,
even when it's slow. You never modify test files because you respect the
test-manager's authority over the RED phase.
```

### Tier 3: Future

#### 3.8 Consensus-Based Review (from CrewAI)

Multiple reviewers independently evaluate code. Consensus determines pass/fail. Useful for
high-stakes changes (auth, crypto, data migration).

#### 3.9 Agent Cards (from Google A2A)

Standardized capability descriptions for each agent. Enables interoperability with other
agent systems. JSON-RPC 2.0 over HTTP.

#### 3.10 Visual Regression (from Playwright + Chromatic)

Automated screenshot comparison for UI acceptance criteria. The dev-kit defines visual
criteria but has no automated enforcement.

---

## Part 4: Borrowable Ideas — Specific Projects

| # | Project | Stars | Idea to Borrow | Effort |
|---|---------|-------|---------------|--------|
| 1 | [Continue.dev](https://github.com/continuedev/continue) | 33.5k | Spec-compliance CI checks (markdown → GitHub status) | Low |
| 2 | [Cline Kanban](https://github.com/cline/kanban) | 62.7k | Worktree-per-task parallelism | Medium |
| 3 | [Aider](https://github.com/Aider-AI/aider) | 45.7k | Repository map (tree-sitter code graph) | Medium |
| 4 | [Plandex](https://github.com/plandex-ai/plandex) | 15.4k | Cumulative diff sandbox | Medium |
| 5 | [CrewAI](https://github.com/crewAIInc/crewAI) | 52.8k | Agent backstories + consensus review | Low |
| 6 | [Goose](https://github.com/aaif-goose/goose) | 46.4k | MCP extension system | Medium |
| 7 | [OpenHands](https://github.com/All-Hands-AI/OpenHands) | 46.4k | Theory-of-Mind for spec interpretation | High |
| 8 | [Nx](https://github.com/nrwl/nx) | 28.8k | Affected analysis (only process changed code) | Low |
| 9 | [Google A2A](https://github.com/a2aproject/A2A) | — | Agent Cards for capability discovery | High |
| 10 | [Specmatic](https://github.com/specmatic/specmatic) | 379 | Contract-first API spec compliance | Medium |

---

## Part 5: Unsolved Industry Problems (Context)

These are problems nobody has solved well — the dev-kit shouldn't try to solve them alone,
but should be aware of them:

1. **Spec compliance verification** — No tool automatically verifies AI code matches a spec
2. **Context window limits** — Even 2M tokens isn't enough for large codebases
3. **Agent hallucination** — AI still generates off-spec code
4. **Multi-agent merge conflicts** — Parallel agents produce inconsistent changes
5. **Long-running task management** — Checkpointing and resume are immature
6. **Cost optimization** — AI coding is expensive at scale
7. **Security/trust** — Running AI-generated code is inherently risky

---

## Part 6: Recommended Implementation Roadmap

### Phase 1 — Fix Foundations (this sprint)

| # | Action | Source | Impact |
|---|--------|--------|--------|
| 1 | Consolidate state machines into single source of truth | Internal | Eliminates agent confusion |
| 2 | Implement or remove missing gate scripts | Internal | Pipeline actually works end-to-end |
| 3 | Add `gate.sh retreat` for backward transitions | Internal | Enables rework loops |
| 4 | Add spec-test traceability checker | Internal + Continue.dev | Closes coverage gaps |
| 5 | Remove daemon claims from docs (or implement minimal) | Internal | Honest documentation |

### Phase 2 — Borrow from Industry (next quarter)

| # | Action | Source | Impact |
|---|--------|--------|--------|
| 6 | Add spec-compliance CI checks | Continue.dev | Automated spec verification |
| 7 | Deduplicate safety rules | Internal | Recover 5-8KB per agent context |
| 8 | Add agent backstories to role definitions | CrewAI | More effective agent behavior |
| 9 | Add affected analysis to pipeline | Nx | Skip unaffected stages |
| 10 | Lower ARIA v2 threshold (8+ for full, 6-7 for lightweight) | Internal | Less over-research |

### Phase 3 — Advanced (future)

| # | Action | Source | Impact |
|---|--------|--------|--------|
| 11 | Worktree-based parallel execution | Cline Kanban | 2-4x speedup on multi-file work |
| 12 | Sandbox mode (coder works in worktree) | Plandex | Safer code generation |
| 13 | MCP bridge for tools | Goose | True agent-agnosticism |
| 14 | Repository map tool | Aider | Better context for planners |
| 15 | Consensus-based review | CrewAI | Higher review quality |

---

## Sources

- Internal: Full analysis of dev-kit repo (workflow/, agents/, quality/, templates/, tools/, docs/)
- [Continue.dev](https://github.com/continuedev/continue) — AI checks in CI
- [Cline Kanban](https://github.com/cline/kanban) — Worktree parallelism
- [Aider](https://github.com/Aider-AI/aider) — Repository map
- [Plandex](https://github.com/plandex-ai/plandex) — Sandbox mode
- [CrewAI](https://github.com/crewAIInc/crewAI) — Role-based agents
- [Goose](https://github.com/aaif-goose/goose) — MCP extensions
- [OpenHands](https://github.com/All-Hands-AI/OpenHands) — Theory of Mind
- [Google A2A](https://github.com/a2aproject/A2A) — Agent-to-Agent protocol
- [Nx](https://github.com/nrwl/nx) — Affected analysis
- [Agent Protocol](https://github.com/AI-Engineer-Foundation/agent-protocol) — Common agent interface
- [Specmatic](https://github.com/specmatic/specmatic) — Contract-first testing
