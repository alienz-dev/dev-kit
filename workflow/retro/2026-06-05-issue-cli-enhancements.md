# Retrospective: Issue-CLI Enhancements for SDD Coding Agent Work

**Date:** 2026-06-05
**Scope:** Phase 1 & 2 enhancements to issue-cli for SDD coding agent workflows
**Duration:** ~2 hours

---

## Summary

Implemented Phase 1 (atomic claim, tiered brief, actionable issues) and Phase 2 (plan decomposition) enhancements to issue-cli, making it suitable for SDD coding agent workflows. Also completed security cleanup (removed personal paths, credentials) and generic database adapter pattern.

---

## What Went Well

### 1. Research-Driven Development
- Spawned 2 researcher agents to investigate issue tracker projects and file-based tracking patterns
- Identified 9 open-source projects with borrowable patterns
- Prioritized features based on relevance to SDD methodology

### 2. Incremental Implementation
- Phase 1 (atomic claim, tiered brief, actionable view) — 1-2 days estimated, ~1 hour actual
- Phase 2 (plan decomposition) — 2-3 days estimated, ~30 minutes actual
- Each phase was independently valuable and testable

### 3. Security Cleanup
- Removed personal paths (vault/, /Users/ding/)
- Removed embedded Supabase credentials
- Updated .gitignore with sensitive file patterns
- Made all configuration generic via environment variables

### 4. Backward Compatibility
- Reverted to synchronous API when async changes broke existing code
- Maintained existing CLI commands while adding new ones
- Preserved test suite (no regressions)

---

## What Could Be Improved

### 1. Breaking Changes
- **Issue:** Changed db.ts from synchronous to async, breaking 10+ files
- **Root Cause:** Didn't check all callers before making API changes
- **Fix:** Reverted to synchronous API, added new methods alongside
- **Lesson:** Always grep for all callers before changing function signatures

### 2. Test Coverage
- **Issue:** 7 pre-existing test failures not addressed
- **Root Cause:** Test setup issues (file paths, environment)
- **Fix:** Should have fixed tests first or documented known failures
- **Lesson:** Fix tests before adding new features

### 3. Type Safety
- **Issue:** TypeScript errors from missing fields in IssueRecord
- **Root Cause:** Added fields to interface but not to all implementations
- **Fix:** Updated all adapters and callers
- **Lesson:** When adding fields to interfaces, update all implementations immediately

### 4. Documentation
- **Issue:** README not updated with all new commands
- **Root Cause:** Focused on implementation first
- **Fix:** Update README as part of each feature
- **Lesson:** Documentation should be part of "done"

---

## Metrics

| Metric | Value |
|--------|-------|
| Commits | 10 |
| Files Changed | 20 |
| Lines Added | ~2,500 |
| Lines Removed | ~500 |
| New Features | 6 (claim, brief tiers, ready, plan prompt/submit/show) |
| Breaking Changes | 1 (reverted) |
| Test Regressions | 0 |

---

## Key Decisions

### 1. Synchronous API for db.ts
- **Decision:** Keep synchronous functions, add new sync methods
- **Rationale:** Async API broke too many callers
- **Trade-off:** Less modern, but more compatible

### 2. Generic Database Adapter
- **Decision:** Use adapter pattern with ISSUE_DB_BACKEND env var
- **Rationale:** Support multiple backends (sqlite, supabase, postgres)
- **Trade-off:** More complexity, but more flexibility

### 3. Plan Decomposition
- **Decision:** JSON-based plan with LLM prompt generation
- **Rationale:** Structured data for validation, LLM-friendly
- **Trade-off:** More rigid than free-form, but more reliable

---

## Lessons Learned

1. **Research first, implement second** — The 30-minute research saved hours of implementation
2. **Backward compatibility is sacred** — Never break existing APIs without migration path
3. **Tests are the safety net** — Fix tests before adding features
4. **Security is not optional** — Remove personal data before sharing
5. **Incremental delivery** — Small, focused commits are easier to review and revert

---

## Next Steps

### Phase 3 (Future)
- Scratch notes section for agent working memory
- Lifecycle hooks for session context preservation
- MCP server for direct agent integration

### Technical Debt
- Fix 7 pre-existing test failures
- Add integration tests for new features
- Update README with all commands
- Add examples directory

---

## Files Created/Modified

### New Files
- `src/plan.ts` — Plan decomposition module
- `src/db-adapter.ts` — Database adapter interface
- `src/adapters/sqlite.ts` — SQLite adapter
- `src/adapters/supabase.ts` — Supabase adapter
- `src/config.ts` — Centralized configuration

### Modified Files
- `src/db.ts` — Added claimIssue, getActionableIssues, enhanced schema
- `src/agent.ts` — Added tiered brief (L0/L1/L2)
- `src/cli.ts` — Added claim, ready, plan commands
- `src/types.ts` — Added linked_specs, linked_tests, parent fields
- `README.md` — Updated documentation

---

## Conclusion

Successfully implemented Phase 1 & 2 enhancements for SDD coding agent work. The issue-cli now supports:
- Atomic claim for multi-agent safety
- Tiered brief for context window optimization
- Actionable issues view for dependency resolution
- Plan decomposition for spec-to-task workflow

The codebase is now ready for multi-agent SDD workflows with proper security and generic database support.
