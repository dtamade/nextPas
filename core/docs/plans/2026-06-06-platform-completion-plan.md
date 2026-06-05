# Platform Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace platform stubs and unsafe platform contracts with tested implementations or truthful unsupported semantics.

**Architecture:** Keep readiness and completion separate. Keep Windows ABI ownership in `platform.windows.base/ffi`. Keep public path strings UTF-8 and convert only at the Windows boundary.

**Tech Stack:** Free Pascal, nextPas-owned platform FFI, Makefile focused tests, heaptrc, source-contract tests.

---

## File Structure

- `src/nextpas.core.platform.process.pas`: POSIX child fd close policy.
- `src/nextpas.core.platform.linux.modern.pas`: existing `close_range` wrapper, reused not duplicated.
- `src/nextpas.core.platform.posix.ffi.pas`: existing `sysconf`, reused for fallback.
- `src/nextpas.core.platform.windows.base.pas`: Windows types/constants for UTF-16 helpers, console control, Winsock readiness state if needed.
- `src/nextpas.core.platform.windows.ffi.pas`: new W imports and Winsock/kernel32 APIs.
- `src/nextpas.core.platform.windows.utf16.pas`: unified UTF-8/UTF-16 helper if no suitable helper already exists.
- `src/nextpas.core.platform.files.pas`: Windows file/path W API migration.
- `src/nextpas.core.platform.path.pas`: Windows full-path W API migration.
- `src/nextpas.core.platform.env.pas`: Windows environment W API migration.
- `src/nextpas.core.platform.process.pas`: Windows command line/CWD W API migration.
- `src/nextpas.core.platform.mmap.pas`: Windows file mapping path open W API migration.
- `src/nextpas.core.platform.pty.pas`: Windows process W API migration.
- `src/nextpas.core.platform.dl.pas`: Windows library path W API migration.
- `src/nextpas.core.platform.signal.pas`: Windows console control handler wrapper.
- `src/nextpas.core.platform.io.base.pas`: Windows readiness poller state.
- `src/nextpas.core.platform.io.pas`: Windows readiness fallback implementation and wake.
- `src/nextpas.core.io.reactor.iocp.pas`: real IOCP lifecycle and explicit operation boundary.
- `src/nextpas.core.io.poller.pas`: Windows backend compile boundary.
- `src/nextpas.core.async.loop.pas`: remove unconditional Linux wake dependency.
- `docs/platform-goal-tree.md`: truthful status update.

## Task 1: Baseline and RED Contracts

- [ ] Run current focused gates before production edits.

```bash
make -C tests/nextpas.core.platform.process/test_platform_process clean test
make -C tests/nextpas.core.platform.io/test_platform_io clean test
make -C tests/nextpas.core.platform.signal/test_platform_signal clean test
make -C tests/nextpas.core.platform.files/test_platform_files clean test
make -C tests/nextpas.core.platform.path/test_platform_path clean test
make -C tests/nextpas.core.platform.env/test_platform_env clean test
```

- [ ] Add process source/runtime RED tests.

Expected RED: source-contract fails on `for LFd := 3 to 1023`; runtime high-fd test fails by observing inherited fd above 1023.

- [ ] Add Windows source-contract RED tests.

Expected RED: tests find Windows poller bare `-1`, Windows signal stub, path-bearing `A` API calls, and direct `eventfd` in `TAsyncLoop`.

## Task 2: POSIX Process FD Cleanup

- [ ] Implement helper in `platform.process`:

```pascal
procedure CloseChildFdRange(AFirst, ALast: Int32; APreserveFd: Int32);
```

- [ ] Linux branch uses `close_range` for `[3, preserve-1]` and `[preserve+1, max]`.
- [ ] Fallback branch uses `sysconf(_SC_OPEN_MAX)` and a conservative dynamic fallback if sysconf fails.
- [ ] Preserve `LErrPipe[1]` until after failed `execve/execvp` write.
- [ ] Run process gates and commit.

## Task 3: Windows UTF-16 Boundary

- [ ] Add unified helper:

```pascal
function PlatformWindowsUtf8ToWide(const AText: PAnsiChar): UnicodeString;
function PlatformWindowsWideToUtf8(const AText: PWideChar): AnsiString;
```

- [ ] Add missing W imports from the requested list.
- [ ] Migrate path-bearing calls in files/path/env/process/mmap/pty/dl to W APIs.
- [ ] Keep non-path calls such as `ReadFile`, `WriteFile`, `GetProcAddress`, and `FormatMessageA` unchanged unless a test shows they are part of public UTF-8 path semantics.
- [ ] Run file/path/env/process/mmap/dl focused gates and commit.

## Task 4: Windows Signal Semantics

- [ ] Define Ctrl+Break token in `platform.signal`.
- [ ] Implement internal console control handler trampoline.
- [ ] `platform_signal_set/reset/ignore` support only Ctrl+C and Ctrl+Break.
- [ ] `platform_signal_block/unblock` return stable unsupported on Windows.
- [ ] Add source-contract compile gate and commit.

## Task 5: Windows Readiness Poller and Async Boundary

- [ ] Extend Windows poller state with registered sockets, event masks, user data, and wake sockets.
- [ ] Implement add/modify/remove/close with capacity growth and validation.
- [ ] Implement wait using Winsock readiness fallback.
- [ ] Implement wake/drain using an internal nonblocking socket pair or loopback pair.
- [ ] Refactor `TAsyncLoop` wake path to use platform poller wake instead of direct Linux `eventfd`.
- [ ] Make `nextpas.core.io.poller` compile on Windows without Linux-only uses.
- [ ] Make `TIocpReactor.Create/Close/IsValid/Poll/Stop` use real completion port lifecycle, and leave async operations explicitly unsupported unless fully implemented and tested.
- [ ] Run async/poller/net-server focused gates and commit.

## Task 6: Documentation and Final Verification

- [ ] Update `docs/platform-goal-tree.md` to record truthful status and remaining real-Windows runtime risk.
- [ ] Wait for subagents and review their findings against the diff.
- [ ] Run required verification:

```bash
make -C tests/nextpas.core.platform.process/test_platform_process clean test
make -C tests/nextpas.core.process/test_process_pipe_contract clean test
make -C tests/nextpas.core.process/test_process clean test
make -C tests/nextpas.core.process/test_process_deep clean test
make -C tests/nextpas.core.platform.io/test_platform_io clean test
make -C tests/nextpas.core.io.uring/test_poller clean test
make -C tests/nextpas.core.async/test_async clean test
make -C tests/nextpas.core.async/test_async_timeout clean test
make -C tests/nextpas.core.platform.signal/test_platform_signal clean test
make -C tests/nextpas.core.platform.files/test_platform_files clean test
make -C tests/nextpas.core.platform.path/test_platform_path clean test
make -C tests/nextpas.core.platform.env/test_platform_env clean test
make -C tests/nextpas.core.platform.mmap/test_platform_mmap clean test
make -C tests/nextpas.core.platform.dl/test_platform_dl clean test
git diff --check
git status --short --branch
```

- [ ] Commit final docs/review corrections.
