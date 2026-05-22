# Session Retrospective

## Problem

Lessons learned in agent sessions are lost. Errors repeat. Patterns aren't captured. Without structured extraction, knowledge stays trapped in conversation history.

## Protocol

### 1. Trigger
- User says "retro" at session end
- Automated: after every session >30 turns
- Scheduled: daily batch extraction

### 2. Extract (from conversation transcript)

**Structured Metrics:**
- Turn count, duration estimate
- Commit count, LOC changed
- Errors encountered, corrections made

**Categories:**
- **Errors:** Turns containing error/failure/workaround/fix patterns
- **Corrections:** User corrections, preference changes, "don't do X"
- **Decisions:** Architecture choices, approach selections
- **Dead ends:** Approaches abandoned and why

### 3. Synthesize

```markdown
## Retrospective: <date> — <topic>

### Metrics
- Duration: ~Xh | Turns: N | Commits: N | Errors: N

### Key Errors
- <Error>: <root cause> → <fix applied>

### Corrections (user preferences)
- <What user corrected> → <new behavior>

### Dead Ends
- Tried <approach>: failed because <reason>

### Forward Plan
- <What to do next time>
- <Open questions>
```

### 4. Route Output

| Content Type | Destination |
|---|---|
| Reusable pattern/footgun | Hot memory (`hot-memory.sh add`) |
| Project-specific learning | `.agents/knowledge/` |
| Session continuity | Workspace state file |
| General investigation | `~/plans/` or knowledge base |

### 5. Archive

Move transcript to archive (prevents re-processing):
```bash
mkdir -p ~/archive/sessions
mv /tmp/session-<id>.jsonl ~/archive/sessions/<date>-<topic>.jsonl
```

## Streak Tracking

Count consecutive days with development activity:
```bash
git log --format="%ad" --date=format:"%Y-%m-%d" | sort -u | tail -60
```

Display in retro header: `Session streak: N consecutive days`

## Anti-Patterns

- ❌ Retro without extraction tool → manual summary misses patterns
- ❌ Dumping everything into hot memory → exceeds budget, dilutes signal
- ❌ Never doing retros → same mistakes repeat
- ❌ Retro without forward plan → learning without action
