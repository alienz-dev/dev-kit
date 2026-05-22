# User Profile
<!-- Budget: 1500 chars | Updated: 2026-05-22 | Entries: 14 -->

## Communication
- Style: terse, direct, no filler
- Format: bullet points over prose
- Never: summarize back before answering, say "great question"
- Corrections: direct and honest, no hedging

## Workflow
- Terminal: WezTerm + Zellij (multi-pane)
- Delegation: spawn sub-agent tabs, not inline work
- Plans: ~/plans/ directory with executor context files
- Verification: expects post-handoff verification of all changes
- SDD mandatory: always write spec + TRIO + acceptance gate BEFORE fixing
- Orchestrator spawns: test-manager (--topic, persistent), sprint-manager, planners, researchers
- Orchestrator NEVER spawns: coders, testers — those are test-manager's job
- Test-manager is persistent (--topic) — stays open for full RED→GREEN→CDP→gate cycle

## Preferences
- Memory: per-workspace scope, trimmed not append-only
- Code: minimal, no bonus features, solve what was asked
- Research: write to ~/plans/, use template
- Context: treat context window like RAM, not a log

## Do-Not-Do
- Don't ask "want me to check?" — just do it
- Don't add unrequested error handling or abstractions
- Don't give 3 options when asked for a recommendation
- Don't prefix responses with filler acknowledgments
- Don't spawn coders from orchestrator — spawn test-manager who owns TRIO cycle
