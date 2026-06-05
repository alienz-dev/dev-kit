#!/usr/bin/env bash
# visual-gate.sh — Composed VISUAL gate (Layer 1 + 2 + 3)
# Single entry point for Sprint-Manager. Runs static analysis, then
# Playwright visual regression, then axe-core accessibility.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Defaults ---
GATE_MODE=0
URL=""
FILES=""
BASELINE_DIR="screenshots/baselines"
THRESHOLD="0.01"
DESIGN_DOC=""
VISION_ENDPOINT=""
SEVERITY="serious"
OUTPUT_DIR=""
PROJECT_NAME="visual"
REPORT_DIR="playwright-report"
RESULT_DIR="test-results"

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --gate) GATE_MODE=1; shift ;;
    --url)
      if [[ $# -lt 2 || "$2" == --* ]]; then echo "ERROR: --url requires a value"; exit 2; fi
      URL="$2"; shift 2 ;;
    --files)
      if [[ $# -lt 2 || "$2" == --* ]]; then echo "ERROR: --files requires a value"; exit 2; fi
      FILES="$2"; shift 2 ;;
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
    --severity)
      if [[ $# -lt 2 || "$2" == --* ]]; then echo "ERROR: --severity requires a value"; exit 2; fi
      SEVERITY="$2"; shift 2 ;;
    --output)
      if [[ $# -lt 2 || "$2" == --* ]]; then echo "ERROR: --output requires a value"; exit 2; fi
      OUTPUT_DIR="$2"; shift 2 ;;
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
      echo "Usage: visual-gate.sh [options]"
      echo ""
      echo "Composed VISUAL gate — runs all 3 layers."
      echo ""
      echo "Options:"
      echo "  --gate                   Gate mode: exit 1 on any failure"
      echo "  --url <url>              Dev server URL (enables Layers 2+3)"
      echo "  --files <glob>           UI files to check"
      echo "  --baseline <dir>         Baseline directory (default: screenshots/baselines)"
      echo "  --threshold <0-1>        Max diff pixel ratio (default: 0.01)"
      echo "  --design <path>          DESIGN.md for AI review context"
      echo "  --vision-endpoint <url>  Vision model API endpoint"
      echo "  --severity <level>       A11y min severity: critical, serious, moderate, minor (default: serious)"
      echo "  --output <dir>           Output directory for reports"
      echo "  --project <name>         Playwright project name (default: visual)"
      echo "  --report-dir <dir>       HTML report directory (default: playwright-report)"
      echo "  --result-dir <dir>       Test results directory (default: test-results)"
      exit 0 ;;
    *) echo "Unknown flag: $1"; exit 2 ;;
  esac
done

echo "╔═══════════════════════════════════════════════╗"
echo "║           VISUAL Gate — 3-Layer Check         ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""

LAYER1_EXIT=0
LAYER2_EXIT=0
LAYER3_EXIT=0
LAYER2_SKIPPED=0
LAYER3_SKIPPED=0

# ────────────────────────────────────────────────
# Layer 1: Static Analysis (always runs)
# ────────────────────────────────────────────────
echo "━━━ Layer 1: Static Analysis ━━━"
LAYER1_ARGS=()
if [[ -n "$FILES" ]]; then
  LAYER1_ARGS+=(--files "$FILES")
fi

bash "$SCRIPT_DIR/ui-visual-check.sh" "${LAYER1_ARGS[@]+"${LAYER1_ARGS[@]}"}" || LAYER1_EXIT=$?
if [[ $LAYER1_EXIT -eq 0 ]]; then
  echo "  ✓ Layer 1 passed"
else
  echo "  ✗ Layer 1 failed (exit $LAYER1_EXIT)"
fi
echo ""

# ────────────────────────────────────────────────
# Layer 2: Visual Regression (needs dev server)
# ────────────────────────────────────────────────
echo "━━━ Layer 2: Visual Regression ━━━"
if [[ -z "$URL" ]]; then
  echo "  ⊘ Skipped (no --url provided)"
  LAYER2_SKIPPED=1
else
  LAYER2_ARGS=(--url "$URL")
  if [[ $GATE_MODE -eq 1 ]]; then
    LAYER2_ARGS+=(--gate)
  fi
  if [[ -n "$BASELINE_DIR" ]]; then
    LAYER2_ARGS+=(--baseline "$BASELINE_DIR")
  fi
  if [[ -n "$THRESHOLD" ]]; then
    LAYER2_ARGS+=(--threshold "$THRESHOLD")
  fi
  if [[ -n "$DESIGN_DOC" ]]; then
    LAYER2_ARGS+=(--design "$DESIGN_DOC")
  fi
  if [[ -n "$VISION_ENDPOINT" ]]; then
    LAYER2_ARGS+=(--vision-endpoint "$VISION_ENDPOINT")
  fi
  if [[ -n "$PROJECT_NAME" ]]; then
    LAYER2_ARGS+=(--project "$PROJECT_NAME")
  fi
  if [[ -n "$REPORT_DIR" ]]; then
    LAYER2_ARGS+=(--report-dir "$REPORT_DIR")
  fi
  if [[ -n "$RESULT_DIR" ]]; then
    LAYER2_ARGS+=(--result-dir "$RESULT_DIR")
  fi

  bash "$SCRIPT_DIR/visual-regression.sh" "${LAYER2_ARGS[@]+"${LAYER2_ARGS[@]}"}" || LAYER2_EXIT=$?
  if [[ $LAYER2_EXIT -eq 0 ]]; then
    echo "  ✓ Layer 2 passed"
  else
    echo "  ✗ Layer 2 failed (exit $LAYER2_EXIT)"
  fi
fi
echo ""

# ────────────────────────────────────────────────
# Layer 3: Accessibility (needs dev server)
# ────────────────────────────────────────────────
echo "━━━ Layer 3: Accessibility ━━━"
if [[ -z "$URL" ]]; then
  echo "  ⊘ Skipped (no --url provided)"
  LAYER3_SKIPPED=1
else
  LAYER3_ARGS=(--url "$URL" --severity "$SEVERITY")
  if [[ $GATE_MODE -eq 1 ]]; then
    LAYER3_ARGS+=(--gate)
  fi
  if [[ -n "$OUTPUT_DIR" ]]; then
    LAYER3_ARGS+=(--output "$OUTPUT_DIR/a11y-report.json")
  fi

  bash "$SCRIPT_DIR/accessibility-check.sh" "${LAYER3_ARGS[@]+"${LAYER3_ARGS[@]}"}" || LAYER3_EXIT=$?
  if [[ $LAYER3_EXIT -eq 0 ]]; then
    echo "  ✓ Layer 3 passed"
  else
    echo "  ✗ Layer 3 failed (exit $LAYER3_EXIT)"
  fi
fi
echo ""

# ────────────────────────────────────────────────
# Aggregate Results
# ────────────────────────────────────────────────
echo "╔═══════════════════════════════════════════════╗"
echo "║              VISUAL Gate Summary               ║"
echo "╠═══════════════════════════════════════════════╣"
echo "║  Layer 1 (Static):     $(if [[ $LAYER1_EXIT -eq 0 ]]; then echo "✓ PASS"; else echo "✗ FAIL ($LAYER1_EXIT)"; fi)"
if [[ $LAYER2_SKIPPED -eq 1 ]]; then
  echo "║  Layer 2 (Regression): ⊘ SKIP"
else
  echo "║  Layer 2 (Regression): $(if [[ $LAYER2_EXIT -eq 0 ]]; then echo "✓ PASS"; else echo "✗ FAIL ($LAYER2_EXIT)"; fi)"
fi
if [[ $LAYER3_SKIPPED -eq 1 ]]; then
  echo "║  Layer 3 (A11y):       ⊘ SKIP"
else
  echo "║  Layer 3 (A11y):       $(if [[ $LAYER3_EXIT -eq 0 ]]; then echo "✓ PASS"; else echo "✗ FAIL ($LAYER3_EXIT)"; fi)"
fi
echo "╚═══════════════════════════════════════════════╝"

# --- Determine final exit code ---
FINAL_EXIT=0
if [[ $LAYER1_EXIT -ne 0 ]]; then FINAL_EXIT=$LAYER1_EXIT; fi
if [[ $LAYER2_EXIT -ne 0 && $LAYER2_EXIT -gt $FINAL_EXIT ]]; then FINAL_EXIT=$LAYER2_EXIT; fi
if [[ $LAYER3_EXIT -ne 0 && $LAYER3_EXIT -gt $FINAL_EXIT ]]; then FINAL_EXIT=$LAYER3_EXIT; fi

echo ""
if [[ $FINAL_EXIT -eq 0 ]]; then
  echo "PASS — VISUAL gate passed"
else
  echo "FAIL — VISUAL gate failed (exit $FINAL_EXIT)"
  if [[ $GATE_MODE -eq 1 ]]; then
    echo ""
    echo "Retry with: visual-gate.sh --gate --url <dev-server> --files <changed-ui-files>"
  fi
fi

exit $FINAL_EXIT
