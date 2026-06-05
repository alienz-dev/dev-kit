# Pipeline Pattern

A typed, composable stage pipeline for sequential data processing with error handling.

## Architecture

```
Pipeline Config (YAML)
  → Stage Registry (name → implementation)
    → Pipeline Runner (sequential execution with context passing)
      → Stage Results (status, duration, errors)
```

## Pipeline Config (YAML)

```yaml
name: nightly
schedule: '0 10 * * 1-5'
projects:
  - ProjectA
  - ProjectB
stages:
  - scan
  - ingest
  - derive_status
  - diagnose
  - sync_tickets
continueOnError: false
```

## TypeScript Types

```typescript
interface PipelineStage {
  name: string;
  execute(context: PipelineContext): Promise<Record<string, unknown>>;
}

interface PipelineContext {
  store?: unknown;
  db?: unknown;
  config?: unknown;
  projects?: string[];
  [key: string]: unknown;  // Stages can add to context
}

interface StageResult {
  name: string;
  status: 'completed' | 'failed';
  duration: number;
  error?: string;
}

interface PipelineResult {
  status: 'completed' | 'failed' | 'completed_with_errors';
  stages: StageResult[];
  duration: number;
  failedStage?: string;
  error?: string;
}

interface PipelineOptions {
  continueOnError?: boolean;
}
```

## Stage Registry

Stages use a factory pattern (not static instances) — each pipeline run gets fresh stage instances:

```typescript
// registry.ts
type StageFactory = () => PipelineStage;

function createStageRegistry() {
  const factories = new Map<string, StageFactory>();

  factories.set('scan', () => new ScanStage());
  factories.set('ingest', () => new IngestStage());
  factories.set('derive_status', () => new DeriveStatusStage());

  return {
    register(name: string, factory: StageFactory): void {
      factories.set(name, factory);
    },
    resolve(names: string[]): PipelineStage[] {
      return names.map(name => {
        const factory = factories.get(name);
        if (!factory) throw new Error(`Unknown pipeline stage: '${name}'`);
        return factory();
      });
    },
  };
}
```

## Runner

```typescript
async function run(
  stageNames: string[],
  initialContext: Record<string, unknown>,
  options?: PipelineOptions
): Promise<PipelineResult> {
  const start = Date.now();
  const stageResults: StageResult[] = [];
  let hasErrors = false;

  eventBus.dispatch({ event_type: 'pipeline_started', timestamp: Date.now() });

  // Context is immutable — each stage enriches via spread
  let mergedContext = { ...initialContext };

  for (const name of stageNames) {
    const stage = registry.resolve([name])[0];
    const stageStart = Date.now();

    try {
      const output = await stage.execute(mergedContext);
      stageResults.push({ name, status: 'completed', duration: Date.now() - stageStart });
      mergedContext = { ...mergedContext, ...output };
    } catch (err) {
      stageResults.push({ name, status: 'failed', duration: Date.now() - stageStart, error: err.message });

      if (!options?.continueOnError) {
        eventBus.dispatch({ event_type: 'pipeline_stage_failed', stage: name, error: err.message });
        return { status: 'failed', stages: stageResults, duration: Date.now() - start, failedStage: name };
      }
      hasErrors = true;
    }
  }

  const status = hasErrors ? 'completed_with_errors' : 'completed';
  eventBus.dispatch({ event_type: 'pipeline_completed', duration_ms: Date.now() - start, status });
  return { status, stages: stageResults, duration: Date.now() - start };
}
```

## Key Patterns

- **Factory registry:** Each run gets fresh stage instances (no shared state between runs)
- **Immutable context enrichment:** `{ ...mergedContext, ...output }` — stages can't corrupt upstream data
- **EventBus integration:** Pipeline emits lifecycle events (started, stage_failed, completed)
- **Fail-fast or continue:** `continueOnError` flag controls behavior
- **Duration tracking:** Every stage timed for observability
- **YAML-driven:** Pipeline definition is config, not code
- **Stage isolation:** Each stage is a class with single `execute()` method

## EventBus Integration

Pipelines emit events that subscribers can react to:

```typescript
interface PipelineEvent {
  event_type: 'pipeline_started' | 'pipeline_stage_failed' | 'pipeline_completed';
  timestamp: number;
  stage?: string;
  error?: string;
  duration_ms?: number;
  status?: string;
}
```

Subscribers can: log, notify, update dashboards, trigger downstream pipelines.

## FSM Integration

Pipelines connect to state machines via events. Example:
- `ingest` stage discovers new CVEs → fires `record_created` event
- `sync_tickets` stage finds ticket→CVE mapping → fires `ticket_created` event
- State machine transitions records based on events
- DB integrity invariants enforced: "after ticket creation, all matching records MUST transition"

## Hooks (lifecycle events)

```typescript
interface PipelineHooks {
  onStageStart?(stage: string, context: PipelineContext): void;
  onStageComplete?(stage: string, result: StageResult): void;
  onPipelineComplete?(result: PipelineResult): void;
  onError?(stage: string, error: Error): void;
}
```

## Pre-Commit as Pipeline

The pre-commit gate is a mini-pipeline:
```yaml
name: pre-commit
stages:
  - detect_changed_files
  - map_to_tests
  - run_affected_tests
  - typecheck
continueOnError: false
```
