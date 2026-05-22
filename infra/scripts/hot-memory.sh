#!/bin/bash
# hot-memory.sh — Manage bounded curated context per workspace
# Usage: hot-memory.sh add|replace|remove "<entry>" <workspace>
set -euo pipefail

ACTION="${1:?Usage: hot-memory.sh add|replace|remove \"<entry>\" <workspace>}"
ENTRY="${2:?}"
WORKSPACE="${3:-default}"
BUDGET=3000

STATE_DIR="${HOME}/.kiro/state"
mkdir -p "$STATE_DIR"
FILE="$STATE_DIR/hot-memory-${WORKSPACE}.md"

# Create if doesn't exist
if [ ! -f "$FILE" ]; then
  cat > "$FILE" << EOF
---
workspace: $WORKSPACE
budget: $BUDGET
char-count: 0
updated: $(date -Iseconds)
---

## Agent Memory

EOF
fi

case "$ACTION" in
  add)
    # Check budget
    CURRENT=$(wc -c < "$FILE")
    NEW_LEN=${#ENTRY}
    if (( CURRENT + NEW_LEN + 3 > BUDGET )); then
      echo "ERROR: Would exceed budget ($BUDGET chars). Current: $CURRENT, adding: $NEW_LEN"
      echo "Remove entries first: hot-memory.sh remove \"<entry>\" $WORKSPACE"
      exit 1
    fi
    echo "- $ENTRY" >> "$FILE"
    # Update metadata
    sed -i "s/^char-count:.*/char-count: $(wc -c < "$FILE")/" "$FILE"
    sed -i "s/^updated:.*/updated: $(date -Iseconds)/" "$FILE"
    echo "Added to $WORKSPACE hot memory"
    ;;
  replace)
    OLD="$ENTRY"
    NEW="${4:?Usage: hot-memory.sh replace \"<old>\" \"<new>\" <workspace>}"
    if grep -qF "$OLD" "$FILE"; then
      sed -i "s|.*${OLD}.*|- ${NEW}|" "$FILE"
      sed -i "s/^char-count:.*/char-count: $(wc -c < "$FILE")/" "$FILE"
      sed -i "s/^updated:.*/updated: $(date -Iseconds)/" "$FILE"
      echo "Replaced in $WORKSPACE hot memory"
    else
      echo "ERROR: Entry not found: $OLD"
      exit 1
    fi
    ;;
  remove)
    if grep -qF "$ENTRY" "$FILE"; then
      grep -vF "$ENTRY" "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
      sed -i "s/^char-count:.*/char-count: $(wc -c < "$FILE")/" "$FILE"
      sed -i "s/^updated:.*/updated: $(date -Iseconds)/" "$FILE"
      echo "Removed from $WORKSPACE hot memory"
    else
      echo "ERROR: Entry not found: $ENTRY"
      exit 1
    fi
    ;;
  *)
    echo "Unknown action: $ACTION"
    echo "Usage: hot-memory.sh add|replace|remove \"<entry>\" <workspace>"
    exit 1
    ;;
esac
