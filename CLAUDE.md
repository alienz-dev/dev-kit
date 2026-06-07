# dev-kit — Project Instructions

This is the dev-kit repository itself (a toolkit, not a scaffolded project).
The standard agent rules from `agents/` apply here with the following overrides.

## What This Repo Is

A portable AI-native development toolkit. Shell scripts + markdown templates.
No compiled code, no package.json at root, no test suite to run.

## Key Files

- `scaffold.sh` — generates new projects with agent infrastructure
- `setup.sh` — bootstraps a fresh machine (Node, git, Claude Code, submodules)
- `templates/` — project templates copied by scaffold
- `agents/` — agent role definitions and rules
- `workflow/` — SDD, TRIO, pipeline methodology
  - `dynamic-workflows-guide.md` — when and how to use dynamic workflows
- `.claude/workflows/` — reusable workflow scripts (adversarial-review, wave-dispatch, sdd-test-gen, sdd-review, sdd-retro, sdd-implement, deep-audit, migration-sweep, research-crosscheck)
- `tools/` — specialized tooling (explainer, issue-cli)

## Skills Architecture

### Global Skills (available in every Claude Code session)

Installed at `~/.claude/skills/`. Useful in any project, regardless of SDD.

| Skill | Phase | Purpose |
|-------|-------|---------|
| `/orient` | Design | Map codebase structure, tech stack, architecture |
| `/grill` | Design | Design tree interview — exhaustive Q&A |
| `/researcher` | Design | Deep investigation with parallel explorers (ARIA v2) |
| `/debug` | Implement | Dispatch debugger subagent |
| `/quick-review` | Review | Lightweight single-pass code review |
| `/security-audit` | Review | OWASP Top 10, auth, crypto, secrets scanning |
| `/dep-audit` | Review | CVEs, licenses, supply chain, outdated packages |
| `/perf-profile` | Review | N+1 queries, algorithmic bottlenecks, caching |
| `/tech-debt` | Review | Dead code, complexity, pattern drift |
| `/docs` | Review | API docs, README, onboarding guides |
| `/release` | Review | Changelog, version bump, pre-flight checks |
| `/a11y` | Review | WCAG 2.1 AA compliance, keyboard nav, ARIA |
| `/api-design` | Review | REST conventions, versioning, backward compat |
| `/health` | Meta | Parallel health agents, weighted scoring, trends |
| `/audit` | Meta | Deep security-focused audit (security + deps + debt) |
| `/pre-commit` | Meta | Pre-commit checks — lint, types, tests, security |
| `/status` | Meta | Quick inline status — build, types, lint, tests, git |
| `/scaffold` | Meta | Scaffold new project or retrofit AI infrastructure |

### SDD Skills (bundled in scaffolded projects only)

Installed at `{project}/.claude/skills/` by `scaffold.sh`. Part of the SDD methodology.

| Skill | Phase | Purpose |
|-------|-------|---------|
| `/sdd` | Implement | Full SDD pipeline: plan → test → code → review → retro |
| `/trio` | Implement | Sprint-only wave dispatch with worktree isolation |
| `/approve` | Design | Approve spec for implementation |
| `/ba-validate` | Design | Validate spec quality (structural + semantic) |
| `/spec-align` | Design | Compare spec vs code, find divergences |

### Auto-Routing Protocol

**Do not wait for the user to type `/skill-name`.** When the user's message matches a skill's trigger pattern, invoke it automatically via the Skill tool. Use this routing table:

| User Intent (keywords/phrases) | Auto-Invoke | Example |
|-------------------------------|-------------|---------|
| "what is this", "how does this work", "where is X", "map the codebase" | `/orient` | "how does auth work?" → `/orient auth` |
| "design X", "let's think about", "what should we build", "explore options" | `/grill` | "let's design the API" → `/grill API design` |
| "research X", "investigate", "compare X vs Y", "what are best practices for" | `/researcher` | "research caching strategies" → `/researcher caching strategies` |
| "this is broken", "fix this bug", "tests failing", "error:", "TypeError", "assertion" | `/debug` | "TypeError at auth.ts:42" → `/debug TypeError at auth.ts:42` |
| "review this", "look at this code", "check this PR", "feedback on" | `/quick-review` | "review the auth module" → `/quick-review src/auth/` |
| "security", "vulnerability", "CVE", "injection", "auth review", "check for secrets" | `/security-audit` | "check auth for vulnerabilities" → `/security-audit src/auth` |
| "dependencies", "npm audit", "outdated", "license", "CVE in deps" | `/dep-audit` | "any CVEs?" → `/dep-audit` |
| "slow", "performance", "N+1", "optimize", "bottleneck", "latency" | `/perf-profile` | "this endpoint is slow" → `/perf-profile <endpoint>` |
| "tech debt", "dead code", "cleanup", "refactor priorities", "code health" | `/tech-debt` | "what needs cleanup?" → `/tech-debt` |
| "document", "write docs", "API docs", "README", "onboarding" | `/docs` | "document the API" → `/docs API` |
| "release", "changelog", "version bump", "what changed" | `/release` | "prepare release" → `/release` |
| "accessibility", "WCAG", "a11y", "screen reader", "keyboard" | `/a11y` | "check accessibility" → `/a11y` |
| "design API", "new endpoint", "API contract", "REST" | `/api-design` | "design user API" → `/api-design users` |
| "health", "how healthy", "full picture", "status dashboard" | `/health` | "how's the project?" → `/health` |
| "full audit", "compliance", "security audit everything" | `/audit` | "audit everything" → `/audit` |
| "pre-commit", "ready to commit", "check before commit" | `/pre-commit` | "am I good?" → `/pre-commit` |
| "status", "what's the state", "are we good", "quick check" | `/status` | "quick status" → `/status` |

