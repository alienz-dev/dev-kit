# Claude Code Features for SDD

> How Claude Code's native features map to the dev-kit's SDD/TRIO methodology.
> Generated 2026-06-04 from research + live system analysis.

## TL;DR

Claude Code has **hooks** (25+ events, 5 handler types) that enforce rules regardless of what
Claude decides. The dev-kit's prompt-based rules are advisory — hooks are structural. Migrate
critical safety rules to hooks; keep methodology content as prompts.

---

## 1. Task Management (Todo Lists)

**What Claude Code has:**
- `TaskCreate` / `TaskUpdate` / `TaskList` / `TaskGet` tools
- Tasks have: subject, description, activeForm, status (pending/in_progress/completed)
- Dependencies: `blocks` and `blockedBy` arrays
- Persist across context compactions
- `Ctrl+T` toggles task list view
- Hooks: `TaskCreated` (exit 2 blocks creation), `TaskCompleted` (exit 2 blocks completion)
- Agent teams: shared task list, self-claiming, `SendMessage` for coordination

**What dev-kit has:**
- `gate.sh` — file-based FSM with stages (plan→test→sprint→review→done/failed)
- `pipeline.json` — state tracking with history
- No dependency tracking between tasks

**Mapping:**

| Dev-kit | Claude Code | Gap |
|---------|------------|-----|
| Pipeline stages (plan/test/sprint/review) | Tasks with dependencies | No built-in FSM |
| `gate.sh advance <signal>` | `TaskCompleted` hook (exit 2 blocks) | Hook can enforce transitions |
| `gate.sh check <stage>` | `TaskList` + filter by status | No direct stage check |
| Pipeline state file | `~/.claude/tasks/{id}/` JSON | Different format |

**Recommendation:** Model pipeline stages as tasks with dependency chains:
```
Task 1: "Write spec" (no deps)
Task 2: "Write failing tests" (blockedBy: [1])
Task 3: "Implement to pass tests" (blockedBy: [2])
Task 4: "Verify + review" (blockedBy: [3])
```
Use `TaskCompleted` hook to enforce stage transitions. Keep `gate.sh` for
explicit FSM control when needed.

---

## 2. Templates

### CLAUDE.md

**What Claude Code has:**
- Load order: Managed policy → User (`~/.claude/CLAUDE.md`) → Project (`./CLAUDE.md`) → Local (`CLAUDE.local.md`)
- `@path/to/import` syntax (max 4 hops)
- HTML comments stripped before injection
- Target: under 200 lines for best adherence
- `/init` generates a starting CLAUDE.md from codebase analysis

**What dev-kit has:**
- `scaffold.sh` generates CLAUDE.md with `@AGENTS.md` import
- `AGENTS.md.template` — cross-tool instructions
- Separate agent rules in `agents/rules/`

**Recommendation:** Use CLAUDE.md with `@` imports for all agent instructions:
```markdown
@agents/rules/planner-core.md
@agents/rules/wave-execution.md
@agents/rules/grill-checklist.md
```
This replaces the "resource sets" concept — CLAUDE.md controls what loads.

### Path-Scoped Rules

**What Claude Code has:**
- `.claude/rules/*.md` with `paths:` frontmatter
- Loads only when Claude reads matching files
- No `paths:` = loads unconditionally (global)

**What dev-kit has:**
- `templates/common/claude-code/rules/code-style.md` — scoped to `src/**/*.ts`
- `templates/common/claude-code/rules/safety.md` — global (no paths)
- `templates/common/claude-code/rules/testing.md` — scoped to `**/*.test.ts`

**Recommendation:** Already correct format. Consolidate the 3 safety files into
one `.claude/rules/safety.md` (global).

### Skills

**What Claude Code has:**
- `.claude/skills/<name>/SKILL.md` with rich frontmatter
- Fields: `name`, `description`, `when_to_use`, `argument-hint`, `user-invocable`,
  `allowed-tools`, `disallowed-tools`, `model`, `effort`, `context`, `agent`, `hooks`,
  `paths`, `shell`
