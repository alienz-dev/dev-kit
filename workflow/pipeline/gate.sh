#!/bin/bash
# gate.sh — File-based pipeline state management
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE=".pipeline/state.json"
TRANSITIONS_FILE=".pipeline/transitions.json"

usage() {
  echo "Usage: gate.sh {init <feature>|advance <signal>|retreat <signal>|status|check <stage>}"
  exit 1
}

[ $# -lt 1 ] && usage

# --- Helpers ---

read_state() {
  if [ ! -f "$STATE_FILE" ]; then
    echo "ERROR: No pipeline state. Run 'gate.sh init <feature>' first." >&2
    exit 1
  fi
  cat "$STATE_FILE"
}

get_field() {
  local json="$1" field="$2"
  if command -v jq &>/dev/null; then
    echo "$json" | jq -r ".$field"
  else
    echo "$json" | grep -o "\"$field\":\"[^\"]*\"" | cut -d'"' -f4
  fi
}

atomic_write() {
  local content="$1"
  local tmp="$STATE_FILE.tmp.$$"
  echo "$content" > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

lock_state() {
  if command -v flock &>/dev/null; then
    exec 9>"$STATE_FILE.lock"
    flock -n 9 || { echo "ERROR: pipeline state locked by another process" >&2; exit 1; }
  else
    # macOS fallback: simple lock file with PID check
    local lockfile="$STATE_FILE.lock"
    if [ -f "$lockfile" ]; then
      local lock_pid
      lock_pid=$(cat "$lockfile" 2>/dev/null)
      if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
        echo "ERROR: pipeline state locked by PID $lock_pid" >&2; exit 1
      fi
      # Stale lock — remove it
      rm -f "$lockfile"
    fi
    echo $$ > "$lockfile"
  fi
}

TRANSITIONS_SRC="$SCRIPT_DIR/transitions.json"

stage_index() {
  local stage="$1"
  local stages
  if command -v jq &>/dev/null && [ -f "$TRANSITIONS_SRC" ]; then
    # Use read loop instead of mapfile for bash 3 compatibility
    stages=()
    while IFS= read -r line; do
      stages+=("$line")
    done < <(jq -r '.stages[]' "$TRANSITIONS_SRC")
  elif [ -f "$TRANSITIONS_SRC" ]; then
    # grep/sed fallback: extract the stages array
    local raw
    raw=$(grep -o '"stages":\[.*\]' "$TRANSITIONS_SRC" | sed 's/"stages":\[//;s/\]//;s/"//g')
    IFS=',' read -ra stages <<< "$raw"
  else
    # ultimate fallback: hardcoded
    stages=("plan" "test" "sprint" "review" "done" "failed")
  fi
  for i in "${!stages[@]}"; do
    [ "${stages[$i]}" = "$stage" ] && echo "$i" && return
  done
  echo "-1"
}

validate_transition() {
  local signal="$1" current_stage="$2"
  if command -v jq &>/dev/null; then
    local from to
    from=$(jq -r ".transitions.\"$signal\".from // empty" "$TRANSITIONS_FILE")
    to=$(jq -r ".transitions.\"$signal\".to // empty" "$TRANSITIONS_FILE")
    [ -z "$from" ] && echo "" && return
    if [ "$from" = "*" ] || [ "$from" = "$current_stage" ]; then
      echo "$to"
    else
      echo ""
    fi
  else
    # grep fallback
    local block
    block=$(grep -A2 "\"$signal\"" "$TRANSITIONS_FILE" || true)
    [ -z "$block" ] && echo "" && return
    local from to
    from=$(echo "$block" | grep -o '"from":"[^"]*"' | cut -d'"' -f4)
    to=$(echo "$block" | grep -o '"to":"[^"]*"' | cut -d'"' -f4)
    [ -z "$from" ] && echo "" && return
    if [ "$from" = "*" ] || [ "$from" = "$current_stage" ]; then
      echo "$to"
    else
      echo ""
    fi
  fi
}

# --- Commands ---

cmd_init() {
  local feature="${1:?Usage: gate.sh init <feature-name>}"
  mkdir -p .pipeline
  if [ ! -f "$TRANSITIONS_FILE" ]; then
    cp "$SCRIPT_DIR/transitions.json" "$TRANSITIONS_FILE"
  fi
  local now
  now=$(date -Iseconds)
  local state
  state=$(printf '{"stage":"plan","feature":"%s","history":[],"created_at":"%s","last_advance":""}' "$feature" "$now")
  echo "$state" > "$STATE_FILE"
  echo "Pipeline initialized: feature='$feature', stage=plan"
}

cmd_advance() {
  local signal="${1:?Usage: gate.sh advance <signal>}"
  lock_state
  local state current_stage new_stage now
  state=$(read_state)
  current_stage=$(get_field "$state" "stage")
  new_stage=$(validate_transition "$signal" "$current_stage")
  if [ -z "$new_stage" ]; then
    echo "ERROR: Invalid transition '$signal' from stage '$current_stage'" >&2
    exit 1
  fi
  now=$(date -Iseconds)
  if command -v jq &>/dev/null; then
    local new_state
    new_state=$(echo "$state" | jq --arg s "$new_stage" --arg t "$now" --arg sig "$signal" --arg from "$current_stage" \
      '.stage = $s | .last_advance = $t | .history += [{"from": $from, "to": $s, "signal": $sig, "at": $t}]')
    atomic_write "$new_state"
  else
    # Minimal sed-based update (no history append without jq)
    local new_state
    new_state=$(echo "$state" | sed "s/\"stage\":\"$current_stage\"/\"stage\":\"$new_stage\"/" | sed "s/\"last_advance\":\"[^\"]*\"/\"last_advance\":\"$now\"/")
    atomic_write "$new_state"
  fi
  echo "Advanced: $current_stage → $new_stage (signal: $signal)"
}

cmd_retreat() {
  local signal="${1:?Usage: gate.sh retreat <signal>}"
  lock_state
  local state current_stage new_stage now

  # Verify transitions file exists
  if [ ! -f "$TRANSITIONS_FILE" ]; then
    echo "ERROR: transitions file not found at $TRANSITIONS_FILE" >&2
    exit 1
  fi

  state=$(read_state)
  current_stage=$(get_field "$state" "stage")

  # Look up signal and validate "from" matches current stage
  new_stage=$(validate_transition "$signal" "$current_stage")
  if [ -z "$new_stage" ]; then
    # Check if signal exists at all
    local signal_from
    if command -v jq &>/dev/null; then
      signal_from=$(jq -r ".transitions.\"$signal\".from // empty" "$TRANSITIONS_FILE")
    else
      signal_from=$(grep -A2 "\"$signal\"" "$TRANSITIONS_FILE" | grep -o '"from":"[^"]*"' | cut -d'"' -f4 || true)
    fi
    if [ -z "$signal_from" ]; then
      echo "ERROR: unknown signal: $signal" >&2
    else
      echo "ERROR: cannot retreat: current stage is '$current_stage', signal '$signal' requires '$signal_from'" >&2
    fi
    exit 1
  fi

  now=$(date -Iseconds)
  if command -v jq &>/dev/null; then
    local new_state
    new_state=$(echo "$state" | jq --arg s "$new_stage" --arg t "$now" --arg sig "$signal" --arg from "$current_stage" \
      '.stage = $s | .last_advance = $t | .history += [{"from": $from, "to": $s, "signal": $sig, "at": $t, "direction": "backward"}]')
    atomic_write "$new_state"
  else
    # Minimal sed-based update (no history append without jq)
    local new_state
    new_state=$(echo "$state" | sed "s/\"stage\":\"$current_stage\"/\"stage\":\"$new_stage\"/" | sed "s/\"last_advance\":\"[^\"]*\"/\"last_advance\":\"$now\"/")
    atomic_write "$new_state"
  fi
  echo "⚠ Pipeline retreated from $current_stage to $new_stage via $signal"
}

cmd_status() {
  local state current_stage feature last_advance
  state=$(read_state)
  current_stage=$(get_field "$state" "stage")
  feature=$(get_field "$state" "feature")
  last_advance=$(get_field "$state" "last_advance")
  echo "Feature: $feature"
  echo "Stage:   $current_stage"
  echo "Last:    ${last_advance:-never}"
}

cmd_check() {
  local required="${1:?Usage: gate.sh check <required-stage>}"
  local state current_stage cur_idx req_idx
  state=$(read_state)
  current_stage=$(get_field "$state" "stage")
  cur_idx=$(stage_index "$current_stage")
  req_idx=$(stage_index "$required")
  if [ "$cur_idx" -ge "$req_idx" ]; then
    exit 0
  else
    echo "BLOCKED: at '$current_stage', need '$required'" >&2
    exit 1
  fi
}

# --- Dispatch ---
case "${1}" in
  init)    shift; cmd_init "$@" ;;
  advance) shift; cmd_advance "$@" ;;
  retreat) shift; cmd_retreat "$@" ;;
  status)  cmd_status ;;
  check)   shift; cmd_check "$@" ;;
  *)       usage ;;
esac
