#!/bin/bash
# scaffold.sh — Create a new project with full AI-native development infrastructure
set -euo pipefail

NAME="${1:?Usage: scaffold.sh <project-name> [--minimal]}"
MINIMAL=0
for arg in "$@"; do
  case "$arg" in --minimal) MINIMAL=1 ;; esac
done
# If --minimal is $2, use default project dir
if [ "$MINIMAL" -eq 1 ] && [ "${2:-}" = "--minimal" ]; then
  PROJECT_DIR="$HOME/projects/$NAME"
elif [ "$MINIMAL" -eq 1 ] && [ "${3:-}" = "--minimal" ]; then
  PROJECT_DIR="${2:-$HOME/projects/$NAME}"
else
  PROJECT_DIR="${2:-$HOME/projects/$NAME}"
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -d "$PROJECT_DIR/.git" ]; then
  echo "Error: $PROJECT_DIR already has a git repo"
  exit 1
fi

echo "=== Scaffolding: $NAME ==="
echo "Directory: $PROJECT_DIR"

# --- Create project ---
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"
git init && git branch -m main

# --- Package.json ---
cat > package.json << EOF
{
  "name": "$NAME",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "build": "tsc",
    "test": "vitest run",
    "test:watch": "vitest",
    "typecheck": "node --max-old-space-size=4096 ./node_modules/.bin/tsc --noEmit --incremental"
  },
  "dependencies": {},
  "devDependencies": {
    "@types/node": "22.10.0",
    "typescript": "5.7.3",
    "vitest": "3.1.3"
  },
  "engines": { "node": ">=22" }
}
EOF

# --- tsconfig ---
cat > tsconfig.json << EOF
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
EOF

# --- vitest ---
cat > vitest.config.ts << EOF
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    globals: true,
    root: '.',
    include: ['tests/**/*.test.{ts,tsx}'],
    pool: 'threads',
    testTimeout: 10000,
    poolOptions: { threads: { maxThreads: 4 } },
  },
})
EOF

# --- gitignore ---
cat > .gitignore << EOF
node_modules/
dist/
*.tsbuildinfo
.env
.env.local
/tmp/
EOF

# --- Source dirs ---
mkdir -p src tests
if [ "$MINIMAL" -eq 0 ]; then
  mkdir -p specs issues plans docs
fi

# --- Agent infrastructure ---
if [ "$MINIMAL" -eq 0 ]; then
mkdir -p .agents/{knowledge,workspace,scripts,hooks}

cat > .agents/knowledge/project.md << EOF
# $NAME — Project Knowledge

## Architecture
<Brief architecture description>

## Tech Stack
- Language: TypeScript
- Runtime: Node.js 22
- Testing: vitest (threads pool)
- Build: tsc

## Key Patterns
- Spec-driven development (SDD)
- TRIO protocol (Test → Red → Implement → Observe)
- File-based issue tracking
EOF

cat > .agents/knowledge/workflow.md << EOF
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

## Roles
- Supervisor: orchestrate, never write code
- Test-manager: own RED→GREEN cycle (persistent)
- Coder: make tests pass (ephemeral, never sees spec)
- Reviewer: verify spec intent (ephemeral)
EOF

cat > .agents/constitution.yml << EOF
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
EOF

cat > .agents/agents.yml << EOF
project:
  name: $NAME
  repo: $PROJECT_DIR
runtime:
  agent_cli: kiro
  multiplexer: zellij
agents:
  - id: supervisor
    tools: [fs_read, glob, grep, execute_bash]
    write_paths: [/tmp/, issues/, plans/, specs/]
  - id: coder
    tools: [fs_read, fs_write, execute_bash, grep, glob]
    write_paths: [src/, tests/, /tmp/]
  - id: tester
    tools: [fs_read, fs_write, execute_bash]
    write_paths: [tests/, /tmp/]
  - id: reviewer
    tools: [fs_read, execute_bash]
    write_paths: [/tmp/]
preflight:
  - check: command
    name: Node 22 available
    command: node --version | grep -q v22
  - check: command
    name: Dependencies installed
    command: test -d node_modules
    fix: npm install
EOF
fi # end MINIMAL check for agent infrastructure

# --- Specs ---
if [ "$MINIMAL" -eq 0 ]; then
cp "$SCRIPT_DIR/workflow/sdd/SDD.md" specs/SDD.md

# --- Copy tools reference ---
mkdir -p .tools
cp "$SCRIPT_DIR/workflow/grill/GRILL.md" .tools/GRILL.md 2>/dev/null || true
cp "$SCRIPT_DIR/workflow/trio/TRIO.md" .tools/TRIO.md 2>/dev/null || true

cat > specs/README.md << EOF
# Specifications

Process: [SDD.md](SDD.md) — Spec-Driven Development lifecycle.

## Spec Index

| Spec | Status | Description |
|---|---|---|
| (none yet) | | |

## Creating a New Spec

