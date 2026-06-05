# dev-kit

A portable development toolkit for AI-assisted software projects. Extracted from real production experience — not theoretical.

## What This Is

A repo you clone on a fresh machine to bootstrap a full AI-native development environment:
- Coding agent integration (Claude Code primary)
- Spec-driven development with EARS acceptance criteria
- Multi-agent orchestration (supervisor → test-manager → sprint-manager → coder)
- ARIA v2 research protocol (parallel explorers + adversarial critic)
- Tiered code review (3 tiers, auto-promotion for sensitive paths)
- UI visual quality gates (static analysis + Playwright regression + axe-core accessibility)
- Data analyst agent (sandboxed iterative analysis)
- Issue tracking with lifecycle gates
- Session management and persistence
- Hot-memory and workspace state

## What This Is NOT

- Not a framework or library to import
- Not tied to any specific LLM provider or agent CLI
- Not opinionated about your application's architecture

## Language & Tooling

The scaffold generates **TypeScript + Vitest + Node 22** projects by default. This is a
starting point based on what the toolkit was built with, not a hard constraint.

**To adapt for other languages (Python, Rust, Go, etc.):**
- Replace `package.json` / `tsconfig.json` / `vitest.config.ts` generation in `scaffold.sh`
- Update `templates/common/lefthook.yml` pre-commit hooks for your test runner
- Modify the code style section in `templates/common/AGENTS.md.template`

The agent infrastructure (CLAUDE.md, .claude/ config, workflow methodology, quality gates)
is language-agnostic and works with any stack.

## Quick Start

```bash
git clone <this-repo> ~/dev-kit
cd ~/dev-kit

# Minimal setup (recommended — works with any AI tool)
./setup.sh --minimal    # just node + git + directories
./scaffold.sh <name> --minimal  # AGENTS.md + CLAUDE.md + lefthook + pipeline state

# Full setup (multi-agent orchestration + submodules)
./setup.sh              # interactive — detects OS, installs deps, auto-inits submodules
./scaffold.sh <name>    # create a new project with full infrastructure

# Check what's missing without installing
./setup.sh --check
```

> **Note:** `tools/issue-cli` is an optional submodule.
> Update `.gitmodules` with your own repository URL, or remove the submodule
> if you don't need it. The core toolkit works without it.

### Start coding

```bash
cd ~/projects/<name>
claude              # Claude Code reads CLAUDE.md automatically
```

## Modes

| Mode | What You Get | Requires |
|------|-------------|----------|
| Full | Multi-agent orchestration, all gates | claude |
| Minimal | AGENTS.md + CLAUDE.md, lefthook pre-commit, file-based pipeline | git, node, any AI coding tool |
| Check | Reports missing tools, installs nothing | bash |

See [docs/DEGRADED-MODE.md](docs/DEGRADED-MODE.md) for details on the 3 levels.

## Structure

```
dev-kit/
├── README.md
├── setup.sh                    # Machine bootstrap (idempotent)
├── scaffold.sh                 # New project generator
├── PLAN.md                     # Detailed roadmap
│
├── core/                       # Core infrastructure
│   └── coding-agent/           # Agent CLI integration adapters
│
├── workflow/                    # Development methodology
│   ├── sdd/                    # Spec-Driven Development (EARS notation)
│   ├── trio/                   # TRIO protocol (Test-Red-Implement-Observe)
│   ├── pipeline/               # File-based pipeline FSM (gate.sh)
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
│   ├── gates/                  # Gate scripts (visual-regression, accessibility, etc.)
│   ├── ui-visual-check/        # VISUAL gate spec and DESIGN.md template
│   ├── review/                 # Tiered review system (3 tiers)
│   ├── pre-commit/             # Test gate, typecheck, lint
│   └── regression/             # Regression test patterns
│
├── tools/                      # Specialized tooling
│   ├── data-analyst/           # Iterative analysis agent (sandboxed)
│   ├── explainer/              # Marketing page generator
│   └── issue-cli/              # Issue tracking CLI (submodule)
│
├── templates/                  # Project templates
│   ├── common/                 # Shared: lefthook, agent rules, skills
│   └── typescript-web/         # Web-specific: visual checks, design tokens
│
├── infra/                      # System services
│   ├── systemd/                # Service units
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

## Pipeline (gate.sh + lefthook)

```
plan → test → sprint → review → done | failed
```

Gates per wave: `trio-preflight → GREEN → wiring → visual → wave-smoke`
After all waves: `hidden → activation → review`
