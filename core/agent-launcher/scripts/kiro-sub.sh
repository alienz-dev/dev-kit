#!/bin/bash
# kiro-sub.sh — Spawn an interactive Kiro session in a new terminal tab
# Usage: kiro-sub.sh "task description" [--agent NAME] [--context FILE] [--workdir PATH] [--headless]
set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") <arg1> <arg2>" >&2
    echo "  kiro-sub.sh — Spawn an interactive Kiro session in a new terminal tab" >&2
    exit ${1:-1}
}
[[ "${1:-}" == "--help" ]] && usage 0
[[ $# -lt 2 ]] && usage


TASK="${1:?Usage: kiro-sub.sh \"task\" [--agent NAME] [--context FILE] [--workdir PATH] [--tab-name NAME] [--headless]}"
shift

CONTEXT_FILE="" WORKDIR="" AGENT_NAME="" TAB_NAME="" HEADLESS=-1 TOPIC_TAB=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT_NAME="$2"; shift 2 ;;
    --context) CONTEXT_FILE="$2"; shift 2 ;;
    --workdir) WORKDIR="$2"; shift 2 ;;
    --tab-name) TAB_NAME="$2"; shift 2 ;;
    --headless) HEADLESS=1; shift ;;
    --visible) HEADLESS=0; shift ;;
    --topic) TOPIC_TAB=1; shift ;;
    *) shift ;;
  esac
done

# --- Auto-detect agent from task description ---
auto_detect_agent() {
  local task_lower="${TASK,,}"
  # Ticket IDs or sprint keywords → sprint agent
  if echo "$task_lower" | grep -qE '(tax|qe|neb|csd)-[0-9]+|sprint|standup|blocker'; then
    echo "sprint"
  elif echo "$task_lower" | grep -qE '(investigate|bug|fix)' && echo "$task_lower" | grep -qE '(tax|qe|neb|csd|ticket)'; then
    echo "sprint"
  elif echo "$task_lower" | grep -qE 'debug|broken|error|crash|failing|not.working|root.cause'; then
    echo "debugger"
  elif echo "$task_lower" | grep -qE '(research|investigate|deep.dive|compare.*vs)'; then
    echo "planner"
  fi
}

if [[ -z "$AGENT_NAME" ]]; then
  AGENT_NAME=$(auto_detect_agent)
fi

# Determine if using a named (persistent) agent or throwaway
NAMED_AGENT=""
if [[ -n "$AGENT_NAME" && -f "$HOME/.kiro/agents/${AGENT_NAME}.json" ]]; then
  NAMED_AGENT=1
fi

ID="kiro-sub-$(date +%s%3N)"
BRIEFING="/tmp/${ID}-briefing.md"
RESULT="/tmp/${ID}-result.md"
LAUNCHER="/tmp/${ID}-launch.sh"
STDERR_LOG="/tmp/${ID}-stderr.log"
STATUS_LOG="${HOME}/.local/share/kiro/sub-status.jsonl"
GENERATED_AGENT=""

if [[ -n "$NAMED_AGENT" ]]; then
  AGENT_ID="$AGENT_NAME"
  AGENT_JSON="$HOME/.kiro/agents/${AGENT_NAME}.json"
else
  AGENT_ID="$ID"
  AGENT_JSON="$HOME/.kiro/agents/${ID}.json"
  GENERATED_AGENT=1
fi

VAULT="$HOME/vault"

# --- Derive --trust-tools from agent JSON (replaces --trust-all-tools) ---
TRUST_TOOLS=""
ROLE_WRITE_PATHS_VAL=""
if [[ -f "$AGENT_JSON" ]]; then
  eval "$(python3 -c "
import json
d=json.load(open('$AGENT_JSON'))
at=d.get('allowedTools') or d.get('tools') or []
print('TRUST_TOOLS=\"' + ','.join(at) + '\"')
# Extract write paths from hook commands that reference role-check-bash-paths.sh
hooks=d.get('hooks',{}).get('preToolUse',[])
for h in hooks:
  if 'bash-paths' in h.get('command',''):
    # Role has bash path checking — need ROLE_WRITE_PATHS
    # Derive from agent name
    name=d.get('name','')
    paths={
      'hs-planner':'/tmp/,/home/mingl/plans/',
      'hs-manager':'/tmp/,/home/mingl/vault/skills/studenths-crew/',
      'hs-discoverer':'/tmp/,/home/mingl/vault/skills/studenths-crew/discovery/',
      'hs-tester':'/tmp/,/home/mingl/vault/skills/studenths-crew/results/',
      'hs-reviewer':'/tmp/,/home/mingl/vault/skills/studenths-crew/results/',
    }
    print('ROLE_WRITE_PATHS_VAL=\"' + paths.get(name,'/tmp/') + '\"')
    break
" 2>/dev/null || true)"
fi
if [[ -n "$TRUST_TOOLS" ]]; then
  TRUST_FLAG="--trust-tools=$TRUST_TOOLS"
else
  TRUST_FLAG="--trust-all-tools"
fi

# --- Color emoji: color = topic identity, shape = role ---
# Circle = root/topic owner, Square = worker child
# Color inherited from parent if available, otherwise from task hash
SQUARES=(🟥 🟦 🟩 🟨 🟪 🟧)
CIRCLES=(🔴 🔵 🟢 🟡 🟣 🟠)

