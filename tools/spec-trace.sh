#!/bin/bash
set -euo pipefail

# spec-trace.sh — Spec-Test Traceability Checker
# Cross-references @spec annotations in test files against spec file sections.
# Outputs a coverage table; exits 1 if any section is uncovered.
#
# Usage: spec-trace.sh [test-dir] [spec-dir]
#   test-dir: directory to scan for test files (default: tests/)
#   spec-dir: directory to scan for spec files (default: specs/)

# --- Help ---
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'EOF'
Usage: spec-trace.sh [test-dir] [spec-dir]

Scans test files for @spec annotations and cross-references them against
spec file sections to report coverage.

Arguments:
  test-dir    Directory to scan for test files (default: tests/)
  spec-dir    Directory to scan for spec files (default: specs/)

@spec annotation format:
  @spec <spec-file.md> §<section-name>

Exit codes:
  0  All spec sections are covered by at least one @spec annotation
  1  One or more spec sections are uncovered (or no test files found)

Examples:
  spec-trace.sh                     # use defaults (tests/, specs/)
  spec-trace.sh tests/ specs/       # explicit directories
  spec-trace.sh test/ docs/specs/   # custom directories
EOF
    exit 0
fi

TEST_DIR="${1:-tests/}"
SPEC_DIR="${2:-specs/}"

# --- Validate spec directory ---
if [[ ! -d "$SPEC_DIR" ]]; then
    echo "no specs found in $SPEC_DIR"
    exit 0
fi

# --- Collect spec files ---
spec_list="$(find "$SPEC_DIR" \( -name "SPEC-*.md" -o -name "spec-*.md" \) 2>/dev/null)"

if [[ -z "$spec_list" ]]; then
    echo "no specs found in $SPEC_DIR"
    exit 0
fi

# --- Validate test directory ---
if [[ ! -d "$TEST_DIR" ]]; then
    echo "no tests found in $TEST_DIR"
    exit 1
fi

# --- Collect test files ---
test_list="$(find "$TEST_DIR" \( -name "*.test.*" -o -name "*.spec.*" \) 2>/dev/null)"

if [[ -z "$test_list" ]]; then
    echo "no tests found in $TEST_DIR"
    exit 1
fi

# --- Extract @spec annotations from all test files into a temp file ---
# Each line: "spec_basename|section"
COVERED_FILE="$(mktemp)"
trap 'rm -f "$COVERED_FILE"' EXIT

while IFS= read -r test_file; do
    grep "@spec" "$test_file" 2>/dev/null || true
done <<< "$test_list" | while IFS= read -r line; do
    # Extract the part after @spec
    spec_ref="${line#*@spec }"
    # Split on § — left side is file, right side is section
    if [[ "$spec_ref" == *"§"* ]]; then
        ref_file="${spec_ref%%§*}"
        ref_section="${spec_ref#*§}"
        # Trim whitespace
        ref_file="$(echo "$ref_file" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        ref_section="$(echo "$ref_section" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        echo "$(basename "$ref_file")|${ref_section}"
    fi
done > "$COVERED_FILE"

if [[ ! -s "$COVERED_FILE" ]]; then
    echo "no @spec annotations found in test files"
    exit 0
fi

# --- Build coverage table ---
uncovered=0
total=0

printf "%-40s | %-40s | %s\n" "SPEC FILE" "SECTION" "STATUS"
printf "%-40s-+-%-40s-+-%s\n" \
    "$(printf '%0.s-' {1..40})" \
    "$(printf '%0.s-' {1..40})" \
    "$(printf '%0.s-' {1..10})"

while IFS= read -r spec_file; do
    spec_basename="$(basename "$spec_file")"

    # Extract ## and ### headings into a temp file (avoids subshell issues)
    headings_file="$(mktemp)"
    grep '^##' "$spec_file" 2>/dev/null | sed 's/^#* //' > "$headings_file" || true

    while IFS= read -r heading; do
        [[ -z "$heading" ]] && continue
        total=$((total + 1))

        if grep -qF "${spec_basename}|${heading}" "$COVERED_FILE" 2>/dev/null; then
            status="covered"
        else
            status="UNCOVERED"
            uncovered=$((uncovered + 1))
        fi

        printf "%-40s | %-40s | %s\n" "$spec_basename" "$heading" "$status"
    done < "$headings_file"

    rm -f "$headings_file"
done <<< "$spec_list"

echo ""
echo "Total sections: $total"
echo "Covered:        $((total - uncovered))"
echo "Uncovered:      $uncovered"

if [[ "$uncovered" -gt 0 ]]; then
    exit 1
fi

exit 0
