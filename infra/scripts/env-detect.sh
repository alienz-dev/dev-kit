#!/bin/bash
# env-detect.sh — Detect runtime environment, write structured output
# Output: /tmp/env-context.md
set -euo pipefail

OUT="/tmp/env-context.md"

# OS
if grep -qi microsoft /proc/version 2>/dev/null; then
  OS="wsl2 ($(lsb_release -ds 2>/dev/null || echo Linux))"
elif [ "$(uname -s)" = "Darwin" ]; then
  OS="macos ($(sw_vers -productVersion 2>/dev/null || echo unknown))"
else
  OS="linux ($(lsb_release -ds 2>/dev/null || cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"' || echo unknown))"
fi

# Node
NODE=$(node --version 2>/dev/null || echo "not found")

# Python
PYTHON=$(python3 --version 2>/dev/null | cut -d' ' -f2 || echo "not found")

# Multiplexer
if [ -n "${ZELLIJ_SESSION_NAME:-}" ]; then MUX="zellij"
elif [ -n "${TMUX:-}" ]; then MUX="tmux"
elif [ -n "${STY:-}" ]; then MUX="screen"
else MUX="none"; fi

# Agent CLI
if command -v claude &>/dev/null; then AGENT_CLI="claude-code"
elif command -v aider &>/dev/null; then AGENT_CLI="aider"
elif command -v codex &>/dev/null; then AGENT_CLI="codex"
else AGENT_CLI="none"; fi

# Package manager (based on lockfiles in cwd)
if [ -f pnpm-lock.yaml ]; then PKG="pnpm"
elif [ -f yarn.lock ]; then PKG="yarn"
else PKG="npm"; fi

# Git
GIT=$(git --version 2>/dev/null | cut -d' ' -f3 || echo "not found")

# Agent session
AGENT_SESSION="no"
if [ -n "${CLAUDE_CODE:-}" ]; then AGENT_SESSION="yes (claude)"
elif [ -n "${CODEX_SANDBOX:-}" ]; then AGENT_SESSION="yes (codex)"
elif [ -n "${AI_AGENT:-}" ]; then AGENT_SESSION="yes (generic)"
elif [ -n "${CI:-}" ]; then AGENT_SESSION="yes (ci)"; fi

cat > "$OUT" << EOF
# Environment Context
Generated: $(date -Iseconds)

| Key | Value |
|-----|-------|
| OS | $OS |
| Node | $NODE |
| Python | $PYTHON |
| Multiplexer | $MUX |
| Agent CLI | $AGENT_CLI |
| Package Manager | $PKG |
| Git | $GIT |
| Agent Session | $AGENT_SESSION |
| Working Dir | $(pwd) |
EOF

echo "$OUT"
