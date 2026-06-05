# Safety Rules

> **This file is a template reference.** The canonical source is `agents/rules/CONSOLIDATED.md` in the dev-kit repository. During scaffold, this file is copied from that source.

Universal safety rules for every agent session. These are non-negotiable.

---

## Tool Execution Safety

- **Never let child processes inherit stdin.** Append `< /dev/null` to every shell command. Example: `npm test < /dev/null`, not `npm test`.
- **Background server isolation.** Use: `cmd > /tmp/log 2>&1 < /dev/null &`
- **Never change vitest `pool: 'threads'` to `pool: 'forks'`.** Orphans at ~2GB each = OOM.
- **Never run raw `tsc --noEmit`.** Use `npm run typecheck` (routes through `--max-old-space-size=4096 --incremental`).

---

## Verification Discipline

- **Verify before verdict.** After any fix, run concrete verification and observe actual result. Banned phrases without evidence: "should work now", "fixed", "done".
- **Auto-verify, don't ask.** Run verification yourself immediately.
- **Confirm hypothesis before implementing.** Add temporary diagnostic at suspected root cause, run reproduction.
- **Non-destructive verification only.** Never inject text into live panes, send messages to real roles, write to active DBs.
- **Fail visibly, not silently.** Surface every: skipped record, rolled-back transaction, constraint violation.

---

## Anti-Destruction

- **Never discard uncommitted work from other agents.** When `git status` shows files you didn't create, NEVER run `git checkout --`, `git clean`, or `rm` without user confirmation.
- **Scope: solve what was asked, no bonus features.** Only modify files explicitly in scope.
- **Convention beats novelty.** Match existing patterns.
- **Surface conflicts, don't average them.** Flag conflicting patterns — don't combine both.

---

## Anti-Hallucination

- **You start every session with zero project knowledge.** Read project context files before acting.
- **You will confidently generate wrong code.** Read actual file before calling/modifying it, run code after writing.
- **Read project context files on startup.** Check: STATUS.md, NEXT-SESSION.md, README.md, DECISIONS.md, CONTEXT.md.

---

## Context Discipline

- **Treat context window like RAM, not a log file.** Don't dump entire files for 10 lines. Summarize failed approaches.
- **Your failed attempts leave debris.** After failures: check state, clean up, retry.

---

## File Navigation

- **Never search from `/` or `~` without scoping.** Identify correct subdirectory first.
