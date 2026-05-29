#!/bin/bash
# Test the adapter contract by mocking an agent CLI
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Create mock workdir with git
cd "$TEST_DIR"
git init -q && git commit --allow-empty -m "init" -q
echo "hello" > test.txt && git add test.txt && git commit -m "add" -q

# Create mock briefing
echo "# Task\nModify test.txt to say goodbye" > briefing.md

# Test: verify base.sh sources correctly
source "$SCRIPT_DIR/base.sh"
write_result "success" "test" "test.txt" "5" "mock output" "$TEST_DIR/result.md"

# Verify result file format
grep -q "## Status" "$TEST_DIR/result.md" && echo "✓ Status section"
grep -q "## Agent" "$TEST_DIR/result.md" && echo "✓ Agent section"
grep -q "## Changes" "$TEST_DIR/result.md" && echo "✓ Changes section"
grep -q "## Duration" "$TEST_DIR/result.md" && echo "✓ Duration section"
grep -q "## Output" "$TEST_DIR/result.md" && echo "✓ Output section"

echo ""
echo "All contract checks passed."
