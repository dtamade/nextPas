# nextpas.core platform ABI import plan

## Goal

Build `nextpas.core.platform` into a broad, disciplined host ABI foundation for
nextPas. FPC source is the authority for raw platform API definitions; nextPas
copies those definitions into its own host `base` / `ffi` units and guards only
the integration boundary.

## Active Scope

- Current status: Wave 14 is closed on `main@7c50af6`. The feature commit was
  rebased onto the latest main, fast-forward merged, post-merge
  `bash build/verify_local.sh` passed, and the temporary worktree / branch were
  removed.
- Goal tree anchors: `G3` core/runtime/framework, `G7` FPC compatibility and
  ecosystem migration, `G0` quality discipline.
- Last closed wave: Platform Host ABI Completeness Wave 14, remaining
  thread/sync/time host FFI helper ownership-name cleanup. This wave corrected
  Android, Darwin, FreeBSD, generic Unix, and Windows clock `platform_*`
  host-owned helper names for pthread, clock, errno, native thread id, and CPU
  count before the next broad FPC raw API import wave.

## Architecture Rules

- Production platform units must not `uses` FPC platform/RTL binding units such
  as `Linux`, `UnixType`, `BaseUnix`, `PThreads`, `Syscall`, or `Windows`.
- Host `base` units own constants, record shapes, opaque carriers, scalar
  aliases, syscall numbers, error-code values, and capability tokens.
- Host `ffi` units own raw external declarations and host-owned thin ABI
  projections.
- Host-owned helper projections must use their owning host prefix such as
  `linux_*`, `android_*`, `darwin_*`, `freebsd_*`, `unix_*`, or `windows_*`.
  Shared POSIX helper projections keep the `platform_posix_*` prefix because
  their owner is `nextpas.core.platform.posix.ffi`. Unified-looking
  `platform_*` names belong to public platform contracts, not host FFI helpers.
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
- Source import from FPC is evidence work, not rediscovery work. Do not add
  runtime probes just to prove FPC-owned raw OS API definitions again.
- Tests for raw ABI import waves are source-surface and route guards only:
  ownership placement, documentation synchronization, absence of feature-specific
  FFI units, absence of FPC platform-unit dependencies, and compile coherence.
- Runtime behavior tests belong to unified nextPas public contracts only.

## Current Phase

### Wave 14: remaining host FFI helper ownership-name cleanup

- [x] Continue in isolated worktree from latest `main@dcf3fd3`.
- [x] Re-read active platform ABI import plan, evidence index, gap matrix, and
  source-surface tests.
- [x] Reaffirm user rule: copied FPC raw API definitions are authoritative and
  do not need nextPas runtime proof; tests guard only nextPas integration
  discipline.
- [x] Add RED source-surface guards requiring Android, Darwin, FreeBSD, and
  generic Unix host-owned pthread/clock/errno/thread/cpu helpers to use
  `android_*`, `darwin_*`, `freebsd_*`, and `unix_*` names.
- [x] Rename the non-Linux POSIX host-owned helper projections and update
  `platform.time.host`, `platform.sync`, and `platform.thread` dispatch helpers
  to consume those host-owned names.
- [x] Extend the same owner-name cleanup to Windows clock helpers by using
  `windows_clock_*` for the host-owned QPC/FILETIME projections.
- [x] Keep shared `platform_posix_*` helpers unchanged because they are owned by
  the shared POSIX owner.
- [x] Record remaining older raw ABI helper-name debt, such as file/path/env/dl
  `platform_*` helpers, as a later cleanup wave instead of expanding this
  pthread/clock/errno/thread/cpu wave mid-flight.
- [x] Run focused and full verification.
- [x] Commit, merge to `main`, post-merge verify, clean the worktree, and
  delete the feature branch.

#### Wave 14 Verification Boundary

- This is naming/ownership cleanup for existing FPC-backed raw ABI helpers, not
  runtime proof of pthread, clock, errno, thread-id, or sysconf behavior.
