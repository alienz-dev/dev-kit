# Context Reduction — Design Rationale

## Problem

Agent context windows are finite (~200K tokens for Claude Opus). Preloading too many resource files consumes context before implementation begins, causing:
- Context exhaustion during complex tasks (vitest output, large file reads)
- Reduced implementation quality as context fills
- Failed spawns when agents hit 2% remaining

## Before/After

| Agent | Before | After | Freed |
|-------|--------|-------|-------|
| Coder | 66.5KB (12 files) | 24KB (6 files) | ~12K tokens |
| Planner | 155KB (14 files) | 29KB (6 files) | ~37K tokens |
| Default | 87KB (11 files) | 68KB (9 files) | ~5K tokens |
| Researcher | 57KB (10 files) | 25KB (6 files) | ~9K tokens |
| All others | 50-70KB avg | 20-37KB | ~10-15K tokens each |

## Approach

1. **Audit** — measure each resource file, classify as essential/situational/bloat
2. **Merge** — combine overlapping files into condensed digests (e.g., client_rules + coder-rules + coding-conventions → coder-safety + coder-workflow)
3. **Remove** — drop resources the role never uses (coders don't spawn, planners don't write code)
4. **Bake in** — frequently-used protocols go into the condensed file, not left to briefing injection
5. **On-demand** — rare protocols (endgame, interaction-design) read from disk when triggered

## Key Decisions

- **Governance layer is sacred** — client_rules.md in every agent, always
- **Don't trust briefings for methodology** — if a coder needs TDD rules, they're in coder-workflow.md always, not injected per-task
- **Hot-memory is supplementary, not primary** — critical rules baked into resource files
- **Digests over full files** — 2.8KB coder-safety covers everything from 8.7KB client_rules that a coder needs
- **Original files preserved** — no data loss, just not preloaded

## Rollback

Original skill files remain on disk. To revert any agent, restore the original resources array from git history or re-add the full skill file paths.
