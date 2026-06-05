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
- `ECore` stays as a compatibility root in stage 1 but inherits from `ENextPasError`.
- `ETimeoutError` has one canonical class.
- `EOutOfMemoryError` is the explicit public OOM root; `EOutOfMemory` remains compatibility naming in the same lineage.

## Worktree Safety

- Shared `main` currently contains HTTP colleague work and unrelated dirty/untracked files.
- This branch must be completed and committed in the isolated worktree.
- Merge back is deferred until shared `main` is clean or explicitly approved.
