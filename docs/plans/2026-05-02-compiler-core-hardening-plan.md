# nextPas Compiler Core Hardening Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** After Batch 34, continue strengthening the compiler core foundation before expanding developer tooling. Focus on resolver error recovery, workspace discovery edge cases, and semantic diagnostics quality.

**Rationale:** Architecture review identified that "front-end semantic truth、source-root / workspace truth 还在靠'先扫目录再猜'的最小基线撑着". Richer developer tooling needs a more robust foundation.

**Architecture:** Keep convergence-first discipline. Add error recovery paths, harden edge case handling, improve diagnostic quality. Do not add new features; focus on making existing features more robust.

**Tech Stack:** FreePascal, Pascal units under `compiler/frontend/`, shell verification via `bash build/verify_local.sh`.

---

## Continuous Execution Rules

- Work straight through the tasks in order. Do not pause after a green gate.
- Use TDD at the promotion-gate level: add verification first, see expected failure, implement, rerun.
- Before every commit, write a short review conclusion.
- Commit after every task using only files touched for that task.
- Keep Linux x86_64, FreePascal `stage0`, no new Pascal syntax, and `ABI compatibility is deferred`.

## Task 1: Resolver Error Recovery - Partial Resolution Success

**Goal:** When some units resolve successfully but others fail, resolver should continue and report all failures, not stop at first error.

**Files:**
- Modify: `compiler/frontend/np_unit_resolver.pas`
- Modify: `build/verify_local.sh`
- Add: `tests/compiler/fail/multiple_missing_units_fail.pas`
- Add: `tests/snapshots/compiler-fail-multiple_missing_units.stderr.txt`
- Modify: `docs/architecture/unit-resolution-specification.md`
- Modify: `progress.md`

**Step 1: Write failing verification gate**

Add test case `tests/compiler/fail/multiple_missing_units_fail.pas`:

```pascal
program MultipleFailures;
uses MissingUnitA, MissingUnitB;
begin
end.
```

Add gate to `build/verify_local.sh`:

```bash
printf 'multiple-missing-units-check=running\n'
if run_stage0_build_capture "$MULTIPLE_MISSING_OUTPUT" tests/compiler/fail/multiple_missing_units_fail.pas; then
  fail 'expected-multiple-missing-units-failure-did-not-fail'
fi
require_output_pattern '^diagnostics-count=2$' "$MULTIPLE_MISSING_OUTPUT" 'missing-multiple-diagnostics-count'
require_output_pattern 'MissingUnitA.*not found' "$MULTIPLE_MISSING_OUTPUT" 'missing-first-unit-diagnostic'
require_output_pattern 'MissingUnitB.*not found' "$MULTIPLE_MISSING_OUTPUT" 'missing-second-unit-diagnostic'
printf 'multiple-missing-units-check=pass\n'
```

**Step 2: Implement error recovery**

In `np_unit_resolver.pas`:
- Change `ResolveDependency` to return boolean but continue on failure
- Accumulate all resolution failures in diagnostics sink
- Set `FResolutionStatus := 'failure'` but continue processing remaining units
- Ensure `ResolveRoot` processes all interface and implementation uses even if some fail

**Step 3: Update docs and commit**

Document error recovery strategy in `unit-resolution-specification.md`.

Commit:
```bash
git add compiler/frontend/np_unit_resolver.pas build/verify_local.sh tests/compiler/fail/multiple_missing_units_fail.pas tests/snapshots/ docs/architecture/unit-resolution-specification.md progress.md
git commit -m "feat: resolver continues on partial resolution failure

- ResolveDependency now accumulates all failures instead of stopping at first
- Multiple missing units are all reported in diagnostics
- Add multiple_missing_units_fail test case
- Update unit-resolution-specification with error recovery contract"
```

## Task 2: Workspace Discovery - Symlink and Permission Edge Cases

**Goal:** Workspace discovery should handle symlinks, permission errors, and malformed manifests gracefully.

**Files:**
- Modify: `compiler/frontend/np_workspace_model.pas`
- Modify: `build/verify_local.sh`
- Add: `tests/fixtures/malformed_manifest/`
- Modify: `docs/architecture/workspace-specification.md`
- Modify: `progress.md`

**Step 1: Write failing verification gates**

Add test fixtures:
- `tests/fixtures/malformed_manifest/nextpas.package.toml` (invalid TOML)
- `tests/fixtures/empty_manifest/nextpas.package.toml` (valid but empty)

Add gates to `build/verify_local.sh`:

```bash
printf 'malformed-manifest-check=running\n'
if run_stage0_build_capture "$MALFORMED_MANIFEST_OUTPUT" tests/fixtures/malformed_manifest/test.pas; then
  fail 'expected-malformed-manifest-to-fail-gracefully'
fi
require_output_pattern 'manifest.*parse.*failed\|invalid.*manifest' "$MALFORMED_MANIFEST_OUTPUT" 'missing-manifest-parse-error'
printf 'malformed-manifest-check=pass\n'
```

