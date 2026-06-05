# Platform Completion Design

## Summary

This slice corrects `nextpas.core.platform.*` areas that are documented as complete but still contain stubs or Windows ANSI path semantics. The goal is not to make Windows look complete by returning different stubs. The goal is to make each platform contract either usable and tested or explicitly unsupported with stable error semantics.

## Architecture

`platform.io` remains a readiness poller API. Linux uses `epoll`, BSD/macOS use `kqueue`, and Windows gets a socket readiness fallback built from Winsock readiness primitives. IOCP is a separate completion/proactor API in `nextpas.core.io.reactor.iocp`; it must not be squeezed into `platform_poller_*` because completion packets are not readable/writable readiness events.

`TAsyncLoop` must stop owning Linux wake primitives directly. Wake belongs behind the platform poller seam, so Linux can keep `eventfd`, BSD/macOS can keep the self-pipe, and Windows can use a wake socketpair or loopback socket pair. If Windows async I/O remains incomplete, `TAsyncLoop` must fail through a truthful unsupported contract rather than silently compiling against Linux-only calls.

Windows signals map only to console control events. `PLATFORM_SIGINT` maps to Ctrl+C and a dedicated Ctrl+Break signal token maps to Ctrl+Break. POSIX-only signals such as HUP, TERM, PIPE, and WINCH are not invented on Windows; unsupported operations return a stable unsupported error code.

Public path strings remain UTF-8. Windows path/environment/process entrypoints convert UTF-8 to UTF-16 once through a nextPas-owned helper and call W APIs. FFI declarations stay in `nextpas.core.platform.windows.ffi/base`; feature modules consume that surface and do not import FPC platform units.

POSIX child fd cleanup must close all unintended inherited descriptors without closing the exec-error pipe. Linux uses `close_range` for two safe ranges where available; POSIX fallback uses `sysconf(_SC_OPEN_MAX)` and loops while skipping `LErrPipe[1]`.

## Error Semantics

- Existing POSIX errno-style returns stay intact.
- Windows unsupported returns use an explicit stable unsupported code, not bare `-1`.
- Windows WinAPI failures return `GetLastError` where existing platform modules already do so.
- IOCP operations that are not fully implemented return `False`, but reactor lifecycle must be real and source-contract tests must make the unsupported boundary explicit.

## Testing Strategy

- Runtime Linux tests prove process fd cleanup closes high descriptors and preserves the exec-error pipe.
- Source-contract tests prove Windows stubs are gone, `SetConsoleCtrlHandler` is wrapped, path-bearing Windows calls use W APIs, and `TAsyncLoop` has no Linux-only direct wake dependency outside platform-specific branches.
- Existing platform focused tests continue to run with heaptrc.
- Windows cross-compile is required if the local FPC toolchain supports it; otherwise final report lists exact real-Windows runtime commands.

## Commit Strategy

1. Process fd cleanup and tests.
2. Windows UTF-16 path/process/env migration and contracts.
3. Windows signal console handler contract.
4. Windows readiness poller, async wake seam, and IOCP lifecycle truth.
5. Documentation/status correction and final review fixes.
