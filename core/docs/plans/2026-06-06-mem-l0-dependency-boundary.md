# Mem L0 Dependency Boundary

## Current position

`mem` is an L0 module, so its supported surface should not depend on L1/L2
modules or raw host units. The current mem tree still has transitional boundary
debt. This note keeps that debt visible while the allocator correctness work
lands.

This batch does not mechanically delete `uses` entries. The rule is stricter:
host ABI and OS mapping details move behind platform-owned facades, and anything
that cannot meet the L0 rule must be reclassified instead of pretending to be a
clean L0 mem unit.

## Boundary decisions

- `nextpas.core.mem.intf`, allocator facade aliases, local arena/pool names,
  `TMappedSlabPool`, `TMemoryMapAllocator`, mimalloc usable-size fallback, and
  NUMA no-op provider stay in the mem roadmap because they define allocation
  contracts.
- `nextpas.core.mem.memory_map` is a boundary concern. If it stays under mem, it
  must stop using `Windows`, `BaseUnix`, `Unix`, `fs.util`, and `text.conv`
  directly. OS mapping and shared-memory details should move behind
  platform-owned APIs.
- `nextpas.core.mem.manager.rtl`, `nextpas.core.mem.blockpool.sharded`, and
  other mem units that use `nextpas.core.sync` need either lower-level L0
  primitives or relocation of the synchronized implementation out of L0 mem.
- `nextpas.core.mem.pool.slab` using `nextpas.core.platform.time` needs a clear
  L0 primitive contract or a move of timing/statistics code out of the L0
  allocator core.
- NUMA remains optional capability truth only. The default provider is an
  explicit no-op and does not silently fall back to ordinary allocation.

## Source contract

The source contract is:

```bash
make -C tests/nextpas.core.mem/test_l0_dependency_boundaries test
```

The script scans `src/nextpas.core.mem*.pas` `uses` blocks for direct references
to disallowed higher-layer or host units. It currently allows only the known
debt listed in the script. Any new direct dependency fails the test.

This lets correctness work proceed while preventing the boundary from getting
worse. Removing an allowlisted dependency is a follow-up cleanup; adding a new
one requires a design note and owner review.

## Follow-up route

1. Move raw memory-map host calls into platform-owned mapping/shared-memory
   facades, or reclassify the mapping unit outside L0 mem.
2. Split synchronized blockpool/slab variants away from the L0 allocation core
   unless they can use approved L0 primitives.
3. Keep mmap-backed `IAllocator` on the anonymous mapping path until the mapping
   boundary is cleaned; do not extend it to file/shared mapping in the same
   commit as allocator API convergence.
