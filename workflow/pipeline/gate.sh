#!/bin/bash
# gate.sh — File-based pipeline state management
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE=".pipeline/state.json"
TRANSITIONS_FILE=".pipeline/transitions.json"

usage() {
  echo "Usage: gate.sh {init <feature>|advance <signal>|status|check <stage>}"
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
  exec 9>"$STATE_FILE.lock"
  flock -n 9 || { echo "ERROR: pipeline state locked by another process" >&2; exit 1; }
}

stage_index() {
  local stage="$1"
  local stages=("plan" "test" "sprint" "review" "done" "failed")
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
  status)  cmd_status ;;
  check)   shift; cmd_check "$@" ;;
  *)       usage ;;
esac
