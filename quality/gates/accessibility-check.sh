#!/usr/bin/env bash
# accessibility-check.sh — Layer 3: axe-core accessibility gate
# Runs @axe-core/playwright to detect WCAG violations.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Detect project root: walk up until we find package.json or .git
_find_project_root() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/package.json" || -d "$dir/.git" ]]; then
      echo "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done
  echo "$1" # fallback: use script dir
}
PROJECT_ROOT="$(_find_project_root "$SCRIPT_DIR")"

# --- Defaults ---
GATE_MODE=0
URL=""
SEVERITY="serious"
OUTPUT_PATH=""

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --gate) GATE_MODE=1; shift ;;
    --url)
      if [[ $# -lt 2 || "$2" == --* ]]; then echo "ERROR: --url requires a value"; exit 2; fi
      URL="$2"; shift 2 ;;
    --severity)
      if [[ $# -lt 2 || "$2" == --* ]]; then echo "ERROR: --severity requires a value"; exit 2; fi
      SEVERITY="$2"; shift 2 ;;
    --output)
      if [[ $# -lt 2 || "$2" == --* ]]; then echo "ERROR: --output requires a value"; exit 2; fi
      OUTPUT_PATH="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: accessibility-check.sh --url <dev-server> [options]"
      echo ""
      echo "Options:"
      echo "  --url <url>         Dev server URL (required)"
      echo "  --gate              Gate mode: exit 1 on violations"
      echo "  --severity <level>  Minimum severity: critical, serious, moderate, minor (default: serious)"
      echo "  --output <path>     JSON report output path"
      exit 0 ;;
    *) echo "Unknown flag: $1"; exit 2 ;;
  esac
done

# --- Validate ---
if [[ -z "$URL" ]]; then
  echo "ERROR: --url is required for accessibility check"
  echo "Usage: accessibility-check.sh --url http://localhost:3000 [--gate] [--severity serious]"
  exit 2
fi

# Validate severity level
case "$SEVERITY" in
  critical) SEVERITY_NUM=4 ;;
  serious)  SEVERITY_NUM=3 ;;
  moderate) SEVERITY_NUM=2 ;;
  minor)    SEVERITY_NUM=1 ;;
  *) echo "Unknown severity: $SEVERITY (use: critical, serious, moderate, minor)"; exit 2 ;;
esac

# --- Check dependencies ---
if ! command -v npx &>/dev/null; then
  echo "ERROR: npx not found. Install Node.js first."
  exit 2
fi

if ! npx playwright --version &>/dev/null; then
  echo "ERROR: Playwright not installed. Run: npm install -D @playwright/test"
  exit 2
fi

echo "=== ACCESSIBILITY Gate: axe-core Check ==="
echo "  URL: $URL"
echo "  Severity filter: ≥ $SEVERITY"
echo ""

# --- Create temporary test file ---
A11Y_TMPDIR=$(mktemp -d)
trap 'rm -rf "$A11Y_TMPDIR"' EXIT

cat > "$A11Y_TMPDIR/accessibility.spec.ts" << 'TESTEOF'
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import * as fs from 'fs';

const url = process.env.A11Y_URL || '/';
const severityFilter = process.env.A11Y_SEVERITY || 'serious';
const outputPath = process.env.A11Y_OUTPUT || '';

const severityLevels: Record<string, number> = {
  minor: 1,
  moderate: 2,
  serious: 3,
  critical: 4,
};

const minSeverity = severityLevels[severityFilter] || 3;

