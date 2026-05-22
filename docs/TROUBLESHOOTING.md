# Troubleshooting

Common failure modes from real production use, with root causes and fixes.

## Agent Hangs

### Symptom: Agent session frozen, no output, can't Ctrl+C
**Cause:** Command reading from stdin (e.g., `npm init`, `git commit` without `-m`, interactive prompts)
**Fix:** Always append `< /dev/null` to shell commands. Kill the session and restart.
**Prevention:** Add stdin closure to your agent CLI wrapper or execution hook.

### Symptom: Agent session frozen after starting a server
**Cause:** Backgrounded server inherits stdout pipe fd. Agent CLI blocks on EOF waiting for pipe to close.
**Fix:** Use `start-server.sh` or redirect: `cmd > /tmp/log 2>&1 < /dev/null &`
**Prevention:** Never `&` a server directly in agent execution context.

### Symptom: Agent responds but commands take forever
**Cause:** `tsc --noEmit` on large project consuming all memory, swapping.
**Fix:** Kill tsc process. Use `node --max-old-space-size=4096 tsc --noEmit --incremental` instead.
**Prevention:** Configure `npm run typecheck` with memory limit in package.json scripts.

---

## Out of Memory

### Symptom: System becomes unresponsive, processes killed
**Cause:** vitest with `pool: 'forks'` — workers survive parent exit at ~2GB each.
**Fix:** Kill orphan vitest workers: `pkill -f vitest`. Switch to `pool: 'threads'`.
**Prevention:** Never use `pool: 'forks'`. If tests are flaky with threads, fix test isolation.

### Symptom: Node process killed during build
**Cause:** TypeScript compiler default memory limit (1.7GB) exceeded.
**Fix:** Set `--max-old-space-size=4096` in node options.
**Prevention:** Use incremental compilation (`--incremental` flag).

---

## Authentication Failures

### Symptom: 401 errors from APIs
**Cause:** Token expired (common with short-lived tokens: Jira 5h, AWS SSO 8h)
**Fix:** Refresh token via configured mechanism (timer service, manual re-auth)
**Prevention:** Token refresh timer running as systemd service.

### Symptom: "unable to get local issuer certificate" from Node.js
**Cause:** Corporate proxy (Zscaler) intercepting TLS. Node doesn't use system CA store.
**Fix:** `export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt`
**Prevention:** Set in `.bashrc` and in systemd service `Environment=` lines.

### Symptom: npm install fails with 401
**Cause:** Registry auth token expired or misconfigured.
**Fix:** Regenerate: `echo -n "user:pass" | base64` → update `.npmrc`
**Prevention:** Document token source and refresh procedure.

---

## Session Loss

### Symptom: Agent tab closed unexpectedly
**Cause:** Ctrl+C in spawned tab kills agent CLI (SIGINT to foreground group).
**Fix:** Result file may still be on disk at `/tmp/kiro-sub-*-result.md`. Check manually.
**Prevention:** Launcher uses `set +e` + `trap '' INT HUP` for immunity.

### Symptom: Context lost after long session
**Cause:** Context window compacted, losing earlier conversation.
**Fix:** Use `--resume` to continue from last checkpoint. Read state files to re-orient.
**Prevention:** Write findings to files as you go (don't keep everything in context).

### Symptom: Agent doesn't know what it was doing
**Cause:** Session crashed without writing state.
**Fix:** Check `STATUS.md`, `NEXT-SESSION.md`, recent git log, `/tmp/` for partial results.
**Prevention:** Update state files after every significant action.

---

## Agent Hallucination

### Symptom: Agent calls function with wrong parameters
**Cause:** LLM hallucinated API signature from training data (may be outdated).
**Fix:** Read the actual source file before calling. Cross-reference docs against code.
**Prevention:** Rule: "Read the file before modifying or calling it."

### Symptom: Agent creates file at wrong path
**Cause:** LLM guessed path from convention rather than checking.
**Fix:** Use `find` or `glob` to locate actual file before writing.
**Prevention:** Rule: "Zero knowledge assumption — verify paths before acting."

### Symptom: Agent uses deprecated API
**Cause:** Training data includes old documentation.
**Fix:** Check actual installed version: `npm list <pkg>`, read current docs.
**Prevention:** Pin versions, keep CONTEXT.md updated with current API patterns.

---

## Multi-Agent Issues

### Symptom: Two agents editing same file
**Cause:** No file locking, concurrent spawns targeting same module.
**Fix:** One agent's changes will be overwritten. Stash and manually merge.
**Prevention:** Supervisor ensures non-overlapping file ownership per spawn.

### Symptom: Agent discards another agent's uncommitted work
**Cause:** `git checkout --` or `git clean` without checking for foreign changes.
**Fix:** Recover from reflog: `git reflog`, `git stash list`.
**Prevention:** Rule: "Never discard uncommitted work you didn't create."

### Symptom: Message not delivered to target agent
**Cause:** Target pane ID changed (tab was closed and reopened).
**Fix:** Re-resolve pane ID: `zellij action list-panes --json`
**Prevention:** Use stable identifiers (session name + tab name) not raw pane IDs.
