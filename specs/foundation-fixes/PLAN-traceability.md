# Plan: Spec-Test Traceability Checker

> Derived from SPEC-004. Defines HOW + ORDER.

## Approach

Build a simple bash tool that greps for @spec annotations in test files, greps for
headings in spec files, and cross-references them. Outputs a coverage table.

## Steps

### Step 1: Create tools/spec-trace.sh
**Files:** `tools/spec-trace.sh`
**Action:** Create a bash script with the following logic:
1. Find all spec files: `find specs/ -name "SPEC-*.md" -o -name "spec-*.md"`
2. For each spec file, extract section headings: `grep "^##" $spec | sed 's/^#* //'`
3. Find all test files: `find ${1:-tests/} -name "*.test.*" -o -name "*.spec.*"`
4. For each test file, extract @spec annotations: `grep "@spec" $test | sed 's/.*@spec //'`
5. Cross-reference: for each spec section, check if any test references it
6. Print table: spec-file | section | covered/uncovered
7. Count uncovered sections, exit 1 if > 0

### Step 2: Add usage and help
**Files:** `tools/spec-trace.sh`
**Action:** Add `--help` flag showing usage: `spec-trace.sh [test-dir] [spec-dir]`
Default: test-dir=tests/, spec-dir=specs/

### Step 3: Make executable
**Action:** `chmod +x tools/spec-trace.sh`

## Test Strategy

1. `bash -n tools/spec-trace.sh` — syntax check
2. Create a test spec file with 3 sections and a test file with @spec annotations covering 2
3. Run spec-trace.sh — should report 1 uncovered section and exit 1
4. Run with --help — should print usage
5. Run in dev-kit repo — should find specs/ and report coverage

## Risks

- **Risk:** @spec format varies between projects
  **Mitigation:** Accept both `@spec file §section` and `@spec file § section`
- **Risk:** No spec files exist (graceful degradation)
  **Mitigation:** Print "no specs found" and exit 0
