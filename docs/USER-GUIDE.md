# SDD User Guide

How to use the SDD system in Claude Code. No jargon, just what to type and what happens.

## Quick Start

```
# 1. Start Claude Code in your project
cd my-project
claude

# 2. Describe what you want
> add dark mode support

# 3. Answer design questions (the system asks you)

# 4. When design is done, run the implementation
> /sdd dark-mode

# 5. Play with the result, file issues if needed
```

## The Two Phases

### Phase 1: Design (you make decisions)

You describe what you want. The system asks you questions to clarify the design.

```
> add dark mode support

The system:
- Gathers requirements (may ask clarifying questions)
- Asks design questions (color scheme? toggle location? system preference?)
- Writes a spec document
- Validates the spec

You:
- Answer questions
- Make design decisions
- Approve the spec when ready
```

**What you type:**
```
> add dark mode support                    # describe the feature
> /grill dark mode                         # optional: explicit design interview
> /ba-validate specs/SPEC-DARKMODE.md      # optional: check spec quality
```

**What you see:**
```
Design Questions:

1. Should dark mode follow system preference, or be manual toggle only?
   Recommended: System preference with manual override (most users expect this)

2. Where should the toggle go?
   Recommended: Settings page + quick-access in header

3. What about images — should they change in dark mode?
   Recommended: Only if they have dark variants (don't force-invert)

Your answers shape the spec. When done, the spec is written and validated.
```

### Phase 2: Implementation (automatic)

After design is done, one command runs everything.

```
> /sdd dark-mode
```

**What you see:**
```
SDD Pipeline: dark-mode
Spec: specs/SPEC-DARKMODE.md (status: approved)
Pipeline: initialized at plan stage

Phase 1: Plan
  Wave 1: theme toggle, CSS variables (independent)
  Wave 2: component updates (depends on wave 1)

Phase 2: Test Manager
  Writing 8 visible tests, 4 hidden tests
  Verifying RED... all 12 tests fail ✓

Phase 3: Implementation
  Wave 1: dispatching 2 coders
    coder-1: src/theme.ts ✓
    coder-2: src/components/Toggle.tsx ✓
  GREEN gate: 8/8 visible tests pass ✓
  Wiring gate: no orphaned modules ✓

  Wave 2: dispatching 1 coder
    coder-3: src/components/Card.tsx, src/components/Modal.tsx ✓
  GREEN gate: 12/12 tests pass ✓
  Hidden gate: 4/4 hidden tests pass ✓

Phase 4: Review
  Spawning reviewer-lite...
  Verdict: APPROVE (0 blocking, 0 major, 2 minor)

═══════════════════════════════════════
SDD Pipeline Complete: dark-mode
═══════════════════════════════════════
Files: 5 modified
Tests: 12/12 passing
Review: APPROVE (2 minor findings)
Status: done

Next steps:
  1. Play with the feature
  2. File issues if changes needed
  3. Run /sdd again for fixes
═══════════════════════════════════════
```

**You don't do anything during this phase.** It runs to completion. Go get coffee.

### Phase 3: Review (you evaluate)

After implementation completes, you play with the result.

```
# Try the feature
# Check if it looks right
# Run the app, click around
# Check the minor findings from the reviewer

# If everything looks good:
> ship it

# If something needs fixing:
> the toggle doesn't animate smoothly

# The system files an issue and you can run:
> /sdd dark-mode    # runs again with the fix

# If the design needs changing:
> /grill dark mode  # back to design phase
```

## Commands Reference

| Command | What It Does | When To Use |
|---------|-------------|-------------|
| `<description>` | Describe what you want | Start of any feature |
| `/grill <topic>` | Design interview | When you want explicit design Q&A |
| `/ba-validate <spec>` | Check spec quality | Before approving a spec |
| `/spec-align <spec>` | Compare spec vs code | When spec and code diverge |
| `/sdd <feature>` | Run implementation | After design is approved |
| `/researcher <question>` | Deep research | When you need to investigate |

## What Happens Behind the Scenes

You don't need to know this, but here's what the system does:

```
Your "add dark mode" request
  ↓
BA agent gathers requirements
  ↓
/grill asks you design questions
  ↓
Spec is written and validated
  ↓
/sdd runs automatically:
  → Plan derived from spec
  → Tests written (test-manager)
  → Code implemented (coder agents, parallel)
  → Quality gates pass
  → Code reviewed (reviewer agent)
  ↓
You review the result
```

## Filing Issues for Next Round

After reviewing, if you find problems:

```
# Just describe the problem naturally:
> the toggle button is too small on mobile

# The system creates an issue and you can run:
> /sdd dark-mode    # picks up the issue and fixes it

# Or if it's a design change:
> /grill dark mode  # re-opens design decisions
```

## Tips

1. **Be specific in your initial request.** "Add dark mode with system preference detection and a toggle in the header" is better than "add dark mode".

2. **Answer design questions thoughtfully.** The implementation follows your design decisions. Garbage in, garbage out.

3. **Let /sdd run to completion.** Don't interrupt it. If something goes wrong, it will stop and tell you.

4. **File issues, don't fix code directly.** The system tracks issues and uses them to guide implementation. If you fix code directly, the system doesn't know.

5. **Run /sdd again for fixes.** Each run is a complete implementation cycle. File an issue, run /sdd, review.

## What Works Today

| Feature | Status |
|---------|--------|
| `/grill` design interview | ✅ Works |
| `/ba-validate` spec validation | ✅ Works |
| `/spec-align` spec-code comparison | ✅ Works |
| `/sdd` full implementation pipeline | ✅ Works (new) |
| `/trio` coder dispatch | ✅ Works |
| `/researcher` deep research | ✅ Works |
| `issue-cli` issue tracking | ✅ Works |
| Pipeline gates (quality checks) | ✅ Works |

## Limitations

1. **Design phase may need multiple rounds.** Complex features might need several grill sessions.

2. **Implementation isn't perfect.** Coders might misunderstand tests. The system retries automatically, but sometimes you need to file issues for fixes.

3. **Review is advisory.** The reviewer catches many issues but not all. Always play with the result.

4. **No visual testing yet.** The system checks code quality but can't verify how things look. You need to check the UI yourself.

5. **Single feature at a time.** Run one /sdd at a time. Don't run multiple features in parallel.
