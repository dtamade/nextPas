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
Windows compile gates, Wine runtime smoke (24-module matrix, including
`platform.watch` UNSUPPORTED smoke and `platform.pty` ConPTY smoke), and durable
GHA **`ci-matrix`** for the **documented 22 platform gates** in
`platform-windows-ci-matrix.sh` / `.ps1`.

### Count honesty (do not mix)

| Count | Meaning |
| --- | --- |
| **22 platform gates** | Promoted `ci-matrix`: suite dirs through `info`+`which`+`dl` + iocp + poller + io/socket real. `dl` PASS on GHA **29725431946** @ `567479723`; full matrix re-green expected after poller Win64 case fix. |
| **mem.host in total** | Optional **`mem.host_runtime`** (mem G4.x). Job `total` may be 23 — do **not** call mem.host a platform facade gate. |

Promotion is **scoped**: it does **not** claim full-host Windows parity for
modules outside that list (e.g. signal, console, native secure-zero) or for
IOCP AcceptEx/ConnectEx depth beyond current smoke gaps.

Allowed wording:

- `source-contract covered`
- `forced Windows compile covered`
- `wine-runtime-smoke` (secondary regression; never substitutes for real Windows)
- `focused-runtime` for modules with real Windows host logs outside CI matrix
- `ci-matrix` for the documented **22 platform gates** only (ROADMAP)
- do **not** say “23-gate platform ci-matrix” when the extra is only mem.host

## Current macOS truth

### Two evidence layers (do not mix)

| Layer | What it is | What it proves |
| --- | --- | --- |
| **A. Platform fail-closed matrix** | `platform-macos-ci-matrix.sh` step in job `test-macos` | **`focused-runtime`** for listed platform gates only |
| **B. Whole `test-macos` job** | May also run async-host / best-effort inventory | Job red/green is **not** platform promotion evidence |

**Documented platform set (layer A):** 9 platform gates
`platform.{time,sync,thread,files,path,env,error,socket,memory}` (ROADMAP D2.c +
Batch-5B). Script may also list **`mem.host_runtime`** → summary `total=10`.

- Promoted platform 9-gate: GHA **29696318492** @ `d160cbc46`
- Re-confirmed layer A green **pass=10 fail=0** (9 platform + mem.host) on
  run **29719632518** @ `918241bd4`. Overall job red on that run was
  **non-platform** (`net.async.dial` / `accept4`) — does **not** demote layer A.

Darwin `platform.memory` notes (honest residual, not a demotion):
- aligned alloc uses SysGetMem fallback (not posix_memalign) on Darwin
- secure-zero uses FillChar+barrier (not memset_s) on Darwin
- virtual reserve uses MAP_ANON + mprotect (not MAP_FIXED)

D2.c / Batch-5 promote is **scoped**: it does **not** claim full-host macOS
parity or treat best-effort whole-suite inventory as evidence.

Allowed wording:

- `focused-runtime` for the documented **9 platform gates** only (layer A)
- layer B / async inventory failures are out of scope for platform promotion

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