- FPC remains the correctness authority for raw ABI declarations and constants.
  Wave 14 guards nextPas integration discipline: host helper owner names,
  consumer routing, docs truth, no FPC platform-unit dependency, and compile
  coherence.

#### Wave 14 Non-goals

- No new raw OS API family import in this wave.
- No public `platform.process`, `platform.file`, or new feature-specific FFI.
- No runtime tests for raw FPC API definitions.
- No broad rename of older file/path/env/dl helpers in this wave; that debt is
  tracked for a later owner-name cleanup after the current thread/sync/time
  helper family is closed cleanly.

### Wave 13: Linux host FFI helper ownership-name cleanup

- [x] Open isolated worktree from latest `main@eab4c19`.
- [x] Re-read active platform ABI import plan, evidence index, gap matrix, and
  goal-tree rules.
- [x] Select the highest-risk naming debt from user review: Linux host FFI still
  exposes host-owned pthread/clock/errno/thread/cpu helper projections with
  unified-looking `platform_*` names.
- [x] Add RED source-surface guard requiring Linux host-owned helpers to use
  `linux_*` names and rejecting Linux `platform_pthread_*`,
  `platform_clock_*`, `platform_thread_self_token_u64`,
  `platform_native_thread_id_u64`, `platform_cpu_count_i32`,
  `platform_errno_location`, and `platform_posix_errno_value` helper exports.
- [x] Rename Linux host-owned helpers to `linux_*` and update Linux branches in
  `platform.time.host`, `platform.sync`, and `platform.thread` to consume those
  host-owned names.
- [x] Keep shared `platform_posix_*` helpers unchanged because they are owned by
  the shared POSIX owner, not by Linux.
- [x] Record remaining Android / Darwin / FreeBSD / generic Unix helper-name
  debt as the next required wave instead of pretending Linux-only cleanup closes
  the whole family.
- [x] Run focused and full verification.
- [x] Commit, merge to `main`, post-merge verify, clean the worktree, and
  delete the feature branch.

#### Wave 13 Verification Boundary

- This is naming/ownership cleanup for existing FPC-backed raw ABI helpers, not
  runtime proof of pthread, clock, errno, thread-id, or sysconf behavior.
- FPC remains the correctness authority for raw ABI declarations and constants.
  Wave 13 guards nextPas integration discipline: host helper owner names,
  consumer boundary, docs truth, no FPC platform-unit dependency, and compile
  coherence.

#### Wave 13 Non-goals

- No new raw OS API family import in this wave.
- No public `platform.process`, `platform.file`, or new feature-specific FFI.
- No runtime tests for raw FPC API definitions.
- No Android / Darwin / FreeBSD / generic Unix bulk rename in this wave; those
  remain the next cleanup wave to keep the Linux correction reviewable.

### Wave 12: host FFI process-id helper ownership cleanup

- [x] Open isolated worktree from latest `main`.
- [x] Reconfirm goal-tree anchors: G3 core/runtime/framework, G7 FPC
  compatibility, G0 quality discipline.
- [x] Select boundary cleanup from the Wave 11 retrospective: POSIX host FFI
  process-id helpers must use host prefixes and must not look like a public
  unified `platform.process` contract.
- [x] Add RED source-surface guard to Wave 1 host ABI test.
- [x] Rename POSIX host `platform_process_id` /
  `platform_parent_process_id` helpers to host-prefixed names:
  `linux_*`, `android_*`, `darwin_*`, `freebsd_*`, and `unix_*`.
- [x] Update source evidence, gap matrix, and goal-tree route truth.
- [x] Run focused and full verification.
- [x] Commit, merge to `main`, post-merge verify, clean the worktree, and
  delete the feature branch.

#### Wave 12 Verification Boundary

- This is owner-boundary cleanup for an existing raw ABI wave, not runtime
  process behavior testing.
- FPC source remains the correctness authority for `getpid` / `getppid`.
  Wave 12 tests guard nextPas naming/owner discipline: host FFI process-id
  helpers are host-prefixed, while unified `platform_process_*` names remain
  absent until a real public `platform.process` design exists.

