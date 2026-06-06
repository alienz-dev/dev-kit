# Plan: Adapt dev-kit for Claude Code + macOS

> **⚠️ ARCHIVED** — This migration plan has been completed. All items below are either done or
> no longer relevant. Kept for historical reference only. The dev-kit now targets Claude Code
> as the primary agent CLI on macOS.

## Current State (After Latest Pull)

The repo has evolved substantially. Many foundations for agent-agnostic operation already exist:

- `templates/common/AGENTS.md.template` — cross-tool instructions (any AI reads it)
- `scaffold.sh` already generates `CLAUDE.md` (symlink to AGENTS.md) at line 302
- `core/coding-agent/adapters/claude-code.sh` — Claude Code headless adapter
- `core/coding-agent/adapters/codex.sh` — Codex adapter
- `core/coding-agent/adapters/base.sh` — shared adapter contract
- `infra/scripts/env-detect.sh` — detects macOS, claude-code, zsh
- `docs/DEGRADED-MODE.md` — Level 3 (Direct) works without daemon/multiplexer
- `workflow/pipeline/gate.sh` — file-based pipeline state (no daemon needed)
- `docs/GETTING-STARTED-AGENT.md` — agent-agnostic onboarding

**What still needs updating:** setup.sh defaults, shell assumptions, sed compatibility, docs referencing kiro, macOS package management.

---

## What's Already Done (No Changes Needed)

| Feature | Status | Location |
|---------|--------|----------|
| AGENTS.md template | ✅ Agent-agnostic | `templates/common/AGENTS.md.template` |
| CLAUDE.md generation | ✅ Symlink from AGENTS.md | `scaffold.sh:302` |
| Claude Code adapter | ✅ Headless mode | `core/coding-agent/adapters/claude-code.sh` |
| Codex adapter | ✅ Full-auto mode | `core/coding-agent/adapters/codex.sh` |
| Adapter base contract | ✅ Shared helpers | `core/coding-agent/adapters/base.sh` |
| Pipeline FSM (no daemon) | ✅ File-based | `workflow/pipeline/gate.sh` |
| Degraded mode docs | ✅ 3 levels | `docs/DEGRADED-MODE.md` |
| Agent onboarding | ✅ Tool-agnostic | `docs/GETTING-STARTED-AGENT.md` |
| Environment detection | ✅ macOS + claude-code | `infra/scripts/env-detect.sh` |
| Lefthook pre-commit | ✅ Cross-platform | `templates/common/lefthook.yml` |
| Role architecture | ✅ Expanded roles | `agents/roles/ROLES.md` |
| Context reduction | ✅ Per-role resource sets | `docs/CONTEXT-REDUCTION.md` |

---

## What Needs Updating

### Phase 1: setup.sh — macOS + Claude Code (Priority: P0)

**File:** `setup.sh`

#### 1.1 Shell Detection (lines 170-172)
```bash
# Current: appends to ~/.bashrc
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Fix: detect shell
SHELL_RC="$HOME/.zshrc"
[ "${SHELL:-}" != "/bin/zsh" ] && [ -f "$HOME/.bashrc" ] && SHELL_RC="$HOME/.bashrc"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
```

#### 1.2 Claude Code as Primary Agent (lines 106-123)
```bash
# Current: only checks for kiro-cli
# Fix: detect claude first, kiro as fallback

if command -v claude &>/dev/null; then
  ok "Claude Code installed"
  AGENT_CLI="claude"
elif command -v kiro-cli &>/dev/null; then
  ok "kiro-cli installed"
  AGENT_CLI="kiro"
elif [ "$MODE" = "check" ]; then
  fail "No coding agent found (claude or kiro-cli)"; MISSING=1
else
  echo "Installing Claude Code..."
  npm install -g @anthropic/claude-code 2>/dev/null && ok "Claude Code installed" || {
    echo "Trying kiro-cli as fallback..."
    npm install -g @anthropic/kiro-cli 2>/dev/null && ok "kiro-cli installed" || {
      fail "No agent installed"; MISSING=1
    }
  }
fi
```