source ~/scripts/lib-tab-title.sh

# Workers inherit parent's color index; root tabs get color from task hash
if [[ -n "${KIRO_PARENT_COLOR_IDX:-}" ]]; then
  COLOR_IDX="$KIRO_PARENT_COLOR_IDX"
else
  COLOR_IDX=$(( $(echo -n "$TASK" | cksum | awk '{print $1}') % 6 ))
fi
SQUARE="${SQUARES[$COLOR_IDX]}"
CIRCLE="${CIRCLES[$COLOR_IDX]}"
# Root/topic tabs use circle, workers use square
TOPIC_EMOJI="$CIRCLE"
WORKER_EMOJI="$SQUARE"

TOPIC=$(_extract_topic "$TASK")
[[ -z "$TOPIC" ]] && TOPIC="${TASK:0:20}"
[[ -n "$TAB_NAME" ]] && TOPIC="$TAB_NAME"
SHORT_TITLE="$TOPIC"

# --- Context matching: find relevant skill files ---
matched_resources() {
  local task_lower="${TASK,,}"
  local files=()

  # Named agents have their own rules; throwaway gets lite rules
  if [[ -z "$NAMED_AGENT" ]]; then
    files+=("$VAULT/rules/sub-task-rules.md")
  fi

  declare -A KW_MAP=(
    ["morning.update"]="skills/morning-update/morning-update.md"
    ["standup|daily.standup"]="skills/daily-standup/daily-standup.md"
    ["jira|ticket"]="skills/jira-ticket/jira-ticket.md"
    ["pr|pull.request|bitbucket"]="skills/pr-creation/pr-creation.md"
    ["merge.pr|bb.merge"]="skills/bb-merge-prs/bb-merge-prs.md"
    ["jenkins|pipeline"]="skills/jenkins/jenkins.md"
    ["maven|mvn"]="skills/maven-build/maven-build.md"
    ["k8s|kubernetes|pod"]="skills/k8s-deploy/k8s-deploy.md"
    ["cve|vulnerability"]="skills/cve-workflow/cve-workflow.md"
    ["veracode"]="skills/veracode-scan/veracode-scan.md"
    ["dashboard"]="skills/dashboard/dashboard.md"
    ["sprint"]="skills/sprint-monitor/sprint-monitor.md"
    ["docker|compose|container"]="skills/docker-local/docker-local.md"
    ["deploy|deployment"]="skills/deploy-agent/deploy-agent.md"
    ["todo|checklist"]="skills/todo/todo.md"
    ["cdp|browser|chrome"]="skills/chrome-cdp/chrome-cdp.md"
    ["outlook|email"]="skills/outlook-mail-management/outlook-mail-management.md"
    ["teams|message"]="skills/teams-messaging/teams-messaging.md"
    ["taxintell|tax"]="skills/taxintell/deep-dive.md"
    ["qds|feeds"]="skills/qds-feeds/qds-feeds.md"
    ["data.fix|feed.fix"]="skills/data-fix/data-fix.md"
    ["timesheet|deltek"]="skills/timesheet/timesheet.md"
    ["confluence|wiki"]="skills/confluence-knowledge-base/confluence-knowledge-base.md"
    ["zscaler|vpn|proxy"]="skills/zscaler/zscaler.md"
    ["code.review"]="skills/code-review/code-review.md"
    ["calendar|meetings"]="skills/calendar/calendar.md"
    ["leave|micropay|pto"]="skills/micropay-leave/micropay-leave.md"
    ["keep.alive|active.hours"]="skills/keep-alive/keep-alive.md"
    ["release"]="skills/release-checklist/release-checklist.md"
    ["transcribe|meeting.audio"]="skills/live-transcribe/live-transcribe.md"
    ["persist|promote.script"]="skills/persist-workflow/persist-workflow.md"
    ["research|investigate|deep.dive|compare.*vs"]="skills/deep-research/deep-research.md"
    ["debug|broken|error|crash|root.cause"]="skills/systematic-debugging/systematic-debugging.md"
  )

  local seen=""
  for pattern in "${!KW_MAP[@]}"; do
    local regex="${pattern//./[^a-z]}"
    if echo "$task_lower" | grep -qE "$regex"; then
      local skill="${KW_MAP[$pattern]}"
      local full="$VAULT/$skill"
      if [[ -f "$full" && "$seen" != *"$full"* ]]; then
        seen="$seen $full"
        files+=("$full")
      fi
    fi
  done

  printf '['
  local first=1
  for f in "${files[@]}"; do
    [[ $first -eq 1 ]] && first=0 || printf ','
    printf '"file://%s"' "$f"
  done
  printf ']'
}

RESOURCES=$(matched_resources)

