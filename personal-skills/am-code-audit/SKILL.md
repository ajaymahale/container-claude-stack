---
name: am-code-audit
description: >
  Use after completing a feature branch or before PR review. Runs a deep .NET code audit
  across modified files using project-specific standards and codified .NET best practices.
  Produces findings bucketed by severity (CRITICAL / WARNING / SUGGESTION), then walks
  the user through each finding conversationally — recommending fix, skip, or defer.
  Approved findings are handed off to /gsd-add-phase as a phase brief.
  Also use when the user asks to "audit", "self-review", "check code quality", "find issues",
  or wants a pre-merge review pass before sending to reviewers.
argument-hint: "[--branch=main] [--files=file1,file2,...] [--focus=performance|correctness|all] [--include-tests]"
allowed-tools:
  - Read
  - Bash
  - Grep
  - Glob
  - Write
  - Edit
  - AskUserQuestion
  - Skill
---

# /am-code-audit — Deep .NET Code Review & Recommendation Engine

Runs a pre-merge self-audit on changed files, catching the class of issues a senior reviewer would find at the code level — performance, correctness, robustness, observability, and design. Walks the user through each finding, pushes back on skipped CRITICALs, and hands approved fixes to GSD.

**This skill does not change production code.** It produces findings, a discussion, and a phase brief. The phase executes the work.

## Process

### Step 1: Scope — Identify files to audit

Parse arguments from `$ARGUMENTS`:
- `--branch=REF` (default: `main`) — base branch to diff against
- `--files=f1.cs,f2.cs` — explicit file list, overrides git diff
- `--focus=performance|correctness|all` (default: `all`) — limit audit to specific dimensions
- `--include-tests` — include test files and add test-specific audit dimension

```bash
BRANCH="${BRANCH:-main}"
CHANGED_FILES=$(git diff --name-only "$BRANCH"...HEAD -- '*.cs')
```

If `--files` is provided, use that list instead.

**Filter rules:**
- Always: only `.cs` files
- Default: exclude files matching `*Tests.cs`, `*Test.cs`, or under `tests/` directories
- With `--include-tests`: include all `.cs` files, add dimension 6 (Tests)

Present scope summary to user:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 AM-CODE-AUDIT ► SCOPE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Branch:    main → HEAD
Files:     {n} production files
Tests:     {excluded|included}
Focus:     {all|performance|correctness}

 {file list, one per line}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Ask user to confirm scope or adjust.

### Step 2: Baseline — Scout existing patterns

Before auditing changed files, read 3-4 representative "good" files from the repo to establish the pattern baseline. This grounds recommendations in actual conventions, not theoretical ideals.

**Read these files** (or closest equivalents that exist):

| Pattern | Reference file |
|---------|---------------|
| Handler | `src/Wow.Pic.Api/Handlers/ArticleGetQueryHandler.cs` |
| Repository | `src/Wow.Pic.Application/Repos/Article/ArticleRepository.cs` |
| Error handling | `src/Wow.Pic.Api/Middleware/ExceptionHandlingMiddleware.cs` |
| Singleton/Disposal | `src/Wow.Pic.Consumers.PicToArticleService/Services/ReversePublisherFactory.cs` |

Build an internal note answering:
- How does this repo handle errors? (PicValidationException, middleware, etc.)
- How are singletons cleaned up? (IAsyncDisposable pattern)
- How is CancellationToken threaded? (standard patterns vs. gaps)
- What does a well-structured handler look like? (MediatR + validator flow)
- How is DateTime handled? (UtcDateTimeExtensions, not SpecifyKind)
- What service lifetimes are used where? (Singleton for factories, Scoped for repos)

### Step 3: Deep Audit — Review dimension by dimension

For each file in scope, read the full file and apply the relevant analysis dimensions. **Do not skim** — read every line. The model must reason through each dimension explicitly before moving to the next.

