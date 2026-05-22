#!/bin/bash
# Adapter for Aider
# Interface: $1=briefing_path $2=workdir $3=result_path
set -euo pipefail

BRIEFING="${1:?Usage: aider.sh <briefing> <workdir> <result>}"
WORKDIR="${2:?}"
RESULT="${3:?}"

cd "$WORKDIR"

# Aider operates on files, uses --message-file for the task
aider --yes-always \
  --no-auto-commits \
  --no-git \
  --message-file "$BRIEFING" \
  2>/dev/null

# Aider modifies files in place — result is the git diff
DIFF=$(git diff 2>/dev/null || echo "no git diff available")

cat > "$RESULT" << EOF
# Result

## Status: completed

## Changes
\`\`\`diff
$DIFF
\`\`\`
EOF

exit 0
