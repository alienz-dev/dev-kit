# Dynamic Workflows — When and How to Use Them

> Comprehensive guide based on deep research (2026-06-06)
> Claude Code v2.1.167, workflows enabled, research preview

---

## Decision Framework

```
Is the task...
  Simple, single-file, clear scope?
    → Just ask Claude directly (no orchestration)

  A repeatable procedure you run often?
    → Use a Skill (instructions Claude follows)

  Needs a few delegated side tasks?
    → Use Subagents (Claude orchestrates turn-by-turn)

  Needs workers to communicate/argue with each other?
    → Use Agent Teams (experimental, 7x token cost)

  Needs 10+ agents, parallel fan-out, rerunnable, quality verification?
    → Use a Dynamic Workflow
```

### The One Question That Matters

**Who holds the plan?**

| Answer | Use |
|--------|-----|
| Claude (turn-by-turn) | Subagents or Skills |
| A lead agent (turn-by-turn) | Agent Teams |
| A script (deterministic) | **Workflows** |

When the plan lives in Claude's context, every intermediate result eats context window. When the plan lives in a script, only the final answer lands in context. This is the fundamental architectural difference.

---

## When TO Use Workflows

### 1. Codebase-wide sweeps (10+ files)

```
ultracode: audit every API endpoint under src/routes/ for missing auth checks
```

**Why workflow**: The same check applied to N files. `parallel()` fans out, results converge. A subagent approach would require Claude to coordinate N turns manually.

### 2. Multi-file migrations

```
ultracode: migrate all TypeScript files from interface to type aliases
```

**Why workflow**: `pipeline(files, transform, verify)` — each file flows through stages independently. Worktree isolation prevents conflicts. Resumable if interrupted.

### 3. Cross-checked research

```
/deep-research What are the trade-offs between Drizzle and Prisma in 2026?
```

**Why workflow**: Multiple search angles, source cross-checking, claim voting. The bundled `/deep-research` workflow does exactly this.

### 4. Adversarial code review

```
ultracode: review the authentication module for bugs, security issues, and maintainability
```

**Why workflow**: 3 independent reviewers with different lenses, then adversarial verification of each finding. Quality pattern that's hard to coordinate manually.

### 5. Multi-angle planning

```
ultracode: draft an implementation plan for the new caching layer from 3 different angles
```

**Why workflow**: Judge panel pattern — N independent attempts, scored by judges, synthesized from the winner.

### 6. Large-scale test generation

```
ultracode: generate comprehensive tests for all utility functions in src/utils/
```

**Why workflow**: Each function gets its own agent. Parallel generation, then verification that tests actually fail before implementation (RED gate).

---

## When NOT to Use Workflows

### 1. Simple tasks

> "If you could describe the diff in one sentence, skip the plan."

Single file, clear scope, obvious changes — just ask Claude directly. The workflow overhead (script writing, agent spawning, approval flow) costs more than the task itself.

### 2. Sequential tasks with many dependencies

If stage B needs ALL of stage A's output, and stage C needs ALL of stage B's — you have a pipeline with barriers at every stage. That's just sequential execution with extra overhead. Use a single session or subagents.

### 3. Same-file edits without worktree isolation

Multiple agents editing the same file will conflict. Use `isolation: 'worktree'` or don't use a workflow.

### 4. Interactive tasks needing human input

Workflows have **no mid-run user input**. If you need human approval between stages (like the grill phase in SDD), split into separate workflows or use skills.

### 5. Tasks where intermediate results must be in Claude's context

If Claude needs to see stage 1's output to decide what stage 2 should do — that's turn-by-turn orchestration, not scripted orchestration. Use subagents.

---

## The Six Orchestration Topologies

### 1. MapReduce

**Shape**: split → map in parallel → reduce

**When**: Same check across many items (audit 500 files, validate 100 configs)

```javascript
phase('Map')
const results = await parallel(
  items.map(item => () => agent(`Check ${item}`, { schema: CHECK }))
)
phase('Reduce')
return await agent(`Summarize: ${JSON.stringify(results)}`)
```

### 2. Pipeline

**Shape**: stage → stage → stage, per item, no barrier

**When**: Each item needs sequential processing (transform → test → fix), but items are independent

```javascript
const results = await pipeline(
  items,
  item => agent(`Transform ${item}`),
  (result, item) => agent(`Verify ${result} for ${item}`),
)
```

**Key**: Item A can be in stage 3 while item B is still in stage 1. Wall-clock = slowest single-item chain, not sum.

### 3. Adversarial

**Shape**: propose → critique → fix → re-verify

**When**: Anything that must be correct, not just plausible

