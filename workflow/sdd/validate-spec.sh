#!/bin/bash
# validate-spec.sh — Validate spec completeness before implementation
# Enhanced version: structural + EARS + banned words + placeholders
set -euo pipefail

# Usage: validate-spec.sh <spec-file>
# Exit 0: spec is valid (or warnings only)
# Exit 1: spec has errors

SPEC_FILE="${1:?Usage: validate-spec.sh <spec-file>}"

if [[ ! -f "$SPEC_FILE" ]]; then
  echo "ERROR: Spec file not found: $SPEC_FILE"
  exit 1
fi

ERRORS=0
WARNINGS=0

echo "=== Validating Spec: $SPEC_FILE ==="
echo ""

# ──────────────────────────────────────────────
# Frontmatter Checks
# ──────────────────────────────────────────────
echo "Checking frontmatter..."

if ! grep -q "^---" "$SPEC_FILE"; then
  echo "ERROR: Missing frontmatter (---)"
  ERRORS=$((ERRORS + 1))
fi

if ! grep -q "^id:" "$SPEC_FILE"; then
  echo "ERROR: Missing id field in frontmatter"
  ERRORS=$((ERRORS + 1))
fi

if ! grep -q "^title:" "$SPEC_FILE"; then
  echo "ERROR: Missing title field in frontmatter"
  ERRORS=$((ERRORS + 1))
fi

if ! grep -q "^status:" "$SPEC_FILE"; then
  echo "ERROR: Missing status field in frontmatter"
  ERRORS=$((ERRORS + 1))
else
  # Validate status value
  STATUS_VAL="$(grep "^status:" "$SPEC_FILE" | head -1 | sed 's/^status:[[:space:]]*//' | tr -d '[:space:]')"
  case "$STATUS_VAL" in
    draft|approved|implementing|verified|shipped) ;;
    *)
      echo "ERROR: Invalid status value '$STATUS_VAL' (must be: draft, approved, implementing, verified, shipped)"
      ERRORS=$((ERRORS + 1))
      ;;
  esac

  # Check approved_by when status is 'approved'
  if [ "$STATUS_VAL" = "approved" ]; then
    if grep -qE "^approved_by:.+[[:alnum:]]" "$SPEC_FILE"; then
      echo "  Approved by: $(grep '^approved_by:' "$SPEC_FILE" | head -1 | sed 's/^approved_by:[[:space:]]*//')"
    else
      echo "WARNING: Status is 'approved' but no approved_by field found"
      WARNINGS=$((WARNINGS + 1))
    fi
  fi
fi

# Check test-files field (accept both hyphen and underscore)
if grep -q "^test-files:" "$SPEC_FILE" || grep -q "^test_files:" "$SPEC_FILE"; then
  if grep -q "^test_files:" "$SPEC_FILE"; then
    echo "WARNING: Using 'test_files:' (underscore) — canonical is 'test-files:' (hyphen)"
    WARNINGS=$((WARNINGS + 1))
  fi
else
  echo "WARNING: No test-files field in frontmatter"
  WARNINGS=$((WARNINGS + 1))
fi

# Check linked_issues field
if ! grep -q "^linked_issues:" "$SPEC_FILE"; then
  echo "WARNING: No linked_issues field in frontmatter"
  WARNINGS=$((WARNINGS + 1))
fi

# ──────────────────────────────────────────────
# Section Checks
# ──────────────────────────────────────────────
echo ""
echo "Checking required sections..."

# Accept both numbered (## 1 Overview) and unnumbered (## Overview)
if ! grep -qE "^## .*Overview" "$SPEC_FILE"; then
  echo "ERROR: Missing Overview section"
  ERRORS=$((ERRORS + 1))
fi

if ! grep -qE "^## .*Behavior" "$SPEC_FILE"; then
  echo "ERROR: Missing Behavior section"
  ERRORS=$((ERRORS + 1))
fi

# Warn on missing optional but recommended sections
if ! grep -qE "^## .*Error Handling" "$SPEC_FILE"; then
  echo "WARNING: Missing Error Handling section (recommended)"
  WARNINGS=$((WARNINGS + 1))
fi