This is the structured deep-thinking phase. Each dimension is checked against each file independently.

#### Dimension 1: Performance

Check every file for:
- **N+1 queries**: DB calls, repository calls, or HTTP calls inside `foreach`/`for` loops. Should be batched.
- **Hot-path allocations**: `new JsonSerializerOptions()` per request, `new List<T>()` in loops, LINQ `.ToList()` inside loops when streaming would suffice.
- **Missing batch operations**: Multiple single-item saves/queries that could be one batch operation.
- **Async over sync**: `.Result`, `.Wait()`, `.GetAwaiter().GetResult()` — acceptable ONLY in `Dispose()` implementations (DisposeAsync is preferred). Flag everywhere else.
- **Uncached client creation**: `new EventHubProducerClient()` or similar per invocation instead of singleton/cached.
- **Unnecessary string allocations**: `$""` interpolation in high-frequency paths, `ToString()` on enums in loops.
- **Unbounded result sets**: Repository or query methods that return `IEnumerable<T>` or `List<T>` without a `Take()`/`Limit` constraint. Every read method should accept a configurable limit parameter.
- **SELECT * patterns**: Fetching all columns from a collection/document when only a subset (projection) is needed. In MongoDB, pull only the fields the caller uses via `Builders<T>.Projection`.
- **Cartesian explosion**: Multiple `Include()` calls on EF Core queries (if present) that multiply row counts. In MongoDB, analogous over-fetching of embedded arrays across multiple sub-documents in a single query.
- **Application-side joins**: Two separate queries followed by an in-memory `.Join()` or `.Where()` match. The database should perform the join, not the application.
- **Premature materialization**: Multiple `.ToList()` calls in a single LINQ chain (e.g., `.Where(...).ToList().OrderBy(...).ToList()`). Defer enumeration to a single terminal `.ToList()`.
- **ValueTask misuse**: `ValueTask<T>` used for operations that are always truly asynchronous (e.g., every call hits MongoDB). `ValueTask` should be reserved for hot paths with a synchronous fast path (cache hits). Otherwise use `Task<T>`.
- **Mutable structs**: `struct` types with mutable fields or setters, which cause silent defensive copies. Should be `readonly record struct`.
- **High cyclomatic complexity as performance risk**: Methods with complexity > 20 that also lack test coverage are performance-risk hotspots (CRAP score > 30). Flag for coverage check even if the method "works."

#### Dimension 2: Correctness

Check every file for:
- **DateTime.SpecifyKind**: This only relabels the Kind flag — it does NOT convert the value. Should use `UtcDateTimeExtensions.ToUtcDateTime()` or `.ToUniversalTime()`.
- **Metrics before success**: `IncrementProcessedMessages` (or equivalent) called before the operation succeeds. If the operation fails, the metric is wrong.
- **Non-transient error retries**: Throwing exceptions for schema/parse failures that retry can't fix, blocking partition progress in EventHub consumers.
- **CancellationToken gaps**: `CancellationToken` available but not passed to async downstream calls (`PublishAsync`, `SaveAsync`, etc.). Each gap is a separate finding.
- **Race conditions**: Shared mutable state (dictionaries, lists, flags) accessed without `lock` or other synchronization. Check for missing `_disposed` flags.
- **Double-dispose**: `Dispose()` called in `finally` block on an object that was already disposed inline, without null guard.
- **Off-by-one**: Pagination cursors, batch sizing, index-based access that could miss the last item or include an extra.
- **Blocking on async (non-Dispose)**: `.Result`, `.Wait()`, `.GetAwaiter().GetResult()` on async methods outside of a `Dispose()`/`DisposeAsync()` implementation. Causes deadlocks on the synchronization context. (Distinct from the "Async over sync" check in Dimension 1 — this focuses on the deadlock risk rather than the performance cost.)
- **Shared mutable state without synchronization**: `List<T>`, `Dictionary<K,V>`, or plain fields mutated by multiple concurrent tasks without `ConcurrentBag<T>`, `ConcurrentDictionary<K,V>`, `lock`, or `Channel<T>`.
- **Manual Thread creation**: `new Thread(...)` instead of `Task.Run(...)`. Manual threads bypass the thread pool, waste resources, and are harder to manage.
- **Missing ConfigureAwait(false)**: In library/infrastructure code (handlers, repositories, consumers) that has no synchronization context. Omitting it forces unnecessary context captures.
- **TypeNameHandling.All in Newtonsoft.Json**: `$type` metadata embedded in serialized payloads. Renaming a class or assembly breaks deserialization of persisted data silently. Should use explicit discriminators or migrate to System.Text.Json.
- **BinaryFormatter usage**: Any reference to `BinaryFormatter` anywhere in the codebase. It is deprecated, has known security vulnerabilities (deserialization attacks), and should be removed.
- **Reflection-based serialization on hot paths**: `JsonConvert.SerializeObject()` (Newtonsoft) or `XmlSerializer` on request-per-second paths. Should use System.Text.Json source generators for AOT compatibility and zero-reflection overhead.

