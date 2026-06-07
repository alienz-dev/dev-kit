# Agent Context Files

Templates for files that provide context to AI agents at session start.

## File Hierarchy (loaded in order)

1. **client_rules.md** — Universal safety rules (every session)
2. **user-profile.md** — Communication style, preferences, do-not-do
3. **Hot memory** — Per-workspace curated patterns (3000 char budget)
4. **Project state** — STATUS.md, NEXT-SESSION.md, CONTEXT.md, DECISIONS.md
5. **Knowledge** — Project-specific knowledge (loaded via agent definitions)
6. **Skills** — On-demand skill files loaded by topic

## client_rules.md

The non-negotiable safety rules. See `client_rules.md` in this directory.

Key sections:
- Tool Execution Safety (stdin, stdout, memory)
- Verification Discipline (verify before verdict)
- Anti-Destruction (never discard uncommitted work)
- Anti-Hallucination (zero knowledge assumption)
- Context Discipline (treat context like RAM)

## user-profile.md

Personal preferences that shape agent behavior. See `user-profile-template.md`.

Sections:
- Communication style (terse/verbose, format preferences)
- Workflow preferences (delegation patterns, verification expectations)
- Do-not-do list (specific behaviors to avoid)

Updated when user corrects agent behavior 3+ times on same pattern.

## CONTEXT.md (Ubiquitous Language)

Project-specific glossary. Agents must use these terms precisely.

```markdown
# Project — Ubiquitous Language

| Term | Meaning | NOT this |
|------|---------|----------|
| Spec | Feature specification (WHAT + WHY) | "ticket", "issue" |
| Plan | Implementation plan (HOW + ORDER) | "spec" |
| Gate | Automated check before state transition | "test" |
| Stage | A lifecycle state in the pipeline | "status" |
```

## STATUS.md

Current project state. Updated after every significant change.

## NEXT-SESSION.md

Exact next action for cold-start sessions. Not "continue with X" but specific step.

## DECISIONS.md

Architecture Decision Records. Hard-to-reverse decisions with rationale.

## Project Knowledge

Project-specific knowledge is embedded in agent definitions and rules:
- `phases/shared/rules/ROLES.md` — Role definitions and dispatch rules
- `phases/shared/rules/HANDOFF.md` — Inter-role data exchange protocols
- `phases/shared/rules/CONSOLIDATED.md` — Universal safety rules
- Project state files: STATUS.md, CONTEXT.md, DECISIONS.md

## Skills (on-demand)

Skills are loaded when relevant to the current task:
- `grill` — Design tree interview before planning
- `explainer` — Visual HTML/Excel presentations
- `systematic-debugging` — Four-phase debugging protocol
- `test-engineer` — TDD workflow and test planning
