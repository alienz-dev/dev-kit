# Dynamic Workflows — Analysis for dev-kit

> Research date: 2026-06-06
> Claude Code version: 2.1.167 (workflows enabled)
> Feature status: Research preview (released v2.1.154, May 28 2026)

## What Are Dynamic Workflows?

Dynamic workflows are a Claude Code feature that orchestrates many subagents from a **JavaScript script** that Claude writes and the user can rerun. The key architectural shift: **the plan lives in code, not in Claude's context window**.

| | Subagents (current) | Workflows (new) |
|---|---|---|
| Who decides next | Claude, turn by turn | The script |
| Where results live | Claude's context window | Script variables |
| What's repeatable | Worker definition | The orchestration itself |
| Scale | A few per turn | Dozens to hundreds per run |
| Interruption | Restarts the turn | Resumable in same session |

### How to trigger

- **Keyword**: Include `ultracode` in your prompt
- **Effort level**: `/effort ultracode` — every substantive task becomes a workflow
- **Bundled**: `/deep-research <question>`
- **Saved**: `/workflow-name` after saving from `/workflows`

### Script primitives

```javascript
// Meta block (required, pure literal)
export const meta = {
  name: 'my-workflow',
  description: 'What it does',
  phases: [{ title: 'Phase1' }, { title: 'Phase2' }],
}

// Core functions
phase('Phase1')                    // Start a new phase (UI grouping)
log('progress message')            // Emit progress
await agent(prompt, opts)          // Spawn a subagent
await parallel([fn1, fn2, fn3])    // Barrier: run all, await all
await pipeline(items, stage1, ...) // Default: items flow through stages
args                               // Global: input from saved workflow invocation
budget.total / budget.spent()      // Token budget tracking

// Agent options
{
  label: 'display-name',
  phase: 'PhaseName',
  schema: { /* JSON Schema for structured output */ },
  model: 'haiku' | 'sonnet' | 'opus',
  isolation: 'worktree',  // git worktree isolation
  agentType: 'Explore',   // custom subagent type
}
```

### Key patterns

| Pattern | When to use | How |
|---|---|---|
| Pipeline | Default for multi-stage work | `pipeline(items, stage1, stage2)` — no barrier between stages |
| Parallel | Need all results at once | `parallel([fn1, fn2])` — barrier before continuing |
| Adversarial verify | Filter plausible-but-wrong findings | N independent refuters, majority vote |
| Judge panel | Wide solution space | N attempts from different angles, score, synthesize from winner |
| Loop-until-dry | Unknown-size discovery | Keep spawning finders until K consecutive rounds return nothing |
| Multi-modal sweep | One search angle won't find everything | Parallel agents, each searching a different way |

### Limits

- Max 16 concurrent agents per run
- Max 1,000 agents total per run
- No mid-run user input (only permission prompts)
- No direct filesystem/shell from script — agents do I/O
- Resume only within same session
- Research preview — API may change

---

## Mapping to dev-kit

### 1. SDD Phases → Workflow Phases

| SDD Phase | Current Mechanism | Workflow Equivalent |
|---|---|---|
| Pre-flight | Manual checks in /sdd skill | `agent()` with validation schema |
| Plan derivation | Claude reasoning in-context | `agent()` for wave decomposition |
| Test Manager (RED) | Spawned subagent | `agent()` with test schema |
| Trio (sprint) | /trio skill, manual wave dispatch | `pipeline(coders, dispatch, verify)` with `isolation: 'worktree'` |
| Review | 3 parallel spawned agents | `parallel([reviewer1, reviewer2, reviewer3])` |
| Retro | Spawned subagent | `agent()` with retro schema |

**Key constraint**: SDD has interactive phases (grill, spec approval) that need human input. These MUST remain as skills, not workflows. The automated phases (test gen, coder dispatch, review, retro) are ideal workflow candidates.

### 2. TRIO Wave Dispatch → pipeline() with worktree isolation

Current: Sprint-Manager manually creates worktrees, dispatches coders, monitors, merges.

Workflow:
```javascript
const waves = await pipeline(
  groupedIssues,
  // Stage 1: dispatch coders in worktrees
  issue => agent(`Make these failing tests pass: ${issue.tests}`, {
    label: `coder:${issue.id}`,
    phase: `Wave ${issue.wave}`,
    isolation: 'worktree',
  }),
  // Stage 2: verify GREEN gate
  (result, issue) => agent(`Verify all tests pass for ${issue.id}`, {
    label: `verify:${issue.id}`,
    phase: `Wave ${issue.wave}`,
  }),
)
```

This eliminates manual worktree management. The runtime handles creation, isolation, and cleanup.

### 3. Multi-Perspective Review → parallel() with voting

Current: Spawn 3 reviewer subagents, wait for all, manually compare.

Workflow:
```javascript
const verdicts = await parallel(
  DIMENSIONS.map(d => () =>
    agent(`Review via ${d.lens}: ${target}`, { schema: VERDICT })
  )
)
const confirmed = verdicts.filter(v => v.real).length >= 2
```

### 4. ARIA Research → Pipeline with adversarial critic

Current: Researcher skill spawns explorers, then critic.

Workflow:
```javascript
const findings = await pipeline(
  ANGLES,
  angle => agent(`Research: ${angle}`, { schema: FINDINGS }),
  findings => agent(`Adversarially verify: ${JSON.stringify(findings)}`, { schema: VERDICT })
)
```

