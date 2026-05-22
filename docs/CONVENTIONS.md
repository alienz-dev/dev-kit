# Coding Conventions for AI-Assisted Development

## Core Principles

1. **Semantic density** — eliminate ceremony, preserve meaning
2. **Explicit > implicit** — make conventions visible to agents
3. **Simple > clever** — flat, direct code outperforms abstractions
4. **Structure = velocity** — consistent organization reduces iteration

## Naming

Full words over abbreviations. Function names encode intent.

| Bad | Good |
|-----|------|
| `procPay()` | `processPaymentAndUpdateLedger()` |
| `d`, `tmp`, `val` | `daysSinceLastLogin`, `temporaryAuthToken` |
| `flag`, `status` | `isAuthenticated`, `hasExpiredLicense` |

## Type Strictness

- Strict mode always. No `any`/`object` — use `unknown` + type guards
- Return types on all public functions
- Discriminated unions for state machines
- Type annotations on all public signatures

## File Organization

- Vertical slice > layer-based for feature work
- Flat directory structures (avoid nesting beyond 3 levels)
- Co-locate tests with source
- Limit barrel files (re-exports confuse agents)

## Abstraction

- Justify every abstraction layer
- Ceremony-to-logic ratio < 4:1
- No metaprogramming for control flow
- No barrel re-exports for internal modules
- Prefer explicit wiring over DI magic

## Error Handling

- Every public function handles errors explicitly
- Every API endpoint returns proper error responses
- Every external call has timeout + retry + fallback
- No silent failures
- Error messages include diagnostic context (actual values, not just "invalid input")

## Testing

- TDD non-negotiable: Red-Green-Refactor
- Unit tests: every function with logic
- Integration tests: every API endpoint
- Edge cases: empty inputs, null values, network failures
- Tests show expected behavior via Given/When/Then

## Comments

- WHY not WHAT
- Inline business rules at point of use
- No stale comments — update or delete when code changes

## Git

- Rich commit messages: what changed, why, what was considered
- Atomic commits — one logical change per commit
- Type prefixes: `feat`/`fix`/`chore`/`refactor`
- `main` always deployable

## Agent-Specific

- Write for grep, not cleverness (agents search by text pattern)
- Moderate duplication > abstraction agents can't trace
- No dynamic dispatch for control flow
- Structured docs > monolithic dumps
