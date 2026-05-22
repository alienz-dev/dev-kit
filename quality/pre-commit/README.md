# Pre-Commit Test Gate

## Problem

Broken code gets committed. Full test suite is too slow for pre-commit. Need fast, targeted verification.

## Approach: Affected Tests Only

Instead of running all tests, determine which tests are affected by the current diff:

```bash
# 1. Get changed files
CHANGED=$(git diff --cached --name-only --diff-filter=ACMR)

# 2. Map to affected tests (via module-map.json or import graph)
TESTS=$(map-to-tests.sh $CHANGED)

# 3. Run only affected tests
if [ -n "$TESTS" ]; then
  npx vitest run $TESTS --reporter=dot
fi

# 4. Run typecheck (incremental = fast)
npm run typecheck
```

## Module Map

```json
// module-map.json — maps source files to their test files
{
  "src/routes/users.ts": ["tests/unit/routes/users.test.ts"],
  "src/core/triage.ts": ["tests/unit/core/triage.test.ts", "tests/integration/triage.test.ts"],
  "src/adapters/jira.ts": ["tests/unit/adapters/jira.test.ts"]
}
```

Generate automatically:
```bash
# Scan test files for imports, build reverse map
generate-module-map.sh > module-map.json
```

## Git Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

set -e

# Get staged files
STAGED=$(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.(ts|tsx)$' || true)
[ -z "$STAGED" ] && exit 0

# Map to tests
TESTS=$(node scripts/map-to-tests.js $STAGED)

# Run affected tests
if [ -n "$TESTS" ]; then
  echo "Running affected tests..."
  npx vitest run $TESTS --reporter=dot < /dev/null
fi

# Typecheck (incremental = ~1.5s warm)
echo "Type checking..."
npm run typecheck < /dev/null
```

## Fallback

If module map doesn't cover a file, run the full test suite:
```bash
# Unknown file → run all tests (safe default)
npx vitest run --reporter=dot < /dev/null
```

## Performance Target

- Affected tests only: <10s for typical commit
- Full suite fallback: <60s
- Typecheck (incremental): <2s warm
