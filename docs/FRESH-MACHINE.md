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
- `session_serialization false` — don't persist layout state
- `pane_frames false` — maximize screen real estate

## Step 6: Coding Agent (Kiro)

```bash
# Install kiro-cli
npm install -g @anthropic/kiro-cli

# Verify
kiro-cli --version
```

### Agent Configuration

```bash
# Create agent definitions directory
mkdir -p ~/.kiro/agents ~/.kiro/rules ~/.kiro/state

# Copy default rules
cp agents/rules/SAFETY.md ~/.kiro/rules/client_rules.md
```

## Step 7: Session Daemon (REQUIRED)

The session daemon provides agent lifecycle management, pipeline enforcement, and EventBus completion tracking.

```bash
# Install kiro-sessiond
cp core/session-daemon/src/kiro-sessiond.py ~/.local/bin/kiro-sessiond
chmod +x ~/.local/bin/kiro-sessiond

# Install kiro-ctl (CLI interface)
npm install -g kiro-ctl

# Systemd user service (auto-start on login)
mkdir -p ~/.config/systemd/user
cp infra/systemd/kiro-sessiond.service ~/.config/systemd/user/
systemctl --user enable --now kiro-sessiond

# Verify
kiro-ctl status
```

## Step 8: Playwright (for Visual QA & Design Tools)

Required for `ui-visual-check.sh` and `design-sandbox.sh`:

```bash
npm install -g playwright
npx playwright install chromium
```

## Step 9: cw-proxy (LLM API Access)

Local proxy for LLM API calls (localhost:8080):

```bash
# Install cw-proxy (provides Bedrock/Anthropic API access)
# Follow corporate setup guide for authentication
# Verify:
curl http://localhost:8080/health
```

## Step 10: Data Analyst venv (optional)

For the data-analyst agent:

```bash
mkdir -p ~/.local/share/kiro/venv
python3 -m venv ~/.local/share/kiro/venv/data-analyst
source ~/.local/share/kiro/venv/data-analyst/bin/activate
pip install pandas numpy scipy scikit-learn matplotlib seaborn
deactivate
```

## Step 11: First Project

```bash
./scaffold.sh my-project
cd ~/projects/my-project
# Agent session starts with full infrastructure
```

## Step 12: Verification Checklist

```bash
# All should pass:
node --version | grep -q v22 && echo "✓ Node 22"
python3 --version | grep -q "3.1" && echo "✓ Python 3.10+"
zellij --version && echo "✓ Zellij"
git --version && echo "✓ Git"
jq --version && echo "✓ jq"
command -v kiro-cli && echo "✓ Kiro CLI"
command -v kiro-ctl && echo "✓ kiro-ctl"
systemctl --user is-active kiro-sessiond && echo "✓ Session daemon"
test -f ~/.config/zellij/config.kdl && echo "✓ Zellij config"
test -d ~/.kiro/agents && echo "✓ Agent config dir"
npx playwright --version && echo "✓ Playwright"
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
