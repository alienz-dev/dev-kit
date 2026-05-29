#!/bin/bash
# Adapter: OpenAI Codex CLI
# Requires: codex CLI installed
set -euo pipefail
source "$(dirname "$0")/base.sh"

BRIEFING="$1"
WORKDIR="$2"
RESULT="$3"
AGENT="codex"

cd "$WORKDIR"
START=$(date +%s)

TASK=$(cat "$BRIEFING")

# Codex reads AGENTS.md natively from workdir — no extra flag needed

# Run with timeout
OUTPUT=$(timeout 300 codex exec "$TASK" --approval-mode full-auto --quiet 2>&1) || EXIT_CODE=$?
EXIT_CODE=${EXIT_CODE:-0}

DURATION=$(( $(date +%s) - START ))
CHANGES=$(git diff --name-only 2>/dev/null || echo "")

if [ $EXIT_CODE -eq 124 ]; then
  write_result "timeout" "$AGENT" "$CHANGES" "$DURATION" "Agent exceeded 300s timeout" "$RESULT"
  exit 1
elif [ $EXIT_CODE -ne 0 ]; then
  write_result "failed" "$AGENT" "$CHANGES" "$DURATION" "$OUTPUT" "$RESULT"
  exit 1
else
  write_result "success" "$AGENT" "$CHANGES" "$DURATION" "$OUTPUT" "$RESULT"
  exit 0
fi
