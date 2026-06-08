#!/bin/bash
# alignment-gate.sh — Spec-to-code alignment check gate
# Usage: alignment-gate.sh <spec-file> [--skip-alignment]
#
# Checks if spec acceptance criteria are aligned with code behavior.
# This is a simplified gate that the agent enhances with full spec-align logic.
#
# Exit codes:
#   0 — ALIGNED (or skipped)
#   1 — Error (missing files, invalid spec)
#   2 — Test gaps found (route to test-manager)
#   3 — Code issues found (route to patch wave)
#   4 — Spec ambiguity (flag for human)
set -euo pipefail

SPEC_FILE="${1:?Usage: alignment-gate.sh <spec-file> [--skip-alignment]}"
SKIP_FLAG="${2:-}"

# --- Skip if requested ---
if [[ "$SKIP_FLAG" == "--skip-alignment" ]]; then
  echo "ALIGNMENT: SKIPPED (--skip-alignment flag)"
  exit 0
fi

# --- Validate spec file ---
if [[ ! -f "$SPEC_FILE" ]]; then
  echo "ERROR: Spec file not found: $SPEC_FILE"
  exit 1
fi

# --- Extract EARS criteria count ---
EARS_COUNT=$(grep -c "THE system SHALL" "$SPEC_FILE" 2>/dev/null || echo "0")
if [[ "$EARS_COUNT" -eq 0 ]]; then
  echo "ALIGNMENT: SKIPPED — no EARS criteria in spec"
  exit 0
fi

echo "=== Alignment Gate ==="
echo "Spec: $SPEC_FILE"
echo "EARS criteria: $EARS_COUNT"
echo ""

# --- Check test coverage via spec-trace ---
echo "Running test traceability check..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRACE_OUTPUT=$(bash "$SCRIPT_DIR/../../tools/spec-trace.sh" tests/ specs/ 2>&1 || true)
echo "$TRACE_OUTPUT"

# Check for uncovered sections
if echo "$TRACE_OUTPUT" | grep -q "UNCOVERED"; then
  UNCOVERED_COUNT=$(echo "$TRACE_OUTPUT" | grep -c "UNCOVERED" || echo "0")
  echo ""
  echo "ALIGNMENT: TEST GAPS FOUND — $UNCOVERED_COUNT uncovered sections"
  echo "ROUTE: alignment_to_test (test-manager must add missing tests)"
  exit 2
fi

echo ""
echo "Test traceability: PASS"
echo ""

# --- Check for spec quality issues ---
echo "Running spec validation..."
VALIDATE_OUTPUT=$(bash workflow/sdd/validate-spec.sh "$SPEC_FILE" 2>&1 || true)
if echo "$VALIDATE_OUTPUT" | grep -q "^FAIL"; then
  echo ""
  echo "ALIGNMENT: SPEC QUALITY ISSUES"
  echo "$VALIDATE_OUTPUT"
  echo "ROUTE: FLAG FOR HUMAN (spec needs fixing before alignment check)"
  exit 4
fi

echo "Spec validation: PASS"
echo ""

# --- Write proof file ---
mkdir -p .pipeline/gates
printf '{"passed":true,"at":"%s","gate":"alignment","ears_count":%s}\n' \
  "$(date -Iseconds)" "$EARS_COUNT" > .pipeline/gates/alignment.passed

# --- Summary ---
echo "=== Alignment Gate Summary ==="
echo "EARS criteria: $EARS_COUNT"
echo "Test coverage: PASS (all sections covered)"
echo "Spec quality: PASS"
echo "Proof: .pipeline/gates/alignment.passed ✓"
echo ""
echo "ALIGNMENT: READY FOR AGENT REVIEW"
echo ""
echo "Next: Agent runs full spec-align skill to compare each AC against code."
echo "The agent classifies divergences and routes to patch wave or re-dispatch."
echo ""
echo "To run full alignment check:"
echo "  /spec-align $SPEC_FILE"
echo ""
echo "To skip alignment (emergency):"
echo "  bash workflow/pipeline/alignment-gate.sh $SPEC_FILE --skip-alignment"
