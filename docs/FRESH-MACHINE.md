# Fresh Machine Setup

Complete guide to bootstrapping an AI-native development environment from zero.

## Quick Start (recommended)

```bash
# 1. Install Node.js 22
# macOS (Homebrew):
brew install node@22
# or via nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.zshrc && nvm install 22

# 2. Clone and setup
git clone <this-repo> ~/dev-kit
cd ~/dev-kit
./setup.sh

# 3. Create your first project
./scaffold.sh my-project

# 4. Start coding
cd ~/projects/my-project
claude
```

The project has CLAUDE.md (Claude Code instructions), .claude/ (agents, rules, skills, settings), lefthook.yml (pre-commit gate), and .pipeline/ (stage tracking).

## Prerequisites

| Component | Version | Purpose |
|-----------|---------|---------|
| Linux/macOS | Any recent | Base OS |
| bash/zsh | 5.0+ | Shell scripts |
| git | 2.30+ | Version control |
| curl | Any | Downloads |
| jq | 1.6+ | JSON processing |

## Step 1: Node.js

```bash
# macOS (Homebrew — recommended)
brew install node@22

# or via nvm (all platforms):
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.zshrc && nvm install 22  # macOS uses zsh
# Linux: source ~/.bashrc && nvm install 22
```

## Step 2: Python 3

```bash
# macOS
brew install python3

# Linux
sudo apt install python3 python3-pip  # Debian/Ubuntu
sudo dnf install python3 python3-pip  # Fedora
```

## Step 3: Coding Agent

```bash
# Install Claude Code
npm install -g @anthropic/claude-code

# Verify
claude --version
```

## Step 4: Directory Structure

```bash
mkdir -p ~/projects ~/plans ~/.local/bin
```

## Step 5: First Project

```bash
cd ~/dev-kit
./scaffold.sh my-project
cd ~/projects/my-project
claude
```

## Verification Checklist

```bash
# All should pass:
node --version | grep -q v2 && echo "✓ Node 22+"
python3 --version | grep -q "3." && echo "✓ Python 3"
git --version && echo "✓ Git"
jq --version && echo "✓ jq"
command -v claude && echo "✓ Coding agent"
```

## Corporate Environment Extras

### TLS/CA Bundle (Zscaler, corporate proxy)

```bash
# Find your corporate CA bundle
ls /etc/ssl/certs/ca-certificates.crt  # Ubuntu
ls /etc/pki/tls/certs/ca-bundle.crt    # RHEL

# Set for Node.js (add to ~/.bashrc or ~/.zshrc)
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

# Set for Python requests
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
```

### npm Registry (Nexus/Artifactory)

```bash
npm config set registry https://your-nexus.company.com/repository/npm-all/
```

### Git SSH (Bitbucket/GitHub Enterprise)

```bash
ssh-keygen -t ed25519 -C "your-email@company.com"
# Add public key to your git hosting
```