test('accessibility check', async ({ page }) => {
  await page.goto(url, { waitUntil: 'networkidle' });

  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
    .analyze();

  // Filter violations by severity
  const filtered = results.violations.filter((v: any) => {
    const level = severityLevels[v.impact] || 0;
    return level >= minSeverity;
  });

  // Build report
  const report = {
    url,
    timestamp: new Date().toISOString(),
    severity_filter: severityFilter,
    total_violations: results.violations.length,
    filtered_violations: filtered.length,
    violations: filtered.map((v: any) => ({
      id: v.id,
      impact: v.impact,
      description: v.description,
      help: v.help,
      helpUrl: v.helpUrl,
      nodes: v.nodes.map((n: any) => ({
        html: n.html.substring(0, 200),
        target: n.target,
        failureSummary: n.failureSummary,
      })),
    })),
    passes: results.passes.length,
    incomplete: results.incomplete.length,
  };

  // Output to file if requested
  if (outputPath) {
    fs.writeFileSync(outputPath, JSON.stringify(report, null, 2));
    console.log(`Report written to: ${outputPath}`);
  }

  // Output summary
  console.log(`\nViolations found: ${results.violations.length} total, ${filtered.length} ≥ ${severityFilter}`);
  for (const v of filtered) {
    console.log(`\n  [${v.impact}] ${v.id}: ${v.help}`);
    console.log(`  ${v.helpUrl}`);
    for (const n of v.nodes) {
      console.log(`    → ${n.target.join(' > ')}`);
      console.log(`      ${n.failureSummary}`);
    }
  }

  // Assert — fail the test if violations found
  expect(filtered).toEqual([]);
});
TESTEOF

# Create config in temp dir with absolute testDir path
# This lets us run from PROJECT_ROOT (so node_modules resolves)
# while Playwright finds the test in the temp dir
# Escape single quotes in URL to prevent TypeScript syntax errors
ESCAPED_URL="${URL//\'/\\\'}"
cat > "$A11Y_TMPDIR/playwright.config.ts" << CONFIGEOF
import { defineConfig } from '@playwright/test';
export default defineConfig({
  testDir: '${A11Y_TMPDIR}',
  use: {
    baseURL: '${ESCAPED_URL}',
  },
});
CONFIGEOF

# --- Run the test from PROJECT_ROOT so node_modules resolves ---
export A11Y_URL="$URL"
export A11Y_SEVERITY="$SEVERITY"
A11Y_REPORT="${OUTPUT_PATH:-$A11Y_TMPDIR/a11y-report.json}"
export A11Y_OUTPUT="$A11Y_REPORT"

set +e
OUTPUT=$(cd "$PROJECT_ROOT" && npx playwright test --config="$A11Y_TMPDIR/playwright.config.ts" --reporter=list 2>&1)
EXIT_CODE=$?
set -e

# --- Parse and display results ---
echo "$OUTPUT"

# Load report if available
if [[ -f "$A11Y_REPORT" ]] && command -v jq &>/dev/null; then
  VIOLATIONS=$(jq -r '.filtered_violations // 0' "$A11Y_REPORT" 2>/dev/null || echo "0")
  TOTAL=$(jq -r '.total_violations // 0' "$A11Y_REPORT" 2>/dev/null || echo "0")
  PASSES=$(jq -r '.passes // 0' "$A11Y_REPORT" 2>/dev/null || echo "0")

  echo ""
  echo "========================================="
  echo "  Accessibility Results"
  echo "========================================="
  echo "  Total violations:   ${TOTAL}"
  echo "  Filtered (≥${SEVERITY}): ${VIOLATIONS}"
  echo "  Rules passed:       ${PASSES}"
  echo "  Exit:               ${EXIT_CODE}"
  echo "========================================="

  # Copy report to output path if specified and different
  if [[ -n "$OUTPUT_PATH" && -f "$A11Y_REPORT" && "$OUTPUT_PATH" != "$A11Y_REPORT" ]]; then
    cp "$A11Y_REPORT" "$OUTPUT_PATH"
    echo "  Report saved to: ${OUTPUT_PATH}"
  fi
elif [[ -f "$A11Y_REPORT" ]]; then
  echo ""
  echo "  (Install jq for detailed violation summary)"
fi

# --- Exit ---
if [[ $EXIT_CODE -ne 0 ]]; then
  echo ""
  echo "FAILED — accessibility violations detected"

  if [[ $GATE_MODE -eq 1 ]]; then
    exit 1
  fi
  exit 0
fi

echo ""
echo "PASSED — no accessibility violations (≥ ${SEVERITY})"
exit 0
