# LLM Proxy

## Problem

In corporate environments, direct LLM API access is blocked or requires:
- Token refresh (AWS SSO, OAuth, API key rotation)
- TLS interception handling (Zscaler, corporate proxy)
- Request translation (different API formats)
- Audit logging

## Architecture

```
Agent CLI → localhost:8080 (proxy) → LLM API (Anthropic, Bedrock, etc.)
                                  ↑
                          Token refresh timer
```

## Why a Proxy

1. **Single endpoint** — all agents hit localhost:8080, no per-agent config
2. **Token refresh** — separate timer handles auth, proxy always has valid token
3. **CA bundle** — proxy handles TLS, agents don't need NODE_EXTRA_CA_CERTS
4. **Translation** — convert between API formats (e.g., AWS Bedrock → Anthropic)
5. **Logging** — audit all LLM calls without modifying agent code

## Implementation Options

### Option A: Go (recommended for production)
- Single binary, no runtime deps
- Fast startup, low memory
- See `cw-proxy` reference implementation

### Option B: Node.js (quick setup)
```javascript
// Simple proxy with token injection
import { createServer } from 'http';
import { request } from 'https';

const TOKEN = readTokenFromFile('/tmp/llm-token');

createServer((req, res) => {
  const proxy = request({
    hostname: 'api.anthropic.com',
    path: req.url,
    method: req.method,
    headers: { ...req.headers, 'x-api-key': TOKEN }
  }, (proxyRes) => {
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res);
  });
  req.pipe(proxy);
}).listen(8080);
```

### Option C: No proxy (direct API key)
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
# Agents use API directly — simplest but no token refresh
```

## Token Refresh

Separate systemd timer refreshes token every N minutes:

```ini
# llm-token-refresh.timer
[Timer]
OnBootSec=1min
OnUnitActiveSec=30min

# llm-token-refresh.service
[Service]
Type=oneshot
ExecStart=/path/to/refresh-token.sh
```

Token written to known path, proxy reads on each request (or watches for changes).

## Corporate TLS (Zscaler)

```bash
# Proxy handles TLS with corporate CA bundle
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

# Agents don't need CA config — they talk to localhost (plain HTTP or self-signed)
```

## Health Check

```bash
curl -s http://localhost:8080/health
# Returns: {"status": "ok", "token_age_seconds": 1234, "upstream": "reachable"}
```

## Preflight Integration

```yaml
# In project agents.yml
preflight:
  - check: command
    name: LLM proxy reachable
    command: curl -sf http://localhost:8080/health
    fix: systemctl --user start llm-proxy
```
