# dev-kit — Development Plan

> **⚠️ ARCHIVED** — This is the original design document. The architecture has since been
> simplified: Claude Code is the primary agent CLI, kiro references are historical, and the
> multi-daemon/session-daemon design was replaced by Claude Code's native session management.
> See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the current architecture.

## Design Principles

1. **Pattern over prescription** — document the WHY and the pattern, not just the config file
2. **Portable** — works on any Linux/WSL2/macOS with bash, node, python3
3. **Incremental** — each module works standalone; full integration is optional
4. **Agent-agnostic** — patterns work with any LLM CLI (kiro, claude, aider, etc.)
5. **Learned from failure** — every pattern here solved a real problem

---

## Phase 1: Core Infrastructure

### 1.1 Terminal Multiplexer Setup (`core/multiplexer/`)

**Problem solved:** Agents need isolated panes, tab lifecycle control, cross-pane communication.

**Contents:**
- `config.kdl` — Zellij config (locked mode default, keybinds for agent workflow)
- `layouts/default.kdl` — Status bar with zjstatus plugin
- `layouts/project.kdl` — Standard project layout (main + floating)
- `plugins/` — zjstatus.wasm (status bar)
- `SETUP.md` — Installation, session naming conventions

**Key patterns:**
- Default locked mode (agents don't accidentally trigger keybinds)
- `--close-on-exit` for spawned agent tabs
- Tab naming convention: `<role>-<task-slug>`
- Pane ID targeting (never focus-steal for programmatic ops)

### 1.2 Coding Agent Integration (`core/coding-agent/`)

**Problem solved:** Need a standardized way to run coding agents with tool access, context injection, and session management. Default to kiro-cli but allow swapping in other agents (claude-code, aider, cursor-agent, etc.).

**Contents:**
- `AGENTS.md` — Supported agents, capabilities matrix, configuration
- `kiro/` — Kiro-specific config (agent JSON, TUI mode setup)
- `adapters/` — Adapter shims for alternative agents
- `agent-config-template.json` — Standard agent definition format
- `preflight.sh` — Verify agent CLI is installed and configured

**Key patterns:**
- Agent CLI abstracted behind a common interface (spawn, briefing, result)
- Kiro as default: `kiro-cli chat --tui --agent <name>`
- Agent JSON defines: name, model, prompt, tools, deniedPaths, resources
- Alternative agents plug in via adapter scripts that translate briefing → agent-specific invocation
- Trust settings per role (coder gets write, supervisor gets read-only)

**Agent interface contract:**
```
Input:  briefing file (markdown) + working directory + allowed tools
Output: result file (markdown) at specified path
Signal: process exit (0=success, non-zero=failure)
```

**Kiro-specific:**
- `--tui` mode for all sessions (stdin/stdout isolation is structural)
- `--agent <name>` loads from `~/.kiro/agents/<name>.json`
- `--trust-tools` whitelist (derived from role's allowed tools)
- Resources array for context injection at session start
- Hooks for spawn-time context (hot memory, workspace state)

**Pluggable alternatives:**
- Claude Code: `claude --dangerously-skip-permissions -p "briefing"`
- Aider: `aider --message-file briefing.md`
- Cursor Agent: via API
- Custom: any CLI that reads a prompt and writes files

### 1.3 Session Daemon (`core/session-daemon/`)

**Problem solved:** Agent sessions hang, crash, or need coordination. Need registry, dispatch, hang detection.

**Contents:**
- Python daemon (SQLite state, no external deps)
- Session registry (who's running, what tab, what state)
- Hang detection (idle timeout, health signal monitoring)
- Message queue (file-based inter-agent messaging)
- Tab replacement (kill hung agent, respawn)

**Key patterns:**
- PID file for singleton enforcement
- SQLite WAL mode for concurrent reads
- Escalating health checks (idle → stuck → dead)
- File-based messaging (no network, no race conditions)

### 1.4 Agent Launcher (`core/agent-launcher/`)

**Problem solved:** Spawning agents with correct context, briefing, result collection, and cleanup.

**Contents:**
- `kiro-ctl spawn` — Primary dispatch (daemon-driven, EventBus completion tracking)
- `kiro-sub.sh` — Low-level fallback launcher (when daemon unavailable)
- `briefing-template.md` — Standard briefing format
- `result-watcher.sh` — Detects completion, notifies parent
- `cleanup.sh` — Remove temp files, agent JSON, close tabs

**Key patterns:**
- Fire-and-forget vs interactive mode detection
- Parent notification via file + pane injection
- Briefing = task + context + constraints + result path
- Tab auto-close on completion (launcher controls lifecycle, not agent)

---

## Phase 2: Development Methodology

### 2.1 Spec-Driven Development (`workflow/sdd/`)

**Problem solved:** Agents implement wrong things without a contract. Specs are the single source of truth.

**Contents:**
- `SDD.md` — Process definition (lifecycle, rules)
- `spec-template.md` — Frontmatter + sections + acceptance criteria
- `plan-template.md` — Derived from spec (HOW + ORDER)
- `validate-spec.sh` — Check spec completeness before implementation
- `spec-to-test.sh` — Generate test stubs from spec sections

**Lifecycle:**
```
Idea → Spec (draft) → Spec (approved) → Plan → Implement (TDD) → Verify → Ship
```

**Rules:**
- Every feature >1 file needs a spec
- Specs define WHAT + WHY; plans define HOW + ORDER
- Tests reference spec sections via `// @spec <file> §<section>`
- If code diverges from spec, update one or the other — never leave in disagreement

### 2.2 TRIO Protocol (`workflow/trio/`)

**Problem solved:** Agents skip testing, write tests after code, or write tests that don't actually verify behavior.

**TRIO = Test → Red → Implement → Observe**

**Contents:**
- `TRIO.md` — Protocol definition
- `constitution.yml` — State machine gates (open → specced → tests_written → red_verified → implementing → green → reviewing → closed)
- `gate-check.sh` — Verify current state meets gate requirements
- `promote.sh` — Advance issue state after gate passes

**Key insight:** The coder NEVER sees the spec. They only see failing tests. This prevents "implement to spec" shortcuts that skip actual test verification.

**Gate definitions:**
| Gate | Requirement |
|------|-------------|
| spec_linked | Spec file exists and is referenced |
| tests_exist | Test files exist with assertions |
| all_tests_fail | Every test fails (RED confirmed) |
| coder_assigned | Worker spawned with test-only briefing |
| visible_tests_pass | All non-hidden tests pass |
| approved_and_hidden_pass | Reviewer approves + hidden regression tests pass |

### 2.3 Issue Lifecycle (`workflow/issue-lifecycle/`)

**Problem solved:** Scattered tracking (Jira, TODO files, mental notes). Need unified, agent-readable, file-based tracking.

**Contents:**
- `issue-template.md` — YAML frontmatter + body
- `lifecycle.md` — State machine (backlog → planned → open → in_progress → review → resolved → verified → closed)
- `index-schema.json` — Issue index format
- `cli-spec.md` — CLI commands (open, start, resolve, verify, close, link, brief)

**Key patterns:**
- Issues are markdown files (readable by agents, indexable by RAG, visible in editors)
- SQLite index is derived (rebuilt from markdown via `reindex`)
- Per-project numbering: `project#N`
- `issue brief` dumps context for agent briefings
- 7-day verification window before auto-close

### 2.4 Session Retrospective (`workflow/retro/`)

**Problem solved:** Lessons learned in sessions are lost. Need structured extraction and archival.

**Contents:**
- `retro-template.md` — Output format (metrics, errors, corrections, forward plan)
- `extract.py` — Tiered extraction from conversation transcripts
- `archive-convention.md` — Where retros go, naming, dedup

**Key patterns:**
- Extract errors, corrections, and decisions from transcripts
- Streak tracking (consecutive active days)
- Compare mode for multi-session trends
- Feed gotchas back into hot-memory or project knowledge

---

## Phase 3: Agent Definitions

### 3.1 Role Definitions (`agents/roles/`)

**Problem solved:** Agents without role constraints do everything poorly. Specialization + delegation = quality.

**Roles:**
| Role | Can Write | Cannot Write | Spawns |
|------|-----------|--------------|--------|
| supervisor | STATUS.md, NEXT-SESSION.md, issues/, /tmp/ | src/, tests/, *.ts | planner, test-manager |
| test-manager | tests/, /tmp/ | src/ | coder, tester |
| coder | src/, tests/, /tmp/ | .agents/knowledge/, STATUS.md | — |
| tester | tests/, /tmp/ | src/ | — |
| reviewer | /tmp/ (reports only) | everything else | — |
| planner | ~/plans/, /tmp/ | src/, tests/ | — |
| researcher | ~/plans/, /tmp/ | src/, tests/ | — |

**Key insight:** Supervisor deniedPaths on `**/*.ts` and `**/src/**` FORCE delegation. Without these, supervisors implement directly.

### 3.2 Safety Rules (`agents/rules/`)

**Problem solved:** Agents hang on stdin, OOM on tsc, destroy uncommitted work, hallucinate APIs.

**Contents:**
- `execution-safety.md` — stdin closure, background server patterns, memory limits
- `verification.md` — Verify before verdict, auto-verify, confirm hypothesis
- `anti-destruction.md` — Never discard uncommitted work, scope discipline
- `anti-hallucination.md` — Zero knowledge assumption, cross-reference before acting
- `context-discipline.md` — Treat context like RAM, don't compress meaning

**Critical rules (from real failures):**
- `< /dev/null` on every bash command (stdin hang prevention)
- Never `pool: 'forks'` in vitest (OOM from orphan workers)
- Never raw `tsc --noEmit` (use `npm run typecheck` with memory limit)
- `start-server.sh` for background processes (stdout pipe deadlock prevention)

### 3.3 Knowledge Templates (`agents/knowledge/`)

**Problem solved:** Agents start every session with zero project knowledge. Need structured onboarding.

**Templates:**
- `project.md` — Architecture, tech stack, key patterns
- `workflow.md` — TDD lifecycle, state transitions, gates
- `goals.md` — Vision, phases, success metrics
- `workspace-rules.md` — Read-only vs writable paths, post-run checklist
- `glossary.md` — Ubiquitous language (CONTEXT.md template)

### 3.4 Agent Hooks (`agents/hooks/`)

**Problem solved:** Agents need context injected at spawn time (workspace state, hot memory, project context).

**Contents:**
- `project-context.sh` — Inject STATUS.md + NEXT-SESSION.md at session start
- `hot-memory-route.sh` — Route per-workspace hot memory
- `conv-linker.sh` — Link conversation ID to session registry

---

## Phase 4: Quality Gates

### 4.1 UI Visual Check (`quality/ui-visual-check/`)

**Problem solved:** UI regressions invisible to text-only agents. Need automated visual quality assessment.

**Three layers:**
1. **Static** — Regex lint (hardcoded colors, !important, missing alt text) — <5s
2. **VLM** — CDP screenshot → vision model + DESIGN.md anchoring — 15-30s
3. **Heuristic** — DOM checks (empty states, touch targets, overflow, focus) — <15s

**Contents:**
- `ui-visual-check.sh` — Main runner (--files, --url, --design, --auto-fix, --threshold)
- `rules/` — Static lint rules
- `heuristics/` — DOM check scripts
- `DESIGN-template.md` — Design system reference for VLM anchoring

### 4.2 Pre-Commit Gate (`quality/pre-commit/`)

**Problem solved:** Broken code gets committed. Need fast, mandatory verification before every commit.

**Contents:**
- `pre-commit-test-gate.sh` — Run affected tests only (git diff → test mapping)
- `test-affected.sh` — Determine which tests to run based on changed files
- `typecheck-gate.sh` — Incremental typecheck with memory limit

**Key pattern:** Only run tests affected by the diff (not full suite). Use module-map.json or import graph.

### 4.3 Regression Prevention (`quality/regression/`)

**Problem solved:** Agents fix one thing and break another. Need hidden tests that catch regressions.

**Contents:**
- `hidden-test-pattern.md` — Tests the coder never sees (only reviewer + gate)
- `regression-suite.md` — How to build and maintain regression tests
- `conformance-test-pattern.md` — Shared test suite verifying two implementations produce identical results

---

## Phase 5: Project Templates

### 5.1 TypeScript CLI (`templates/typescript-cli/`)
- oclif or plain commander
- vitest, tsconfig strict, Node 22
- Issue tracking, specs dir, agent config

### 5.2 TypeScript Web (`templates/typescript-web/`)
- Next.js 15 or Vite + React
- Tailwind, vitest, Playwright for e2e
- DESIGN.md for visual check anchoring

### 5.3 Python Service (`templates/python-service/`)
- FastAPI or plain script
- pytest, mypy strict
- Systemd service template

### 5.4 Common (`templates/common/`)
- `.gitignore` variants
- `tsconfig.json` (strict, ESM)
- `vitest.config.ts` (threads, never forks)
- `STATUS.md`, `NEXT-SESSION.md`, `CONTEXT.md`, `DECISIONS.md` templates
- `.agents/` directory structure

---

## Phase 6: System Infrastructure

### 6.1 Systemd Services (`infra/systemd/`)

**Problem solved:** Daemons need reliable lifecycle, log rotation, restart policies.

**Templates:**
- Service unit (Type=simple, Restart=on-failure, WatchdogSec)
- Timer unit (OnCalendar patterns)
- Environment file template
- Log rotation config

### 6.2 Utility Scripts (`infra/scripts/`)

**Problem solved:** Common operations need safe, idempotent wrappers.

**Scripts:**
- `start-server.sh` — Safe background server launch (port, log, wait)
- `stop-server.sh` — Graceful shutdown by port
- `pane-inject.sh` — Safe text injection into zellij panes
- `hot-memory.sh` — Bounded curated context management (add/replace/remove)
- `agents-msg.sh` — File-based inter-agent messaging

### 6.3 Workspace State (`infra/state/`)

**Problem solved:** Sessions lose context between restarts. Need persistent state that survives crashes.

**Templates:**
- `hot-memory-template.md` — Per-workspace bounded memory (3000 char budget)
- `memo-template.md` — Transient session state (current focus, open items)
- `workspace-state-template.md` — Compiled execution plan for next session

---

## Phase 7: Documentation

### 7.1 Architecture (`docs/ARCHITECTURE.md`)
- How modules interact
- Data flow: user → supervisor → test-manager → coder → reviewer → ship
- File-based communication patterns

### 7.2 Conventions (`docs/CONVENTIONS.md`)
- Extracted from coding-conventions skill
- Semantic density, naming, type strictness, file organization
- Git conventions (atomic commits, rich messages, type prefixes)

### 7.3 Fresh Machine Guide (`docs/FRESH-MACHINE.md`)
- OS prerequisites (WSL2, macOS, Linux)
- Node 22 (nvm), Python 3.10+, Go 1.22+
- Zellij installation
- LLM proxy setup
- First project scaffold
- Verification checklist

### 7.4 Troubleshooting (`docs/TROUBLESHOOTING.md`)
- Extracted from real failure modes:
  - Agent hangs (stdin, stdout pipe, background process)
  - OOM (tsc, vitest forks, memory hogs)
  - Auth failures (token expiry, CA bundle, proxy)
  - Session loss (crash recovery, resume commands)
  - Agent hallucination (wrong API, stale docs, invented signatures)

---

## Implementation Priority

| Priority | Module | Effort | Value |
|----------|--------|--------|-------|
| P0 | `docs/FRESH-MACHINE.md` | 1d | Unblocks everything else |
| P0 | `core/multiplexer/` | 0.5d | Foundation for all agent work |
| P0 | `workflow/sdd/` + `workflow/trio/` | 1d | Core methodology |
| P0 | `core/coding-agent/` | 1d | Agent CLI setup + kiro default |
| P1 | `agents/roles/` + `agents/rules/` | 1d | Agent quality |
| P1 | `core/agent-launcher/` | 1d | Spawn infrastructure |
| P1 | `templates/common/` | 0.5d | Reusable project skeleton |
| P2 | `workflow/issue-lifecycle/` | 1d | Tracking |
| P2 | `quality/pre-commit/` | 0.5d | Safety net |
| P3 | `core/session-daemon/` | 3d | Advanced orchestration |
| P3 | `quality/ui-visual-check/` | 2d | UI quality |
| P3 | `workflow/retro/` | 0.5d | Learning loop |
| P4 | `templates/typescript-*` | 1d | Convenience |
| P4 | `infra/systemd/` | 0.5d | Production daemons |

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| File-based messaging over network | No race conditions, survives crashes, agent-readable |
| SQLite over Postgres | Zero setup, WAL mode for concurrency, portable |
| Zellij over tmux | Native tab/pane IDs, plugin system, locked mode |
| Markdown issues over DB-only | Agent-readable, RAG-indexable, git-trackable |
| Constitution gates over honor system | Agents skip steps without enforcement |
| Coder never sees spec | Prevents "implement to spec" shortcuts |
| Hot memory bounded at 3000 chars | Forces curation over accumulation |
| Supervisor can't write *.ts | Forces delegation pattern |

---

## Anti-Patterns to Avoid (Learned the Hard Way)

1. **Don't put everything in one agent** — specialization + delegation beats generalist
2. **Don't trust agents to self-verify** — gates must be external (different agent or script)
3. **Don't use `pool: 'forks'`** — orphan processes at 2GB each = OOM
4. **Don't background servers without stdout capture** — pipe deadlock
5. **Don't let agents read stdin** — session hang with no recovery
6. **Don't compress meaningful names** — saves 2 tokens, costs 67% more reasoning
7. **Don't skip the RED step** — tests that pass immediately test nothing
8. **Don't put session state in hot memory** — hot memory = permanent patterns, memo = transient
9. **Don't force-push, reset --hard, or clean -f** — uncommitted work from other agents
10. **Don't run raw tsc on large projects** — needs 8GB+, use incremental with memory cap