```javascript
const proposal = await agent('Propose solution', { schema: SOLUTION })
const critiques = await parallel(
  CRITICS.map(c => () => agent(`${c.prompt}: ${JSON.stringify(proposal)}`, { schema: VERDICT }))
)
const confirmed = critiques.filter(v => v.approved).length >= 2
```

### 4. Consensus

**Shape**: many evaluators → weighted vote

**When**: Uncertain facts, research, judgment calls

```javascript
const votes = await parallel(
  Array(5).fill(null).map(() => () => agent(question, { schema: VOTE }))
)
const consensus = majorityVote(votes)
```

### 5. Tree Search

**Shape**: expand → score → prune → backtrack

**When**: Root-cause hunts, branching exploration

```javascript
let candidates = initialHypotheses
while (candidates.length > 1) {
  const scored = await parallel(
    candidates.map(h => () => agent(`Test hypothesis: ${h}`, { schema: SCORE }))
  )
  candidates = scored.filter(s => s.score > THRESHOLD).map(s => s.hypothesis)
}
```

### 6. Hybrid

**Shape**: The above, composed

**When**: Real features with several phases. Most useful workflows combine topologies.

---

## Script Patterns

### Pattern 1: Args handling (REQUIRED)

**Bug workaround**: `args` arrives as a serialized JSON string, not an object. Always parse it.

```javascript
// At the top of every workflow script:
const _args = typeof args === 'string' ? JSON.parse(args) : (args || {})
const target = _args.target || 'default value'
```

### Pattern 2: Model routing for cost optimization

```javascript
// Discovery/exploration → cheap model
const files = await agent('List all files', { model: 'haiku' })

// Analysis/implementation → balanced model
const analysis = await agent('Analyze in detail', { model: 'sonnet' })

// Final synthesis → strongest model
const verdict = await agent('Make final decision', { model: 'opus' })
```

**Note**: Model override may not work in all environments (tested: v2.1.167 ignores it). Session model is the fallback.

### Pattern 3: Structured output with schema

Always use `schema` for agent output. It:
- Forces valid JSON (no parsing needed)
- Reduces token usage (structured vs verbose free-text)
- Enables downstream logic (filtering, sorting, comparing)

```javascript
const result = await agent('Analyze this', {
  schema: {
    type: 'object',
    properties: {
      findings: { type: 'array', items: { type: 'object', properties: { ... } } },
      confidence: { type: 'number' },
    },
    required: ['findings'],
  },
})
```

### Pattern 4: Loop-until-dry

For unknown-size discovery. Keep spawning finders until consecutive rounds return nothing.

```javascript
const seen = new Set()
let dry = 0
while (dry < 2) {
  const found = await agent('Find bugs', { schema: BUGS })
  const fresh = found.bugs.filter(b => !seen.has(b.id))
  if (!fresh.length) { dry++; continue }
  dry = 0
  fresh.forEach(b => seen.add(b.id))
  confirmed.push(...fresh)
}
```

### Pattern 5: Budget-aware scaling

```javascript
const results = []
while (budget.remaining() > 50_000) {
  const batch = await agent('Process next batch', { schema: RESULTS })
  results.push(...batch.items)
  log(`${results.length} processed, ${Math.round(budget.remaining()/1000)}k remaining`)
}
```

### Pattern 6: Error handling in pipeline

Stages that throw drop the item to `null`. Filter before using results.

```javascript
const results = await pipeline(items, stage1, stage2)
const successful = results.filter(Boolean)  // Drop failed items
```

### Pattern 7: Worktree isolation for parallel edits

```javascript
await parallel(
  files.map(f => () => agent(`Edit ${f}`, { isolation: 'worktree' }))
)
```

Each agent gets its own git branch. No file conflicts.

---

## Cost Management

### Token economics

From Anthropic's research: **Multi-agent systems use ~15x more tokens than chats.** Token usage alone explains 80% of performance variance.

### Cost estimates per workflow type

| Workflow | Agents | Est. tokens | Frequency |
|----------|--------|-------------|-----------|
| Adversarial review | 6-9 | 50-100k | Every PR |
| Wave implement | 5-15 | 100-300k | Every feature |
| Migration sweep | N+1 | 50-500k | Occasional |
| Deep audit | 10-30 | 200-500k | Pre-release |
| Research crosscheck | 5-10 | 100-200k | Decisions |

### Cost reduction strategies

1. **Run on a small slice first** — one directory instead of the whole repo
2. **Use structured output** (`schema`) — reduces verbose free-text responses
3. **Filter early** — deduplicate before expensive verification
4. **Use `/workflows` to monitor** — stop if costs escalate
5. **Set budget limits** — `budget.total` caps the run

