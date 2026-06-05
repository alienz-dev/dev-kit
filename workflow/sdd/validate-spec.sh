#!/bin/bash
# validate-spec.sh — Validate spec completeness before implementation
set -euo pipefail

# Usage: validate-spec.sh <spec-file>
# Exit 0: spec is valid
# Exit 1: spec has issues

SPEC_FILE="${1:?Usage: validate-spec.sh <spec-file>}"

if [[ ! -f "$SPEC_FILE" ]]; then
  echo "ERROR: Spec file not found: $SPEC_FILE"
  exit 1
fi

ERRORS=0
WARNINGS=0

echo "=== Validating Spec: $SPEC_FILE ==="
echo ""

# Check frontmatter
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
fi

# Check required sections
echo ""
echo "Checking required sections..."

if ! grep -q "^## §1 Overview" "$SPEC_FILE"; then
  echo "ERROR: Missing §1 Overview section"
  ERRORS=$((ERRORS + 1))
fi

if ! grep -q "^## §2 Behavior" "$SPEC_FILE"; then
  echo "ERROR: Missing §2 Behavior section"
  ERRORS=$((ERRORS + 1))
fi

# Check for EARS acceptance criteria
echo ""
echo "Checking acceptance criteria..."
if ! grep -q "THE system SHALL" "$SPEC_FILE"; then
  echo "WARNING: No EARS acceptance criteria found (THE system SHALL)"
  WARNINGS=$((WARNINGS + 1))
fi

# Check for test files reference
echo ""
echo "Checking test files..."
if ! grep -q "test-files:" "$SPEC_FILE"; then
  echo "WARNING: No test-files field in frontmatter"
  WARNINGS=$((WARNINGS + 1))
fi

# Check for linked issues
echo ""
echo "Checking linked issues..."
if ! grep -q "linked_issues:" "$SPEC_FILE"; then
  echo "WARNING: No linked_issues field in frontmatter"
  WARNINGS=$((WARNINGS + 1))
fi

# Summary
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
