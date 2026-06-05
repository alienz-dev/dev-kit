# Claude Code Native Mode

How to use dev-kit with Claude Code directly — no daemon, no multiplexer.

## Quick Start

```bash
# 1. Clone and setup
git clone <this-repo> ~/dev-kit
cd ~/dev-kit
./setup.sh --minimal

# 2. Create a project
./scaffold.sh my-project

# 3. Start coding
cd ~/projects/my-project
claude
```

That's it. Claude Code reads CLAUDE.md, loads agents from `.claude/agents/`, and applies rules from `.claude/rules/`.

## What Gets Generated

```
my-project/
├── CLAUDE.md                    # Project instructions (lean, <80 lines)
├── AGENTS.md                    # Cross-tool instructions (shared with aider, codex, etc.)
├── CLAUDE.local.md              # Personal overrides (gitignored)
├── .claude/
│   ├── settings.json            # Permissions, hooks
│   ├── agents/                  # Subagent definitions
│   │   ├── coder.md             # Implementation agent
│   │   ├── reviewer.md          # Code review agent
│   │   ├── test-manager.md      # RED gate owner
│   │   ├── researcher.md        # Deep investigation
│   │   └── explorer.md          # Focused search
│   ├── rules/                   # Path-scoped rules
│   │   ├── testing.md           # Loaded for *.test.ts files
│   │   ├── code-style.md        # Loaded for src/**/*.ts files
│   │   └── safety.md            # Always loaded
│   └── skills/                  # Custom commands
│       ├── trio/SKILL.md        # /trio command
│       └── grill/SKILL.md       # /grill command
├── .pipeline/                   # Pipeline state (gate.sh)
├── lefthook.yml                 # Pre-commit hooks
└── ...                          # src/, tests/, specs/, etc.
```

## Agent Definitions

Each agent is a Markdown file with YAML frontmatter:

```markdown
---
name: coder
description: Implementation agent. Makes failing tests pass.
tools: Read, Write, Edit, Bash, Grep, Glob
model: sonnet
permissionMode: acceptEdits
maxTurns: 50
memory: project
---

You are a coder. Your job is to make failing tests pass.
...
```

Claude Code automatically delegates to the right agent based on the `description` field.

## Path-Scoped Rules

Rules in `.claude/rules/` with `paths:` frontmatter load only when Claude reads matching files:

```markdown
---
paths:
  - "**/*.test.ts"
---

# Testing Rules
- Runner: vitest (threads pool, NEVER forks)
- Use descriptive test names
```

Rules without `paths:` load at session start.

## Skills

Skills are reusable workflows with dynamic context injection:

```
/trio feature-name    # Run TRIO protocol for a feature
/grill topic          # Design tree interview
```

## Hooks

Hooks in `.claude/settings.json` run automatically:

- **Stop hook**: Plays macOS notification sound when session ends
- **PreToolUse**: Can block dangerous commands
- **PostToolUse**: Can auto-format on file changes

## Multi-Agent Workflow

Claude Code's in-process `Agent()` tool handles multi-agent spawning:

1. **You** describe a feature to Claude Code
2. **Claude Code** writes a spec in specs/
3. **Claude Code** spawns test-manager agent (writes tests, verifies RED)
4. **Claude Code** spawns coder agent (implements, verifies GREEN)
5. **Claude Code** spawns reviewer agent (verifies spec intent)
6. **You** approve and close

No separate CLI instances. No daemon. No multiplexer.

## Comparison with Full Mode

| Feature | Full Mode (Level 1) | Claude Code Native (Level 3) |
|---------|-------------------|---------------------------|
| Agent spawning | Separate processes | Agent() tool (in-process) |
| Multiplexer | Zellij (tabs per agent) | Not needed |
| Daemon | Session daemon (required) | Self-managing (implicit) |
| Pipeline enforcement | Daemon FSM | gate.sh (file-based) |
| Pre-commit | lefthook | lefthook (same) |
| Agent definitions | Agent JSON files | .claude/agents/*.md |
| Skills | Skill files | .claude/skills/ |
| Hooks | Agent spawn hooks | settings.json hooks |

## When to Use Full Mode

Use Level 1 (Full) only when you need:
- Multiple agents running in parallel in separate Zellij tabs
- gate.sh-enforced pipeline transitions

For most development, Claude Code native mode is sufficient.
