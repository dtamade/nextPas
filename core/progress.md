# nextpas.core platform progress

## 2026-05-28

- Started Wave 10 from `main@eeac28c` in worktree
  `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave10-posix-stat-hosts`
  on branch `codex/platform-host-abi-wave10-posix-stat-hosts`.
- Confirmed sibling worktrees remain `collections-refactor` and
  `sema-no-matching-overload`; Wave 10 stays isolated from those lines.
- `planning-with-files` catchup again reported stale unrelated mem/collections
  context. Current `task_plan.md`, `findings.md`, `progress.md`, and clean git
  status are authoritative for this platform worktree.
- Reconfirmed the user's raw ABI boundary: FPC source is already the authority
  for platform API definitions. This wave will not runtime-prove FPC's
  constants, records, syscall numbers, external symbols, or calling
  conventions. Checks will guard only nextPas integration discipline.
- Selected Wave 10 from the deferred POSIX stat family: promote Darwin,
  FreeBSD, and Android traditional stat raw ABI into host owners; leave generic
  Unix stat deferred because there is no single FPC-backed generic Unix layout.
- FPC evidence found for Wave 10:
  - `rtl/bsd/ostypes.inc` defines the Darwin `darwin_new_iostructs` stat record
    and the FreeBSD stat record.
  - `rtl/darwin/ptypes.inc` and `rtl/freebsd/ptypes.inc` define the scalar
    widths used by those records.
  - `rtl/unix/oscdeclh.inc` records direct non-Linux `stat`, `lstat`, and
    `fstat` libc symbols and Darwin `$INODE64` suffix policy.
  - `rtl/android/Makefile` routes Android POSIX type/system ownership through
    Linux include families; Android x86_64/aarch64 stat records come from
    `rtl/linux/x86_64/stat.inc` and `rtl/linux/aarch64/stat.inc`.
  - `rtl/android/x86_64/sysnr.inc`, `rtl/android/aarch64/sysnr.inc`,
    `rtl/linux/osdefs.inc`, `rtl/linux/ossysc.inc`, and
    `rtl/linux/bunxsysc.inc` record Android's `newfstatat` / `fstat` syscall
    route for stat/fstat/lstat.
- Updated `task_plan.md` active scope from closed Wave 9 to Wave 10 and added
  Wave 10 decisions/evidence to `findings.md`.
- Added Wave 10 source-surface guard in
  `core/tests/nextpas.core.platform/test_platform_host_abi_wave10_posix_stat_hosts/`.
- RED result:
  `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave10_posix_stat_hosts clean test`
  compiled and failed as expected with `7 total, 2 passed, 5 failed`. The
  intended failures are missing Darwin / FreeBSD / Android host stat owner
  tokens, missing docs evidence, and missing `verify_local` route truth.
- Imported Wave 10 raw ABI inventory into host owners:
  - `darwin.base` now owns `TPlatformDarwinStat`, `PPlatformDarwinStat`, and
    Darwin stat scalar aliases copied from FPC's Darwin/BSD type surface.
  - `darwin.ffi` now owns `darwin_stat`, `darwin_lstat`, `darwin_fstat`, and
    thin Darwin-prefixed path/fd helpers using FPC's `$INODE64` symbol policy.
  - `freebsd.base` now owns `TPlatformFreeBSDStat`, `PPlatformFreeBSDStat`, and
    FreeBSD stat scalar aliases copied from FPC's FreeBSD/BSD type surface.
  - `freebsd.ffi` now owns `freebsd_stat`, `freebsd_lstat`, `freebsd_fstat`,
    and thin FreeBSD-prefixed path/fd helpers through direct libc symbols.
  - `android.base` now owns `TPlatformAndroidStat`,
    `PPlatformAndroidStat`, Android `AT_*` tokens, and the x86_64/aarch64
    `newfstatat` / `fstat` syscall numbers from FPC's Android syscall tables.
  - `android.ffi` now owns `android_syscall`, `android_newfstatat`,
    `android_fstat`, `android_stat_path`, `android_lstat_path`, and
    `android_fstat_fd`; it deliberately does not use Linux glibc `__xstat`
    wrappers.
- Kept shared `posix.base` / `posix.ffi` and generic Unix owners free of a
  generic POSIX/Unix stat record or generic `stat` / `lstat` / `fstat`
  binding. FPC has host-specific layouts and suffix/syscall policies, so a
  generic nextPas shape would invent ABI truth.
