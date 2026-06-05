#!/usr/bin/env bash
# ui-visual-check.sh — VISUAL gate Layer 1: Static analysis for CSS regressions, token drift
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Detect project root: walk up until we find package.json or .git
_find_project_root() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/package.json" || -d "$dir/.git" ]]; then
      echo "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done
  echo "$1" # fallback: use script dir
}
PROJECT_ROOT="$(_find_project_root "$SCRIPT_DIR")"

# Usage: ui-visual-check.sh [--files <glob>]
# Exit 0: visual checks pass
# Exit 1: visual issues found

FILES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --files)
      if [[ $# -lt 2 || "$2" == --* ]]; then echo "ERROR: --files requires a value"; exit 2; fi
      FILES="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: ui-visual-check.sh [--files <glob>]"
      echo ""
      echo "Layer 1 static analysis — checks for hardcoded colors, missing alt text,"
      echo "hardcoded breakpoints, and design token drift."
      echo ""
      echo "Options:"
      echo "  --files <glob>  Specific files to check (default: all UI files)"
      exit 0
      ;;
    *)
      echo "Unknown flag: $1"
      exit 2
      ;;
  esac
done

# Find UI files — pre-computed once in main, passed to each check
UI_FILE_LIST=""
if [[ -n "$FILES" ]]; then
  UI_FILE_LIST="$FILES"
else
  UI_FILE_LIST=$(find . -type f \( -name "*.tsx" -o -name "*.jsx" -o -name "*.vue" -o -name "*.svelte" -o -name "*.css" -o -name "*.scss" -o -name "*.html" -o -name "*.ejs" -o -name "*.hbs" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/dist/*" \
    -not -path "*/.git/*" \
    -not -path "*/tests/*" \
    -not -path "*/__tests__/*" \
    -not -path "*/coverage/*" \
    -not -path "*/.next/*" \
    -not -path "*/build/*")
fi

# Check for hardcoded colors
check_hardcoded_colors() {
  local issues=()
  local file_list="$UI_FILE_LIST"

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    # Check for hardcoded hex colors (not in CSS variables or design tokens)
    if grep -nE "color:\s*#[0-9a-fA-F]{3,8}" "$file" 2>/dev/null | grep -v "var(--" | grep -v "\-\-[a-z]"; then
      issues+=("$file:hardcoded hex color")
    fi
    # Check for hardcoded RGB colors
    if grep -nE "color:\s*rgb\(" "$file" 2>/dev/null | grep -v "var(--" | grep -v "\-\-[a-z]"; then
      issues+=("$file:hardcoded rgb color")
    fi
    # Check for hardcoded HSL colors
    if grep -nE "color:\s*hsl\(" "$file" 2>/dev/null | grep -v "var(--" | grep -v "\-\-[a-z]"; then
      issues+=("$file:hardcoded hsl color")
    fi
  done <<< "$file_list"

  if [[ ${#issues[@]} -gt 0 ]]; then
    for issue in "${issues[@]}"; do
      echo "HARDCODED_COLOR: $issue"
    done
    return 1
  fi
  return 0
}

# Check for missing alt text on images
check_missing_alt() {
  local issues=()
  local file_list="$UI_FILE_LIST"

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    # Check for img tags without alt attribute
    if grep -nE "<img[^>]*>" "$file" 2>/dev/null | grep -v "alt="; then
      issues+=("$file:missing alt text on img")
    fi
    # Check for Image components without alt prop
    if grep -nE "<Image[^>]*>" "$file" 2>/dev/null | grep -v "alt="; then
      issues+=("$file:missing alt prop on Image component")
    fi
  done <<< "$file_list"

  if [[ ${#issues[@]} -gt 0 ]]; then
    for issue in "${issues[@]}"; do
      echo "MISSING_ALT: $issue"
    done
    return 1
  fi
  return 0
}

# Check for !important usage
check_important() {
  local issues=()
  local file_list="$UI_FILE_LIST"

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if grep -nE "!important" "$file" 2>/dev/null; then
      issues+=("$file:!important usage")
    fi
  done <<< "$file_list"

  if [[ ${#issues[@]} -gt 0 ]]; then
    for issue in "${issues[@]}"; do
      echo "IMPORTANT: $issue"
    done
    return 1
  fi
  return 0
}

# Check for responsive breakpoints
check_responsive_breakpoints() {
  local issues=()
  local file_list="$UI_FILE_LIST"

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    # Check for hardcoded pixel widths in media queries
    if grep -nE "@media.*width:\s*[0-9]+px" "$file" 2>/dev/null | grep -v "var(--" | grep -v "\-\-[a-z]"; then
      issues+=("$file:hardcoded breakpoint")
    fi
  done <<< "$file_list"

  if [[ ${#issues[@]} -gt 0 ]]; then
    for issue in "${issues[@]}"; do
      echo "HARDCODED_BREAKPOINT: $issue"
    done
    return 1
  fi
  return 0
}

# Check for design token usage
check_design_tokens() {
  local issues=()
  local file_list="$UI_FILE_LIST"

  # Check if DESIGN.md exists (try project root, then docs/)
  local design_file=""
  if [[ -f "$PROJECT_ROOT/DESIGN.md" ]]; then
    design_file="$PROJECT_ROOT/DESIGN.md"
  elif [[ -f "$PROJECT_ROOT/docs/DESIGN.md" ]]; then
    design_file="$PROJECT_ROOT/docs/DESIGN.md"
  else
    echo "WARNING: DESIGN.md not found, skipping design token check"
    return 0
  fi

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    # Check for hardcoded spacing values
    if grep -nE "(margin|padding|gap):\s*[0-9]+px" "$file" 2>/dev/null | grep -v "var(--" | grep -v "\-\-[a-z]"; then
      issues+=("$file:hardcoded spacing value")
    fi
    # Check for hardcoded font sizes
    if grep -nE "font-size:\s*[0-9]+px" "$file" 2>/dev/null | grep -v "var(--" | grep -v "\-\-[a-z]"; then
      issues+=("$file:hardcoded font size")
    fi
  done <<< "$file_list"

  if [[ ${#issues[@]} -gt 0 ]]; then
    for issue in "${issues[@]}"; do
      echo "HARDCODED_TOKEN: $issue"
    done
    return 1
  fi
  return 0
}

# Main
echo "=== VISUAL Gate: UI Quality Check ==="
echo ""

ERRORS=0
WARNINGS=0

echo "Checking for hardcoded colors..."
if ! check_hardcoded_colors; then
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "Checking for missing alt text..."
if ! check_missing_alt; then
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "Checking for !important usage..."
if ! check_important; then
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "Checking for responsive breakpoints..."
if ! check_responsive_breakpoints; then
  WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "Checking for design token usage..."
if ! check_design_tokens; then
  WARNINGS=$((WARNINGS + 1))
fi

echo ""
if [[ $ERRORS -gt 0 ]]; then
  echo "FAIL: Found ${ERRORS} error(s) and ${WARNINGS} warning(s)"
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  echo "WARN: Found ${WARNINGS} warning(s)"
  exit 0
else
  echo "PASS: All visual checks passed"
  exit 0
fi
