#!/bin/bash
# activation-gate.test.sh — Tests for ACTIVATION gate
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_SCRIPT="${TEST_DIR}/../activation-gate.sh"

# Test helper
run_test() {
  local test_name="$1"
  local test_func="$2"

  echo "Running: $test_name"
  if $test_func; then
    echo "  PASS"
    return 0
  else
    echo "  FAIL"
    return 1
  fi
}

# Test: Gate passes for reachable feature
test_reachable_feature() {
  # Create temp directory with reachable feature
  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"
  git init > /dev/null 2>&1

  # Create entry point
  mkdir -p src
  cat > src/index.ts << 'INNER_EOF'
export { default } from './app';
INNER_EOF

  # Create app module
  cat > src/app.ts << 'INNER_EOF'
export default function app() {
  return 'hello';
}
INNER_EOF

  # Commit
  git add . > /dev/null 2>&1
  git commit -m "initial" > /dev/null 2>&1

  # Run gate
  if bash "$GATE_SCRIPT" > /dev/null 2>&1; then
    cd - > /dev/null
    rm -rf "$tmp_dir"
    return 0
  else
    cd - > /dev/null
    rm -rf "$tmp_dir"
    return 1
  fi
}

# Test: Gate fails for unreachable feature
test_unreachable_feature() {
  # Create temp directory with unreachable feature
  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"
  git init > /dev/null 2>&1

  # Create entry point
  mkdir -p src
  cat > src/index.ts << 'INNER_EOF'
export default function app() {
  return 'hello';
}
INNER_EOF

  # Commit
  git add . > /dev/null 2>&1
  git commit -m "initial" > /dev/null 2>&1

  # Create unreachable module (committed but not imported)
  cat > src/unreachable.ts << 'INNER_EOF'
export default function unreachable() {
  return 'I am unreachable';
}
INNER_EOF

  # Commit unreachable file
  git add . > /dev/null 2>&1
  git commit -m "add unreachable" > /dev/null 2>&1

  # Run gate (should fail)
  if bash "$GATE_SCRIPT" > /dev/null 2>&1; then
    cd - > /dev/null
    rm -rf "$tmp_dir"
    return 1  # Should have failed
  else
    cd - > /dev/null
    rm -rf "$tmp_dir"
    return 0  # Correctly failed
  fi
}

# Run tests
run_test "Reachable feature" test_reachable_feature
run_test "Unreachable feature" test_unreachable_feature
