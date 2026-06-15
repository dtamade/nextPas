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
- `TAllocResult.ExpectPtr` raises canonical `EOutOfMemory` for
  `aeOutOfMemory`. Capacity exhaustion remains an `EAllocError` with
  `Error = aeCapacityExhausted` and reports `ecResourceExhausted`; it is not an
  invalid-pointer leaf.

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
make -C core/tests/nextpas.core.mem/test_mapped_ring_buffer_sharded clean test
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
- `nextpas.core.mem.memory_map` and the mapped-family units no longer use
  `nextpas.core.fs.util` or `nextpas.core.text.conv` where they were previously
  avoidable; file existence checks now go through platform file stat helpers.
- `nextpas.core.mem.mapped_ring_buffer.sharded` now uses `nextpas.core.mem.mutex`
  instead of `SyncObjs`, so the concurrent wrapper stays inside the mem-local
  sync surface rather than pulling in a broader host-only unit.
- `nextpas.core.mem.pool.fixed` no longer depends on `nextpas.core.text.conv`;
  the debug-only `Format` path was moved behind a narrow `{$IFDEF FAF_MEM_DEBUG}`
  implementation guard.
- `nextpas.core.mem.secure` now delegates secure zeroing to `nextpas.core.platform.memory`, so backend truth and future host promotion stay under the platform owner.
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

The live dependency-boundary gate now reports **0 allowlisted debt entries**.

That means mem currently has no known new helper or host-unit boundary
regressions, but it does **not** mean mapped-family ownership was already
settled. The debt gate only proves known source-boundary violations have been
removed.

The ownership decision is now explicit:

- `nextpas.core.mem.memory_map` stays in L0 mem for now.
- `nextpas.core.mem.allocator.memory_map_allocator` stays in L0 mem for now.
- `nextpas.core.mem.mapped_slab_pool` owns only the anonymous mapping allocator surface.
- `nextpas.core.io.mapped.slab_pool` is the fixed owner for file-backed and shared-memory slab pools.
- `nextpas.core.io.mapped.ring_buffer` and
  `nextpas.core.io.mapped.ring_buffer.sharded` are the fixed owners for mapped
  ring buffer behavior.
- The mem allocator surface must not grow `CreateFile`, `OpenFile`, `CreateShared`, `OpenShared`, or `nextpas.core.platform.files` dependencies.
- `nextpas.core.mem.mapped_ring_buffer*` are thin deprecated compatibility wrappers only.

See `src/nextpas.core.mem.mapped_slab_pool.pas` and `src/nextpas.core.io.mapped.slab_pool.pas` for the current owner split.

Additional architecture debt that remains:

- `nextpas.core.mem.mapped_ring_buffer*` remain in `mem` only as deprecated
  wrappers. Keep them thin and do not grow new behavior there.
- `mem.secure` now relies on the `nextpas.core.platform.memory` secure-zero seam; future host upgrades should evolve that owner instead of reintroducing raw imports into `mem`.

## Follow-Up Route

Priority follow-up work:

0. **mapped_ring_buffer owner split** (completed):
   - Owner: `nextpas.core.io.mapped.ring_buffer`
   - Compatibility: `nextpas.core.mem.mapped_ring_buffer*` stay as thin deprecated wrappers
   - Status: readiness gates complete and owner move landed
1. Keep the `mapped_slab_pool` split stable: anonymous allocator work stays in `mem`, and file/shared lifecycle work stays in `nextpas.core.io.mapped.slab_pool`.
2. Treat `memory_map` as temporary L0 surface, not permanent stable surface;
   always replay `nextpas.core.io.mapped` before changing `memory_map`
   ownership.
3. Revisit `nextpas.core.platform.memory` only if a later platform slice promotes a native Windows secure-zero owner.
4. Keep allocator-manager behavior narrow and explicit: `rtl` already has a
   runtime regression test for installation safety, while optional guarded
   backends such as CRT still need at least compile truth before wider rollout.
5. Keep narrowing public allocator claims so traits, ownership, and fallback
   behavior remain verifiable and unsurprising.
