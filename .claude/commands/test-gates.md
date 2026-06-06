# Run quality gate tests

Execute the quality gate test suite to verify gate scripts work correctly.

## Usage

```
/test-gates [gate-name]
```

## Instructions

1. If a gate name is provided in `$ARGUMENTS`, run only that test:
   `bash phases/review/gates/__tests__/<gate-name>.test.sh`
2. Otherwise, run all gate tests:
   ```bash
   for test in phases/review/gates/__tests__/*.test.sh; do
     echo "--- $(basename "$test") ---"
     bash "$test"
   done
   ```
3. Report pass/fail for each test
4. If any fail, show the relevant output and suggest fixes

## Available tests

- `accessibility-check.test.sh`
- `activation-gate.test.sh`
- `entry-reachability.test.sh`
- `review-precheck.test.sh`
- `ui-visual-check.test.sh`
- `visual-regression.test.sh`
- `wave-smoke.test.sh`
