# Getting Started — For AI Coding Agents

This guide is for any AI coding agent working in a dev-kit project.

## What This Project Uses

**Spec-Driven Development (SDD):** Every feature starts as a specification. Tests are written from the spec. You implement from the tests — never from the spec directly.

**TRIO Protocol (Test → Red → Implement → Observe):** Tests are written first and verified to fail (RED). You make them pass (GREEN). A reviewer checks the result. This ensures tests actually verify behavior.

**Pipeline Gates:** Automated checks enforce quality at each stage. You cannot skip them.

## Your Workflow (6 Steps)

1. **Read AGENTS.md** — project commands, boundaries, code style
2. **Read your briefing** — task description, test file paths, result path
3. **Read the failing tests** — understand expected behavior from assertions
4. **Implement** — minimal code to make tests pass
5. **Verify** — run `npm test` (GREEN) + `npm run typecheck` (clean)
6. **Write result** — to the path specified in your briefing

## Rules

- You work from **tests only** — do NOT read `specs/` directory
- One change → verify → next change. Never stack unverified changes.
- If tests fail after your change, fix before moving on. DO NOT SKIP.
- Write your result file when done (even if you failed)

## Finding Commands

All project commands are in `AGENTS.md` at the project root. Common ones:
- `npm test` — run all tests
- `npx vitest run tests/<path>` — run specific test
- `npm run typecheck` — type check (never run raw `tsc`)

## Environment Detection

If `infra/scripts/env-detect.sh` exists in the dev-kit, run it to discover your environment:
```bash
bash /path/to/dev-kit/infra/scripts/env-detect.sh
cat /tmp/env-context.md
```

## Pipeline State (if present)

If `.pipeline/state.json` exists, the project tracks pipeline stages:
```bash
# Check current stage
cat .pipeline/state.json | grep stage

# You should only be implementing during "sprint" stage
```

## Result File Format

```markdown
## Status
success | failed

## Changes
<list of files you modified>

## Verification Output
<exact command run + output>
```
