# nextpas.core.mem

`nextpas.core.mem` is the L0 allocation foundation for nextPas core. Its job is
to expose small, honest allocation contracts and a few reusable local ownership
primitives without pulling in higher-layer runtime policy by accident.

## Stable Surface

The current stable public surface is centered on `IAllocator`:

- `nextpas.core.mem.intf.IAllocator` is the canonical allocator contract.
- `nextpas.core.mem.allocator` and `nextpas.core.mem.allocator.base` keep
  compatibility aliases to that same contract.
- `nextpas.core.mem.DefaultAllocator` returns the process-wide default
  allocator facade.

The facade unit `nextpas.core.mem` also re-exports the current local record
types:

- `TLocalArena` with `TArena` as a compatibility alias
- `TLocalBlockPool` with `TPool` as a compatibility alias

These names are intended to make ownership and lifecycle shape visible in call
sites without forcing downstream code to migrate all at once.

The current internal L0 helper surface also includes `nextpas.core.mem.mutex`
and `nextpas.core.mem.rwlock`, which keep concurrent mem units on
platform-owned sync primitives instead of routing through the broader L1 sync
module.

## Module Shape

The mem tree currently contains four practical families:

- Allocator contracts and adapters: `mem.intf`, `mem.allocator*`, `mem.alloc`,
  `mem.adapter`
- Local ownership primitives: `mem.arena`, `mem.pool`, `mem.blockpool`
- Backend allocators: default RTL allocator, memory-map allocator, mimalloc
  bindings, NUMA provider facade
- Specialized pools and mapped structures: slab pool, stack pool, mapped slab,
  mapped ring buffer

At L0, correctness and ownership truth are more important than breadth. A mem
unit should either be an honest allocation primitive or move out of the L0 core.

## Focused Gates

Recommended focused verification for the current mem surface:

```sh
make -C core/tests/nextpas.core.mem/test_contracts clean test
make -C core/tests/nextpas.core.mem/test_mem clean test
make -C core/tests/nextpas.core.mem/test_arena clean test
make -C core/tests/nextpas.core.mem/test_arena_class clean test
make -C core/tests/nextpas.core.mem/test_pool clean test
make -C core/tests/nextpas.core.mem/test_blockpool clean test
make -C core/tests/nextpas.core.mem/test_slab_pool clean test
make -C core/tests/nextpas.core.mem/test_concurrent_wrappers clean test
make -C core/tests/nextpas.core.mem/test_default_allocator clean test
make -C core/tests/nextpas.core.mem/test_memory_map_allocator clean test
make -C core/tests/nextpas.core.mem/test_memory_map_compile_gate clean test
make -C core/tests/nextpas.core.mem/test_memory_manager_rtl clean test
make -C core/tests/nextpas.core.mem/test_memory_manager_crt_compile_gate clean test
make -C core/tests/nextpas.core.mem/test_mapped_ring_buffer clean test
make -C core/tests/nextpas.core.mem/test_mapped_slab_pool clean test
make -C core/tests/nextpas.core.mem/test_stack_pool clean test
make -C core/tests/nextpas.core.mem/test_oom clean test
make -C core/tests/nextpas.core.mem/test_numa_allocator clean test
make -C core/tests/nextpas.core.mem/test_l0_dependency_boundaries test
```

The L0 boundary contract is source-based. It does not prove the architecture is
finished; it only prevents the known debt from spreading silently.

## Current L0 Boundary Truth

What is already aligned with the L0 direction:

- The canonical allocator contract lives in `mem.intf`.
- `DefaultAllocator` stays small and delegates to the RTL allocator singleton.
- `TMemoryMapAllocator` gives mem an allocator backend without forcing file or
  shared-memory policy into the default path.
- `nextpas.core.mem.memory_map` no longer depends on `nextpas.core.fs.util` or
  `nextpas.core.text.conv` for local helper behavior; existence checks now go
  through platform file stat and string replacement stays at the RTL level.
- The mem mapping path now has a focused Windows host-compile gate so local
  helper cleanups cannot silently break `memory_map` or its anonymous allocator
  path under `NEXTPAS_FORCE_HOST_WINDOWS`.
- `nextpas.core.mem.allocator.mimalloc` no longer depends on `text.conv` for
  platform-library path selection; the remaining helper is explicit RTL
  `SysUtils.LowerCase`.
- `nextpas.core.mem.pool.fixed` no longer depends on `nextpas.core.text.conv`
  for its debug-only leak message; the fixed pool keeps L0 ownership and uses
  local `Str` formatting instead.
- `nextpas.core.mem.mapped_ring_buffer` no longer depends on
  `nextpas.core.fs.util` for file existence checks; file-backed ring buffers
  now consume the platform-owned file-stat facade directly.
- `nextpas.core.mem.mapped_slab_pool` no longer depends on
  `nextpas.core.text.conv` for manager-generated pool names or
  `nextpas.core.fs.util` for file existence checks; generated names stay local
  and file-backed pools now consume the platform-owned file stat facade.
- `TSlabPool` no longer samples `platform.time` directly; the core keeps call
  counters but does not depend on L1 timing APIs.
- `mem.blockpool.concurrent`, `mem.pool.fixed.concurrent`, and
  `mem.pool.slab.concurrent` no longer depend on `nextpas.core.sync`; they use
  the local `TMemMutex` helper backed by `nextpas.core.platform.sync`.
- `mem.blockpool.sharded` no longer depends on `nextpas.core.sync` or
  `nextpas.core.time.cpu`; it now uses `TMemMutex` plus
  `nextpas.core.platform.thread` for its local contention paths.
- `mem.pool.slab.sharded` no longer depends on `nextpas.core.sync` or
  `nextpas.core.time.cpu`; it now uses `TMemMutex`, `TMemRwLock`, and
  `nextpas.core.platform.thread`.
- `mem.manager.rtl` no longer depends on `nextpas.core.sync`, and its install
  path delegates directly to the previously active RTL memory manager instead
  of recursing through `GetRtlAllocator`.
- `mem.manager.crt` no longer depends on `nextpas.core.sync`; the guarded CRT
  manager path now has a focused compile gate so the optional macro branch
  cannot silently rot.
- NUMA remains an explicit optional capability, with a no-op default provider
  instead of silent best-effort behavior.
- Raw mapping and shared-memory host ownership have moved behind the
  platform-owned mmap facade; `mem.memory_map` remains a compatibility wrapper
  and `TMemoryMapAllocator` stays on the anonymous mapping-backed allocator
  path.

## Known Debt

The boundary is not fully clean yet. The main remaining debt is:

- The current source-boundary contract still carries 2 allowlisted debt
  entries; this is a guardrail against regression, not proof that mem is
  already layer-clean.
- `mapped_ring_buffer.sharded` still carries non-L0 helper dependencies that
  should be revisited with its owning architecture slice.

Treat these as explicit debt, not as proof that mem is already layer-clean.

## Follow-Up Route

Priority follow-up slices:

1. Revisit the mapped ring-buffer sharded helpers so their remaining
   higher-layer dependencies either move behind platform-owned seams or leave
   the L0 mem core.
2. Keep the mem mapping compile surface honest across host branches: helper
   cleanups may stay in mem, but do not reopen the landed mapping/shared-memory
   owner slice without a new blocker.
3. Keep allocator-manager behavior narrow and explicit: `rtl` now has a runtime
   regression test for installation safety, while optional guarded backends such
   as CRT need at least compile truth before wider rollout.
4. Keep narrowing public allocator claims so traits, ownership, and fallback
   behavior remain verifiable and unsurprising.