- Kept Wave 10 out of `platform.time`, `platform.sync`, `platform.thread`, and
  any public `platform.file` contract. This is raw host ABI inventory only.
- Updated `docs/platform-ffi-source-evidence-index.md`,
  `docs/platform-host-ffi-gap-matrix.md`, and `build/verify_local.sh` with Wave
  10 evidence, route truth, and the official focused check.
- Focused Wave 10 verification passed:
  - `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave10_posix_stat_hosts clean test`:
    `7 total, 7 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`:
    Darwin / Android / FreeBSD / generic Unix simulated compile passed.
  - `make -C core/tests/nextpas.core.platform/test_platform_host_gap_matrix clean test`:
    `4 total, 4 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_source_evidence_index clean test`:
    `2 total, 2 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_import_workflow clean test`:
    `2 total, 2 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave9_linux_stat clean test`:
    `5 total, 5 passed, 0 failed`.
- Full Wave 10 verification passed in the isolated worktree:
  - `git diff --check`: pass.
  - `sh -n build/verify_local.sh`: pass.
  - `make -C core test`: `All tests passed.`
  - `make -C core examples`: `All examples compiled.`
  - `make -C core benchmarks`: `All benchmarks passed.`
  - `bash build/verify_local.sh`: `verify-local=pass`,
    `human-summary=local verification passed`, final envelope includes
    `corePlatformHostAbiWave10PosixStatHostsCheck`.
- Committed Wave 10 as `8ed96da`
  (`platform: add POSIX host stat ABI wave 10`).
- Fast-forwarded `main` from `eeac28c` to `8ed96da`.
- Post-merge `bash build/verify_local.sh` passed on the main checkout with
  `verify-local=pass`, `human-summary=local verification passed`, and final
  envelope token `corePlatformHostAbiWave10PosixStatHostsCheck`.
- Removed the Wave 10 worktree and deleted branch
  `codex/platform-host-abi-wave10-posix-stat-hosts`.
- Remaining active sibling worktrees are `collections-refactor` and
  `sema-no-matching-overload`.
- Cleanup note: after post-merge verify, a broad cleanup command removed tracked
  `build/` files along with generated artifacts. The tracked files were restored
  immediately with `git restore build`; future cleanup must target ignored
  generated paths precisely.

- Started Wave 9 from `main@524b27c` in worktree
  `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave9-posix-stat`
  on branch `codex/platform-host-abi-wave9-posix-stat`.
- Current goal tree anchors are `G3` core/runtime/framework, `G7` FPC
  compatibility and ecosystem migration, and `G0` quality discipline.
- `planning-with-files` catchup reported stale unrelated mem/collections context
  from an older interrupted session; current `git status` is clean, and the live
  platform plan/progress/findings are authoritative for this worktree.
- Confirmed remaining active sibling worktrees are `collections-refactor` and
  `sema-no-matching-overload`; Wave 9 remains isolated.
- Baseline focused platform gate passed:
  `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave8_file_io clean test`
  reported `5 total, 5 passed, 0 failed`.
- Selected Wave 9 from the explicit gap matrix marker: traditional POSIX
  `stat` / `fstat` / `lstat` was deferred in Wave 3 because layouts and suffix
  policy are host-specific. Wave 9 promotes only the Linux traditional stat
  raw ABI into Linux host owners.
- FPC evidence found for Wave 9:
  - `rtl/linux/ostypes.inc` defines `_STAT_VER` policy. For the current nextPas
    Linux CPU set, x86_64 uses `_STAT_VER_LINUX = 1`; aarch64 uses
    `_STAT_VER_LINUX = 0`.
  - `rtl/linux/x86_64/stat.inc` defines the x86_64 Linux `stat` record used by
    FPC.
  - `rtl/linux/aarch64/stat.inc` defines the aarch64 Linux `stat` record used by
    FPC.
  - `rtl/linux/osmacro.inc` declares `__xstat`, `__lxstat`, and `__fxstat`, then
    routes `FpStat`, `FpLstat`, and `FpFstat` through those libc wrappers with
    `_STAT_VER`.
  - `rtl/unix/oscdeclh.inc` records why this must remain host-owned: Linux has
    macro wrappers, while non-Linux Unix hosts use symbol suffix handling such
    as Darwin `$INODE64`.
