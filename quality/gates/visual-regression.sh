#!/usr/bin/env bash
# visual-regression.sh — Layer 2: Playwright visual regression gate
# Captures screenshots, compares against baselines, reports diffs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Defaults ---
GATE_MODE=0
UPDATE_BASELINES=0
URL=""
BASELINE_DIR="screenshots/baselines"
THRESHOLD="0.01"
DESIGN_DOC=""
VISION_ENDPOINT=""
PROJECT_NAME="visual"
REPORT_DIR="playwright-report"
RESULT_DIR="test-results"

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --gate) GATE_MODE=1; shift ;;
    --update-baselines) UPDATE_BASELINES=1; shift ;;
    --url)
      if [[ $# -lt 2 || "$2" == --* ]]; then echo "ERROR: --url requires a value"; exit 2; fi
      URL="$2"; shift 2 ;;
    --baseline)
      if [[ $# -lt 2 || "$2" == --* ]]; then echo "ERROR: --baseline requires a value"; exit 2; fi
      BASELINE_DIR="$2"; shift 2 ;;
    --threshold)
      if [[ $# -lt 2 || "$2" == --* ]]; then echo "ERROR: --threshold requires a value"; exit 2; fi
      THRESHOLD="$2"; shift 2 ;;
    --design)
      if [[ $# -lt 2 || "$2" == --* ]]; then echo "ERROR: --design requires a value"; exit 2; fi
      DESIGN_DOC="$2"; shift 2 ;;
    --vision-endpoint)
      if [[ $# -lt 2 || "$2" == --* ]]; then echo "ERROR: --vision-endpoint requires a value"; exit 2; fi
      VISION_ENDPOINT="$2"; shift 2 ;;
    --project)
      if [[ $# -lt 2 || "$2" == --* ]]; then echo "ERROR: --project requires a value"; exit 2; fi
      PROJECT_NAME="$2"; shift 2 ;;
    --report-dir)
      if [[ $# -lt 2 || "$2" == --* ]]; then echo "ERROR: --report-dir requires a value"; exit 2; fi
      REPORT_DIR="$2"; shift 2 ;;
    --result-dir)
      if [[ $# -lt 2 || "$2" == --* ]]; then echo "ERROR: --result-dir requires a value"; exit 2; fi
      RESULT_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: visual-regression.sh --url <dev-server> [options]"
      echo ""
      echo "Options:"
      echo "  --url <url>              Dev server URL (required)"
      echo "  --gate                   Gate mode: exit 1 on regression"
      echo "  --update-baselines       Capture new baselines instead of comparing"
      echo "  --baseline <dir>         Baseline directory (default: screenshots/baselines)"
      echo "  --threshold <0-1>        Max diff pixel ratio (default: 0.01)"
      echo "  --design <path>          DESIGN.md for AI review context"
      echo "  --vision-endpoint <url>  Vision model API endpoint for AI review"
      echo "  --project <name>         Playwright project name (default: visual)"
      echo "  --report-dir <dir>       HTML report directory (default: playwright-report)"
      echo "  --result-dir <dir>       Test results directory (default: test-results)"
      exit 0 ;;
    *) echo "Unknown flag: $1"; exit 2 ;;
  esac
done

# --- Validate ---
if [[ -z "$URL" ]]; then
  echo "ERROR: --url is required for visual regression"
  echo "Usage: visual-regression.sh --url http://localhost:3000 [--gate] [--update-baselines]"
  exit 2
fi

# Validate threshold is a number between 0 and 1
if ! [[ "$THRESHOLD" =~ ^[0-9]*\.?[0-9]+$ ]]; then
  echo "ERROR: --threshold must be a number, got: $THRESHOLD"
  exit 2
fi
# Range check (integer comparison for portability — no bc dependency)
THRESHOLD_INT=$(echo "$THRESHOLD" | awk '{printf "%.0f", $1 * 1000}')
if [[ $THRESHOLD_INT -gt 1000 || $THRESHOLD_INT -lt 0 ]]; then
  echo "ERROR: --threshold must be between 0 and 1, got: $THRESHOLD"
  exit 2
fi

# --- Check dependencies ---
for cmd in npx base64; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: $cmd not found."
    case "$cmd" in
      npx) echo "Install Node.js first." ;;
      base64) echo "Install coreutils." ;;
    esac
    exit 2
  fi
done

if ! npx playwright --version &>/dev/null; then
  echo "ERROR: Playwright not installed. Run: npm install -D @playwright/test"
  exit 2
fi

# jq is only needed for AI review, check lazily below

# --- Cross-platform base64 encoding ---
b64_encode() {
  local file="$1"
  if [[ "$(uname)" == "Darwin" ]]; then
    base64 -i "$file" | tr -d '\n'
  else
    base64 -w0 "$file"
  fi
}

# --- Ensure baseline directory exists ---
mkdir -p "$BASELINE_DIR"

# --- Build Playwright command ---
CMD="npx playwright test --project=${PROJECT_NAME}"
if [[ $UPDATE_BASELINES -eq 1 ]]; then
  CMD="${CMD} --update-snapshots"
  echo "=== VISUAL Gate: Update Baselines ==="
else
  echo "=== VISUAL Gate: Visual Regression ==="
fi
echo "  URL: $URL"
echo "  Threshold: $THRESHOLD"
echo "  Baseline: $BASELINE_DIR"
echo ""

# --- Set environment for Playwright ---
export DEV_SERVER_URL="$URL"
export VISUAL_THRESHOLD="$THRESHOLD"
export BASELINE_DIR="$BASELINE_DIR"

# --- Run Playwright ---
set +e
OUTPUT=$($CMD 2>&1)
EXIT_CODE=$?
set -e

# --- Parse results ---
echo "$OUTPUT"

# Extract test counts from Playwright summary line
# Format: "X passed, Y failed, Z skipped" or "X passed"
PASSED="0"
FAILED="0"
SKIPPED="0"
if echo "$OUTPUT" | grep -qE '[0-9]+ passed'; then
  PASSED=$(echo "$OUTPUT" | grep -oE '[0-9]+ passed' | head -1 | grep -oE '[0-9]+')
fi
if echo "$OUTPUT" | grep -qE '[0-9]+ failed'; then
  FAILED=$(echo "$OUTPUT" | grep -oE '[0-9]+ failed' | head -1 | grep -oE '[0-9]+')
fi
if echo "$OUTPUT" | grep -qE '[0-9]+ skipped'; then
  SKIPPED=$(echo "$OUTPUT" | grep -oE '[0-9]+ skipped' | head -1 | grep -oE '[0-9]+')
fi

echo ""
echo "========================================="
echo "  Visual Regression Results"
echo "========================================="
echo "  Passed:   ${PASSED}"
echo "  Failed:   ${FAILED}"
echo "  Skipped:  ${SKIPPED}"
echo "  Exit:     ${EXIT_CODE}"
echo "========================================="

# --- List diff images for review ---
DIFF_COUNT=0
if [[ -d "$RESULT_DIR" ]]; then
  while IFS= read -r diff_file; do
    echo "  DIFF: $diff_file"
    DIFF_COUNT=$((DIFF_COUNT + 1))
  done < <(find "$RESULT_DIR" -name "*-diff.png" 2>/dev/null)
fi

if [[ $DIFF_COUNT -gt 0 ]]; then
  echo ""
  echo "  ${DIFF_COUNT} diff image(s) saved in ${RESULT_DIR}/"
fi

# --- AI Review (optional) ---
if [[ $EXIT_CODE -ne 0 && -n "$VISION_ENDPOINT" && -n "$DESIGN_DOC" ]]; then
  # Check jq dependency now (only needed for AI review)
  if ! command -v jq &>/dev/null; then
    echo ""
    echo "WARNING: jq not installed — skipping AI review. Install jq for vision model integration."
  elif ! command -v curl &>/dev/null; then
    echo ""
    echo "WARNING: curl not installed — skipping AI review."
  else
    echo ""
    echo "--- AI Review ---"
    if [[ -d "$RESULT_DIR" ]]; then
      while IFS= read -r diff_file; do
        actual_file="${diff_file/-diff.png/-actual.png}"
        expected_file="${diff_file/-diff.png/-expected.png}"

        if [[ -f "$actual_file" && -f "$expected_file" ]]; then
          echo "  Analyzing: $(basename "$diff_file")"
          actual_b64=$(b64_encode "$actual_file")
          expected_b64=$(b64_encode "$expected_file")
          diff_b64=$(b64_encode "$diff_file")

          design_context=""
          if [[ -f "$DESIGN_DOC" ]]; then
            design_context=$(head -50 "$DESIGN_DOC")
          fi

          REVIEW_RESPONSE=$(curl -s -X POST "$VISION_ENDPOINT" \
            -H "Content-Type: application/json" \
            -d "$(jq -n \
              --arg actual "$actual_b64" \
              --arg expected "$expected_b64" \
              --arg diff "$diff_b64" \
              --arg design "$design_context" \
              '{
                model: "gpt-4-vision-preview",
                messages: [{
                  role: "user",
                  content: [
                    { type: "text", text: ("Compare these UI screenshots. The first is the baseline, the second is the current rendering, the third is the pixel diff.\n\nDesign context:\n" + $design + "\n\nClassify the change as: intentional, regression, or ambiguous. Respond in JSON: {\"classification\": \"...\", \"summary\": \"...\", \"elements_changed\": [\"...\"]}") },
                    { type: "image_url", image_url: { url: ("data:image/png;base64," + $expected) } },
                    { type: "image_url", image_url: { url: ("data:image/png;base64," + $actual) } },
                    { type: "image_url", image_url: { url: ("data:image/png;base64," + $diff) } }
                  ]
                }],
                max_tokens: 500
              }')" 2>/dev/null) || REVIEW_RESPONSE='{"error": "vision API call failed"}'

          echo "  AI Assessment: $REVIEW_RESPONSE"
        fi
      done < <(find "$RESULT_DIR" -name "*-diff.png" 2>/dev/null)
    fi
  fi
fi

# --- Report and exit ---
if [[ $EXIT_CODE -ne 0 ]]; then
  echo ""
  echo "FAILED — visual regressions detected"
  echo ""
  echo "To update baselines locally:"
  echo "  npx playwright test --project=${PROJECT_NAME} --update-snapshots"
  echo ""
  echo "To view the diff report:"
  echo "  npx playwright show-report ${REPORT_DIR}"

  if [[ $GATE_MODE -eq 1 ]]; then
    exit 1
  fi
  exit 0
fi

echo ""
echo "PASSED — all visual snapshots match"
exit 0
