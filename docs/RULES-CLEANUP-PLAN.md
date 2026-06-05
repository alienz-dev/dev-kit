# Rules Cleanup Plan

> What to remove, consolidate, or migrate in the dev-kit's agent rules.
> Generated 2026-06-04 from repo scan + Claude Code features research.

## Summary

| Category | Files | Action |
|----------|-------|--------|
| REDUNDANT | 2 files | Delete |
| CONSOLIDATE | 3 files → 1 | Merge into single safety rules |
| ENRICH | 2 agent defs | Merge rule content into agent templates |
| UPDATE | 3 docs | Fix inaccurate enforcement claims |
| MIGRATE TO HOOKS | 5 rules | Move from prompt-based to hook-based enforcement |

## Priority 1: Delete Redundant Files

### `agents/rules/SAFETY.md` — DELETE
- 125 lines, duplicates `client_rules.md` (85 lines) and `.claude/rules/safety.md` (23 lines)
- Three safety files covering the same domain wastes context budget
- **Before deleting:** merge unique technical content (stdin closure pattern, background server pattern) into consolidated safety file

### `agents/rules/delegation-slim.md` — DELETE
- 46 lines, agent selection table duplicates `.claude/agents/*.md` descriptions
- Claude Code routes to agents based on `description:` frontmatter — the selection table is redundant
- The `Agent()` dispatch syntax is natively known
- **Before deleting:** verify agent descriptions cover all routing cases

## Priority 2: Consolidate Safety Rules

### Merge 3 files → 1: `.claude/rules/safety.md`

**Source files:**
- `agents/rules/SAFETY.md` (125 lines) — most technical, incident-derived
- `agents/rules/client_rules.md` (85 lines) — governance layer, user profile
- `templates/common/claude-code/rules/safety.md` (23 lines) — condensed, Claude Code format

**Target:** `.claude/rules/safety.md` (global, no `paths:` — loads at session start)

