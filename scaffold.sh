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

# Playwright artifacts (baselines are tracked, these are not)
test-results/
playwright-report/
blob-report/
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
- Spec-driven development with implementation protocol (wave dispatch, gate sequence)
- File-based issue tracking
EOF

cat > .agents/knowledge/workflow.md << EOF
# Workflow: Spec-Driven Development (SDD)

## Pipeline Stages
plan → test → sprint → review → retro → done | failed

## Sprint Sub-Gates
green → wiring → visual → hidden → alignment → activation

## Roles
- Supervisor: orchestrate, never write code
- Test-manager: own RED gate (persistent)
- Coder: make tests pass (ephemeral, never sees spec)
- Reviewer: verify spec intent (ephemeral)

See .pipeline/transitions.json for the canonical state machine.
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
3. Begin SDD cycle
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

## Workflow (SDD — Spec-Driven Development)

Features are built through a 3-phase lifecycle. **Do not skip phases.**

### Phase 1: Design (interactive — user makes decisions)
\`\`\`
/grill <topic>       → Design interview (Q&A, explores design space)
/ba-validate <spec>  → Validate spec quality
/approve <spec>      → Approve spec for implementation
\`\`\`

### Phase 2: Implement (automatic — walk away)
\`\`\`
/sdd <feature>       → Full pipeline: plan → test → code → review → retro
\`\`\`

### Phase 3: Review (human — evaluate results)
- Play with the feature, file issues if changes needed
- Run /sdd again for fixes, /grill for design changes

See @AGENTS.md for agent roles and coder workflow.

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
cp "$SCRIPT_DIR/phases/shared/hooks/block-dangerous.sh" .claude/hooks/block-dangerous.sh
cp "$SCRIPT_DIR/phases/shared/hooks/verify-tests.sh" .claude/hooks/verify-tests.sh
cp "$SCRIPT_DIR/phases/implement/hooks/check-briefing.sh" .claude/hooks/check-briefing.sh
cp "$SCRIPT_DIR/phases/implement/hooks/block-spec-read.sh" .claude/hooks/block-spec-read.sh
chmod +x .claude/hooks/block-dangerous.sh .claude/hooks/verify-tests.sh .claude/hooks/check-briefing.sh .claude/hooks/block-spec-read.sh

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
      },
      {
        "matcher": "Read",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/block-spec-read.sh"
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
for phase_dir in design implement review; do
  if [ -d "$SCRIPT_DIR/phases/$phase_dir/agents" ]; then
    cp "$SCRIPT_DIR/phases/$phase_dir/agents/"*.md .claude/agents/ 2>/dev/null || true
  fi
done

# --- .claude/rules/ ---
for phase_dir in design implement review shared; do
  if [ -d "$SCRIPT_DIR/phases/$phase_dir/rules" ]; then
    cp "$SCRIPT_DIR/phases/$phase_dir/rules/"*.md .claude/rules/ 2>/dev/null || true
  fi
done

# --- .claude/skills/ ---
for phase_dir in design implement shared; do
  if [ -d "$SCRIPT_DIR/phases/$phase_dir/skills" ]; then
    cp -r "$SCRIPT_DIR/phases/$phase_dir/skills/"* .claude/skills/ 2>/dev/null || true
  fi
done

# --- .claude/workflows/ (workflow scripts) ---
if [ -d "$SCRIPT_DIR/.claude/workflows" ]; then
  mkdir -p .claude/workflows
  cp "$SCRIPT_DIR/.claude/workflows/"*.md .claude/workflows/ 2>/dev/null || true
fi

# --- .claude/project/ (extensibility overlay — never touched by sync.sh) ---
mkdir -p .claude/project/{agents,rules,skills,hooks}
cat > .claude/project/README.md << 'PROJEOF'
# Project Extensions

Files in this directory are project-specific. They are NEVER overwritten by sync.sh.

## How to extend

- **Custom agents:** Drop .md files in agents/ — they appear alongside base agents
- **Custom rules:** Drop .md files in rules/ — auto-loaded with base rules (same name = override)
- **Custom skills:** Drop directories with SKILL.md in skills/ — appear alongside base skills
- **Custom hooks:** Drop .sh files in hooks/, register in settings.local.json
PROJEOF

# --- .claude/settings.local.json (project overlay, gitignored) ---
cat > .claude/settings.local.json << 'SLEOF'
{
  "permissions": { "allow": [] },
  "hooks": {}
}
SLEOF

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

# --- Visual testing (Playwright) ---
if [ "$MINIMAL" -eq 0 ]; then
  VISUAL_DIR="$SCRIPT_DIR/templates/common/visual-testing"
  if [ -d "$VISUAL_DIR" ]; then
    # Copy Playwright config
    cp "$VISUAL_DIR/playwright.config.ts" playwright.config.ts

    # Copy visual test templates
    mkdir -p tests/visual
    cp "$VISUAL_DIR/tests/visual/"*.spec.ts tests/visual/ 2>/dev/null || true

    # Create screenshots directory for baselines
    mkdir -p screenshots/baselines
    echo "# Visual regression baselines — commit these" > screenshots/baselines/.gitkeep

    # Copy gate scripts to project (quality gates)
    mkdir -p scripts
    GATES_DIR="$SCRIPT_DIR/phases/review/gates"
    for gate in visual-gate.sh visual-regression.sh accessibility-check.sh ui-visual-check.sh; do
      if [ -f "$GATES_DIR/$gate" ]; then
        cp "$GATES_DIR/$gate" "scripts/$gate"
        chmod +x "scripts/$gate"
      fi
    done

    # Create DESIGN.md template if it doesn't exist
    mkdir -p docs
    if [ ! -f "docs/DESIGN.md" ]; then
      cat > docs/DESIGN.md << 'DESIGNEOF'
# Design System

## Colors
- Primary: var(--color-primary) = #2563eb
- Background: var(--color-bg) = #ffffff
- Text: var(--color-text) = #1f2937

## Spacing
- xs: 4px, sm: 8px, md: 16px, lg: 24px, xl: 32px

## Typography
- Body: 16px/1.5 Inter
- Heading: 24px/1.2 Inter Bold

## Components
- Button: min-height 44px, border-radius 6px
- Card: padding 16px, border 1px solid var(--color-border)
- Input: height 40px, padding 8px 12px

## Layout
- Max content width: 1200px
- Sidebar: 256px fixed
- Grid gap: 16px
DESIGNEOF
    fi

    # Add Playwright + axe-core to devDependencies
    # (will be installed by npm install below)
    if ! node --input-type=module -e "
      import { readFileSync, writeFileSync } from 'fs';
      const pkg = JSON.parse(readFileSync('./package.json', 'utf-8'));
      pkg.devDependencies = pkg.devDependencies || {};
      pkg.devDependencies['@playwright/test'] = '^1.50.0';
      pkg.devDependencies['@axe-core/playwright'] = '^4.10.0';
      pkg.scripts = pkg.scripts || {};
      pkg.scripts['test:visual'] = 'npx playwright test --project=visual';
      pkg.scripts['test:a11y'] = 'npx playwright test --project=a11y';
      pkg.scripts['test:visual:update'] = 'npx playwright test --project=visual --update-snapshots';
      writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
    " 2>&1; then
      echo "WARNING: Failed to add Playwright dependencies to package.json"
    fi
  fi
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
git commit -m "feat: initial scaffold with SDD infrastructure" --quiet

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
