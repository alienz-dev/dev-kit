#!/bin/bash
# hot-memory.sh — Manage bounded curated context per workspace
# Usage: hot-memory.sh add|replace|remove "<entry>" <workspace>
set -euo pipefail

# Portable sed in-place (BSD on macOS, GNU on Linux)
_sed_i() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

ACTION="${1:?Usage: hot-memory.sh add|replace|remove \"<entry>\" <workspace>}"
ENTRY="${2:?}"
BUDGET=3000

# For add/remove: $2=entry, $3=workspace
# For replace:    $2=old, $3=new, $4=workspace
case "$ACTION" in
  replace) WORKSPACE="${4:-default}" ;;
  *)       WORKSPACE="${3:-default}" ;;
esac

STATE_DIR="${STATE_DIR:-${HOME}/.state}"
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
    _sed_i "s/^char-count:.*/char-count: $(wc -c < "$FILE")/" "$FILE"
    _sed_i "s/^updated:.*/updated: $(date -Iseconds)/" "$FILE"
    echo "Added to $WORKSPACE hot memory"
    ;;
  replace)
    OLD="$ENTRY"
    NEW="${3:?Usage: hot-memory.sh replace \"<old>\" \"<new>\" <workspace>}"
    # Match with or without "- " prefix (add prepends it)
    if grep -qF -- "$OLD" "$FILE" || grep -qF -- "- $OLD" "$FILE"; then
      _sed_i "s|.*${OLD}.*|- ${NEW}|" "$FILE"
      _sed_i "s/^char-count:.*/char-count: $(wc -c < "$FILE")/" "$FILE"
      _sed_i "s/^updated:.*/updated: $(date -Iseconds)/" "$FILE"
      echo "Replaced in $WORKSPACE hot memory"
    else
      echo "ERROR: Entry not found: $OLD"
      exit 1
    fi
    ;;
  remove)
    # Match with or without "- " prefix (add prepends it)
    if grep -qF -- "$ENTRY" "$FILE" || grep -qF -- "- $ENTRY" "$FILE"; then
      # Remove both forms
      grep -vF -- "$ENTRY" "$FILE" | grep -vF -- "- $ENTRY" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
      _sed_i "s/^char-count:.*/char-count: $(wc -c < "$FILE")/" "$FILE"
      _sed_i "s/^updated:.*/updated: $(date -Iseconds)/" "$FILE"
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
