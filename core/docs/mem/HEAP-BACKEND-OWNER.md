# Heap backend owner (RTL isolation)

**Status**: Active (audit remediation 2026-07-26)
**Owner unit**: `nextpas.core.system.heap`
**Related**: `nextpas.core.system.memmanager` (TMemoryManager hooks only)

## Rule

| Layer | May call `System.GetMem/FreeMem/ReallocMem/AllocMem/Move`? |
|-------|-----------------------------------------------------------|
| `nextpas.core.system.heap` | **Yes** (sole process-heap owner for core) |
| `nextpas.core.system.memmanager` | Yes for Get/SetMemoryManager only |
| `nextpas.core.mem.*` | **No** — use `NpSystem*` |
| mem tests / examples (`core/tests|examples/nextpas.core.mem/**`) | **No** — use `NpSystem*` |
| All other `nextpas.core.*` | **No** — use system.heap or mem facades |

**Tests policy (MEM2-A-002)**: process-heap comparison rows (scorecard
"system" baseline, bench system patterns, allocator-callback fixtures) go
through `NpSystem*`. Wrappers are inline — identical codegen, so baseline
measurements are unchanged; no `System.*` WAIVE list exists. mem tests also
must not declare OS thread/TLS/clock FFI (`pthread_*`, `Fls*`,
`clock_gettime`) — use `nextpas.core.platform.*`.

## API

```pascal
uses nextpas.core.system.heap;

P := NpSystemGetMem(Size);
NpSystemFreeMem(P);
NpSystemFreeMem(P, Size);  // sized when known
P := NpSystemReallocMem(P, NewSize);
NpSystemAllocMem(Size);
NpSystemMove(Src, Dst, Count);
```

Wrappers are **inline**. Scorecard must stay green after mem migration.

## Gate

`core/tests/nextpas.core.mem/test_usability_guardrails/check_mem_rtl_isolation.sh`

Scans mem sources **and** `core/tests|examples/nextpas.core.mem/**`
(`*.pas`, `*.lpr`) for FPC RTL uses, `System.*` heap primitives, platform OS
sub-unit uses, and OS thread/TLS/clock FFI declarations.
