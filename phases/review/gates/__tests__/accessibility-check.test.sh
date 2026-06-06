#!/usr/bin/env bash
# accessibility-check.test.sh — Tests for Layer 3 accessibility gate
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_SCRIPT="${TEST_DIR}/../accessibility-check.sh"

PASS_COUNT=0
FAIL_COUNT=0

run_test() {
  local test_name="$1"
  local test_func="$2"

  echo "Running: $test_name"
  if $test_func; then
    echo "  PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# Test: Missing --url exits 2
test_missing_url() {
  bash "$GATE_SCRIPT" 2>&1 && { echo "  Expected exit 2, got 0"; return 1; }
  local exit_code=$?
  if [[ $exit_code -eq 2 ]]; then return 0; fi
  echo "  Expected exit 2, got $exit_code"
  return 1
}

# Test: Unknown flag exits 2
test_unknown_flag() {
  bash "$GATE_SCRIPT" --url http://localhost:3000 --bogus 2>&1 && { echo "  Expected exit 2, got 0"; return 1; }
  local exit_code=$?
  if [[ $exit_code -eq 2 ]]; then return 0; fi
  echo "  Expected exit 2, got $exit_code"
  return 1
}

# Test: Invalid severity exits 2
test_invalid_severity() {
  bash "$GATE_SCRIPT" --url http://localhost:3000 --severity bogus 2>&1 && { echo "  Expected exit 2, got 0"; return 1; }
  local exit_code=$?
  if [[ $exit_code -eq 2 ]]; then return 0; fi
  echo "  Expected exit 2, got $exit_code"
  return 1
}

# Test: Script is executable
test_is_executable() {
  if [[ -x "$GATE_SCRIPT" ]]; then return 0; fi
  echo "  Script is not executable"
  return 1
}

# Test: Script has proper shebang
test_has_shebang() {
  local first_line
  first_line=$(head -1 "$GATE_SCRIPT")
  if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then return 0; fi
  echo "  Expected #!/usr/bin/env bash, got: $first_line"
  return 1
}

# Test: Script uses set -euo pipefail
test_strict_mode() {
  if grep -q 'set -euo pipefail' "$GATE_SCRIPT"; then return 0; fi
  echo "  Missing set -euo pipefail"
  return 1
}

# Test: Script supports all documented flags
test_documented_flags() {
  local flags=("--gate" "--url" "--severity" "--output")
  local missing=()
  for flag in "${flags[@]}"; do
    if ! grep -q -- "$flag" "$GATE_SCRIPT"; then missing+=("$flag"); fi
  done
  if [[ ${#missing[@]} -eq 0 ]]; then return 0; fi
  echo "  Missing flags: ${missing[*]}"
  return 1
}

# Test: Severity levels are defined
test_severity_levels() {
  if grep -q 'critical' "$GATE_SCRIPT" && grep -q 'serious' "$GATE_SCRIPT" && grep -q 'moderate' "$GATE_SCRIPT"; then
    return 0
  fi
  echo "  Missing severity level definitions"
  return 1
}

# Test: axe-core is referenced
test_axe_core_reference() {
  if grep -q 'AxeBuilder' "$GATE_SCRIPT" || grep -q 'axe-core' "$GATE_SCRIPT"; then return 0; fi
  echo "  No axe-core reference found"
  return 1
}

echo "=== Accessibility Gate Tests ==="
echo ""
run_test "Missing --url exits 2" test_missing_url
run_test "Unknown flag exits 2" test_unknown_flag
run_test "Invalid severity exits 2" test_invalid_severity
run_test "Script is executable" test_is_executable
run_test "Script has shebang" test_has_shebang
run_test "Script uses strict mode" test_strict_mode
run_test "All documented flags present" test_documented_flags
run_test "Severity levels defined" test_severity_levels
run_test "axe-core referenced" test_axe_core_reference

echo ""
echo "Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
if [[ $FAIL_COUNT -gt 0 ]]; then exit 1; fi
exit 0
