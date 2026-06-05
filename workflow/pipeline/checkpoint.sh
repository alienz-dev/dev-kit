#!/bin/bash
# checkpoint.sh — Write stage-specific pipeline checkpoint artifacts
set -euo pipefail

# Usage: checkpoint.sh <stage> <json-payload>
# Writes .pipeline/checkpoint-<stage>.json
#
# Stages and their expected payloads:
#
#   checkpoint.sh test '{"visible_tests":[...],"hidden_tests":[...],"spec_coverage":{...},"all_red":true}'
#   checkpoint.sh sprint '{"waves":[...],"gates_passed":[...],"hidden_status":"passed"}'
#   checkpoint.sh review '{"reviewer":"reviewer-lite","tier":2,"findings":{...},"verdict":"pass-with-minor"}'

STAGE="${1:?Usage: checkpoint.sh <stage> <json-payload>}"
PAYLOAD="${2:?Usage: checkpoint.sh <stage> <json-payload>}"

PIPELINE_DIR=".pipeline"
CHECKPOINT_FILE="$PIPELINE_DIR/checkpoint-$STAGE.json"

if [ ! -d "$PIPELINE_DIR" ]; then
  echo "ERROR: No pipeline directory. Run 'gate.sh init <feature>' first." >&2
  exit 1
fi

# Validate JSON
if command -v jq &>/dev/null; then
  if ! echo "$PAYLOAD" | jq empty 2>/dev/null; then
    echo "ERROR: Invalid JSON payload" >&2
    exit 1
  fi
  # Add timestamp
  PAYLOAD=$(echo "$PAYLOAD" | jq --arg ts "$(date -Iseconds)" '. + {timestamp: $ts}')
else
  # Without jq, just write as-is
  :
fi

echo "$PAYLOAD" > "$CHECKPOINT_FILE"
echo "Checkpoint written: $CHECKPOINT_FILE"
