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
- Tool-use architecture (fs_read, fs_write, execute_bash, grep, glob, web_search)
- Agent JSON definitions (role, model, prompt, tools, deniedPaths)
- Classic mode for non-interactive spawns
- Resource injection (context files loaded at session start)
- Trust settings per role

### Kiro Invocation

```bash
# Interactive session (supervisor, test-manager)
kiro-cli chat --agent <name>

# Non-interactive spawn (coder, tester, reviewer)
kiro-cli chat --classic --agent <name> --trust-tools fs_read,fs_write,execute_bash,grep,glob
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
  "tools": ["fs_read", "fs_write", "grep", "execute_bash", "glob"],
  "resources": [
    "file:///path/to/knowledge/workflow.md",
    "file:///path/to/knowledge/project.md"
  ]
}
```

### Key Kiro Patterns

| Pattern | Purpose |
|---------|---------|
| `--classic` mode | Non-interactive, no TUI, suitable for spawned tabs |
| `--agent <name>` | Load role-specific config from JSON |
| `--trust-tools <list>` | Whitelist tools without interactive confirmation |
| `deniedPaths` in JSON | Enforce role boundaries (supervisor can't write src/) |
| `resources` array | Inject context at session start |
| `--resume` | Recover crashed session |

### Kiro Session Lifecycle

```
1. Tab created (zellij)
2. Launcher starts: kiro-cli chat --classic --agent coder --trust-tools ...
3. Briefing injected as first user message
4. Agent works (reads, writes, executes)
5. Agent writes result to /tmp/<id>-result.md
6. Launcher detects result → notifies parent → exits
7. Tab auto-closes (--close-on-exit)
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

### Cursor Agent (API)
```bash
# Adapter: adapters/cursor.sh
# Uses cursor's background agent API
curl -X POST http://localhost:3000/agent \
  -d @/tmp/briefing.json
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

## Configuration

```yaml
# In project .agents/agents.yml
runtime:
  agent_cli: kiro          # Default agent CLI
  # agent_cli: claude-code # Alternative
  # agent_cli: aider       # Alternative
  # agent_cli: custom      # Uses adapters/custom.sh
```

## Preflight Check

```bash
#!/bin/bash
# preflight.sh — verify coding agent is available

case "${AGENT_CLI:-kiro}" in
  kiro)
    command -v kiro-cli >/dev/null || { echo "kiro-cli not found"; exit 1; }
    kiro-cli --version
    ;;
  claude-code)
    command -v claude >/dev/null || { echo "claude not found"; exit 1; }
    ;;
  aider)
    command -v aider >/dev/null || { echo "aider not found"; exit 1; }
    ;;
  *)
    test -x "adapters/${AGENT_CLI}.sh" || { echo "adapter not found"; exit 1; }
    ;;
esac
```

## Why Kiro as Default

1. **Tool-use native** — built for file operations, not just chat
2. **Agent JSON** — declarative role definitions with enforced boundaries
3. **deniedPaths** — structural enforcement of delegation (supervisor can't write code)
4. **Resources** — context injection without prompt engineering
5. **Classic mode** — clean non-interactive operation for spawned workers
6. **Resume** — crash recovery without losing session state
