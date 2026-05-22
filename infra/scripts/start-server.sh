#!/bin/bash
# start-server.sh — Launch a background server with full fd isolation
# Solves: execute_bash hangs when agents background servers
#
# Usage: start-server.sh <port> <logfile> [--wait <seconds>] -- <command...>
# Example: start-server.sh 3000 /tmp/server.log --wait 3 -- npx tsx server.ts
#
# What it does:
#   1. Redirects ALL fds (stdin/stdout/stderr) to /dev/null or logfile
#   2. Runs the command in a new session (setsid) so no fd leaks to parent
#   3. Writes PID to /tmp/.server-<port>.pid
#   4. Optionally waits and checks if server is listening on <port>
#   5. Returns immediately — execute_bash never hangs
#
# Exit codes:
#   0 = server started (and responding if --wait used)
#   1 = usage error
#   2 = server failed to start (exited early)
#   3 = server not responding on port after wait

set -euo pipefail

usage() {
  echo "Usage: start-server.sh <port> <logfile> [--wait <seconds>] -- <command...>"
  exit 1
}

[[ $# -lt 4 ]] && usage

PORT="$1"; shift
LOGFILE="$1"; shift

WAIT_SECS=3
while [[ $# -gt 0 ]]; do
  case "$1" in
    --wait) WAIT_SECS="$2"; shift 2 ;;
    --) shift; break ;;
    *) usage ;;
  esac
done

[[ $# -eq 0 ]] && usage

PIDFILE="/tmp/.server-${PORT}.pid"

# Kill any existing server on this port
if [[ -f "$PIDFILE" ]]; then
  OLD_PID=$(cat "$PIDFILE" 2>/dev/null || true)
  if [[ -n "$OLD_PID" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
    echo "Killing existing server (PID $OLD_PID) on port $PORT"
    kill "$OLD_PID" 2>/dev/null || true
    sleep 1
    kill -9 "$OLD_PID" 2>/dev/null || true
  fi
  rm -f "$PIDFILE"
fi

# Launch with full fd isolation:
# - setsid: new session, no controlling terminal
# - stdout/stderr → logfile
# - stdin ← /dev/null
# - & backgrounds it
# - The subshell + exec ensures the command replaces the shell
setsid bash -c 'echo $$ > "'"$PIDFILE"'"; exec "$@" > "'"$LOGFILE"'" 2>&1 < /dev/null' _ "$@" &
disown

# Brief pause to let process start
sleep 0.5

# Check it didn't die immediately
if [[ -f "$PIDFILE" ]]; then
  SERVER_PID=$(cat "$PIDFILE" 2>/dev/null || true)
  if [[ -n "$SERVER_PID" ]] && ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "ERROR: Server exited immediately. Log:"
    tail -20 "$LOGFILE" 2>/dev/null || true
    exit 2
  fi
  echo "Server started (PID $SERVER_PID) on port $PORT"
  echo "Log: $LOGFILE"
else
  echo "ERROR: PID file not created"
  exit 2
fi

# Wait for port to be listening
if [[ "$WAIT_SECS" -gt 0 ]]; then
  echo "Waiting up to ${WAIT_SECS}s for port $PORT..."
  ELAPSED=0
  while [[ $ELAPSED -lt $WAIT_SECS ]]; do
    if ss -tlnp 2>/dev/null | grep -q ":${PORT} " || \
       netstat -tlnp 2>/dev/null | grep -q ":${PORT} "; then
      echo "Port $PORT is listening"
      exit 0
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
  done
  echo "WARNING: Port $PORT not listening after ${WAIT_SECS}s (server may still be starting)"
  echo "Last 5 lines of log:"
  tail -5 "$LOGFILE" 2>/dev/null || true
  exit 3
fi

exit 0
