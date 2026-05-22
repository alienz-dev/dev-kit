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

### .agents/knowledge/project.md
```markdown
# <Name> — Project Knowledge

## Architecture
<Brief architecture description>

## Tech Stack
- Language: TypeScript / Python / Go
- Framework: <framework>
- Testing: vitest / pytest / go test
- Build: <build tool>

## Key Patterns
- <Pattern 1>
- <Pattern 2>

## Spec-Driven TDD
Constitution at .agents/constitution.yml defines gates.
Lifecycle: open → specced → tests_written → red_verified → implementing → green → reviewing → closed
```

### .agents/knowledge/workflow.md
```markdown
# Workflow: Spec-Driven TDD

## Issue Lifecycle
open → specced → tests_written → red_verified → implementing → green → reviewing → closed

## Gate Requirements
| From | To | Gate |
|------|----|------|
| open | specced | Spec file exists and is linked |
| specced | tests_written | Test files exist with assertions |
| tests_written | red_verified | All tests fail (RED) |
| red_verified | implementing | Coder assigned |
| implementing | green | All visible tests pass |
| green | reviewing | Reviewer assigned |
| reviewing | closed | Approved AND hidden tests pass |
```

### .agents/constitution.yml
```yaml
forward_transitions:
  - from: open
    to: specced
    gate: spec_linked
  - from: specced
    to: tests_written
    gate: tests_exist
  - from: tests_written
    to: red_verified
    gate: all_tests_fail
  - from: red_verified
    to: implementing
    gate: coder_assigned
  - from: implementing
    to: green
    gate: visible_tests_pass
  - from: green
    to: reviewing
    gate: reviewer_assigned
  - from: reviewing
    to: closed
    gate: approved_and_hidden_pass
```

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
├── specs/                  # Feature specifications
│   └── SDD.md             # Process reference
├── issues/                 # Issue tracking (markdown + index)
├── plans/                  # Implementation plans
├── docs/                   # Documentation
├── .agents/
│   ├── knowledge/          # Project knowledge (read-only for agents)
│   ├── workspace/          # Agent workspace state
│   ├── constitution.yml    # TRIO gates
│   └── agents.yml          # Agent definitions
├── STATUS.md
├── NEXT-SESSION.md
├── CONTEXT.md
├── DECISIONS.md
├── package.json
├── tsconfig.json
├── vitest.config.ts
└── .gitignore
```
