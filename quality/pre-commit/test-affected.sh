#!/bin/bash
# test-affected.sh — identifies regressions between commits.
# Default: compares HEAD~1 vs HEAD
# Usage: test-affected.sh [--since <commit>] [--deep]

set -o pipefail

# Timeout command with macOS fallback
if command -v timeout &>/dev/null; then
  TIMEOUT_CMD="timeout"
elif command -v gtimeout &>/dev/null; then
  TIMEOUT_CMD="gtimeout"
else
  TIMEOUT_CMD=""
fi

SINCE_COMMIT="HEAD~1"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)
      SINCE_COMMIT="$2"
      shift 2
      ;;
    --deep)
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate commit ref
if ! git rev-parse "$SINCE_COMMIT" >/dev/null 2>&1; then
  echo "ERROR: Invalid commit reference: $SINCE_COMMIT" >&2
  exit 1
fi

# Get changed files between commits
CHANGED=$(git diff --name-only "$SINCE_COMMIT" HEAD 2>/dev/null)

if [ -z "$CHANGED" ]; then
  echo "✓ No regressions detected"
  exit 0
fi

# Run vitest on affected tests and capture results
if [ -n "$TIMEOUT_CMD" ]; then
  VITEST_OUTPUT=$($TIMEOUT_CMD 120 npx vitest run --changed "$SINCE_COMMIT" --reporter=verbose 2>&1)
else
  VITEST_OUTPUT=$(npx vitest run --changed "$SINCE_COMMIT" --reporter=verbose 2>&1)
fi
exit_code=$?

if [ $exit_code -eq 0 ]; then
  echo "✓ No regressions detected"
  exit 0
fi

# Parse and report: file name, test name, pass/fail status change
echo "Regressions detected between $SINCE_COMMIT and HEAD:"
echo ""
echo "Changed files:"
echo "$CHANGED" | while read -r file; do
  echo "  - $file"
done
echo ""
echo "Test results (PASS → FAIL status change):"
echo "$VITEST_OUTPUT" | grep -E "FAIL|✗|×" | while read -r line; do
  echo "  $line"
done

exit $exit_code