#### 1.3 Zellij arm64 Detection (lines 94-101)
```bash
# Current: only x86_64 and aarch64
# Fix: also handle arm64 (macOS convention)

if [ "$ARCH" = "x86_64" ]; then
  curl -sL ...zellij-x86_64-unknown-linux-musl.tar.gz...
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
  # On macOS, prefer brew
  if command -v brew &>/dev/null; then
    brew install zellij
  else
    curl -sL ...zellij-aarch64-unknown-linux-musl.tar.gz...
  fi
```

#### 1.4 Claude Code Directories (lines 129-133)
```bash
# Current: creates ~/.kiro/ dirs
# Fix: also create ~/.claude/ project dirs

mkdir -p ~/projects ~/plans ~/.local/bin
if [ "$MODE" != "minimal" ]; then
  mkdir -p ~/.kiro/{agents,rules,state,skills,hooks}
  mkdir -p ~/.config/zellij/{layouts,plugins}
fi
# Claude Code uses ~/.claude/projects/<encoded-path>/memory/
# No additional dirs needed — Claude Code creates them automatically
```

#### 1.5 Summary Update (lines 204-216)
```bash
# Current: always suggests kiro-cli chat
# Fix: suggest based on detected agent

if [ "$AGENT_CLI" = "claude" ]; then
  echo "  3. Launch agent: claude"
else
  echo "  3. Launch agent: kiro-cli chat --agent $NAME"
fi
```

---

### Phase 2: hot-memory.sh — macOS sed Fix (Priority: P0)

**File:** `infra/scripts/hot-memory.sh`

All `sed -i` calls (lines 42-43, 52-54, 62-64) need macOS compatibility:

```bash
# Add at top of file, after set -euo pipefail:
_sed_i() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

# Replace all: sed -i "s/..." → _sed_i "s/..."
```

---

### Phase 3: scaffold.sh — Better Claude Code Integration (Priority: P1)

**File:** `scaffold.sh`

#### 3.1 CLAUDE.md Content (line 301-302)
**Current:** `ln -sf AGENTS.md CLAUDE.md` — symlink only, no Claude Code-specific content.

**Improvement:** Generate a real CLAUDE.md with Claude Code-specific additions on top of AGENTS.md:

```bash
# After AGENTS.md generation:
cat > CLAUDE.md << EOF
# $NAME — Claude Code Instructions

$(cat AGENTS.md)

## Claude Code Specifics
- Subagent types: Explore (search), Plan (architecture), general-purpose (implementation)
- Memory: ~/.claude/projects/<encoded-path>/memory/ for persistent facts
- Settings: .claude/settings.json for permission rules
- Hooks: .claude/settings.json hooks for pre/post tool execution
EOF
```

#### 3.2 .claude/settings.json (after line 302)
```bash
mkdir -p .claude
cat > .claude/settings.json << EOF
{
  "permissions": {
    "allow": ["Read", "Write", "Edit", "Bash(npm run *)", "Bash(npm test*)", "Bash(git *)", "Bash(npx vitest *)"],
    "deny": []
  }
}
EOF
```

#### 3.3 Kiro Agent JSON (lines 314-336)
**Current:** Always generates kiro agent JSON in minimal mode too (line 314 checks MINIMAL)
**Fix:** Only generate if kiro-cli is detected:

```bash
if [ "$MINIMAL" -eq 0 ] && command -v kiro-cli &>/dev/null; then
  # ... kiro agent JSON generation ...
fi
```

#### 3.4 Summary (lines 350-356)
**Fix:** Detect and suggest appropriate agent:

```bash
if command -v claude &>/dev/null; then
  echo "  claude"
elif command -v kiro-cli &>/dev/null; then
  echo "  kiro-cli chat --agent $NAME"
else
  echo "  (install claude or kiro-cli to start)"
fi
```

---

### Phase 4: Documentation Updates (Priority: P1)

#### 4.1 docs/FRESH-MACHINE.md
- Add macOS Homebrew path for each step
- Add `brew install python@3.12` for Python
- Add `brew install zellij` as primary macOS path
- Note `source ~/.zshrc` instead of `source ~/.bashrc`
- Add Claude Code install: `npm install -g @anthropic/claude-code`
- Keep Linux/WSL2 as secondary

#### 4.2 README.md
- Update Quick Start to mention Claude Code
- Update "What This Is" to be more agent-agnostic
- Mention degraded mode (Level 3) as simplest start

#### 4.3 docs/ARCHITECTURE.md
- Add Claude Code as primary agent option in diagram
- Note that Level 3 (Direct) mode works without daemon

