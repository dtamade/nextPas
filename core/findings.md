# Findings: Exception Root Convergence

## Current State Evidence

- `nextpas.core.base` defines `ECore`, `ETimeoutError`, and `EOutOfMemory` directly under RTL `Exception`.
- `nextpas.core.errors` defines a separate `ENextPasError`, `ETimeoutError`, and `EOutOfMemoryError`.
- `nextpas.core.mem.error` defines `EAllocError = class(ECore)` and a third `EOutOfMemory`.
- `nextpas.core.http.impl.h1` uses `E is ETimeoutError` for timeout request-read failure classification, so timeout identity must be canonical.
- `nextpas.core.tui.error` previously used `ETui = class(ECore)`. Stage 1B migrated it to `ETui = class(ENextPasError)`.
- `TVec.Reserve/ReserveExact` previously used `ECore.Create` for allocation failure. Stage 1B migrated those failures to canonical OOM.
- Several mem modules raised `aeOutOfMemory` through `EAllocError` or module-specific `EAllocError` subclasses. Stage 1B migrated those OOM-producing paths to `EOutOfMemory`.

## Design Decisions

- The official root unit is `nextpas.core.exception`.
- The official root class remains `ENextPasError`; no fourth root class name is introduced.
- `nextpas.core.base` will not depend on `nextpas.core.errors`.
- `ECore` stays as a compatibility name in stage 1 but is an alias of `ENextPasError`, so legacy `on E: ECore` catches canonical timeout and OOM aliases.
- `ETimeoutError` has one canonical class.
- `EOutOfMemoryError` is the explicit public OOM root; `EOutOfMemory` remains compatibility naming in the same lineage.
- `mem.error.EOutOfMemory` keeps the old `(TAllocError, msg)` constructor and `Error` property, but it follows the canonical OOM lineage instead of the non-OOM `EAllocError` lineage.
- Pascal single inheritance forces a migration choice for allocation OOM: canonical `EOutOfMemoryError` catch takes priority over old `EAllocError` catch.
- Module-specific allocation errors still inherit from `EAllocError` for non-OOM conditions. OOM conditions now use canonical `EOutOfMemoryError` semantics instead of module-specific `EAllocError` subclasses.
- `ETui` now depends on `nextpas.core.exception` directly. `ECore` remains catch-compatible only because it is an alias of `ENextPasError`.

## Subagent Review

- `/codex` read-only review confirmed the `mem.error.EOutOfMemory -> canonical OOM` tradeoff is acceptable.
- The review identified that `ECore = class(ENextPasError)` was too weak because old `on E: ECore` would not catch canonical aliases.
- The implementation was adjusted to `ECore = nextpas.core.exception.ENextPasError` and focused tests now lock this compatibility behavior.
- A later read-only `/codex` audit identified remaining first-batch migration seams: `TVec.Reserve/ReserveExact`, mem `aeOutOfMemory` producers, and `nextpas.core.tui.error`. These were all addressed in Stage 1B.

## Worktree Safety

- Shared `main` currently contains HTTP colleague work and unrelated dirty/untracked files.
- This branch must be completed and committed in the isolated worktree.
- Merge back is deferred until shared `main` is clean or explicitly approved.
- During RED setup, relative patch paths wrote two new test files into shared `main`. They were files created by this session, were removed immediately, and shared `main` no longer reports that test directory in git status.

## RED Evidence

- `tests/nextpas.core.exception/test_exception_root` fails to compile because `nextpas.core.exception` does not exist.
- This is the expected RED proof for the new root infrastructure.
- Additional RED proof: after adding legacy `ECore` catch coverage, FPC reported `Class or Object types "ECore" and "EOutOfMemoryError" are not related`. This proved `ECore` needed to be a root alias, not a separate subclass.

## Stage 1B Evidence

- `tests/nextpas.core.collections/test_vec` RED failed at the new `Reserve/ReserveExact` OOM assertions before implementation migration; after replacing `ECore.Create` with `EOutOfMemory.Create`, it passes 49/49 with heaptrc 0.
- `tests/nextpas.core.mem/test_oom` RED failed for blockpool, growable mem, and allocator-backed mem OOM paths before mem producer migration; after migration it passes 5/5 with heaptrc 0.
- `nextpas.core.tui.error` source-contract RED found `ETui = class(ECore)`. After migration, no production `class(ECore)` remains outside `nextpas.core.base`.
- Static audit now shows no production `ECore.Create` outside the base compatibility layer, no `EAllocError.Create(aeOutOfMemory...)`, and exactly one public `ETimeoutError` class with base/errors aliases.
