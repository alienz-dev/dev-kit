#!/usr/bin/env python3
"""crew-sessiond.py — Crew session daemon: registry, message queue, dispatch,
state monitoring, hang detection, tab replacement, LLM verdict system,
LLM merge proxy, DLQ, reminders, observability.

Phases 1-4 of plan-crew-queue.md.
"""
import argparse
import glob
import hashlib
import json
import logging
import os
import re
import signal
import sqlite3
import subprocess
import sys
import threading
import shutil
import time
import uuid
from logging.handlers import RotatingFileHandler
from pathlib import Path

# Ensure ~/.local/bin is in PATH (zellij, kiro-cli live there)
_local_bin = str(Path.home() / ".local" / "bin")
if _local_bin not in os.environ.get("PATH", ""):
    os.environ["PATH"] = _local_bin + ":" + os.environ.get("PATH", "")

_CREW_DATA = Path(os.environ.get("CREW_DATA_DIR", os.path.expanduser("~/.local/share/crew")))
_CREW_CONFIG = Path(os.environ.get("CREW_CONFIG_DIR", os.path.expanduser("~/.config/crew")))
_CREW_DATA.mkdir(parents=True, exist_ok=True)
_CREW_CONFIG.mkdir(parents=True, exist_ok=True)

DB_PATH = _CREW_DATA / "crew-session.db"
PID_FILE = Path("/tmp/crew-sessiond.pid")
DAEMON_CONFIG = _CREW_CONFIG / "daemon.json"
LOG_PATH = _CREW_DATA / "crew-sessiond.log"
CHECKLIST_DIR = _CREW_CONFIG / "checklists"
SESSION_LOG_DB = Path.home() / ".local/share/kiro-cli/session-log.db"
KIRO_DATA_DB = Path.home() / ".local/share/kiro-cli/data.sqlite3"
PROMPT_RE = re.compile(r"\[(\w[\w-]*)\]\s+(\d+)%\s+[!>]+")
THINKING_RE = re.compile(r"Thinking\.\.\.", re.IGNORECASE)
ERROR_RE = re.compile(r"error|failed|traceback|exception", re.IGNORECASE)

# ── Health signal detection (service degradation) ──────────────────────
HEALTH_HARD_LIMIT_RE = re.compile(
    r"daily usage limit|return tomorrow to continue|monthly.*limit.*reached",
    re.IGNORECASE)
HEALTH_THROTTLE_RE = re.compile(
    r"Too many requests.*wait|please wait before trying again|SlowDown",
    re.IGNORECASE)
HEALTH_MODEL_DOWN_RE = re.compile(
    r"model is currently unavailable|model.*temporarily unavailable|select another model",
    re.IGNORECASE)
HEALTH_AUTH_FAIL_RE = re.compile(
    r"not logged in|session expired|please.*log ?in|denied access to Kiro|token.*expired",
    re.IGNORECASE)
HEALTH_SERVICE_DOWN_RE = re.compile(
    r"service.*unavailable|InternalServerError|temporarily suspended",
    re.IGNORECASE)
HEALTH_TRANSIENT_RE = re.compile(
    r"An unexpected error occurred|dispatch failure",
    re.IGNORECASE)
PAUSE_SIGNAL = "/tmp/.crew-paused"
_transient_counts = {}  # pane_id -> [(timestamp, ...)]
DISPATCH_INTERVAL = 5
REGISTRY_SCAN_INTERVAL = 60
MONITOR_INTERVAL = 30
SNAPSHOT_INTERVAL = 300  # 5 min
PROTECTED_ROLES = {"Manager", "Planner"}
MERGE_ORIGINALS_DIR = _CREW_DATA / "merge-originals"
REFUSAL_PHRASES = ("i cannot", "i'm sorry", "i can't", "i am unable")
LLM_MERGE_THRESHOLD = 4  # 4+ msgs or mixed priorities → LLM merge
DLQ_NO_TARGET_TIMEOUT = 600  # 10 min
DLQ_NOTIFY_INTERVAL = 900  # 15 min
REMINDER_COOLDOWN = 900  # 15 min per pane
ESCALATION_P1_TO_P0 = 600  # 10 min
ALERT_P0_FILE = 5 * 60  # 5 min → write alert file
ALERT_P0_INJECT = 15 * 60  # 15 min → inject into legacy tab

HUMAN_IN_THE_LOOP = True  # When True, destructive actions require user approval via toast

logger = logging.getLogger("crew-sessiond")
_shutdown = False


def notify_user(title, message, urgent=False):
    """Send Windows toast notification via powershell.exe."""
    try:
        escaped = message.replace("'", "''").replace('"', '\\"')[:200]
        ps = f"""
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null
$t = '<toast><visual><binding template="ToastText02"><text id="1">{title}</text><text id="2">{escaped}</text></binding></visual><audio silent="{'false' if urgent else 'true'}"/></toast>'
$x = New-Object Windows.Data.Xml.Dom.XmlDocument; $x.LoadXml($t)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('crew-sessiond').Show([Windows.UI.Notifications.ToastNotification]::new($x))
"""
        subprocess.run(["powershell.exe", "-Command", ps],
                       capture_output=True, timeout=10)
        logger.info("NOTIFY: [%s] %s", title, escaped)
    except Exception:
        logger.exception("NOTIFY: toast failed")


def request_human_approval(action_desc, pane_id, role):
    """Notify user of pending destructive action. Returns False (action blocked).
    In HUMAN_IN_THE_LOOP mode, destructive actions are blocked and user is notified.
    User must run `crew-ctl approve <action>` or take manual action."""
    if not HUMAN_IN_THE_LOOP:
        return True  # auto mode — proceed
    notify_user("🚨 Crew Action Needed", f"{action_desc} — {role} ({pane_id})", urgent=True)
    logger.warning("HUMAN_GATE: blocked [%s] for %s (%s) — waiting for manual action", action_desc, role, pane_id)
    return False  # blocked — caller must skip the action

# Phase 2 state: per-pane tracking for hang detection + verdicts
_hang_levels = {}       # pane_id → highest level attempted (1-4)
_last_ctrlc = {}        # pane_id → unix timestamp of last Ctrl+C
_last_verdict = {}      # pane_id → unix timestamp of last verdict
_last_action = {}       # pane_id → unix timestamp of last verdict action
_prev_status = {}       # pane_id → previous status for transition detection
_idle_since = {}        # pane_id → unix timestamp when idle transition detected
_replacement_count = {} # role → [(timestamp, ...)] for rate limiting
_verdict_shadow = True  # start in shadow mode
_verdict_total = 0
_verdict_concordant = 0
_last_reminder = {}     # pane_id → unix timestamp of last reminder
_last_dlq_notify = 0    # unix timestamp of last DLQ notification
_last_dlq_count = 0     # last known DLQ count — only notify on increase


def setup_logging():
    handler = RotatingFileHandler(str(LOG_PATH), maxBytes=10 * 1024 * 1024, backupCount=2)
    handler.setFormatter(logging.Formatter("[%(asctime)s] [%(levelname)s] [%(name)s] %(message)s",
                                           datefmt="%Y-%m-%dT%H:%M:%S%z"))
    logger.addHandler(handler)
    logger.addHandler(logging.StreamHandler())
    logger.setLevel(logging.INFO)


# ── Schema ──────────────────────────────────────────────────────────────────

SCHEMA = """
PRAGMA journal_mode=WAL;
PRAGMA busy_timeout=5000;

CREATE TABLE IF NOT EXISTS registry (
    pane_id TEXT PRIMARY KEY,
    session_id TEXT,
    conversation_id TEXT,
    tab_name TEXT,
    agent TEXT,
    role TEXT,
    model TEXT,
    workdir TEXT,
    pid INTEGER,
    pane_command TEXT,
    status TEXT DEFAULT 'unknown',
    context_tokens INTEGER DEFAULT 0,
    context_window INTEGER DEFAULT 0,
    context_pct REAL DEFAULT 0,
    history_turns INTEGER DEFAULT 0,
    tasks_completed INTEGER DEFAULT 0,
    screen_hash TEXT,
    consecutive_same_hash INTEGER DEFAULT 0,
    last_screen_change INTEGER,
    last_activity INTEGER,
    registered_at INTEGER,
    updated_at INTEGER,
    title_color_idx INTEGER,
    title_set INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY,
    target_role TEXT NOT NULL,
    target_pane TEXT,
    sender TEXT,
    priority INTEGER DEFAULT 1,
    payload TEXT NOT NULL,
    content_hash TEXT,
    status TEXT DEFAULT 'pending',
    created_at INTEGER,
    delivered_at INTEGER,
    merge_batch_id TEXT,
    retry_count INTEGER DEFAULT 0,
    error TEXT
);

CREATE TABLE IF NOT EXISTS dead_letters (
    id INTEGER PRIMARY KEY,
    original_msg_id INTEGER,
    reason TEXT,
    payload TEXT,
    target_role TEXT,
    created_at INTEGER
);

CREATE TABLE IF NOT EXISTS state_snapshots (
    id INTEGER PRIMARY KEY,
    snapshot_json TEXT,
    created_at INTEGER
);

CREATE TABLE IF NOT EXISTS replacement_log (
    id INTEGER PRIMARY KEY,
    old_pane_id TEXT,
    old_session_id TEXT,
    old_conversation_id TEXT,
    new_pane_id TEXT,
    new_session_id TEXT,
    reason TEXT,
    archive_path TEXT,
    briefing_path TEXT,
    created_at INTEGER
);

CREATE TABLE IF NOT EXISTS verdicts (
    id INTEGER PRIMARY KEY,
    pane_id TEXT NOT NULL,
    role TEXT,
    status_before TEXT,
    status_after TEXT,
    screen_tail TEXT,
    verdict_raw TEXT,
    action_taken TEXT,
    confidence TEXT,
    llm_used INTEGER DEFAULT 1,
    latency_ms INTEGER,
    created_at INTEGER
);

CREATE TABLE IF NOT EXISTS decision_patterns (
    id INTEGER PRIMARY KEY,
    signal_type TEXT NOT NULL,
    role_category TEXT NOT NULL,
    screen_signature TEXT NOT NULL,
    resolution TEXT NOT NULL,
    occurrences INTEGER DEFAULT 1,
    user_approved INTEGER DEFAULT 0,
    user_rejected INTEGER DEFAULT 0,
    auto_approved INTEGER DEFAULT 0,
    graduated_at INTEGER,
    last_seen INTEGER,
    created_at INTEGER
);

CREATE TABLE IF NOT EXISTS signals (
    id TEXT PRIMARY KEY,
    signal_type TEXT NOT NULL,
    severity TEXT NOT NULL,
    pane_id TEXT,
    role TEXT,
    role_category TEXT,
    evidence_json TEXT,
    proposed_action TEXT,
    alternatives_json TEXT,
    pattern_id INTEGER,
    status TEXT DEFAULT 'pending',
    decided_action TEXT,
    decided_by TEXT,
    decided_at INTEGER,
    auto_approve_at INTEGER,
    created_at INTEGER
);

CREATE TABLE IF NOT EXISTS resolutions (
    id INTEGER PRIMARY KEY,
    signal_id TEXT NOT NULL,
    signal_type TEXT,
    role TEXT,
    action_taken TEXT,
    decided_by TEXT,
    pattern_id INTEGER,
    latency_sec INTEGER,
    outcome TEXT DEFAULT 'unknown',
    created_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_messages_status ON messages(status, priority, created_at);
CREATE INDEX IF NOT EXISTS idx_messages_target ON messages(target_role, status);
CREATE INDEX IF NOT EXISTS idx_registry_role ON registry(role);
CREATE INDEX IF NOT EXISTS idx_verdicts_pane ON verdicts(pane_id, created_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_patterns_key ON decision_patterns(signal_type, role_category, screen_signature, resolution);
CREATE INDEX IF NOT EXISTS idx_signals_status ON signals(status, created_at);
CREATE INDEX IF NOT EXISTS idx_resolutions_signal ON resolutions(signal_id);

CREATE TABLE IF NOT EXISTS autoscale_log (
    id INTEGER PRIMARY KEY,
    role TEXT NOT NULL,
    reason TEXT NOT NULL,
    created_at INTEGER NOT NULL
);
"""


def init_db():
    """Create DB and apply schema."""
    conn = sqlite3.connect(str(DB_PATH))
    conn.executescript(SCHEMA)
    # Safe migration for existing DBs — ALTER TABLE is idempotent with try/except
    for col, defn in [
        ("session_id", "TEXT"),
        ("conversation_id", "TEXT"),
        ("tab_name", "TEXT"),
        ("agent", "TEXT"),
        ("model", "TEXT"),
        ("workdir", "TEXT"),
        ("pid", "INTEGER"),
        ("pane_command", "TEXT"),
        ("status", "TEXT DEFAULT 'unknown'"),
        ("context_tokens", "INTEGER DEFAULT 0"),
        ("context_window", "INTEGER DEFAULT 0"),
        ("context_pct", "REAL DEFAULT 0"),
        ("history_turns", "INTEGER DEFAULT 0"),
        ("tasks_completed", "INTEGER DEFAULT 0"),
        ("screen_hash", "TEXT"),
        ("consecutive_same_hash", "INTEGER DEFAULT 0"),
        ("last_screen_change", "INTEGER"),
        ("last_activity", "INTEGER"),
        ("registered_at", "INTEGER"),
        ("updated_at", "INTEGER"),
        ("title_color_idx", "INTEGER"),
        ("title_set", "INTEGER DEFAULT 0"),
        ("waiting_on", "TEXT"),
        ("working_for", "TEXT"),
        ("consecutive_idle_checks", "INTEGER DEFAULT 0"),
        ("kiro_chat_pid", "INTEGER"),
    ]:
        try:
            conn.execute(f"ALTER TABLE registry ADD COLUMN {col} {defn}")
        except sqlite3.OperationalError:
            pass  # column already exists
    # ETA monitoring columns on messages table
    for col, defn in [("eta_seconds", "INTEGER"), ("dispatched_at", "INTEGER")]:
        try:
            conn.execute(f"ALTER TABLE messages ADD COLUMN {col} {defn}")
        except sqlite3.OperationalError:
            pass  # column already exists
    # Planner idle elimination state table
    conn.execute("""CREATE TABLE IF NOT EXISTS planner_idle_state (
        id INTEGER PRIMARY KEY,
        last_dispatch_at INTEGER,
        last_nudge_at INTEGER,
        last_nudge_tier TEXT,
        nudged_result_paths TEXT DEFAULT '[]',
        waves_since_knowledge_update INTEGER DEFAULT 0,
        current_wave_name TEXT,
        next_wave_name TEXT,
        expected_result_path TEXT
    )""")
    # Ensure exactly one state row exists
    if conn.execute("SELECT COUNT(*) FROM planner_idle_state").fetchone()[0] == 0:
        conn.execute("INSERT INTO planner_idle_state (nudged_result_paths) VALUES ('[]')")
    conn.commit()
    conn.close()
    logger.info("DB initialized at %s", DB_PATH)


def get_db():
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=5000")
    return conn


def check_schema():
    """Validate all expected tables exist."""
    conn = get_db()
    tables = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()}
    conn.close()
    expected = {"registry", "messages", "dead_letters", "state_snapshots", "replacement_log", "verdicts",
                "decision_patterns", "signals", "resolutions", "planner_idle_state", "autoscale_log"}
    missing = expected - tables
    if missing:
        print(f"FAIL: missing tables: {missing}", file=sys.stderr)
        return False
    print("OK: all tables present")
    return True


# ── Zellij helpers ──────────────────────────────────────────────────────────

def _get_session():
    """Get target zellij session from config or environment."""
    try:
        if DAEMON_CONFIG.exists():
            s = json.loads(DAEMON_CONFIG.read_text()).get("session")
            if s:
                return s
    except (json.JSONDecodeError, OSError):
        pass
    return os.environ.get("ZELLIJ_SESSION_NAME")


def zellij_cmd(*args, session=None):
    """Run a zellij action, return stdout or None on error."""
    cmd = ["zellij"]
    s = session or _get_session()
    if s:
        cmd += ["--session", s]
    cmd += ["action"] + list(args)
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        return r.stdout if r.returncode == 0 else None
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None


def list_all_panes():
    """Get all non-plugin panes from configured session."""
    panes = []
    try:
        cmd = ["zellij"]
        s = _get_session()
        if s:
            cmd += ["--session", s]
        cmd += ["action", "list-panes", "--json", "--all"]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        if r.returncode == 0 and r.stdout.strip():
            raw = json.loads(r.stdout)
            for p in raw:
                if not p.get("is_plugin", True):
                    panes.append(p)
    except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError):
        pass
    return panes


def dump_screen(pane_id, lines=5):
    """Dump last N lines from a pane. Focus-safe."""
    out = zellij_cmd("dump-screen", "--pane-id", pane_id)
    if not out:
        return ""
    all_lines = out.rstrip("\n").split("\n")
    return "\n".join(all_lines[-lines:]) if all_lines else ""


def is_idle(pane_id):
    """Check if pane shows a kiro-cli prompt in last 5 lines."""
    screen = dump_screen(pane_id, 5)
    return bool(PROMPT_RE.search(screen))


def prompt_line_clean(pane_id):
    """Check prompt visible AND no user-typed text after the prompt marker."""
    screen = dump_screen(pane_id, 5)
    if not PROMPT_RE.search(screen):
        return False
    # Find last non-empty line containing the prompt marker.
    # kiro-cli may append helper text after the prompt (e.g. "Use /help",
    # "What should we work on?"), so we match the prompt pattern anywhere
    # in the line rather than requiring [!>] at end-of-line.
    for line in reversed(screen.split("\n")):
        stripped = line.strip()
        if stripped:
            return bool(PROMPT_RE.search(stripped))
    return False


def parse_prompt(pane_id):
    """Extract agent name and context % from prompt."""
    screen = dump_screen(pane_id, 5)
    m = PROMPT_RE.search(screen)
    if m:
        return m.group(1), int(m.group(2))
    return None, None


