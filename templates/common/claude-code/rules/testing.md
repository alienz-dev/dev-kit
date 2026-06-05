---
paths:
  - "**/*.test.ts"
  - "**/*.test.tsx"
---

# Testing Rules

- Runner: vitest (threads pool, NEVER forks)
- Pattern: `tests/**/*.test.{ts,tsx}`
- Use descriptive test names that explain behavior
- Mock external dependencies, not internal modules
- One change → verify → next change
- Reference spec sections: `// @spec <file> §<section>`
- Given/When/Then pattern for test structure
- Edge cases: empty inputs, null values, boundary conditions
- Error paths: invalid input, network failures, timeouts
