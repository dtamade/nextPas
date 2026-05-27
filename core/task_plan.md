# nextpas.core platform ABI import plan

## Goal

Build `nextpas.core.platform` into a broad, disciplined host ABI foundation for
nextPas. FPC source is the authority for raw platform API definitions; nextPas
copies those definitions into its own host `base` / `ffi` units and guards only
the integration boundary.

## Active Scope

- Current status: Wave 9 merged to `main` as `23f0dfd`
  (`platform: add Linux stat ABI wave 9`).
- Closed worktree:
  `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave9-posix-stat`
- Closed branch: `codex/platform-host-abi-wave9-posix-stat`
- Base: `main@524b27c`
- Goal tree anchors: `G3` core/runtime/framework, `G7` FPC compatibility and
  ecosystem migration, `G0` quality discipline.
- Current wave: Platform Host ABI Completeness Wave 9, Linux traditional stat
  raw ABI, closed; next wave should start from latest `main`.

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

### Wave 9: Linux traditional stat raw ABI

- [x] Open isolated worktree from latest `main`.
- [x] Baseline focused platform gate before edits.
- [x] Select next gap from goal tree and gap matrix: promote Linux traditional
  `stat` / `lstat` / `fstat` from the Wave 3 deferred POSIX stat family.
- [x] Add Wave 9 source-surface guard for owner, docs, and route discipline.
- [x] Import Linux `_STAT_VER`, `stat` record, and `__xstat` / `__lxstat` /
  `__fxstat` declarations into `linux.base` / `linux.ffi`.
- [x] Keep shared `posix.base` / `posix.ffi` free of a generic POSIX stat
  record or generic `stat` binding.
- [x] Update source evidence, gap matrix, and official verification route.
- [x] Run focused and full verification.
- [x] Commit, merge to `main`, post-merge verify, and clean the worktree.

## Non-goals

- No public `nextpas.core.platform.file` contract in this wave.
- No `nextpas.core.platform.file.ffi` file.
- No runtime unit tests for FPC raw API values or record layouts.
- No L1 abstractions such as stopwatch, thread pool, channel, future, process
  runner, or command API inside `platform`.
- No Darwin, FreeBSD, Android, or generic Unix traditional `stat` promotion in
  this wave; those hosts remain separate owner decisions because FPC records
  host-specific layout and suffix policy.

## Verification Commands

- `git diff --check`
- `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave9_linux_stat clean test`
- `make -C core/tests/nextpas.core.platform/test_platform_host_gap_matrix clean test`
- `make -C core/tests/nextpas.core.platform/test_platform_ffi_source_evidence_index clean test`
- `make -C core/tests/nextpas.core.platform/test_platform_ffi_import_workflow clean test`
- `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- `make -C core test`
- `make -C core examples`
- `make -C core benchmarks`
- `bash build/verify_local.sh`

### Verification Evidence

- `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave9_linux_stat clean test`:
  `5 total, 5 passed, 0 failed`.
- `make -C core/tests/nextpas.core.platform/test_platform_host_gap_matrix clean test`:
  `4 total, 4 passed, 0 failed`.
- `make -C core/tests/nextpas.core.platform/test_platform_ffi_source_evidence_index clean test`:
  `2 total, 2 passed, 0 failed`.
- `make -C core/tests/nextpas.core.platform/test_platform_ffi_import_workflow clean test`:
  `2 total, 2 passed, 0 failed`.
- `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`:
  Darwin, Android, FreeBSD, and generic Unix simulated compile routes passed.
- `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`:
  `8 total, 8 passed, 0 failed`.
- `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`:
  `14 total, 14 passed, 0 failed`.
- `git diff --check`: pass.
- `sh -n build/verify_local.sh`: pass.
- `make -C core test`: `All tests passed.`
- `make -C core examples`: `All examples compiled.`
- `make -C core benchmarks`: `All benchmarks passed.`
- `bash build/verify_local.sh`: `verify-local=pass`,
  `human-summary=local verification passed`, final envelope includes
  `corePlatformHostAbiWave9LinuxStatCheck`.
- Post-merge `bash build/verify_local.sh` on `main@23f0dfd`: pass; final
  envelope reports `verify-local=pass`, `human-summary=local verification
  passed`, and includes `corePlatformHostAbiWave9LinuxStatCheck`.

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| Active planning files still described collections work in the Wave 7 platform worktree. | Session recovery | Replaced the active plan with platform ABI Wave 7 scope before implementation. |