if ! grep -qE "^## .*Constraints" "$SPEC_FILE"; then
  echo "WARNING: Missing Constraints section (recommended)"
  WARNINGS=$((WARNINGS + 1))
fi

if ! grep -qE "^## .*Debugging" "$SPEC_FILE" && ! grep -qE "^## §8" "$SPEC_FILE"; then
  echo "WARNING: Missing Debugging & Observability section (§8) — features without debugging AC create unmaintainable code"
  WARNINGS=$((WARNINGS + 1))
fi

# Check section numbering consistency
if grep -qE "^## [A-Z]" "$SPEC_FILE" && ! grep -qE "^## §[0-9]" "$SPEC_FILE"; then
  echo "WARNING: Sections use unnumbered format — canonical is '## N SectionName'"
  WARNINGS=$((WARNINGS + 1))
fi

# ──────────────────────────────────────────────
# EARS Acceptance Criteria Checks
# ──────────────────────────────────────────────
echo ""
echo "Checking acceptance criteria..."

if ! grep -q "THE system SHALL" "$SPEC_FILE"; then
  echo "WARNING: No EARS acceptance criteria found (THE system SHALL)"
  WARNINGS=$((WARNINGS + 1))
else
  # Count EARS criteria
  EARS_COUNT="$(grep -c "THE system SHALL" "$SPEC_FILE" || true)"
  echo "  Found $EARS_COUNT EARS criteria"

  # Check for valid EARS prefixes
  # Valid: THE system SHALL (ubiquitous), WHEN ... THE system SHALL, WHILE ... THE system SHALL,
  #        IF ... THEN THE system SHALL, WHERE ... THE system SHALL
  CRITERIA_LINES="$(grep -n "THE system SHALL" "$SPEC_FILE" || true)"
  INVALID_EARS=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    LINENUM="${line%%:*}"
    CONTENT="${line#*:}"

    # Strip markdown formatting (bullets, bold, etc.)
    CLEAN="$(echo "$CONTENT" | sed 's/^[-*[:space:]]*//' | sed 's/\*\*//g')"

    # Check if it starts with a valid EARS prefix
    if echo "$CLEAN" | grep -qE "^(THE|WHEN|WHILE|IF|WHERE)"; then
      : # valid
    else
      echo "WARNING: Line $LINENUM — criterion does not start with valid EARS prefix (THE/WHEN/WHILE/IF/WHERE)"
      echo "  $CONTENT"
      INVALID_EARS=$((INVALID_EARS + 1))
    fi
  done <<< "$CRITERIA_LINES"

  if [[ $INVALID_EARS -gt 0 ]]; then
    echo "  $INVALID_EARS criteria with non-standard EARS prefix"
    WARNINGS=$((WARNINGS + INVALID_EARS))
  fi
fi

# ──────────────────────────────────────────────
# Banned Words Check (acceptance criteria only)
# ──────────────────────────────────────────────
echo ""
echo "Checking for banned words in acceptance criteria..."

BANNED_WORDS=("should" "appropriately" "properly" "correctly")
BANNED_HITS=0

for word in "${BANNED_WORDS[@]}"; do
  # Search in acceptance criteria section only (after Behavior heading, before next ## heading)
  # Simple heuristic: grep for the word and filter out Clarifications section
  HITS="$(grep -n -i "\b${word}\b" "$SPEC_FILE" 2>/dev/null || true)"
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    LINENUM="${hit%%:*}"

    # Check if this line is in the Clarifications section (acceptable there)
    # Look backward for the nearest ## heading
    NEAREST_HEADING="$(head -n "$LINENUM" "$SPEC_FILE" | grep -E "^##" | tail -1 || true)"
    if echo "$NEAREST_HEADING" | grep -qi "clarification"; then
      continue  # allowed in Clarifications
    fi

    # Check if it's in an acceptance criteria context (has SHALL nearby)
    if head -n "$LINENUM" "$SPEC_FILE" | tail -5 | grep -q "THE system SHALL"; then
      echo "WARNING: Line $LINENUM — banned word '$word' near acceptance criterion"
      echo "  ${hit#*:}"
      BANNED_HITS=$((BANNED_HITS + 1))
    fi
  done <<< "$HITS"
done

