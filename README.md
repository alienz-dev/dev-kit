# dev-kit

A portable development toolkit for AI-assisted software projects. Extracted from real production experience (watchdog, krew-cli, neo-ui, studenths) — not theoretical.

## What This Is

A repo you clone on a fresh machine to bootstrap a full AI-native development environment:
- Terminal multiplexer with agent-aware layout
- Coding agent integration (kiro default, pluggable for others)
- Session daemon with pipeline enforcement and EventBus
- Spec-driven development with EARS acceptance criteria
- Multi-agent orchestration (supervisor → test-manager → sprint-manager → coder)
- ARIA v2 research protocol (parallel explorers + adversarial critic)
- Tiered code review (3 tiers, auto-promotion for sensitive paths)
- UI visual quality gates (static + VLM + DOM heuristics)
- Design system iteration tools (autonomous feedback loop)
- Data analyst agent (sandboxed iterative analysis)
- Issue tracking with lifecycle gates
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
│   ├── session-daemon/         # kiro-sessiond (REQUIRED) — lifecycle, EventBus, pipeline
│   └── agent-launcher/         # kiro-ctl spawn, briefing, result collection
│
├── workflow/                    # Development methodology
│   ├── sdd/                    # Spec-Driven Development (EARS notation)
│   ├── trio/                   # TRIO protocol (Test-Red-Implement-Observe)
│   ├── pipeline/               # Daemon-enforced pipeline FSM
│   ├── grill/                  # Spec interrogation sessions
│   ├── issue-lifecycle/        # Issue states, transitions, CLI
│   └── retro/                  # Session retrospective extraction
│
├── agents/                     # Agent definitions and roles
│   ├── roles/                  # 12 roles: supervisor, sprint-manager, coder, ui-designer, etc.
│   ├── rules/                  # Safety rules, coding conventions
│   ├── knowledge/              # Per-project knowledge templates
│   ├── context-files/          # Context injection templates
│   └── hooks/                  # Agent spawn hooks, context injection
│
├── quality/                    # Quality gates
│   ├── ui-visual-check/        # CDP screenshot + VLM + heuristic checks
│   ├── review/                 # Tiered review system (3 tiers)
│   ├── pre-commit/             # Test gate, typecheck, lint
│   └── regression/             # Regression test patterns
│
├── tools/                      # Specialized tooling
│   ├── design-system/          # Design iteration tools (sandbox, grade, iterate)
│   ├── data-analyst/           # Iterative analysis agent (sandboxed)
│   ├── explainer/              # Marketing page generator
│   ├── issue-cli/              # Issue tracking CLI (submodule)
│   └── ui-visual-check/        # Visual QA tool (submodule)
│
├── templates/                  # Project templates
│   ├── typescript-cli/
│   ├── typescript-web/
│   ├── python-service/
│   └── common/                 # Shared: tsconfig, vitest, gitignore, etc.
│
├── infra/                      # System services
│   ├── systemd/                # Service units (kiro-sessiond)
│   ├── scripts/                # Utility scripts (start-server, stop-server, etc.)
│   └── state/                  # Hot-memory, workspace state, memo templates
│
└── docs/                       # Documentation
    ├── ARCHITECTURE.md         # How the pieces fit together
    ├── CONVENTIONS.md          # Coding standards for AI-assisted dev
    ├── TROUBLESHOOTING.md      # Common failure modes and fixes
    └── FRESH-MACHINE.md        # Complete setup from zero
```

## Agent Hierarchy

```
User
  └── Planner/Supervisor (orchestrator, persistent)
        ├── Researcher (ARIA v2 orchestrator)
        │     ├── Explorer ×N (parallel)
        │     └── Research-Critic (adversarial)
        ├── UI-Designer (Phase 0, score 6+ UI)
        ├── Test-Manager (RED gate — persistent)
        └── Sprint-Manager (GREEN→REVIEW — ephemeral)
              ├── Coder ×N (parallel)
              ├── Reviewer-Lite (Tier 2)
              └── Reviewer (Tier 3)
```

## Pipeline (Daemon-Enforced)

```
plan → test → sprint → review → done | failed
```

Gates per wave: `trio-preflight → GREEN → wiring → visual → wave-smoke`
After all waves: `hidden → activation → review`
