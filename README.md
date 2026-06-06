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
├── CLAUDE.md                   # Project instructions for Claude Code
├── setup.sh                    # Machine bootstrap (idempotent)
├── scaffold.sh                 # New project generator
├── sync.sh                     # Re-sync base files into scaffolded projects
│
├── .claude/                    # Claude Code project config
│   ├── settings.json           # Permissions
│   ├── commands/               # Slash commands (/scaffold, /setup, /test-gates)
│   └── workflows/              # Workflow scripts (adversarial-review, wave-implement, etc.)
│
├── phases/                     # Agent configs organized by development phase
│   ├── design/                 # Phase 1: Design (interactive)
│   │   ├── agents/             # BA, Architect, Researcher, Explorer, Research-Critic
│   │   ├── rules/              # grill-checklist
│   │   └── skills/             # grill, ba-validate, approve, spec-align
│   ├── implement/              # Phase 2+3: Test + Implement (automated)
│   │   ├── agents/             # Coder, Test-Manager, Tester
│   │   ├── rules/              # coder-safety, wave-execution, implementation-briefing
│   │   ├── skills/             # sdd (orchestrator), coder-safety, trio (alias)
│   │   └── hooks/              # block-spec-read, check-briefing
│   ├── review/                 # Phase 4: Review (automated)
│   │   ├── agents/             # Reviewer, Reviewer-Lite
│   │   └── gates/              # 8 gate scripts + __tests__/
│   └── shared/                 # Cross-cutting (all phases)
│       ├── rules/              # client_rules, CONSOLIDATED, HANDOFF, ROLES, complexity-scoring
│       ├── hooks/              # block-dangerous, check-spec-approval, verify-tests
│       ├── skills/             # compaction-strategy, testing-patterns, typescript-patterns
│       └── context-files/      # session-routing, user-profile
│
├── core/                       # Core infrastructure
│   └── coding-agent/           # Agent CLI integration adapters
│
├── docs/                       # Documentation
│   ├── ARCHITECTURE.md
│   ├── USER-GUIDE.md
│   ├── TROUBLESHOOTING.md
│   └── archive/                # Archived: PLAN.md, TRIO.md, foundation-fixes specs
│
├── infra/scripts/              # Utility scripts (env-detect, hot-memory, start/stop)
├── issues/                     # Issue tracking (markdown) + templates
├── specs/                      # Feature specs and implementation plans
├── templates/                  # Project templates (lefthook, AGENTS.md.template, visual-testing)
├── tools/                      # Standalone tooling (issue-cli, ui-visual-check, explainer)
│
└── workflow/                   # Process docs + pipeline FSM
    ├── sdd/                    # SDD methodology (absorbs TRIO), spec tools
    ├── pipeline/               # gate.sh, transitions.json, checkpoint.sh
    └── dynamic-workflows-analysis.md
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

### Workflow Orchestration

In addition to subagent-based orchestration, the toolkit supports Claude Code's
dynamic workflows for automated phases. The hybrid model uses:
- **Skills** for interactive phases (grill, approval, spec review)
- **Workflows** for automated phases (test gen, coder dispatch, review, retro)
- **gate.sh** for filesystem enforcement (proof files, state transitions)
- **Hooks** for git enforcement (pre-commit checks)

See `workflow/dynamic-workflows-guide.md` for the complete guide.

## Pipeline (gate.sh + lefthook)

```
plan → test → sprint → review → done | failed
```

Gates per wave: `trio-preflight → GREEN → wiring → visual → wave-smoke`
After all waves: `hidden → activation → review`

> **Dynamic Workflows**: The sprint stage can be driven by the `wave-dispatch` workflow
> for automated parallel coder dispatch. See `workflow/dynamic-workflows-guide.md`.

## SDD Commands (Claude Code Skills)

The SDD system runs in three phases: **Design** (interactive) → **Implementation** (automatic) → **Review** (human).

| Command | Phase | What It Does |
|---------|-------|-------------|
| `<description>` | Design | Describe what you want, agent gathers requirements |
| `/grill <topic>` | Design | Interactive design interview (Q&A with user) |
| `/ba-validate <spec>` | Design | Validate spec quality (structural + semantic) |
| `/approve <spec>` | Design | Approve spec for implementation |
| `/sdd <feature>` | Implementation | Run full pipeline (automatic, no human needed) |
| `/sdd resume <feature>` | Implementation | Resume failed pipeline from current stage |
| `/spec-align <spec>` | Maintenance | Compare spec vs code, find divergences |
| `/researcher <question>` | Research | Deep investigation (parallel explorers) |
| `ultracode: <task>` | Workflow | Trigger a dynamic workflow for a specific task |
| `/adversarial-review` | Workflow | Multi-angle code review with adversarial verification |
| `/wave-implement` | Workflow | TRIO-style wave dispatch with worktree isolation |
| `/deep-audit` | Workflow | Comprehensive codebase audit |
| `/research-crosscheck` | Workflow | Multi-angle research with cross-checked sources |
| `/migration-sweep` | Workflow | Codebase-wide migration pipeline |
| `/sdd-implement` | Workflow | Full SDD implementation via workflows |

### Workflow

```
1. User: "add dark mode"
2. Agent: gathers requirements, asks design questions
3. User: answers questions, approves spec
4. User: "/sdd dark-mode"
5. Agent: runs implementation automatically
6. User: reviews result, files issues if needed
7. User: "/sdd dark-mode" again for fixes
```

See [docs/USER-GUIDE.md](docs/USER-GUIDE.md) for detailed usage.
