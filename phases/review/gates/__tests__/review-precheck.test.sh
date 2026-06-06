#!/bin/bash
# review-precheck.test.sh — Tests for REVIEW gate
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_SCRIPT="${TEST_DIR}/../review-precheck.sh"

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

# Test: Gate passes for clean code
test_clean_code() {
  # Create temp directory with clean code
  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"
  
  # Create clean source file
  mkdir -p src
  cat > src/app.ts << 'INNER_EOF'
export default function app() {
  return 'hello';
}
INNER_EOF
  
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

# Test: Gate fails for TODO comments
test_todo_comments() {
  # Create temp directory with TODO comments
  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"
  
  # Create source file with TODO
  mkdir -p src
  cat > src/app.ts << 'INNER_EOF'
export default function app() {
  // TODO: implement this
  return 'hello';
}
INNER_EOF
  
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

# Test: Gate fails for console.log
test_console_log() {
  # Create temp directory with console.log
  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"
  
  # Create source file with console.log
  mkdir -p src
  cat > src/app.ts << 'INNER_EOF'
export default function app() {
  console.log('debug');
  return 'hello';
}
INNER_EOF
  
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
run_test "Clean code" test_clean_code
run_test "TODO comments" test_todo_comments
run_test "Console.log" test_console_log