# --- Generate task-specific agent config (throwaway only) ---
if [[ -n "$GENERATED_AGENT" ]]; then
cat > "$AGENT_JSON" <<AGENTEOF
{
  "name": "${ID}",
  "description": "Sub-task: ${SHORT_TITLE}",
  "model": "claude-opus-4.6",
  "prompt": "You are working on a sub-task. Be concise and focused. Write your results to the specified result file using fs_write when done.\n\nAfter your final response text (before the prompt appears), always end with a separator line: \`------\`. This must be the very last line of your output.",
  "mcpServers": {},
  "tools": ["fs_read", "fs_write", "execute_bash"],
  "toolAliases": {},
  "allowedTools": ["fs_read", "fs_write"],
  "resources": ${RESOURCES},
  "toolsSettings": {
    "execute_bash": {
      "alwaysAllow": [{"preset": "readOnly"}]
    }
  },
  "useLegacyMcpJson": true
}
AGENTEOF
fi
# --- Spawn UUID for launcher queue isolation ---
SPAWN_UUID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)
CHILD_SESSION_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)
# Query parent session
PARENT_SESSION_ID="${KIRO_SESSION_ID:-}"
PARENT_PANE_ID="${ZELLIJ_PANE_ID:-}"
PARENT_ZELLIJ_SESSION="${ZELLIJ_SESSION_NAME:-}"

INTERACTIVE=0
TASK_LOWER="${TASK,,}"
if echo "$TASK_LOWER" | grep -qE 'discuss|interactive|planning session|wait for.*(user|input|feedback)|ask.*question|collaborate'; then
  INTERACTIVE=1
fi

# --- Headless heuristic ---
should_go_headless() {
  local task_lower="${TASK,,}"

  # Already interactive? Never headless
  [[ "$INTERACTIVE" -eq 1 ]] && return 1

  # Named persistent agent? Stay visible
  [[ -n "$NAMED_AGENT" ]] && return 1

  # Ambiguity markers → visible
  echo "$task_lower" | grep -qE 'investigate|debug|explore|figure.out|not.sure|help.me|what.should|diagnose' && return 1

  # Large context file → visible
  if [[ -n "$CONTEXT_FILE" && -f "$CONTEXT_FILE" ]]; then
    local size=$(stat -c%s "$CONTEXT_FILE" 2>/dev/null || echo 0)
    [[ $size -gt 10240 ]] && return 1
  fi

  # Simple output task → headless
  echo "$task_lower" | grep -qE 'write.*(to|file|result)|create.*file|update.*file|generate|add.*to|append' && return 0

  # Default: visible (conservative)
  return 1
}

# Auto-detect mode if not explicitly set
# Topic tabs are always visible — override any headless setting
if [[ "$TOPIC_TAB" -eq 1 ]]; then
  HEADLESS=0
  AUTO_MODE="visible (topic)"
elif [[ "$HEADLESS" -eq -1 ]]; then
  if should_go_headless; then
    HEADLESS=1
    AUTO_MODE="headless (auto)"
  else
    HEADLESS=0
    AUTO_MODE="visible (auto)"
  fi
elif [[ "$HEADLESS" -eq 1 ]]; then
  AUTO_MODE="headless (forced)"
else
  AUTO_MODE="visible (forced)"
fi

# Planner stays open by default — no auto-close unless --headless
if [[ "$AGENT_NAME" == "planner" && "$HEADLESS" -eq 0 && "$INTERACTIVE" -eq 0 ]]; then
  INTERACTIVE=1
fi

if [[ "$TOPIC_TAB" -eq 1 && "$INTERACTIVE" -eq 1 ]]; then
cat > "$BRIEFING" <<EOF
# You are starting a new session on: ${TASK}

You are in a live conversation with the user. This is NOT a sub-task — do not auto-complete.

IMPORTANT RULES:
- Do NOT type /quit
- Do NOT write a result file
- Do NOT signal completion
- After your first response, STOP and WAIT for the user to reply
- Continue the conversation as long as the user wants
- The user will close this tab manually when done

## Session
Session ID: ${CHILD_SESSION_ID}

EOF
elif [[ "$TOPIC_TAB" -eq 1 ]]; then
cat > "$BRIEFING" <<EOF
# You are starting a new session on: ${TASK}

## Session
Session ID: ${CHILD_SESSION_ID}
EOF
elif [[ "$INTERACTIVE" -eq 1 ]]; then
cat > "$BRIEFING" <<EOF
# ${TASK}

You are in a live conversation with the user. This is NOT a sub-task — do not auto-complete.

IMPORTANT RULES:
- Do NOT type /quit
- Do NOT write a result file
- Do NOT signal completion
- After your first response, STOP and WAIT for the user to reply
- Continue the conversation as long as the user wants
- The user will close this tab manually when done

## Environment
- Parent pane: terminal_${PARENT_PANE_ID}
- Session ID: \${KIRO_SESSION_ID}

## Shortcodes
| Code | Action |
|------|--------|
| report | Summarize discussion, write to mailbox, inject into parent |