- Updated `task_plan.md` active scope from closed Wave 8 to Wave 9 Linux
  traditional stat raw ABI.
- Added Wave 9 source-surface guard in
  `core/tests/nextpas.core.platform/test_platform_host_abi_wave9_linux_stat/`.
  The guard checks Linux host ownership tokens, shared POSIX stat absence,
  documentation evidence, `verify_local` route truth, absence of
  `platform.file` / `platform.file.ffi`, and absence of Wave 9 raw stat
  consumption from `platform.time`, `platform.sync`, and `platform.thread`.
- Imported Linux traditional stat raw ABI into Linux host owners:
  - `linux.base` now owns `TPlatformLinuxStat`, `PPlatformLinuxStat`, and
    CPU-specific `PLATFORM_LINUX_STAT_VERSION`.
  - `linux.ffi` now owns raw libc wrapper declarations `linux_xstat`,
    `linux_lxstat`, and `linux_fxstat`.
  - `linux.ffi` also exposes thin Linux-prefixed helpers `linux_stat_path`,
    `linux_lstat_path`, and `linux_fstat_fd`.
- Kept shared `posix.base` / `posix.ffi` free of generic POSIX stat record and
  generic `stat` / `lstat` / `fstat` bindings.
- Kept Wave 9 out of public `platform.file` / `platform.file.ffi`; this is raw
  host ABI inventory only, not a unified file contract.
- Updated `docs/platform-ffi-source-evidence-index.md`,
  `docs/platform-host-ffi-gap-matrix.md`, and `build/verify_local.sh` with Wave
  9 source evidence and route truth. The gap matrix now has a separate
  `File / status ABI` column so stat/file status inventory does not get mixed
  into timeout capability.
- Reconfirmed the raw ABI correctness boundary after user review:
  FPC source is the authority for copied platform API definitions. nextPas raw
  ABI wave checks should not runtime-prove FPC constants, record layouts, or
  libc/syscall declarations; they guard owner placement, docs, route truth,
  absence of feature-specific FFI units, no FPC platform-unit dependencies, and
  compile coherence.