def paste_to_pane(pane_id, text):
    """Inject text via bracketed paste + send-keys Enter. Returns True on success."""
    s = _get_session()
    base = ["zellij"] + (["--session", s] if s else [])
    try:
        r = subprocess.run(
            base + ["action", "paste", "--pane-id", pane_id, text],
            capture_output=True, text=True, timeout=10,
        )
        if r.returncode != 0:
            return False
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False
    time.sleep(0.2)
    try:
        subprocess.run(
            base + ["action", "send-keys", "--pane-id", pane_id, "Enter"],
            capture_output=True, text=True, timeout=5,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False
    return True


def confirm_delivery(pane_id, timeout=8):
    """Poll screen to confirm agent started processing after paste.

    Returns True if the agent is no longer showing an idle prompt (i.e., it
    picked up the message and started working). Returns False if the prompt
    is still clean after timeout — message may have been swallowed.
    """
    import hashlib
    before = dump_screen(pane_id, 5)
    before_hash = hashlib.md5((before or "").encode()).hexdigest()
    for _ in range(timeout // 2):
        time.sleep(2)
        after = dump_screen(pane_id, 5)
        after_hash = hashlib.md5((after or "").encode()).hexdigest()
        # Screen changed = agent is processing
        if after_hash != before_hash:
            return True
        # Prompt gone = agent picked it up
        if not PROMPT_RE.search(after or ""):
            return True
    return False


# ── /proc helpers ───────────────────────────────────────────────────────────

def read_proc_environ(pid):
    """Read environment variables from /proc/<pid>/environ."""
    try:
        data = Path(f"/proc/{pid}/environ").read_bytes()
        env = {}
        for entry in data.split(b"\x00"):
            if b"=" in entry:
                k, v = entry.split(b"=", 1)
                env[k.decode(errors="replace")] = v.decode(errors="replace")
        return env
    except (OSError, PermissionError):
        return {}


def find_kiro_pid_for_pane(pane_pid):
    """Walk child processes to find kiro-cli-chat PID.
    Legacy wrapper — prefer resolve_kiro_chat_pid() for correct thread-safe resolution."""
    try:
        r = subprocess.run(
            ["pstree", "-p", str(pane_pid)],
            capture_output=True, text=True, timeout=5,
        )
        # Match real processes only (not threads in {braces})
        for m in re.finditer(r"kiro-cli-chat\((\d+)\)", r.stdout):
            return int(m.group(1))
        # Fallback: any kiro process (not thread)
        for m in re.finditer(r"(\w[\w-]*)\((\d+)\)", r.stdout):
            name, pid = m.group(1), int(m.group(2))
            if "kiro" in name.lower():
                return pid
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return None


def resolve_kiro_chat_pid(pane_id, zellij_pane_json):
    """Resolve pane → kiro-cli-chat PID via launcher process tree.
    Returns the PID of kiro-cli-chat (the process that spawns tool children),
    not a kiro-cli thread PID."""
    term_cmd = zellij_pane_json.get("terminal_command", "") or ""

    # Strategy 1: launcher-based (kiro-sub spawned tabs)
    m = re.search(r"(kiro-sub-\d+-launch\.sh)", term_cmd)
    if m:
        try:
            r = subprocess.run(["pgrep", "-f", m.group(1)],
                capture_output=True, text=True, timeout=2)
            if r.returncode == 0 and r.stdout.strip():
                launcher_pid = r.stdout.strip().split("\n")[0]
                tree = subprocess.run(
                    ["pstree", "-p", launcher_pid],
                    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                    text=True, timeout=2,
                ).stdout
                for pm in re.finditer(r"kiro-cli-chat\((\d+)\)", tree):
                    return int(pm.group(1))
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    # Strategy 2: main pane (no launcher)
    pane_cmd = zellij_pane_json.get("pane_command", "") or ""
    if "kiro-cli" in pane_cmd and not m:
        agent_m = re.search(r"--agent\s+(\S+)", pane_cmd)
        if agent_m:
            try:
                r = subprocess.run(
                    ["pgrep", "-f", f"kiro-cli chat.*--agent {agent_m.group(1)}"],
                    capture_output=True, text=True, timeout=2)
                if r.returncode == 0 and r.stdout.strip():
                    wrapper_pid = r.stdout.strip().split("\n")[0]
                    tree = subprocess.run(
                        ["pstree", "-p", wrapper_pid],
                        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                        text=True, timeout=2,
                    ).stdout
                    for pm in re.finditer(r"kiro-cli-chat\((\d+)\)", tree):
                        return int(pm.group(1))
            except (subprocess.TimeoutExpired, FileNotFoundError):
                pass

    # Strategy 3: fallback via pane PID from registry
    pane_pid = zellij_pane_json.get("pid")
    if pane_pid:
        try:
            tree = subprocess.run(
                ["pstree", "-p", str(pane_pid)],
                capture_output=True, text=True, timeout=2,
                stderr=subprocess.DEVNULL,
            ).stdout
            for pm in re.finditer(r"kiro-cli-chat\((\d+)\)", tree):
                return int(pm.group(1))
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    return None


def has_tool_children(kiro_chat_pid):
    """Check if kiro-cli-chat has any child processes (= tool executing)."""
    if not kiro_chat_pid:
        return False
    try:
        r = subprocess.run(["pgrep", "-P", str(kiro_chat_pid)],
            capture_output=True, timeout=2)
        return r.returncode == 0 and bool(r.stdout.strip())
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def get_child_processes_with_age(kiro_chat_pid):
    """Get child processes of kiro-cli-chat with their elapsed time and command."""
    if not kiro_chat_pid:
        return []
    try:
        r = subprocess.run(
            ["ps", "--ppid", str(kiro_chat_pid), "-o", "pid=,etimes=,comm=", "--no-headers"],
            capture_output=True, text=True, timeout=5
        )
        if r.returncode != 0:
            return []
        children = []
        for line in r.stdout.strip().split('\n'):
            if not line.strip():
                continue
            parts = line.split(None, 2)
            if len(parts) >= 2:
                pid = int(parts[0])
                elapsed = int(parts[1])
                cmd = parts[2] if len(parts) > 2 else ""
                children.append((pid, elapsed, cmd))
        return children
    except (subprocess.TimeoutExpired, FileNotFoundError, ValueError):
        return []


def get_cpu_time(pid):
    """Get total CPU time (user + system) in clock ticks from /proc/pid/stat."""
    try:
        with open(f"/proc/{pid}/stat") as f:
            fields = f.read().split()
            return int(fields[13]) + int(fields[14])
    except (FileNotFoundError, IndexError, ValueError):
        return -1


# Tool timeout thresholds (seconds)
TOOL_TIMEOUT_DEFAULT = 300      # 5 min
TOOL_TIMEOUT_NETWORK = 120      # 2 min for curl/wget
TOOL_TIMEOUT_DANGEROUS = 30     # 30s for known stdin-blockers
TOOL_TIMEOUT_BUILD = 600        # 10 min for builds


def tool_timeout_for_command(cmd):
    """Return appropriate timeout threshold based on command pattern."""
    cmd_lower = cmd.lower()
    if any(p in cmd_lower for p in ['cat', 'read', 'head', 'tail']):
        return TOOL_TIMEOUT_DANGEROUS
    if any(p in cmd_lower for p in ['curl', 'wget', 'ssh']):
        return TOOL_TIMEOUT_NETWORK
    if any(p in cmd_lower for p in ['npm', 'npx', 'mvn', 'cargo', 'make', 'gradle']):
        return TOOL_TIMEOUT_BUILD
    return TOOL_TIMEOUT_DEFAULT


# Track CPU snapshots for verification: {child_pid: [cpu_time1, cpu_time2, cpu_time3]}
_tool_cpu_snapshots = {}


def verify_child_stuck(child_pid):
    """
    Check if a child process is truly stuck by tracking CPU time across ticks.
    Returns True if 3 consecutive snapshots show 0 CPU delta.
    """
    cpu = get_cpu_time(child_pid)
    if cpu < 0:
        _tool_cpu_snapshots.pop(child_pid, None)
        return False

    snapshots = _tool_cpu_snapshots.setdefault(child_pid, [])
    snapshots.append(cpu)

    if len(snapshots) > 3:
        snapshots[:] = snapshots[-3:]

    if len(snapshots) < 3:
        return False

    return snapshots[0] == snapshots[1] == snapshots[2]


# ── Session log DB helpers ──────────────────────────────────────────────────

def query_session_log(session_id):
    """Look up agent/task info from session-log.db."""
    if not SESSION_LOG_DB.exists():
        return {}
    try:
        conn = sqlite3.connect(str(SESSION_LOG_DB))
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            "SELECT * FROM sessions WHERE session_id = ? ORDER BY started_at DESC LIMIT 1",
            (session_id,),
        ).fetchone()
        conn.close()
        if row:
            return dict(row)
    except sqlite3.Error:
        pass
    return {}


# ── data.sqlite3 reader (Task 2.1/2.2) ─────────────────────────────────────

def read_kiro_conversation(conversation_id):
    """Read conversation data from data.sqlite3 (READ-ONLY). Returns dict or None."""
    if not KIRO_DATA_DB.exists():
        return None
    try:
        uri = f"file:{KIRO_DATA_DB}?mode=ro"
        conn = sqlite3.connect(uri, uri=True, timeout=5)
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            "SELECT value, updated_at FROM conversations_v2 WHERE conversation_id = ? ORDER BY updated_at DESC LIMIT 1",
            (conversation_id,),
        ).fetchone()
        conn.close()
        if row:
            return json.loads(row["value"])
    except (sqlite3.Error, json.JSONDecodeError) as e:
        logger.warning("MONITOR: failed reading data.sqlite3 for %s: %s", conversation_id, e)
    return None


def find_conversation_id_for_session(session_id, registered_at):
    """Match session_id to conversation_id via timing (Task 2.2)."""
    if not KIRO_DATA_DB.exists() or not session_id:
        return None
    try:
        uri = f"file:{KIRO_DATA_DB}?mode=ro"
        conn = sqlite3.connect(uri, uri=True, timeout=5)
        conn.row_factory = sqlite3.Row
        # registered_at is unix seconds, data.sqlite3 uses milliseconds
        ts_ms = registered_at * 1000 if registered_at else 0
        window = 60000  # 60s window
        rows = conn.execute(
            "SELECT conversation_id, value, created_at FROM conversations_v2 WHERE created_at BETWEEN ? AND ? ORDER BY created_at DESC",
            (ts_ms - window, ts_ms + window),
        ).fetchall()
        conn.close()
        for row in rows:
            return row["conversation_id"]
    except sqlite3.Error as e:
        logger.warning("MONITOR: conversation lookup failed: %s", e)
    return None


def get_context_from_data_db(conversation_id):
    """Get context_message_length, context_window_tokens, history_turns from data.sqlite3."""
    data = read_kiro_conversation(conversation_id)
    if not data:
        return None, None, None
    ctx_len = data.get("context_message_length", 0)
    model_info = data.get("model_info", {})
    ctx_window = model_info.get("context_window_tokens", 0)
    history = data.get("history", [])
    return ctx_len, ctx_window, len(history)


# ── Signal System ──────────────────────────────────────────────────────────

SIGNAL_DIR = _CREW_DATA / "signals"
CONFIG_PATH = _CREW_CONFIG / "coordinator.json"
_NORM_PATTERNS = [
    (re.compile(r"\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}[:\d.+Z-]*"), "<TS>"),
    (re.compile(r"terminal_\d+"), "<PANE>"),
    (re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", re.I), "<SID>"),
    (re.compile(r"(/tmp/|/home/)\S+"), "<PATH>"),
    (re.compile(r"\d+(\.\d+)?%"), "<PCT>"),
]


def _load_config():
    """Load coordinator config, return defaults if missing."""
    defaults = {"graduation_enabled": False, "overnight_mode": False,
                "overnight_start_hour": 23, "overnight_end_hour": 7,
                "overnight_auto_approve_delay": 120, "coordinator_replace_pct": 80}
    try:
        if CONFIG_PATH.exists():
            cfg = json.loads(CONFIG_PATH.read_text())
            defaults.update(cfg)
    except (json.JSONDecodeError, OSError):
        pass
    # Pool autoscale defaults (overridable via coordinator.json "pool" key)
    pool_cfg = defaults.get("pool", {})
    pool_cfg.setdefault("min_workers", 2)
    pool_cfg.setdefault("max_workers", 20)
    pool_cfg.setdefault("proactive_replace_pct", 75)
    pool_cfg.setdefault("spawn_cooldown_sec", 120)
    pool_cfg.setdefault("max_spawn_batch", 2)
    defaults["pool"] = pool_cfg
    return defaults


def _save_config(cfg):
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    CONFIG_PATH.write_text(json.dumps(cfg, indent=2) + "\n")


def is_overnight():
    """Check if overnight mode is active (explicit toggle or time-based)."""
    cfg = _load_config()
    if "overnight_mode" in cfg:
        return cfg["overnight_mode"]
    # Auto-detect from time
    hour = time.localtime().tm_hour
    start = cfg.get("overnight_start_hour", 23)
    end = cfg.get("overnight_end_hour", 7)
    if start > end:  # wraps midnight
        return hour >= start or hour < end
    return start <= hour < end


def _role_category(role):
    if not role:
        return "worker"
    r = role.strip().lower()
    if r in ("manager",):
        return "manager"
    if r in ("planner",):
        return "planner"
    if r in ("coordinator",):
        return "coordinator"
    return "worker"


def normalize_screen(text):
    """Strip variable parts from screen text for stable hashing."""
    out = text
    for pat, repl in _NORM_PATTERNS:
        out = pat.sub(repl, out)
    return out.strip()


def compute_screen_signature(signal_type, role_cat, screen_text):
    normalized = normalize_screen(screen_text)
    raw = f"{signal_type}:{role_cat}:{normalized}"
    return hashlib.sha256(raw.encode()).hexdigest()[:16]


def check_pattern_match(db, signal_type, role_cat, screen_text):
    """Return graduated pattern row if match found, else None."""
    cfg = _load_config()
    if not cfg.get("graduation_enabled", False):
        return None
    sig = compute_screen_signature(signal_type, role_cat, screen_text)
    now = int(time.time())
    cutoff = now - 14 * 86400
    row = db.execute(
        "SELECT * FROM decision_patterns WHERE signal_type=? AND role_category=? AND screen_signature=? AND auto_approved=1 AND last_seen>?",
        (signal_type, role_cat, sig, cutoff),
    ).fetchone()
    return row


def emit_signal(db, signal_type, severity, pane_id, role, evidence_dict, proposed_action, alternatives):
    """Emit a signal: auto-resolve if graduated pattern matches, else write signal file for triage."""
    now = int(time.time())
    role_cat = _role_category(role)
    screen_text = evidence_dict.get("screen_tail_10", "")

    # Check for graduated pattern
    pattern = check_pattern_match(db, signal_type, role_cat, screen_text)
    if pattern and pattern["resolution"] == proposed_action:
        db.execute("UPDATE decision_patterns SET occurrences=occurrences+1, last_seen=? WHERE id=?",
                   (now, pattern["id"]))
        db.commit()
        # Record resolution
        sig_id = f"sig-{now}-{uuid.uuid4().hex[:4]}"
        db.execute(
            "INSERT INTO signals (id,signal_type,severity,pane_id,role,role_category,evidence_json,proposed_action,alternatives_json,pattern_id,status,decided_action,decided_by,decided_at,created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (sig_id, signal_type, severity, pane_id, role, role_cat, json.dumps(evidence_dict),
             proposed_action, json.dumps(alternatives), pattern["id"], "auto_resolved", proposed_action, "pattern", now, now))
        db.execute(
            "INSERT INTO resolutions (signal_id,signal_type,role,action_taken,decided_by,pattern_id,latency_sec,created_at) VALUES (?,?,?,?,?,?,?,?)",
            (sig_id, signal_type, role, proposed_action, "pattern", pattern["id"], 0, now))
        db.commit()
        notify_user("ℹ️ Auto", f"{proposed_action} on {role} (pattern #{pattern['id']})")
        logger.info("SIGNAL: auto-resolved %s %s on %s via pattern #%d", sig_id, signal_type, role, pattern["id"])
        return sig_id

    # No pattern match — emit signal file for triage
    sig_id = f"sig-{now}-{uuid.uuid4().hex[:4]}"

    # Similar history
    recent = db.execute(
        "SELECT decided_action, COUNT(*) as cnt FROM signals WHERE signal_type=? AND role_category=? AND created_at>? AND status IN ('resolved','auto_resolved') GROUP BY decided_action",
        (signal_type, role_cat, now - 86400)).fetchall()
    history = "; ".join(f"{r['cnt']}x {r['decided_action']}" for r in recent) if recent else "none in 24h"

    packet = {
        "signal_id": sig_id, "type": signal_type, "severity": severity,
        "pane_id": pane_id, "role": role, "role_category": role_cat,
        "timestamp": now, "evidence": evidence_dict,
        "proposed_action": proposed_action, "alternatives": alternatives,
        "pattern_match": None, "similar_history": history,
    }

    # Write signal file
    sig_path = SIGNAL_DIR / f"{sig_id}.json"
    sig_path.write_text(json.dumps(packet, indent=2) + "\n")

    # Insert into DB
    auto_approve_at = None
    if is_overnight() and role_cat == "worker" and evidence_dict.get("confidence") == "HIGH":
        cfg = _load_config()
        delay = cfg.get("overnight_auto_approve_delay", 120)
        auto_approve_at = now + delay

    db.execute(
        "INSERT INTO signals (id,signal_type,severity,pane_id,role,role_category,evidence_json,proposed_action,alternatives_json,status,auto_approve_at,created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
        (sig_id, signal_type, severity, pane_id, role, role_cat, json.dumps(evidence_dict),
         proposed_action, json.dumps(alternatives), "pending", auto_approve_at, now))
    db.commit()

    notify_user(f"🚨 {severity}", f"{signal_type} on {role} — crew-ctl approve {sig_id}", urgent=(severity == "P0"))
    extra = f" auto_approve_in={auto_approve_at - now}s" if auto_approve_at else ""
    logger.info("SIGNAL: emitted %s type=%s severity=%s role=%s action=%s%s", sig_id, signal_type, severity, role, proposed_action, extra)

    # T3: Spawn headless triage agent for unresolved signals
    threading.Thread(target=t3_triage_spawn, args=(sig_id, packet), daemon=True).start()

    return sig_id


# ── T3: Heartbeat-Based LLM Triage ────────────────────────────────────────

T3_TRIAGE_TIMEOUT = 60
T3_POLL_INTERVAL = 5