### Wave 11: POSIX signal-control raw ABI

- [x] Open isolated worktree from latest `main`.
- [x] Reconfirm goal-tree anchors: G3 core/runtime/framework, G7 FPC
  compatibility, G0 quality discipline.
- [x] Select next gap from the platform ABI roadmap: POSIX signal-control raw
  ABI follows Wave 7 wait/status signal constants and prepares future process /
  runtime contracts without creating them now.
- [x] Add Wave 11 source-surface guard for owner, docs, route, and feature
  boundary discipline.
- [x] Keep shared POSIX signal-control shape deferred; signal set and sigaction
  records are host-owned because FPC records host-specific layouts.
- [x] Import Linux / Android `rt_sigaction` and `rt_sigprocmask` syscall
  numbers, record shapes, and host-owned thin projections.
- [x] Import Darwin / FreeBSD `sigaction`, `sigprocmask`, and pthread mask
  declarations and host-owned thin projections.
- [x] Keep generic Unix signal-control shape source-backed but conservative.
- [x] Keep Wave 11 out of `platform.time`, `platform.sync`, `platform.thread`,
  and any public `platform.signal` / `platform.process` contract.
- [x] Update source evidence, gap matrix, goal-tree platform route text, and
  official verification route.
- [x] Run focused and full verification.
- [x] Commit, merge to `main`, post-merge verify, clean the worktree, and
  delete the feature branch.

#### Wave 11 Verification Boundary

- FPC source is the correctness authority for `sigset_t`, `sigactionrec`, signal
  action flags, mask-operation constants, syscall numbers, libc symbols, and
  pthread signal mask declarations.
- Wave 11 tests must not runtime-probe raw signal behavior. They guard only
  nextPas integration: host owner placement, source evidence, verify route,
  no FPC platform-unit dependency, no feature-specific FFI, and simulated
  compile coherence.

#### Wave 11 Non-goals

- No public `nextpas.core.platform.signal` or `nextpas.core.platform.process`
  contract in this wave.
- No `nextpas.core.platform.signal.ffi` or `nextpas.core.platform.process.ffi`.
- No runtime tests for raw `sigaction`, `sigprocmask`, `pthread_sigmask`, or
  signal mask bit arithmetic.
- No Windows signal emulation. Windows has different console/control-event
  semantics and needs a separate future design.

### Wave 10: Darwin / FreeBSD / Android traditional stat raw ABI

- [x] Open isolated worktree from latest `main`.
- [x] Reconfirm Wave 10 boundary: copy FPC raw ABI definitions as authority,
  guard nextPas integration only, and do not runtime-prove FPC records,
  constants, syscall numbers, or libc symbols.
- [x] Select host owners from the Wave 9 deferred stat family: Darwin,
  FreeBSD, and Android. Keep generic Unix stat deferred because there is no
  single trustworthy generic Unix stat layout.
- [x] Update `/plan` files with Wave 10 scope, evidence, and verification
  boundary.
- [x] Add Wave 10 source-surface guard for owner, docs, route, and compile
  discipline.
- [x] Import Darwin `$INODE64` `stat` / `lstat` / `fstat` record and raw
  bindings into Darwin host owners.
- [x] Import FreeBSD `stat` / `lstat` / `fstat` record and raw bindings into
  FreeBSD host owners.
- [x] Import Android Linux-derived stat records and syscall-backed
  `newfstatat` / `fstat` helpers into Android host owners.
- [x] Keep shared `posix.base` / `posix.ffi` free of a generic POSIX stat
  record or generic `stat` binding.
- [x] Keep raw stat inventory out of `platform.time`, `platform.sync`,
  `platform.thread`, and any `platform.file` feature contract.
