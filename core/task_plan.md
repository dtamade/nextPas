# nextpas.core platform ABI import plan

## Goal

Build `nextpas.core.platform` into a broad, disciplined host ABI foundation for
nextPas. FPC source is the authority for raw platform API definitions; nextPas
copies those definitions into its own host `base` / `ffi` units and guards only
the integration boundary.

## Active Scope

- Current worktree: `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave8-file-io`
- Branch: `codex/platform-host-abi-wave8-file-io`
- Base: `main@ac4a6fe`
- Goal tree anchors: `G3` core/runtime/framework, `G7` FPC compatibility and
  ecosystem migration, `G0` quality discipline.
- Current wave: Platform Host ABI Completeness Wave 8, file I/O continuation.

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

### Wave 8: file I/O continuation

- [x] Open isolated worktree from latest `main`.
- [x] Baseline focused platform gate before edits.
- [x] Re-anchor the plan after user correction: FPC raw ABI definitions are
  authoritative and do not need nextPas runtime proof.
- [x] Add Wave 8 source-surface guard and confirm RED.
- [x] Import shared POSIX file I/O aliases, externals, and thin helpers for
  `read`, `write`, `lseek`, `fsync`, and `ftruncate`.
- [x] Import POSIX host seek tokens into Linux, Android, Darwin, FreeBSD, and
  generic Unix `base` owners.
- [x] Expose POSIX host delegated file I/O helpers from each POSIX host `ffi`
  unit without creating a public `platform.file` contract.
- [x] Import Windows file position, size, sync, and truncate raw ABI declarations
  and constants into `windows.base` / `windows.ffi`.
- [x] Update source evidence, gap matrix, and official verification route.
- [x] Run focused and full verification.
- [ ] Commit, merge to `main`, post-merge verify, and clean the worktree.

## Non-goals

- No public `nextpas.core.platform.file` contract in this wave.
- No `nextpas.core.platform.file.ffi` file.
- No runtime unit tests for FPC raw API values or record layouts.
- No L1 abstractions such as stopwatch, thread pool, channel, future, process
  runner, or command API inside `platform`.

## Verification Commands

- `git diff --check`
- `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave8_file_io clean test`
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
- `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave8_file_io clean test`:
  `5 total, 5 passed, 0 failed`.
- `make -C core/tests/nextpas.core.platform/test_platform_host_gap_matrix clean test`:
  `4 total, 4 passed, 0 failed`.
- `make -C core/tests/nextpas.core.platform/test_platform_ffi_source_evidence_index clean test`:
  `2 total, 2 passed, 0 failed`.
- `make -C core/tests/nextpas.core.platform/test_platform_ffi_import_workflow clean test`:
  `2 total, 2 passed, 0 failed`.
- `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`:
  Darwin, Android, FreeBSD, and generic Unix simulated host compile gates pass.
- Win64 compile-only gates pass for `core.time`, `platform.thread`, and
  `platform.sync`.
- `sh -n build/verify_local.sh`: pass.
- `make -C core examples`: pass, all examples compiled.
- `make -C core benchmarks`: pass, all benchmarks passed.
- `make -C core test`: pass, all tests passed.
- `bash build/verify_local.sh`: pass; final envelope reports
  `verify-local=pass`, `human-summary=local verification passed`, and
  includes `corePlatformHostAbiWave8FileIoCheck`.

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| Active planning files still described collections work in the Wave 7 platform worktree. | Session recovery | Replaced the active plan with platform ABI Wave 7 scope before implementation. |
