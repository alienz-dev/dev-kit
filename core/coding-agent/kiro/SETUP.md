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
  "tools": ["read", "write", "grep", "shell", "glob"],
  "allowedTools": ["read", "write", "grep", "shell", "glob"],
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

## Invocation

All sessions use TUI mode (stdin/stdout isolation is structural):

```bash
# Standard invocation (all roles)
kiro-cli chat --tui --agent <name>

# Resume crashed session
kiro-cli chat --resume

# Resume specific conversation
kiro-cli chat --resume-id <conversation-id>
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
- TUI mode handles stdin/stdout isolation structurally — no `< /dev/null` needed
- Resources use `file://` protocol with absolute paths
- Model field determines which LLM is used (check available models)
- kiro-bash-guard.sh (AMAZON_Q_CHAT_SHELL) provides 300s timeout for all commands
