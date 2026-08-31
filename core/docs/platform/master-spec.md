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
| `forced-compile` | Host branch compiles under a forced target. Carrier: `test_platform_simulated_host_compile_matrix` — darwin/android/freebsd/generic-unix/windows legs × all 29 `platform.*` facades (stat/pty deferrals leg-gated; windows leg is a true `-Twin64` cross target). | Symbols/types/uses are compile-coherent. |
| `focused-runtime` | Focused behavior gate runs on a real host. | The named path works on that host. |
| `ci-matrix` | CI repeats runtime proof across host/arch entries. | Runtime truth is durable for those entries. |

Without real runtime evidence, a host is not runtime ready.

## Current Windows truth

Windows x86_64 has host ABI declarations, source-contract coverage, forced
Windows compile gates, Wine runtime smoke (**25**-module matrix incl. watch RDCW,
pty ConPTY, console), and durable GHA **`ci-matrix`** for the **documented 28
platform gates** (`platform-windows-ci-matrix.sh` / `.ps1`, +… +pty +watch
+console). Console promote: GHA **30168411064** @ `5464b31c4`.

### Count honesty (do not mix)

| Count | Meaning |
| --- | --- |
| **28 platform gates** | Promoted `ci-matrix`: suite dirs through `…`+`pty`+`watch`+`console` + iocp + poller + io/socket real. `console` PASS on GHA **30168411064** @ `5464b31c4` (pass=29 fail=0 with mem.host). |
| **mem.host in total** | Optional **`mem.host_runtime`** (mem G4.x). Job `total` may be 29 — do **not** call mem.host a platform facade gate. |

Promotion is **scoped**: it does **not** claim full-host Windows parity for
modules outside that list (e.g. signal, native secure-zero) or for
IOCP AcceptEx/ConnectEx depth beyond current smoke gaps. Console promote is
facade smoke (is_terminal/size/ansi/write), **not** full TUI true-console product.

Allowed wording: `source-contract covered`; `forced Windows compile covered`;
`wine-runtime-smoke` (secondary; never substitutes for real Windows);
`focused-runtime` for real-Windows host logs outside CI matrix; `ci-matrix` for
the documented **28 platform gates** only — never “29-gate” (extra is mem.host).

## Current macOS truth

### Two evidence layers (do not mix)

| Layer | What it is | What it proves |
| --- | --- | --- |
| **A. Platform fail-closed matrix** | `platform-macos-ci-matrix.sh` step in job `test-macos` | **`focused-runtime`** for listed platform gates only |
| **B. Whole `test-macos` job** | May also run async-host / best-effort inventory | Job red/green is **not** platform promotion evidence |

**Documented platform set (layer A):** 10 platform gates
`platform.{time,sync,thread,files,path,env,error,socket,memory,console}`
(ROADMAP D2.c + Batch-5B; console promoted 2026-07-26). Script may also list
**`mem.host_runtime`** → summary `total=11`.

- Promoted 9-gate: GHA **29696318492** @ `d160cbc46`; console promote to 10:
  GHA **30198722396** @ `20f9c6de6` layer A **pass=11 fail=0** (job red there
  was non-platform `http.threaded_host` log.pas — does **not** demote layer A).

Darwin `platform.memory` native completeness: mmap-aligned alloc (heaptrc-
agnostic, inline header carve, zero-copy shrink; 16MiB cap) + FillChar+barrier
secure-zero; MAP_ANON+mprotect reserve/decommit/munmap.

D2.c / Batch-5 promote is **scoped**: it does **not** claim full-host macOS
parity or treat best-effort whole-suite inventory as evidence.

Allowed wording: `focused-runtime` for the documented **10 platform gates** only
(layer A); layer B / async inventory failures are out of platform scope.

### IOCP completion operations

All seven IOCP socket completion ops (AsyncRead/Write/Send/Recv/Close +
WSAIoctl-loaded ConnectEx/AcceptEx) live in `nextpas.core.io.reactor.iocp`
with source-contract coverage and forced Windows compile gates;
Send/Recv and Accept/Connect have focused-runtime evidence on Wine and a
real Windows VM.

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

## Optional host bindings (F-006)

`platform.freetype` and `platform.x11` are **optional dlopen host bindings**, not
core OS facades. They may use independent `FT_ERR_*` / `X11_ERR_*` domains.
Move-out requires a dedicated owner lane (ROADMAP D3.d). Do not treat them as
evidence for Windows/macOS platform matrix promotion.

## L0 heap policy (F-009)

Feature modules under platform may use System `GetMem`/`FreeMem` for internal
buffers. They must **not** depend on `nextpas.core.mem` (layer cycle). This is an
intentional L0 invariant.
