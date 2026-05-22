#!/bin/bash
# stop-server.sh — Stop a server by port
# Usage: stop-server.sh <port>
set -euo pipefail

PORT="${1:?Usage: stop-server.sh <port>}"

if ! command -v lsof &>/dev/null; then
  # Fallback: use fuser
  fuser -k "$PORT/tcp" 2>/dev/null && echo "Stopped server on port $PORT" || echo "No server on port $PORT"
  exit 0
fi

PID=$(lsof -ti :"$PORT" 2>/dev/null | head -1)

if [ -z "$PID" ]; then
  echo "No server on port $PORT"
  exit 0
fi

kill "$PID" 2>/dev/null
sleep 1

if kill -0 "$PID" 2>/dev/null; then
  kill -9 "$PID" 2>/dev/null
  echo "Force-killed server on port $PORT (PID $PID)"
else
  echo "Stopped server on port $PORT (PID $PID)"
fi
