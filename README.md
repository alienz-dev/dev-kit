# dev-kit

A portable AI-native development toolkit. 24 skills, 6 hooks, spec-driven development, and multi-agent orchestration — all in markdown and bash.

## What This Is

A toolkit you clone to bootstrap AI-assisted development in any project:
- **24 agent skills** covering the full SDLC (design → implement → review)
- **Spec-driven development** with EARS acceptance criteria and automated pipelines
- **Multi-agent orchestration** with parallel dispatch, worktree isolation, quality gates
- **Confidence-scored routing** for intelligent skill selection
- **Three-layer customization** (skill defaults → project → user)
- **6 safety hooks** blocking dangerous operations and enforcing workflow discipline
- **Meta-skills** for health checks, audits, and pre-commit validation

## What This Is NOT

- Not a framework or library to import
- Not tied to any specific LLM provider
- Not opinionated about your application's architecture

## Quick Start

```bash
git clone <this-repo> ~/dev-kit
cd ~/dev-kit

# Install global skills (available in every Claude Code session)
./setup.sh

# Scaffold a new project with full infrastructure
./scaffold.sh <project-name>

# Or retrofit an existing project
./scaffold.sh here
```

## Skills

### Global Skills (18 — available in every session)

| Skill | Purpose | Trigger |
|-------|---------|---------|
| `/orient` | Map codebase structure, tech stack, architecture | "what is this", "how does this work" |
| `/grill` | Design tree interview — exhaustive Q&A | "design X", "let's think about X" |
| `/researcher` | Deep investigation with parallel explorers | "research X", "investigate X" |
| `/debug` | Dispatch debugger subagent | "this is broken", "tests failing" |
| `/quick-review` | Lightweight code review | "review this", "check this PR" |
| `/security-audit` | OWASP Top 10, auth, crypto, secrets | "security audit", "check vulnerabilities" |
| `/dep-audit` | CVEs, licenses, supply chain | "check dependencies", "npm audit" |
| `/perf-profile` | N+1 queries, bottlenecks, caching | "this is slow", "optimize" |
| `/tech-debt` | Dead code, complexity, pattern drift | "tech debt", "code health" |
| `/docs` | API docs, README, onboarding guides | "document this", "write docs" |
| `/release` | Changelog, version bump, pre-flight | "release", "changelog" |
| `/a11y` | WCAG 2.1 AA compliance | "accessibility", "WCAG" |
| `/api-design` | REST conventions, versioning | "design API", "new endpoint" |
| `/health` | Parallel health agents, weighted scoring | "health check", "project health" |
| `/audit` | Deep security-focused audit | "full audit", "compliance" |
| `/pre-commit` | Pre-commit validation | "pre-commit", "ready to commit" |
| `/status` | Quick inline status check | "status", "are we good" |
| `/scaffold` | Scaffold new project | "scaffold", "new project" |

### SDD Skills (6 — scaffolded projects only)

| Skill | Purpose | Trigger |
|-------|---------|---------|
| `/sdd` | Full SDD pipeline: plan → test → code → review → retro | "implement X" |
| `/trio` | Sprint-only wave dispatch | "run sprint" |
| `/approve` | Approve spec for implementation | "approve spec" |
| `/ba-validate` | Validate spec quality | "validate spec" |
| `/spec-align` | Compare spec vs code | "spec alignment" |
| `coder-safety` | Safety rules (auto-loaded) | — |

## Features

### Spec-Driven Development (SDD)

Features are built through a 3-phase lifecycle:

```
Design (interactive) → Implementation (automatic) → Review (human)
```

1. **Design**: `/grill` explores the design space, BA gathers requirements, user approves spec
2. **Implementation**: `/sdd` derives plan, generates tests, dispatches coders in parallel, runs review
3. **Review**: User evaluates results, files issues, re-runs `/sdd` for fixes

### Confidence-Scored Routing

Before invoking a skill, the system evaluates 5 signals:

| Signal | Weight | What It Measures |
|--------|--------|-----------------|
| Keyword match | 30% | Does the request match a skill trigger? |
| Intent clarity | 25% | Is the request unambiguous? |
| Context available | 20% | Do referenced files/concepts exist? |
| Precedent | 15% | Has this pattern been routed before? |
| Risk (inverse) | 10% | Is the action low-risk? |

