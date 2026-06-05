#!/bin/bash
# review-precheck.sh — REVIEW gate: Pre-review checks
set -euo pipefail

# Usage: review-precheck.sh
# Exit 0: ready for review
# Exit 1: issues found

# Check for TODO/FIXME comments
check_todos() {
  local todos=()

  # Check all source files
  while IFS= read -r file; do
    if grep -n "TODO\|FIXME\|HACK\|XXX" "$file" 2>/dev/null; then
      todos+=("$file")
    fi
  done < <(find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/dist/*" \
    -not -path "*/.git/*" \
    -not -path "*/tests/*" \
    -not -path "*/__tests__/*" \
    -not -path "*.test.*" \
    -not -path "*.spec.*")

  if [[ ${#todos[@]} -gt 0 ]]; then
    for todo in "${todos[@]}"; do
      echo "TODO: $todo has TODO/FIXME comments"
    done
    return 1
  fi
  return 0
}

# Check for console.log/debug statements
check_console_logs() {
  local logs=()

  # Check all source files
  while IFS= read -r file; do
    if grep -n "console\.log\|console\.debug\|console\.warn\|console\.error" "$file" 2>/dev/null; then
      logs+=("$file")
    fi
  done < <(find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/dist/*" \
    -not -path "*/.git/*" \
    -not -path "*/tests/*" \
    -not -path "*/__tests__/*" \
    -not -path "*.test.*" \
    -not -path "*.spec.*")

  if [[ ${#logs[@]} -gt 0 ]]; then
    for log in "${logs[@]}"; do
      echo "CONSOLE: $log has console.log/debug statements"
    done
    return 1
  fi
  return 0
}

# Check test coverage
check_test_coverage() {
  echo "Checking test coverage..."

  # Check if package.json exists
  if [[ ! -f "package.json" ]]; then
    echo "WARNING: No package.json found, skipping coverage check"
    return 0
  fi

  # Check if coverage script exists
  if ! grep -q '"coverage"' package.json 2>/dev/null; then
    echo "WARNING: No coverage script found, skipping coverage check"
    return 0
  fi

  # Run coverage
  if npm run coverage < /dev/null 2>&1; then
    echo "Coverage check passed"
    return 0
  else
    echo "Coverage check failed"
    return 1
  fi
}

# Check for type errors
check_types() {
  echo "Checking types..."

  # Check if package.json exists
  if [[ ! -f "package.json" ]]; then
    echo "WARNING: No package.json found, skipping type check"
    return 0
  fi

  # Run typecheck
  if npm run typecheck < /dev/null 2>&1; then
    echo "Type check passed"
    return 0
  else
    echo "Type check failed"
    return 1
  fi
}

# Check for lint errors
check_lint() {
  echo "Checking lint..."

  # Check if package.json exists
  if [[ ! -f "package.json" ]]; then
    echo "WARNING: No package.json found, skipping lint check"
    return 0
  fi

  # Check if lint script exists
  if ! grep -q '"lint"' package.json 2>/dev/null; then
    echo "WARNING: No lint script found, skipping lint check"
    return 0
  fi

  # Run lint
  if npm run lint < /dev/null 2>&1; then
    echo "Lint check passed"
    return 0
  else
    echo "Lint check failed"
    return 1
  fi
}

# Main
echo "=== REVIEW Gate: Pre-Review Check ==="
echo ""

ERRORS=0

echo "Checking for TODO/FIXME comments..."
if ! check_todos; then
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "Checking for console.log/debug statements..."
if ! check_console_logs; then
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "Checking types..."
if ! check_types; then
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "Checking lint..."
if ! check_lint; then
  ERRORS=$((ERRORS + 1))
fi

echo ""
if [[ $ERRORS -gt 0 ]]; then
  echo "FAIL: Found ${ERRORS} issue(s)"
  exit 1
else
  echo "PASS: Ready for review"
  exit 0
fi
