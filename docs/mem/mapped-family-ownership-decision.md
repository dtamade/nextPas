# mem mapped-family ownership decision

## Decision

- Keep `nextpas.core.mem.memory_map` in L0 mem for now.
- Keep `nextpas.core.mem.allocator.memory_map_allocator` in L0 mem for now.
- Keep `nextpas.core.mem.mapped_slab_pool` anonymous allocator path in L0 mem for now.
- Treat `nextpas.core.mem.mapped_ring_buffer` as future migration surface.
- Treat `nextpas.core.mem.mapped_ring_buffer.sharded` as future migration surface.
- Treat `nextpas.core.mem.mapped_slab_pool` file/shared manager path as future migration surface.

## Rationale

- `memory_map` is already the narrow platform-owned mapping seam used by mem.
- `memory_map_allocator` is anonymous mapping-backed allocator behavior, not IPC policy.
- `mapped_ring_buffer` and `mapped_ring_buffer.sharded` are cross-process/shared-memory data structures, not core allocator surface.
- `mapped_slab_pool` mixes anonymous allocator behavior with file-backed/shared-memory manager behavior; that split must be resolved before any larger move.
- `nextpas.core.io.mapped` is an active consumer of `memory_map`, so any ownership change for `memory_map` must be replayed against the IO surface.

## Affected surfaces

- `nextpas.core.mem.memory_map`
- `nextpas.core.mem.allocator.memory_map_allocator`
- `nextpas.core.mem.mapped_ring_buffer`
- `nextpas.core.mem.mapped_ring_buffer.sharded`
- `nextpas.core.mem.mapped_slab_pool`
- `nextpas.core.io.mapped`

## What not to do next

- Do not move `memory_map` until a higher owner is explicitly approved.
- Do not relocate `memory_map_allocator` while it remains the canonical anonymous allocator backend.
- Do not treat `mapped_ring_buffer` as settled L0 mem surface just because its helper imports were cleaned.
- Do not refactor `mapped_slab_pool` until the allocator surface is separated from the file/shared manager surface.

## Recommended first migration candidate

If migration is later approved, `mapped_ring_buffer` should be the first relocation candidate, not `memory_map`.

`mapped_slab_pool` should be reviewed as two surfaces before any move:
1. anonymous allocator path
2. file-backed/shared-memory manager path

## Next slices

1. If migration is later approved, relocate `mapped_ring_buffer` and
   `mapped_ring_buffer.sharded` first.
2. Split `mapped_slab_pool` into allocator surface and file/shared manager
   surface before moving it.
3. Treat `memory_map` as temporary L0 surface, not permanent stable surface.
4. Always replay `nextpas.core.io.mapped` before changing `memory_map`
   ownership.