| Score | Action |
|-------|--------|
| ≥ 0.85 | Auto-proceed |
| 0.70–0.84 | Proceed, log decision |
| 0.50–0.69 | Ask user to confirm |
| < 0.50 | Explore first, then re-score |

### Three-Layer Customization

Skills support configuration overrides without forking:

```
Skill defaults (config.default.md)
  ↓
Project overrides (.claude/config/{skill}.md)
  ↓
User overrides (~/.claude/config/{skill}.md)
```

**Merge rules**: scalars override, tables deep-merge, arrays append.

**Configurable fields**: `model`, `strictness`, `scope`, `thresholds`, `custom_rules`, `output_format`, `persistent_facts`.

**Example** — project-level security-audit config:
```yaml
# .claude/config/security-audit.md
---
strictness: paranoid
scope:
  include: ["src/auth/**", "src/api/**"]
custom_rules:
  - "All auth endpoints must have rate limiting"
  - "JWT tokens must use RS256, not HS256"
---
```

### Safety Hooks

6 PreToolUse hooks enforce workflow discipline:

| Hook | Blocks | Purpose |
|------|--------|---------|
| `block-dangerous.sh` | rm -rf, git push --force, sudo, mkfs | Prevent destructive commands |
| `orchestrator-dispatch-gate.sh` | Edit/Write on main thread | Force delegation to subagents |
| `check-spec-approval.sh` | Spec writes without approval | Enforce SDD gates |
| `check-briefing.sh` | Agents without briefing | Ensure proper context |
| `block-spec-read.sh` | Reading specs in implement phase | Enforce information barrier |
| `verify-tests.sh` | Session end with failing tests | Catch regressions |

### Meta-Skills

| Skill | What It Does | Speed |
|-------|-------------|-------|
| `/health quick` | Inline checks (build, lint, types, tests) | ~15s |
| `/health full` | Parallel agents (security, deps, perf, debt) + weighted scoring | ~2min |
| `/audit` | Deep security-focused audit (security + deps + debt) | ~3min |
| `/pre-commit` | Lint, types, tests, security scan on staged changes | ~30s |
| `/status` | Inline status — build, types, lint, tests, git | ~5s |

### Research-Validated Patterns

Patterns adopted from leading frameworks:

| Pattern | Source | What It Does |
|---------|--------|-------------|
| `Why_This_Matters` | oh-my-claudecode | Explains reasoning behind every constraint |
| Dispatcher pattern | dev-kit original | Triage → spawn subagent → structured report |
| Tool restrictions | TapAgents | PreToolUse hook enforces orchestrator-dispatches |
| Config layers | BMAD-METHOD | Three-layer customization without forking |
| Confidence routing | TapAgents | Score routing decisions, surface uncertainty |
| Parallel health | vibecosystem | Fan-out agents, file-based aggregation |

## Architecture

```
dev-kit/
├── scaffold.sh              # Project generator
├── setup.sh                 # Machine bootstrap
├── sync.sh                  # Re-sync base files
├── CLAUDE.md                # Project instructions
│
├── phases/                  # Skills organized by development phase
│   ├── design/skills/       # orient, grill, researcher, approve, ba-validate, spec-align
│   ├── implement/skills/    # sdd, trio, debug, coder-safety
│   ├── review/skills/       # 14 review + meta skills
│   └── shared/              # Hooks, rules, config-resolution
│
├── templates/               # Project templates
│   └── common/              # AGENTS.md.template, lefthook.yml, .claude/
│
├── .claude/workflows/       # Dynamic workflow scripts
├── workflow/                # SDD methodology docs
├── tools/                   # Standalone tooling
└── docs/                    # Documentation
```

## Conventions

- Shell scripts: bash, `set -euo pipefail`, idempotent
- Skills: markdown with YAML frontmatter, dispatcher pattern
- Hooks: bash, receive JSON on stdin, exit 0 = allow, exit 2 = block
- Config: YAML frontmatter in markdown, LLM-as-resolver (no Python dependency)

## Language Bias

Default: TypeScript + Vitest. To adapt:
- Replace `package.json` / `tsconfig.json` / `vitest.config.ts` in `scaffold.sh`
- Update `templates/common/lefthook.yml` pre-commit hooks
- Modify `templates/common/AGENTS.md.template` code style section

The agent infrastructure is language-agnostic.

## License

MIT