#### Dimension 3: Robustness

Check every file for:
- **Exception swallowing**: `catch (Exception)` blocks that silently continue or only log at Trace level without rethrowing or handling.
- **Overly broad catches**: `catch (Exception)` where a specific exception type (`MongoException`, `EventHubsException`, `TimeoutException`) would be more appropriate.
- **Missing constructor null guards**: DI-injected dependencies not checked with `ArgumentNullException.ThrowIfNull()`.
- **Sync DisposeAsync**: `.DisposeAsync().GetAwaiter().GetResult()` or `.AsTask().Wait()` — should implement `IAsyncDisposable` and await directly.
- **Batch TryAdd failure**: `TryAdd` to `EventDataBatch` returns false but the failure isn't logged or the count isn't adjusted.
- **Poison message handling**: EventHub consumer functions that throw on individual bad events, causing the entire batch to retry indefinitely.
- **Scoped service injected into Singleton**: A Singleton service takes a constructor dependency on a Scoped service (e.g., repository, DbContext). The Scoped dependency is captured once at startup and becomes stale. If the Singleton needs Scoped data, it must use `IServiceScopeFactory` to create a scope per operation.
- **Background services accessing Scoped services without scope**: `BackgroundService` or `IHostedService` implementations that inject Scoped services directly via constructor. Background services are Singletons — they must create a scope via `IServiceScopeFactory` for each unit of work.
- **Hardcoded configuration in DI registrations**: Connection strings, URLs, or API keys hardcoded in `services.AddSingleton(new SomeClient("https://..."))` instead of using `IOptions<T>` or configuration binding.
- **Missing IServiceCollection extension methods**: A `Program.cs` with dozens of inline `services.Add...` calls that should be organized into feature-scoped `AddXxxServices()` extension methods. Makes DI registrations hard to find and impossible to reuse in tests.

#### Dimension 4: Observability

Check every file for:
- **Unstructured logging**: `$"Processed {count} items"` instead of `_logger.LogInformation("Processed {Count} items", count)`. String interpolation bypasses structured logging.
- **Wrong log levels**: `LogError` for expected business conditions (404, validation failure), `LogInformation` for system errors. Should match: Trace=DB ops, Information=business events, Error=unexpected failures.
- **Missing event properties**: `EventData` published without `MessageId`, `CorrelationId`, or custom properties (`unique_key`, `DomainGrouping`, `DomainEvent`) that downstream consumers expect.
- **Inaccurate metric labels**: Log says "Published {Count}" but Count is the input total, not the actual successfully published count.
- **Wire compatibility concerns when changing serialized types**: Modifying a type that is serialized to Event Hub, MongoDB, or any persistence layer — adding required fields, renaming properties, or changing types — without considering backward and forward compatibility. Old consumers or old data will break silently.