- Focused Wave 9 verification passed:
  - `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave9_linux_stat clean test`:
    `5 total, 5 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_host_gap_matrix clean test`:
    `4 total, 4 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_source_evidence_index clean test`:
    `2 total, 2 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_import_workflow clean test`:
    `2 total, 2 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`:
    Darwin / Android / FreeBSD / generic Unix simulated compile passed.
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`:
    `8 total, 8 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`:
    `14 total, 14 passed, 0 failed`.
- Full Wave 9 verification passed in the isolated worktree:
  - `git diff --check`: pass.
  - `sh -n build/verify_local.sh`: pass.
  - `make -C core test`: `All tests passed.`
  - `make -C core examples`: `All examples compiled.`
  - `make -C core benchmarks`: `All benchmarks passed.`
  - `bash build/verify_local.sh`: `verify-local=pass`,
    `human-summary=local verification passed`, final envelope includes
    `corePlatformHostAbiWave9LinuxStatCheck`.
- Committed Wave 9 as `23f0dfd`
  (`platform: add Linux stat ABI wave 9`).
- Fast-forwarded `main` from `524b27c` to `23f0dfd`.
- Post-merge `bash build/verify_local.sh` passed on the main checkout with
  `verify-local=pass`, `human-summary=local verification passed`, and final
  envelope token `corePlatformHostAbiWave9LinuxStatCheck`.
- Removed the Wave 9 worktree and deleted branch
  `codex/platform-host-abi-wave9-posix-stat`.
- Remaining active sibling worktrees are `collections-refactor` and
  `sema-no-matching-overload`.

- Started Wave 8 from latest `main@ac4a6fe` in worktree
  `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave8-file-io`
  on branch `codex/platform-host-abi-wave8-file-io`.
- Confirmed the main checkout was clean before branching and that the other
  active worktrees are still `collections-refactor` and
  `sema-no-matching-overload`; this wave remains isolated.
- Ran the Wave 7 focused baseline in the new worktree:
  `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave7_process_status clean test`
  passed with `5 total, 5 passed, 0 failed`.
- Reconfirmed the user's boundary for raw ABI expansion: FPC source is the
  correctness authority for copied platform API definitions. Wave 8 checks must
  not try to runtime-prove FPC's `read`, `write`, `lseek`, `fsync`,
  `ftruncate`, or Windows kernel32 definitions.
- FPC evidence found for Wave 8:
  - POSIX `read`, `write`, `lseek`, and `ftruncate` are declared in
    `/home/dtamade/projects/fpc/rtl/unix/oscdeclh.inc` and mirrored through
    `bunxh.inc` / Linux-BSD syscall wrapper sources.
  - POSIX `fsync` is declared in
    `/home/dtamade/projects/fpc/rtl/unix/unxdeclh.inc`.
  - POSIX `SEEK_SET`, `SEEK_CUR`, and `SEEK_END` values are recorded in
    Linux, BSD, and macOS FPC source.
  - Windows `GetFileSize`, `SetFilePointer`, `FlushFileBuffers`,
    `SetEndOfFile`, `GetFileSizeEx`, and `SetFilePointerEx` are recorded in
    FPC `rtl/win/wininc` and used by `rtl/win/sysfile.inc` /
    `rtl/win/sysutils.pp`.
- Updated `task_plan.md` active scope from closed Wave 7 to Wave 8 file I/O
  continuation.
- Added Wave 8 source-surface guard in
  `core/tests/nextpas.core.platform/test_platform_host_abi_wave8_file_io/`.
- RED result:
  `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave8_file_io clean test`
  compiled the guard and failed as expected with `5 total, 1 passed, 4 failed`.
  The failures are the intended missing POSIX file I/O source tokens, Windows
  file I/O source tokens, docs evidence, and `verify_local` route truth. The
  feature-specific `platform.file` / `platform.file.ffi` absence check passed.
- Imported Wave 8 raw ABI inventory:
  - `posix.base` now owns `size_t`, `ssize_t`, `off_t`, and
    `TPlatformFileOffset`.
  - `posix.ffi` now owns `read`, `write`, `lseek`, `fsync`, `ftruncate`, and
    shared `platform_posix_*` thin helpers.
  - Linux, Android, Darwin, FreeBSD, and generic Unix `base` owners now carry
    `PLATFORM_SEEK_SET`, `PLATFORM_SEEK_CURRENT`, and `PLATFORM_SEEK_END`.
  - POSIX host `ffi` owners now expose delegated `platform_file_read`,
    `platform_file_write`, `platform_file_seek`, `platform_file_sync`, and
    `platform_file_truncate` helpers.
  - `windows.base` now carries FPC-shaped `LONG`, `LONGLONG`, `PLONG`,
    `PINT64`, `LARGE_INTEGER`, `FILE_BEGIN`, `FILE_CURRENT`, `FILE_END`, and
    `INVALID_SET_FILE_POINTER`.
  - `windows.ffi` now carries raw `GetFileSize`, `SetFilePointer`,
    `FlushFileBuffers`, `SetEndOfFile`, `GetFileSizeEx`, and
    `SetFilePointerEx` declarations plus thin Windows-prefixed helpers.
- Updated `docs/platform-ffi-source-evidence-index.md`,
  `docs/platform-host-ffi-gap-matrix.md`, and `build/verify_local.sh` with Wave
  8 route truth and final envelope token `corePlatformHostAbiWave8FileIoCheck`.
- Focused verification now passed:
  - `test_platform_host_abi_wave8_file_io`: `5 total, 5 passed, 0 failed`.
  - `test_platform_host_gap_matrix`: `4 total, 4 passed, 0 failed`.
  - `test_platform_ffi_source_evidence_index`: `2 total, 2 passed, 0 failed`.
  - `test_platform_ffi_import_workflow`: `2 total, 2 passed, 0 failed`.
  - `test_platform_simulated_host_compile_matrix`: Darwin / Android / FreeBSD /
    generic Unix all `status=pass`.
- Win64 compile-only checks passed for `core/tests/nextpas.core.time/test_time`,
  `core/tests/nextpas.core.platform.thread/test_platform_thread`, and
  `core/tests/nextpas.core.platform.sync/test_platform_sync`.
- `git diff --check` and `sh -n build/verify_local.sh` passed with no output.
- Full Wave 8 verification passed in the isolated worktree:
  - `make -C core examples`: all examples compiled.
  - `make -C core benchmarks`: all benchmarks passed.
  - `make -C core test`: all tests passed.
  - `bash build/verify_local.sh`: `verify-local=pass`,
    `human-summary=local verification passed`, final envelope includes
    `corePlatformHostAbiWave8FileIoCheck`.
- After updating the `/plan` records, reran
  `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave8_file_io clean test`;
  it passed with `5 total, 5 passed, 0 failed`.
- Committed Wave 8 as `e6c09b3`
  (`platform: add file I/O ABI wave 8`).
- Fast-forwarded `main` from `ac4a6fe` to `e6c09b3`.
- Post-merge `bash build/verify_local.sh` passed on the main checkout with
  `verify-local=pass`, `human-summary=local verification passed`, and final
  envelope token `corePlatformHostAbiWave8FileIoCheck`.
- Removed the Wave 8 worktree and deleted branch
  `codex/platform-host-abi-wave8-file-io`.
- Cleaned generated untracked tag-index files `core/GPATH`, `core/GRTAGS`, and
  `core/GTAGS` from the main checkout; they were not part of the deliverable.

- Previous completed baseline from handoff: Wave 6 process-control raw ABI was
  merged to `main@79f1a05` as `platform: add process ABI wave 6`.
- Created and resumed worktree
  `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave7-process-status`
  on branch `codex/platform-host-abi-wave7-process-status`.
- Confirmed current worktree is clean and based on `main@79f1a05`.
- Confirmed other active worktrees exist for `collections-refactor` and
  `sema-no-matching-overload`; this platform work remains isolated.
- Recovered the user decision for this wave: FPC source is the correctness
  authority for raw platform API definitions. nextPas should not add runtime
  tests to prove copied constants, record layouts, or raw ABI macro logic.
- Replaced stale collections planning files in this worktree with the active
  platform ABI import plan so future sessions can resume the correct thread.
- Added the Wave 7 source-surface guard and ran it once before implementation.
  It failed as expected on missing POSIX wait/status tokens, missing Windows
  wait/status constants, missing docs, and missing `verify_local` route. The
  `platform.process` / `platform.process.ffi` absence check already passed.
- Imported Wave 7 definitions into nextPas-owned platform owners:
  POSIX wait core flag in `posix.base`, FPC wait-status macro projections in
  `posix.math`, POSIX wait/signal constants in each POSIX host `.base`, and
  Windows wait/status/access constants in `windows.base`.
- Updated `docs/platform-ffi-source-evidence-index.md`,
  `docs/platform-host-ffi-gap-matrix.md`, and `build/verify_local.sh` for Wave
  7 route truth.
- Focused verification passed:
  `test_platform_host_abi_wave7_process_status`,
  `test_platform_host_gap_matrix`, `test_platform_ffi_source_evidence_index`,
  `test_platform_ffi_import_workflow`, and
  `test_platform_simulated_host_compile_matrix`.
- Full verification passed in the isolated worktree:
  `git diff --check`, `make -C core test`, `make -C core examples`,
  `make -C core benchmarks`, and `bash build/verify_local.sh`.
- `verify_local` reported `verify-local=pass`,
  `human-summary=local verification passed`, and the final envelope includes
  `corePlatformHostAbiWave7ProcessStatusCheck`.
- After synchronizing `/plan` records, reran `git diff --check` and the focused
  Wave 7/doc/compile guards:
  `test_platform_host_abi_wave7_process_status`,
  `test_platform_host_gap_matrix`, `test_platform_ffi_source_evidence_index`,
  `test_platform_ffi_import_workflow`, and
  `test_platform_simulated_host_compile_matrix`; all passed.
- Committed Wave 7 as `9cc441b` (`platform: add process status ABI wave 7`).
- Fast-forwarded `main` from `79f1a05` to `9cc441b`.
- Post-merge `bash build/verify_local.sh` passed on the main checkout and the
  final envelope includes `corePlatformHostAbiWave7ProcessStatusCheck`.
- Removed the Wave 7 worktree and deleted branch
  `codex/platform-host-abi-wave7-process-status`.

## Next

- Start the next platform ABI import wave from latest `main`; keep raw FPC ABI
  imports source-evidence based, and reserve runtime behavior tests for unified
  public contracts such as `platform.time`, `platform.sync`, and
  `platform.thread`.
