# Coding Agent Integration

## Design

The dev-kit uses a **coding agent** as the execution engine — an AI CLI that reads files, writes code, runs commands, and produces results. Claude Code is the default. Others plug in via adapters.

## Interface Contract

Every coding agent must satisfy:

```
Input:
  - Briefing file (markdown): task description + context + constraints
  - Working directory: where to operate
  - Allowed tools/paths: what the agent can read/write/execute

Output:
  - Result file (markdown) at a specified path
  - Modified source files in the working directory

Signal:
  - Process exit 0 = success
  - Process exit non-zero = failure
```

## Default: Claude Code

Claude Code is the default coding agent. It provides:
- In-process subagent spawning via `Agent()` tool
- Agent definitions as `.claude/agents/*.md` files with YAML frontmatter
- Path-scoped rules via `.claude/rules/*.md`
- Skills via `.claude/skills/*/SKILL.md`
- Hooks via `.claude/settings.json`
- Background dispatch with completion tracking

### Claude Code Dispatch

```javascript
// In-process subagent
Agent({ prompt: "task", subagent_type: "general-purpose" })

// With isolation (parallel coders)
Agent({ prompt: "task", isolation: "worktree" })

// Background dispatch
Agent({ prompt: "task", run_in_background: true })
```

### Agent Definitions (`.claude/agents/*.md`)

```markdown
---
name: coder
description: Implementation agent
tools: Read, Write, Edit, Bash
model: sonnet
permissionMode: acceptEdits
maxTurns: 50
---

You are a coder. Your job is to make failing tests pass.
...
```

## Alternative Agents

### Aider
```bash
# Adapter: adapters/aider.sh
aider --yes-always \
  --message-file /tmp/briefing.md \
  --no-auto-commits \
  $FILES
```

### Custom Agent
```bash
# Adapter: adapters/custom.sh
# Any CLI that:
# 1. Reads a briefing (stdin or file)
# 2. Operates on files in a directory
# 3. Exits with status code
$CUSTOM_AGENT_CMD --input /tmp/briefing.md --workdir $WORKDIR
```

## Adapter Interface

Each adapter script must:

```bash
#!/bin/bash
# adapters/<name>.sh
# Args: $1=briefing_path $2=workdir $3=result_path

BRIEFING="$1"
WORKDIR="$2"
RESULT="$3"

# 1. Translate briefing to agent-specific format
# 2. Invoke agent CLI
# 3. Collect output → write to $RESULT
# 4. Exit 0 on success, non-zero on failure
```
