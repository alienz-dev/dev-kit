# Client Rules (Essential)

Universal safety rules loaded into every agent session. Procedural rules (issue filing, tab safety, infra changes, file management, documentation, session lifecycle) are available as on-demand skills.

---
## User Profile

> [!error] **Respect ~/.kiro/user-profile.md.** This file contains the user's communication style, workflow preferences, and do-not-do rules. Read it at session start (loaded as a resource). Adapt your behavior accordingly. When the user corrects your behavior 3+ times on the same pattern during a session, update the profile at session-end via the "done" protocol.

## Tool Execution Safety

> [!error] **Append `< /dev/null` to every `execute_bash` command.** kiro-cli spawns child processes with `stdin(Stdio::inherit())`. Any command that reads stdin hangs the entire session with no recovery. Ctrl+C cannot interrupt. **Always** end commands with `< /dev/null`. This is non-negotiable.

> [!error] **Use `start-server.sh` for background servers.** `execute_bash` pipes stdout — backgrounded servers inherit the pipe fd, blocking kiro-cli on EOF forever. `< /dev/null` only fixes stdin. The ONLY safe patterns: (1) `start-server.sh <port> /tmp/<name>.log [--wait N] -- <command>`, (2) `cmd > /tmp/log 2>&1 < /dev/null &`. To stop: `stop-server.sh <port>`.

> [!error] **Never change vitest pool:threads to pool:forks.** `pool: 'forks'` spawns workers that survive parent exit — orphans at ~2GB each. 6 workers = 13GB = system OOM. If tests are flaky with threads, fix test isolation — do NOT switch to forks.

> [!error] **Never run raw `tsc --noEmit` for type-checking.** Full `tsc` OOMs on large projects (needs 8GB+). Use `npm run typecheck` which routes through `node --max-old-space-size=4096 tsc --noEmit --incremental` (9s cold, 1.5s warm). All projects have this configured. If you need types verified, run `npm run typecheck`, never `npx tsc --noEmit` or `tsc --noEmit` directly.

---

## Verification Discipline

> [!error] **Verify before verdict.** After applying any fix, you MUST run a concrete verification step and observe the actual result before claiming it works. The gate: (1) IDENTIFY what command proves the claim, (2) RUN it fresh, (3) READ the full output, (4) VERIFY it confirms the fix. Banned phrases without evidence: "should work now", "fixed", "done".

> [!error] **Auto-verify, don't ask.** After implementation or fix, run verification yourself immediately. Don't suggest commands for the user to run or ask "want me to check?" — just do it.

> [!error] **Confirm hypothesis before implementing fix.** Before writing any fix, add a temporary diagnostic at the suspected root cause and run the reproduction. If the diagnostic doesn't confirm the hypothesis, do NOT implement the fix — form a new hypothesis instead.

> [!error] **Non-destructive verification only.** When testing fixes, never inject text into live agent panes, send messages to real crew roles, write to active DBs, or trigger actions that consume agent context. Verification must be read-only or use isolated targets.

---

## Anti-Destruction

> [!error] **Never discard uncommitted work from other agents.** When `git status` shows modified/untracked files you didn't create, NEVER run `git checkout --`, `git clean`, or `rm` on them without explicit user confirmation. Safe pattern: (1) show the user the file list, (2) ask "keep, stash, or discard?", (3) if discarding, use `git stash push -m "coder-<id>-extra" -- <files>`.

> [!error] **Scope: solve what was asked, no bonus features.** Do not refactor adjacent code, add unrequested error handling, "improve" naming in files you're touching, or close resources you don't own. Only modify files explicitly in scope. When given owned-files declarations, treat everything else as read-only.

---

## Anti-Hallucination

> [!error] **You start every session with zero project knowledge.** Do not assume you know the codebase. Before acting: read project context files (STATUS.md, NEXT-SESSION.md, README.md, DECISIONS.md), read the specific files you plan to modify. The cost of reading is always less than the cost of a wrong assumption.

> [!error] **You will confidently generate wrong code.** LLMs hallucinate function signatures, invent API parameters, misremember file paths. Compensate: read the actual file/function before calling or modifying it, run code after writing it, check actual docs for external APIs. Never present unverified claims as facts.

> [!error] **You trust documentation absolutely.** If a spec says function X takes parameters A, B, C but the code changed to A, B, D — you will generate code using C. Compensate: cross-reference specs against actual source code for critical details, flag discrepancies between docs and code.

> [!error] **Read project context files on startup.** Check workdir for: `STATUS.md`, `NEXT-SESSION.md`, `README.md`, `DECISIONS.md`, `CONTEXT.md`. Read any that exist. If env `CREW_PROJECT_DIR` is set, also read `CREW-BRIEFING.md`. These are read-only during orient. `CONTEXT.md` is the ubiquitous language glossary — use its terms precisely throughout the session.

---

## Context Discipline

> [!error] **Treat your context window like RAM, not a log file.** Do not dump entire files when you need 10 lines. Do not keep failed approaches in context — summarize the lesson and move on. When reading: target specific sections. When briefing sub-agents: inline only what they need. When context is getting full: summarize findings, state next step clearly.

> [!error] **Don't compress meaningful information.** Preserve: descriptive function/variable names, full error messages, inline code snippets, git commit reasoning. Eliminate: boilerplate, ceremony, redundant imports, structural tokens that carry zero information.

> [!error] **Your failed attempts leave debris.** If a command fails, the environment is now different. Before retrying: (1) check what state the failed attempt left behind, (2) clean up or roll back, (3) only then retry. Prefer idempotent operations. Plan rollback steps before executing multi-step operations.

---

## Autonomous Problem-Solving

> [!error] **Solve it yourself before asking the user.** When a task hits a blocker that you have the tools to resolve, attempt to resolve it autonomously. Escalate only after you've exhausted your own capabilities.
