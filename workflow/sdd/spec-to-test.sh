#!/bin/bash
# spec-to-test.sh — Generate test stubs from spec sections
set -euo pipefail

# Usage: spec-to-test.sh <spec-file> [output-dir]
# Generates test stubs for each acceptance criterion in the spec

SPEC_FILE="${1:?Usage: spec-to-test.sh <spec-file> [output-dir]}"
OUTPUT_DIR="${2:-tests/generated}"

if [[ ! -f "$SPEC_FILE" ]]; then
  echo "ERROR: Spec file not found: $SPEC_FILE"
  exit 1
fi

# Extract spec ID from frontmatter
SPEC_ID=$(grep "^id:" "$SPEC_FILE" | head -1 | sed 's/^id: *//')
if [[ -z "$SPEC_ID" ]]; then
  SPEC_ID="SPEC-UNKNOWN"
fi

# Extract spec title from frontmatter
SPEC_TITLE=$(grep "^title:" "$SPEC_FILE" | head -1 | sed 's/^title: *"//' | sed 's/"$//')
if [[ -z "$SPEC_TITLE" ]]; then
  SPEC_TITLE="Unknown Feature"
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Generate test file
TEST_FILE="$OUTPUT_DIR/${SPEC_ID}.test.ts"

echo "Generating test stubs for: $SPEC_ID - $SPEC_TITLE"
echo "Output: $TEST_FILE"

cat > "$TEST_FILE" << EOF
// @spec $(basename "$SPEC_FILE") §2 Behavior
// Auto-generated test stubs for $SPEC_ID: $SPEC_TITLE
// Generated: $(date +%Y-%m-%d)

import { describe, it, expect } from 'vitest';

describe('$SPEC_TITLE', () => {
EOF

# Extract EARS acceptance criteria
# Pattern: THE system SHALL [behavior]
grep "THE system SHALL" "$SPEC_FILE" | while IFS= read -r line; do
  # Extract the behavior part
  behavior=$(echo "$line" | sed 's/.*THE system SHALL //' | sed 's/^ *//')

  # Create a test name from the behavior
  test_name=$(echo "$behavior" | sed 's/[^a-zA-Z0-9 ]//g' | sed 's/  */ /g' | cut -c1-80)

  cat >> "$TEST_FILE" << EOF

  it('$test_name', () => {
    // TODO: Implement test for: $behavior
    expect(true).toBe(true); // Placeholder
  });
EOF
done

cat >> "$TEST_FILE" << EOF
});
EOF

echo ""
echo "Generated $(grep -c "it('" "$TEST_FILE") test stubs"
echo ""
echo "Next steps:"
echo "1. Review generated test stubs in $TEST_FILE"
echo "2. Replace placeholder assertions with actual test logic"
echo "3. Run: npm test $TEST_FILE"
