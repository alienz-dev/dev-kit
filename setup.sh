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
if [ -n "${CLAUDE_CODE:-}" ] || [ -n "${CODEX_SANDBOX:-}" ] || [ -n "${AI_AGENT:-}" ]; then
  [ "$MODE" = "full" ] && MODE="ci"
fi

echo "=== dev-kit setup (mode: $MODE) ==="
echo "Detecting environment..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

# Detect package manager for install hints
if [ "$OS" = "Darwin" ] && command -v brew &>/dev/null; then
  PKG_MGR="brew install"
elif command -v apt &>/dev/null; then
  PKG_MGR="sudo apt install"
else
  PKG_MGR="install"
fi

if command -v git &>/dev/null; then ok "git $(git --version | cut -d' ' -f3)"; else fail "git not found"; MISSING=1; need "$PKG_MGR git"; fi
if command -v curl &>/dev/null; then ok "curl"; else fail "curl not found"; MISSING=1; need "$PKG_MGR curl"; fi
if command -v jq &>/dev/null; then ok "jq $(jq --version 2>/dev/null)"; else fail "jq not found"; MISSING=1; need "$PKG_MGR jq"; fi

# --- Node.js via nvm ---
echo ""
echo "=== Node.js ==="

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  source "$NVM_DIR/nvm.sh"
fi

if command -v node &>/dev/null && node --version | grep -q "v2"; then
  ok "Node $(node --version)"
else
  echo "Installing Node 22..."
  if [ "$OS" = "Darwin" ] && command -v brew &>/dev/null; then
    brew install node@22 && ok "Node $(node --version) installed via brew"
  elif [ ! -s "$NVM_DIR/nvm.sh" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"
    nvm install 22
    nvm alias default 22
    ok "Node $(node --version) installed via nvm"
  else
    nvm install 22
    nvm alias default 22
    ok "Node $(node --version) installed via nvm"
  fi
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
  if [ "$OS" = "Darwin" ]; then
    need "$PKG_MGR python@3.12"
  else
    need "$PKG_MGR python3 python3-pip python3-venv"
  fi
fi

# --- Coding Agent ---
if [ "$MODE" != "minimal" ]; then
echo ""
echo "=== Coding Agent ==="

AGENT_CLI=""
if command -v claude &>/dev/null; then
  ok "Claude Code installed"
  AGENT_CLI="claude"
elif [ "$MODE" = "check" ]; then
  fail "No coding agent found (claude)"; MISSING=1
else
  echo "Installing Claude Code..."
  npm install -g @anthropic/claude-code 2>/dev/null && ok "Claude Code installed" && AGENT_CLI="claude" || {
    fail "No coding agent installed — install manually:"
    need "npm install -g @anthropic/claude-code"
    MISSING=1
  }
fi
fi # end MODE != minimal

# --- Directory structure ---
echo ""
echo "=== Directory structure ==="

mkdir -p ~/projects ~/plans ~/.local/bin
ok "Directories created"

# --- Agent rules ---
echo ""
echo "=== Agent rules ==="

ok "Safety rules available in agents/rules/SAFETY.md"

# --- PATH ---
echo ""
echo "=== PATH ==="

if echo "$PATH" | grep -q "$HOME/.local/bin"; then
  ok "~/.local/bin in PATH"
else
  # Detect shell rc file
  SHELL_RC="$HOME/.bashrc"
  if [ "${SHELL:-}" = "/bin/zsh" ] || [ "${SHELL:-}" = "/usr/bin/zsh" ]; then
    SHELL_RC="$HOME/.zshrc"
  fi
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
  ok "Added ~/.local/bin to PATH (source $SHELL_RC to activate)"
fi

# --- Submodules ---
if [ "$MODE" != "minimal" ]; then
echo ""
echo "=== Submodules ==="

if [ -f "$SCRIPT_DIR/.gitmodules" ]; then
  # Auto-init submodules if not yet populated
  UNINITED=$(git -C "$SCRIPT_DIR" submodule status 2>/dev/null | grep '^-' | wc -l | tr -d ' ')
  if [ "$UNINITED" -gt 0 ]; then
    echo "  Initializing $UNINITED submodule(s)..."
    git -C "$SCRIPT_DIR" submodule update --init 2>/dev/null && ok "Submodules initialized" || {
      fail "Submodule init failed (Bitbucket access required)"
      need "git submodule update --init"
    }
  else
    ok "Submodules up to date"
  fi
else
  ok "No submodules defined"
fi

# --- Issue CLI ---
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
  echo "  (issue-cli not available — submodule may need Bitbucket access)"
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
    if [ "${AGENT_CLI:-}" = "claude" ]; then
      echo "  2. cd <project-dir> && claude"
    else
      echo "  2. Install claude and start"
    fi
  fi
else
  fail "Some prerequisites missing — see above"
  echo ""
  echo "After fixing, re-run: ./setup.sh"
fi
