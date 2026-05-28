# Data Analyst Agent

Autonomous iterative data analysis with sandboxed execution and statistical validation.

## Architecture

```
profiler → iterative loop (max 15 iterations):
  planner → coder → executor (sandboxed) → verifier (LLM judge) → router
```

The router decides: add next step, backtrack (max 3), or complete.

## 6 Agent Roles (Prompt Files)

| Role | Purpose |
|------|---------|
| Profiler | Initial data inspection, schema detection, summary stats |
| Planner | Decides next analysis step based on findings so far |
| Coder | Writes Python code for the planned step |
| Executor | Runs code in sandbox, captures output |
| Verifier | LLM judge — validates output makes sense |
| Router | Decides: proceed, backtrack, or complete |

## Sandboxed Execution

| Constraint | Value |
|-----------|-------|
| Memory | 2GB via `resource.setrlimit` |
| Timeout | 120s per execution |
| Stdout cap | 10KB |
| Blocked patterns | `os.system`, `subprocess`, `socket`, `shutil.rmtree` |

Code is executed in an isolated Python process with restricted imports and resource limits.

## PCS Sanity Checks

Post-analysis statistical validation:

| Check | Method | Purpose |
|-------|--------|---------|
| Subsample | Run on 80% of data | Stability — results shouldn't change dramatically |
| Noise | Add 5% random noise | Robustness — results shouldn't be fragile |
| Null shuffle | Shuffle target variable | Falsifiability — results should disappear with random data |

**Verdicts:**
- `TRUST` — All checks pass, results are reliable
- `VERIFY_MANUALLY` — Some checks marginal, human review recommended
- `LIKELY_SPURIOUS` — Null shuffle still shows effect, likely overfitting

## Integration

```bash
# Kiro agent wraps the CLI tool
kiro-ctl spawn data-analyst "Analyze churn patterns in users.csv" \
  --subscribe --workdir ~/projects/analytics
```

The kiro agent calls `~/projects/data-analyst-agent/run.py` with the task description.

## When to Use

| Scenario | Use Data Analyst? |
|----------|-------------------|
| Complex multi-step analysis | ✅ Yes |
| Simple pandas one-liner | ❌ No — just write the code |
| Visualization only | ❌ No — use matplotlib directly |
| SQL query | ❌ No — use SQL directly |
| Statistical modeling with validation | ✅ Yes |

## Cost

~$0.20-0.50 per analysis (sonnet model, 5-15 iterations typical).

## Backtracking

When the verifier rejects an output or the router detects a dead end:
1. Undo the last N steps (max 3 backtracks per analysis)
2. Planner generates alternative approach
3. Resume from the last good state

This prevents the agent from getting stuck in unproductive loops.
