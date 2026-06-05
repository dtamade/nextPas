# Progress Log: Exception Root Convergence

## Session

- Scope: first-stage exception root convergence.
- Worktree: `/home/dtamade/.config/superpowers/worktrees/nextPas/exception-root-20260605`
- Branch: `codex/exception-root-20260605`
- Base: `5c28a959b5fd5065d1de98c93f9089d60bf80de1`

## Completed

- Created isolated worktree; shared dirty `main` was not modified.
- Ran baseline:

```text
make -C tests/nextpas.core.errors/test_errors clean test
PASS: all errors tests passed
0 unfreed memory blocks : 0
```

- Wrote design document:
  `docs/plans/2026-06-05-exception-root-convergence-design.md`.
- Wrote implementation plan:
  `docs/plans/2026-06-05-exception-root-convergence-plan.md`.
- Replaced branch-local `task_plan.md`, `findings.md`, and `progress.md` with the exception-root lane.
- Added RED focused test under `tests/nextpas.core.exception/test_exception_root`.
- RED verification:

```text
make -C tests/nextpas.core.exception/test_exception_root clean test
test_exception_root.lpr(7,3) Fatal: Can't find unit nextpas.core.exception used by test_exception_root
```

- Corrected an accidental relative-path patch that briefly created the RED test in shared `main`; those files were deleted and `git status -- tests/nextpas.core.exception` in shared `main` no longer reports them.
- Added `src/nextpas.core.exception.pas` as the canonical L0 framework exception root.
- Rewired `nextpas.core.errors` into a facade over `nextpas.core.exception`, including explicit category constant re-exports.
- Rewired `nextpas.core.base` so `ECore` is a compatibility alias of `ENextPasError`; `ETimeoutError` and `EOutOfMemory` are canonical aliases.
- Rewired `nextpas.core.mem.error` so `EAllocError` is under `ENextPasError` and mem OOM follows the canonical OOM lineage while preserving the old constructor and `Error` detail.
- Ran `/codex` subagent review. The review confirmed canonical OOM should win over old `EAllocError` OOM catch, and identified that `ECore` must be an alias rather than a subclass.
- Added focused tests for:
  - `ECore` catch compatibility over canonical aliases.
  - single runtime type for `base/errors.ETimeoutError`.
  - canonical OOM catch for `base`, `errors`, and `mem.error`.
  - non-OOM allocator errors still catching as `EAllocError`.
  - OOM not being swallowed by `EAllocError` before `EOutOfMemoryError`.

## Green Evidence So Far

```text
make -C tests/nextpas.core.exception/test_exception_root clean test
PASS: all exception root tests passed
0 unfreed memory blocks : 0
```

## Final Focused Verification

All commands exited `0`:

```text
make -C tests/nextpas.core.exception/test_exception_root clean test
PASS: all exception root tests passed
0 unfreed memory blocks : 0

make -C tests/nextpas.core.errors/test_errors clean test
PASS: all errors tests passed
0 unfreed memory blocks : 0

make -C tests/nextpas.core.base/test_base clean test
PASS: all base tests passed
0 unfreed memory blocks : 0

make -C tests/nextpas.core.tui/test_tui_error clean test
--- nextpas.core.tui.error: 3 total, 3 passed, 0 failed ---
0 unfreed memory blocks : 0

make -C tests/nextpas.core.mem/test_mem clean test
PASS: all mem tests passed
0 unfreed memory blocks : 0

make -C tests/nextpas.core.mem/test_arena clean test
--- nextpas.core.mem.arena: 9 total, 9 passed, 0 failed ---

make -C tests/nextpas.core.mem/test_arena_class clean test
--- nextpas.core.mem.arena_class: 9 total, 9 passed, 0 failed ---

make -C tests/nextpas.core.mem/test_pool clean test
--- nextpas.core.mem.pool: 9 total, 9 passed, 0 failed ---

make -C tests/nextpas.core.mem/test_blockpool clean test
--- nextpas.core.mem.blockpool: 9 total, 9 passed, 0 failed ---

make -C tests/nextpas.core.mem/test_contracts clean test
--- nextpas.core.mem.contracts: 6 total, 6 passed, 0 failed ---

make -C tests/nextpas.core.http/test_http_server clean test
--- nextpas.core.http.server: 275 total, 275 passed, 0 failed ---
0 unfreed memory blocks : 0

git diff --check
```

Existing compile warnings/notes appeared in SIMD, platform path, hash, and HTTP test code; they are unrelated to this exception-root slice and were not changed.

## Current Position

First-stage exception-root convergence is implemented and verified in the isolated worktree.

## Commit

```text
f198fc86 refactor(errors): introduce unified framework exception root
```

## Next Step

Merge remains deferred while shared `main` contains unrelated HTTP/async/compiler work.

## Follow-Up Migration Items

- Migrate module roots that still inherit through the `ECore` compatibility alias, starting with `nextpas.core.tui.error`.
- Gradually reduce modules that import both `nextpas.core.base` and `nextpas.core.errors`.
- Migrate allocation OOM catch sites, if found downstream, from `EAllocError` to `EOutOfMemoryError`.
- Stop documenting `ECore` as a public framework root after module-specific roots are migrated.
