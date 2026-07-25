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
| All other `nextpas.core.*` | **No** — use system.heap or mem facades |

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
