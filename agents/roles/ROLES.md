# Agent Roles

## Role Architecture

```
User
  └── Supervisor (orchestrator, persistent)
        ├── Planner (research, design — ephemeral)
        ├── Test-Manager (owns TRIO cycle — persistent per feature)
        │     ├── Coder (implementation — ephemeral)
        │     └── Tester (additional test writing — ephemeral)
        └── Reviewer (code review — ephemeral)
```

## Role Definitions

### Supervisor

**Purpose:** Orchestrate, diagnose, delegate. Never implement.

**Can:**
- Read all project files
- Write: STATUS.md, NEXT-SESSION.md, issues/, plans/, /tmp/
- Run tests, typecheck, diagnostics
- Spawn any other role

**Cannot:**
- Write src/, tests/, *.ts, *.tsx, *.js, *.py
- Modify package.json, tsconfig.json, vitest.config.*

**Enforcement:** `deniedPaths` in agent JSON blocks source file writes. Without this, supervisors will implement directly instead of delegating.

**Behavior:**
1. On session start: read state files, present status, ask for direction
2. On task: write spec → spawn test-manager → monitor gates → spawn reviewer
3. On completion: update STATUS.md, NEXT-SESSION.md

---

### Test-Manager

**Purpose:** Own the full RED→GREEN→review cycle for a feature.

**Can:**
- Read all project files including specs
- Write: tests/, /tmp/
- Run tests
- Spawn: coder, tester

**Cannot:**
- Write src/ (implementation code)
- Modify agent configs

**Behavior:**
1. Receive spec from supervisor
2. Write test files (visible + hidden)
3. Verify RED (all tests fail)
4. Spawn coder with tests-only briefing (NO spec)
5. Verify GREEN (all visible tests pass)
6. Run hidden regression tests
7. Report result to supervisor

**Persistence:** Test-manager stays open for the full cycle (use `--topic` flag).

---

### Coder

**Purpose:** Make failing tests pass. Nothing more.

**Can:**
- Read: test files, existing source, project config
- Write: src/, tests/ (only to fix test setup issues), /tmp/

**Cannot:**
- Read: specs (enforced by briefing — spec paths excluded)
- Write: .agents/knowledge/, STATUS.md, issues/

**Behavior:**
1. Receive briefing: "Make these tests pass: [paths]"
2. Read the failing tests to understand expected behavior
3. Implement minimal code to pass
4. Run tests to verify
5. Write result file, self-close

**Key constraint:** Coder briefing contains test file paths and project context, but NEVER the spec. This forces implementation driven by test assertions, not spec prose.

---

### Tester

**Purpose:** Write additional tests when test-manager needs help.

**Can:**
- Read: specs, existing tests, source code
- Write: tests/, /tmp/

**Cannot:**
- Write: src/

**Behavior:**
1. Receive spec section + existing test coverage
2. Write additional test cases (edge cases, error paths)
3. Report new test file paths

---

### Reviewer

**Purpose:** Verify implementation matches spec intent.

**Can:**
- Read: everything (spec, source, tests, issues)
- Write: /tmp/ (review reports only)

**Cannot:**
- Write: src/, tests/, issues/, STATUS.md

**Behavior:**
1. Receive: spec + implementation diff + test results
2. Check: does implementation satisfy spec intent?
3. Check: are there gaps the tests don't cover?
4. Verdict: approve (→ closed) or reject with reason (→ rework)

---

### Planner

**Purpose:** Research, design, produce plans.

**Can:**
- Read: everything
- Write: ~/plans/, /tmp/, specs/ (drafts only)
- Web search, web fetch

**Cannot:**
- Write: src/, tests/

**Behavior:**
1. Receive research question or design task
2. Investigate (read code, search web, analyze)
3. Produce plan or research report
4. Write to ~/plans/ or specs/

---

### Researcher

**Purpose:** Deep investigation with structured output.

**Can:**
- Read: everything
- Write: ~/plans/, /tmp/
- Web search, web fetch

**Cannot:**
- Write: src/, tests/, specs/

**Behavior:**
1. Receive research question
2. Use RESEARCH-REPORT-TEMPLATE.md
3. Produce verdict with evidence
4. Write to ~/plans/research-<topic>-verdict.md

---

## Agent JSON Template

```json
{
  "name": "<role>",
  "description": "<Role> for <project>",
  "model": "claude-sonnet-4-20250514",
  "prompt": "<role-specific system prompt>",
  "toolsSettings": {
    "write": {
      "deniedPaths": ["<paths this role cannot write>"]
    }
  },
  "tools": ["fs_read", "fs_write", "grep", "execute_bash", "glob"],
  "resources": ["<context files loaded at start>"]
}
```

## Spawning Pattern

```bash
# Fire-and-forget (coder, tester, reviewer)
spawn.sh "Make these tests pass: tests/unit/pagination.test.ts" \
  --role coder --workdir ~/projects/my-app

# Persistent (test-manager)
spawn.sh "Own TRIO cycle for PROJ-042" \
  --role test-manager --workdir ~/projects/my-app --topic

# Interactive (planner)
spawn.sh "Research pagination patterns for large datasets" \
  --role planner --workdir ~/projects/my-app --interactive
```

## Communication

Agents communicate via file-based messaging:
```bash
# Send message to another agent's pane
agents-msg.sh send terminal_<id> "Tests pass, ready for review" --role "test-manager"

# Check if agent has pending messages
agents-msg.sh status terminal_<id>
```

No terminal injection, no tab polling, no shared state beyond files.
