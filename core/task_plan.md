# nextpas.core platform ABI import plan

## Goal

Build `nextpas.core.platform` into a broad, disciplined host ABI foundation for
nextPas. FPC source is the authority for raw platform API definitions; nextPas
copies those definitions into its own host `base` / `ffi` units and guards only
the integration boundary.

## Active Scope

- Current worktree: `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave7-process-status`
- Branch: `codex/platform-host-abi-wave7-process-status`
- Base: `main@79f1a05`
- Goal tree anchors: `G3` core/runtime/framework, `G7` FPC compatibility and
  ecosystem migration, `G0` quality discipline.
- Current wave: Platform Host ABI Completeness Wave 7, process wait-status and
  signal constants.

## Architecture Rules

- Production platform units must not `uses` FPC platform/RTL binding units such
  as `Linux`, `UnixType`, `BaseUnix`, `PThreads`, `Syscall`, or `Windows`.
- Host `base` units own constants, record shapes, opaque carriers, scalar
  aliases, syscall numbers, error-code values, and capability tokens.
- Host `ffi` units own raw external declarations and host-owned thin ABI
  projections.
- Shared POSIX ABI shapes belong in `nextpas.core.platform.posix.base`; shared
  POSIX pure arithmetic helpers belong in `nextpas.core.platform.posix.math`;
  shared POSIX external declarations belong in `nextpas.core.platform.posix.ffi`.
- `platform.time`, `platform.sync`, and `platform.thread` are unified public
  contracts. They consume host owners and must not grow `platform.time.ffi`,
  `platform.sync.ffi`, or `platform.thread.ffi`.
- Do not create public `platform.process` or `platform.process.ffi` in raw ABI
  import waves.

## Verification Boundary

- Raw FPC API definitions do not need runtime tests in nextPas. If FPC carries
  the API, constant, record, or macro logic, nextPas treats that definition as
  correct.
- Tests for raw ABI import waves are source-surface and route guards only:
  ownership placement, documentation synchronization, absence of feature-specific
  FFI units, absence of FPC platform-unit dependencies, and compile coherence.
- Runtime behavior tests belong to unified nextPas public contracts only.

## Current Phase

### Wave 7: process wait status and signal constants

- [x] Open isolated worktree from latest `main`.
- [x] Baseline focused platform gates before edits.
- [x] Re-anchor the plan after user correction: no runtime proof for FPC raw ABI
  definitions.
- [x] Add Wave 7 source-surface guard.
- [x] Import POSIX wait option tokens into host `base` units.
- [x] Import POSIX signal tokens into host `base` units, with host-specific
  `SIGCHLD` values.
- [x] Import FPC wait-status macro logic into shared POSIX math helpers.
- [x] Import Windows wait/process status/access tokens into `windows.base`.
- [x] Update source evidence, gap matrix, and official verification route.
- [x] Run focused and full verification.
- [ ] Commit, merge to `main`, post-merge verify, and clean the worktree.

## Non-goals

- No public `nextpas.core.platform.process` contract in this wave.
- No `nextpas.core.platform.process.ffi` file.
- No runtime unit tests for FPC raw API values or record layouts.
- No L1 abstractions such as stopwatch, thread pool, channel, future, process
  runner, or command API inside `platform`.

## Verification Commands

- `git diff --check`
- `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave7_process_status clean test`
- `make -C core/tests/nextpas.core.platform/test_platform_host_gap_matrix clean test`
- `make -C core/tests/nextpas.core.platform/test_platform_ffi_source_evidence_index clean test`
- `make -C core/tests/nextpas.core.platform/test_platform_ffi_import_workflow clean test`
- `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- `make -C core test`
- `make -C core examples`
- `make -C core benchmarks`
- `bash build/verify_local.sh`

### Verification Evidence

- `git diff --check`: pass.
- Focused Wave 7 and companion guards: pass.
- `make -C core test`: pass.
- `make -C core examples`: pass.
- `make -C core benchmarks`: pass.
- `bash build/verify_local.sh`: pass, including
  `corePlatformHostAbiWave7ProcessStatusCheck`.

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| Active planning files still described collections work in the Wave 7 platform worktree. | Session recovery | Replaced the active plan with platform ABI Wave 7 scope before implementation. |
