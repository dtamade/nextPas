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
   `source-contract`, `forced-compile`, `focused-runtime`, or `CI matrix`.
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
| `CI matrix` | CI repeats runtime proof across host/arch entries. | Runtime truth is durable for those entries. |

Without real runtime evidence, a host is not runtime ready.

## Current Windows truth

Windows x86_64 has host ABI declarations, source-contract coverage, and forced
Windows compile gates for key readiness/completion seams. It does not have real
Windows runtime or CI matrix evidence in this repository.

Allowed wording:

- `source-contract covered`
- `forced Windows compile covered`
- `not runtime ready`

Unsupported IOCP socket operations such as async accept/connect/send/recv/close
remain explicit unsupported boundaries until implementation and runtime evidence
exist.

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
