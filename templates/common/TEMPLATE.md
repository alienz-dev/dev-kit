# Common Project Template

Files every project gets regardless of language/framework.

## Project State Files

### STATUS.md
```markdown
# <Name> — Status

## Current Version: v0.1.0
## Phase: 1 — Foundation

## What's Working
- [x] Project scaffolded
- [x] Agent config created
- [x] Tests running

## What's Next
- [ ] First feature spec

## Version History
| Version | Date | Changes |
|---------|------|---------|
| v0.1.0 | YYYY-MM-DD | Initial scaffold |
```

### NEXT-SESSION.md
```markdown
# <Name> — Next Session

## Resume From
<Exact next action — not "continue with X" but specific step>

## Priority Order
1. ...
2. ...

## Context
<Anything the next session needs to know>
```

### CONTEXT.md (Ubiquitous Language)
```markdown
# <Name> — Ubiquitous Language

Terms used precisely in specs, tests, and agent communication.

| Term | Meaning | NOT this |
|------|---------|----------|
| ... | ... | ... |
```

### DECISIONS.md
```markdown
# <Name> — Architecture Decision Records

## ADR-001: <Decision Title>
**Date:** YYYY-MM-DD
**Status:** Accepted | Superseded | Deprecated
**Context:** <Why this decision was needed>
**Decision:** <What was decided>
**Rationale:** <Why this option over alternatives>
**Consequences:** <What changes as a result>
```

## Agent Infrastructure

Agent definitions live in `.claude/agents/` (14 roles), rules in `.claude/rules/`, skills in `.claude/skills/`, hooks in `.claude/hooks/`, and workflows in `.claude/workflows/`. All are copied from the dev-kit's `phases/` directory during scaffold.

### Key Files
- `.claude/agents/*.md` — role-specific agent definitions (frontmatter + instructions)
- `.claude/rules/CONSOLIDATED.md` — universal safety rules loaded by every agent
- `.claude/rules/ROLES.md` — role registry, dispatch rules, contracts
- `.claude/rules/HANDOFF.md` — inter-role data exchange protocols
- `.claude/rules/complexity-scoring.md` — agent spawning thresholds
- `.claude/settings.json` — hooks, permissions, tool allowlists

## TypeScript Defaults

### tsconfig.json
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "outDir": "dist",
    "rootDir": "src",
    "declaration": true,
    "sourceMap": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist", "tests"]
}
```

### vitest.config.ts
```typescript
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    globals: true,
    root: '.',
    include: ['tests/**/*.test.{ts,tsx}'],
    pool: 'threads',  // NEVER 'forks' — orphan workers OOM
    testTimeout: 10000,
    poolOptions: { threads: { maxThreads: 4 } },
  },
})
```

### .gitignore
```
node_modules/
dist/
.next/
*.tsbuildinfo
.env
.env.local
/tmp/
```

## Directory Structure

```
project/
├── src/                    # Source code
├── tests/                  # Test files (mirror src/ structure)
│   ├── unit/               # Unit tests
│   └── hidden/             # Hidden regression tests (coder never sees)
├── specs/                  # Feature specifications (DO NOT READ as coder)
│   └── SDD.md             # Process reference
├── issues/                 # Issue tracking (markdown + index)
├── plans/                  # Implementation plans
├── docs/                   # Documentation
├── .claude/
│   ├── agents/             # Agent definitions (14 roles)
│   ├── rules/              # Shared rules (CONSOLIDATED, ROLES, HANDOFF, etc.)
│   ├── skills/             # Skills (grill, sdd, trio, researcher, etc.)
│   ├── hooks/              # Enforcement hooks (block-dangerous, check-spec-approval, etc.)
│   ├── workflows/          # Dynamic workflows (wave-dispatch, adversarial-review, etc.)
│   └── settings.json       # Hooks, permissions, tool allowlists
├── .pipeline/              # Pipeline state (test_map, coder results, gate proofs)
├── STATUS.md
├── NEXT-SESSION.md
├── CONTEXT.md
├── DECISIONS.md
├── package.json
├── tsconfig.json
├── vitest.config.ts
└── .gitignore
```
