#!/bin/bash
# hook-violations-to-issues.sh — Convert hook violation log to issue-cli issues
# Reads ~/.claude/hook-violations.log and creates issues for repeated violations
#
# Usage: bash tools/hook-violations-to-issues.sh [--dry-run]

set -euo pipefail

VIOLATIONS_LOG="${HOME}/.claude/hook-violations.log"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

if [ ! -f "$VIOLATIONS_LOG" ]; then
  echo "No violations log found at $VIOLATIONS_LOG"
  exit 0
fi

# Count violations by pattern
echo "=== Hook Violations Summary ==="
echo ""
awk -F'|' '{print $1}' "$VIOLATIONS_LOG" | sort | uniq -c | sort -rn | while read count pattern; do
  echo "  $count x $pattern"
done

echo ""
echo "=== Recent Violations (last 10) ==="
tail -10 "$VIOLATIONS_LOG" | while IFS='|' read -r pattern command timestamp; do
  echo "  [$timestamp] $pattern: $command"
done

# Create issues for patterns with 3+ violations
echo ""
awk -F'|' '{print $1}' "$VIOLATIONS_LOG" | sort | uniq -c | sort -rn | while read count pattern; do
  if [ "$count" -ge 3 ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "DRY RUN: Would create issue for '$pattern' ($count violations)"
    else
      echo "Creating issue for '$pattern' ($count violations)..."
      source ~/.nvm/nvm.sh 2>/dev/null && nvm use 22 --silent 2>/dev/null
      issue open "Hook violation: $pattern ($count occurrences)" \
        --project dev-kit --type bug --severity P2 \
        --tags "hook,auto-filed" \
        --body "Auto-filed from hook violations log. Pattern: $pattern. Count: $count. See ~/.claude/hook-violations.log for details."
    fi
  fi
done

echo ""
echo "Done. Run 'issue list --project dev-kit --state open' to see all issues."
