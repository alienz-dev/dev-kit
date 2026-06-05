#!/bin/bash
# ui-visual-check.test.sh — Tests for VISUAL gate
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_SCRIPT="${TEST_DIR}/../ui-visual-check.sh"

# Test helper
run_test() {
  local test_name="$1"
  local test_func="$2"
  
  echo "Running: $test_name"
  if $test_func; then
    echo "  PASS"
    return 0
  else
    echo "  FAIL"
    return 1
  fi
}

# Test: Gate passes for clean CSS
test_clean_css() {
  # Create temp directory with clean CSS
  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"
  
  # Create clean CSS file
  cat > styles.css << 'INNER_EOF'
:root {
  --primary-color: #007bff;
}

.button {
  color: var(--primary-color);
  padding: 8px 16px;
}
INNER_EOF
  
  # Run gate
  if bash "$GATE_SCRIPT" > /dev/null 2>&1; then
    cd - > /dev/null
    rm -rf "$tmp_dir"
    return 0
  else
    cd - > /dev/null
    rm -rf "$tmp_dir"
    return 1
  fi
}

# Test: Gate fails for hardcoded colors
test_hardcoded_colors() {
  # Create temp directory with hardcoded colors
  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"
  
  # Create CSS with hardcoded colors
  cat > styles.css << 'INNER_EOF'
.button {
  color: #ff0000;
  background-color: rgb(0, 0, 255);
}
INNER_EOF
  
  # Run gate (should fail)
  if bash "$GATE_SCRIPT" > /dev/null 2>&1; then
    cd - > /dev/null
    rm -rf "$tmp_dir"
    return 1  # Should have failed
  else
    cd - > /dev/null
    rm -rf "$tmp_dir"
    return 0  # Correctly failed
  fi
}

# Test: Gate fails for missing alt text
test_missing_alt() {
  # Create temp directory with missing alt text
  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"
  
  # Create HTML with missing alt text
  cat > index.html << 'INNER_EOF'
<img src="image.jpg">
INNER_EOF
  
  # Run gate (should fail)
  if bash "$GATE_SCRIPT" > /dev/null 2>&1; then
    cd - > /dev/null
    rm -rf "$tmp_dir"
    return 1  # Should have failed
  else
    cd - > /dev/null
    rm -rf "$tmp_dir"
    return 0  # Correctly failed
  fi
}

# Run tests
run_test "Clean CSS" test_clean_css
run_test "Hardcoded colors" test_hardcoded_colors
run_test "Missing alt text" test_missing_alt
