#!/bin/bash
# issue-cli.sh — File-based issue tracking for dev-kit
# Usage: issue-cli.sh <command> [options]
#
# Commands:
#   create  --type bug|enhancement|research [--component X] [--title "T"]
#   list    [--status open|closed] [--component X] [--type bug|enhancement|research]
#   update  <id> --status <new-status>
#   close   <id>
#   summary
#
# Issues are stored as markdown files in issues/ with YAML frontmatter.

set -euo pipefail

ISSUES_DIR="${ISSUES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/issues}"
TEMPLATES_DIR="$ISSUES_DIR/templates"

# --- Helpers ---

next_id() {
  local type="$1"
  local prefix
  case "$type" in
    bug) prefix="BUG" ;;
    enhancement) prefix="ENH" ;;
    research) prefix="RES" ;;
    *) prefix="ISS" ;;
  esac
  local max=0
  local files
  files=$(find "$ISSUES_DIR" -maxdepth 1 -name "${prefix}-*.md" -type f 2>/dev/null || true)
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local num
    num=$(basename "$f" | grep -oE '[0-9]+' | head -1)
    if [ "${num:-0}" -gt "$max" ] 2>/dev/null; then
      max=$num
    fi
  done <<< "$files"
  printf "%s-%04d" "$prefix" $((max + 1))
}

get_frontmatter() {
  local file="$1" key="$2"
  sed -n '/^---$/,/^---$/p' "$file" | grep "^$key:" | sed "s/^$key:[[:space:]]*//"
}

set_frontmatter() {
  local file="$1" key="$2" value="$3"
  # Use awk for safe replacement (handles special characters in value)
  awk -v key="$key" -v val="$value" '
    $0 ~ "^"key":" { print key": "val; next }
    { print }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# --- Commands ---

cmd_create() {
  local type="bug" component="" title=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --type) type="$2"; shift 2 ;;
      --component) component="$2"; shift 2 ;;
      --title) title="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local id
  id=$(next_id "$type")
  local date
  date=$(date +%Y-%m-%d)
  local template="$TEMPLATES_DIR/$type.md"
  local outfile="$ISSUES_DIR/$id-$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-').md"

  if [ ! -f "$template" ]; then
    echo "ERROR: Template not found: $template" >&2
    exit 1
  fi

  # Create issue from template
  cp "$template" "$outfile"

  # Fill in frontmatter
  set_frontmatter "$outfile" "id" "$id"
  set_frontmatter "$outfile" "title" "\"$title\""
  set_frontmatter "$outfile" "date" "$date"
  [ -n "$component" ] && set_frontmatter "$outfile" "component" "$component"

  echo "Created: $outfile"
  echo "ID: $id"
}

cmd_list() {
  local status_filter="" component_filter="" type_filter=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --status) status_filter="$2"; shift 2 ;;
      --component) component_filter="$2"; shift 2 ;;
      --type) type_filter="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  printf "%-12s %-8s %-10s %-12s %s\n" "ID" "Status" "Priority" "Component" "Title"
  printf "%-12s %-8s %-10s %-12s %s\n" "---" "------" "--------" "---------" "-----"

  local files
  files=$(find "$ISSUES_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null || true)
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ "$(basename "$f")" = "INDEX.md" ] && continue
    [[ "$(basename "$f")" == *"-template"* ]] && continue

    local id status priority component title
    id=$(get_frontmatter "$f" "id")
    status=$(get_frontmatter "$f" "status")
    priority=$(get_frontmatter "$f" "priority")
    component=$(get_frontmatter "$f" "component")
    title=$(get_frontmatter "$f" "title" | tr -d '"')

    # Apply filters
    [ -n "$status_filter" ] && [ "$status" != "$status_filter" ] && continue
    [ -n "$component_filter" ] && [ "$component" != "$component_filter" ] && continue
    [ -n "$type_filter" ] && ! echo "$id" | grep -qi "^${type_filter}" && continue

    printf "%-12s %-8s %-10s %-12s %s\n" "$id" "$status" "$priority" "$component" "$title"
  done <<< "$files"
}

cmd_update() {
  local id="$1"; shift
  local new_status=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --status) new_status="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ -z "$new_status" ]; then
    echo "ERROR: --status required" >&2
    exit 1
  fi

  local file
  file=$(find "$ISSUES_DIR" -name "${id}*.md" -type f | head -1)
  if [ -z "$file" ]; then
    echo "ERROR: Issue not found: $id" >&2
    exit 1
  fi

  set_frontmatter "$file" "status" "$new_status"
  echo "Updated: $id -> $new_status"
}

cmd_close() {
  local id="$1"
  cmd_update "$id" --status "closed"
}

cmd_summary() {
  local open=0 closed=0
  local files
  files=$(find "$ISSUES_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null || true)
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ "$(basename "$f")" = "INDEX.md" ] && continue
    local status
    status=$(get_frontmatter "$f" "status")
    case "$status" in
      open) open=$((open + 1)) ;;
      closed) closed=$((closed + 1)) ;;
    esac
  done <<< "$files"
  echo "Issues: $open open, $closed closed, $((open + closed)) total"
}

# --- Main ---

case "${1:-help}" in
  create) shift; cmd_create "$@" ;;
  list) shift; cmd_list "$@" ;;
  update) shift; cmd_update "$@" ;;
  close) shift; cmd_close "$@" ;;
  summary) cmd_summary ;;
  *)
    echo "Usage: issue-cli.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  create  --type bug|enhancement|research [--component X] [--title T]"
    echo "  list    [--status open|closed] [--component X]"
    echo "  update  <id> --status <new-status>"
    echo "  close   <id>"
    echo "  summary"
    ;;
esac
