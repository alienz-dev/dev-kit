# Kiro Agent Setup

## Installation

```bash
npm install -g @anthropic/kiro-cli
```

## Directory Structure

```
~/.kiro/
├── agents/              # Agent JSON definitions (one per role per project)
│   ├── watchdog-dev.json
│   ├── coder.json
│   ├── planner.json
│   └── ...
├── rules/               # Global rules loaded into every session
│   └── client_rules.md
├── skills/              # Skill definitions (loaded on demand)
│   └── <skill>/SKILL.md
├── state/               # Per-workspace state files
│   ├── hot-memory-<workspace>.md
│   └── memo-<workspace>.md
└── hooks/               # Spawn-time hooks
    └── project-context.sh
```

## Agent JSON Template

```json
{
  "name": "<project>-<role>",
  "description": "<Role> for <project>",
  "model": "claude-sonnet-4-20250514",
  "prompt": "<system prompt defining role behavior>",
  "toolsSettings": {
    "write": {
      "deniedPaths": [
        "~/.kiro/**",
        "**/node_modules/**"
      ]
    },
    "read": {
      "deniedPaths": ["~/.ssh/id_*", "**/.env.production"]
    }
  },
  "tools": ["fs_read", "fs_write", "grep", "execute_bash", "glob"],
  "allowedTools": ["fs_read", "fs_write", "grep", "execute_bash", "glob"],
  "resources": [
    "file:///path/to/knowledge.md"
  ]
}
```

## Role-Specific deniedPaths

### Supervisor (orchestrator — cannot write code)
```json
"deniedPaths": [
  "**/src/**", "**/tests/**",
  "**/*.ts", "**/*.tsx", "**/*.js", "**/*.py",
  "**/package.json", "**/tsconfig.json"
]
```

### Coder (implementation — cannot write project management)
```json
"deniedPaths": [
  "~/.kiro/agents/**",
  "**/STATUS.md", "**/NEXT-SESSION.md",
  "**/.agents/knowledge/**"
]
```

### Reviewer (read-only except reports)
```json
"deniedPaths": [
  "**/src/**", "**/tests/**",
  "**/*.ts", "**/*.tsx", "**/*.js", "**/*.py"
]
```

## Invocation Modes

| Mode | Command | Use Case |
|------|---------|----------|
| Interactive | `kiro-cli chat --agent <name>` | Supervisor, test-manager |
| Classic (non-interactive) | `kiro-cli chat --classic --agent <name>` | Spawned workers |
| Resume | `kiro-cli chat --resume` | Crash recovery |
| With trust | `--trust-tools fs_read,fs_write,...` | Skip tool confirmation |

## Trust Settings

Derive `--trust-tools` from agent JSON's `tools` array:
```bash
TRUST=$(jq -r '.tools | join(",")' ~/.kiro/agents/<name>.json)
kiro-cli chat --classic --agent <name> --trust-tools "$TRUST"
```

## Resources (Context Injection)

Files listed in `resources` are loaded into agent context at session start:
```json
"resources": [
  "file:///home/user/.kiro/rules/client_rules.md",
  "file:///home/user/projects/myapp/.agents/knowledge/workflow.md"
]
```

Use for: safety rules, project knowledge, workflow definitions.

## Gotchas

- Agent JSON must exist BEFORE launching (`kiro-cli` errors with "no agent found")
- `--classic` mode: `/quit` doesn't exit process — launcher must `kill -9`
- Ctrl+C in classic mode kills the process (no graceful cancel)
- Resources use `file://` protocol with absolute paths
- Model field determines which LLM is used (check available models)
