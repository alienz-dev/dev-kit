# Regression Prevention

## Hidden Tests Pattern

Hidden tests are regression tests the coder never sees. They verify invariants that should never break.

### How It Works

1. **Test-manager** writes two categories of tests:
   - **Visible tests** — given to coder in briefing (they make these pass)
   - **Hidden tests** — kept secret, run only at review gate

2. **Coder** only sees visible test file paths in their briefing

3. **Review gate** runs ALL tests (visible + hidden):
   - If hidden tests fail → issue goes back to `implementing`
   - If all pass → reviewer can approve → `closed`

### File Convention

```
tests/
├── unit/
│   └── feature.test.ts          ← Visible (coder sees)
├── hidden/
│   └── feature.hidden.test.ts   ← Hidden (coder never sees)
└── regression/
    └── feature.regression.test.ts ← Added after bugs found
```

### vitest config for hidden tests

```typescript
// vitest.config.ts (normal runs — excludes hidden)
export default defineConfig({
  test: {
    include: ['tests/**/*.test.ts'],
    exclude: ['tests/hidden/**'],
  },
})

// vitest.gate.config.ts (gate runs — includes everything)
export default defineConfig({
  test: {
    include: ['tests/**/*.test.ts', 'tests/hidden/**/*.test.ts'],
  },
})
```

### Gate Script

```bash
#!/bin/bash
# Run full test suite including hidden tests (for review gate)
npx vitest run --config vitest.gate.config.ts --reporter=dot < /dev/null
```

## Conformance Tests

Shared test suite verifying two implementations produce identical results.

Use case: when you have multiple adapters (e.g., SQLite for tests, Postgres for prod) that must behave identically.

```typescript
// tests/conformance/store.conformance.ts
export function runStoreConformance(createStore: () => IStore) {
  describe('Store conformance', () => {
    let store: IStore;
    beforeEach(() => { store = createStore(); });

    it('creates and retrieves', async () => { ... });
    it('updates existing', async () => { ... });
    it('handles not found', async () => { ... });
  });
}

// tests/unit/sqlite-store.test.ts
import { runStoreConformance } from '../conformance/store.conformance';
runStoreConformance(() => new SqliteStore(':memory:'));

// tests/integration/postgres-store.test.ts
import { runStoreConformance } from '../conformance/store.conformance';
runStoreConformance(() => new PostgresStore(testConnectionString));
```

## Pre-Commit Gate

Production-tested script. See `quality/pre-commit/pre-commit-test-gate.sh`.

Key features:
- Runs only tests affected by staged changes
- 60-second timeout (fail-closed)
- Maps frontend file changes to test directories
- Supports `VITEST_BIN` override for testing the gate itself
