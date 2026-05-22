# Pipeline Pattern

Extracted from watchdog's engine-v2 pipeline system. A typed, composable stage pipeline for sequential data processing with error handling.

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

```typescript
// registry.ts — maps stage names to implementations
const stages: Record<string, PipelineStage> = {
  scan: new ScanStage(),
  ingest: new IngestStage(),
  derive_status: new DeriveStatusStage(),
  diagnose: new DiagnoseStage(),
  sync_tickets: new SyncTicketsStage(),
};
```

## Runner

```typescript
async function runPipeline(
  config: PipelineConfig,
  options: PipelineOptions = {}
): Promise<PipelineResult> {
  const results: StageResult[] = [];
  const context: PipelineContext = { projects: config.projects };
  const start = Date.now();

  for (const stageName of config.stages) {
    const stage = registry[stageName];
    const stageStart = Date.now();

    try {
      const output = await stage.execute(context);
      Object.assign(context, output);  // Stages enrich context
      results.push({ name: stageName, status: 'completed', duration: Date.now() - stageStart });
    } catch (error) {
      results.push({ name: stageName, status: 'failed', duration: Date.now() - stageStart, error: error.message });
      if (!options.continueOnError) {
        return { status: 'failed', stages: results, duration: Date.now() - start, failedStage: stageName, error: error.message };
      }
    }
  }

  const hasFailures = results.some(r => r.status === 'failed');
  return {
    status: hasFailures ? 'completed_with_errors' : 'completed',
    stages: results,
    duration: Date.now() - start,
  };
}
```

## Key Patterns

- **Context enrichment:** Each stage can add data to context for downstream stages
- **Fail-fast or continue:** `continueOnError` flag controls behavior
- **Duration tracking:** Every stage timed for observability
- **YAML-driven:** Pipeline definition is config, not code
- **Stage isolation:** Each stage is a class with single `execute()` method

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
