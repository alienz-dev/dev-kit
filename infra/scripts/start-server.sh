#!/bin/bash
# start-server.sh — Safely start a background server
# Usage: start-server.sh <port> <logfile> [--wait N] -- <command...>
set -euo pipefail

PORT="${1:?Usage: start-server.sh <port> <logfile> [--wait N] -- <command...>}"
LOGFILE="${2:?}"
shift 2

WAIT=5
while [[ "${1:-}" != "--" && $# -gt 0 ]]; do
  case "$1" in
    --wait) WAIT="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ "${1:-}" == "--" ]] && shift

# Check if port already in use
if command -v lsof &>/dev/null && lsof -i :"$PORT" &>/dev/null; then
  echo "Port $PORT already in use"
  exit 0
fi

# Start server with stdout/stderr captured, stdin closed
"$@" > "$LOGFILE" 2>&1 < /dev/null &
PID=$!

# Wait for port to be ready
for i in $(seq 1 "$WAIT"); do
  if command -v lsof &>/dev/null && lsof -i :"$PORT" &>/dev/null; then
    echo "Server started on port $PORT (PID $PID, log: $LOGFILE)"
    exit 0
  fi
  sleep 1
done

# Check if process is still alive
if kill -0 "$PID" 2>/dev/null; then
  echo "Server started (PID $PID) but port $PORT not yet listening after ${WAIT}s"
  echo "Log: $LOGFILE"
else
  echo "Server failed to start. Log:"
  tail -20 "$LOGFILE"
  exit 1
fi
