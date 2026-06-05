#!/bin/bash
# entry-reachability.sh — WIRING gate: Check for orphaned modules and dead imports
set -euo pipefail

# Usage: entry-reachability.sh [--fix]
# Exit 0: all modules are reachable
# Exit 1: orphaned modules or dead imports found

FIX_MODE=0
if [[ "${1:-}" == "--fix" ]]; then
  FIX_MODE=1
fi

# Find all TypeScript/JavaScript source files
find_src_files() {
  find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/dist/*" \
    -not -path "*/.git/*" \
    -not -path "*/tests/*" \
    -not -path "*/__tests__/*" \
    -not -path "*.test.*" \
    -not -path "*.spec.*" \
    -not -path "*/coverage/*" \
    -not -path "*/.next/*" \
    -not -path "*/build/*"
}

# Find entry points (index files, main files, app files)
find_entry_points() {
  find . -type f \( -name "index.ts" -o -name "index.tsx" -o -name "main.ts" -o -name "main.tsx" -o -name "app.ts" -o -name "app.tsx" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/dist/*" \
    -not -path "*/.git/*" \
    -not -path "*/tests/*"
}

# Check if a file is imported by any other file
is_imported() {
  local file="$1"
  local basename
  basename=$(basename "$file" | sed 's/\.[^.]*$//')

  # Search for imports of this file
  grep -r "from ['\"].*${basename}" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" . 2>/dev/null | \
    grep -v "node_modules" | \
    grep -v "dist/" | \
    grep -v ".git/" | \
    grep -v "tests/" | \
    grep -v "__tests__" | \
    grep -v "*.test.*" | \
    grep -v "*.spec.*" | \
    grep -v "${file}" | \
    head -1 | \
    wc -l
}

# Check for dead imports (importing non-existent modules)
check_dead_imports() {
  local dead_count=0

  while IFS= read -r file; do
    # Extract import statements
    while IFS= read -r line; do
      # Extract module path
      module=$(echo "$line" | sed -E "s/.*from ['\"]([^'\"]+)['\"].*/\1/")

      # Skip node_modules (package imports)
      if [[ ! "$module" =~ ^\.{0,2}/ ]]; then
        continue
      fi

      # Resolve relative path
      local dir
      dir=$(dirname "$file")
      local resolved="${dir}/${module}"

      # Normalize path (remove ./)
      resolved=$(echo "$resolved" | sed 's|/\./|/|g')

      # Check if file exists (with or without extension)
      local found=0
      if [[ -f "$resolved" ]]; then
        found=1
      elif [[ -f "${resolved}.ts" || -f "${resolved}.tsx" || -f "${resolved}.js" || -f "${resolved}.jsx" ]]; then
        found=1
      elif [[ -f "${resolved}/index.ts" || -f "${resolved}/index.tsx" || -f "${resolved}/index.js" || -f "${resolved}/index.jsx" ]]; then
        found=1
      fi

      if [[ $found -eq 0 ]]; then
        echo "DEAD_IMPORT: ${file} imports '${module}' (not found)"
        dead_count=$((dead_count + 1))
      fi
    done < <(grep -E "from ['\"]" "$file" 2>/dev/null)
  done < <(find_src_files)

  if [[ $dead_count -gt 0 ]]; then
    return 1
  fi
  return 0
}

# Check for orphaned modules (not imported by any entry point or their dependencies)
check_orphaned_modules() {
  local orphaned_count=0
  local entry_points=()

  # Get all entry points
  while IFS= read -r entry; do
    entry_points+=("$entry")
  done < <(find_entry_points)

  # If no entry points found, skip orphan check
  if [[ ${#entry_points[@]} -eq 0 ]]; then
    echo "WARNING: No entry points found, skipping orphan check"
    return 0
  fi

  # Check each source file
  while IFS= read -r file; do
    # Skip entry points themselves
    if [[ " ${entry_points[*]} " =~ " ${file} " ]]; then
      continue
    fi

    # Check if file is imported
    if [[ $(is_imported "$file") -eq 0 ]]; then
      echo "ORPHANED: ${file}"
      orphaned_count=$((orphaned_count + 1))
    fi
  done < <(find_src_files)

  if [[ $orphaned_count -gt 0 ]]; then
    return 1
  fi
  return 0
}

# Main
echo "=== WIRING Gate: Entry Reachability ==="
echo ""

ERRORS=0

echo "Checking for dead imports..."
if ! check_dead_imports; then
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "Checking for orphaned modules..."
if ! check_orphaned_modules; then
  ERRORS=$((ERRORS + 1))
fi

echo ""
if [[ $ERRORS -gt 0 ]]; then
  echo "FAIL: Found ${ERRORS} issue(s)"
  exit 1
else
  echo "PASS: All modules are reachable"
  exit 0
fi
