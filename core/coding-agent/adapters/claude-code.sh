#!/bin/bash
# Adapter for Claude Code (claude-code CLI)
# Interface: $1=briefing_path $2=workdir $3=result_path
set -euo pipefail

BRIEFING="${1:?Usage: claude-code.sh <briefing> <workdir> <result>}"
WORKDIR="${2:?}"
RESULT="${3:?}"

cd "$WORKDIR"

# Claude Code uses -p for non-interactive prompt
OUTPUT=$(claude --dangerously-skip-permissions \
  --print \
  --output-format text \
  -p "$(cat "$BRIEFING")" \
  --allowedTools "Edit,Write,Bash,Read" \
  2>/dev/null)

# Write result
cat > "$RESULT" << EOF
# Result

## Status: completed

## Output
$OUTPUT
EOF

exit 0
