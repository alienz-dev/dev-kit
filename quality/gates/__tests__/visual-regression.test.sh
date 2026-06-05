#!/usr/bin/env bash
# visual-regression.test.sh — Tests for Layer 2 visual regression gate
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_SCRIPT="${TEST_DIR}/../visual-regression.sh"

PASS_COUNT=0
FAIL_COUNT=0

# Test helper
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
  local output
  output=$(bash "$GATE_SCRIPT" 2>&1) && {
    echo "  Expected exit 2, got 0"
    return 1
  }
  local exit_code=$?
  if [[ $exit_code -eq 2 ]]; then
    return 0
  else
    echo "  Expected exit 2, got $exit_code"
    return 1
  fi
}

# Test: unknown flag exits 2 (use --bogus alone to hit flag parser before dependency check)
test_unknown_flag() {
  local output
  output=$(bash "$GATE_SCRIPT" --bogus 2>&1) && {
    echo "  Expected exit 2, got 0"
    return 1
  }
  local exit_code=$?
  if [[ $exit_code -eq 2 ]]; then
    return 0
  else
    echo "  Expected exit 2, got $exit_code"
    return 1
  fi
}

# Test: Script is executable
test_is_executable() {
  if [[ -x "$GATE_SCRIPT" ]]; then
    return 0
  else
    echo "  Script is not executable"
    return 1
  fi
}

# Test: Script has proper shebang
test_has_shebang() {
  local first_line
  first_line=$(head -1 "$GATE_SCRIPT")
  if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
    return 0
  else
    echo "  Expected #!/usr/bin/env bash, got: $first_line"
    return 1
  fi
}

# Test: Script uses set -euo pipefail
test_strict_mode() {
  if grep -q 'set -euo pipefail' "$GATE_SCRIPT"; then
    return 0
  else
    echo "  Missing set -euo pipefail"
    return 1
  fi
}

# Test: Script supports all documented flags
test_documented_flags() {
  local flags=("--gate" "--update-baselines" "--url" "--baseline" "--threshold" "--design" "--vision-endpoint" "--project" "--report-dir" "--result-dir")
  local missing=()

  for flag in "${flags[@]}"; do
    if ! grep -q -- "$flag" "$GATE_SCRIPT"; then
      missing+=("$flag")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    return 0
  else
    echo "  Missing flags: ${missing[*]}"
    return 1
  fi
}

# Test: Gate mode flag is parsed
test_gate_mode_parsed() {
  if grep -q 'GATE_MODE=1' "$GATE_SCRIPT" && grep -q '\-\-gate' "$GATE_SCRIPT"; then
    return 0
  else
    echo "  Gate mode not properly implemented"
    return 1
  fi
}

# Run tests
echo "=== Visual Regression Gate Tests ==="
echo ""
run_test "Missing --url exits 2" test_missing_url
run_test "Unknown flag exits 2" test_unknown_flag
run_test "Script is executable" test_is_executable
run_test "Script has shebang" test_has_shebang
run_test "Script uses strict mode" test_strict_mode
run_test "All documented flags present" test_documented_flags
run_test "Gate mode flag parsed" test_gate_mode_parsed

echo ""
echo "Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
fi
exit 0