- Dynamic context injection: `` !`git diff HEAD` `` inlines shell output
- String substitutions: `$ARGUMENTS`, `$ARGUMENTS[N]`, `$N`, `$name`
- `context: fork` runs in a subagent
- Live change detection — edits take effect without restart

**What dev-kit has:**
- `skills/trio/SKILL.md` and `skills/grill/SKILL.md` — already Claude Code skills
- Simple frontmatter (name, description, user-invocable)

**Recommendation:** Enrich skills with hooks, model overrides, and tool restrictions:
```yaml
---
name: trio
user-invocable: true
model: opus
hooks:
  TaskCompleted:
    - type: command
      command: ".claude/hooks/validate-stage.sh"
---
```

---

## 3. Hooks

**This is Claude Code's most powerful enforcement mechanism.**

### 25+ Hook Events

| Event | When | Can Block? |
|-------|------|-----------|
| `PreToolUse` | Before tool call | Yes (exit 2) |
| `PostToolUse` | After tool call | No (stderr → Claude) |
| `PostToolBatch` | After batch of calls | Yes (stops loop) |
| `Stop` | Claude about to stop | Yes (exit 2) |
| `SubagentStart` | Subagent spawned | No |
| `SubagentStop` | Subagent finished | Yes (exit 2) |
| `TaskCreated` | Task being created | Yes (exit 2) |
| `TaskCompleted` | Task being completed | Yes (exit 2) |
| `UserPromptSubmit` | User submits prompt | Yes (exit 2) |
| `WorktreeCreate` | Worktree being created | Yes (any non-zero) |
| `PreCompact` | Before context compaction | Yes |
| `SessionStart` | Session begins | No |
| `FileChanged` | Watched file changes | No |
| `ConfigChange` | Config changes | Yes |

### 5 Handler Types

1. **Command** — shell command, receives JSON on stdin
2. **HTTP** — POST to URL with JSON body
3. **MCP Tool** — call tool on connected MCP server
4. **Prompt** — single-turn LLM evaluation (yes/no)
5. **Agent** — spawn subagent with tools to verify conditions

