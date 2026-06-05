---
paths:
  - "src/**/*.ts"
  - "src/**/*.tsx"
---

# Code Style Rules

- TypeScript strict mode, no `any` — use `unknown` + type guards
- Full words in names: `processPayment()` not `procPay()`
- Return types on all public functions
- Discriminated unions for state machines
- Error messages include diagnostic context (actual values, not just "invalid input")
- No barrel re-exports for internal modules
- Moderate duplication > abstraction that's hard to trace
- Write for grep, not cleverness
