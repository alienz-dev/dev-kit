# Bootstrap development environment

Run the machine setup script. Idempotent — safe to run multiple times.

## Usage

```
/setup [--minimal|--check|--ci]
```

## Instructions

1. Run `./setup.sh` with any flags from `$ARGUMENTS`
2. Report what was installed vs what was already present
3. If `--check` mode, list missing tools without installing

## Arguments

- `$ARGUMENTS` — optional flags

## Modes

| Flag | Behavior |
|------|----------|
| (none) | Full interactive setup — detects OS, installs deps, inits submodules |
| `--minimal` | Just node + git + directories |
| `--check` | Report missing tools, install nothing |
| `--ci` | Non-interactive, suitable for CI/agent sessions |