- [x] Update source evidence, gap matrix, and official verification route.
- [x] Run focused and full verification.
- [x] Commit, merge to `main`, post-merge verify, and clean the worktree.

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
- No generic Unix traditional `stat` promotion in this wave; generic Unix stays
  deferred until a specific FPC-backed layout can be promoted without inventing
  ABI truth.
- No Linux changes unless needed to keep shared route or guard naming coherent.

## Verification Commands

- `git diff --check`
- `sh -n build/verify_local.sh`
- `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave1 clean test`
- `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
- `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
- `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
- `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
- `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
- `make -C core/tests/nextpas.core.platform.time/test_platform_time_helpers clean test`
- `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave11_signal_control clean test`
- `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave10_posix_stat_hosts clean test`
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

- Wave 14 RED:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
    failed as expected on missing `android_errno_location`.
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    failed as expected on missing `darwin_errno_value`.
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
    failed as expected on missing `android_clock_monotonic_now`.
  - `make -C core/tests/nextpas.core.platform/test_platform_host_gap_matrix clean test`
    failed as expected on missing `android_errno_location`.
- Wave 14 focused GREEN:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`:
    `1 total, 1 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`:
    `1 total, 1 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`:
    `1 total, 1 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_host_gap_matrix clean test`:
    `4 total, 4 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_partition_surface clean test`:
    `1 total, 1 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`:
    Darwin, Android, FreeBSD, and generic Unix simulated compile routes passed.
  - `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave11_signal_control clean test`:
    `7 total, 7 passed, 0 failed`.
- Wave 14 full pre-merge verification:
  - `git diff --check`: pass.
  - `sh -n build/verify_local.sh`: pass.
  - `make -C core test`: `All tests passed.`
  - `make -C core examples`: `All examples compiled.`
  - `make -C core benchmarks`: `All benchmarks passed.`
  - `bash build/verify_local.sh`: `verify-local=pass`,
    `human-summary=local verification passed`, final envelope includes
    `corePlatformTimeHostFfiSurfaceCheck`,
    `corePlatformThreadHostFfiSurfaceCheck`,
    `corePlatformSyncHostFfiSurfaceCheck`,
    `corePlatformFfiPartitionSurfaceCheck`,
    `corePlatformHostGapMatrixCheck`, and
    `corePlatformSimulatedHostCompileMatrixCheck`.
- Wave 14 merge / post-merge closeout:
  - Feature branch commit after rebase: `7c50af6 platform: clean remaining host
    ffi helper names`.
  - Fast-forward merged to `main@7c50af6`.
  - Post-merge `bash build/verify_local.sh`: `verify-local=pass`,
    `human-summary=local verification passed`.
  - Removed worktree
    `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-ffi-wave14-posix-names`.
  - Deleted branch `codex/platform-host-ffi-wave14-posix-names` and ran
    `git worktree prune`.
  - Remaining parallel worktrees are `collections-refactor` and
    `sema-no-matching-overload`.
- Wave 13 RED:
  `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  failed as expected on missing `linux_errno_location`.
- Wave 13 focused GREEN:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`:
    `1 total, 1 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`:
    `1 total, 1 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`:
    `1 total, 1 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_host_gap_matrix clean test`:
    `4 total, 4 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_partition_surface clean test`:
    `1 total, 1 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_import_workflow clean test`:
    `2 total, 2 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave1 clean test`:
    `3 total, 3 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave11_signal_control clean test`:
    `7 total, 7 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_source_evidence_index clean test`:
    `2 total, 2 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`:
    Darwin, Android, FreeBSD, and generic Unix simulated compile routes passed.
- Wave 13 full pre-merge verification:
  - `git diff --check`: pass.
  - `sh -n build/verify_local.sh`: pass.
  - `make -C core test`: `All tests passed.`
  - `make -C core examples`: `All examples compiled.`
  - `make -C core benchmarks`: `All benchmarks passed.`
  - `bash build/verify_local.sh`: `verify-local=pass`,
    `human-summary=local verification passed`, final envelope includes
    `corePlatformFfiPartitionSurfaceCheck`,
    `corePlatformHostGapMatrixCheck`,
    `corePlatformFfiSourceEvidenceIndexCheck`,
    `corePlatformFfiImportWorkflowCheck`,
    `corePlatformHostAbiWave1Check`,
    `corePlatformHostAbiWave11SignalControlCheck`, and
    `corePlatformSimulatedHostCompileMatrixCheck`.
