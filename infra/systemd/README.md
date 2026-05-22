# Systemd Service Templates

User-level services for development daemons.

## Installation

```bash
mkdir -p ~/.config/systemd/user
cp infra/systemd/*.service ~/.config/systemd/user/
cp infra/systemd/*.timer ~/.config/systemd/user/
systemctl --user daemon-reload
```

## Available Services

| Service | Purpose | Type |
|---------|---------|------|
| kiro-sessiond.service | Agent session daemon | always-on |

## Patterns

### Always-On Service
```ini
[Service]
Type=simple
Restart=on-failure
RestartSec=5
```

### Timer-Triggered (periodic)
```ini
[Timer]
OnCalendar=*-*-* 10:00:00
Persistent=true

[Service]
Type=oneshot
```

### Environment
- Use `%h` for home directory (expands at runtime)
- Set PATH to include ~/.local/bin and node
- Use `Environment=NODE_EXTRA_CA_CERTS=...` for corporate TLS