#### Dimension 5: Design & Standards

Check every file for:
- **Dead code / YAGNI**: Config-driven branches that are never enabled, feature flags always off, `if` blocks that are never entered. Code that exists "just in case" adds cognitive load.
- **Missing IAsyncDisposable**: Class holds `EventHubProducerClient` or other `IAsyncDisposable` resources but only implements `IDisposable`.
- **Service lifetime mismatch**: Singleton service depends on Scoped service. Transient registered when Singleton is appropriate (stateless services).
- **Validator gap**: Handler has validation logic but no corresponding `IMessageValidator<T>` implementation registered in DI.
- **Logic in controller**: Business logic in controller that should be in a MediatR handler. Controller should delegate, not compute.
- **Mutable DTOs**: Classes with `{ get; set; }` properties used as DTOs, messages, or events. Should be `record` types for immutability, value equality, and `with` expression support.
- **Reflection-based mapping**: AutoMapper `CreateMap<>()` or similar reflection-based object mapping. This codebase uses explicit mapping methods or constructor mapping. Reflection mappers hide bugs, break at runtime, and are slow.
- **Deep inheritance hierarchies**: More than 2 levels of class inheritance (e.g., `BaseHandler : BaseService : BaseComponent`). Should use composition via interfaces and record types instead.
- **Missing readonly record struct for value objects**: Value objects (OrderId, ArticleId, etc.) implemented as `class` or mutable `struct` instead of `readonly record struct`. Value objects should have value semantics and zero-copy guarantees.
- **Breaking changes disguised as fixes**: Changing a method return type, making a sync method async, or removing a public member in a way that breaks callers. Add new members instead, deprecate old ones.
- **Silent behavior changes**: Changing default parameter values, swapping `true`/`false` defaults, or altering error handling behavior in a way that existing callers depend on silently.
- **Adding optional parameters to existing methods**: `void Process(Order order, CancellationToken ct = default)` added to an existing method. This is binary incompatible — compiled callers get `MissingMethodException` at runtime. Add a new overload instead.
- **Polymorphic serialization without explicit discriminators**: `$type` in JSON payloads instead of a schema-defined discriminator field. Renaming the class or namespace breaks the wire format silently.
- **Unsealed classes not designed for inheritance**: Public classes that are not `sealed` and have no `virtual` members or `protected` constructor. Seal by default; unseal only when inheritance is an explicit design choice.
- **Instance methods that should be static pure functions**: Methods that don't access any instance state (`this`) and could be `static`. Static pure functions are faster (no vtable), easier to test, and thread-safe.
- **Returning mutable collections from API boundaries**: `List<T>` or `Dictionary<K,V>` returned from public methods or handlers. Should return `IReadOnlyList<T>`, `IReadOnlyDictionary<K,V>`, or `IReadOnlyCollection<T>`.

#### Dimension 6: Tests (only when `--include-tests` provided)

Check every test file for:
- **Shallow assertions**: Test asserts `result != null` or `Assert.Single(result)` but doesn't verify field values. Should assert specific expected values.
- **Missing Moq Verify**: Mock setup exists but no `Verify()` call to confirm the mock was actually invoked with expected parameters.
- **Unnamed tests**: Method name is `Test1`, `HandleAsync_Test`, or similar. Should describe the scenario: `HandleAsync_WhenArticleNotFound_ReturnsNull`.
- **Happy-path only**: Only positive test cases. No tests for null inputs, empty collections, exception paths, or boundary conditions.
- **Shared state leaks**: Test class uses shared fields that aren't reset between tests. `[Fact]` tests should be isolated.
- **Wrong mock pattern**: `IAsyncEnumerable<T>` mocks not using `yield return` + `Task.Yield()` pattern (the codebase convention).

#### Dimension 7: Complexity Hotspots

