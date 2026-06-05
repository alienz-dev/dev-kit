#!/bin/bash
# ui-visual-check.sh — VISUAL gate: Check for CSS regressions, token drift, layout breaks
set -euo pipefail

# Usage: ui-visual-check.sh [--fix] [--threshold <0-100>]
# Exit 0: visual checks pass
# Exit 1: visual issues found

FIX_MODE=0
THRESHOLD=80

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fix)
      FIX_MODE=1
      shift
      ;;
    --threshold)
      THRESHOLD="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

# Find UI files
find_ui_files() {
  find . -type f \( -name "*.tsx" -o -name "*.jsx" -o -name "*.vue" -o -name "*.svelte" -o -name "*.css" -o -name "*.scss" -o -name "*.html" -o -name "*.ejs" -o -name "*.hbs" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/dist/*" \
    -not -path "*/.git/*" \
    -not -path "*/tests/*" \
    -not -path "*/__tests__/*" \
    -not -path "*/coverage/*" \
    -not -path "*/.next/*" \
    -not -path "*/build/*"
}

# Check for hardcoded colors
check_hardcoded_colors() {
  local issues=()

  while IFS= read -r file; do
    # Check for hardcoded hex colors (not in CSS variables or design tokens)
    # Exclude lines that define CSS variables (--variable-name: #color)
    if grep -nE "color:\s*#[0-9a-fA-F]{3,8}" "$file" 2>/dev/null | grep -v "var(--" | grep -v "token" | grep -v "theme" | grep -v "\-\-"; then
      issues+=("$file:hardcoded hex color")
    fi

    # Check for hardcoded RGB colors
    if grep -nE "color:\s*rgb\(" "$file" 2>/dev/null | grep -v "var(--" | grep -v "token" | grep -v "theme" | grep -v "\-\-"; then
      issues+=("$file:hardcoded rgb color")
    fi

    # Check for hardcoded HSL colors
    if grep -nE "color:\s*hsl\(" "$file" 2>/dev/null | grep -v "var(--" | grep -v "token" | grep -v "theme" | grep -v "\-\-"; then
      issues+=("$file:hardcoded hsl color")
    fi
  done < <(find_ui_files)

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

  while IFS= read -r file; do
    # Check for img tags without alt attribute
    if grep -nE "<img[^>]*>" "$file" 2>/dev/null | grep -v "alt="; then
      issues+=("$file:missing alt text on img")
    fi

    # Check for Image components without alt prop
    if grep -nE "<Image[^>]*>" "$file" 2>/dev/null | grep -v "alt="; then
      issues+=("$file:missing alt prop on Image component")
    fi
  done < <(find_ui_files)

  if [[ ${#issues[@]} -gt 0 ]]; then
    for issue in "${issues[@]}"; do
      echo "MISSING_ALT: $issue"
    done
    return 1
  fi
  return 0
}

# Check for responsive breakpoints
check_responsive_breakpoints() {
  local issues=()

  while IFS= read -r file; do
    # Check for hardcoded pixel widths in media queries
    if grep -nE "@media.*width:\s*[0-9]+px" "$file" 2>/dev/null | grep -v "var(--" | grep -v "token" | grep -v "theme"; then
      issues+=("$file:hardcoded breakpoint")
    fi
  done < <(find_ui_files)

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

  # Check if DESIGN.md exists
  if [[ ! -f "DESIGN.md" ]]; then
    echo "WARNING: DESIGN.md not found, skipping design token check"
    return 0
  fi

  while IFS= read -r file; do
    # Check for hardcoded spacing values
    if grep -nE "(margin|padding|gap):\s*[0-9]+px" "$file" 2>/dev/null | grep -v "var(--" | grep -v "token" | grep -v "theme"; then
      issues+=("$file:hardcoded spacing value")
    fi

    # Check for hardcoded font sizes
    if grep -nE "font-size:\s*[0-9]+px" "$file" 2>/dev/null | grep -v "var(--" | grep -v "token" | grep -v "theme"; then
      issues+=("$file:hardcoded font size")
    fi
  done < <(find_ui_files)

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