def t3_triage_spawn(signal_id, signal_packet):
    """Spawn a headless coordinator agent to triage an unresolved signal.
    Writes triage-request.json, spawns kiro-sub --headless, polls for decision."""
    request_path = _CREW_DATA / "triage-request.json"
    decision_path = f"/tmp/t3-triage-{signal_id}-decision.json"

    try:
        db = get_db()

        # Build triage request with crew state + context
        crew_state = {}
        try:
            for row in db.execute("SELECT role, status, waiting_on FROM registry WHERE role IS NOT NULL").fetchall():
                entry = row["status"] or "unknown"
                if row["waiting_on"]:
                    entry += f" waiting_on:{row['waiting_on']}"
                crew_state[row["role"]] = entry
        except sqlite3.OperationalError:
            # Fallback if status column missing (pre-existing schema gap)
            for row in db.execute("SELECT role, waiting_on FROM registry WHERE role IS NOT NULL").fetchall():
                entry = "unknown"
                if row["waiting_on"]:
                    entry += f" waiting_on:{row['waiting_on']}"
                crew_state[row["role"]] = entry

        pending = [{"target": r["target_role"], "sender": r["sender"], "payload": r["payload"][:200]}
                   for r in db.execute("SELECT target_role, sender, payload FROM messages WHERE status='pending' ORDER BY created_at DESC LIMIT 10").fetchall()]

        recent_sigs = [{"id": r["id"], "type": r["signal_type"], "resolution": r["decided_action"], "outcome": r["status"]}
                       for r in db.execute("SELECT id, signal_type, decided_action, status FROM signals WHERE status IN ('resolved','auto_resolved') ORDER BY created_at DESC LIMIT 5").fetchall()]

        db.close()

        request = {
            "signal_id": signal_id,
            "type": signal_packet.get("type"),
            "evidence": signal_packet.get("evidence", {}),
            "auto_actions_tried": signal_packet.get("alternatives", []),
            "crew_state": crew_state,
            "pending_messages": pending,
            "recent_signals": recent_sigs,
        }

        # Atomic write
        tmp_path = str(request_path) + ".tmp"
        Path(tmp_path).write_text(json.dumps(request, indent=2) + "\n")
        os.replace(tmp_path, str(request_path))
        logger.info("T3: wrote triage request for %s", signal_id)

        # Spawn headless agent
        task = (
            f"Triage crew signal. Read context. Decide: nudge, respawn, reassign, escalate, or dismiss. "
            f"Write decision JSON to {decision_path} with: signal_id, action, target, reason, confidence. Then exit."
        )
        cmd = [
            "bash", os.path.expanduser("~/scripts/kiro-sub.sh"), task,
            "--agent", "coordinator",
            "--context", str(request_path),
            "--headless",
        ]
        subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        logger.info("T3: spawned headless coordinator for %s", signal_id)

        # Poll for decision
        deadline = time.time() + T3_TRIAGE_TIMEOUT
        decision = None
        while time.time() < deadline:
            if os.path.exists(decision_path):
                time.sleep(0.5)
                try:
                    decision = json.loads(Path(decision_path).read_text())
                    break
                except json.JSONDecodeError:
                    time.sleep(1)
                    continue
            time.sleep(T3_POLL_INTERVAL)

        if not decision:
            logger.warning("T3: triage timeout for %s after %ds", signal_id, T3_TRIAGE_TIMEOUT)
            return

        logger.info("T3: decision for %s: action=%s target=%s confidence=%s",
                     signal_id, decision.get("action"), decision.get("target"), decision.get("confidence"))

        # Write decision file where poll_signal_decisions expects it
        dec_path = SIGNAL_DIR / f"{signal_id}.decision.json"
        dec_data = {
            "signal_id": signal_id,
            "action": decision.get("action", "escalate"),
            "decided_by": "t3_coordinator",
            "decided_at": int(time.time()),
            "target": decision.get("target"),
            "reason": decision.get("reason"),
            "confidence": decision.get("confidence"),
        }
        Path(str(dec_path) + ".tmp").write_text(json.dumps(dec_data) + "\n")
        os.replace(str(dec_path) + ".tmp", str(dec_path))
        logger.info("T3: wrote decision file for %s → %s", signal_id, dec_path)

        # Cleanup agent decision file from /tmp
        try:
            os.unlink(decision_path)
        except OSError:
            pass

    except Exception:
        logger.exception("T3: triage error for %s", signal_id)


# ── State Monitor (Task 2.1) ───────────────────────────────────────────────

def screen_hash(pane_id):
    """SHA256 of last 10 non-empty lines."""
    out = zellij_cmd("dump-screen", "--pane-id", pane_id)
    if not out:
        return None
    lines = [l for l in out.rstrip("\n").split("\n") if l.strip()]
    tail = "\n".join(lines[-10:])
    return hashlib.sha256(tail.encode()).hexdigest()



def check_health(pane_id, screen_text):
    """Check screen for service degradation signals. Auto-pauses if critical."""
    now = int(time.time())
    # Hard limit — full stop
    if HEALTH_HARD_LIMIT_RE.search(screen_text):
        if not os.path.exists(PAUSE_SIGNAL):
            with open(PAUSE_SIGNAL, "w") as f:
                f.write(f"{time.strftime('%Y-%m-%dT%H:%M:%S%z')} reason=hard_limit pane={pane_id}\n")
            logger.critical("HEALTH: daily limit hit on %s — crew PAUSED", pane_id)
        return "hard_limit"
    # Throttle
    if HEALTH_THROTTLE_RE.search(screen_text):
        if not os.path.exists(PAUSE_SIGNAL):
            with open(PAUSE_SIGNAL, "w") as f:
                f.write(f"{time.strftime('%Y-%m-%dT%H:%M:%S%z')} reason=throttle pane={pane_id} resume_after=300\n")
            logger.warning("HEALTH: throttled on %s — crew PAUSED 5 min", pane_id)
        return "throttle"
    # Model down
    if HEALTH_MODEL_DOWN_RE.search(screen_text):
        if not os.path.exists(PAUSE_SIGNAL):
            with open(PAUSE_SIGNAL, "w") as f:
                f.write(f"{time.strftime('%Y-%m-%dT%H:%M:%S%z')} reason=model_down pane={pane_id} resume_after=600\n")
            logger.warning("HEALTH: model down on %s — crew PAUSED 10 min", pane_id)
        return "model_down"
    # Auth fail
    if HEALTH_AUTH_FAIL_RE.search(screen_text):
        if not os.path.exists(PAUSE_SIGNAL):
            with open(PAUSE_SIGNAL, "w") as f:
                f.write(f"{time.strftime('%Y-%m-%dT%H:%M:%S%z')} reason=auth_fail pane={pane_id}\n")
            logger.critical("HEALTH: auth failure on %s — crew PAUSED (manual fix needed)", pane_id)
        return "auth_fail"
    # Service down
    if HEALTH_SERVICE_DOWN_RE.search(screen_text):
        if not os.path.exists(PAUSE_SIGNAL):
            with open(PAUSE_SIGNAL, "w") as f:
                f.write(f"{time.strftime('%Y-%m-%dT%H:%M:%S%z')} reason=service_down pane={pane_id} resume_after=300\n")
            logger.warning("HEALTH: service down on %s — crew PAUSED 5 min", pane_id)
        return "service_down"
    # Transient — only flag if 3+ in 60s on same pane
    if HEALTH_TRANSIENT_RE.search(screen_text):
        hits = _transient_counts.get(pane_id, [])
        hits = [t for t in hits if now - t < 60] + [now]
        _transient_counts[pane_id] = hits
        if len(hits) >= 3:
            logger.warning("HEALTH: repeated transient errors on %s (%d in 60s)", pane_id, len(hits))
            return "transient_repeated"
        return "transient"
    # Clean — clear transient counter
    _transient_counts.pop(pane_id, None)
    return None
def classify_status(pane_id, row, screen_text):
    """Classify pane status: idle|working|possibly_hung|hung|crashed|context_rot."""
    prompt_visible = bool(PROMPT_RE.search(screen_text))
    thinking = bool(THINKING_RE.search(screen_text))
    consec = row["consecutive_same_hash"] if row else 0
    ctx_pct = row["context_pct"] if row else 0

    if ctx_pct > 75:
        return "context_rot"

    # Tier 1: Process-level signal (absolute override)
    kiro_chat_pid = row.get("kiro_chat_pid") if row else None
    if has_tool_children(kiro_chat_pid):
        return "working"

    if prompt_visible:
        # Preserve "done" if already marked and screen unchanged
        if row and row.get("status") == "done" and consec > 0:
            return "done"
        return "idle"
    if consec >= 40:  # 40 * 30s = 20 min
        return "hung"
    if consec >= 10 and thinking:  # 5 min with Thinking...
        return "possibly_hung"
    if consec >= 10 and not prompt_visible:  # 5 min static, no prompt
        return "possibly_hung"
    return "working"


def monitor_panes(db):
    """State monitor loop — runs every 30s (Task 2.1)."""
    now = int(time.time())
    rows = db.execute("SELECT * FROM registry").fetchall()

    # Build pane JSON lookup for PID resolution
    _pane_json_map = {}
    for p in list_all_panes():
        _pane_json_map[f"terminal_{p['id']}"] = p

    for row in rows:
        pane_id = row["pane_id"]
        try:
            # Dump screen
            full_screen = zellij_cmd("dump-screen", "--pane-id", pane_id) or ""
            tail_5 = "\n".join(full_screen.rstrip("\n").split("\n")[-5:]) if full_screen else ""

            # Parse prompt
            agent_name, ctx_pct_screen = None, None
            m = PROMPT_RE.search(tail_5)
            if m:
                agent_name, ctx_pct_screen = m.group(1), int(m.group(2))

            # Screen hash
            lines = [l for l in full_screen.rstrip("\n").split("\n") if l.strip()]
            h = hashlib.sha256("\n".join(lines[-10:]).encode()).hexdigest() if lines else None

            prev_hash = row["screen_hash"]
            consec = row["consecutive_same_hash"] or 0
            if h and h == prev_hash:
                consec += 1
            else:
                consec = 0

            # Conversation ID linking (Task 2.2)
            conv_id = row["conversation_id"]
            if not conv_id and row["session_id"]:
                conv_id = find_conversation_id_for_session(row["session_id"], row["registered_at"])

            # Read data.sqlite3 for context info
            ctx_tokens, ctx_window, hist_turns = None, None, None
            if conv_id:
                ctx_tokens, ctx_window, hist_turns = get_context_from_data_db(conv_id)

            # Compute context_pct from data.sqlite3
            ctx_pct_db = None
            if ctx_tokens and ctx_window and ctx_window > 0:
                ctx_pct_db = round(ctx_tokens / ctx_window * 100, 1)

            # Use screen % as primary, data.sqlite3 as secondary
            final_ctx_pct = ctx_pct_screen if ctx_pct_screen is not None else (ctx_pct_db or row["context_pct"] or 0)

            # Resolve kiro-cli-chat PID (cached, re-resolve if stale)
            cached_pid = row["kiro_chat_pid"] if "kiro_chat_pid" in row.keys() else None
            kiro_chat_pid = None
            if cached_pid:
                try:
                    os.kill(cached_pid, 0)  # check alive
                    kiro_chat_pid = cached_pid
                except (OSError, ProcessLookupError):
                    kiro_chat_pid = None  # stale — re-resolve
            if not kiro_chat_pid and pane_id in _pane_json_map:
                kiro_chat_pid = resolve_kiro_chat_pid(pane_id, _pane_json_map[pane_id])

            # Classify status

            # Health check — detect service degradation from screen text
            check_health(pane_id, tail_5)
            status = classify_status(pane_id, dict(row) | {"consecutive_same_hash": consec, "context_pct": final_ctx_pct, "kiro_chat_pid": kiro_chat_pid}, tail_5)

            # Track screen changes
            last_change = row["last_screen_change"] or now
            if h != prev_hash:
                last_change = now

            # T2: Track consecutive idle checks for deadlock detection
            prev_idle = row["consecutive_idle_checks"] if "consecutive_idle_checks" in row.keys() else 0
            idle_checks = (prev_idle + 1) if status == "idle" else 0

            # Update registry
            db.execute(
                """UPDATE registry SET status=?, screen_hash=?, consecutive_same_hash=?,
                   context_pct=?, context_tokens=?, context_window=?, history_turns=?,
                   conversation_id=?, last_screen_change=?, last_activity=?, updated_at=?,
                   consecutive_idle_checks=?, kiro_chat_pid=?
                   WHERE pane_id=?""",
                (status, h, consec, final_ctx_pct,
                 ctx_tokens or row["context_tokens"], ctx_window or row["context_window"],
                 hist_turns if hist_turns is not None else row["history_turns"],
                 conv_id, last_change, now if h != prev_hash else row["last_activity"], now,
                 idle_checks, kiro_chat_pid, pane_id),
            )

            if agent_name and not row["agent"]:
                db.execute("UPDATE registry SET agent=? WHERE pane_id=?", (agent_name, pane_id))

            # Detect state transition for verdict system
            old_status = _prev_status.get(pane_id)
            if old_status != status:
                if old_status:
                    logger.info("MONITOR: %s transition %s → %s", pane_id, old_status, status)
                    _schedule_verdict(db, pane_id, row["role"], old_status, status, full_screen, now)
                else:
                    logger.info("MONITOR: %s initial status %s", pane_id, status)
                _update_tab_status_color(db, pane_id, status)
            _prev_status[pane_id] = status

        except Exception:
            logger.exception("MONITOR: error processing %s", pane_id)

    db.commit()


# ── Hang Detection (Task 2.3) ──────────────────────────────────────────────

def send_ctrl_c(pane_id):
    """Send Ctrl+C (byte 3) to pane."""
    s = _get_session()
    base = ["zellij"] + (["--session", s] if s else [])
    try:
        subprocess.run(
            base + ["action", "send-keys", "--pane-id", pane_id, "\x03"],
            capture_output=True, timeout=5,
        )
        return True
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def check_hang_detection(db):
    """Graduated 4-level hang response (Task 2.3). Overnight: thresholds double."""
    now = int(time.time())
    overnight = is_overnight()
    t_mult = 2 if overnight else 1  # threshold multiplier
    rows = db.execute("SELECT * FROM registry WHERE status IN ('idle','possibly_hung','hung') AND status != 'done'").fetchall()

    for row in rows:
        pane_id = row["pane_id"]
        role = row["role"] or ""
        last_change = row["last_screen_change"] or now
        idle_sec = now - last_change
        idle_min = idle_sec / 60
        consec = row["consecutive_same_hash"] or 0
        prompt_visible = row["status"] == "idle"
        level = _hang_levels.get(pane_id, 0)
        protected = role in PROTECTED_ROLES

        # Child-process guard: if kiro-cli-chat has children, tool is running — reset hang state
        kiro_chat_pid = row["kiro_chat_pid"] if "kiro_chat_pid" in row.keys() else None
        if has_tool_children(kiro_chat_pid):
            if level > 0:
                logger.info("HANG: reset %s — tool children detected (pid=%s)", pane_id, kiro_chat_pid)
            _hang_levels[pane_id] = 0
            continue

        # Level 1: 5 min idle, prompt visible → nudge
        if idle_min >= 5 * t_mult and prompt_visible and level < 1:
            _enqueue_system_msg(db, role, "You've been idle for 5 min. Check your current task and proceed.", priority=2)
            _hang_levels[pane_id] = 1
            logger.info("HANG: L1 NUDGE %s idle_min=%.0f", pane_id, idle_min)

        # Level 2: 15 min static, no prompt → alert
        elif idle_min >= 15 * t_mult and not prompt_visible and level < 2 and level >= 1:
            _enqueue_system_msg(db, role,
                "You appear stuck. If waiting for input, check /tmp/.crew-pending/. If hung, type /quit and your spawner will recreate you.", priority=1)
            _hang_levels[pane_id] = 2
            logger.info("HANG: L2 ALERT %s static_min=%.0f", pane_id, idle_min)

        # Level 3: 20 min static, Thinking... → Ctrl+C
        elif idle_min >= 20 * t_mult and level < 3 and level >= 2:
            last_cc = _last_ctrlc.get(pane_id, 0)
            if now - last_cc < 1800:  # max 1 Ctrl+C per 30 min
                continue
            # 3-snapshot pre-check
            if _verify_truly_stuck(pane_id):
                screen_tail = dump_screen(pane_id, 10) or ""
                evidence = {"idle_seconds": idle_sec, "consecutive_same_hash": consec,
                            "screen_tail_10": screen_tail, "det_verdict": "HUNG", "confidence": "HIGH"}
                emit_signal(db, "hang_ctrlc", "P0", pane_id, role, evidence, "ctrl_c", ["nudge", "replace", "ignore"])
                _hang_levels[pane_id] = 3
                logger.info("HANG: L3 SIGNAL %s static_min=%.0f", pane_id, idle_min)
            else:
                logger.info("HANG: L3 pre-check failed for %s — screen changed, resetting", pane_id)
                _hang_levels[pane_id] = 0

        # Level 4: 30 min static (45 for protected) OR Ctrl+C failed → replacement
        elif level >= 3:
            threshold = (45 if protected else 30) * t_mult
            if idle_min >= threshold:
                screen_tail = dump_screen(pane_id, 10) or ""
                evidence = {"idle_seconds": idle_sec, "consecutive_same_hash": consec,
                            "screen_tail_10": screen_tail, "det_verdict": "HUNG", "confidence": "HIGH"}
                emit_signal(db, "hang_replace", "P0", pane_id, role, evidence, "replace", ["ctrl_c", "ignore"])
                _hang_levels[pane_id] = 4
                logger.info("HANG: L4 SIGNAL %s reason=hung static_min=%.0f", pane_id, idle_min)


def check_tool_timeout(db):
    """Detect and kill tool processes stuck on stdin or otherwise hung (#69)."""
    rows = db.execute(
        "SELECT pane_id, role, kiro_chat_pid FROM registry WHERE status IN ('idle','active','possibly_hung') AND status != 'done'"
    ).fetchall()

    for row in rows:
        pane_id = row["pane_id"]
        role = row["role"] or ""
        kiro_chat_pid = row["kiro_chat_pid"] if "kiro_chat_pid" in row.keys() else None
        if not kiro_chat_pid:
            continue

        children = get_child_processes_with_age(kiro_chat_pid)
        if not children:
            continue

        for child_pid, elapsed_sec, cmd in children:
            threshold = tool_timeout_for_command(cmd)

            if elapsed_sec < threshold:
                continue

            if not verify_child_stuck(child_pid):
                continue

            logger.warning("TOOL_TIMEOUT: killing child pid=%d cmd='%s' elapsed=%ds threshold=%ds (agent=%s)",
                          child_pid, cmd, elapsed_sec, threshold, pane_id)
            try:
                pgid = os.getpgid(child_pid)
                os.killpg(pgid, signal.SIGTERM)
            except (ProcessLookupError, PermissionError):
                try:
                    os.kill(child_pid, signal.SIGTERM)
                except (ProcessLookupError, PermissionError):
                    pass

            def _force_kill(pid):
                time.sleep(3)
                try:
                    os.kill(pid, 0)
                    os.kill(pid, signal.SIGKILL)
                    logger.warning("TOOL_TIMEOUT: SIGKILL sent to pid=%d", pid)
                except (ProcessLookupError, PermissionError):
                    pass

            threading.Thread(target=_force_kill, args=(child_pid,), daemon=True).start()

            _tool_cpu_snapshots.pop(child_pid, None)

            msg = (f"⚠️ Tool execution killed after {elapsed_sec}s — command `{cmd}` appeared stuck "
                   f"(0 CPU activity for 3 consecutive checks). The command may have been waiting for stdin. "
                   f"Add `< /dev/null` to prevent this.")
            _enqueue_system_msg(db, role, msg, priority=1)