**Step 2: Implement graceful degradation**

In `np_workspace_model.pas`:
- Wrap manifest parsing in try-except
- On parse failure, emit diagnostic but continue with workspace-root-only model
- Handle missing source roots gracefully (empty array, not crash)
- Validate manifest paths are within workspace root

**Step 3: Update docs and commit**

Document error handling strategy in `workspace-specification.md`.

Commit:
```bash
git add compiler/frontend/np_workspace_model.pas build/verify_local.sh tests/fixtures/ docs/architecture/workspace-specification.md progress.md
git commit -m "feat: workspace discovery handles malformed manifests gracefully

- Manifest parse failures emit diagnostic but don't crash
- Empty or missing source roots handled as empty array
- Add malformed_manifest test fixture
- Update workspace-specification with error handling contract"
```

## Task 3: Semantic Diagnostics - Richer Context in Error Messages

**Goal:** Improve diagnostic quality by adding more context: file location, suggested fixes, related information.

**Files:**
- Modify: `compiler/diagnostics/np_diagnostics_sink.pas`
- Modify: `compiler/frontend/np_unit_resolver.pas`
- Modify: `build/verify_local.sh`
- Modify: `docs/architecture/compiler-specification.md`
- Modify: `progress.md`

**Step 1: Extend diagnostic structure**

In `np_diagnostics_sink.pas`:
- Add optional `RelatedInformation: array of TDiagnosticRelatedInfo` field
- Add optional `SuggestedFix: string` field
- Ensure these fields are projected in `command-envelope` JSON

**Step 2: Enhance resolver diagnostics**

In `np_unit_resolver.pas`:
- For `unit-not-found`: add suggested fix "Check unit name spelling or add unit root"
- For `ambiguous-unit-source`: add related information showing all candidate paths
- For `unit-cycle`: add related information showing full cycle path

**Step 3: Update verification**

Update `build/verify_local.sh` to verify new fields are present in envelope.

**Step 4: Update docs and commit**

Document diagnostic structure in `compiler-specification.md`.

Commit:
```bash
git add compiler/diagnostics/np_diagnostics_sink.pas compiler/frontend/np_unit_resolver.pas build/verify_local.sh docs/architecture/compiler-specification.md progress.md
git commit -m "feat: richer diagnostic context with related info and suggested fixes

- Add RelatedInformation and SuggestedFix to diagnostic structure
- Resolver diagnostics now include actionable suggestions
- Ambiguous unit errors show all candidate paths
- Update compiler-specification with diagnostic contract"
```

## Task 4: Search Index - Incremental Invalidation Preparation

**Goal:** Prepare search index for future incremental invalidation by adding staleness tracking.

**Files:**
- Modify: `compiler/frontend/np_unit_resolver.pas`
- Modify: `docs/architecture/unit-resolution-specification.md`
- Modify: `progress.md`

**Step 1: Add staleness tracking**

In `np_unit_resolver.pas`:
- Add `LastScanTimestamp: Int64` to `TRootSearchIndex`
- Add `function IsStale(const ARootIndex: LongInt): Boolean`
- Document but don't yet implement automatic invalidation

**Step 2: Update docs**

In `unit-resolution-specification.md`:
- Document the fourth state: `stale` (needs rebuild)
- Clarify when index should be marked stale (file system changes)
- Mark as preparation for future language service

**Step 3: Commit**

```bash
git add compiler/frontend/np_unit_resolver.pas docs/architecture/unit-resolution-specification.md progress.md
git commit -m "feat: prepare search index for incremental invalidation

- Add staleness tracking to TRootSearchIndex
- Document 'stale' state in unit-resolution-specification
- No automatic invalidation yet (future language service feature)
- Preparation for stage1 incremental compilation"
```

## Task 5: Final Verification and Documentation Sync

**Goal:** Run full verification, update all tracking documents, sync roadmap.

**Files:**
- Modify: `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`
- Modify: `progress.md`
- Modify: `findings.md`

**Step 1: Run full verification**

```bash
bash build/verify_local.sh
```

Expected: `verify-local=pass` with all new checks passing.

**Step 2: Update roadmap**

Add Batch 35 entry in master-roadmap-plan.md documenting compiler core hardening.

**Step 3: Commit**

```bash
git add docs/plans/2026-03-24-nextpas-master-roadmap-plan.md progress.md findings.md
git commit -m "docs: sync roadmap after compiler core hardening (Batch 35)

- Document error recovery, workspace edge cases, diagnostic quality improvements
- Update current status to reflect hardened resolver and workspace discovery
- Record preparation for future incremental compilation"
```

## Final Completion Gate

Run:

```bash
git status --short
bash build/verify_local.sh
```

Expected:
- Only unrelated pre-existing untracked files remain
- `verify-local=pass`
- All tasks completed

Final response must include:
- Commits created
- Verification result
- Assessment of compiler core robustness improvement
