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

# --- Functional tests ---

test_clean_css() {
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local orig_dir
  orig_dir=$(pwd)
  cd "$tmp_dir"

  cat > styles.css << 'EOF'
:root {
  --primary-color: #007bff;
  --spacing-md: 16px;
}
.button {
  color: var(--primary-color);
  padding: var(--spacing-md);
  z-index: 10;
}
EOF

  if bash "$GATE_SCRIPT" > /dev/null 2>&1; then
    cd "$orig_dir"; rm -rf "$tmp_dir"; return 0
  else
    cd "$orig_dir"; rm -rf "$tmp_dir"; return 1
  fi
}

test_hardcoded_colors() {
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local orig_dir
  orig_dir=$(pwd)
  cd "$tmp_dir"

  cat > styles.css << 'EOF'
.button { color: #ff0000; background-color: rgb(0, 0, 255); }
EOF

  if bash "$GATE_SCRIPT" > /dev/null 2>&1; then
    cd "$orig_dir"; rm -rf "$tmp_dir"; return 1
  else
    cd "$orig_dir"; rm -rf "$tmp_dir"; return 0
  fi
}

test_missing_alt() {
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local orig_dir
  orig_dir=$(pwd)
  cd "$tmp_dir"

  cat > index.html << 'EOF'
<img src="image.jpg">
EOF

  if bash "$GATE_SCRIPT" > /dev/null 2>&1; then
    cd "$orig_dir"; rm -rf "$tmp_dir"; return 1
  else
    cd "$orig_dir"; rm -rf "$tmp_dir"; return 0
  fi
}

test_important() {
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local orig_dir
  orig_dir=$(pwd)
  cd "$tmp_dir"

  cat > styles.css << 'EOF'
.button { font-size: 12px !important; }
EOF

  if bash "$GATE_SCRIPT" > /dev/null 2>&1; then
    cd "$orig_dir"; rm -rf "$tmp_dir"; return 1
  else
    cd "$orig_dir"; rm -rf "$tmp_dir"; return 0
  fi
}

test_zindex_war() {
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local orig_dir
  orig_dir=$(pwd)
  cd "$tmp_dir"

  cat > styles.css << 'EOF'
.modal { z-index: 9999; }
EOF

  if bash "$GATE_SCRIPT" > /dev/null 2>&1; then
    cd "$orig_dir"; rm -rf "$tmp_dir"; return 1
  else
    cd "$orig_dir"; rm -rf "$tmp_dir"; return 0
  fi
}

test_zindex_ok() {
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local orig_dir
  orig_dir=$(pwd)
  cd "$tmp_dir"

  cat > styles.css << 'EOF'
.modal { z-index: 50; }
.dropdown { z-index: 100; }
EOF

  if bash "$GATE_SCRIPT" > /dev/null 2>&1; then
    cd "$orig_dir"; rm -rf "$tmp_dir"; return 0
  else
    cd "$orig_dir"; rm -rf "$tmp_dir"; return 1
  fi
}

test_empty_link_aria() {
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local orig_dir
  orig_dir=$(pwd)
  cd "$tmp_dir"

  cat > index.html << 'EOF'
<a href="/details"></a>
EOF

  if bash "$GATE_SCRIPT" > /dev/null 2>&1; then
    cd "$orig_dir"; rm -rf "$tmp_dir"; return 1
  else
    cd "$orig_dir"; rm -rf "$tmp_dir"; return 0
  fi
}

test_root_definitions_not_flagged() {
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local orig_dir
  orig_dir=$(pwd)
  cd "$tmp_dir"

  # CSS variable definitions should NOT be flagged as hardcoded
  cat > styles.css << 'EOF'
:root {
  --color-primary: #2563eb;
  --color-bg: #ffffff;
  --color-text: #1f2937;
  --space-md: 16px;
  --font-size: 14px;
}
.button {
  color: var(--color-primary);
  padding: var(--space-md);
}
EOF

  if bash "$GATE_SCRIPT" > /dev/null 2>&1; then
    cd "$orig_dir"; rm -rf "$tmp_dir"; return 0
  else
    cd "$orig_dir"; rm -rf "$tmp_dir"; return 1
  fi
}

test_strict_promotes_warnings() {
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local orig_dir
  orig_dir=$(pwd)
  cd "$tmp_dir"

  # Only has a hardcoded breakpoint (warning normally)
  cat > styles.css << 'EOF'
@media (max-width: 768px) { .card { display: none; } }
EOF

  # Without --strict: should pass (warning only)
  if ! bash "$GATE_SCRIPT" > /dev/null 2>&1; then
    cd "$orig_dir"; rm -rf "$tmp_dir"; return 1  # Should pass without --strict
  fi

  # With --strict: should fail (warning promoted)
  if bash "$GATE_SCRIPT" --strict > /dev/null 2>&1; then
    cd "$orig_dir"; rm -rf "$tmp_dir"; return 1  # Should fail with --strict
  fi

  cd "$orig_dir"; rm -rf "$tmp_dir"; return 0
}

# --- Structural tests ---

test_is_executable() {
  if [[ -x "$GATE_SCRIPT" ]]; then return 0; fi
  echo "  Script is not executable"
  return 1
}

test_has_shebang() {
  local first_line
  first_line=$(head -1 "$GATE_SCRIPT")
  if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then return 0; fi
  echo "  Expected #!/usr/bin/env bash, got: $first_line"
  return 1
}

test_strict_mode() {
  if grep -q 'set -euo pipefail' "$GATE_SCRIPT"; then return 0; fi
  echo "  Missing set -euo pipefail"
  return 1
}

test_unknown_flag() {
  bash "$GATE_SCRIPT" --bogus 2>/dev/null && { echo "  Expected exit 2, got 0"; return 1; }
  local exit_code=$?
  if [[ $exit_code -eq 2 ]]; then return 0; fi
  echo "  Expected exit 2, got $exit_code"
  return 1
}

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
run_test "!important fails" test_important
run_test "z-index > 100 fails" test_zindex_war
run_test "z-index <= 100 passes" test_zindex_ok
run_test "Empty link fails (ARIA)" test_empty_link_aria
run_test ":root definitions not flagged" test_root_definitions_not_flagged
run_test "--strict promotes warnings" test_strict_promotes_warnings
run_test "Script is executable" test_is_executable
run_test "Script has shebang" test_has_shebang
run_test "Script uses strict mode" test_strict_mode
run_test "Unknown flag exits 2" test_unknown_flag
run_test "--help flag works" test_help_flag

echo ""
echo "Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
if [[ $FAIL_COUNT -gt 0 ]]; then exit 1; fi
exit 0