def _verify_truly_stuck(pane_id):
    """Take 3 snapshots 10s apart. All must be identical."""
    hashes = []
    for _ in range(3):
        h = screen_hash(pane_id)
        hashes.append(h)
        if len(hashes) > 1 and hashes[-1] != hashes[-2]:
            return False
        time.sleep(10)
    return len(set(hashes)) == 1


def _post_ctrlc_check(db_ignored, pane_id, role, sent_at):
    """Check if prompt appeared after Ctrl+C. Runs in timer thread."""
    try:
        if is_idle(pane_id):
            db = get_db()
            _enqueue_system_msg(db, role, "You were interrupted due to a hang. Resume your current task.", priority=1)
            db.close()
            logger.info("HANG: L3 recovery success for %s — prompt appeared", pane_id)
        else:
            logger.info("HANG: L3 Ctrl+C failed for %s — no prompt after 15s, will escalate to L4", pane_id)
    except Exception:
        logger.exception("HANG: post-ctrlc check error for %s", pane_id)


def _enqueue_system_msg(db, role, text, priority=1):
    """Insert a system message into the queue. Dedup-aware (Task 3.3)."""
    if not role:
        return
    ch = content_hash(text)
    if dedup_check(db, ch):
        logger.info("DISPATCH: deduped system msg for %s (hash=%s…)", role, ch[:8])
        return
    now = int(time.time())
    db.execute(
        "INSERT INTO messages (target_role, sender, priority, payload, content_hash, status, created_at) VALUES (?, 'daemon', ?, ?, ?, 'pending', ?)",
        (role, priority, text, ch, now),
    )
    db.commit()


# ── T2: Dependency Cross-Reference Deadlock Detection ──────────────────────

T2_MIN_IDLE_CHECKS = 2  # Require 2 consecutive idle checks (60s at 30s interval) before deadlock

def t2_detect_deadlocks(db):
    """Cross-reference waiting_on with target status. Emit signal on deadlock."""
    rows = db.execute(
        "SELECT pane_id, role, waiting_on FROM registry WHERE waiting_on IS NOT NULL AND waiting_on != ''"
    ).fetchall()

    for row in rows:
        for target_role in row["waiting_on"].split(","):
            target_role = target_role.strip()
            if not target_role:
                continue
            target = db.execute(
                "SELECT pane_id, role, status, consecutive_idle_checks FROM registry WHERE role=?",
                (target_role,),
            ).fetchone()
            if not target:
                # Target not registered — emit missing_target signal
                emit_signal(db, "deadlock_detected", "P1", row["pane_id"], row["role"],
                            {"waiter": row["role"], "target": target_role, "reason": "target_not_registered"},
                            "nudge", ["ignore"])
                logger.warning("T2: %s waiting on %s but %s not registered", row["role"], target_role, target_role)
                continue

            idle_checks = target["consecutive_idle_checks"] or 0
            if target["status"] != "idle" or idle_checks < T2_MIN_IDLE_CHECKS:
                continue

            # Target is idle for 2+ checks — check for pending messages
            pending = db.execute(
                "SELECT COUNT(*) FROM messages WHERE target_role=? AND status IN ('pending','delivered')",
                (target_role,),
            ).fetchone()[0]
            if pending > 0:
                continue  # Target has work queued, not a deadlock

            # Deadlock: waiter waiting on idle target with no pending work
            emit_signal(db, "deadlock_detected", "P1", target["pane_id"], target["role"],
                        {"waiter": row["role"], "target": target_role,
                         "idle_checks": idle_checks, "reason": "idle_no_work"},
                        "nudge", ["ignore"])
            logger.warning("T2: DEADLOCK — %s waiting on %s, %s idle (%d checks) with no pending messages",
                           row["role"], target_role, target_role, idle_checks)


# ── ETA Overdue Detection ──────────────────────────────────────────────────

_eta_nudged: dict[int, set] = {}  # msg_id -> set of tiers fired ("1.5x", "3.0x")
_p0_alerted: set = set()  # target_roles already alerted for stale P0 — reset when messages delivered

def check_eta_overdue(db):
    """Nudge Manager when a worker exceeds its ETA. Two tiers: 1.5x (soft), 3.0x (always)."""
    now = int(time.time())
    rows = db.execute("SELECT * FROM registry WHERE role NOT IN ('Manager','Planner','Watcher')").fetchall()

    for row in rows:
        role = row["role"]
        if not role:
            continue
        # Skip workers that are idle/done with no active task
        if row["status"] in ("idle", "done", "unknown"):
            continue
        msg = db.execute(
            "SELECT id, eta_seconds, dispatched_at FROM messages "
            "WHERE target_role=? AND status='delivered' AND eta_seconds IS NOT NULL AND dispatched_at IS NOT NULL "
            "ORDER BY dispatched_at DESC LIMIT 1", (role,)
        ).fetchone()
        if not msg:
            continue

        # Skip if worker is idle — task is done or abandoned, no nudge needed.
        # _idle_since tracks when each pane last became idle (prompt visible).
        idle_since = _idle_since.get(row["pane_id"])
        if idle_since and idle_since > msg["dispatched_at"]:
            continue

        elapsed = now - msg["dispatched_at"]
        eta = msg["eta_seconds"]
        if eta <= 0 or elapsed <= eta * 1.5:
            continue

        msg_id = msg["id"]
        nudged = _eta_nudged.setdefault(msg_id, set())
        screen_changing = (row["consecutive_same_hash"] or 0) == 0

        # Tier 1: eta * 1.5 — skip if screen actively changing
        if "1.5x" not in nudged:
            if not (screen_changing and elapsed < eta * 3.0):
                tail = dump_screen(row["pane_id"], 5)
                tag = _eta_status_tag(tail)
                _enqueue_system_msg(db, "Manager",
                    f"\u23f0 {role} overdue (est {eta}s, elapsed {elapsed}s). Status: [{tag}]\n{tail}", priority=1)
                nudged.add("1.5x")
                logger.info("ETA: tier 1.5x nudge for %s (msg %d, eta=%d, elapsed=%d)", role, msg_id, eta, elapsed)

        # Tier 2: eta * 3.0 — always fires
        if elapsed > eta * 3.0 and "3.0x" not in nudged:
            tail = dump_screen(row["pane_id"], 5)
            tag = _eta_status_tag(tail)
            _enqueue_system_msg(db, "Manager",
                f"\u23f0\u26a0\ufe0f {role} VERY overdue — may be going wrong direction "
                f"(est {eta}s, elapsed {elapsed}s). Status: [{tag}]\n{tail}", priority=0)
            nudged.add("3.0x")
            logger.info("ETA: tier 3.0x nudge for %s (msg %d, eta=%d, elapsed=%d)", role, msg_id, eta, elapsed)


def _eta_status_tag(screen_text):
    """Classify screen into a status tag for ETA nudge messages."""
    if not screen_text:
        return "UNKNOWN"
    if ERROR_RE.search(screen_text):
        return "ERROR"
    if THINKING_RE.search(screen_text):
        return "THINKING"
    if PROMPT_RE.search(screen_text):
        return "IDLE"
    return "WORKING"


# ── Context Rot Detection (Task 2.4) ───────────────────────────────────────

def check_context_rot(db):
    """Warn at >75%, auto-replace at >90%. Coordinator: warn >60%, auto-replace >80%."""
    rows = db.execute("SELECT * FROM registry WHERE context_pct > 55").fetchall()
    now = int(time.time())

    for row in rows:
        pane_id = row["pane_id"]
        role = row["role"] or ""
        screen_pct = row["context_pct"] or 0
        is_coordinator = (role == "Coordinator")

        # Verify with data.sqlite3
        db_pct = None
        if row["conversation_id"]:
            ctx_tokens, ctx_window, _ = get_context_from_data_db(row["conversation_id"])
            if ctx_tokens and ctx_window and ctx_window > 0:
                db_pct = round(ctx_tokens / ctx_window * 100, 1)

        # Dual-source check: if both available, must agree within 20%
        if db_pct is not None and abs(screen_pct - db_pct) > 20:
            logger.warning("CONTEXT_ROT: source mismatch for %s screen=%.0f%% db=%.0f%% — skipping", pane_id, screen_pct, db_pct)
            continue

        effective_pct = db_pct if db_pct is not None else screen_pct

        # Coordinator: lower thresholds, auto-replace (stateless, no signal needed)
        if is_coordinator:
            cfg = _load_config()
            replace_pct = cfg.get("coordinator_replace_pct", 80)
            if effective_pct > replace_pct:
                logger.info("CONTEXT_ROT: auto-replace Coordinator %s at %.0f%% (threshold %d%%)", pane_id, effective_pct, replace_pct)
                trigger_replacement(db, pane_id, "context_rot")
            elif effective_pct > 60:
                _enqueue_system_msg(db, role,
                    f"Context at {effective_pct:.0f}%. Daemon will replace me soon — no state will be lost.", priority=2)
                logger.info("CONTEXT_ROT: warned Coordinator %s at %.0f%%", pane_id, effective_pct)
            continue

        # Non-coordinator: skip if below standard thresholds
        if effective_pct <= 75:
            continue

        if effective_pct > 90:
            screen_tail = dump_screen(pane_id, 10) or ""
            evidence = {"context_pct": effective_pct, "screen_pct": screen_pct,
                        "db_pct": db_pct, "screen_tail_10": screen_tail}
            emit_signal(db, "context_rot", "P0", pane_id, role, evidence, "replace", ["ignore"])
            logger.info("CONTEXT_ROT: signal emitted for %s at %.0f%%", pane_id, effective_pct)
        elif effective_pct > 75:
            _enqueue_system_msg(db, role,
                f"Context window at {effective_pct:.0f}%. Consider writing your current state to a file and requesting a fresh tab.", priority=1)
            logger.info("CONTEXT_ROT: warned %s at %.0f%%", pane_id, effective_pct)


# ── Pool Autoscale ─────────────────────────────────────────────────────────

def _next_worker_role(db):
    """Compute next W<N> role name from registry."""
    row = db.execute(
        "SELECT MAX(CAST(SUBSTR(role,2) AS INTEGER)) FROM registry WHERE role GLOB 'W[0-9]*' AND status != 'replaced'"
    ).fetchone()
    return f"W{(row[0] or 0) + 1}"


def _spawn_autoscale_worker(role):
    """Spawn an idle worker tab via kiro-sub.sh."""
    ctx_path = f"/tmp/ctx-autoscale-{role}.md"
    Path(ctx_path).write_text(f"# Idle Worker {role}\nAwait task dispatch.\n")
    try:
        subprocess.run(
            ["bash", str(Path.home() / "scripts/kiro-sub.sh"),
             "Idle worker awaiting task dispatch.",
             "--agent", "coder", "--context", ctx_path,
             "--tab-name", f"⚙️ {role}", "--visible"],
            capture_output=True, timeout=30,
        )
        return True
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        logger.error("AUTOSCALE: spawn failed for %s: %s", role, e)
        return False


def check_pool_autoscale(db):
    """Autoscale worker pool: min guarantee, demand-driven, proactive replacement."""
    cfg = _load_config()
    pool = cfg["pool"]
    now = int(time.time())

    # All alive workers (not replaced)
    all_workers = db.execute(
        "SELECT role, status, context_pct FROM registry WHERE role GLOB 'W[0-9]*' AND status != 'replaced'"
    ).fetchall()
    total_alive = len(all_workers)

    # Healthy = (idle or working) AND context < proactive threshold
    healthy = [w for w in all_workers
               if w["status"] in ("idle", "working") and (w["context_pct"] or 0) < pool["proactive_replace_pct"]]
    idle_healthy = [w for w in healthy if w["status"] == "idle"]

    # Pending messages targeting workers
    pending = db.execute(
        "SELECT COUNT(*) FROM messages WHERE target_role GLOB 'W[0-9]*' AND status = 'pending'"
    ).fetchone()[0]

    # Cooldown check
    last_spawn = db.execute("SELECT MAX(created_at) FROM autoscale_log").fetchone()[0]
    cooldown_ok = last_spawn is None or (now - last_spawn) >= pool["spawn_cooldown_sec"]

    if not cooldown_ok:
        remaining = pool["spawn_cooldown_sec"] - (now - (last_spawn or 0))
        logger.info("AUTOSCALE: skipped — cooldown (%ds remaining)", remaining)
        return

    if total_alive >= pool["max_workers"]:
        logger.info("AUTOSCALE: skipped — at ceiling (%d/%d)", total_alive, pool["max_workers"])
        return

    spawns = []
    batch = 0

    def do_spawn(reason):
        nonlocal total_alive, batch
        if total_alive >= pool["max_workers"] or batch >= pool["max_spawn_batch"]:
            return False
        role = _next_worker_role(db)
        if _spawn_autoscale_worker(role):
            db.execute("INSERT INTO autoscale_log (role, reason, created_at) VALUES (?, ?, ?)",
                       (role, reason, now))
            total_alive += 1
            batch += 1
            spawns.append((role, reason))
            logger.info("AUTOSCALE: spawned %s reason=%s", role, reason)
            return True
        return False

    # Rule 1: Min pool guarantee
    deficit = pool["min_workers"] - len(healthy)
    while deficit > 0:
        if not do_spawn("min_pool_guarantee"):
            break
        deficit -= 1

    # Rule 2: Demand-driven scaling (only if rule 1 didn't spawn)
    if pending > 0 and len(idle_healthy) == 0 and not spawns:
        for _ in range(min(pending, pool["max_spawn_batch"])):
            if not do_spawn("demand_driven"):
                break

    # Rule 3: Proactive replacement (only if nothing spawned yet)
    if not spawns:
        high_ctx = [w for w in all_workers
                    if (w["context_pct"] or 0) >= pool["proactive_replace_pct"]
                    and w["status"] in ("idle", "working")]
        if pending > 0 and high_ctx:
            for w in high_ctx:
                if not do_spawn(f"proactive_replace({w['role']})"):
                    break

    if spawns:
        db.commit()


# ── Role Violation Detection ───────────────────────────────────────────────

ROLE_VIOLATION_RE = re.compile(
    r"(?:Updating|Writing|Creating|Modifying):\s+(\S+\.(?:tsx?|css|py|jsx?|vue|svelte))",
    re.IGNORECASE,
)
_SAFE_WRITE_PREFIXES = ("/tmp/", os.path.expanduser("~/plans/"), str(_CREW_DATA) + "/")
_last_role_violation = {}  # pane_id → unix timestamp


def check_role_violations(db):
    """Detect Manager/Planner tabs writing source files (role boundary violation)."""
    now = int(time.time())
    rows = db.execute("SELECT * FROM registry WHERE role IN ('Manager', 'Planner')").fetchall()

    for row in rows:
        pane_id = row["pane_id"]
        role = row["role"]

        # Cooldown: 5 min per pane
        if now - _last_role_violation.get(pane_id, 0) < 300:
            continue

        screen = dump_screen(pane_id, 15)
        if not screen:
            continue

        m = ROLE_VIOLATION_RE.search(screen)
        if not m:
            continue

        file_path = m.group(1)
        if any(file_path.startswith(p) for p in _SAFE_WRITE_PREFIXES):
            continue

        _last_role_violation[pane_id] = now
        evidence = {"screen_tail_10": dump_screen(pane_id, 10) or "",
                    "file_path": file_path, "indicator": m.group(0)}
        emit_signal(db, "role_violation", "P1", pane_id, role, evidence, "nudge", ["ignore"])
        logger.info("ROLE_VIOLATION: %s (%s) writing %s", pane_id, role, file_path)


# ── Tab Replacement (Task 2.5) ─────────────────────────────────────────────