#### 4.4 docs/CONVENTIONS.md
- Add Claude Code conventions section
- CLAUDE.md as project context (replaces kiro resources)
- `.claude/settings.json` for permissions

---

### Phase 5: Agent Rules — Claude Code References (Priority: P2)

#### 5.1 agents/rules/delegation-slim.md
- Add Claude Code `Agent()` tool spawning alongside kiro-ctl
- Map: `kiro-ctl spawn coder` → `Agent(subagent_type="general-purpose")`
- Note: Claude Code doesn't need `--subscribe` (built-in task tracking)

#### 5.2 agents/rules/planner-core.md
- Add Claude Code equivalents for kiro-ctl commands
- `kiro-ctl spawn` → `Agent()` tool
- `kiro-ctl wait` → `TaskOutput` tool
- `--subscribe` → automatic in Claude Code

#### 5.3 agents/context-files/session-routing.md
- Keep shortcodes (project-specific, not tool-specific)
- Update "Done Protocol" to mention Claude Code memory

---

### Phase 6: macOS Daemon Alternatives (Priority: P3)

#### 6.1 Option A: Skip Daemon for Dev
For development, Level 3 (Direct) mode is sufficient:
- `gate.sh` for pipeline state
- `lefthook` for pre-commit gates
- Manual agent spawning via Claude Code

#### 6.2 Option B: Simple PID-Based Daemon
```bash
# infra/scripts/start-daemon-macos.sh
nohup kiro-sessiond > /tmp/kiro-sessiond.log 2>&1 &
echo $! > /tmp/kiro-sessiond.pid
```

#### 6.3 Option C: launchd
```xml
<!-- infra/launchd/com.dev-kit.session-daemon.plist -->
```

**Recommendation:** Option A for now. The daemon is only needed for Level 1 (Full) multi-agent orchestration. Most Claude Code usage is Level 2-3.

---

## Implementation Order

| # | Task | Effort | Impact | Files |
|---|------|--------|--------|-------|
| 1 | Fix hot-memory.sh sed for macOS | 5min | Unblocks macOS | `infra/scripts/hot-memory.sh` |
| 2 | Update setup.sh for macOS + Claude Code | 30min | Fresh machine works | `setup.sh` |
| 3 | Enhance scaffold.sh CLAUDE.md generation | 30min | Better Claude Code integration | `scaffold.sh` |
| 4 | Add .claude/settings.json to scaffold | 10min | Permissions work | `scaffold.sh` |
| 5 | Update FRESH-MACHINE.md | 30min | Onboarding accurate | `docs/FRESH-MACHINE.md` |
| 6 | Update README.md | 15min | First impression correct | `README.md` |
| 7 | Update delegation-slim.md for Claude Code | 20min | Agent spawning documented | `agents/rules/delegation-slim.md` |
| 8 | Update planner-core.md for Claude Code | 20min | Planner works with Claude | `agents/rules/planner-core.md` |
| 9 | Update ARCHITECTURE.md | 20min | Architecture docs accurate | `docs/ARCHITECTURE.md` |
| 10 | macOS daemon option (if needed) | 2h | Level 1 support | `infra/` |

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| AGENTS.md as canonical, CLAUDE.md as symlink | Single source of truth, works with any agent |
| Claude Code primary, kiro optional | User's machine has Claude Code installed |
| Level 3 (Direct) as default experience | No daemon/multiplexer needed to start |
| Keep kiro-ctl in docs | Multi-agent orchestration still uses it |
| No launchd yet | Level 3 mode works without daemon |
| macOS sed wrapper over platform detection | Minimal change, maximum compatibility |

---

## Verification Checklist

After implementation:
- [ ] `./setup.sh` runs clean on macOS ARM64 (zsh, brew)
- [ ] `./setup.sh --minimal` works without zellij/kiro
- [ ] `./scaffold.sh test-project` generates real CLAUDE.md + .claude/settings.json
- [ ] `./scaffold.sh test-project --minimal` works without agent deps
- [ ] `hot-memory.sh add "test" default` works on macOS (BSD sed)
- [ ] `claude` CLI works in scaffolded project directory
- [ ] `gate.sh init test && gate.sh status` works
- [ ] All docs reference Claude Code alongside kiro
- [ ] SDD/TRIO workflow patterns preserved
