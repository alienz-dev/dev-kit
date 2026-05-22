#!/bin/bash
# stop-server.sh — Stop a server started by start-server.sh
# Usage: stop-server.sh <port>
set -euo pipefail
[[ $# -ne 1 ]] && { echo "Usage: stop-server.sh <port>"; exit 1; }
PORT="$1"
PIDFILE="/tmp/.server-${PORT}.pid"
if [[ ! -f "$PIDFILE" ]]; then
  echo "No server tracked on port $PORT"
  exit 0
fi
PID=$(cat "$PIDFILE")
if kill -0 "$PID" 2>/dev/null; then
  kill "$PID" 2>/dev/null
  sleep 1
  kill -0 "$PID" 2>/dev/null && kill -9 "$PID" 2>/dev/null
  echo "Server (PID $PID) on port $PORT stopped"
else
  echo "Server (PID $PID) already dead"
fi
rm -f "$PIDFILE"