### When to use /effort ultracode vs explicit workflows

| Mode | When | Cost |
|------|------|------|
| `/effort high` | Routine work, no workflow needed | Baseline |
| `ultracode: <task>` | One specific task needs a workflow | One workflow's cost |
| `/effort ultracode` | Session where every task warrants a workflow | Multiple workflows |

---

## Integration with dev-kit

### What stays as skills (interactive, human-in-the-loop)

| Skill | Why it stays |
|-------|-------------|
| /sdd | Interactive phases (grill, approval) need human input |
| /trio | Sprint-Manager needs to make turn-by-turn decisions |
| /grill | Interactive design interview — no mid-run input in workflows |
| /approve | Human approval gate |

### What becomes workflows (automated, parallel, resumable)

| Workflow | Replaces |
|----------|----------|
| /adversarial-review | Manual 3-agent review spawning |
| /wave-implement | /trio's automated sprint stages |
| /deep-audit | Ad-hoc bug hunting |
| /research-crosscheck | ARIA manual orchestration |
| /migration-sweep | Manual file-by-file migration |

### The hybrid model

```
Human request
  → /sdd skill (interactive: grill, spec approval)
    → Workflow: /wave-implement (automated: test gen, coder dispatch, verify)
      → gate.sh (filesystem: proof files, state transitions)
        → Hooks (git-level: pre-commit checks)
```

Each layer handles what it's best at. No single mechanism tries to do everything.

---

## Known Bugs and Workarounds

### Bug 1: Args serialization (verified 2026-06-06)

**Symptom**: `args` arrives as a JSON string, not a parsed object.
**Workaround**: `const _args = typeof args === 'string' ? JSON.parse(args) : (args || {})`
**Impact**: Affects all parameterized workflows and nested workflow args.

### Bug 2: Model override ignored (verified 2026-06-06)

**Symptom**: `model: 'haiku'` in `agent()` has no effect — agents use session model.
**Workaround**: Set session model via `/model` before running workflow.
**Impact**: Cost optimization via per-agent model routing doesn't work.

### Not a bug: No mid-run user input

**By design**: Workflows run in the background. Only permission prompts can pause them.
**Workaround**: Split interactive workflows into multiple runs, or use skills for interactive phases.

---

## Debugging Workflows

### During execution

```
/workflows
```

| Key | Action |
|-----|--------|
| ↑/↓ | Select phase or agent |
| Enter | Drill into phase → agent |
| Esc | Back out |
| p | Pause/resume |
| x | Stop agent or workflow |
| r | Restart agent |
| s | Save script as command |

### After execution

Every run writes its script to `~/.claude/projects/`. Read it, diff against previous runs, edit and relaunch.

### Resume

Stopped runs resume within the same session. Completed agents return cached results; rest run live.

```javascript
// Resume from a prior run
Workflow({ scriptPath: '...', resumeFromRunId: 'wf_...' })
```

---

## Quick Reference

### Trigger methods

| Method | Example | Scope |
|--------|---------|-------|
| Keyword | `ultracode: audit auth` | One task |
| Effort | `/effort ultracode` | Session |
| Bundled | `/deep-research question` | One task |
| Saved | `/workflow-name args` | Reusable |

### Script primitives

```javascript
export const meta = { name, description, phases }  // Required, pure literal
phase('Title')                                        // UI grouping
log('message')                                        // Progress
await agent(prompt, opts)                             // Spawn worker
await parallel([fn1, fn2])                            // Barrier
await pipeline(items, stage1, stage2)                 // Streaming
args                                                  // Input (parse it!)
budget.total / budget.spent() / budget.remaining()    // Token tracking
await workflow({scriptPath}, childArgs)               // Nest (1 level)
```

### Agent options

```javascript
{
  label: 'display-name',          // UI label
  phase: 'PhaseName',             // Assign to phase
  schema: { type: 'object', ... }, // Structured output
  model: 'haiku',                 // Model override (may not work)
  isolation: 'worktree',          // Git worktree
  agentType: 'Explore',           // Custom subagent type
}
```

---

## Sources

- https://docs.anthropic.com/en/docs/claude-code/workflows
- https://docs.anthropic.com/en/docs/claude-code/sub-agents
- https://docs.anthropic.com/en/docs/claude-code/agent-teams
- https://anthropic.com/engineering/multi-agent-research-system
- https://anthropic.com/engineering/effective-harnesses-for-long-running-agents
- https://github.com/Suraj1235/open-dynamic-workflows (community)
- https://github.com/QuintinShaw/pi-dynamic-workflows (community)
- Live testing on Claude Code v2.1.167 (2026-06-06)