if [[ $BANNED_HITS -gt 0 ]]; then
  echo "  $BANNED_HITS banned word occurrences found"
  WARNINGS=$((WARNINGS + BANNED_HITS))
else
  echo "  No banned words found in acceptance criteria"
fi

# ──────────────────────────────────────────────
# Placeholder Detection
# ──────────────────────────────────────────────
echo ""
echo "Checking for placeholders..."

PLACEHOLDER_PATTERNS=("TBD" "TODO" "FIXME" "add appropriate" "add proper" "insert here")
PLACEHOLDER_HITS=0

for pattern in "${PLACEHOLDER_PATTERNS[@]}"; do
  HITS="$(grep -n -i "$pattern" "$SPEC_FILE" 2>/dev/null || true)"
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    echo "WARNING: Line ${hit%%:*} — placeholder found: '$pattern'"
    echo "  ${hit#*:}"
    PLACEHOLDER_HITS=$((PLACEHOLDER_HITS + 1))
  done <<< "$HITS"
done

if [[ $PLACEHOLDER_HITS -gt 0 ]]; then
  echo "  $PLACEHOLDER_HITS placeholder occurrences found"
  WARNINGS=$((WARNINGS + PLACEHOLDER_HITS))
else
  echo "  No placeholders found"
fi

# ──────────────────────────────────────────────
# Non-Goals Check
# ──────────────────────────────────────────────
echo ""
echo "Checking for Non-Goals..."

# Check for explicit Non-Goals section, Scope Boundary with NOT bullets, or Out of Scope
if grep -qi "non-goal" "$SPEC_FILE" || grep -qi "out of scope" "$SPEC_FILE"; then
  echo "  Non-Goals section found"
elif grep -q "Scope Boundary" "$SPEC_FILE"; then
  # Check if Scope Boundary has NOT bullets (common pattern)
  SCOPE_START="$(grep -n "Scope Boundary" "$SPEC_FILE" | head -1 | cut -d: -f1)"
  SCOPE_END="$(tail -n +"$((SCOPE_START + 1))" "$SPEC_FILE" | grep -n "^##" | head -1 | cut -d: -f1 || echo "999")"
  SCOPE_END=$((SCOPE_START + SCOPE_END - 1))
  NOT_COUNT="$(sed -n "${SCOPE_START},${SCOPE_END}p" "$SPEC_FILE" | grep -ciE "NOT |not changing|not implement" || true)"
  if [[ $NOT_COUNT -gt 0 ]]; then
    echo "  Non-Goals found in Scope Boundary ($NOT_COUNT NOT-bullets)"
  else
    echo "WARNING: Scope Boundary exists but has no NOT-bullets (non-goals)"
    WARNINGS=$((WARNINGS + 1))
  fi
else
  echo "WARNING: No Non-Goals or Scope Boundary found (planner-core quality gate requires 2-5 non-goals)"
  WARNINGS=$((WARNINGS + 1))
fi

# ──────────────────────────────────────────────
# Error Handling Table Check
# ──────────────────────────────────────────────
echo ""
echo "Checking for error handling table..."

if grep -qE "^## .*Error Handling" "$SPEC_FILE"; then
  # Check if there's a table (line starting with |)
  EH_START="$(grep -n "^## .*Error Handling" "$SPEC_FILE" | head -1 | cut -d: -f1)"
  # Find next ## heading
  EH_END="$(tail -n +"$((EH_START + 1))" "$SPEC_FILE" | grep -n "^##" | head -1 | cut -d: -f1 || echo "999")"
  EH_END=$((EH_START + EH_END - 1))

  if sed -n "${EH_START},${EH_END}p" "$SPEC_FILE" | grep -q "^|"; then
    echo "  Error handling table found"
  else
    echo "WARNING: Error Handling section exists but has no table"
    WARNINGS=$((WARNINGS + 1))
  fi
else
  echo "  No Error Handling section (already warned above)"
fi

# ──────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────
echo ""
if [[ $ERRORS -gt 0 ]]; then
  echo "FAIL: Found ${ERRORS} error(s) and ${WARNINGS} warning(s)"
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  echo "WARN: Found ${WARNINGS} warning(s)"
  exit 0
else
  echo "PASS: Spec is valid"
  exit 0
fi