**Content to include:**
- Verification protocol (run-then-claim, auto-verify, confirm-hypothesis)
- Anti-destruction (scope discipline, no uncommitted work discard)
- Anti-hallucination (zero-knowledge assumption, cross-reference)
- Forbidden commands (from SAFETY.md landmines)
- Context discipline (RAM not log, don't compress meaning)
- User profile compliance (from client_rules.md)
- Tool-specific safety (vitest forks, tsc memory, stdin closure)

**Content to exclude (already in Claude Code):**
- Generic "don't fabricate" — Claude Code's system prompt handles this
- Generic "be careful" — too vague to be useful

**Estimated:** ~80-100 lines consolidated

## Priority 3: Enrich Agent Definitions

### Merge `adversarial-reviewer.md` → `.claude/agents/reviewer.md`
- Current reviewer.md: 31 lines (simple workflow)
- Adversarial reviewer: 95 lines (edge-case checklists, severity levels, "invert the question")
- Merged result: self-contained reviewer agent with adversarial protocol
- Delete `agents/rules/adversarial-reviewer.md` after merge

### Merge `coder-workflow.md` → `.claude/agents/coder.md`
- Current coder.md: 33 lines (basic workflow)
- Coder workflow: 100 lines (six-phase loop, debugging rules, deviation protocol)
- Unique content to merge: six-phase loop, debugging protocol, deviation logging, context exhaustion
- Remove from coder-workflow.md: style/testing sections that duplicate `.claude/rules/code-style.md` and `testing.md`
- Delete `agents/rules/coder-workflow.md` after merge

## Priority 4: Update Documentation

### `agents/roles/ROLES.md`
- Remove `Agent JSON Template` section (deniedPaths is not a Claude Code feature)
- Replace with: enforcement uses `permissionMode` and `settings.json` permissions
- Update dispatch rules to reference Claude Code's Agent() tool
- Keep role definitions as documentation

### `workflow/pipeline/PIPELINE-ENFORCEMENT.md`
- Note that deniedPaths is not a Claude Code native feature
- Closest equivalents: `permissionMode: plan` (read-only) and `settings.json` deny patterns
- Update three-tier model to reflect hooks as a new tier

### `agents/rules/RESOURCE-SETS.md`
- Reflect Claude Code's actual loading: `.claude/rules/*.md` with `paths:`, agent defs, CLAUDE.md
- Remove custom resource-set loading descriptions
- Update context budget targets

## Priority 5: Migrate to Hooks

### Critical Safety Rules → PreToolUse Hooks

| Rule | Hook |
|------|------|
| Never `rm -rf` | `PreToolUse` hook: `if: "Bash(rm *)"`, exit 2 |
| Never `git push --force` | `PreToolUse` hook: `if: "Bash(git push --force*)"`, exit 2 |
| Never `pool: 'forks'` in vitest | `PreToolUse` hook: `if: "Bash(*--pool forks*)"`, exit 2 |
| Never `git reset --hard` | `PreToolUse` hook: `if: "Bash(git reset --hard*)"`, exit 2 |
| Never `git clean` | `PreToolUse` hook: `if: "Bash(git clean*)"`, exit 2 |

### Pipeline Enforcement → TaskCompleted Hook

```json
{
  "hooks": {
    "TaskCompleted": [{
      "type": "command",
      "command": ".claude/hooks/validate-pipeline-stage.sh"
    }]
  }
}
```

The hook script checks `gate.sh status` and blocks completion if the pipeline
is at the wrong stage.

### Test Verification → Stop Hook

```json
{
  "hooks": {
    "Stop": [{
      "type": "command",
      "command": ".claude/hooks/verify-tests-pass.sh"
    }]
  }
}
```

The hook runs tests and blocks stop (exit 2) if tests fail.

## Files to Create

### `.claude/hooks/block-dangerous.sh`
Blocks dangerous commands via PreToolUse hook. Receives JSON on stdin with tool name and args.

### `.claude/hooks/validate-pipeline-stage.sh`
Checks pipeline stage before allowing task completion. Reads `.pipeline/state.json`.

### `.claude/hooks/verify-tests-pass.sh`
Runs tests before allowing Claude to stop. Exit 2 if tests fail.

## Effort Estimate

| Change | Effort | Impact |
|--------|--------|--------|
| Delete SAFETY.md + delegation-slim.md | 30 min | -170 lines |
| Consolidate 3 safety files → 1 | 2-3 hours | Single source of truth |
| Merge adversarial-reviewer → reviewer.md | 1 hour | Self-contained reviewer |
| Merge coder-workflow → coder.md | 2 hours | Self-contained coder |
| Update ROLES.md, PIPELINE-ENFORCEMENT.md | 1 hour | Accurate docs |
| Update RESOURCE-SETS.md | 30 min | Accurate docs |
| Create 3 hook scripts | 2 hours | Structural enforcement |
| Update scaffold.sh settings.json | 30 min | Hooks in new projects |
| **Total** | **~10 hours** | |

## After Cleanup

```
agents/rules/
├── planner-core.md           (KEEP — methodology, unique)
├── wave-execution.md         (KEEP — methodology, unique)
├── grill-checklist.md        (KEEP — methodology, unique)
├── implementation-briefing.md (KEEP — methodology, unique)
└── client_rules.md           (DELETED — consolidated into .claude/rules/safety.md)

.claude/
├── rules/
│   ├── safety.md             (NEW — consolidated from 3 files)
│   ├── code-style.md         (KEEP)
│   └── testing.md            (KEEP)
├── agents/
│   ├── coder.md              (ENRICHED — merged coder-workflow)
│   ├── reviewer.md           (ENRICHED — merged adversarial-reviewer)
│   ├── researcher.md         (KEEP)
│   ├── explorer.md           (KEEP)
│   └── test-manager.md       (KEEP)
├── hooks/
│   ├── block-dangerous.sh    (NEW — PreToolUse enforcement)
│   ├── validate-pipeline.sh  (NEW — TaskCompleted enforcement)
│   └── verify-tests.sh       (NEW — Stop enforcement)
└── settings.json             (UPDATED — hooks configured)
```

## Anti-Patterns

- ❌ **Keep duplicate safety files** — wastes context, creates update drift
- ❌ **Prompt-based enforcement for critical rules** — hooks are structural, prompts are advisory
- ❌ **deniedPaths references** — not a Claude Code feature, confusing
- ❌ **Agent JSON template** — not applicable to Claude Code
