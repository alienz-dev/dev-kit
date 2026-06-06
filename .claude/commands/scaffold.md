# Scaffold a new project

Create a new project with AI-native development infrastructure.

## Usage

```
/scaffold <project-name> [directory] [--minimal]
```

## Instructions

1. Validate the project name (lowercase, hyphens, no spaces)
2. Check if the target directory already exists
3. Run the scaffold script:
   - Full: `./scaffold.sh <name> [dir]`
   - Minimal: `./scaffold.sh <name> [dir] --minimal`
4. Report what was created:
   - Files generated
   - Whether `npm install` succeeded (full mode)
   - Next steps for the user

## Arguments

- `$ARGUMENTS` — project name and optional flags (e.g. `my-app --minimal`)

## Modes

| Mode | Command | What it creates |
|------|---------|-----------------|
| Full | `./scaffold.sh my-app` | package.json, tsconfig, vitest, AGENTS.md, CLAUDE.md, lefthook, pipeline state, .claude/ with agents/hooks/rules/skills |
| Minimal | `./scaffold.sh my-app --minimal` | AGENTS.md, CLAUDE.md, lefthook, pipeline state only |

Parse `$ARGUMENTS` to extract the project name, optional directory, and `--minimal` flag.
