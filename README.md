# dev-kit

A portable development toolkit for AI-assisted software projects. Extracted from real production experience (watchdog, krew-cli, neo-ui, studenths) — not theoretical.

## What This Is

A repo you clone on a fresh machine to bootstrap a full AI-native development environment:
- Terminal multiplexer with agent-aware layout
- Coding agent integration (kiro default, pluggable for others)
- Spec-driven development pipeline
- Multi-agent orchestration (supervisor → test-manager → coder)
- Issue tracking with lifecycle gates
- UI regression and visual quality checks
- Session management and persistence
- Hot-memory and workspace state

## What This Is NOT

- Not a framework or library to import
- Not tied to any specific LLM provider or agent CLI
- Not opinionated about your application's architecture

## Quick Start

```bash
git clone <this-repo> ~/dev-kit
cd ~/dev-kit
./setup.sh              # interactive — detects OS, installs deps, configures
./scaffold.sh <name>    # create a new project with full infrastructure
```

## Structure

```
dev-kit/
├── README.md
├── setup.sh                    # Machine bootstrap (idempotent)
├── scaffold.sh                 # New project generator
├── PLAN.md                     # Detailed roadmap
│
├── core/                       # Core infrastructure
│   ├── multiplexer/            # Zellij config, layouts, plugins
│   ├── coding-agent/           # Agent CLI integration (kiro default, pluggable)
│   ├── session-daemon/         # Session lifecycle, hang detection, dispatch
│   └── agent-launcher/         # Agent spawn, briefing, result collection
│
├── workflow/                    # Development methodology
│   ├── sdd/                    # Spec-Driven Development templates + gates
│   ├── trio/                   # TRIO protocol (Test-Red-Implement-Observe)
│   ├── issue-lifecycle/        # Issue states, transitions, CLI
│   └── retro/                  # Session retrospective extraction
│
├── agents/                     # Agent definitions and roles
│   ├── roles/                  # supervisor, coder, tester, reviewer, planner
│   ├── rules/                  # Safety rules, coding conventions
│   ├── knowledge/              # Per-project knowledge templates
│   └── hooks/                  # Agent spawn hooks, context injection
│
├── quality/                    # Quality gates
│   ├── ui-visual-check/        # CDP screenshot + VLM + heuristic checks
│   ├── pre-commit/             # Test gate, typecheck, lint
│   └── regression/             # Regression test patterns
│
├── templates/                  # Project templates
│   ├── typescript-cli/
│   ├── typescript-web/
│   ├── python-service/
│   └── common/                 # Shared: tsconfig, vitest, gitignore, etc.
│
├── infra/                      # System services
│   ├── systemd/                # Service units for daemons
│   ├── scripts/                # Utility scripts (start-server, stop-server, etc.)
│   └── state/                  # Hot-memory, workspace state, memo templates
│
└── docs/                       # Documentation
    ├── ARCHITECTURE.md         # How the pieces fit together
    ├── CONVENTIONS.md          # Coding standards for AI-assisted dev
    ├── TROUBLESHOOTING.md      # Common failure modes and fixes
    └── FRESH-MACHINE.md        # Complete setup from zero
```
