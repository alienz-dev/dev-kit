#!/bin/bash
# base.sh — Adapter contract template and shared helpers
# This file is NOT executable. Source it from adapters.
#
# Contract:
#   $1 = briefing_path (markdown file with task description)
#   $2 = workdir (directory to operate in)
#   $3 = result_path (where to write result markdown)
#
# Behavior:
#   1. cd to workdir
#   2. Record git state (git rev-parse HEAD, git diff --stat)
#   3. Invoke agent CLI with briefing content
#   4. Capture exit code
#   5. Record changes (git diff --name-only)
#   6. Write result file (ALWAYS — even on failure)
#   7. Exit 0 if agent succeeded, 1 if failed
#
# Mandatory:
#   - timeout 300 wraps ALL agent invocations
#   - Result file MUST be written regardless of success/failure
#   - If AGENTS.md exists in workdir, pass it as context to agent

# Common functions for adapters
write_result() {
  local status="$1" agent="$2" changes="$3" duration="$4" output="$5" result_path="$6"
  cat > "$result_path" << EOF
## Status
$status

## Agent
$agent

## Changes
$changes

## Duration
${duration}s

## Output
$(echo "$output" | head -100)
EOF
}