Check every production file for:
- **High cyclomatic complexity**: Methods with cyclomatic complexity > 10. Count: if/else branches, switch cases, loop continuations, &&/|| conditions, catch blocks. Flag methods > 10 as WARNING, methods > 20 as CRITICAL.
- **CRAP score risk**: Estimate CRAP score (complexity x (1 - coverage)^2). If complexity > 15 and no corresponding test file exists, assume 0% coverage, yielding CRAP = complexity. Flag CRAP > 30 as WARNING. Flag CRAP > 50 as CRITICAL.
- **Large files**: Files exceeding 500 lines. Large files often mix concerns and hide bugs. Flag as SUGGESTION unless the file also has high complexity methods, then WARNING.
- **SRP violations**: Classes with more than 10 public methods. Likely mixing concerns — should be split into focused types. Flag as SUGGESTION unless methods also have high complexity, then WARNING.

**Pragmatism note**: For this transient codebase, complexity hotspots are SUGGESTION by default unless the method is in a hot path (Event Hub consumer, publish pipeline) or directly affects correctness. A complex-but-correct method that processes events at 10k/min is a higher priority than a complex admin utility.

### Step 4: Classify findings

For every issue found, create a structured finding:

```
FINDING #{n}:
  Severity:     CRITICAL | WARNING | SUGGESTION
  Category:     Performance | Correctness | Robustness | Observability | Design | Tests | Complexity
  File:         src/Wow.Pic.XXX/Path/File.cs:{line}
  Description:  {what's wrong, in plain English}
  Why:          {why it matters — concrete prod scenario, not abstract}
  Fix:          {code snippet showing the corrected code}
  Pragmatic:    YES (ship blocker) | MAYBE (worth if time allows) | NO (nice-to-have)
  Effort:       {estimated lines changed or minutes}
```

**Severity rules:**
- **CRITICAL**: Will cause incorrect behavior, data loss, or production outages. Examples: N+1 under load, race condition on disposal, DateTime bug producing wrong timestamps, non-transient retry loop blocking partition, TypeNameHandling producing unrecoverable data, Scoped-in-Singleton serving stale DbContext, method with complexity > 20 and zero test coverage in a consumer hot path.
- **WARNING**: Works now but fragile or suboptimal. Examples: missing CancellationToken that works until shutdown is slow, metrics slightly inaccurate, dead code adding cognitive load, unbounded result set that works until the collection grows, missing ConfigureAwait(false) in library code, method with complexity 15+ and no test coverage.
- **SUGGESTION**: Better practice, no functional impact. Examples: more specific exception type, structured logging improvement, test naming convention, mutable DTO that could be a record, unsealed class that could be sealed, file exceeding 500 lines.

**Pragmatic judgment rules:**
- YES: The code is in a hot path, affects correctness, or will bite in prod. Fix before merge.
- MAYBE: Worth doing if time allows, but won't block the PR. Could be a follow-up.
- NO: Nice-to-have improvement. Defer to a cleanup pass.

**Self-check before presenting**: Review each finding against the pattern baseline from Step 2. If the existing "good" code does the same thing (e.g., all repos use the same pattern), it's not a finding for this PR — it's a repo-wide convention. Note it as "repo-wide pattern, not PR-specific" and exclude from the PR findings unless the user asks for repo-wide audit.

### Step 5: Conversational triage

Present findings grouped by severity, starting with CRITICAL.

**Header:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 AM-CODE-AUDIT ► FINDINGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Files audited:     {n}
Dimensions:        {list}
Total findings:    {n}
  CRITICAL:        {n}   ← must fix
  WARNING:         {n}
  SUGGESTION:      {n}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**CRITICAL findings** — present one at a time. For each:
1. State the problem in plain English (no jargon)
2. Show the problematic code with line numbers
3. Explain the concrete prod scenario: "If X happens, Y will break because Z"
4. Show the fix
5. Ask: ACCEPT / SKIP / MODIFY

