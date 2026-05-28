# Client Rules (Essential)

Universal safety rules loaded into every agent session. Procedural rules (issue filing, tab safety, infra changes, file management, documentation, session lifecycle) are available as on-demand skills.

---
## User Profile

> [!error] **Respect ~/.kiro/user-profile.md.** This file contains the user's communication style, workflow preferences, and do-not-do rules. Read it at session start (loaded as a resource). Adapt your behavior accordingly. When the user corrects your behavior 3+ times on the same pattern during a session, update the profile at session-end via the "done" protocol.

## Tool Execution Safety

> [!info] **`< /dev/null` is handled structurally.** `kiro-bash-guard.sh` (AMAZON_Q_CHAT_SHELL) closes stdin, captures stdout to temp files, and applies 300s timeout for ALL commands. TUI mode (2.4.1) also isolates stdin/stdout. Appending `< /dev/null` is harmless but no longer mandatory.

> [!info] **Background servers use `start-server.sh`.** `kiro-bash-guard.sh` captures stdout to temp files (breaking fd inheritance), so raw backgrounding no longer hangs. `start-server.sh` is still the recommended pattern for readability and port management.

> [!error] **Never change vitest pool:threads to pool:forks.** `pool: 'forks'` spawns workers that survive parent exit — orphans at ~2GB each. 6 workers = 13GB = system OOM. If tests are flaky with threads, fix test isolation — do NOT switch to forks.

> [!error] **Never run raw `tsc --noEmit` for type-checking.** Full `tsc` OOMs on large projects (needs 8GB+). Use `npm run typecheck` which routes through `node --max-old-space-size=4096 tsc --noEmit --incremental` (9s cold, 1.5s warm). All projects have this configured. If you need types verified, run `npm run typecheck`, never `npx tsc --noEmit` or `tsc --noEmit` directly.

---

## Verification Discipline

> [!error] **Verify before verdict.** After applying any fix, you MUST run a concrete verification step and observe the actual result before claiming it works. The gate: (1) IDENTIFY what command proves the claim, (2) RUN it fresh, (3) READ the full output, (4) VERIFY it confirms the fix. Banned phrases without evidence: "should work now", "fixed", "done".

> [!error] **Auto-verify, don't ask.** After implementation or fix, run verification yourself immediately. Don't suggest commands for the user to run or ask "want me to check?" — just do it.

> [!error] **Confirm hypothesis before implementing fix.** Before writing any fix, add a temporary diagnostic at the suspected root cause and run the reproduction. If the diagnostic doesn't confirm the hypothesis, do NOT implement the fix — form a new hypothesis instead.

> [!error] **Non-destructive verification only.** When testing fixes, never inject text into live agent panes, send messages to real crew roles, write to active DBs, or trigger actions that consume agent context. Verification must be read-only or use isolated targets.

> [!error] **Fail visibly, not silently.** Never report success when something was skipped or bypassed. Surface every: skipped record, rolled-back transaction, constraint violation, unhandled edge case, partial result. "14/15 succeeded, 1 skipped: [reason]" — not "migration complete."

---

## Anti-Destruction

> [!error] **Never discard uncommitted work from other agents.** When `git status` shows modified/untracked files you didn't create, NEVER run `git checkout --`, `git clean`, or `rm` on them without explicit user confirmation. Safe pattern: (1) show the user the file list, (2) ask "keep, stash, or discard?", (3) if discarding, use `git stash push -m "coder-<id>-extra" -- <files>`.

> [!error] **Scope: solve what was asked, no bonus features.** Do not refactor adjacent code, add unrequested error handling, "improve" naming in files you're touching, or close resources you don't own. Only modify files explicitly in scope. When given owned-files declarations, treat everything else as read-only.

> [!error] **Convention beats novelty.** In an established codebase, match the existing pattern even if a "better" one exists. Introducing a second pattern is worse than either pattern alone. If you believe the existing pattern should change, flag it as a separate task — don't mix it into the current work.

> [!error] **Surface conflicts, don't average them.** When two parts of the codebase use conflicting patterns (error handling, state management, naming conventions), do NOT combine both. Flag the conflict, state which pattern each location uses, and ask which to follow.

---

## Spawn Compliance

> [!error] **Obey explicit spawn requests.** When the user explicitly asks to spawn, delegate, or hand off to a specific agent (keywords: spawn, delegate to, have X do, send to X, use X agent), you MUST execute `kiro-ctl spawn <agent> "task" --subscribe` immediately. Do not do the work yourself. Use the exact agent type specified. After spawning, report the spawn ID and stop. Origin: 2026-05-28 — agents repeatedly ignored spawn requests and did work inline.

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

---

## File Navigation

> [!error] **Never search from `/` or `~` without scoping.** Unscoped searches are slow (4s+ traversing node_modules, .git, caches) and return noisy results from unrelated system paths. Before using `find` or `glob` on the home directory, read `~/.kiro/knowledge/home-tree.md` to identify the correct subdirectory. Then search within that specific path. Searching from `/` is banned. Searching from `~` requires `-maxdepth 3` minimum.

> [!error] **Use `locate` for file-by-name lookups.** `locate -r "^/home/mingl/.*<pattern>"` is instant (0.03s) vs `find` (4s+). Use it for: finding where a file lives, listing project directories, checking if a path exists. Pipe through `grep -v node_modules` when needed.

> [!error] **Scope searches to known directories.** The home tree at `~/.kiro/knowledge/home-tree.md` maps all key areas. Common targets: `~/projects/` (app repos), `~/work-enhancement/` (tooling repos), `~/vault/` (knowledge), `~/scripts/` (utilities), `~/infra/` (services). Never glob `**/*` from home root.
