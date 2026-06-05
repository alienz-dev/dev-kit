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

# --- Defaults ---
FILES=""
STRICT_MODE=0

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --files)
      if [[ $# -lt 2 || "$2" == --* ]]; then echo "ERROR: --files requires a value"; exit 2; fi
      FILES="$2"
      shift 2
      ;;
    --strict)
      STRICT_MODE=1
      shift
      ;;
    -h|--help)
      echo "Usage: ui-visual-check.sh [--files <file-list>] [--strict]"
      echo ""
      echo "Layer 1 static analysis — checks for CSS regressions, token drift,"
      echo "accessibility issues, and design system violations."
      echo ""
      echo "Options:"
      echo "  --files <list>  Newline-separated file list (default: scan CWD)"
      echo "  --strict        Promote warnings to errors (exit 1)"
      echo ""
      echo "Checks:"
      echo "  ERROR:   Hardcoded colors, missing alt text, !important, z-index wars"
      echo "  WARNING: Hardcoded breakpoints, design token drift, missing ARIA"
      exit 0
      ;;
    *)
      echo "Unknown flag: $1"
      exit 2
      ;;
  esac
done

# --- Find UI files (pre-computed) ---
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

# --- Check: hardcoded colors ---
check_hardcoded_colors() {
  local issues=()
  local file_list="$UI_FILE_LIST"

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    # Filter out CSS variable definitions (--var-name: #color) and var() usage
    if grep -nE "color:\s*#[0-9a-fA-F]{3,8}" "$file" 2>/dev/null | grep -v "var(--" | grep -v "^\s*[0-9]*:\s*--"; then
      issues+=("$file:hardcoded hex color")
    fi
    if grep -nE "color:\s*rgb\(" "$file" 2>/dev/null | grep -v "var(--" | grep -v "^\s*[0-9]*:\s*--"; then
      issues+=("$file:hardcoded rgb color")
    fi
    if grep -nE "color:\s*hsl\(" "$file" 2>/dev/null | grep -v "var(--" | grep -v "^\s*[0-9]*:\s*--"; then
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

# --- Check: missing alt text ---
# Note: grep-based, so multiline <img> tags may not be caught.
# For full coverage, use a proper HTML parser or axe-core (Layer 3).
check_missing_alt() {
  local issues=()
  local file_list="$UI_FILE_LIST"

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if grep -nE "<img[^>]*>" "$file" 2>/dev/null | grep -v "alt="; then
      issues+=("$file:missing alt text on img")
    fi
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

# --- Check: !important usage ---
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

# --- Check: z-index wars ---
check_zindex() {
  local issues=()
  local file_list="$UI_FILE_LIST"

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    # Flag z-index values > 100 (likely a z-index war)
    # Filter out CSS variable definitions
    local zindex_lines
    zindex_lines=$(grep -nE "z-index:\s*[0-9]+" "$file" 2>/dev/null | grep -v "var(--" | grep -v "^\s*[0-9]*:\s*--" || true)
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      # Extract the numeric z-index value (use space instead of \s for macOS sed)
      local val
      val=$(echo "$line" | sed 's/.*z-index: *//' | sed 's/[^0-9].*//')
      if [[ -n "$val" && "$val" -gt 100 ]]; then
        echo "$line"
        issues+=("$file:z-index $val > 100 (z-index war)")
      fi
    done <<< "$zindex_lines"
  done <<< "$file_list"

  if [[ ${#issues[@]} -gt 0 ]]; then
    for issue in "${issues[@]}"; do
      echo "ZINDEX_WAR: $issue"
    done
    return 1
  fi
  return 0
}

# --- Check: responsive breakpoints (warning — breakpoints are legitimately hardcoded) ---
check_responsive_breakpoints() {
  local issues=()
  local file_list="$UI_FILE_LIST"

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    # Note: CSS custom properties don't work in @media queries.
    # Breakpoints are legitimately hardcoded — this is a style warning, not an error.
    # Consider using a CSS preprocessor (Sass/Less) for breakpoint variables.
    if grep -nE "@media.*width:\s*[0-9]+px" "$file" 2>/dev/null | grep -v "var(--" | grep -v "^\s*[0-9]*:\s*--"; then
      issues+=("$file:hardcoded breakpoint (consider CSS preprocessor variables)")
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

# --- Check: design token drift ---
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
    echo "  Create docs/DESIGN.md with your design tokens to enable this check."
    return 0
  fi

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    # Check for hardcoded spacing values (not in variable definitions)
    if grep -nE "(margin|padding|gap):\s*[0-9]+px" "$file" 2>/dev/null | grep -v "var(--" | grep -v "^\s*[0-9]*:\s*--"; then
      issues+=("$file:hardcoded spacing value")
    fi
    # Check for hardcoded font sizes (not in variable definitions)
    if grep -nE "font-size:\s*[0-9]+px" "$file" 2>/dev/null | grep -v "var(--" | grep -v "^\s*[0-9]*:\s*--"; then
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

# --- Check: missing ARIA on interactive elements ---
check_aria() {
  local issues=()
  local file_list="$UI_FILE_LIST"

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    # Check for empty links (no text, no aria-label)
    if grep -nE "<a[^>]*>\s*</a>" "$file" 2>/dev/null | grep -v "aria-label" | grep -v "aria-labelledby"; then
      issues+=("$file:empty link (no accessible name)")
    fi
    # Check for buttons without text content (single-line only — multiline needs a parser)
    if grep -nE "<button[^>]*>\s*</button>" "$file" 2>/dev/null | grep -v "aria-label"; then
      issues+=("$file:empty button (no accessible name)")
    fi
  done <<< "$file_list"

  if [[ ${#issues[@]} -gt 0 ]]; then
    for issue in "${issues[@]}"; do
      echo "MISSING_ARIA: $issue"
    done
    return 1
  fi
  return 0
}

# ═══════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════
echo "=== VISUAL Gate: UI Quality Check ==="
if [[ $STRICT_MODE -eq 1 ]]; then
  echo "  Mode: strict (warnings promoted to errors)"
fi
echo ""

ERRORS=0
WARNINGS=0

# --- Error checks (always block) ---

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
echo "Checking for z-index wars..."
if ! check_zindex; then
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "Checking for missing ARIA..."
if ! check_aria; then
  ERRORS=$((ERRORS + 1))
fi

# --- Warning checks (block only in --strict mode) ---

echo ""
echo "Checking for responsive breakpoints..."
if ! check_responsive_breakpoints; then
  if [[ $STRICT_MODE -eq 1 ]]; then
    ERRORS=$((ERRORS + 1))
  else
    WARNINGS=$((WARNINGS + 1))
  fi
fi

echo ""
echo "Checking for design token usage..."
if ! check_design_tokens; then
  if [[ $STRICT_MODE -eq 1 ]]; then
    ERRORS=$((ERRORS + 1))
  else
    WARNINGS=$((WARNINGS + 1))
  fi
fi

# --- Summary ---
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