- Wave 12 RED:
  `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave1 clean test`
  failed as expected on missing `linux_process_id`.
- Wave 12 GREEN:
  `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave1 clean test`:
  `3 total, 3 passed, 0 failed`.
- `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave11_signal_control clean test`:
  `7 total, 7 passed, 0 failed`.
- `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave10_posix_stat_hosts clean test`:
  `7 total, 7 passed, 0 failed`.
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
  `corePlatformHostAbiWave1Check`,
  `corePlatformHostAbiWave9LinuxStatCheck`,
  `corePlatformHostAbiWave10PosixStatHostsCheck`,
  `corePlatformHostAbiWave11SignalControlCheck`, and
  `corePlatformSimulatedHostCompileMatrixCheck`.
- Post-merge `bash build/verify_local.sh` on `main@4d22157`: pass; final
  envelope reports `verify-local=pass`, `human-summary=local verification
  passed`, and includes `corePlatformHostAbiWave1Check`,
  `corePlatformHostAbiWave11SignalControlCheck`, and
  `corePlatformSimulatedHostCompileMatrixCheck`.
- Post-merge `bash build/verify_local.sh` on `main@23f0dfd`: pass; final
  envelope reports `verify-local=pass`, `human-summary=local verification
  passed`, and includes `corePlatformHostAbiWave9LinuxStatCheck`.
- Post-merge `bash build/verify_local.sh` on `main@8ed96da`: pass; final
  envelope reports `verify-local=pass`, `human-summary=local verification
  passed`, and includes `corePlatformHostAbiWave10PosixStatHostsCheck`.
- Post-merge `bash build/verify_local.sh` on `main@96c3c1e`: pass; final
  envelope reports `verify-local=pass`, `human-summary=local verification
  passed`, and includes `corePlatformHostAbiWave11SignalControlCheck`.

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| Active planning files still described collections work in the Wave 7 platform worktree. | Session recovery | Replaced the active plan with platform ABI Wave 7 scope before implementation. |
| Cleanup command removed tracked `build/` files while clearing generated artifacts. | Wave 10 post-merge cleanup | Immediately restored tracked `build/` with `git restore build`; avoid broad `rm -rf build` in future cleanups. |
| Tried to patch Darwin `pthread_sigmask` external library after it had already been corrected to FPC's libc route. | Wave 11 review | Re-read the file and kept the already-correct `external 'c'` declaration. |
| `make -C core test` stopped at the Wave 11 goal-tree guard after Wave 12 updated the current platform ABI paragraph. | Wave 12 full verification | Kept Wave 12 as current state and restored the exact historical phrase `Platform Host ABI Completeness Wave 11` so the previous wave's route truth remains recoverable. |
| `make -C core/tests/nextpas.core.platform/test_platform_host_gap_matrix clean test` failed after Wave 13 changed the POSIX token helper signature. | Wave 13 focused verification | Updated the generic Unix call to pass the transitional `platform` host-helper prefix, matching the intentionally deferred non-Linux rename scope. |
| Fresh `make -C core test` stopped at `test_platform_ffi_partition_surface` because the guard still required Linux `function platform_errno_location`. | Wave 13 full verification | Updated the Linux partition guard to require `linux_errno_location` / `linux_pthread_condattr_setclock` and reject old unified-looking Linux helper names. |
| `make -C core test` stopped at the Wave 11 goal-tree guard after Wave 14 updated the current platform ABI paragraph. | Wave 14 full verification | Kept Wave 14 as current state and restored the exact historical phrase `Platform Host ABI Completeness Wave 11` so the previous wave's route truth remains recoverable. |
