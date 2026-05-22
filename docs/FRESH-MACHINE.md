# Fresh Machine Setup

Complete guide to bootstrapping an AI-native development environment from zero.

## Prerequisites

| Component | Version | Purpose |
|-----------|---------|---------|
| Linux/WSL2/macOS | Any recent | Base OS |
| bash | 5.0+ | Shell scripts |
| git | 2.30+ | Version control |
| curl | Any | Downloads |
| jq | 1.6+ | JSON processing |

## Step 1: Node.js (via nvm)

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc
nvm install 22
nvm alias default 22
node --version  # v22.x.x
```

## Step 2: Python 3.10+

```bash
# Ubuntu/WSL2
sudo apt install python3 python3-pip python3-venv

# macOS
brew install python@3.12
```

## Step 3: Zellij (Terminal Multiplexer)

```bash
# Linux
curl -L https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz | tar xz
mv zellij ~/.local/bin/

# macOS
brew install zellij
```

## Step 4: Directory Structure

```bash
mkdir -p ~/projects ~/plans ~/scripts ~/.local/bin ~/.config/zellij/{layouts,plugins}
```

## Step 5: Zellij Configuration

Copy from `core/multiplexer/`:
```bash
cp core/multiplexer/config.kdl ~/.config/zellij/config.kdl
cp core/multiplexer/layouts/*.kdl ~/.config/zellij/layouts/
```

Key settings:
- `default_mode "locked"` — agents can't accidentally trigger keybinds
- `session_serialization false` — don't persist layout state (agents manage their own)
- `pane_frames false` — maximize screen real estate

## Step 6: LLM Access

Choose one:

### Option A: Direct API Key
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
# Or for OpenAI-compatible:
export OPENAI_API_KEY="..."
export OPENAI_BASE_URL="https://api.anthropic.com/v1"
```

### Option B: LLM Proxy (corporate environments)
```bash
cd core/llm-proxy
# See core/llm-proxy/README.md for setup
# Provides localhost:8080 with auto token refresh
```

### Option C: AWS Bedrock / CodeWhisperer
```bash
# Requires AWS SSO login + proxy translation layer
# See core/llm-proxy/README.md for corporate setup
```

## Step 7: Agent CLI

Install your preferred agent CLI:

```bash
# Kiro
npm install -g @anthropic/kiro-cli

# Claude Code
npm install -g @anthropic/claude-code

# Aider
pip install aider-chat

# Or any Anthropic-compatible CLI
```

## Step 8: First Project

```bash
./scaffold.sh my-project
cd ~/projects/my-project
# Agent session starts with full infrastructure
```

## Step 9: Verification Checklist

```bash
# All should pass:
node --version | grep -q v22 && echo "✓ Node 22"
python3 --version | grep -q "3.1" && echo "✓ Python 3.10+"
zellij --version && echo "✓ Zellij"
git --version && echo "✓ Git"
jq --version && echo "✓ jq"
test -f ~/.config/zellij/config.kdl && echo "✓ Zellij config"
```

## Corporate Environment Extras

### TLS/CA Bundle (Zscaler, corporate proxy)

```bash
# Find your corporate CA bundle
ls /etc/ssl/certs/ca-certificates.crt  # Ubuntu
ls /etc/pki/tls/certs/ca-bundle.crt    # RHEL

# Set for Node.js (add to ~/.bashrc)
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

# Set for Python requests
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
```

### npm Registry (Nexus/Artifactory)

```bash
npm config set registry https://your-nexus.company.com/repository/npm-all/
npm config set //your-nexus.company.com/repository/npm-all/:_auth=$(echo -n "user:pass" | base64)
```

### Git SSH (Bitbucket/GitHub Enterprise)

```bash
ssh-keygen -t ed25519 -C "your-email@company.com"
# Add public key to your git hosting
```

## WSL2-Specific

```bash
# Access Windows filesystem
ls /mnt/c/Users/$USER/

# Open URLs in Windows browser
alias open='cmd.exe /c start'

# Windows Terminal / WezTerm integration
# See core/multiplexer/WEZTERM.md for hotkey setup
```
