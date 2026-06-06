#!/bin/bash
# sync.sh — Re-sync base files from dev-kit into a scaffolded project
# NEVER touches .claude/project/ or settings.local.json (project overlay)
set -euo pipefail

DEV_KIT_DIR="${1:?Usage: sync.sh <dev-kit-path> [project-path]}"
PROJECT_DIR="${2:-.}"

if [ ! -d "$DEV_KIT_DIR/phases" ]; then
  echo "Error: $DEV_KIT_DIR does not look like a dev-kit repo (no phases/ directory)"
  exit 1
fi

if [ ! -d "$PROJECT_DIR/.claude" ]; then
  echo "Error: $PROJECT_DIR does not have a .claude/ directory. Run scaffold.sh first."
  exit 1
fi

echo "=== Syncing dev-kit base files ==="
echo "Source: $DEV_KIT_DIR"
echo "Target: $PROJECT_DIR"

cd "$PROJECT_DIR"

# --- Agents ---
echo "Syncing agents..."
for phase_dir in design implement review; do
  if [ -d "$DEV_KIT_DIR/phases/$phase_dir/agents" ]; then
    for f in "$DEV_KIT_DIR/phases/$phase_dir/agents/"*.md; do
      [ -f "$f" ] || continue
      name=$(basename "$f")
      # Skip if project has an override
      if [ -f ".claude/project/agents/$name" ]; then
        echo "  SKIP agents/$name (project override exists)"
      else
        cp "$f" ".claude/agents/$name"
      fi
    done
  fi
done

# --- Rules ---
echo "Syncing rules..."
for phase_dir in design implement review shared; do
  if [ -d "$DEV_KIT_DIR/phases/$phase_dir/rules" ]; then
    for f in "$DEV_KIT_DIR/phases/$phase_dir/rules/"*.md; do
      [ -f "$f" ] || continue
      name=$(basename "$f")
      if [ -f ".claude/project/rules/$name" ]; then
        echo "  SKIP rules/$name (project override exists)"
      else
        cp "$f" ".claude/rules/$name"
      fi
    done
  fi
done

# --- Skills ---
echo "Syncing skills..."
for phase_dir in design implement shared; do
  if [ -d "$DEV_KIT_DIR/phases/$phase_dir/skills" ]; then
    for skill_dir in "$DEV_KIT_DIR/phases/$phase_dir/skills/"*/; do
      [ -d "$skill_dir" ] || continue
      name=$(basename "$skill_dir")
      if [ -d ".claude/project/skills/$name" ]; then
        echo "  SKIP skills/$name (project override exists)"
      else
        cp -r "$skill_dir" ".claude/skills/$name"
      fi
    done
  fi
done

# --- Hooks ---
echo "Syncing hooks..."
for hook_dir in "$DEV_KIT_DIR/phases/shared/hooks/"*.sh "$DEV_KIT_DIR/phases/implement/hooks/"*.sh; do
  [ -f "$hook_dir" ] || continue
  name=$(basename "$hook_dir")
  if [ -f ".claude/project/hooks/$name" ]; then
    echo "  SKIP hooks/$name (project override exists)"
  else
    cp "$hook_dir" ".claude/hooks/$name"
    chmod +x ".claude/hooks/$name"
  fi
done

# --- Workflows ---
echo "Syncing workflows..."
if [ -d "$DEV_KIT_DIR/.claude/workflows" ]; then
  mkdir -p .claude/workflows
  for f in "$DEV_KIT_DIR/.claude/workflows/"*.md; do
    [ -f "$f" ] || continue
    cp "$f" ".claude/workflows/"
  done
fi

# --- settings.json (base only, not settings.local.json) ---
echo "Syncing settings.json..."
if [ -f "$DEV_KIT_DIR/.claude/settings.json" ]; then
  cp "$DEV_KIT_DIR/.claude/settings.json" ".claude/settings.json"
fi

# --- NEVER touch these ---
# .claude/project/     — project-specific extensions
# .claude/settings.local.json — project overlay
# CLAUDE.md            — project instructions
# AGENTS.md            — cross-tool instructions

echo ""
echo "=== Done ==="
echo "Base files synced. Project overrides in .claude/project/ were preserved."
echo "settings.local.json was NOT touched."
