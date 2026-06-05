# Plan: AIDLC Best Practices Implementation

Derived from: SPEC-AIDLC-001

## Approach

Implement the three critical gaps identified in AIDLC research in sequential order:
1. Context management (consolidate governance, add skills loading, document compaction)
2. Gate scripts (implement 5 missing gates with automated tests)
3. Worktree isolation (modify sprint-manager for parallel coders)

## Steps (ordered)

### Phase 1: Context Management

1. [ ] **Audit current governance files** — Measure sizes, identify duplicates across:
   - `agents/rules/` (execution-safety.md, verification.md, anti-destruction.md, anti-hallucination.md, context-discipline.md)
   - `templates/common/` (agent rules templates)
   - `workflow/` (SDD, TRIO rules)

2. [ ] **Create consolidated governance file** — `agents/rules/CONSOLIDATED.md` (<8KB)
   - Merge core rules (execution safety, verification, anti-destruction)
   - Remove duplicates
   - Add cross-references to skills for domain-specific knowledge

3. [ ] **Create skills directory** — `agents/skills/`
   - Move domain-specific rules (TypeScript patterns, testing patterns)
   - Create index file for on-demand loading

4. [ ] **Update templates** — Reference consolidated file during scaffold
   - Modify `templates/common/` to copy from `agents/rules/CONSOLIDATED.md`
   - Update scaffold.sh to handle new structure

5. [ ] **Document compaction strategy** — Add to governance file
   - `/compact` guidance between tasks
   - Subagent context isolation protocol
   - Context budget monitoring

### Phase 2: Gate Scripts

6. [ ] **Implement WIRING gate** — `quality/gates/entry-reachability.sh`
   - Check for orphaned modules (not imported anywhere)
   - Check for dead imports (importing non-existent modules)
   - Return exit code 0 (pass) or 1 (fail) with details

7. [ ] **Implement VISUAL gate** — `quality/gates/ui-visual-check.sh`
   - Check for hardcoded colors (should use design tokens)
   - Check for missing alt text on images
   - Check for responsive breakpoints
   - Integrate with existing visual check tool if available

8. [ ] **Implement wave-smoke gate** — `quality/gates/wave-smoke.sh`
   - Verify all tests in current wave pass
   - Check for uncommitted changes
   - Verify no merge conflicts

9. [ ] **Implement ACTIVATION gate** — `quality/gates/activation-gate.sh`
   - Verify feature is reachable from entry point
   - Check for proper exports/imports
   - Verify no dead code paths

10. [ ] **Implement REVIEW gate** — `quality/gates/review-precheck.sh`
    - Check for TODO/FIXME comments
    - Verify test coverage meets threshold
    - Check for console.log/debug statements

11. [ ] **Write automated tests** for all gate scripts
    - Test each gate catches the failure it's designed for
    - Test each gate passes for valid code
    - Integration test for gate sequence

### Phase 3: Worktree Isolation

12. [ ] **Modify sprint-manager** — Add worktree creation before dispatching coders
    - Create worktree per coder: `git worktree add .worktrees/coder-<id>`
    - Pass worktree path to coder briefing
    - Track worktree cleanup

13. [ ] **Implement rebase and merge** — After all coders complete
    - Rebase each worktree onto main
    - Fast-forward merge sequentially
    - Clean up worktrees after merge

14. [ ] **Add error handling** — Graceful degradation
    - If worktree creation fails, fall back to sequential execution
    - If rebase fails, log error and pause for manual resolution
    - Add worktree cleanup on agent exit

15. [ ] **Update documentation** — ARCHITECTURE.md, TRIO.md
    - Document worktree isolation pattern
    - Update data flow diagram
    - Add troubleshooting section

## Test Strategy

- **Unit:** Each gate script has a test file in `quality/gates/__tests__/`
- **Integration:** Test gate sequence (WIRING → VISUAL → wave-smoke → ACTIVATION → REVIEW)
- **Manual:** Verify context size <8KB after consolidation
- **Manual:** Verify worktree creation and merge

## Risks

- **Risk:** Consolidation breaks existing projects
  - **Mitigation:** Keep old files as deprecated, update scaffold gradually

- **Risk:** Gate scripts too strict, blocking valid code
  - **Mitigation:** Start with warnings, graduate to errors after validation

- **Risk:** Worktree merge conflicts
  - **Mitigation:** Sequential merge with conflict detection, pause for manual resolution

## Dependencies

- No external dependencies
- Uses existing git, bash, node tooling
- Integrates with existing pipeline (gate.sh, transitions.json)
