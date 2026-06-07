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

## Skills Sync

Bundled skills live in `phases/*/skills/` and are copied by `scaffold.sh` into new projects.
Global skills live at `~/.claude/skills/` and are available in every session.

**When changing bundled skills, also update the global copies:**

```bash
cp -r phases/design/skills/orient ~/.claude/skills/orient
cp -r phases/design/skills/grill ~/.claude/skills/grill
cp -r phases/implement/skills/debug ~/.claude/skills/debug
cp -r phases/implement/skills/sdd ~/.claude/skills/sdd
cp -r phases/review/skills/quick-review ~/.claude/skills/quick-review
```

Or use `sync.sh` if working from a scaffolded project.

Skills that are global-only (not bundled):
- `~/.claude/skills/scaffold/` — project scaffolding and retrofit

## Conventions

- Shell scripts: bash, `set -euo pipefail`, idempotent
- Docs: markdown, no line-length limit
- Templates use `{{PROJECT_NAME}}` placeholders (substituted by scaffold.sh)
- Submodules (`tools/issue-cli`) require GitHub access

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
