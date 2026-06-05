#!/bin/bash
# wave-smoke.sh — Wave completion gate: Verify all tests pass and no uncommitted changes
set -euo pipefail

# Usage: wave-smoke.sh [--fix]
# Exit 0: wave is clean
# Exit 1: wave has issues

FIX_MODE=0
if [[ "${1:-}" == "--fix" ]]; then
  FIX_MODE=1
fi

# Check for uncommitted changes
check_uncommitted_changes() {
  local changes=()

  # Check for staged changes
  if [[ -n "$(git diff --cached --name-only 2>/dev/null)" ]]; then
    changes+=("staged changes")
  fi

  # Check for unstaged changes
  if [[ -n "$(git diff --name-only 2>/dev/null)" ]]; then
    changes+=("unstaged changes")
  fi

  # Check for untracked files
  if [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
    changes+=("untracked files")
  fi

  if [[ ${#changes[@]} -gt 0 ]]; then
    for change in "${changes[@]}"; do
      echo "UNCOMMITTED: $change"
    done
    return 1
  fi
  return 0
}

# Check for merge conflicts
check_merge_conflicts() {
  local conflicts=()

  # Check for conflict markers
  if grep -rn "<<<<<<< " --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.css" --include="*.scss" . 2>/dev/null | grep -v "node_modules" | grep -v "dist" | grep -v ".git"; then
    conflicts+=("merge conflict markers found")
  fi

  if [[ ${#conflicts[@]} -gt 0 ]]; then
    for conflict in "${conflicts[@]}"; do
      echo "CONFLICT: $conflict"
    done
    return 1
  fi
  return 0
}

# Run tests
run_tests() {
  echo "Running tests..."

  # Check if package.json exists
  if [[ ! -f "package.json" ]]; then
    echo "WARNING: No package.json found, skipping test run"
    return 0
  fi

  # Run tests
  if npm test < /dev/null 2>&1; then
    echo "Tests passed"
    return 0
  else
    echo "Tests failed"
    return 1
  fi
}

# Check for TODO/FIXME comments
check_todos() {
  local todos=()

  # Check for TODO/FIXME in modified files
  while IFS= read -r file; do
    if grep -n "TODO\|FIXME\|HACK\|XXX" "$file" 2>/dev/null; then
      todos+=("$file")
    fi
  done < <(git diff --name-only 2>/dev/null)

  if [[ ${#todos[@]} -gt 0 ]]; then
    for todo in "${todos[@]}"; do
      echo "TODO: $todo has TODO/FIXME comments"
    done
    return 1
  fi
  return 0
}

# Main
echo "=== Wave Smoke Gate: Completion Check ==="
echo ""

ERRORS=0

echo "Checking for uncommitted changes..."
if ! check_uncommitted_changes; then
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "Checking for merge conflicts..."
if ! check_merge_conflicts; then
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "Checking for TODO/FIXME comments..."
if ! check_todos; then
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "Running tests..."
if ! run_tests; then
  ERRORS=$((ERRORS + 1))
fi

echo ""
if [[ $ERRORS -gt 0 ]]; then
  echo "FAIL: Found ${ERRORS} issue(s)"
  exit 1
else
  echo "PASS: Wave is clean"
  exit 0
fi
