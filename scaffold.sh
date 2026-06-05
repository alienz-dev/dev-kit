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
# constitution.yml — project-level pipeline config
# State definitions are in transitions.json (single source of truth).
# See .pipeline/transitions.json for stage definitions and gate checks.
constraints:
  max_coder_parallel: 3
  max_green_retries: 3
  max_visual_retries: 2
EOF

cat > .agents/agents.yml << EOF
project:
  name: $NAME
  repo: $PROJECT_DIR
runtime:
  agent_cli: claude
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

# --- CLAUDE.md (lean, <80 lines, uses @ imports) ---
cat > CLAUDE.md << EOF
# $NAME

## Commands
- Install: \`npm install\`
- Build: \`npm run build\`
- Typecheck: \`npm run typecheck\`
- Test all: \`npm test\`
- Test single: \`npx vitest run tests/<path>\`

## Workflow
Spec-driven TDD with TRIO protocol. Read @AGENTS.md for full details.

## Rules
@.claude/rules/safety.md
@.claude/rules/code-style.md
@.claude/rules/testing.md

## Agents
Custom agents in .claude/agents/: coder, reviewer, test-manager, researcher, explorer

## Boundaries
- src/ and tests/ — writable
- specs/, .agents/, .pipeline/ — read-only for agents
- Never pool:forks in vitest, never raw tsc --noEmit
EOF

# --- .claude/ directory structure ---
mkdir -p .claude/{agents,rules,skills,hooks}

# --- .claude/hooks/ ---
cp "$SCRIPT_DIR/templates/common/claude-code/hooks/block-dangerous.sh" .claude/hooks/block-dangerous.sh
cp "$SCRIPT_DIR/templates/common/claude-code/hooks/verify-tests.sh" .claude/hooks/verify-tests.sh
cp "$SCRIPT_DIR/templates/common/claude-code/hooks/check-briefing.sh" .claude/hooks/check-briefing.sh
chmod +x .claude/hooks/block-dangerous.sh .claude/hooks/verify-tests.sh .claude/hooks/check-briefing.sh

# --- .claude/settings.json ---
cat > .claude/settings.json << EOF
{
  "permissions": {
    "allow": ["Read", "Write", "Edit", "Bash(npm run *)", "Bash(npm test*)", "Bash(git *)", "Bash(npx vitest *)"],
    "deny": ["Bash(rm -rf *)", "Bash(git push --force *)"]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/block-dangerous.sh"
          }
        ]
      },
      {
        "matcher": "Agent",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/check-briefing.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/verify-tests.sh"
          },
          {
            "type": "command",
            "command": "afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 || true"
          }
        ]
      }
    ]
  }
}
EOF

# --- .claude/agents/ ---
if [ -d "$SCRIPT_DIR/templates/common/claude-code/agents" ]; then
  cp "$SCRIPT_DIR/templates/common/claude-code/agents/"*.md .claude/agents/ 2>/dev/null || true
fi

# --- .claude/rules/ ---
if [ -d "$SCRIPT_DIR/templates/common/claude-code/rules" ]; then
  cp "$SCRIPT_DIR/templates/common/claude-code/rules/"*.md .claude/rules/ 2>/dev/null || true
fi

# --- Copy consolidated governance rules ---
if [ -f "$SCRIPT_DIR/agents/rules/CONSOLIDATED.md" ]; then
  cp "$SCRIPT_DIR/agents/rules/CONSOLIDATED.md" .claude/rules/CONSOLIDATED.md
fi

# --- Copy skills ---
if [ -d "$SCRIPT_DIR/agents/skills" ]; then
  cp "$SCRIPT_DIR/agents/skills/"*.md .claude/skills/ 2>/dev/null || true
fi

# --- .claude/skills/ ---
if [ -d "$SCRIPT_DIR/templates/common/claude-code/skills" ]; then
  cp -r "$SCRIPT_DIR/templates/common/claude-code/skills/"* .claude/skills/ 2>/dev/null || true
fi

# --- CLAUDE.local.md (personal overrides, gitignored) ---
cat > CLAUDE.local.md << EOF
# $NAME — Local Overrides (gitignored)

## Personal preferences
# Add your personal Claude Code preferences here

## MCP Servers
# Add project-specific MCP servers in .mcp.json
EOF

# Add to gitignore
echo "CLAUDE.local.md" >> .gitignore
echo ".claude/settings.local.json" >> .gitignore

# --- Lefthook (pre-commit gate) ---
if [ -f "$SCRIPT_DIR/templates/common/lefthook.yml" ]; then
  cp "$SCRIPT_DIR/templates/common/lefthook.yml" lefthook.yml
fi

# --- Pipeline state ---
mkdir -p .pipeline
cp "$SCRIPT_DIR/workflow/pipeline/transitions.json" .pipeline/transitions.json

# --- Install deps ---

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
echo ""
echo "Next steps:"
echo "  cd $PROJECT_DIR"
if command -v claude &>/dev/null; then
  echo "  claude"
else
  echo "  (install claude to start)"
fi
