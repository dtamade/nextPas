# Historical Progress: Exception Root Convergence

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

- Migrate any remaining module roots found in later audits that still inherit through the `ECore` compatibility alias. `nextpas.core.tui.error` is already migrated in Stage 1B.
- Gradually reduce modules that import both `nextpas.core.base` and `nextpas.core.errors`.
- Migrate allocation OOM catch sites, if found downstream, from `EAllocError` to `EOutOfMemoryError`. Known in-repo mem producers are already migrated in Stage 1B.
- Stop documenting `ECore` as a public framework root after module-specific roots are migrated.

## Stage 1B Continuation

Roadmap position:

- Still in `G0` quality discipline + Core L0 exception architecture governance.
- No compiler work touched.
- HTTP behavior was not changed; HTTP server was only used as a compatibility verification gate.

Completed in Stage 1B:

- Added focused `TVec.Reserve/ReserveExact` OOM tests in `tests/nextpas.core.collections/test_vec`.
- Migrated `TVec.Reserve/ReserveExact` failure exceptions from `ECore.Create` to canonical `EOutOfMemory.Create`.
- Added focused `tests/nextpas.core.mem/test_oom` covering canonical OOM catch semantics for `TAllocResult`, `TBlockPool`, blockpool `TArena`, `TGrowingBlockPool`, `TGrowingArena`, `TFixedPool`, `TGrowingFixedPool`, `TRingBuffer`, and `TStackPool`.
- Migrated mem `aeOutOfMemory` producer paths from `EAllocError`/module-specific `EAllocError` subclasses to canonical `EOutOfMemory`.
- Migrated `nextpas.core.tui.error.ETui` from `ECore` compatibility inheritance to direct `ENextPasError` inheritance.
- Updated TUI tests to cover official `ENextPasError` catch and legacy `ECore` compatibility catch.

Stage 1B verification:

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

make -C tests/nextpas.core.mem/test_oom clean test
--- nextpas.core.mem.oom: 5 total, 5 passed, 0 failed ---
0 unfreed memory blocks : 0

make -C tests/nextpas.core.tui/test_tui_error clean test
--- nextpas.core.tui.error: 4 total, 4 passed, 0 failed ---
0 unfreed memory blocks : 0

make -C tests/nextpas.core.collections/test_vec clean test
--- nextpas.core.collections.vec: 49 total, 49 passed, 0 failed ---
0 unfreed memory blocks : 0

make -C tests/nextpas.core.mem/test_mem clean test
PASS: all mem tests passed
0 unfreed memory blocks : 0

make -C tests/nextpas.core.mem/test_arena clean test
--- nextpas.core.mem.arena: 9 total, 9 passed, 0 failed ---
0 unfreed memory blocks : 0

make -C tests/nextpas.core.mem/test_arena_class clean test
--- nextpas.core.mem.arena_class: 9 total, 9 passed, 0 failed ---
0 unfreed memory blocks : 0

make -C tests/nextpas.core.mem/test_pool clean test
--- nextpas.core.mem.pool: 9 total, 9 passed, 0 failed ---
0 unfreed memory blocks : 0

make -C tests/nextpas.core.mem/test_blockpool clean test
--- nextpas.core.mem.blockpool: 9 total, 9 passed, 0 failed ---
0 unfreed memory blocks : 0

make -C tests/nextpas.core.mem/test_contracts clean test
--- nextpas.core.mem.contracts: 6 total, 6 passed, 0 failed ---
0 unfreed memory blocks : 0

make -C tests/nextpas.core.http/test_http_server clean test
--- nextpas.core.http.server: 275 total, 275 passed, 0 failed ---
0 unfreed memory blocks : 0

git diff --check
PASS
```

Stage 1B static audit:

```text
rg -n "class\(ECore\)|ECore\.Create" src --glob '!src/nextpas.core.base.pas'
no matches

rg -n "EAllocError\.Create\(aeOutOfMemory|E[A-Za-z0-9_]*Error\.Create\(aeOutOfMemory" src/nextpas.core.mem*.pas
no matches

