#!/bin/bash
# setup.sh — Bootstrap AI-native development environment on a fresh machine
# Idempotent: safe to run multiple times
set -euo pipefail

# --- Mode parsing ---
MODE="full"
for arg in "$@"; do
  case "$arg" in
    --check) MODE="check" ;;
    --minimal) MODE="minimal" ;;
    --ci) MODE="ci" ;;
  esac
done

# Auto-detect agent session — skip confirmations
if [ -n "${KIRO_SESSION:-}" ] || [ -n "${CLAUDE_CODE:-}" ] || [ -n "${CODEX_SANDBOX:-}" ] || [ -n "${AI_AGENT:-}" ]; then
  [ "$MODE" = "full" ] && MODE="ci"
fi

echo "=== dev-kit setup (mode: $MODE) ==="
echo "Detecting environment..."

OS="$(uname -s)"
ARCH="$(uname -m)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

ok() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; }
need() { echo "  → $1"; }

MISSING=0

# --- Prerequisites ---
echo ""
echo "=== Checking prerequisites ==="

if command -v git &>/dev/null; then ok "git $(git --version | cut -d' ' -f3)"; else fail "git not found"; MISSING=1; need "sudo apt install git"; fi
if command -v curl &>/dev/null; then ok "curl"; else fail "curl not found"; MISSING=1; need "sudo apt install curl"; fi
if command -v jq &>/dev/null; then ok "jq $(jq --version 2>/dev/null)"; else fail "jq not found"; MISSING=1; need "sudo apt install jq"; fi

# --- Node.js via nvm ---
echo ""
echo "=== Node.js ==="

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  source "$NVM_DIR/nvm.sh"
fi

if command -v node &>/dev/null && node --version | grep -q "v22"; then
  ok "Node $(node --version)"
else
  echo "Installing nvm + Node 22..."
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"
  fi
  nvm install 22
  nvm alias default 22
  ok "Node $(node --version) installed"
fi

# --- Python ---
echo ""
echo "=== Python ==="

if command -v python3 &>/dev/null; then
  PY_VER=$(python3 --version | cut -d' ' -f2)
  ok "Python $PY_VER"
else
  fail "Python 3 not found"
  MISSING=1
  need "sudo apt install python3 python3-pip python3-venv"
fi

# --- Zellij ---
if [ "$MODE" != "minimal" ]; then
echo ""
echo "=== Zellij ==="

if command -v zellij &>/dev/null; then
  ok "Zellij $(zellij --version 2>/dev/null | head -1)"
elif [ "$MODE" = "check" ]; then
  fail "zellij not found"; MISSING=1
else
  echo "Installing zellij..."
  mkdir -p ~/.local/bin
  if [ "$ARCH" = "x86_64" ]; then
    curl -sL https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz | tar xz -C ~/.local/bin/
  elif [ "$ARCH" = "aarch64" ]; then
    curl -sL https://github.com/zellij-org/zellij/releases/latest/download/zellij-aarch64-unknown-linux-musl.tar.gz | tar xz -C ~/.local/bin/
  else
    fail "Unsupported arch: $ARCH — install zellij manually"
    MISSING=1
  fi
  if command -v zellij &>/dev/null; then ok "Zellij installed"; fi
fi
fi # end MODE != minimal

# --- Kiro CLI ---
if [ "$MODE" != "minimal" ]; then
echo ""
echo "=== Coding Agent (kiro-cli) ==="

if command -v kiro-cli &>/dev/null; then
  ok "kiro-cli installed"
elif [ "$MODE" = "check" ]; then
  fail "kiro-cli not found"; MISSING=1
else
  echo "Installing kiro-cli..."
  npm install -g @anthropic/kiro-cli 2>/dev/null && ok "kiro-cli installed" || {
    fail "kiro-cli install failed (may need auth or registry config)"
    need "npm install -g @anthropic/kiro-cli"
    MISSING=1
  }
fi
fi # end MODE != minimal

# --- Directory structure ---
echo ""
echo "=== Directory structure ==="

mkdir -p ~/projects ~/plans ~/.local/bin
if [ "$MODE" != "minimal" ]; then
  mkdir -p ~/.kiro/{agents,rules,state,skills,hooks}
  mkdir -p ~/.config/zellij/{layouts,plugins}
fi
ok "Directories created"

# --- Zellij config ---
if [ "$MODE" != "minimal" ]; then
echo ""
echo "=== Zellij configuration ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f ~/.config/zellij/config.kdl ] || [ "${FORCE:-}" = "1" ]; then
  cp "$SCRIPT_DIR/core/multiplexer/config.kdl" ~/.config/zellij/config.kdl
  cp "$SCRIPT_DIR/core/multiplexer/layouts/default.kdl" ~/.config/zellij/layouts/default.kdl
  ok "Zellij config installed"
else
  ok "Zellij config exists (use FORCE=1 to overwrite)"
fi

# --- Agent rules ---
echo ""
echo "=== Agent rules ==="

if [ ! -f ~/.kiro/rules/client_rules.md ] || [ "${FORCE:-}" = "1" ]; then
  cp "$SCRIPT_DIR/agents/rules/SAFETY.md" ~/.kiro/rules/client_rules.md
  ok "Safety rules installed"
else
  ok "Rules exist (use FORCE=1 to overwrite)"
fi
fi # end MODE != minimal

# --- PATH ---
echo ""
echo "=== PATH ==="

if echo "$PATH" | grep -q "$HOME/.local/bin"; then
  ok "~/.local/bin in PATH"
else
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
  ok "Added ~/.local/bin to PATH (source ~/.bashrc to activate)"
fi

# --- Issue CLI ---
if [ "$MODE" != "minimal" ]; then
echo ""
echo "=== Issue CLI ==="

if [ -d "$SCRIPT_DIR/tools/issue-cli" ] && [ -f "$SCRIPT_DIR/tools/issue-cli/package.json" ]; then
  cd "$SCRIPT_DIR/tools/issue-cli"
  npm install --silent 2>/dev/null
  npm link --silent 2>/dev/null && ok "issue CLI linked" || {
    fail "issue CLI link failed"
    need "cd tools/issue-cli && npm link"
  }
  cd "$SCRIPT_DIR"
else
  echo "  (issue-cli submodule not initialized — run: git submodule update --init)"
fi
fi # end MODE != minimal

# --- Summary ---
echo ""
echo "=== Summary ==="

if [ "$MODE" = "check" ]; then
  if [ $MISSING -eq 0 ]; then
    ok "All prerequisites satisfied"; exit 0
  else
    fail "Some prerequisites missing — see above"; exit 1
  fi
fi

if [ $MISSING -eq 0 ]; then
  ok "All prerequisites satisfied"
  echo ""
  if [ "$MODE" = "minimal" ]; then
    echo "Next steps:"
    echo "  1. Create your first project: ./scaffold.sh --minimal <project-name>"
    echo "  2. Start coding with any AI agent in the project directory"
  else
    echo "Next steps:"
    echo "  1. Create your first project: ./scaffold.sh <project-name>"
    echo "  2. Start a session: zellij --session <project-name>"
    echo "  3. Launch agent: kiro-cli chat --agent <project-name>"
  fi
else
  fail "Some prerequisites missing — see above"
  echo ""
  echo "After fixing, re-run: ./setup.sh"
fi