## Report Protocol
When user types "report":
1. Summarize: learnings, progress, patterns, action items, knowledge worth persisting
2. \`mkdir -p /tmp/.kiro-mailbox-\${KIRO_SESSION_ID:-unknown}/\`
3. Write JSON to temp file, then \`mv\` to \`/tmp/.kiro-mailbox-\${KIRO_SESSION_ID}/\$(date +%s)-report.json\` (atomic)
4. JSON schema: \`{"type":"report","from":"<session-id>","topic":"<topic>","summary":"<1-3 sentences>","learnings":[],"patterns":[],"action_items":[],"knowledge_paths":[],"persist":[]}\`
5. Run: \`bash ~/scripts/wait-and-inject.sh \$KIRO_PARENT_PANE_ID '<injected prompt>'\`
   - Injected prompt format: \`Child report on "<topic>". Mailbox: /tmp/.kiro-mailbox-<id>/<file>.json. Actions: <count> items. Read and integrate.\`
6. Confirm to user: "Report filed. Tab closing in 5s."
7. Signal completion (tab auto-closes):
   \`\`\`bash
   if command -v krew &>/dev/null && [ -f .agents/krew.db ]; then
     krew signal emit tab_complete --payload '{"pane_id":"terminal_'\$ZELLIJ_PANE_ID'"}'
   else
     sleep 5 && zellij action close-pane --pane-id "terminal_\$ZELLIJ_PANE_ID"
   fi
   \`\`\`
EOF
else
cat > "$BRIEFING" <<EOF
# Sub-Task: ${TASK}

## Session
Session ID: ${CHILD_SESSION_ID}

## Result Path
When done, write your summary/results to: ${RESULT}
Use fs_write to create this file.

## Completion Protocol
When done, write your summary/results to: ${RESULT}
Use fs_write to create this file. This is your FINAL action — the tab will close automatically.

## Task
${TASK}
EOF
fi

if [[ -n "$CONTEXT_FILE" && -f "$CONTEXT_FILE" ]]; then
  if [[ "$INTERACTIVE" -eq 1 || "$TOPIC_TAB" -eq 1 ]]; then
    printf '\n' >> "$BRIEFING"
    cat "$CONTEXT_FILE" >> "$BRIEFING"
  else
    printf '\n## Context\n' >> "$BRIEFING"
    cat "$CONTEXT_FILE" >> "$BRIEFING"
  fi
  printf '\n' >> "$BRIEFING"
fi

# --- Inject CREW-BRIEFING.md from project dir (if set) ---
if [[ -n "${CREW_PROJECT_DIR:-}" ]]; then
  _cb="${CREW_PROJECT_DIR}/CREW-BRIEFING.md"
  if [[ -f "$_cb" ]]; then
    printf '\n## Project Context\n' >> "$BRIEFING"
    cat "$_cb" >> "$BRIEFING"
    printf '\n---\n' >> "$BRIEFING"
  fi
fi

# --- Inline keyword-matched skill content for THROWAWAY agents only ---
# Named agents get context via kiro-cli skill:// progressive loading. No double-load.
if [[ -n "$GENERATED_AGENT" ]]; then
  # Parse matched files from RESOURCES JSON array (skip sub-task-rules)
  while IFS= read -r fpath; do
    [[ -f "$fpath" ]] || continue
    printf '\n## Reference: %s\n' "$(basename "$fpath")" >> "$BRIEFING"
    cat "$fpath" >> "$BRIEFING"
    printf '\n' >> "$BRIEFING"
  done < <(echo "$RESOURCES" | tr -d '[]"' | tr ',' '\n' | sed 's|^file://||')
fi

# --- Inject session marker for conv-linker matching ---
printf '\n<!-- kiro-session:%s -->\n' "$CHILD_SESSION_ID" >> "$BRIEFING"

# --- Write launcher script ---
# Agent-specific default workdirs (when --workdir not provided)
if [[ -z "$WORKDIR" ]]; then
  case "$AGENT_NAME" in
    watchdog) WORKDIR="$HOME/workspaces/watchdog" ;;
  esac
fi
CD_PATH="${WORKDIR:-$(pwd)}"

cat > "$LAUNCHER" <<'ENDSCRIPT'
#!/bin/bash
# --- Safety: launcher never dies from signals or errors ---
set +e
GOT_INT=0
trap 'GOT_INT=1' INT
trap '' HUP

export KIRO_SESSION_ID="PLACEHOLDER_SESSION_ID"
export KIRO_SPAWN_ID="PLACEHOLDER_SPAWN_ID"
export KIRO_PARENT_PANE_ID="PLACEHOLDER_PARENT_PANE_ID"
export KIRO_PARENT_COLOR_IDX="PLACEHOLDER_COLOR_IDX"
export KIRO_SPAWNED_FROM="PLACEHOLDER_PARENT_ID"
[[ -n "PLACEHOLDER_ROLE_WRITE_PATHS" ]] && export ROLE_WRITE_PATHS="PLACEHOLDER_ROLE_WRITE_PATHS"
[[ -n "PLACEHOLDER_CREW_PROJECT_DIR" ]] && export CREW_PROJECT_DIR="PLACEHOLDER_CREW_PROJECT_DIR"
SHORT_TITLE="PLACEHOLDER_TITLE"
WORKER_EMOJI="PLACEHOLDER_WORKER_EMOJI"
RESULT_PATH="PLACEHOLDER_RESULT_PATH"
STDERR_LOG="PLACEHOLDER_STDERR_LOG"
PARENT_PANE_ID="PLACEHOLDER_PARENT_PANE_ID"
PARENT_SESSION_ID="PLACEHOLDER_PARENT_ID"
PARENT_ZELLIJ_SESSION="PLACEHOLDER_PARENT_ZELLIJ_SESSION"
TIMEOUT="${KIRO_SUB_TIMEOUT:-1800}"

cleanup() {
  [[ "PLACEHOLDER_GENERATED" == "1" ]] && rm -f "PLACEHOLDER_AGENT_JSON"
  # Remove session lock if no other kiro-cli-chat processes remain
  local sess="${ZELLIJ_SESSION_NAME:-}"
  if [[ -n "$sess" && -f "/tmp/.zellij-lock/$sess" ]]; then
    local server_pid
    server_pid=$(pgrep -f "zellij.*--session $sess" 2>/dev/null | head -1)
    if [[ -n "$server_pid" ]]; then
      local count
      count=$(pstree -p "$server_pid" 2>/dev/null | grep -oP 'kiro-cli-chat\(\K[0-9]+' | wc -l)
      # 1 = only the restart-loop idle kiro-cli, 0 = none
      [[ "$count" -le 1 ]] && rm -f "/tmp/.zellij-lock/$sess"
    else
      rm -f "/tmp/.zellij-lock/$sess"
    fi
  fi
}
cd "PLACEHOLDER_CD"
printf '\033]0;kiro:%s\007' "$KIRO_SESSION_ID"

# --- Self-discovery: tab vs invisible pane ---
if [[ "PLACEHOLDER_INVISIBLE" == "1" ]]; then
  SELF_ID="terminal_$ZELLIJ_PANE_ID"
  rename_status() { zellij action rename-pane --pane-id "$SELF_ID" "$1" 2>/dev/null || true; }
else
  SELF_ID=$(zellij action current-tab-info --json 2>/dev/null | jq -r '.tab_id' 2>/dev/null || echo "")
  rename_status() { [[ -n "$SELF_ID" ]] && zellij action rename-tab --tab-id "$SELF_ID" "$1" 2>/dev/null || true; }
fi

source ~/scripts/session-log-lib.sh 2>/dev/null || true
session_log_created "$KIRO_SESSION_ID" "PLACEHOLDER_AGENT_ID" "PLACEHOLDER_SPAWN_TYPE" "PLACEHOLDER_TASK_ESC" "$PARENT_SESSION_ID" "$KIRO_SPAWN_ID" "$SHORT_TITLE" "PLACEHOLDER_CD" $$

if [[ "PLACEHOLDER_TOPIC_TAB" == "1" ]]; then
  # Topic (pure or interactive): foreground, no lifecycle coupling, user controls everything
  BEFORE_TS=$(date +%s%3N)
  ( sleep 5; bash ~/infra/bin/conv-linker.sh "$KIRO_SESSION_ID" "$BEFORE_TS" "PLACEHOLDER_CD" "${ZELLIJ_PANE_ID:-}" ) &
  kiro-cli chat --agent PLACEHOLDER_AGENT_ID PLACEHOLDER_TRUST_FLAG --classic "$(cat PLACEHOLDER_BRIEFING)" 2> >(tee "$STDERR_LOG" >&2)
  session_log_exited "$KIRO_SESSION_ID" "closed"
  cleanup
  # Tab stays open — user closes manually or via Ctrl+D
  exec bash
elif [[ "PLACEHOLDER_INTERACTIVE" == "1" ]]; then
  # Interactive (non-topic): foreground, user controls lifecycle
  BEFORE_TS=$(date +%s%3N)
  ( sleep 5; bash ~/infra/bin/conv-linker.sh "$KIRO_SESSION_ID" "$BEFORE_TS" "PLACEHOLDER_CD" "${ZELLIJ_PANE_ID:-}" ) &
  kiro-cli chat --agent PLACEHOLDER_AGENT_ID PLACEHOLDER_TRUST_FLAG --classic "$(cat PLACEHOLDER_BRIEFING)" 2> >(tee "$STDERR_LOG" >&2)
  session_log_exited "$KIRO_SESSION_ID" "closed"
  cleanup
  # Tab stays open — user closes manually or via Ctrl+D
  exec bash
else
  # --- Lifecycle: start ---
  rename_status "${WORKER_EMOJI}🔄 $SHORT_TITLE"

  BEFORE_TS=$(date +%s%3N)
  ( sleep 5; bash ~/infra/bin/conv-linker.sh "$KIRO_SESSION_ID" "$BEFORE_TS" "PLACEHOLDER_CD" "${ZELLIJ_PANE_ID:-}" ) &
  kiro-cli chat --agent PLACEHOLDER_AGENT_ID PLACEHOLDER_TRUST_FLAG --classic \
    "$(cat PLACEHOLDER_BRIEFING)" 2> >(tee "$STDERR_LOG" >&2) &
  KIRO_PID=$!

  # --- Watcher: poll for result file or kiro-cli death ---
  ELAPSED=0
  while kill -0 $KIRO_PID 2>/dev/null; do
    if [[ -f "$RESULT_PATH" ]]; then
      sleep 2
      kill -9 $KIRO_PID 2>/dev/null || true
      break
    fi
    sleep 3
    ELAPSED=$((ELAPSED + 3))
    if [[ $ELAPSED -ge $TIMEOUT ]]; then
      kill -9 $KIRO_PID 2>/dev/null || true
      wait $KIRO_PID 2>/dev/null
      rename_status "${WORKER_EMOJI}⏰ $SHORT_TITLE"
      printf '\a'
      bash ~/infra/bin/pane-inject.sh "$PARENT_PANE_ID" "check $RESULT_PATH (timeout)" ${PARENT_ZELLIJ_SESSION:+--session "$PARENT_ZELLIJ_SESSION"} --safe 2>/dev/null || true
      session_log_exited "$KIRO_SESSION_ID" "timeout"
      cleanup
      sleep 5
      exit 1  # pane/tab closes via --close-on-exit
    fi
  done
  wait $KIRO_PID 2>/dev/null

  # --- Decision: close or stay ---
  if [[ -f "$RESULT_PATH" ]]; then
    # SUCCESS — inject result path directly, no signal file needed
    rename_status "${WORKER_EMOJI}✅ $SHORT_TITLE"
    printf '\a'
    session_log_exited "$KIRO_SESSION_ID" "success"
    cleanup
    bash ~/infra/bin/pane-inject.sh "$PARENT_PANE_ID" "check $RESULT_PATH" ${PARENT_ZELLIJ_SESSION:+--session "$PARENT_ZELLIJ_SESSION"} --safe 2>/dev/null || true
    sleep 2
    exit 0  # pane/tab closes via --close-on-exit
  elif [[ "$GOT_INT" -eq 1 ]]; then
    # USER INTERRUPT (Ctrl+C) — not a crash, no parent notification
    rename_status "${WORKER_EMOJI}⏸ $SHORT_TITLE"
    session_log_exited "$KIRO_SESSION_ID" "interrupted"
    cleanup
    echo "--- ⏸ interrupted by user (Ctrl+C) — not a crash ---"
    echo "Result expected at: $RESULT_PATH"
    if [[ "PLACEHOLDER_INVISIBLE" == "1" ]]; then
      sleep 5
      exit 1  # pane closes via --close-on-exit
    else
      exec bash  # STAY OPEN — user can restart or close
    fi
  else
    # CRASH — best-effort notify
    rename_status "${WORKER_EMOJI}❌ $SHORT_TITLE"
    printf '\a'
    bash ~/infra/bin/pane-inject.sh "$PARENT_PANE_ID" "check $STDERR_LOG (crashed)" ${PARENT_ZELLIJ_SESSION:+--session "$PARENT_ZELLIJ_SESSION"} --safe 2>/dev/null || true
    session_log_exited "$KIRO_SESSION_ID" "crash"
    cleanup
    echo "--- kiro-cli exited without result file ---"
    echo "Stderr log: $STDERR_LOG"
    echo "Expected result: $RESULT_PATH"
    echo "---"
    tail -10 "$STDERR_LOG" 2>/dev/null
    if [[ "PLACEHOLDER_INVISIBLE" == "1" ]]; then
      sleep 5
      exit 1  # pane closes via --close-on-exit
    else
      exec bash  # STAY OPEN — user can inspect crash output
    fi
  fi
fi
ENDSCRIPT

sed -i "s|PLACEHOLDER_CD|${CD_PATH}|" "$LAUNCHER"
sed -i "s|PLACEHOLDER_AGENT_ID|${AGENT_ID}|g" "$LAUNCHER"
sed -i "s|PLACEHOLDER_AGENT_JSON|${AGENT_JSON}|" "$LAUNCHER"
sed -i "s|PLACEHOLDER_BRIEFING|${BRIEFING}|" "$LAUNCHER"
sed -i "s|PLACEHOLDER_GENERATED|${GENERATED_AGENT:-0}|" "$LAUNCHER"
sed -i "s|PLACEHOLDER_SESSION_ID|${CHILD_SESSION_ID}|" "$LAUNCHER"
sed -i "s|PLACEHOLDER_SPAWN_ID|${SPAWN_UUID}|" "$LAUNCHER"
sed -i "s|PLACEHOLDER_PARENT_ID|${PARENT_SESSION_ID}|" "$LAUNCHER"
sed -i "s|PLACEHOLDER_PARENT_PANE_ID|${PARENT_PANE_ID}|g" "$LAUNCHER"
sed -i "s|PLACEHOLDER_PARENT_ZELLIJ_SESSION|${PARENT_ZELLIJ_SESSION}|" "$LAUNCHER"
sed -i "s|PLACEHOLDER_TITLE|${SHORT_TITLE}|" "$LAUNCHER"
sed -i "s|PLACEHOLDER_WORKER_EMOJI|${WORKER_EMOJI}|g" "$LAUNCHER"
sed -i "s|PLACEHOLDER_COLOR_IDX|${COLOR_IDX}|" "$LAUNCHER"

sed -i "s|PLACEHOLDER_RESULT_PATH|${RESULT}|" "$LAUNCHER"
sed -i "s|PLACEHOLDER_STDERR_LOG|${STDERR_LOG}|g" "$LAUNCHER"
sed -i "s|PLACEHOLDER_INTERACTIVE|${INTERACTIVE}|g" "$LAUNCHER"
sed -i "s|PLACEHOLDER_TOPIC_TAB|${TOPIC_TAB}|g" "$LAUNCHER"
SPAWN_TYPE=$( [[ "$TOPIC_TAB" -eq 1 ]] && echo "topic" || echo "spawn" )
sed -i "s|PLACEHOLDER_SPAWN_TYPE|${SPAWN_TYPE}|g" "$LAUNCHER"
TASK_ESC="${TASK//\"/\\\"}"
sed -i "s|PLACEHOLDER_TASK_ESC|${TASK_ESC}|" "$LAUNCHER"
sed -i "s|PLACEHOLDER_TRUST_FLAG|${TRUST_FLAG}|g" "$LAUNCHER"
sed -i "s|PLACEHOLDER_ROLE_WRITE_PATHS|${ROLE_WRITE_PATHS_VAL}|g" "$LAUNCHER"
sed -i "s|PLACEHOLDER_CREW_PROJECT_DIR|${CREW_PROJECT_DIR:-}|g" "$LAUNCHER"
sed -i "s|PLACEHOLDER_INVISIBLE|${HEADLESS}|g" "$LAUNCHER"
chmod +x "$LAUNCHER"

# --- Lock file: prevent reaper from killing session with active sub-tasks ---
if [[ -n "${ZELLIJ_SESSION_NAME:-}" ]]; then
  mkdir -p /tmp/.zellij-lock
  touch "/tmp/.zellij-lock/$ZELLIJ_SESSION_NAME"
fi

# --- Launch ---
if [[ "$HEADLESS" -eq 1 ]]; then
  if [[ -n "${ZELLIJ:-}" ]]; then
    # --- Connected headless: invisible floating pane ---
    _MY_TAB=$(zellij action list-panes --json | jq -r ".[] | select(.id == $ZELLIJ_PANE_ID and .is_plugin == false) | .tab_id")
    SPAWN_PANE=$(zellij action new-pane --floating --near-current-pane --close-on-exit \
      --name "👻 $SHORT_TITLE" -- bash "$LAUNCHER")
    zellij action hide-floating-panes --tab-id "$_MY_TAB" 2>/dev/null || true
    ( sleep 2; session-snapshot.sh ) &>/dev/null & disown

    # --- Log status ---
    printf '{"id":"%s","task":"%s","spawned":"%s","result":"%s","mode":"invisible","pane":"%s"}\n' \
      "$ID" "${TASK//\"/\\\"}" "$(date -Iseconds)" "$RESULT" "$SPAWN_PANE" >> "$STATUS_LOG"

    # --- crew-ctl register ---
    if [[ -f /tmp/crew-session.db && -n "$SPAWN_PANE" ]]; then
      bash ~/infra/bin/crew-ctl register "$SPAWN_PANE" "${AGENT_NAME:-Worker}" \
        --session-id "$CHILD_SESSION_ID" --agent "$AGENT_ID" 2>/dev/null || true
    fi

    echo "Spawned (invisible): $SHORT_TITLE"
    echo "  ID:       $ID"
    echo "  Pane:     $SPAWN_PANE"
    echo "  Mode:     invisible (connected)"
    echo "  Agent:    ${AGENT_ID}${NAMED_AGENT:+ (named)}${GENERATED_AGENT:+ (throwaway)}"
    echo "  Briefing: $BRIEFING"
    echo "  Stderr:   $STDERR_LOG"
    echo "  Result:   $RESULT"
  else
    # --- Disconnected headless: ACP fallback (no zellij) ---
    HEADLESS_PY="/tmp/${ID}-headless.py"
    TIMEOUT="${KIRO_SUB_TIMEOUT:-1800}"

    cat > "$HEADLESS_PY" <<HEADLESS_EOF
import sys, os, time
sys.path.insert(0, os.path.expanduser("~/scripts"))
from acp_client import ACPAgent

agent = ACPAgent(agent="${AGENT_ID}", cwd="${CD_PATH}", timeout=${TIMEOUT})
briefing = open("${BRIEFING}").read()
result = agent.prompt_collect(briefing)
agent.close()

if not os.path.exists("${RESULT}"):
    with open("${RESULT}", "w") as f:
        f.write(result.get("text", ""))
HEADLESS_EOF

    (
      timeout "$TIMEOUT" python3 "$HEADLESS_PY" 2>"$STDERR_LOG"
      EXIT_CODE=$?
      # Cleanup generated agent
      [[ -n "${GENERATED_AGENT:-}" ]] && rm -f "$AGENT_JSON"
      if [[ $EXIT_CODE -eq 0 && -f "$RESULT" ]]; then
        bash ~/infra/bin/pane-inject.sh "$PARENT_PANE_ID" "check $RESULT" ${PARENT_ZELLIJ_SESSION:+--session "$PARENT_ZELLIJ_SESSION"} --safe 2>/dev/null || true
      else
        bash ~/infra/bin/pane-inject.sh "$PARENT_PANE_ID" "check $STDERR_LOG (headless failed)" ${PARENT_ZELLIJ_SESSION:+--session "$PARENT_ZELLIJ_SESSION"} --safe 2>/dev/null || true
      fi
      rm -f "$HEADLESS_PY"
    ) &

    # --- Log status ---
    printf '{"id":"%s","task":"%s","spawned":"%s","result":"%s","mode":"headless"}\n' \
      "$ID" "${TASK//\"/\\\"}" "$(date -Iseconds)" "$RESULT" >> "$STATUS_LOG"

    echo "Spawned (headless): $SHORT_TITLE"
    echo "  ID:       $ID"
    echo "  Mode:     $AUTO_MODE"
    echo "  Agent:    ${AGENT_ID}${NAMED_AGENT:+ (named)}${GENERATED_AGENT:+ (throwaway)}"
    echo "  Briefing: $BRIEFING"
    echo "  Stderr:   $STDERR_LOG"
    echo "  Result:   $RESULT"
  fi

else
  # --- Visible tab launch ---
  _NEW_TAB_ID=""
  if [[ -n "${ZELLIJ:-}" ]]; then
    # Capture current tab position so we can return focus after new-tab steals it
    _ORIG_TAB_POS=$(zellij action current-tab-info --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('position',0))" 2>/dev/null || echo "")
    if [[ "$TOPIC_TAB" -eq 1 ]]; then
      _NEW_TAB_ID=$(zellij action new-tab --name "${CIRCLE} $SHORT_TITLE" -- bash "$LAUNCHER")
    elif [[ "$INTERACTIVE" -eq 1 ]]; then
      _NEW_TAB_ID=$(zellij action new-tab --name "${CIRCLE} $SHORT_TITLE" -- bash "$LAUNCHER")
    else
      _NEW_TAB_ID=$(zellij action new-tab --close-on-exit --name "${WORKER_EMOJI}⏳ $SHORT_TITLE" -- bash "$LAUNCHER")
      # Return focus to the spawning tab (new-tab always steals focus)
      if [[ -n "$_ORIG_TAB_POS" ]]; then
        zellij action go-to-tab $(( _ORIG_TAB_POS + 1 )) 2>/dev/null || true
      fi
    fi
    ( sleep 2; session-snapshot.sh ) &>/dev/null & disown
  elif [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    WIN_TEMP="/mnt/c/Users/MingL/AppData/Local/Temp"
    LAUNCHER_QUEUE="${WIN_TEMP}/.kiro-launchers"
    mkdir -p "$LAUNCHER_QUEUE"
    # Write launcher path keyed by SPAWN_UUID — only the matching tab will consume it
    echo "$LAUNCHER" > "${LAUNCHER_QUEUE}/${SPAWN_UUID}"
    echo "" > "${LAUNCHER_QUEUE}/${SPAWN_UUID}.dispatch"
    # Trigger dispatch plugin
    echo "${PARENT_WINDOW_ID:-}" > "${WIN_TEMP}/.kiro-spawn-${SPAWN_UUID}"
  elif [[ "$(uname)" == "Darwin" ]]; then
    osascript -e "tell application \"Terminal\" to do script \"bash -l '$LAUNCHER'\"" &
  else
    echo "Unsupported environment. Run: bash $LAUNCHER"
    exit 1
  fi

  # --- Log status ---
  if [[ "$TOPIC_TAB" -eq 1 ]]; then
    printf '{"id":"%s","task":"%s","spawned":"%s","type":"topic","spawned_from":"%s"}\n' \
      "$ID" "${TASK//\"/\\\"}" "$(date -Iseconds)" "$PARENT_SESSION_ID" >> "$STATUS_LOG"
  else
    printf '{"id":"%s","task":"%s","spawned":"%s","result":"%s"}\n' \
      "$ID" "${TASK//\"/\\\"}" "$(date -Iseconds)" "$RESULT" >> "$STATUS_LOG"
  fi

  # --- crew-ctl register (if daemon DB exists) ---
  if [[ -f /tmp/crew-session.db ]]; then
    # Discover pane_id from the new tab's ID (avoids relying on focus)
    _new_pane_id=""
    if [[ -n "$_NEW_TAB_ID" ]]; then
      _new_pane_id=$(zellij action list-panes --json --all 2>/dev/null \
        | python3 -c "import sys,json
ps=[p for p in json.load(sys.stdin) if not p.get('is_plugin') and p.get('tab_id')==${_NEW_TAB_ID}]
print(f\"terminal_{ps[0]['id']}\" if ps else '')" 2>/dev/null || true)
    fi
    if [[ -n "$_new_pane_id" ]]; then
      bash ~/infra/bin/crew-ctl register "$_new_pane_id" "${AGENT_NAME:-Worker}" \
        --session-id "$CHILD_SESSION_ID" --agent "$AGENT_ID" 2>/dev/null || true
    fi
  fi

  # --- kiro-sessiond register (if daemon running) ---
  _KS_PORT_FILE="/tmp/kiro-sessiond-${ZELLIJ_SESSION_NAME:-default}.port"
  if [[ -f "$_KS_PORT_FILE" && -n "$_new_pane_id" ]]; then
    _KS_PORT=$(jq -r .port "$_KS_PORT_FILE")
    _KS_TOKEN=$(jq -r .token "$_KS_PORT_FILE")
    curl -s -X POST -H "Authorization: Bearer $_KS_TOKEN" -H "Content-Type: application/json" \
      "localhost:$_KS_PORT/v1/agents/register" \
      -d "{\"pane_id\":\"$_new_pane_id\",\"role\":\"${SHORT_TITLE:-worker}\",\"agent\":\"${AGENT_ID}\",\"parent_pane_id\":\"${KIRO_PARENT_PANE_ID:-}\"}" \
      --max-time 2 &>/dev/null &
  fi

  echo "Spawned: $SHORT_TITLE"
  echo "  ID:       $ID"
  echo "  Session:  $CHILD_SESSION_ID"
  echo "  Spawn:    $SPAWN_UUID"
  echo "  Mode:     $AUTO_MODE"
  echo "  Agent:    ${AGENT_ID}${NAMED_AGENT:+ (named)}${GENERATED_AGENT:+ (throwaway)}"
  echo "  Resources: $(echo "$RESOURCES" | python3 -c "import sys,json; [print('    ' + r.replace('file://','')) for r in json.load(sys.stdin)]" 2>/dev/null)"
  echo "  Briefing: $BRIEFING"
  echo "  Stderr:   $STDERR_LOG"
  echo "  Result:   $RESULT"
fi
