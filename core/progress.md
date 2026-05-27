# nextpas.core platform progress

## 2026-05-28

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