def trigger_replacement(db, pane_id, reason):
    """6-step tab replacement flow."""
    now = int(time.time())
    row = db.execute("SELECT * FROM registry WHERE pane_id = ?", (pane_id,)).fetchone()
    if not row:
        return
    role = row["role"] or ""
    protected = role in PROTECTED_ROLES

    # Rate limit: max 2 replacements/role/hour
    recent = [t for t in _replacement_count.get(role, []) if now - t < 3600]
    if len(recent) >= 2:
        logger.warning("REPLACE: rate limit hit for %s (2/hour). Manual intervention needed.", role)
        _enqueue_system_msg(db, "Manager",
            f"Role {role} has been replaced 2 times in the last hour. Manual intervention needed.", priority=0)
        notify_user("🚨 Replacement Loop", f"{role} replaced 2x in 1hr — needs manual fix", urgent=True)
        return

    conv_id = row["conversation_id"]
    session_id = row["session_id"]

    # Step 1: Archive
    archive_path = None
    if conv_id:
        archive_path = f"/tmp/conversation-archive-{conv_id}.json"
        data = read_kiro_conversation(conv_id)
        if data:
            try:
                Path(archive_path).write_text(json.dumps(data, indent=2))
                # Verify
                json.loads(Path(archive_path).read_text())
                logger.info("REPLACE: archived %s → %s", pane_id, archive_path)
            except Exception as e:
                logger.error("REPLACE: ABORT — archive failed for %s: %s", pane_id, e)
                return
        else:
            logger.warning("REPLACE: no conversation data for %s, proceeding without archive", pane_id)

    # Step 2: Build briefing
    briefing_path = f"/tmp/ctx-replacement-{session_id or pane_id}.md"
    briefing = _build_replacement_briefing(conv_id, reason, archive_path, row)
    Path(briefing_path).write_text(briefing)
    logger.info("REPLACE: briefing written to %s", briefing_path)

    # Step 3: Terminate (or context reset for protected)
    if protected:
        logger.info("REPLACE: protected tab %s (%s) — injecting context reset", pane_id, role)
        paste_to_pane(pane_id, briefing)
        db.execute("UPDATE registry SET status='working', consecutive_same_hash=0 WHERE pane_id=?", (pane_id,))
        db.commit()
        _hang_levels.pop(pane_id, None)
        return

    # Kill old tab
    send_ctrl_c(pane_id)
    time.sleep(10)
    pid = row["pid"]
    if pid:
        try:
            os.kill(pid, 9)
            time.sleep(5)
        except OSError:
            pass
    subprocess.run(["bash", str(Path.home() / "scripts/crew-close-tab.sh"), pane_id],
                   capture_output=True, timeout=15)
    logger.info("REPLACE: terminated %s", pane_id)

    # Step 4: Respawn
    agent = row["agent"] or ""
    tab_name = row["tab_name"] or ""
    task_text = _extract_original_task(conv_id) or f"Resume {role} work"
    try:
        subprocess.run(
            ["bash", str(Path.home() / "scripts/kiro-sub.sh"), task_text,
             "--agent", agent, "--context", briefing_path,
             "--tab-name", tab_name, "--visible"],
            capture_output=True, timeout=30,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        logger.error("REPLACE: respawn failed for %s: %s", pane_id, e)

    # Step 5: Retarget — update registry + messages
    db.execute("UPDATE registry SET status='replaced' WHERE pane_id=?", (pane_id,))
    db.execute(
        "UPDATE messages SET target_pane=NULL WHERE target_role=? AND status='pending'",
        (role,),
    )
    db.execute(
        "INSERT INTO replacement_log (old_pane_id, old_session_id, old_conversation_id, reason, archive_path, briefing_path, created_at) VALUES (?,?,?,?,?,?,?)",
        (pane_id, session_id, conv_id, reason, archive_path, briefing_path, now),
    )
    db.commit()
    _replacement_count.setdefault(role, []).append(now)
    _hang_levels.pop(pane_id, None)
    logger.info("REPLACE: completed for %s reason=%s", pane_id, reason)

    # Step 6: Verify after 60s (in background)
    threading.Timer(60, _verify_replacement, args=(role,)).start()


def _build_replacement_briefing(conv_id, reason, archive_path, row):
    """Build replacement briefing from archived conversation."""
    parts = [f"## Replacement Notice\nThis tab replaces a previous session that was {reason}."]
    if archive_path:
        parts.append(f"The conversation archive is at {archive_path}.")
    parts.append("Resume from where the previous session left off.\n")

    # Extract original task + last 8 turns
    data = read_kiro_conversation(conv_id) if conv_id else None
    if data:
        history = data.get("history", [])
        if history and history[0].get("user"):
            task = str(history[0]["user"])[:2000]
            parts.append(f"## Original Task\n{task}\n")
        if len(history) > 1:
            recent = history[-8:]
            parts.append("## Recent Context (last 8 turns)")
            for turn in recent:
                if turn.get("assistant"):
                    text = str(turn["assistant"])[:500]
                    parts.append(f"- Assistant: {text}")
    return "\n".join(parts)


def _extract_original_task(conv_id):
    """Get first user prompt from conversation."""
    data = read_kiro_conversation(conv_id) if conv_id else None
    if data:
        history = data.get("history", [])
        if history and history[0].get("user"):
            return str(history[0]["user"])[:2000]
    return None


def _verify_replacement(role):
    """Check new tab after 60s (Task 2.5 step 6)."""
    try:
        db = get_db()
        pane = db.execute("SELECT * FROM registry WHERE role=? AND status != 'replaced' ORDER BY registered_at DESC LIMIT 1", (role,)).fetchone()
        if pane:
            if pane["status"] in ("crashed", "exited"):
                logger.warning("REPLACE: new tab for %s is %s — NOT retrying (prevent loop)", role, pane["status"])
                _enqueue_system_msg(db, "Manager",
                    f"Replacement tab for {role} has status '{pane['status']}'. Manual intervention needed.", priority=0)
                notify_user("🚨 Replacement Failed", f"New {role} tab {pane['status']} — check manually", urgent=True)
            else:
                logger.info("REPLACE: verified new tab for %s — status=%s", role, pane["status"])
        db.close()
    except Exception:
        logger.exception("REPLACE: verify error for %s", role)


# ── State Snapshots (Task 2.6) ─────────────────────────────────────────────

def save_snapshot(db):
    """Serialize registry to state_snapshots. Keep last 288."""
    now = int(time.time())
    rows = db.execute("SELECT * FROM registry").fetchall()
    snapshot = [dict(r) for r in rows]
    db.execute("INSERT INTO state_snapshots (snapshot_json, created_at) VALUES (?, ?)",
               (json.dumps(snapshot), now))
    # Prune old snapshots
    db.execute("DELETE FROM state_snapshots WHERE id NOT IN (SELECT id FROM state_snapshots ORDER BY created_at DESC LIMIT 288)")
    db.commit()
    logger.info("SNAPSHOT: saved %d entries", len(snapshot))


# ── Registry ────────────────────────────────────────────────────────────────

def scan_and_populate_registry(db):
    """Scan zellij panes, populate/update registry."""
    panes = list_all_panes()
    now = int(time.time())
    live_pane_ids = set()

    for p in panes:
        pane_id = f"terminal_{p['id']}"
        live_pane_ids.add(pane_id)
        tab_name = p.get("tab_name", "")
        pane_pid = p.get("pid")
        pane_command = p.get("pane_command", "") or p.get("command", "") or ""

        # Check if already registered
        existing = db.execute("SELECT * FROM registry WHERE pane_id = ?", (pane_id,)).fetchone()

        # Try to get session ID from process environ
        session_id = None
        agent = None
        role = None
        if pane_pid:
            kiro_pid = find_kiro_pid_for_pane(pane_pid)
            if kiro_pid:
                env = read_proc_environ(kiro_pid)
                session_id = env.get("KIRO_SESSION_ID")
                if session_id:
                    info = query_session_log(session_id)
                    agent = info.get("agent", agent)

        # Infer role from tab name
        if not role:
            role = infer_role(tab_name)

        # Parse prompt for agent name and context %
        prompt_agent, ctx_pct = parse_prompt(pane_id)
        if prompt_agent and not agent:
            agent = prompt_agent

        if existing:
            updates = {"updated_at": now}
            # Only update tab_name if zellij reports a non-empty, non-default name
            # Prevents race where daemon scans before launcher renames
            if tab_name and not re.match(r"^Tab #\d+$", tab_name):
                updates["tab_name"] = tab_name
            if session_id:
                updates["session_id"] = session_id
            if agent:
                updates["agent"] = agent
            if role:
                updates["role"] = role
            if pane_pid:
                updates["pid"] = pane_pid
            updates["pane_command"] = pane_command
            if ctx_pct is not None:
                updates["context_pct"] = ctx_pct
            sets = ", ".join(f"{k} = ?" for k in updates)
            db.execute(f"UPDATE registry SET {sets} WHERE pane_id = ?", (*updates.values(), pane_id))
        else:
            db.execute(
                """INSERT INTO registry (pane_id, session_id, tab_name, agent, role, pid, pane_command,
                   context_pct, status, registered_at, updated_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'unknown', ?, ?)""",
                (pane_id, session_id, tab_name, agent, role, pane_pid, pane_command, ctx_pct or 0, now, now),
            )
            logger.info("REGISTRY: registered %s role=%s agent=%s tab=%s", pane_id, role, agent, tab_name)

    # Prune dead panes
    all_registered = [r[0] for r in db.execute("SELECT pane_id FROM registry").fetchall()]
    for pid in all_registered:
        if pid not in live_pane_ids:
            db.execute("DELETE FROM registry WHERE pane_id = ?", (pid,))
            logger.info("REGISTRY: pruned dead pane %s", pid)

    db.commit()

    # Auto-title untitled tabs (one-shot, after registry is populated)
    try:
        auto_title_tabs(db, panes)
    except Exception:
        logger.exception("AUTO-TITLE: error during tab titling")


def infer_role(tab_name):
    """Infer role from tab name patterns."""
    if not tab_name:
        return None
    # Extract explicit role IDs: W1, W2, T1, T2, etc.
    m = re.search(r'\b([WwTt]\d+)\b', tab_name)
    if m:
        return m.group(1).upper()
    t = tab_name.lower()
    if "manager" in t:
        return "Manager"
    if "planner" in t:
        return "Planner"
    if "watcher" in t:
        return "Watcher"
    if "coordinator" in t or "🎯" in tab_name:
        return "Coordinator"
    if "tester" in t or "test" in t:
        return "Tester"
    if "discover" in t:
        return "Discoverer"
    # Worker emoji patterns
    if any(e in tab_name for e in ("🟥", "🟦", "🟩", "🟨", "🟪", "🟧", "🔍")):
        return "Worker"
    return None


# ── Tab auto-title (v2) ────────────────────────────────────────────────────

_COLOR_CIRCLES = ["🔴", "🔵", "🟢", "🟡", "🟣", "🟠"]
_COLOR_EMOJIS = set(_COLOR_CIRCLES) | {"🟥", "🟦", "🟩", "🟨", "🟪", "🟧", "💚", "💙", "🧡", "❤️", "💜", "💛"}
# Status color circles — simple color = status
_STATUS_COLORS = {
    "working": "🟢",
    "idle": "🟠",
    "possibly_hung": "🟡",
    "hung": "🔴",
    "crashed": "🔴",
    "error": "🔴",
    "context_rot": "🟡",
    "done": "🔵",
}
_STOP_WORDS = frozenset(
    "the a an to and or in on at of for is it my do if by from with this that then just write read run use get set add "
    "all its into your file task sub exit done let me you can will here what how about have has been are was were not "
    "but also some any more most very much well now new first last next each every both few many such own other than "
    "too only same so no yes up out off over under back down still already even would could should might may shall "
    "need want like look make take give go come see know think say tell ask try find check start begin end stop help "
    "work call show keep turn put move play live believe hold bring happen must during before after between through "
    "against without within along following across behind beyond plus except around among per toward towards when did "
    "does why who where which please using execute result plan investigate fix debug review create update setup".split()
)
_EVENTS_DIR = Path.home() / ".local/share/kiro/tab-events"


def _extract_topic(text):
    """Extract short topic from user message. Port of lib-tab-title.sh logic."""
    if not text:
        return ""
    # 1. Plan filename
    m = re.search(r"plan-([^\s.]+)", text)
    if m:
        parts = m.group(1).split("-")[:3]
        return "-".join(parts)
    # 2. Ticket ID + context
    m = re.search(r"(TAX|QE|NEB|CSD)-\d+", text, re.IGNORECASE)
    if m:
        ticket = m.group(0).lower()
        rest = re.sub(re.escape(m.group(0)), "", text, flags=re.IGNORECASE)
        words = [w for w in re.findall(r"[a-z]{3,}", rest.lower()) if w not in _STOP_WORDS][:2]
        return f"{ticket}-{'-'.join(words)}" if words else ticket
    # 3. Stop-word filter
    words = [w for w in re.findall(r"[a-z0-9]{3,}", text.lower()) if w not in _STOP_WORDS][:3]
    return "-".join(words)


def _tab_name_has_color(name):
    """Check if tab name starts with a recognized color emoji."""
    if not name:
        return False, -1
    for idx, emoji in enumerate(_COLOR_CIRCLES):
        if name.startswith(emoji):
            return True, idx
    # Check squares and hearts too
    for idx, emoji in enumerate(["🟥", "🟦", "🟩", "🟨", "🟪", "🟧"]):
        if name.startswith(emoji):
            return True, idx
    for idx, emoji in enumerate(["💚", "💙", "🧡", "❤️", "💜", "💛"]):
        if name.startswith(emoji):
            return True, idx
    return False, -1


def _is_human_renamed(tab_id):
    """Check kiro-events JSONL for character-by-character rename pattern (human typing)."""
    today = time.strftime("%Y-%m-%d")
    logfile = _EVENTS_DIR / f"{today}.jsonl"
    if not logfile.exists():
        return False
    try:
        renames = []
        for line in logfile.read_text().splitlines():
            ev = json.loads(line)
            if ev.get("event") == "tab_renamed" and ev.get("tab_id") == tab_id:
                renames.append(ev)
        if len(renames) < 3:
            return False
        # Check last burst: >2 renames within 3 seconds = human typing
        last_few = renames[-6:]  # check last burst
        ts_list = []
        for r in last_few:
            t = r.get("ts", "")
            try:
                # Parse ISO timestamp
                dt = time.strptime(t[:19], "%Y-%m-%dT%H:%M:%S")
                ts_list.append(time.mktime(dt))
            except (ValueError, TypeError):
                continue
        if len(ts_list) >= 3:
            span = ts_list[-1] - ts_list[-3]
            if span <= 3.0:
                return True
    except (OSError, json.JSONDecodeError):
        pass
    return False


def _resolve_conv_id(pane_id):
    """Resolve conversation_id for a pane via breadcrumb file or session-log.db."""
    # Strategy 1: breadcrumb file (fast, written by conv-linker)
    # pane_id is "terminal_N" — extract the number
    pane_num = pane_id.replace("terminal_", "") if pane_id.startswith("terminal_") else pane_id
    breadcrumb = f"/tmp/.kiro-tab-conv-{pane_num}"
    try:
        if os.path.isfile(breadcrumb):
            cid = open(breadcrumb).read().strip()
            if cid:
                return cid
    except OSError:
        pass
    # Strategy 2: session-log.db — find session for this pane via KIRO_SESSION_ID in env
    return None


def _query_first_message_by_conv(conv_id):
    """Query first qualifying user message from a specific conversation."""
    if not conv_id or not KIRO_DATA_DB.exists():
        return None
    try:
        conn = sqlite3.connect(str(KIRO_DATA_DB))
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            "SELECT value FROM conversations_v2 WHERE conversation_id = ?", (conv_id,)
        ).fetchone()
        if not row:
            conn.close()
            return None
        try:
            data = json.loads(row["value"])
        except (json.JSONDecodeError, TypeError):
            conn.close()
            return None
        transcript = data.get("transcript", [])
        for i, entry in enumerate(transcript):
            if not (isinstance(entry, str) and entry.startswith("> ")):
                continue
            text = entry[2:].strip()
            if not text or text.startswith("/") or len(text) <= 15:
                continue
            # Skip session markers
            if text.startswith("<!-- kiro-session:"):
                continue
            lower = text.lower()
            if lower.startswith(("why ", "what is my", "do you think", "should ", "is this ", "how is my", "can you check")):
                continue
            has_response = any(
                isinstance(t, str) and not t.startswith("> ") and len(t.strip()) > 0
                for t in transcript[i + 1:]
            )
            if has_response:
                conn.close()
                return text
        conn.close()
    except (sqlite3.Error, OSError):
        pass
    return None


def _query_first_message(workdir, pane_pid):
    """Query kiro-cli DB for first qualifying user message with a response.
    Fallback: uses most recent conversation for workdir. Only called when pane has active kiro process."""
    if not KIRO_DATA_DB.exists():
        return None
    try:
        conn = sqlite3.connect(str(KIRO_DATA_DB))
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            "SELECT conversation_id, value FROM conversations_v2 WHERE key = ? ORDER BY updated_at DESC LIMIT 1",
            (workdir,),
        ).fetchone()
        if not row:
            conn.close()
            return None
        try:
            data = json.loads(row["value"])
        except (json.JSONDecodeError, TypeError):
            conn.close()
            return None
        transcript = data.get("transcript", [])
        for i, entry in enumerate(transcript):
            if not (isinstance(entry, str) and entry.startswith("> ")):
                continue
            text = entry[2:].strip()
            if not text or text.startswith("/") or len(text) <= 15:
                continue
            lower = text.lower()
            if lower.startswith(("why ", "what is my", "do you think", "should ", "is this ", "how is my", "can you check")):
                continue
            has_response = any(
                isinstance(t, str) and not t.startswith("> ") and len(t.strip()) > 0
                for t in transcript[i + 1:]
            )
            if has_response:
                conn.close()
                return text
        conn.close()
    except (sqlite3.Error, OSError):
        pass
    return None


def auto_title_tabs(db, panes):
    """One-shot auto-title for tabs during registry scan. Sets title once, never re-titles."""
    for p in panes:
        pane_id = f"terminal_{p['id']}"
        tab_id = p.get("tab_id")
        tab_name = p.get("tab_name", "")
        pane_pid = p.get("pid")
        workdir = None

        if tab_id is None:
            continue

        row = db.execute("SELECT title_set, title_color_idx FROM registry WHERE pane_id = ?", (pane_id,)).fetchone()
        if row and row["title_set"]:
            continue

        # Read color index from process env if available
        color_idx = None
        if pane_pid:
            kiro_pid = find_kiro_pid_for_pane(pane_pid)
            if kiro_pid:
                env = read_proc_environ(kiro_pid)
                idx_str = env.get("KIRO_PARENT_COLOR_IDX", "")
                if idx_str.isdigit():
                    color_idx = int(idx_str) % 6
                workdir = env.get("PWD") or env.get("HOME")

        has_color, existing_idx = _tab_name_has_color(tab_name)

        # Case 1: Already has color emoji — record and skip
        if has_color:
            db.execute("UPDATE registry SET title_set = 1, title_color_idx = ? WHERE pane_id = ?",
                       (existing_idx, pane_id))
            continue

        # Assign color: from env, or deterministic hash of pane_id as fallback
        if color_idx is None:
            color_idx = int(hashlib.md5(pane_id.encode()).hexdigest(), 16) % 6
        emoji = _COLOR_CIRCLES[color_idx]

        # Case 2: Untitled (Tab #N) — auto-title from first message
        if re.match(r"^Tab #\d+$", tab_name):
            # Try conv_id from breadcrumb first (reliable), then fall back to workdir query
            conv_id = _resolve_conv_id(pane_id)
            if conv_id:
                msg = _query_first_message_by_conv(conv_id)
            elif workdir:
                msg = _query_first_message(workdir, pane_pid)
            else:
                continue  # can't query DB without workdir or conv_id
            if not msg:
                continue  # no qualifying message yet, retry next scan
            topic = _extract_topic(msg)
            if not topic:
                continue
            new_name = f"{emoji} {topic}"
            zellij_cmd("rename-tab-by-id", str(tab_id), new_name)
            db.execute("UPDATE registry SET title_set = 1, title_color_idx = ?, tab_name = ? WHERE pane_id = ?",
                       (color_idx, new_name, pane_id))
            logger.info("AUTO-TITLE: %s → %s (from: %s)", pane_id, new_name, msg[:60])
            continue

        # Case 3: Has text but no color — prepend color emoji (respect human names)
        if tab_name and not has_color:
            if _is_human_renamed(tab_id):
                # Human-set name: prepend color only
                new_name = f"{emoji} {tab_name}"
            else:
                # Programmatic name without color (unusual) — prepend color
                new_name = f"{emoji} {tab_name}"
            zellij_cmd("rename-tab-by-id", str(tab_id), new_name)
            db.execute("UPDATE registry SET title_set = 1, title_color_idx = ?, tab_name = ? WHERE pane_id = ?",
                       (color_idx, new_name, pane_id))
            logger.info("AUTO-TITLE: prepend color %s → %s", pane_id, new_name)

    db.commit()


def _update_tab_status_color(db, pane_id, status):
    """Update tab name color emoji to reflect agent status."""
    row = db.execute("SELECT tab_name FROM registry WHERE pane_id = ?", (pane_id,)).fetchone()
    if not row or not row["tab_name"]:
        return
    tab_name = row["tab_name"]
    new_emoji = _STATUS_COLORS.get(status, "🟠")

    # Replace leading color/shape emoji
    replaced = False
    for e in sorted(_COLOR_EMOJIS, key=len, reverse=True):
        if tab_name.startswith(e):
            new_name = new_emoji + tab_name[len(e):]
            replaced = True
            break
    if not replaced:
        new_name = new_emoji + " " + tab_name

    if new_name == tab_name:
        return  # no change needed

    pane_tab_map = _build_pane_tab_map()
    tab_id = pane_tab_map.get(pane_id)
    if tab_id is not None:
        zellij_cmd("rename-tab-by-id", str(tab_id), new_name)
    db.execute("UPDATE registry SET tab_name = ? WHERE pane_id = ?", (new_name, pane_id))