### Configuration

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "if": "Bash(rm *)",
          "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/block-dangerous.sh"
        }]
      }
    ]
  }
}
```

### What dev-kit Should Migrate to Hooks

| Current (prompt-based) | Hook Migration |
|------------------------|---------------|
| "Never run `rm -rf`" | `PreToolUse` hook blocking `Bash(rm *)` |
| "Never `git push --force`" | `PreToolUse` hook blocking `Bash(git push --force*)` |
| "Run tests before claiming done" | `Stop` hook running tests, exit 2 if fail |
| "Coder cannot write specs/" | `PreToolUse` hook blocking `Edit(specs/**)` |
| "Pipeline must be at sprint stage" | `PreToolUse` hook checking `gate.sh check sprint` |
| "vitest must use threads pool" | `PreToolUse` hook blocking `Bash(*--pool forks*)` |
| "Max 3 green retries" | `TaskCompleted` hook counting retries |

**Key insight:** Hooks execute regardless of what Claude decides. Rules in CLAUDE.md
are advisory — Claude may not follow them. For anything that "must" happen, use hooks.

---

## 4. Prompts / System Instructions

### CLAUDE.md Hierarchy

```
Managed policy (org-wide)
  └── User (~/.claude/CLAUDE.md)
        └── Project (./CLAUDE.md)
              └── Local (./CLAUDE.local.md, gitignored)
                    └── Nested (subdirectory CLAUDE.md, on-demand)
```

All files concatenated. `@` imports expand inline. HTML comments stripped.

### Agent Definitions

`.claude/agents/*.md` with frontmatter:
```yaml
name: coder
description: Implementation agent
tools: Read, Write, Edit, Bash
permissionMode: acceptEdits    # or: plan, auto, bypassPermissions
maxTurns: 50
model: sonnet
isolation: worktree
memory: project
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./.claude/hooks/validate-coder.sh"
```

**Key fields for SDD:**
- `permissionMode: plan` — read-only (replaces dev-kit's "planner reads only")
- `isolation: worktree` — each coder gets isolated worktree (replaces manual worktree management)
- `hooks` — enforce safety rules structurally
- `tools: Agent(sprint-manager)` — restrict which agents can be spawned (replaces delegation rules)
- `memory: project` — persistent memory across sessions

### Auto Memory

- `~/.claude/projects/<path>/memory/` — Claude writes notes to itself
- `MEMORY.md` — index loaded at session start (first 200 lines)
- Topic files loaded on demand
- `/memory` command to browse
- Subagents: `memory: user|project|local` scopes

**Replaces:** dev-kit's `hot-memory.sh`, workspace state files, session continuity docs

---

## 5. Other SDD-Relevant Features

### Agent Teams (Experimental)

- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- Shared task list with dependencies
- Teammates self-claim unblocked tasks
- `SendMessage` for inter-agent communication
- Display: in-process, tmux, iTerm2

**Replaces:** dev-kit's session daemon, multiplexer, parallel session management

### Worktree Isolation

- `isolation: worktree` in agent frontmatter
- Auto-creates `.claude/worktrees/<name>/`
- `WorktreeCreate`/`WorktreeRemove` hooks
- Auto-cleanup after `cleanupPeriodDays`

**Replaces:** Manual worktree management in wave execution

### Monitor Tool

- Background bash commands with `run_in_background`
- Stream stdout events as notifications
- `persistent: true` for session-length watches

**Replaces:** Manual process monitoring, log tailing

### Model Selection

- Session: `--model claude-opus-4-8`
- Agent: `model: sonnet|opus|haiku` in frontmatter
- Skill: `model: opus` (temporary override)
- Env: `CLAUDE_CODE_SUBAGENT_MODEL`

**Enables:** Tiered review (sonnet for lite, opus for full), model diversity for adversarial review

### Checkpointing

- Automatic file change tracking
- `Esc` + `Esc` opens rewind menu
- Restore conversation and code to previous points

**Replaces:** Manual checkpoint/resume in pipeline

---

## 6. What Claude Code Cannot Replace

| Dev-kit Feature | Why Claude Code Can't Replace It |
|----------------|--------------------------------|
| Git pre-commit hooks | Claude Code hooks are agent lifecycle, not git hooks |
| Pipeline FSM with explicit stages | Tasks have dependencies but no stage-based FSM |
| Cross-tool portability | CLAUDE.md is Claude-specific; AGENTS.md can be shared |
| EARS spec enforcement | No built-in spec format or validation |
| Spec-test traceability | No built-in @spec parsing |
| Visual regression testing | No built-in screenshot comparison |

**Keep:** lefthook, gate.sh, spec-trace.sh, quality gates — these are code-enforced
mechanisms that complement Claude Code's prompt-based and hook-based enforcement.

---

## 7. Dynamic Workflows

Dynamic workflows (Claude Code v2.1.154+, research preview) move orchestration logic
from Claude's context window into executable JavaScript scripts.

### How They Map to SDD

| SDD Phase | Workflow | What It Does |
|-----------|----------|-------------|
| Test Manager (RED) | sdd-test-gen | Generate tests, verify RED, check AC coverage |
| Sprint (GREEN) | wave-dispatch | Parallel coders, GREEN gate, post-wave gates |
| Review | sdd-review | Multi-perspective review with adversarial verify |
| Retro | sdd-retro | Classify findings, route outputs |

### Hybrid Model
- Skills for interactive phases (grill, approval)
- Workflows for automated phases (test gen, sprint, review, retro)
- gate.sh for filesystem enforcement
- Hooks for git enforcement

### Script Primitives
- `agent(prompt, opts)` — spawn worker
- `parallel([fn1, fn2])` — barrier
- `pipeline(items, stage1, stage2)` — streaming
- `phase('Title')` — UI grouping
- `log('message')` — progress
- `args` — input (parse with JSON.parse)
- `budget.total/spent/remaining` — token tracking

### Known Bugs
- Args arrive as JSON string — use `JSON.parse(args)` workaround
- Model override ignored — set `/model` before running workflow

See `workflow/dynamic-workflows-guide.md` for the complete guide.