### 5. Codebase Migrations → Multi-modal sweep + transform

Current: Not well-orchestrated — manual file-by-file changes.

Workflow:
```javascript
const targets = await agent('Find all files needing migration X', { schema: FILE_LIST })
const results = await pipeline(
  targets.files,
  file => agent(`Migrate ${file}`, { isolation: 'worktree' }),
  (result, file) => agent(`Verify ${file} migration`, { schema: VERDICT })
)
```

---

## What Workflows DON'T Replace

| Component | Why it stays |
|---|---|
| gate.sh FSM | Real filesystem I/O, proof files — workflow scripts can't access FS directly |
| Spec system (EARS, templates) | Human-authored documents, not orchestration |
| Agent role definitions | Still define what each agent does — workflows define how they're coordinated |
| Hook scripts (lefthook) | Git-level enforcement, outside Claude's control |
| Interactive skills (/grill, /approve) | Need mid-run human input — not supported in workflows |
| issue-cli | Standalone tool with its own MCP server |

**The right model is hybrid**: workflows for automated orchestration phases, skills for interactive phases, gate.sh for filesystem-level enforcement.

---

## Concrete Workflow Scripts

### 1. /adversarial-review — Multi-angle code review

**When to use**: Any PR or feature branch review where you want confidence from multiple independent perspectives.

**What it does**: Spawns 3 reviewers with different lenses (correctness, security, maintainability), then verifies each finding adversarially.

See: `.claude/workflows/adversarial-review.md`

### 2. /wave-implement — TRIO-style wave dispatch

**When to use**: Implementing a spec with multiple independent issues that can be coded in parallel.

**What it does**: Analyzes spec → generates tests → dispatches coders in waves with worktree isolation → verifies GREEN gate → runs alignment check.

See: `.claude/workflows/wave-implement.md`

### 3. /migration-sweep — Codebase-wide migration

**When to use**: Renaming APIs, updating patterns, migrating frameworks across many files.

**What it does**: Discovers targets → transforms each in isolation → verifies → reports failures.

See: `.claude/workflows/migration-sweep.md`

### 4. /deep-audit — Comprehensive bug hunt

**When to use**: Pre-release audit, security review, or when you suspect issues but don't know where.

**What it does**: Multi-modal sweep (by-container, by-content, by-pattern) → loop-until-dry → adversarial verify → report.

See: `.claude/workflows/deep-audit.md`

### 5. /research-crosscheck — ARIA-style research with verification

**When to use**: Technology comparison, best practices research, architecture decisions.

**What it does**: Fan out searches → cross-check sources → vote on claims → cited report.

See: `.claude/workflows/research-crosscheck.md`

---

## Migration Strategy

### Phase 1: Extract reusable quality workflows (Week 1)
- Create /adversarial-review — replaces manual 3-agent review spawning
- Create /deep-audit — replaces ad-hoc bug hunting
- Test on existing codebase

### Phase 2: Convert automated SDD phases (Week 2-3)
- Create /wave-implement — replaces /trio's sprint stage
- Create /research-crosscheck — replaces ARIA manual orchestration
- Keep /sdd as the interactive orchestrator that calls workflows for automated phases

### Phase 3: Integration (Week 4)
- Update /sdd skill to invoke workflows for phases 3-5 (test gen, sprint, review)
- Update /trio skill to use /wave-implement internally
- Save workflows as commands in .claude/workflows/
- Document the hybrid model

### Phase 4: Advanced patterns (Ongoing)
- Loop-until-dry for unknown-size discovery
- Budget-aware scaling for cost control
- Custom agent types for domain-specific reviewers
- Cross-workflow chaining (workflow calling workflow)

---

## Cost Considerations

Each workflow run spawns many agents. Rough estimates:

| Workflow | Agents spawned | Est. tokens | Use frequency |
|---|---|---|---|
| /adversarial-review | 6-9 (3 reviewers + 3 verifiers) | 50-100k | Every PR |
| /wave-implement | 5-15 (per wave) | 100-300k | Every feature |
| /migration-sweep | N+1 (N files + 1 verifier) | 50-500k | Occasional |
| /deep-audit | 10-30 (sweep + verify loop) | 200-500k | Pre-release |
| /research-crosscheck | 5-10 (searches + cross-check) | 100-200k | Decisions |

**Mitigation**: Use `model: 'haiku'` for discovery/exploration phases, `model: 'sonnet'` for implementation, `model: 'opus'` only for final synthesis/verification.

---

## Recommendation

**Adopt workflows for the automated orchestration layer. Keep skills for interactive phases.**

The dev-kit's biggest pain point — "prompt-enforced boundaries are acknowledged as weak" — is directly addressed by workflows. When orchestration logic lives in a script rather than a prompt, it executes deterministically. Claude's role shifts from orchestrator to worker, which is what the role system already assumes.

The hybrid model:
- **Skills** (/sdd, /trio, /grill, /approve) — interactive, human-in-the-loop
- **Workflows** (/adversarial-review, /wave-implement, /deep-audit) — automated, parallel, resumable
- **gate.sh** — filesystem-level enforcement, proof files
- **Hooks** — git-level enforcement, pre-commit checks

Each layer handles what it's best at. No single mechanism tries to do everything.