**Push-back rule**: If the user says SKIP on a CRITICAL:
- Push back once: "This is marked CRITICAL because {concrete scenario}. In production, {what breaks}. Are you sure you want to skip?"
- If user confirms skip again: accept, mark as `SKIP-ACKNOWLEDGED`, move on. No second push-back.

**WARNING findings** — batch-present in a table. Ask user which to action:
- Format: `| # | File:Line | Description | Pragmatic? | Effort |`
- User can: ACCEPT specific numbers, SKIP, DEFER to backlog, or MODIFY

**SUGGESTION findings** — summarize in one paragraph. Ask if any are of interest.
- If user wants details on specific ones, present individually.
- Default: defer all to backlog.

After triage, show running tally:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 AM-CODE-AUDIT ► TRIAGE RESULT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ACCEPTED:   {n} ({c} critical, {w} warning, {s} suggestion)
SKIPPED:    {n}
DEFERRED:   {n} (sent to backlog)
MODIFIED:   {n}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 6: Phase brief generation

If any findings were ACCEPTED, write `/tmp/am-code-audit/phase-brief.md`:

```markdown
# Phase Brief: Code Audit Findings

## Executive Summary
- ACCEPTED: {n} findings ({c} critical, {w} warnings, {s} suggestions)
- Files to modify: {unique file list}
- Estimated effort: {total effort}

## CRITICAL Findings

### F#{n}: {title}
- **File**: `src/.../File.cs:{line}`
- **Category**: Correctness
- **Problem**: {description}
- **Prod impact**: {concrete scenario}
- **Current code**:
  ```csharp
  // problematic code
  ```
- **Fixed code**:
  ```csharp
  // corrected code
  ```
- **Test plan**: {what to test to verify the fix}

### (repeat for each finding)

## WARNING Findings
(same structure)

## SUGGESTION Findings
(same structure)
```

Then invoke `/gsd-add-phase`. Suggested title:
```
Code audit: {N} fixes ({C} critical, {W} warnings, {S} suggestions)
```

Feed `/tmp/am-code-audit/phase-brief.md` as the context/description.

### Step 7: Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 AM-CODE-AUDIT ► COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Files audited:    {n}
Findings total:   {n}
  CRITICAL:       {n} ({accepted} accepted, {skipped} skipped)
  WARNING:        {n} ({accepted} accepted)
  SUGGESTION:     {n} ({accepted} accepted)

Phase created:    {phase-number} — .planning/phases/{phase-number}-{slug}/
Phase brief:      /tmp/am-code-audit/phase-brief.md

Next:
  /gsd-plan-phase {phase-number}      # flesh out the PLAN.md
  /gsd-execute-phase {phase-number}   # run the plans once planned
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Notes

- **Do not modify production code.** Only write scratch files under `/tmp/am-code-audit/` and create the phase directory via `/gsd-add-phase`.
- **Pattern baseline matters.** Always read the reference files in Step 2 before auditing. A finding that contradicts an established repo pattern is a bad finding — adjust or drop it.
- **Pragmatism over purity.** This codebase has an explicit design principle: "swiftly written to tactically tackle migration... a crutch... should be retired in a couple of quarters." Don't flag issues that don't matter for a transient codebase. Focus on prod-breakers and correctness.
- **One finding = one issue.** Don't bundle "missing CancellationToken" across 5 files into one finding. Each file is a separate finding with its own file:line and fix snippet.
- **Re-runnable.** Safe to run repeatedly. Each run overwrites scratch files and produces fresh findings.
- **Focus flag.** When `--focus=performance`, only run Dimension 1. When `--focus=correctness`, only run Dimension 2. When `all` (default), run all applicable dimensions.
- **No false confidence.** If the audit finds 0 CRITICAL issues, say "No CRITICAL findings" — don't inflate severity to appear thorough. Zero findings is a valid and good outcome.
