#!/bin/bash
# Pre-commit test gate: runs vitest --changed HEAD with 60s timeout.
# Fail-closed: any non-zero exit blocks the commit.
# Supports VITEST_BIN env override for testing.

set -o pipefail

# Allow test harness to override vitest binary and changed files
VITEST="${VITEST_BIN:-npx vitest run --changed HEAD --reporter=dot --bail 1}"
CHANGED_FILES="${GIT_DIFF_FILES:-$(git diff --cached --name-only 2>/dev/null)}"

# Frontend supplement: detect vanilla JS/CSS changes that vitest --changed can't map
EXTRA_TESTS=""

if echo "$CHANGED_FILES" | grep -qF 'src/dashboard/public/css/ai-native.css'; then
  EXTRA_TESTS="$EXTRA_TESTS tests/dashboard/ tests/unit/frontend/"
elif echo "$CHANGED_FILES" | grep -q 'src/dashboard/public/js/workbench/'; then
  # Map workbench/<name>.js → tests/dashboard/<name>/
  for f in $(echo "$CHANGED_FILES" | grep 'src/dashboard/public/js/workbench/' | sed 's|.*/||;s|\.js$||'); do
    if [ -d "tests/dashboard/$f" ]; then
      EXTRA_TESTS="$EXTRA_TESTS tests/dashboard/$f/"
    elif [ -d "tests/dashboard/${f}-panel" ]; then
      EXTRA_TESTS="$EXTRA_TESTS tests/dashboard/${f}-panel/"
    else
      EXTRA_TESTS="$EXTRA_TESTS tests/dashboard/"
    fi
  done
elif echo "$CHANGED_FILES" | grep -qE 'src/dashboard/public/js/[^/]+\.js$'; then
  # Shared root JS files → all dashboard tests
  EXTRA_TESTS="$EXTRA_TESTS tests/dashboard/"
fi

# If no changed files and no extra tests, nothing to do
if [ -z "$CHANGED_FILES" ] && [ -z "$EXTRA_TESTS" ]; then
  exit 0
fi

# Run vitest with 60 second timeout
if [ -n "$EXTRA_TESTS" ]; then
  timeout 60 bash -c "$VITEST $EXTRA_TESTS" 2>&1
else
  timeout 60 bash -c "$VITEST" 2>&1
fi

exit_code=$?

if [ $exit_code -ne 0 ]; then
  echo "❌ Test gate FAILED (exit code: $exit_code). Commit blocked." >&2
  exit $exit_code
fi

exit 0