# ── Dedup on enqueue (Task 3.3) ─────────────────────────────────────────────

def dedup_check(db, chash):
    """Return True if message should be rejected (duplicate)."""
    if not chash:
        return False
    now = int(time.time())
    ten_min_ago = now - 600
    # Check pending with same hash
    pending = db.execute(
        "SELECT id FROM messages WHERE content_hash = ? AND status = 'pending' LIMIT 1", (chash,)
    ).fetchone()
    if pending:
        return True
    # Check recently delivered with same hash
    recent = db.execute(
        "SELECT id FROM messages WHERE content_hash = ? AND status = 'delivered' AND delivered_at > ? LIMIT 1",
        (chash, ten_min_ago),
    ).fetchone()
    return recent is not None


# ── Dispatch + Merge (Tasks 3.1, 3.2, 3.3) ─────────────────────────────────

def content_hash(text):
    normalized = re.sub(r'\s+', ' ', text.strip().lower())
    return hashlib.sha256(normalized.encode()).hexdigest()


def _update_dependency_tracking(db, target_role, delivered_msgs):
    """T2: Update waiting_on/working_for based on message delivery.

    When sender A sends to target B and it's delivered:
      - A.waiting_on += B (A is now waiting on B)
      - B.working_for = A
    When B sends to A (response):
      - Clear B from A.waiting_on
    """
    senders = {m["sender"] for m in delivered_msgs if m["sender"] and m["sender"] != "daemon"}
    for sender in senders:
        # Sender is now waiting on target_role
        row = db.execute("SELECT waiting_on FROM registry WHERE role=?", (sender,)).fetchone()
        if row:
            current = set(filter(None, (row["waiting_on"] or "").split(",")))
            current.add(target_role)
            db.execute("UPDATE registry SET waiting_on=? WHERE role=?",
                       (",".join(sorted(current)), sender))
        # Target is working for sender
        db.execute("UPDATE registry SET working_for=? WHERE role=?",
                   (sender, target_role))
        # Clear sender from target_role's waiting_on (this is a response)
        tgt_row = db.execute("SELECT waiting_on FROM registry WHERE role=?", (target_role,)).fetchone()
        if tgt_row and tgt_row["waiting_on"]:
            current = set(tgt_row["waiting_on"].split(","))
            current.discard(sender)
            db.execute("UPDATE registry SET waiting_on=? WHERE role=?",
                       (",".join(sorted(current)) or None, target_role))
    db.commit()


def _load_daemon_config():
    """Load daemon.json config."""
    try:
        if DAEMON_CONFIG.exists():
            return json.loads(DAEMON_CONFIG.read_text())
    except (json.JSONDecodeError, OSError):
        pass
    return {}


def deliver_via_file(pane_id, role, messages, batch_id):
    """Write messages to pane's file inbox (file-based messaging)."""
    inbox_dir = Path(f"/tmp/agents-msg/{pane_id}/pending")
    inbox_dir.mkdir(parents=True, exist_ok=True)
    now_ms = int(time.time() * 1000)
    for i, msg in enumerate(messages):
        msg_id = f"{now_ms + i}-{batch_id[:6]}"
        payload = json.dumps({
            "id": msg_id,
            "ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "from": msg.get("sender", "daemon"),
            "from_role": msg.get("sender_role", role),
            "priority": msg.get("priority", 1),
            "type": "task",
            "subject": (msg.get("payload", "") or "")[:80],
            "body": msg.get("payload", ""),
            "reply_to": None,
            "ttl_seconds": 3600,
        }, indent=2)
        tmp = inbox_dir / f".tmp-{msg_id}"
        tmp.write_text(payload)
        tmp.rename(inbox_dir / f"{msg_id}.json")
    logger.info("DISPATCH-FILE: wrote %d msgs to %s/pending/ batch=%s", len(messages), pane_id, batch_id)
    return True


def dispatch_messages(db):
    """For each role with pending messages, check idle, deliver with merge."""
    # Check pause signal (with auto-resume for timed pauses)
    if os.path.exists(PAUSE_SIGNAL):
        try:
            content = open(PAUSE_SIGNAL).read()
            # Check for resume_after=N (seconds)
            m = re.search(r"resume_after=(\d+)", content)
            if m:
                pause_age = time.time() - os.path.getmtime(PAUSE_SIGNAL)
                if pause_age >= int(m.group(1)):
                    os.remove(PAUSE_SIGNAL)
                    logger.info("HEALTH: auto-resumed after %ds pause", int(pause_age))
                else:
                    return  # still paused
            else:
                return  # permanent pause (hard_limit, auth_fail)
        except (OSError, ValueError):
            return
    now = int(time.time())
    ten_min_ago = now - 600

    # Promote unconfirmed deliveries back to pending for retry (max 2 retries)
    db.execute(
        "UPDATE messages SET status = 'pending' "
        "WHERE status = 'delivered_unconfirmed' AND retry_count < 2"
    )
    # Give up after 2 retries — mark as delivered (best-effort)
    db.execute(
        "UPDATE messages SET status = 'delivered' "
        "WHERE status = 'delivered_unconfirmed' AND retry_count >= 2"
    )
    db.commit()

    roles = db.execute(
        "SELECT DISTINCT target_role FROM messages WHERE status = 'pending'"
    ).fetchall()

    for (role,) in roles:
        pane = db.execute(
            "SELECT pane_id FROM registry WHERE role = ? AND pane_id IS NOT NULL ORDER BY updated_at DESC",
            (role,),
        ).fetchone()
        if not pane:
            continue
        pane_id = pane[0]

        if not prompt_line_clean(pane_id):
            continue

        msgs = db.execute(
            """SELECT id, payload, content_hash, sender, priority FROM messages
               WHERE target_role = ? AND status = 'pending'
               ORDER BY priority ASC, created_at ASC""",
            (role,),
        ).fetchall()
        if not msgs:
            continue

        # Dedup against recent deliveries (Task 3.3)
        recent_hashes = {
            r[0] for r in db.execute(
                "SELECT content_hash FROM messages WHERE status = 'delivered' AND delivered_at > ? AND content_hash IS NOT NULL",
                (ten_min_ago,),
            ).fetchall()
        }
        # Also dedup within the batch
        seen_hashes = set()
        to_deliver = []
        for msg in msgs:
            ch = msg["content_hash"]
            if ch and (ch in recent_hashes or ch in seen_hashes):
                db.execute("UPDATE messages SET status = 'deduped', error = 'duplicate' WHERE id = ?", (msg["id"],))
                logger.info("DISPATCH: deduped msg %d for %s", msg["id"], role)
                continue
            if ch:
                seen_hashes.add(ch)
            to_deliver.append(msg)

        if not to_deliver:
            db.commit()
            continue

        batch_id = str(uuid.uuid4())[:8]

        # File-based messaging (2026-05-21): write to inbox, agent picks up via kiro-bash-guard.sh
        if _load_daemon_config().get("file_messaging"):
            deliver_via_file(pane_id, role, to_deliver, batch_id)
            for msg in to_deliver:
                db.execute(
                    "UPDATE messages SET status='delivered', delivered_at=?, dispatched_at=?, target_pane=?, merge_batch_id=? WHERE id=?",
                    (now, now, pane_id, batch_id, msg["id"]),
                )
            logger.info("DISPATCH-FILE: delivered %d msgs to %s (%s) batch=%s",
                        len(to_deliver), role, pane_id, batch_id)
            _p0_alerted.discard(role)
            _update_dependency_tracking(db, role, to_deliver)
        else:
            # Legacy paste path
            priorities = {m["priority"] for m in to_deliver}
            mixed = len(priorities) > 1
            use_llm = len(to_deliver) >= LLM_MERGE_THRESHOLD or mixed

            if use_llm:
                merged = _llm_merge(role, to_deliver, batch_id)
            else:
                merged = _template_merge(role, to_deliver)

            if paste_to_pane(pane_id, merged):
                confirmed = confirm_delivery(pane_id, timeout=8)
                status = "delivered" if confirmed else "delivered_unconfirmed"
                for msg in to_deliver:
                    db.execute(
                        "UPDATE messages SET status=?, delivered_at=?, dispatched_at=?, target_pane=?, merge_batch_id=? WHERE id=?",
                        (status, now, now, pane_id, batch_id, msg["id"]),
                    )
                if confirmed:
                    logger.info("DISPATCH: delivered %d msgs to %s (%s) merge=%s batch=%s [confirmed]",
                                len(to_deliver), role, pane_id, "llm" if use_llm else "template", batch_id)
                    _p0_alerted.discard(role)
                else:
                    logger.warning("DISPATCH: delivered %d msgs to %s (%s) but agent did not pick up [unconfirmed] batch=%s",
                                   len(to_deliver), role, pane_id, batch_id)
                _update_dependency_tracking(db, role, to_deliver)
            else:
                for msg in to_deliver:
                    db.execute(
                        "UPDATE messages SET retry_count = retry_count + 1, error = 'paste failed' WHERE id = ?",
                        (msg["id"],),
                    )
                logger.warning("DISPATCH: paste failed for %s (%s)", role, pane_id)

    db.commit()


def update_message_indicators(db):
    """Add 📬 to tabs with pending messages, remove when delivered."""
    pending_roles = {
        r[0] for r in db.execute(
            "SELECT DISTINCT target_role FROM messages WHERE status = 'pending'"
        ).fetchall()
    }
    # Check if any work needed: pending roles or existing indicators
    rows = db.execute("SELECT pane_id, role, tab_name FROM registry WHERE role IS NOT NULL").fetchall()
    changes = []
    for row in rows:
        tab_name = row["tab_name"] or ""
        role = row["role"]
        has_indicator = "📬" in tab_name
        has_pending = role in pending_roles
        if has_pending and not has_indicator:
            if tab_name and any(tab_name.startswith(e) for e in _COLOR_EMOJIS):
                for e in sorted(_COLOR_EMOJIS, key=len, reverse=True):
                    if tab_name.startswith(e):
                        new_name = e + "📬" + tab_name[len(e):]
                        break
            else:
                new_name = "📬 " + tab_name
            changes.append((row["pane_id"], new_name, role, "add"))
        elif not has_pending and has_indicator:
            new_name = tab_name.replace("📬", "").replace("  ", " ")
            changes.append((row["pane_id"], new_name, role, "remove"))

    if not changes:
        return

    # Single list-panes call to build pane→tab_id map
    pane_tab_map = _build_pane_tab_map()
    for pane_id, new_name, role, action in changes:
        tab_id = pane_tab_map.get(pane_id)
        if tab_id is not None:
            zellij_cmd("rename-tab-by-id", str(tab_id), new_name)
        db.execute("UPDATE registry SET tab_name = ? WHERE pane_id = ?", (new_name, pane_id))
        logger.info("MSG-INDICATOR: %s 📬 %s %s (%s)", "added" if action == "add" else "removed", "to" if action == "add" else "from", role, pane_id)
    db.commit()


def _build_pane_tab_map():
    """Single list-panes call → {pane_id: tab_id} dict."""
    try:
        out = zellij_cmd("list-panes", "--json", "--all")
        if not out:
            return {}
        return {f"terminal_{p['id']}": p.get("tab_id") for p in json.loads(out) if not p.get("is_plugin", True)}
    except (json.JSONDecodeError, KeyError):
        return {}


def _append_checklist(role, text):
    """Append role checklist if it exists."""
    checklist_file = CHECKLIST_DIR / f"{role}.txt"
    if checklist_file.exists():
        checklist = checklist_file.read_text().strip()
        if checklist:
            text += f"\n\n[CHECKLIST: {checklist}]"
    return text


def _template_merge(role, msgs):
    """Task 3.1: Template merge (zero-cost). 1-3 msgs same priority."""
    if len(msgs) == 1:
        return _append_checklist(role, msgs[0]["payload"])
    parts = [f"You have {len(msgs)} pending items:\n"]
    for i, msg in enumerate(msgs, 1):
        sender = msg["sender"] or "system"
        parts.append(f"## {i}. [P{msg['priority']}] From {sender}:\n{msg['payload']}")
    return _append_checklist(role, "\n\n".join(parts))


def _save_merge_originals(msgs, batch_id):
    """Save original payloads before LLM merge."""
    MERGE_ORIGINALS_DIR.mkdir(parents=True, exist_ok=True)
    data = [{"id": m["id"], "sender": m["sender"], "priority": m["priority"], "payload": m["payload"]} for m in msgs]
    (MERGE_ORIGINALS_DIR / f"{batch_id}.json").write_text(json.dumps(data, indent=2))


def _llm_merge(role, msgs, batch_id):
    """Task 3.2: LLM merge via Haiku. Fallback chain: Haiku → template → individual."""
    _save_merge_originals(msgs, batch_id)

    # Try Haiku
    try:
        import anthropic
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            raise RuntimeError("no ANTHROPIC_API_KEY")

        # Build input
        items = []
        for i, msg in enumerate(msgs, 1):
            items.append(f"{i}. [P{msg['priority']}] From {msg['sender'] or 'system'}:\n{msg['payload']}")
        input_text = "\n\n".join(items)
        input_len = len(input_text)

        system_prompt = f"""Combine these messages into one coherent briefing for a {role} agent.
Rules:
- P0 alerts FIRST, then P1 results, then P2 reminders
- Deduplicate: if same information appears twice, include once
- Preserve all actionable details — file paths, commands, error messages
- Be concise but don't lose information
- Output format: numbered list grouped by priority"""

        # Set SSL bundle for Zscaler
        ca_bundle = os.environ.get("REQUESTS_CA_BUNDLE")
        kwargs = {}
        if ca_bundle:
            import httpx
            kwargs["http_client"] = httpx.Client(verify=ca_bundle)

        client = anthropic.Anthropic(api_key=api_key, timeout=10.0, **kwargs)
        resp = client.messages.create(
            model="claude-haiku-3.5",
            max_tokens=2000,
            system=system_prompt,
            messages=[{"role": "user", "content": input_text}],
        )
        output = resp.content[0].text.strip()

        # Validate (Task 3.2 safeguards)
        if len(output) < input_len * 0.2:
            logger.warning("MERGE: LLM output too short (%d vs %d input), falling back to template", len(output), input_len)
            return _template_merge(role, msgs)
        if any(phrase in output.lower() for phrase in REFUSAL_PHRASES):
            logger.warning("MERGE: LLM output contains refusal, falling back to template")
            return _template_merge(role, msgs)

        logger.info("MERGE: LLM merge success for %s, %d msgs → %d chars (batch=%s)", role, len(msgs), len(output), batch_id)
        return _append_checklist(role, output)

    except Exception as e:
        logger.warning("MERGE: LLM merge failed (%s), falling back to template", e)
        return _template_merge(role, msgs)


# ── Signal Decision Poller ─────────────────────────────────────────────────

def _execute_signal_action(db, signal_row, action):
    """Execute a resolved signal action. Returns (success, reason)."""
    pane_id = signal_row["pane_id"]
    role = signal_row["role"] or ""
    if action == "ctrl_c":
        send_ctrl_c(pane_id)
        return True, "ctrl_c sent"
    elif action == "replace":
        trigger_replacement(db, pane_id, signal_row["signal_type"])
        return True, "replacement triggered"
    elif action == "nudge":
        evidence = json.loads(signal_row["evidence_json"] or "{}")
        waiter = evidence.get("waiter")
        if waiter and signal_row["signal_type"] == "deadlock_detected":
            msg = f"{waiter} is waiting on your output. Check your current task and proceed."
        else:
            msg = "You appear stuck. Check your current task and proceed."
        _enqueue_system_msg(db, role, msg, priority=1)
        return True, "nudge enqueued"
    elif action in ("ignore", "reject"):
        return True, f"action={action}, no-op"
    else:
        logger.warning("SIGNAL: unknown action '%s' for %s", action, signal_row["id"])
        return False, f"unknown action: {action}"


def record_pattern(db, signal_row, action):
    """Record or update a decision pattern. Check graduation."""
    now = int(time.time())
    screen_text = json.loads(signal_row["evidence_json"] or "{}").get("screen_tail_10", "")
    role_cat = signal_row["role_category"] or "worker"
    sig = compute_screen_signature(signal_row["signal_type"], role_cat, screen_text)
    is_reject = action in ("reject", "ignore")

    existing = db.execute(
        "SELECT * FROM decision_patterns WHERE signal_type=? AND role_category=? AND screen_signature=? AND resolution=?",
        (signal_row["signal_type"], role_cat, sig, action)).fetchone()

    if existing:
        if is_reject:
            db.execute("UPDATE decision_patterns SET user_rejected=user_rejected+1, occurrences=occurrences+1, last_seen=?, auto_approved=0, graduated_at=NULL WHERE id=?",
                       (now, existing["id"]))
        else:
            db.execute("UPDATE decision_patterns SET user_approved=user_approved+1, occurrences=occurrences+1, last_seen=? WHERE id=?",
                       (now, existing["id"]))
        db.commit()
        # Check graduation
        row = db.execute("SELECT * FROM decision_patterns WHERE id=?", (existing["id"],)).fetchone()
        if not row["auto_approved"] and row["user_approved"] >= 3 and row["user_rejected"] == 0:
            db.execute("UPDATE decision_patterns SET auto_approved=1, graduated_at=? WHERE id=?", (now, row["id"]))
            db.commit()
            logger.info("PATTERN: graduated #%d type=%s res=%s after %d approvals", row["id"], row["signal_type"], row["resolution"], row["user_approved"])
        return existing["id"]
    else:
        cur = db.execute(
            "INSERT INTO decision_patterns (signal_type,role_category,screen_signature,resolution,occurrences,user_approved,user_rejected,last_seen,created_at) VALUES (?,?,?,?,1,?,?,?,?)",
            (signal_row["signal_type"], role_cat, sig, action, 0 if is_reject else 1, 1 if is_reject else 0, now, now))
        db.commit()
        logger.info("PATTERN: new #%d type=%s sig=%s res=%s", cur.lastrowid, signal_row["signal_type"], sig, action)
        return cur.lastrowid


def _record_rejection(db, signal_row):
    """On reject: increment user_rejected on the proposed action's pattern, revoke graduation."""
    now = int(time.time())
    screen_text = json.loads(signal_row["evidence_json"] or "{}").get("screen_tail_10", "")
    role_cat = signal_row["role_category"] or "worker"
    sig = compute_screen_signature(signal_row["signal_type"], role_cat, screen_text)
    proposed = signal_row["proposed_action"]
    existing = db.execute(
        "SELECT id FROM decision_patterns WHERE signal_type=? AND role_category=? AND screen_signature=? AND resolution=?",
        (signal_row["signal_type"], role_cat, sig, proposed)).fetchone()
    if existing:
        db.execute("UPDATE decision_patterns SET user_rejected=user_rejected+1, auto_approved=0, graduated_at=NULL, last_seen=? WHERE id=?",
                   (now, existing["id"]))
        db.commit()
        logger.info("PATTERN: rejection recorded on #%d, graduation revoked", existing["id"])


