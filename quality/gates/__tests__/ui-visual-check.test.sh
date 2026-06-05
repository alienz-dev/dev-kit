#!/usr/bin/env bash
# ui-visual-check.test.sh — Tests for VISUAL gate Layer 1
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_SCRIPT="${TEST_DIR}/../ui-visual-check.sh"

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

# Test: Gate passes for clean CSS
test_clean_css() {
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local orig_dir
  orig_dir=$(pwd)
  cd "$tmp_dir"

  cat > styles.css << 'EOF'
:root {
  --primary-color: #007bff;
}
.button {
  color: var(--primary-color);
  padding: 8px 16px;
}
EOF

  if bash "$GATE_SCRIPT" > /dev/null 2>&1; then
    cd "$orig_dir"
    rm -rf "$tmp_dir"
    return 0
  else
    cd "$orig_dir"
    rm -rf "$tmp_dir"
    return 1
  fi
}

# Test: Gate fails for hardcoded colors
test_hardcoded_colors() {
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local orig_dir
  orig_dir=$(pwd)
  cd "$tmp_dir"

  cat > styles.css << 'EOF'
.button {
  color: #ff0000;
  background-color: rgb(0, 0, 255);
}
EOF

  # Should fail (exit 1)
  if bash "$GATE_SCRIPT" > /dev/null 2>&1; then
    cd "$orig_dir"
    rm -rf "$tmp_dir"
    return 1  # Should have failed
  else
    cd "$orig_dir"
    rm -rf "$tmp_dir"
    return 0  # Correctly failed
  fi
}

# Test: Gate fails for missing alt text
test_missing_alt() {
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local orig_dir
  orig_dir=$(pwd)
  cd "$tmp_dir"

  cat > index.html << 'EOF'
<img src="image.jpg">
EOF

  # Should fail (exit 1)
  if bash "$GATE_SCRIPT" > /dev/null 2>&1; then
    cd "$orig_dir"
    rm -rf "$tmp_dir"
    return 1  # Should have failed
  else
    cd "$orig_dir"
    rm -rf "$tmp_dir"
    return 0  # Correctly failed
  fi
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

# Test: Unknown flag exits 2
test_unknown_flag() {
  bash "$GATE_SCRIPT" --bogus 2>/dev/null && { echo "  Expected exit 2, got 0"; return 1; }
  local exit_code=$?
  if [[ $exit_code -eq 2 ]]; then return 0; fi
  echo "  Expected exit 2, got $exit_code"
  return 1
}

# Test: --help flag works
test_help_flag() {
  local output
  output=$(bash "$GATE_SCRIPT" --help 2>&1)
  if echo "$output" | grep -q "Usage:"; then return 0; fi
  echo "  --help did not produce usage output"
  return 1
}

# Run tests
echo "=== UI Visual Check (Layer 1) Tests ==="
echo ""
run_test "Clean CSS passes" test_clean_css
run_test "Hardcoded colors fail" test_hardcoded_colors
run_test "Missing alt text fails" test_missing_alt
run_test "Script is executable" test_is_executable
run_test "Script has shebang" test_has_shebang
run_test "Script uses strict mode" test_strict_mode
run_test "Unknown flag exits 2" test_unknown_flag
run_test "--help flag works" test_help_flag

echo ""
echo "Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
if [[ $FAIL_COUNT -gt 0 ]]; then exit 1; fi
exit 0
