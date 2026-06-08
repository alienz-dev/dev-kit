# Research Verdict: EARS Standard Integration

## Question
How should the dev-kit spec system adopt EARS (Easy Approach to Requirements Syntax) as a proper standard?

## Verdict
**The dev-kit already mandates EARS — but incompletely.** The research identified 4 gaps and patches were applied.

## Evidence

### Angle 1: EARS Patterns (Mavin et al., 2009)
- 5 core patterns: Ubiquitous (THE), Event-driven (WHEN), State-driven (WHILE), Unwanted (IF/THEN), Optional (WHERE)
- Complex (compound) patterns combine two or more
- Referenced in ISO/IEC/IEEE 29148, adopted in aerospace/automotive/medical
- Key insight: pattern keywords act as a requirements checklist

### Angle 2: Current Dev-Kit State
- Spec template showed only 3 of 5 patterns (missing Ubiquitous, WHERE)
- §5 Constraints was freeform prose (no SHALL/MUST language)
- BA agent said "follow EARS" but had no decomposition guide
- ba-validate checked syntax but not pattern coverage completeness

### Angle 3: Format Comparison
- EARS: best balance of structure + readability + testability for AI-assisted dev
- Gherkin: higher testability but requires tooling infrastructure
- SHALL: good for NFRs, poor for functional requirements (no trigger/precondition structure)
- Hybrid approach (EARS for functional + SHALL for NFRs) is the emerging consensus

## Patches Applied

### 1. Spec Template (`workflow/sdd/spec-template.md`)
- Expanded EARS section with all 5 patterns + "When to use" guidance
- Added coverage rule: happy-path AND error-path required per behavior
- Added NFR subsection to §5 with RFC 2119 SHALL/MUST templates and measurable threshold rules

### 2. BA Agent (`phases/design/agents/ba.md`)
- Added 4-step EARS decomposition guide (happy path → ongoing → errors → optional)
- Added pattern selection checklist
- Updated output format to include Pattern Coverage table
- Added SHALL/MUST language for constraints

### 3. ba-validate (`phases/design/skills/ba-validate/SKILL.md`)
- Added §3da EARS Pattern Coverage check
- Reports pattern counts with expected minimums
- Flags MAJOR if feature has happy-path but zero IF/THEN error criteria

### 4. SDD.md (`workflow/sdd/SDD.md`)
- Added Pattern Coverage completeness checklist
- Added Non-Functional Requirements (SHALL/MUST) section with RFC 2119 guidance
- Documented the hybrid approach: EARS for functional, SHALL/MUST for NFRs

## Risks & Unknowns
- Training data: EARS has lower LLM training data prevalence than Gherkin/User Stories. Mitigated by the structured templates being easy to learn from examples.
- Existing specs: no migration needed — existing EARS criteria remain valid, new patterns are additive.

## Recommendation
Done. All 4 patches applied and verified. Existing specs don't need migration — the changes are additive.