def poll_signal_decisions(db):
    """Check for decision files matching pending signals. Execute and record."""
    now = int(time.time())
    pending = db.execute(
        "SELECT * FROM signals WHERE status='pending' AND created_at>?", (now - 3600,)
    ).fetchall()

    for sig in pending:
        sig_id = sig["id"]
        dec_path = SIGNAL_DIR / f"{sig_id}.decision.json"

        if not dec_path.exists():
            # Overnight auto-approve: if auto_approve_at has passed and no decision yet
            if sig["auto_approve_at"] and now >= sig["auto_approve_at"]:
                decision = {"signal_id": sig_id, "action": sig["proposed_action"],
                            "decided_by": "overnight_auto", "decided_at": now}
                dec_path.write_text(json.dumps(decision) + "\n")
                logger.info("SIGNAL: overnight auto-approved %s after %ds", sig_id, now - sig["created_at"])
            else:
                continue

        try:
            decision = json.loads(dec_path.read_text())
        except (json.JSONDecodeError, OSError) as e:
            logger.warning("SIGNAL: bad decision file for %s: %s", sig_id, e)
            continue

        action = decision.get("action", sig["proposed_action"])
        decided_by = decision.get("decided_by", "unknown")

        # Execute
        success, reason = _execute_signal_action(db, sig, action)
        new_status = "resolved" if success else "blocked"

        # Update signal
        db.execute("UPDATE signals SET status=?, decided_action=?, decided_by=?, decided_at=? WHERE id=?",
                   (new_status, action, decided_by, now, sig_id))

        # Record resolution
        latency = now - sig["created_at"]
        db.execute(
            "INSERT INTO resolutions (signal_id,signal_type,role,action_taken,decided_by,latency_sec,created_at) VALUES (?,?,?,?,?,?,?)",
            (sig_id, sig["signal_type"], sig["role"], action, decided_by, latency, now))

        # Record pattern (only on success, or rejection against proposed action)
        if success and action not in ("reject",):
            pattern_id = record_pattern(db, sig, action)
            db.execute("UPDATE signals SET pattern_id=? WHERE id=?", (pattern_id, sig_id))
            db.execute("UPDATE resolutions SET pattern_id=? WHERE signal_id=?", (pattern_id, sig_id))
        elif action == "reject":
            # Rejection: increment user_rejected on the proposed action's pattern
            _record_rejection(db, sig)

        db.commit()

        # Cleanup files
        try:
            (SIGNAL_DIR / f"{sig_id}.json").unlink(missing_ok=True)
            dec_path.unlink(missing_ok=True)
        except OSError:
            pass

        logger.info("SIGNAL: resolved %s action=%s by=%s status=%s latency=%ds",
                     sig_id, action, decided_by, new_status, latency)

    # Expire old pending signals (>1hr)
    expired = db.execute(
        "SELECT * FROM signals WHERE status='pending' AND created_at<?", (now - 3600,)
    ).fetchall()
    for sig in expired:
        db.execute("UPDATE signals SET status='expired' WHERE id=?", (sig["id"],))
        try:
            (SIGNAL_DIR / f"{sig['id']}.json").unlink(missing_ok=True)
        except OSError:
            pass
    if expired:
        db.commit()
        logger.info("SIGNAL: expired %d stale signals", len(expired))


def check_pattern_decay(db):
    """Demote patterns unseen for 14 days."""
    cutoff = int(time.time()) - 14 * 86400
    demoted = db.execute(
        "UPDATE decision_patterns SET auto_approved=0, graduated_at=NULL WHERE auto_approved=1 AND last_seen<?",
        (cutoff,))
    if demoted.rowcount:
        db.commit()
        logger.info("PATTERN: decayed %d stale patterns (unseen >14d)", demoted.rowcount)


def batch_morning_alerts(db):
    """Write morning summary of overnight activity to /tmp/.crew-alerts/."""
    now = int(time.time())
    today = time.strftime("%Y-%m-%d")
    alert_path = Path(f"/tmp/.crew-alerts/morning-{today}.md")
    if alert_path.exists():
        return  # already generated today

    cfg = _load_config()
    start_hour = cfg.get("overnight_start_hour", 23)
    # Compute overnight window start (previous day at start_hour)
    t = time.localtime(now)
    overnight_start = now - (t.tm_hour * 3600 + t.tm_min * 60 + t.tm_sec) - (24 - start_hour) * 3600

    # Pending signals (need decisions)
    pending = db.execute(
        "SELECT id, signal_type, severity, role, created_at FROM signals WHERE status='pending' AND created_at>?",
        (overnight_start,)).fetchall()

    # Auto-resolved overnight
    auto = db.execute(
        "SELECT id, signal_type, role, decided_action FROM signals WHERE status='resolved' AND decided_by='overnight_auto' AND created_at>?",
        (overnight_start,)).fetchall()

    # Blocked
    blocked = db.execute(
        "SELECT id, signal_type, role, decided_action FROM signals WHERE status='blocked' AND created_at>?",
        (overnight_start,)).fetchall()

    # DLQ
    dlq = db.execute(
        "SELECT original_msg_id, reason, target_role FROM dead_letters WHERE created_at>?",
        (overnight_start,)).fetchall()

    if not (pending or auto or blocked or dlq):
        return  # quiet night

    lines = [f"# Morning Crew Alert — {today}\n"]

    if pending:
        lines.append("## Pending Signals (need your decision)")
        for s in pending:
            age = time.strftime("%H:%M", time.localtime(s["created_at"]))
            lines.append(f"- [{s['id']}] {s['severity']} {s['signal_type']} on {s['role']} (queued {age})")
        lines.append("")

    if auto:
        lines.append("## Auto-Resolved Overnight")
        for s in auto:
            lines.append(f"- [{s['id']}] {s['decided_action']} on {s['role']}")
        lines.append("")

    if blocked:
        lines.append("## Blocked Actions (safe_inject rejected)")
        for s in blocked:
            lines.append(f"- [{s['id']}] {s['decided_action']} on {s['role']}")
        lines.append("")

    if dlq:
        lines.append(f"## Dead Letters ({len(dlq)} messages)")
        for d in dlq:
            lines.append(f"- msg #{d['original_msg_id']} ({d['reason']}) role={d['target_role']}")
        lines.append("")

    alert_path.parent.mkdir(parents=True, exist_ok=True)
    alert_path.write_text("\n".join(lines) + "\n")

    summary = f"{len(pending)} pending, {len(auto)} auto-resolved, {len(blocked)} blocked, {len(dlq)} DLQ"
    notify_user("☀️ Morning crew summary", summary)
    logger.info("MORNING: alert written to %s — %s", alert_path, summary)


# ── Priority Escalation (Task 3.4) ─────────────────────────────────────────

def check_priority_escalation(db):
    """Promote P1→P0 after 10min. Alert on stale P0."""
    now = int(time.time())

    # P1 pending >10 min → promote to P0 (only if target is not actively working)
    stale_p1 = db.execute(
        "SELECT id, target_role FROM messages WHERE status = 'pending' AND priority = 1 AND created_at < ?",
        (now - ESCALATION_P1_TO_P0,),
    ).fetchall()
    promoted = 0
    for msg in stale_p1:
        target = db.execute("SELECT consecutive_same_hash FROM registry WHERE role = ?", (msg["target_role"],)).fetchone()
        if target and (target["consecutive_same_hash"] or 0) == 0:
            continue  # target screen changing — agent is working, don't promote
        db.execute("UPDATE messages SET priority = 0 WHERE id = ?", (msg["id"],))
        promoted += 1
    if promoted > 0:
        logger.info("ESCALATION: promoted %d P1 messages pending >10min to P0 (skipped working targets)", promoted)

    # P0 pending >5 min → write alert file + terminal bell
    stale_p0 = db.execute(
        "SELECT DISTINCT target_role FROM messages WHERE status = 'pending' AND priority = 0 AND created_at < ?",
        (now - ALERT_P0_FILE,),
    ).fetchall()
    for (role,) in stale_p0:
        # Sanitize role for filename (guard against corrupted DB entries)
        safe_role = re.sub(r'[^a-zA-Z0-9_-]', '', role)[:50] if role else 'unknown'
        alert_path = Path(f"/tmp/.crew-alert-{safe_role}.txt")
        alert_path.write_text(f"P0 alert pending for {safe_role} since {time.strftime('%H:%M:%S', time.localtime(now))}\n")
        sys.stdout.write("\a")  # terminal bell
        sys.stdout.flush()

    # P0 pending >15 min → inject into legacy/watcher tab (once per role, skip if target working)
    very_stale = db.execute(
        "SELECT DISTINCT target_role FROM messages WHERE status = 'pending' AND priority = 0 AND created_at < ?",
        (now - ALERT_P0_INJECT,),
    ).fetchall()
    for (role,) in very_stale:
        # Skip if already alerted for this role (dedup)
        if role in _p0_alerted:
            continue
        # Skip if target is actively working (screen changing = not hung)
        target = db.execute("SELECT pane_id, consecutive_same_hash FROM registry WHERE role = ?", (role,)).fetchone()
        if target and (target["consecutive_same_hash"] or 0) == 0:
            continue  # screen is changing — agent is working, just slow
        # Find watcher or manager pane to inject alert
        watcher = db.execute(
            "SELECT pane_id FROM registry WHERE role IN ('Watcher','Manager') ORDER BY role ASC LIMIT 1"
        ).fetchone()
        if watcher:
            paste_to_pane(watcher[0], f"⚠️ ALERT: P0 message for {role} has been pending >15 min!")
            logger.warning("ESCALATION: injected P0 alert for %s into legacy tab", role)
        notify_user("🔴 P0 Undelivered", f"P0 for {role} pending >15min!", urgent=True)
        _p0_alerted.add(role)

    db.commit()


# ── DLQ (Task 4.1) ─────────────────────────────────────────────────────────

def move_to_dlq(db):
    """Move expired/failed/orphaned messages to dead letter queue."""
    global _last_dlq_notify
    now = int(time.time())
    one_hour_ago = now - 3600

    # 3+ failed deliveries
    failed = db.execute(
        "SELECT id, payload, target_role FROM messages WHERE status = 'pending' AND retry_count >= 3"
    ).fetchall()
    for msg in failed:
        _dlq_insert(db, msg, "max_retries", now)

    # Expired (>1 hour old)
    expired = db.execute(
        "SELECT id, payload, target_role FROM messages WHERE status = 'pending' AND created_at < ?",
        (one_hour_ago,),
    ).fetchall()
    for msg in expired:
        _dlq_insert(db, msg, "expired", now)

    # No target pane for 10+ min (Task 4.1)
    orphaned = db.execute(
        "SELECT m.id, m.payload, m.target_role FROM messages m WHERE m.status = 'pending' AND m.created_at < ? "
        "AND NOT EXISTS (SELECT 1 FROM registry r WHERE r.role = m.target_role)",
        (now - DLQ_NO_TARGET_TIMEOUT,),
    ).fetchall()
    for msg in orphaned:
        _dlq_insert(db, msg, "target_gone", now)

    # Notify only when DLQ count increases (new entries), not repeatedly for stale ones
    global _last_dlq_count
    dlq_count = db.execute("SELECT COUNT(*) FROM dead_letters").fetchone()[0]
    if dlq_count > _last_dlq_count:
        new_entries = dlq_count - _last_dlq_count
        notify_user("📬 Dead Letters", f"{new_entries} new dead letter(s) ({dlq_count} total). Run crew-ctl dlq")
        logger.info("DLQ: %d new dead letters (%d total)", new_entries, dlq_count)
        _last_dlq_notify = now
    _last_dlq_count = dlq_count

    db.commit()


def _dlq_insert(db, msg, reason, now):
    """Move a message to DLQ."""
    db.execute(
        "INSERT INTO dead_letters (original_msg_id, reason, payload, target_role, created_at) VALUES (?, ?, ?, ?, ?)",
        (msg["id"], reason, msg["payload"], msg["target_role"], now),
    )
    db.execute("UPDATE messages SET status = 'dlq' WHERE id = ?", (msg["id"],))
    logger.info("DLQ: msg %d moved (%s) role=%s", msg["id"], reason, msg["target_role"])


# ── Reminder System (Task 4.2) ─────────────────────────────────────────────

def check_reminders(db):
    """Idle reminders: 15min → P2, 30min → P1. Max 1/pane/15min."""
    now = int(time.time())
    rows = db.execute("SELECT * FROM registry WHERE status = 'idle'").fetchall()

    for row in rows:
        pane_id = row["pane_id"]
        role = row["role"]
        if not role:
            continue

        # Cooldown check
        last = _last_reminder.get(pane_id, 0)
        if now - last < REMINDER_COOLDOWN:
            continue

        # Skip if there are pending messages for this role (they ARE the reminder)
        pending = db.execute(
            "SELECT COUNT(*) FROM messages WHERE target_role = ? AND status = 'pending'", (role,)
        ).fetchone()[0]
        if pending > 0:
            continue

        last_change = row["last_screen_change"] or now
        idle_min = (now - last_change) / 60

        if idle_min >= 30:
            _enqueue_system_msg(db, role,
                "Idle for 30 min. If blocked, write state to file and request help.", priority=1)
            _last_reminder[pane_id] = now
            logger.info("REMIND: P1 30min reminder for %s (%s)", pane_id, role)
        elif idle_min >= 15:
            _enqueue_system_msg(db, role,
                "You've been idle for 15 min. Check your current task status and proceed.", priority=2)
            _last_reminder[pane_id] = now
            logger.info("REMIND: P2 15min reminder for %s (%s)", pane_id, role)


# ── Planner Idle Elimination ───────────────────────────────────────────────

HS_RESULTS_DIR = os.path.expanduser("~/vault/skills/studenths-crew/results")
HS_BRIEFINGS_DIR = os.path.expanduser("~/vault/skills/studenths-crew/briefings")
HS_DISCOVERY_DIR = os.path.expanduser("~/vault/skills/studenths-crew/discovery")

_PLANNER_NUDGE_COOLDOWN = 45
_PLANNER_GRACE_PERIOD = 10
_PLANNER_ALERT_THRESHOLD = 120

_PLANNER_CONTEXT_GATES = [
    (85, 0),   # >85% → P0 only
    (75, 1),   # 75-85% → P0-P1
    (60, 3),   # 60-75% → P0-P3
    (0,  5),   # <60% → all
]


def _planner_max_priority(ctx_pct):
    """Return max allowed priority tier for given context %."""
    for threshold, max_p in _PLANNER_CONTEXT_GATES:
        if ctx_pct > threshold:
            return max_p
    return 5


def _planner_get_state(db):
    return db.execute("SELECT * FROM planner_idle_state ORDER BY id DESC LIMIT 1").fetchone()


def _planner_update_state(db, **kwargs):
    sets = ", ".join(f"{k}=?" for k in kwargs)
    vals = list(kwargs.values())
    db.execute(f"UPDATE planner_idle_state SET {sets} WHERE id = (SELECT MAX(id) FROM planner_idle_state)", vals)
    db.commit()


def _check_p0_arrived_results(nudged_paths):
    if not os.path.isdir(HS_RESULTS_DIR):
        return None
    for f in sorted(os.listdir(HS_RESULTS_DIR)):
        if f.startswith("wave-") and f.endswith("-report.md"):
            full = os.path.join(HS_RESULTS_DIR, f)
            if full not in nudged_paths:
                return {"tier": "P0", "text": f"Wave report ready: {full} — review it now.", "mark_path": full}
    return None


def _check_p1_overdue(state):
    if not state or not state["last_dispatch_at"]:
        return None
    elapsed = int(time.time()) - state["last_dispatch_at"]
    expected = state["expected_result_path"]
    if elapsed > 300 and expected and not os.path.exists(expected):
        return {"tier": "P1", "text": f"Wave dispatched {elapsed // 60}min ago. Expected result at {expected} not found. Check Manager status."}
    return None


def _check_p2_briefing(state):
    if not state or not state["next_wave_name"]:
        return None
    briefing_path = os.path.join(HS_BRIEFINGS_DIR, f"{state['next_wave_name']}.md")
    if not os.path.exists(briefing_path):
        return {"tier": "P2", "text": f"Manager still executing. Draft next wave briefing: {briefing_path}"}
    return None


def _check_p3_knowledge(state):
    if not state:
        return None
    waves = state["waves_since_knowledge_update"] or 0
    if waves >= 2:
        return {"tier": "P3", "text": f"Knowledge.md stale ({waves} waves since last update). Append patterns from recent wave results."}
    return None


def _check_p4_gaps():
    if not os.path.isdir(HS_DISCOVERY_DIR):
        return None
    for f in sorted(os.listdir(HS_DISCOVERY_DIR)):
        if f.startswith("gaps-") and f.endswith(".md"):
            full = os.path.join(HS_DISCOVERY_DIR, f)
            if time.time() - os.path.getmtime(full) < 86400:
                return {"tier": "P4", "text": f"While waiting: review gap report {full} for upcoming work."}
    return None


def _check_p5_revise(state):
    if not state:
        return None
    waves = state["waves_since_knowledge_update"] or 0
    if waves >= 3:
        return {"tier": "P5", "text": "3+ waves complete. Re-read your plan — any tasks to reorder or drop based on results?"}
    return None


def _find_planner_work_item(db, max_priority, state):
    """Return highest-priority applicable work item, or None."""
    nudged_paths = json.loads(state["nudged_result_paths"] or "[]") if state else []
    checks = [
        (0, lambda: _check_p0_arrived_results(nudged_paths)),
        (1, lambda: _check_p1_overdue(state)),
        (2, lambda: _check_p2_briefing(state)),
        (3, lambda: _check_p3_knowledge(state)),
        (4, lambda: _check_p4_gaps()),
        (5, lambda: _check_p5_revise(state)),
    ]
    for tier, check_fn in checks:
        if max_priority >= tier:
            item = check_fn()
            if item:
                return item
    return None