**Routing rules:**
1. Match on **intent**, not exact phrasing. "this is slow" = "optimize" = "performance"
2. If multiple skills match, pick the **most specific** one. "the auth is broken and has CVEs" → `/security-audit` (not `/debug`)
3. If the user says "implement X" or "build X" and a spec exists, route to `/sdd`
4. If the user says "implement X" and no spec exists, route to `/grill` first
5. When in doubt, `/orient` first to understand the codebase, then re-route

### Skills Sync

**When changing bundled skills, also update the global copies:**

```bash
# Global skills (copy these to ~/.claude/skills/)
cp -r phases/design/skills/orient ~/.claude/skills/orient
cp -r phases/design/skills/grill ~/.claude/skills/grill
cp -r phases/design/skills/researcher ~/.claude/skills/researcher
cp -r phases/implement/skills/debug ~/.claude/skills/debug
cp -r phases/review/skills/quick-review ~/.claude/skills/quick-review
cp -r phases/review/skills/security-audit ~/.claude/skills/security-audit
cp -r phases/review/skills/dep-audit ~/.claude/skills/dep-audit
cp -r phases/review/skills/perf-profile ~/.claude/skills/perf-profile
cp -r phases/review/skills/tech-debt ~/.claude/skills/tech-debt
cp -r phases/review/skills/release ~/.claude/skills/release
cp -r phases/review/skills/docs ~/.claude/skills/docs
cp -r phases/review/skills/a11y ~/.claude/skills/a11y
cp -r phases/review/skills/api-design ~/.claude/skills/api-design
cp -r phases/review/skills/health ~/.claude/skills/health
cp -r phases/review/skills/audit ~/.claude/skills/audit
cp -r phases/review/skills/pre-commit ~/.claude/skills/pre-commit
cp -r phases/review/skills/status ~/.claude/skills/status
```

Or use `sync.sh` if working from a scaffolded project.

### Redeployment Protocol

**When ANY skill is changed (SKILL.md or config.default.md), redeploy to global:**

```bash
# From dev-kit repo root
cd /Users/ding/projects/dev-kit

# Sync a specific skill
cp -r phases/<phase>/skills/<skill-name> ~/.claude/skills/<skill-name>

# Or sync all global skills at once
for skill in orient grill researcher debug quick-review security-audit dep-audit perf-profile tech-debt docs release a11y api-design health audit pre-commit status; do
  cp -r phases/*/skills/$skill ~/.claude/skills/$skill 2>/dev/null
done
```

**What needs redeployment:**
- SKILL.md changes (skill logic, triggers, output format)
- config.default.md changes (default configuration values)
- Hook changes (phases/shared/hooks/, phases/implement/hooks/)
- AGENTS.md.template changes (affects scaffolded projects — re-scaffold or manual update)
- CLAUDE.md changes (affects this project only)

**SDD skills (bundled only, no global redeploy):** sdd, trio, approve, ba-validate, spec-align, coder-safety

### Customization

Skills support three-layer configuration (from BMAD pattern):

1. **Skill defaults**: `{skill-root}/config.default.md` (shipped, never edited)
2. **Project overrides**: `.claude/config/{skill-name}.md` (committed to git)
3. **User overrides**: `~/.claude/config/{skill-name}.md` (gitignored, personal)

Merge rules: scalars override (higher layer wins), tables deep-merge, arrays append.

Config fields: `model`, `strictness`, `scope.include/exclude`, `thresholds`, `custom_rules`, `output_format`, `persistent_facts`.

### Hooks

Installed by `scaffold.sh` into `.claude/hooks/`:

| Hook | Trigger | Purpose |
|------|---------|---------|
| `block-dangerous.sh` | Bash | Block rm -rf, git push --force, etc. |
| `orchestrator-dispatch-gate.sh` | Edit\|Write\|NotebookEdit | Enforce orchestrator-dispatches pattern |
| `verify-tests.sh` | Stop | Verify tests pass before session end |
| `check-spec-approval.sh` | Write\|Edit | Block spec writes without approval |
| `check-briefing.sh` | Agent | Verify agent has proper briefing |
| `block-spec-read.sh` | Read | Block reading specs in wrong phase |

### Confidence-Scored Routing

AGENTS.md template includes a 5-signal confidence scoring rubric for routing decisions:

| Score | Action |
|-------|--------|
| ≥ 0.85 | Auto-proceed with matched skill |
| 0.70–0.84 | Proceed, log routing decision |
| 0.50–0.69 | Ask user to confirm or clarify |
| < 0.50 | Spawn explorer to gather context |

## Conventions

- Shell scripts: bash, `set -euo pipefail`, idempotent
- Docs: markdown, no line-length limit
- Templates use `{{PROJECT_NAME}}` placeholders (substituted by scaffold.sh)
- Submodules (`tools/issue-cli`) require GitHub access
- Skills use `Why_This_Matters` sections to explain constraint reasoning
- Skills use dispatcher pattern: triage scope → spawn subagent → structured report

## Language Bias

The scaffold generates TypeScript + Vitest projects by default. This is a
starting point, not a constraint. To adapt for other languages:
- Replace `package.json` / `tsconfig.json` / `vitest.config.ts` generation in `scaffold.sh`
- Update `templates/common/lefthook.yml` pre-commit hooks
- Modify `templates/common/AGENTS.md.template` code style section

## What NOT To Do

- Don't run `npm install` at repo root (there's no package.json)
- Don't treat this as a scaffolded project — it's the toolkit that creates them
- Don't modify `templates/` without considering impact on all scaffolded projects
- Don't install SDD-specific skills globally (sdd, trio, approve, ba-validate, spec-align, coder-safety)
