#!/bin/bash
# activation-gate.sh — ACTIVATION gate: Verify feature is reachable from entry point
set -euo pipefail

# Usage: activation-gate.sh
# Exit 0: feature is reachable
# Exit 1: feature is not reachable

# Find entry points
find_entry_points() {
  find . -type f \( -name "index.ts" -o -name "index.tsx" -o -name "main.ts" -o -name "main.tsx" -o -name "app.ts" -o -name "app.tsx" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/dist/*" \
    -not -path "*/.git/*" \
    -not -path "*/tests/*"
}

# Find recently modified source files
find_modified_files() {
  git diff --name-only HEAD~1 2>/dev/null | grep -E "\.(ts|tsx|js|jsx)$" | grep -v "node_modules" | grep -v "dist" | grep -v ".git" | grep -v "tests" | grep -v "__tests__" | grep -v "\.test\." | grep -v "\.spec\."
}

# Check if a file is reachable from entry points
is_reachable() {
  local file="$1"
  local basename
  basename=$(basename "$file" | sed 's/\.[^.]*$//')

  # Check if file is imported by any entry point or its dependencies
  local entry_points=()
  while IFS= read -r entry; do
    entry_points+=("$entry")
  done < <(find_entry_points)

  # If no entry points, assume reachable
  if [[ ${#entry_points[@]} -eq 0 ]]; then
    echo "WARNING: No entry points found, assuming reachable"
    return 0
  fi

  # Check if file is imported by entry points
  for entry in "${entry_points[@]}"; do
    if grep -q "from ['\"].*${basename}" "$entry" 2>/dev/null; then
      return 0
    fi
  done

  # Check if file is imported by files imported by entry points (2 levels deep)
  for entry in "${entry_points[@]}"; do
    grep -E "from ['\"]" "$entry" 2>/dev/null | while IFS= read -r line; do
      module=$(echo "$line" | sed -E "s/.*from ['\"]([^'\"]+)['\"].*/\1/")
      if [[ "$module" =~ ^\.{0,2}/ ]]; then
        local dir
        dir=$(dirname "$entry")
        local resolved="${dir}/${module}"
        if [[ ! -f "$resolved" ]]; then
          resolved="${resolved}.ts"
          if [[ ! -f "$resolved" ]]; then
            resolved="${resolved}x"
          fi
        fi
        if [[ -f "$resolved" ]]; then
          if grep -q "from ['\"].*${basename}" "$resolved" 2>/dev/null; then
            return 0
          fi
        fi
      fi
    done
  done

  return 1
}

# Check for dead code paths
check_dead_code() {
  local dead_code=()

  while IFS= read -r file; do
    # Check for unreachable code after return/throw
    # Only flag if there's actual code (not just closing braces) after return/throw
    local line_num
    line_num=$(grep -nE "^\s*(return|throw)\s" "$file" 2>/dev/null | head -1 | cut -d: -f1)
    if [[ -n "$line_num" ]]; then
      local total_lines
      total_lines=$(wc -l < "$file")
      if [[ $line_num -lt $total_lines ]]; then
        # Check if there's actual code after the return/throw
        # Exclude: empty lines, comments, closing braces
        local remaining
        remaining=$(tail -n +$((line_num + 1)) "$file" | grep -v "^\s*$" | grep -v "^\s*//" | grep -v "^\s*/\*" | grep -v "^\s*\*" | grep -v "^\s*}" | grep -v "^\s*)" | grep -v "^\s*;" | head -1)
        if [[ -n "$remaining" ]]; then
          dead_code+=("$file:$line_num:unreachable code after return/throw")
        fi
      fi
    fi
  done < <(find . -type f \( -name "*.ts" -o -name "*.tsx" \) -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/.git/*" -not -path "*/tests/*")

  if [[ ${#dead_code[@]} -gt 0 ]]; then
    for code in "${dead_code[@]}"; do
      echo "DEAD_CODE: $code"
    done
    return 1
  fi
  return 0
}

# Main
echo "=== ACTIVATION Gate: Feature Reachability ==="
echo ""

ERRORS=0

echo "Checking modified files for reachability..."
modified_files=()
while IFS= read -r file; do
  modified_files+=("$file")
done < <(find_modified_files)

if [[ ${#modified_files[@]} -eq 0 ]]; then
  echo "No modified files found, skipping reachability check"
else
  for file in "${modified_files[@]}"; do
    echo "Checking: $file"
    if ! is_reachable "$file"; then
      echo "UNREACHABLE: $file is not reachable from entry points"
      ERRORS=$((ERRORS + 1))
    fi
  done
fi

echo ""
echo "Checking for dead code paths..."
if ! check_dead_code; then
  ERRORS=$((ERRORS + 1))
fi

echo ""
if [[ $ERRORS -gt 0 ]]; then
  echo "FAIL: Found ${ERRORS} issue(s)"
  exit 1
else
  echo "PASS: Feature is reachable"
  exit 0
fi
