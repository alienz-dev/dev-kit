# Coding Agent Integration

## Design

The dev-kit uses a **coding agent** as the execution engine — an AI CLI that reads files, writes code, runs commands, and produces results. Kiro is the default. Others plug in via adapters.

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

## Default: Kiro

Kiro is the default coding agent. It provides:
- Tool-use architecture (read, write, shell, grep, glob, web_search)
- Agent JSON definitions (role, model, prompt, tools, deniedPaths)
- TUI mode for all sessions (stdin/stdout isolation handled structurally)
- Resource injection (context files loaded at session start)
- Trust settings per role

### Kiro Invocation

```bash
# All sessions use --tui mode (stdin/stdout isolation is structural)
kiro-cli chat --tui --agent <name>

# Resume crashed session
kiro-cli chat --resume
```

### Agent JSON (`~/.kiro/agents/<name>.json`)

```json
{
  "name": "coder",
  "description": "Implementation agent for <project>",
  "model": "claude-sonnet-4-20250514",
  "prompt": "<role-specific system prompt>",
  "toolsSettings": {
    "write": {
      "deniedPaths": ["<paths this role cannot write>"]
    }
  },
  "tools": ["read", "write", "grep", "shell", "glob"],
  "resources": [
    "file:///path/to/knowledge/workflow.md",
    "file:///path/to/knowledge/project.md"
  ]
}
```

### Key Kiro Patterns

| Pattern | Purpose |
|---------|---------|
| `--tui` mode | Structural stdin/stdout isolation for all sessions |
| `--agent <name>` | Load role-specific config from JSON |
| `deniedPaths` in JSON | Enforce role boundaries (supervisor can't write src/) |
| `resources` array | Inject context at session start |
| `--resume` | Recover crashed session |

### Kiro Session Lifecycle

```
1. Tab created (zellij)
2. kiro-ctl spawn → daemon creates tab, starts kiro-cli --tui --agent <role>
3. Briefing injected as first user message
4. Agent works (reads, writes, executes via tools)
5. Agent writes result to /tmp/<id>-result.md
6. Daemon detects result → notifies parent via EventBus → tab closes
```

## Alternative Agents

### Claude Code
```bash
# Adapter: adapters/claude-code.sh
claude --dangerously-skip-permissions \
  --print \
  --output-format text \
  -p "$(cat /tmp/briefing.md)" \
  --allowedTools "Edit,Write,Bash" \
  2>/dev/null
```

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

## Why Kiro as Default

1. **Tool-use native** — built for file operations, not just chat
2. **Agent JSON** — declarative role definitions with enforced boundaries
3. **deniedPaths** — structural enforcement of delegation (supervisor can't write code)
4. **Resources** — context injection without prompt engineering
5. **TUI mode** — structural stdin/stdout isolation, no manual workarounds needed
6. **Resume** — crash recovery without losing session state