def check_planner_productive(db):
    """Detect idle Planner and inject prioritized productive work."""
    now = int(time.time())
    row = db.execute("SELECT * FROM registry WHERE role LIKE '%lanner%' AND status = 'idle'").fetchone()
    if not row:
        return

    pane_id = row["pane_id"]
    role = row["role"]
    ctx_pct = row["context_pct"] or 0
    last_change = row["last_screen_change"] or now
    idle_secs = now - last_change

    if idle_secs < _PLANNER_GRACE_PERIOD:
        return

    state = _planner_get_state(db)
    if state and state["last_nudge_at"] and (now - state["last_nudge_at"]) < _PLANNER_NUDGE_COOLDOWN:
        return

    max_priority = _planner_max_priority(ctx_pct)
    if ctx_pct > 85:
        logger.warning("PLANNER_IDLE: context at %.0f%% — restricting to P0 only (refresh threshold)", ctx_pct)

    nudge = _find_planner_work_item(db, max_priority, state)

    if nudge:
        _enqueue_system_msg(db, role, nudge["text"], priority=1)
        if nudge.get("mark_path"):
            nudged = json.loads(state["nudged_result_paths"] or "[]") if state else []
            nudged.append(nudge["mark_path"])
            _planner_update_state(db, nudged_result_paths=json.dumps(nudged))
        _planner_update_state(db, last_nudge_at=now, last_nudge_tier=nudge["tier"])
        logger.info("PLANNER_IDLE: nudged %s with %s: %s", pane_id, nudge["tier"], nudge["text"][:80])
        return

    if idle_secs > _PLANNER_ALERT_THRESHOLD:
        notify_user("📋 Planner Idle", f"Planner idle {idle_secs}s, no applicable work. Context: {ctx_pct:.0f}%")
        _planner_update_state(db, last_nudge_at=now, last_nudge_tier="ALERT")
        logger.info("PLANNER_IDLE: user alert — idle %ds, no work at max_priority=%d", idle_secs, max_priority)


# ── /tmp Cleanup (Task 4.4) ────────────────────────────────────────────────

def cleanup_tmp():
    """Clean stale files from XDG dirs and ephemeral /tmp crew files."""
    now = time.time()
    cutoff_48h = now - 48 * 3600
    cutoff_24h = now - 24 * 3600
    cutoff_1h = now - 3600
    cleaned = 0

    # Ensure XDG subdirectories exist
    SIGNAL_DIR.mkdir(parents=True, exist_ok=True)
    _CREW_CONFIG.mkdir(parents=True, exist_ok=True)
    os.makedirs("/tmp/.crew-alerts", exist_ok=True)

    # 48h: merge originals, archives, replacements, alerts, signals
    patterns_48h = [
        str(MERGE_ORIGINALS_DIR / "*.json"),
        "/tmp/conversation-archive-*.json",
        "/tmp/ctx-replacement-*.md",
        "/tmp/.crew-alert-*.txt",
        str(SIGNAL_DIR / "*.json"),
    ]
    for pattern in patterns_48h:
        for path in glob.glob(pattern):
            try:
                if os.path.getmtime(path) < cutoff_48h:
                    os.unlink(path)
                    cleaned += 1
            except OSError:
                pass

    # 24h: ephemeral kiro-sub files, screen dumps, screenshots
    patterns_24h = [
        "/tmp/kiro-sub-*",
        "/tmp/crew-*.txt",
        "/tmp/crew-*.png",
    ]
    for pattern in patterns_24h:
        for path in glob.glob(pattern):
            try:
                if os.path.getmtime(path) < cutoff_24h:
                    os.unlink(path)
                    cleaned += 1
            except OSError:
                pass

    # 1h: stale lock files
    for path in glob.glob("/tmp/.crew-locks/*"):
        try:
            if os.path.getmtime(path) < cutoff_1h:
                os.unlink(path)
                cleaned += 1
        except OSError:
            pass

    if cleaned:
        logger.info("CLEANUP: removed %d stale files", cleaned)


# ── Verdict System (Tasks 2.7, 2.8, 2.9) ──────────────────────────────────

def _schedule_verdict(db, pane_id, role, old_status, new_status, full_screen, now):
    """Schedule a verdict on state transition. Grace period for idle transitions."""
    global _verdict_total, _verdict_concordant
    # Rate limit: 1 verdict/pane/60s
    last = _last_verdict.get(pane_id, 0)
    if now - last < 60:
        return

    # Grace period: on transition to idle, wait 90s
    if new_status == "idle":
        _idle_since[pane_id] = now
        threading.Timer(90, _deferred_verdict,
                        args=(pane_id, role, old_status, new_status, full_screen, now)).start()
        return

    _execute_verdict(db, pane_id, role, old_status, new_status, full_screen, now)


def _deferred_verdict(pane_id, role, old_status, new_status, full_screen, transition_time):
    """Run verdict after grace period. Cancel if pane resumed working."""
    try:
        db = get_db()
        row = db.execute("SELECT status FROM registry WHERE pane_id=?", (pane_id,)).fetchone()
        if row and row["status"] != "idle":
            logger.info("VERDICT: cancelled deferred verdict for %s — resumed working", pane_id)
            db.close()
            return
        _execute_verdict(db, pane_id, role, old_status, new_status, full_screen, transition_time)
        db.close()
    except Exception:
        logger.exception("VERDICT: deferred verdict error for %s", pane_id)


def _execute_verdict(db, pane_id, role, old_status, new_status, full_screen, now):
    """Get LLM or deterministic verdict and optionally act on it."""
    global _verdict_total, _verdict_concordant, _verdict_shadow
    _last_verdict[pane_id] = int(time.time())

    # Get screen tail (last 40 lines)
    lines = full_screen.rstrip("\n").split("\n") if full_screen else []
    screen_tail = "\n".join(lines[-40:])

    idle_sec = int(time.time()) - (_idle_since.get(pane_id) or int(time.time()))

    # Deterministic classification
    det_verdict = _deterministic_verdict(pane_id, screen_tail, new_status, idle_sec)

    # Try LLM verdict
    llm_verdict = _llm_verdict(pane_id, role, old_status, screen_tail, idle_sec)
    used_llm = llm_verdict is not None

    verdict = llm_verdict or det_verdict
    confidence = _compute_confidence(llm_verdict, det_verdict, screen_tail)

    # Track concordance for auto-promote
    _verdict_total += 1
    if llm_verdict and det_verdict and llm_verdict.get("status") == det_verdict.get("status"):
        _verdict_concordant += 1

    # Auto-promote after 50 verdicts with >85% concordance
    if _verdict_shadow and _verdict_total >= 50:
        accuracy = _verdict_concordant / _verdict_total
        if accuracy >= 0.85:
            _verdict_shadow = False
            logger.info("VERDICT: shadow mode graduated after %d verdicts, accuracy %.0f%%",
                        _verdict_total, accuracy * 100)

    # Store verdict
    action_desc = "shadow" if _verdict_shadow else _describe_action(verdict, confidence)
    db.execute(
        """INSERT INTO verdicts (pane_id, role, status_before, status_after, screen_tail,
           verdict_raw, action_taken, confidence, llm_used, latency_ms, created_at)
           VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
        (pane_id, role, old_status, verdict.get("status", new_status), screen_tail[:2000],
         json.dumps(verdict), action_desc, confidence, 1 if used_llm else 0, 0, int(time.time())),
    )
    db.commit()

    logger.info("VERDICT: %s status=%s confidence=%s action=%s shadow=%s",
                pane_id, verdict.get("status"), confidence, action_desc, _verdict_shadow)

    # Act on verdict (Task 2.8)
    if not _verdict_shadow:
        _act_on_verdict(db, pane_id, role, verdict, confidence)


def _deterministic_verdict(pane_id, screen_tail, current_status, idle_sec):
    """Fallback deterministic classification (Task 2.7)."""
    prompt_visible = bool(PROMPT_RE.search(screen_tail))
    has_error = bool(ERROR_RE.search(screen_tail))

    if has_error:
        return {"status": "ERROR", "detail": "Error text visible on screen", "output_path": None, "needs_from": None}
    if current_status == "hung":
        return {"status": "HUNG", "detail": "Screen static 20+ min", "output_path": None, "needs_from": None}
    if prompt_visible:
        # Check for result file paths on screen
        path_match = re.search(r"(/tmp/\S+result\S*\.md)", screen_tail)
        output_path = path_match.group(1) if path_match else None
        if output_path and Path(output_path).exists():
            return {"status": "IDLE_DONE", "detail": "Prompt visible, result file found", "output_path": output_path, "needs_from": None}
        if idle_sec > 300:
            return {"status": "IDLE_STUCK", "detail": f"Idle {idle_sec}s with no result file", "output_path": None, "needs_from": None}
        return {"status": "IDLE_DONE", "detail": "Prompt visible", "output_path": output_path, "needs_from": None}
    if THINKING_RE.search(screen_tail):
        return {"status": "WORKING", "detail": "Thinking indicator visible", "output_path": None, "needs_from": None}
    return {"status": "WORKING", "detail": "Screen active", "output_path": None, "needs_from": None}


def _llm_verdict(pane_id, role, old_status, screen_tail, idle_sec):
    """Call Haiku for verdict. Returns dict or None on failure."""
    try:
        import anthropic
    except ImportError:
        return None

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        return None

    prompt = f"""Agent: {role}
Previous status: {old_status}
Idle duration: {idle_sec}s (time since last screen change)
Screen (last 40 lines):
{screen_tail[:3000]}

Classify this agent's state. Reply with EXACTLY one JSON object:
{{"status": "WORKING|IDLE_DONE|IDLE_STUCK|NEEDS_INPUT|ERROR|HUNG",
 "detail": "one sentence explanation",
 "output_path": "/path/to/result if visible on screen, else null",
 "needs_from": "role name if NEEDS_INPUT, else null"}}"""

    try:
        client = anthropic.Anthropic(api_key=api_key, timeout=10.0)
        resp = client.messages.create(
            model="claude-haiku-3.5",
            max_tokens=150,
            messages=[{"role": "user", "content": prompt}],
        )
        text = resp.content[0].text.strip()
        # Extract JSON from response
        m = re.search(r"\{.*\}", text, re.DOTALL)
        if m:
            return json.loads(m.group())
    except Exception as e:
        logger.warning("VERDICT: LLM call failed: %s", e)
    return None


def _compute_confidence(llm_verdict, det_verdict, screen_tail):
    """Derive confidence: HIGH/MEDIUM/LOW."""
    if not llm_verdict:
        return "MEDIUM"
    if det_verdict and llm_verdict.get("status") == det_verdict.get("status"):
        return "HIGH"
    # Cross-check: LLM says IDLE_DONE but no prompt visible
    prompt_visible = bool(PROMPT_RE.search(screen_tail))
    if llm_verdict.get("status") == "IDLE_DONE" and not prompt_visible:
        return "LOW"
    return "MEDIUM"


def _describe_action(verdict, confidence):
    """Describe what action would be taken."""
    status = verdict.get("status", "")
    if confidence == "LOW":
        return "log_only"
    if status == "IDLE_DONE":
        return "notify_manager"
    if status == "IDLE_STUCK":
        return "nudge"
    if status == "NEEDS_INPUT":
        return "notify_manager"
    if status == "ERROR":
        return "retry_or_notify"
    if status == "HUNG":
        return "defer_to_hang_detection"
    return "none"


def _act_on_verdict(db, pane_id, role, verdict, confidence):
    """Execute verdict-driven dispatch (Task 2.8)."""
    now = int(time.time())
    # Action cooldown: 90s per pane
    last = _last_action.get(pane_id, 0)
    if now - last < 90:
        return
    if confidence == "LOW":
        return

    status = verdict.get("status", "")
    output_path = verdict.get("output_path")
    detail = verdict.get("detail", "")
    needs_from = verdict.get("needs_from")

    row = db.execute("SELECT * FROM registry WHERE pane_id=?", (pane_id,)).fetchone()
    tab_name = row["tab_name"] if row else pane_id

    if status == "IDLE_DONE":
        if output_path and Path(output_path).exists() and Path(output_path).stat().st_size > 0:
            _enqueue_system_msg(db, "Manager", f"check {output_path}", priority=1)
        elif output_path and Path(output_path).exists():
            _enqueue_system_msg(db, "Manager",
                f"{role} finished but result file is empty. Read their conversation at tab '{tab_name}' for context.", priority=1)
        else:
            _enqueue_system_msg(db, "Manager",
                f"{role} appears done (idle at prompt) but no result file found. Read their conversation at tab '{tab_name}' to determine outcome.", priority=1)
        db.execute("UPDATE registry SET tasks_completed = tasks_completed + 1 WHERE pane_id=?", (pane_id,))

    elif status == "IDLE_STUCK":
        task = _extract_original_task(row["conversation_id"] if row else None) or "your assigned task"
        _enqueue_system_msg(db, role, f"Your task: {task[:200]}. Proceed or report blockers.", priority=2)

    elif status == "NEEDS_INPUT":
        _enqueue_system_msg(db, "Manager",
            f"{role} is waiting for input: {detail}. Check if the needed info is available and route it.", priority=1)

    elif status == "ERROR":
        error_lines = "\n".join(l for l in (verdict.get("detail", "")).split("\n") if ERROR_RE.search(l))[:200]
        if any(w in detail.lower() for w in ("timeout", "network", "transient", "retry")):
            _enqueue_system_msg(db, role, "Retry the last operation.", priority=1)
        else:
            _enqueue_system_msg(db, "Manager",
                f"{role} hit a fatal error: {error_lines or detail}. Check tab '{tab_name}'.", priority=0)

    # HUNG defers to graduated response (Task 2.3)

    _last_action[pane_id] = now
    db.commit()


# ── Main loop ───────────────────────────────────────────────────────────────

def handle_signal(signum, frame):
    global _shutdown
    _shutdown = True
    logger.info("Received signal %d, shutting down", signum)


def write_pid():
    PID_FILE.write_text(str(os.getpid()))


def remove_pid():
    PID_FILE.unlink(missing_ok=True)


def update_session_manifest():
    """Update vault session manifest for the crew session."""
    try:
        cfg = json.loads(DAEMON_CONFIG.read_text()) if DAEMON_CONFIG.exists() else {}
        session = cfg.get("session")
        if not session:
            return
        subprocess.run(
            ["python3", os.path.expanduser("~/scripts/session-manifest-update.py"), session],
            capture_output=True, timeout=15,
        )
    except Exception:
        logger.debug("session manifest update failed", exc_info=True)


# Track whether we already marked session as done (avoid repeated notifications)
_session_marked_done = False

def check_all_idle_done(db):
    """Mark all agents as 'done' when: all crew panes idle + no pending messages. Suppresses nudges."""
    global _session_marked_done
    
    rows = db.execute("SELECT pane_id, role, status FROM registry WHERE role IS NOT NULL AND role != ''").fetchall()
    if not rows:
        return
    
    crew = [r for r in rows if r["pane_id"] != "terminal_0"]
    crew = [r for r in crew if r["role"] not in (None, "", "?")]
    
    if not crew:
        return
    
    all_idle = all(r["status"] in ("idle", "done") for r in crew)
    crew_roles = [r["role"] for r in crew]
    pending = db.execute(
        "SELECT COUNT(*) FROM messages WHERE status = 'pending' AND target_role IN ({})".format(
            ",".join("?" for _ in crew_roles)
        ), crew_roles
    ).fetchone()[0]
    
    if all_idle and pending == 0:
        # Don't mark done if Planner has unreviewed results
        planner_state = db.execute("SELECT expected_result_path FROM planner_idle_state ORDER BY id DESC LIMIT 1").fetchone()
        if planner_state and planner_state["expected_result_path"]:
            if os.path.exists(planner_state["expected_result_path"]):
                return

        # Mark any remaining idle crew as done (catches stragglers from previous cycle)
        still_idle = [r for r in crew if r["status"] == "idle"]
        if still_idle:
            db.execute("UPDATE registry SET status = 'done' WHERE role IS NOT NULL AND role != '' AND status = 'idle' AND pane_id != 'terminal_0'")
            db.commit()
            for r in still_idle:
                logger.info("SESSION DONE: marked %s (%s) as done", r["role"], r["pane_id"])
        if not _session_marked_done:
            logger.info("SESSION DONE: all crew idle + no pending messages")
            try:
                notify_user("Crew Session Complete", "All agents idle, no pending tasks.")
            except Exception:
                pass
            _session_marked_done = True
    else:
        if _session_marked_done and not all_idle:
            _session_marked_done = False
            logger.info("SESSION RESUMED: new activity detected — clearing done status")


def main_loop():
    global _shutdown
    setup_logging()
    init_db()
    write_pid()
    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    # Task 4.4: /tmp cleanup on startup
    cleanup_tmp()

    logger.info("crew-sessiond started (pid=%d)", os.getpid())
    last_registry_scan = 0
    last_monitor = 0
    last_snapshot = 0
    _was_overnight = is_overnight()

    try:
        while not _shutdown:
            now = time.time()
            db = get_db()
            try:
                # Registry scan every 60s
                if now - last_registry_scan >= REGISTRY_SCAN_INTERVAL:
                    scan_and_populate_registry(db)
                    last_registry_scan = now

                # State monitor every 30s (Task 2.1)
                if now - last_monitor >= MONITOR_INTERVAL:
                    monitor_panes(db)
                    check_all_idle_done(db)
                    check_hang_detection(db)
                    check_tool_timeout(db)
                    check_context_rot(db)
                    check_pool_autoscale(db)
                    check_role_violations(db)
                    check_reminders(db)  # Task 4.2
                    check_planner_productive(db)  # Planner idle elimination
                    t2_detect_deadlocks(db)
                    check_eta_overdue(db)
                    last_monitor = now

                # State snapshots every 5 min (Task 2.6)
                if now - last_snapshot >= SNAPSHOT_INTERVAL:
                    save_snapshot(db)
                    check_pattern_decay(db)
                    # Overnight→daytime transition: generate morning alerts
                    _now_overnight = is_overnight()
                    if _was_overnight and not _now_overnight:
                        batch_morning_alerts(db)
                        logger.info("OVERNIGHT: transition to daytime detected")
                    _was_overnight = _now_overnight
                    # Update session manifest in vault
                    update_session_manifest()
                    last_snapshot = now

                # Dispatch pending messages (with merge)
                dispatch_messages(db)

                # Update 📬 indicators on tabs
                update_message_indicators(db)

                # Poll signal decisions
                poll_signal_decisions(db)

                # Priority escalation (Task 3.4)
                check_priority_escalation(db)

                # DLQ check (Task 4.1)
                move_to_dlq(db)
            except Exception:
                logger.exception("Error in main loop")
            finally:
                db.close()

            time.sleep(DISPATCH_INTERVAL)
    finally:
        remove_pid()
        logger.info("crew-sessiond stopped")


# ── CLI entry ───────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Crew session daemon")
    parser.add_argument("--init-db", action="store_true", help="Initialize DB and exit")
    parser.add_argument("--check", action="store_true", help="Validate schema and exit")
    args = parser.parse_args()

    if args.init_db:
        init_db()
        print(f"DB created at {DB_PATH}")
        return

    if args.check:
        if not DB_PATH.exists():
            print(f"FAIL: {DB_PATH} does not exist", file=sys.stderr)
            sys.exit(1)
        sys.exit(0 if check_schema() else 1)

    main_loop()


if __name__ == "__main__":
    main()
