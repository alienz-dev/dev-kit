# Agent Safety Rules

Rules extracted from real production failures. Every rule traces to an incident.

## Execution Safety

### stdin Closure (CRITICAL)
**Problem:** Agent CLI spawns child processes with `stdin(Stdio::inherit())`. Any command that reads stdin hangs the entire session with no recovery.

**Rule:** Append `< /dev/null` to every shell command execution.

```bash
# WRONG — will hang if command reads stdin
npm test

# RIGHT
npm test < /dev/null
```

### Background Server Pattern (CRITICAL)
**Problem:** TUI mode captures stdout to temp files. Backgrounded servers that inherit the pipe fd can block the agent CLI on EOF.

**Rule:** Use a dedicated launcher for background processes:
```bash
# Safe pattern
start-server.sh <port> /tmp/<name>.log [--wait N] -- <command>

# Or manual (capture stdout to file)
cmd > /tmp/log 2>&1 < /dev/null &
```

### Memory Limits
**Problem:** `tsc --noEmit` on large projects needs 8GB+ and OOMs.

**Rule:** Always use incremental typecheck with memory cap:
```bash
node --max-old-space-size=4096 ./node_modules/.bin/tsc --noEmit --incremental
# Or: npm run typecheck (which should be configured to do the above)
```

### Test Runner Pool (CRITICAL)
**Problem:** `pool: 'forks'` in vitest spawns workers that survive parent exit — orphans at ~2GB each.

**Rule:** Always use `pool: 'threads'` in vitest config. Never switch to forks for "flaky test" fixes — fix test isolation instead.

---

## Verification Discipline

### Verify Before Verdict
After applying any fix, run a concrete verification step and observe the actual result before claiming it works.

Gate:
1. IDENTIFY what command proves the claim
2. RUN it fresh
3. READ the full output
4. VERIFY it confirms the fix

**Banned phrases without evidence:** "should work now", "fixed", "done"

### Auto-Verify
After implementation, run verification yourself immediately. Don't suggest commands for the user to run.

### Confirm Hypothesis Before Fix
Before writing any fix, add a temporary diagnostic at the suspected root cause. Run reproduction. If diagnostic doesn't confirm hypothesis, do NOT implement the fix.

---

## Anti-Destruction

### Never Discard Uncommitted Work
When `git status` shows modified/untracked files you didn't create:
1. Show the user the file list
2. Ask "keep, stash, or discard?"
3. If discarding: `git stash push -m "agent-extra" -- <files>`

### Scope Discipline
Do not refactor adjacent code, add unrequested error handling, "improve" naming in files you're touching, or close resources you don't own. Only modify files explicitly in scope.

---

## Anti-Hallucination

### Zero Knowledge Assumption
Every session starts with zero project knowledge. Before acting:
- Read project context files (STATUS.md, NEXT-SESSION.md, CONTEXT.md)
- Read the specific files you plan to modify
- The cost of reading is always less than the cost of a wrong assumption

### Cross-Reference Before Acting
LLMs hallucinate function signatures, invent API parameters, misremember file paths. Compensate:
- Read the actual file/function before calling or modifying it
- Run code after writing it
- Check actual docs for external APIs

---

## Context Discipline

### Context = RAM, Not Log
- Don't dump entire files when you need 10 lines
- Don't keep failed approaches in context — summarize the lesson
- When reading: target specific sections
- When briefing sub-agents: inline only what they need

### Don't Compress Meaning
Preserve: descriptive names, full error messages, inline code snippets, git commit reasoning.
Eliminate: boilerplate, ceremony, redundant imports, structural tokens with zero information.

### Failed Attempts Leave Debris
If a command fails, the environment is now different. Before retrying:
1. Check what state the failed attempt left behind
2. Clean up or roll back
3. Only then retry

---

## Autonomous Problem-Solving

### Solve Before Asking
When a task hits a blocker that you have the tools to resolve, attempt to resolve it autonomously. Escalate only after exhausting your own capabilities.

### Two-Failure Rule
If an approach has failed twice, diagnose the root cause rather than making incremental patches. Explain what went wrong and try a fundamentally different approach.
