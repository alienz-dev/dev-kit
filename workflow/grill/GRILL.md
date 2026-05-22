---
tags:
- skills
- planning
- interview
- design
aliases:
- grill
- grill me
- design interview
scope: any
env: any
last-updated: 2026-05-18
---

# Grill — Design Tree Interview

> **When to use:** Before writing plans for complex features. Forces exhaustive exploration of the design space. Invoke with `grill <topic>`.

## Protocol

When `grill` is invoked:

1. Read `CONTEXT.md` from workdir if it exists (domain awareness)
2. Interview the user relentlessly about every aspect of the topic until reaching shared understanding
3. Walk down each branch of the design tree, resolving dependencies one-by-one
4. For each question, provide your recommended answer
5. Ask questions one at a time — wait for response before continuing
6. If a question can be answered by exploring the codebase, explore instead of asking
7. If user uses a term that conflicts with CONTEXT.md glossary, challenge it immediately
8. When a term is resolved/sharpened during the session, note it for CONTEXT.md update
9. After reaching shared understanding, present summary of all decisions made
10. Do NOT proceed to plan-writing until user explicitly requests it

## Question Style

- Be specific, not generic: "Should the daemon own this transition or should the CLI command trigger it directly?" not "How should this work?"
- Provide recommended answer with brief rationale: "Recommended: daemon-owned, because it can enforce the gate even when agents crash mid-task"
- Surface tensions with existing decisions: "DECISIONS.md says X, but this implies Y — which wins?"
- Probe edge cases: "What happens when the agent exits before writing its result file?"
- Challenge vague language: "You said 'handle it' — do you mean retry, skip, or escalate to user?"

## Domain Awareness

When CONTEXT.md exists:
- Use its vocabulary precisely (don't say "service" when the glossary says "daemon")
- Challenge terminology mismatches immediately
- Note new terms that emerge for later CONTEXT.md update
- Reference existing relationships when probing design decisions

When CONTEXT.md doesn't exist:
- Behave like standard grill-me (no domain challenging)
- If the session surfaces enough terms, suggest creating CONTEXT.md at the end

## Completion

The session ends when:
- All branches of the design tree are resolved (no open questions remain)
- User says "enough" or "plan it" or "done"

On completion:
1. Present summary of decisions made (bulleted list)
2. **Write Clarifications section** for the plan — format each resolved question as:
   ```
   - Q: [question asked] → A: [resolved answer + brief rationale]
   ```
   This section will be included verbatim in the plan file under `## Clarifications`. It persists resolved ambiguities for the test-manager and reviewer.
3. Note any CONTEXT.md terms that need adding/updating
4. Note any ADR-worthy decisions (hard to reverse + surprising without context + real trade-off)

## When NOT to Use

- Simple bug fixes (use systematic-debugging)
- Tasks with score 0-3 (plan directly, no grilling needed)
- When the user already has a clear spec and just wants execution

## Related
- [[skills/planner-rules/SKILL|Planner Rules]] — grill feeds into Phase 0 Clarify
- [[skills/deep-research/deep-research|Deep Research]] — for when grilling reveals unknown territory
