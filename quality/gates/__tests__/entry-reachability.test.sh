#!/bin/bash
# entry-reachability.test.sh — Tests for WIRING gate
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_SCRIPT="${TEST_DIR}/../entry-reachability.sh"

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

# Test: Gate passes for clean codebase
test_clean_codebase() {
  # Create temp directory with clean code
  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"
  
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

# Test: Gate fails for dead imports
test_dead_imports() {
  # Create temp directory with dead import
  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"

  # Create entry point with dead import
  mkdir -p src
  cat > src/index.ts << 'INNER_EOF'
import { missing } from './nonexistent';
export default function app() {
  return missing();
}
INNER_EOF

  # Verify file exists
  if [[ ! -f "src/index.ts" ]]; then
    echo "ERROR: Test file not created"
    cd - > /dev/null
    rm -rf "$tmp_dir"
    return 1
  fi

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

# Test: Gate fails for orphaned modules
test_orphaned_modules() {
  # Create temp directory with orphaned module
  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"
  
  # Create entry point
  mkdir -p src
  cat > src/index.ts << 'INNER_EOF'
export default function app() {
  return 'hello';
}
INNER_EOF
  
  # Create orphaned module (not imported)
  cat > src/orphaned.ts << 'INNER_EOF'
export default function orphaned() {
  return 'I am orphaned';
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
run_test "Clean codebase" test_clean_codebase
run_test "Dead imports" test_dead_imports
run_test "Orphaned modules" test_orphaned_modules