1. Copy an existing spec as template.
2. Set \`status: draft\` in frontmatter.
3. Define sections with acceptance criteria.
4. Get approval → ready for planning.
5. Add entry to this table.
EOF

# --- Project state files ---
DATE=$(date +%Y-%m-%d)

cat > STATUS.md << EOF
# $NAME — Status

## Current Version: v0.1.0 (scaffold)
## Phase: 1 — Foundation

## What's Working
- [x] Project scaffolded
- [x] Agent config created
- [x] Test infrastructure ready

## What's Next
- [ ] First feature spec
- [ ] First issue

## Version History
| Version | Date | Changes |
|---------|------|---------|
| v0.1.0 | $DATE | Initial scaffold |
EOF

cat > NEXT-SESSION.md << EOF
# $NAME — Next Session

## Resume From
Write first feature spec in specs/

## Priority Order
1. Define first feature as spec
2. Create issue linking to spec
3. Begin TRIO cycle
EOF

cat > CONTEXT.md << EOF
# $NAME — Ubiquitous Language

## Core Concepts
| Term | Definition |
|------|-----------|
| Spec | Feature specification (WHAT + WHY) |
| Plan | Implementation plan derived from spec (HOW + ORDER) |
| Gate | Automated check that must pass before state transition |
| Hidden test | Regression test the coder never sees |
EOF

cat > DECISIONS.md << EOF
# $NAME — Architecture Decision Records

## ADR-001: TypeScript + Vitest + SDD
**Date:** $DATE
**Status:** Accepted
**Context:** Need a typed language with fast test runner and spec-driven workflow.
**Decision:** TypeScript with vitest (threads pool) and spec-driven TDD.
**Rationale:** Type safety catches errors early, vitest is fast, SDD ensures specs before code.
**Consequences:** All features need specs. Tests run in threads (never forks).
EOF
fi # end MINIMAL check for specs/tools/NEXT-SESSION/DECISIONS

# --- AGENTS.md (cross-tool instructions) ---
sed "s/{{PROJECT_NAME}}/$NAME/g" "$SCRIPT_DIR/templates/common/AGENTS.md.template" > AGENTS.md
ln -sf AGENTS.md CLAUDE.md

# --- Lefthook (pre-commit gate) ---
if [ -f "$SCRIPT_DIR/templates/common/lefthook.yml" ]; then
  cp "$SCRIPT_DIR/templates/common/lefthook.yml" lefthook.yml
fi

# --- Pipeline state ---
mkdir -p .pipeline
cp "$SCRIPT_DIR/workflow/pipeline/transitions.json" .pipeline/transitions.json

# --- Kiro agent JSON ---
if [ "$MINIMAL" -eq 0 ]; then
mkdir -p ~/.kiro/agents

cat > ~/.kiro/agents/${NAME}.json << EOF
{
  "name": "$NAME",
  "description": "$NAME project supervisor",
  "model": "claude-sonnet-4-20250514",
  "prompt": "You are the $NAME project supervisor at $PROJECT_DIR.\n\nOn session start:\n1. Read: STATUS.md, NEXT-SESSION.md, CONTEXT.md\n2. Read: .agents/knowledge/workflow.md\n3. Run: npm run typecheck\n4. Present state and ask for direction\n\nYou orchestrate and delegate. You do NOT write source code.\nDelegate to spawned workers (coder, tester, reviewer).\n\nFollow spec-driven TDD:\n- Write spec → spawn test-manager → verify RED → spawn coder → verify GREEN → spawn reviewer → close\n\nAvailable skills:\n- grill <topic>: Design tree interview before planning (read .tools/GRILL.md)\n- TRIO protocol: Test→Red→Implement→Observe (read .tools/TRIO.md)\n- explainer: Generate visual HTML presentations",
  "toolsSettings": {
    "write": {
      "deniedPaths": ["**/src/**", "**/tests/**", "**/*.ts", "**/*.tsx", "**/*.js"]
    }
  },
  "tools": ["fs_read", "fs_write", "grep", "execute_bash", "glob"],
  "allowedTools": ["fs_read", "fs_write", "grep", "execute_bash", "glob"],
  "resources": [
    "file://$PROJECT_DIR/.agents/knowledge/workflow.md",
    "file://$PROJECT_DIR/.agents/knowledge/project.md"
  ]
}
EOF
fi # end MINIMAL check for kiro agent JSON

# --- Install deps ---
echo ""
echo "Installing dependencies..."
npm install --silent 2>/dev/null

# --- Initial commit ---
git add -A
git commit -m "feat: initial scaffold with SDD/TRIO infrastructure" --quiet

echo ""
echo "=== Done ==="
echo ""
echo "Project created at: $PROJECT_DIR"
echo "Agent config at: ~/.kiro/agents/${NAME}.json"
echo ""
echo "Next steps:"
echo "  cd $PROJECT_DIR"
echo "  zellij --session $NAME"
echo "  kiro-cli chat --agent $NAME"
