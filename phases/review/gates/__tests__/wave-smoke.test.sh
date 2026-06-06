#!/bin/bash
# wave-smoke.test.sh — Tests for wave-smoke gate
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_SCRIPT="${TEST_DIR}/../wave-smoke.sh"

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

# Test: Gate passes for clean git state
test_clean_git() {
  # Create temp directory with clean git state
  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"
  git init > /dev/null 2>&1
  
  # Create and commit a file
  echo "test" > test.txt
  git add test.txt > /dev/null 2>&1
  git commit -m "test" > /dev/null 2>&1
  
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

# Test: Gate fails for uncommitted changes
test_uncommitted_changes() {
  # Create temp directory with uncommitted changes
  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"
  git init > /dev/null 2>&1
  
  # Create and commit a file
  echo "test" > test.txt
  git add test.txt > /dev/null 2>&1
  git commit -m "test" > /dev/null 2>&1
  
  # Make uncommitted change
  echo "modified" > test.txt
  
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

# Test: Gate fails for merge conflicts
test_merge_conflicts() {
  # Create temp directory with merge conflicts
  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"
  git init > /dev/null 2>&1
  
  # Create file with conflict markers
  cat > test.txt << 'INNER_EOF'
<<<<<<< HEAD
ours
=======
theirs
>>>>>>> branch
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
run_test "Clean git state" test_clean_git
run_test "Uncommitted changes" test_uncommitted_changes
run_test "Merge conflicts" test_merge_conflicts