rg -n "ETimeoutError\s*=\s*class|ETimeoutError\s*=\s*nextpas\.core\.exception\.ETimeoutError" src/nextpas.core.exception.pas src/nextpas.core.base.pas src/nextpas.core.errors.pas
canonical class in nextpas.core.exception; aliases only in base/errors
```

Updated follow-up migration items after Stage 1B:

- `ECore` compatibility classes still exist in `nextpas.core.base`; retire only after downstream modules stop treating `base` as the public exception root.
- Low-risk mixed imports remain in fs/io/compress/http and should be migrated in module-focused slices, not by broad replacement.
- HTTP files were intentionally not mechanically migrated in this round because current aliases already preserve timeout identity and a colleague is working in HTTP.
- TLS result utils still deserves a later focused review for bare `EOutOfMemory` binding and SSL error mapping.

## Post-Merge Reverification: 2026-06-06

Roadmap position:

- Still in `G0` quality discipline + Core L0 exception architecture governance.
- Current work is first-stage exception root convergence closeout.
- No compiler work touched.
- HTTP was only used as a focused compatibility gate.

Fresh verification commands all exited `0`:

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

make -C tests/nextpas.core.mem/test_oom clean test
--- nextpas.core.mem.oom: 5 total, 5 passed, 0 failed ---
0 unfreed memory blocks : 0

make -C tests/nextpas.core.tui/test_tui_error clean test
--- nextpas.core.tui.error: 4 total, 4 passed, 0 failed ---
0 unfreed memory blocks : 0

make -C tests/nextpas.core.collections/test_vec clean test
--- nextpas.core.collections.vec: 49 total, 49 passed, 0 failed ---
0 unfreed memory blocks : 0

make -C tests/nextpas.core.mem/test_mem clean test
PASS: all mem tests passed
0 unfreed memory blocks : 0

make -C tests/nextpas.core.mem/test_arena clean test
--- nextpas.core.mem.arena: 9 total, 9 passed, 0 failed ---
0 unfreed memory blocks : 0

make -C tests/nextpas.core.mem/test_arena_class clean test
--- nextpas.core.mem.arena_class: 9 total, 9 passed, 0 failed ---
0 unfreed memory blocks : 0

make -C tests/nextpas.core.mem/test_pool clean test
--- nextpas.core.mem.pool: 9 total, 9 passed, 0 failed ---
0 unfreed memory blocks : 0

make -C tests/nextpas.core.mem/test_blockpool clean test
--- nextpas.core.mem.blockpool: 9 total, 9 passed, 0 failed ---
0 unfreed memory blocks : 0

make -C tests/nextpas.core.mem/test_contracts clean test
--- nextpas.core.mem.contracts: 6 total, 6 passed, 0 failed ---
0 unfreed memory blocks : 0

make -C tests/nextpas.core.http/test_http_server clean test
--- nextpas.core.http.server: 275 total, 275 passed, 0 failed ---
0 unfreed memory blocks : 0

git diff --check
PASS
```

Fresh static audit:

```text
rg -n "class\(ECore\)|ECore\.Create" src --glob '!src/nextpas.core.base.pas'
no matches

rg -n "EAllocError\.Create\(aeOutOfMemory|E[A-Za-z0-9_]*Error\.Create\(aeOutOfMemory" src/nextpas.core.mem*.pas
no matches

rg -n "ENextPasError\s*=\s*class|ECore\s*=\s*class|ECore\s*=\s*nextpas\.core\.exception\.ENextPasError" src/nextpas.core.exception.pas src/nextpas.core.base.pas src/nextpas.core.errors.pas src/nextpas.core.mem.error.pas
one ENextPasError class in nextpas.core.exception; ECore is an alias only

rg -n "ETimeoutError\s*=\s*class|ETimeoutError\s*=\s*nextpas\.core\.exception\.ETimeoutError" src/nextpas.core.exception.pas src/nextpas.core.base.pas src/nextpas.core.errors.pas
canonical class in nextpas.core.exception; aliases only in base/errors
```

Merge safety:

- `main` is an ancestor of `codex/exception-root-20260605`; merge can be fast-forwarded.
- Branch changed paths and shared `main` dirty/untracked paths have no path intersection.
- Shared `main` still has unrelated dirty HTTP/async/compiler/control-file work; do not stash, reset, or rewrite it.

Reviewer closeout:

- Read-only reviewer reported no Critical/Important/Minor findings and no blocking merge issue.
- Reviewer did not rerun tests; local focused verification above is the test evidence for this closeout.
- Remaining risks are outside this stage: non-L0 modules with direct `Exception` roots, and `EOutOfMemory.CreateFmt` category coverage.
