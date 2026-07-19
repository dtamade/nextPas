# nextPas Platform Master Spec

`nextpas.core.platform` is the nextPas-owned OS foundation. It is not an FPC
`BaseUnix`, `Unix`, `Windows`, or `SysUtils` compatibility layer.

## Core principles

1. Host-owned raw FFI and nextPas-owned feature semantics are separate.
   `platform.<host>.base` and `platform.<host>.ffi` own raw ABI declarations.
   Feature modules own portable semantics, error folding, and resource
   ownership.
2. Readiness and completion stay split. `platform_poller_*` is readiness-only.
   IOCP and future proactor/completion queues belong to
   `nextpas.core.io.reactor.*` plus consumer adapters.
3. Truth is evidence-tiered. A status must say whether it is
   `source-contract`, `forced-compile`, `focused-runtime`, or `ci-matrix`.
4. Public API first, host workaround second. If a consumer exposes a bad
   platform facade, fix the facade instead of hiding the problem in the
   consumer.
5. Correctness precedes benchmarking. Performance work follows stable contract,
   leak, and runtime evidence.

## Truth tiers

| Tier | Evidence | What it can claim |
| --- | --- | --- |
| `source-contract` | Static/focused source guard. | Owner boundary or source shape is locked. |
| `forced-compile` | Host branch compiles under a forced target. | Symbols/types/uses are compile-coherent. |
| `focused-runtime` | Focused behavior gate runs on a real host. | The named path works on that host. |
| `ci-matrix` | CI repeats runtime proof across host/arch entries. | Runtime truth is durable for those entries. |

Without real runtime evidence, a host is not runtime ready.

## Current Windows truth

Windows x86_64 has host ABI declarations, source-contract coverage, forced
Windows compile gates, Wine runtime smoke (17-module matrix, including
`platform.error`, `platform.fmt`, and `platform.info`), and durable GHA
**`ci-matrix`** for the **documented 19-gate set** in
`platform-windows-ci-matrix.sh` / `.ps1` (16 suite dirs + poller/io/socket real
gates) under job `test-windows-runtime` on `windows-latest`.

Promotion is **scoped**: it does **not** claim full-host Windows parity for
modules outside that list (e.g. signal, console, native secure-zero) or for
IOCP AcceptEx/ConnectEx depth beyond current smoke gaps.

Allowed wording:

- `source-contract covered`
- `forced Windows compile covered`
- `wine-runtime-smoke` (secondary regression; never substitutes for real Windows)
- `focused-runtime` for modules with real Windows host logs outside CI matrix
- `ci-matrix` for the documented 19-gate set only (ROADMAP; GHA run 29686191527)

## Current macOS truth

macOS aarch64 (`macos-14`) has durable GHA **`focused-runtime`** for the
**documented 8-gate set** in `platform-macos-ci-matrix.sh` under job
`test-macos` (fail-closed step; ROADMAP D2.c):
`platform.{time,sync,thread,files,path,env,error,socket}`.

D2.c promotion is **scoped**: it does **not** claim full-host macOS parity or
treat best-effort whole-suite inventory as evidence.

Allowed wording:

- `focused-runtime` for the documented 8-gate set only (ROADMAP D2.c)
- best-effort inventory remains non-promotional non-evidence

### IOCP completion operations

IOCP socket completion operations are structurally implemented in
`nextpas.core.io.reactor.iocp`:

| Operation | API | Status |
|-----------|-----|--------|
| AsyncRead | `ReadFile` + OVERLAPPED | implemented |
| AsyncWrite | `WriteFile` + OVERLAPPED | implemented |
| AsyncSend | `WSASend` + OVERLAPPED | implemented |
| AsyncRecv | `WSARecv` + OVERLAPPED | implemented |
| AsyncClose | `CancelIoEx` + `closesocket` | implemented |
| AsyncConnect | `ConnectEx` (WSAIoctl-loaded) | implemented |
| AsyncAccept | `AcceptEx` (WSAIoctl-loaded) | implemented — accepts pre-created socket via `winsock_socket`, caller retrieves via `LastAcceptedSocket` |

All seven operations have source-contract coverage and forced Windows compile
gates. `AsyncSend`/`AsyncRecv` and `AsyncAccept`/`AsyncConnect` have
focused-runtime evidence on Wine and a real Windows VM.

## Host raw FFI ownership

Raw host units such as `Windows`, `BaseUnix`, `Unix`, `DynLibs`, and `ctypes`
belong in platform owner paths or explicit module-owned FFI surfaces. Direct
consumer uses outside those owners require a reviewed path+token allowlist entry.

Run:

```bash
make -C core/tests/architecture/source_contracts host-raw-ffi-audit
```

A new allowlist entry is owner-boundary debt. The landing report must name the
path, token, reason, and follow-up owner route.
