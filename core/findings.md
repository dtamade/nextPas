# Findings: Exception Root Convergence

## Current State Evidence

- `nextpas.core.base` defines `ECore`, `ETimeoutError`, and `EOutOfMemory` directly under RTL `Exception`.
- `nextpas.core.errors` defines a separate `ENextPasError`, `ETimeoutError`, and `EOutOfMemoryError`.
- `nextpas.core.mem.error` defines `EAllocError = class(ECore)` and a third `EOutOfMemory`.
- `nextpas.core.http.impl.h1` uses `E is ETimeoutError` for timeout request-read failure classification, so timeout identity must be canonical.
- `nextpas.core.tui.error` currently uses `ETui = class(ECore)`, so TUI migration belongs to a later stage after first-stage compatibility is proven.

## Design Decisions

- The official root unit is `nextpas.core.exception`.
- The official root class remains `ENextPasError`; no fourth root class name is introduced.
- `nextpas.core.base` will not depend on `nextpas.core.errors`.
- `ECore` stays as a compatibility name in stage 1 but is an alias of `ENextPasError`, so legacy `on E: ECore` catches canonical timeout and OOM aliases.
- `ETimeoutError` has one canonical class.
- `EOutOfMemoryError` is the explicit public OOM root; `EOutOfMemory` remains compatibility naming in the same lineage.
- `mem.error.EOutOfMemory` keeps the old `(TAllocError, msg)` constructor and `Error` property, but it follows the canonical OOM lineage instead of the non-OOM `EAllocError` lineage.
- Pascal single inheritance forces a migration choice for allocation OOM: canonical `EOutOfMemoryError` catch takes priority over old `EAllocError` catch.

## Subagent Review

- `/codex` read-only review confirmed the `mem.error.EOutOfMemory -> canonical OOM` tradeoff is acceptable.
- The review identified that `ECore = class(ENextPasError)` was too weak because old `on E: ECore` would not catch canonical aliases.
- The implementation was adjusted to `ECore = nextpas.core.exception.ENextPasError` and focused tests now lock this compatibility behavior.

## Worktree Safety

- Shared `main` currently contains HTTP colleague work and unrelated dirty/untracked files.
- This branch must be completed and committed in the isolated worktree.
- Merge back is deferred until shared `main` is clean or explicitly approved.
- During RED setup, relative patch paths wrote two new test files into shared `main`. They were files created by this session, were removed immediately, and shared `main` no longer reports that test directory in git status.

## RED Evidence

- `tests/nextpas.core.exception/test_exception_root` fails to compile because `nextpas.core.exception` does not exist.
- This is the expected RED proof for the new root infrastructure.
- Additional RED proof: after adding legacy `ECore` catch coverage, FPC reported `Class or Object types "ECore" and "EOutOfMemoryError" are not related`. This proved `ECore` needed to be a root alias, not a separate subclass.
