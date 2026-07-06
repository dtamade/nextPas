# mapped_ring_buffer compatibility contract

## Strategy

**Thin wrapper with deprecation.**

Rationale:
- No external consumers exist — only `mapped_ring_buffer.sharded` depends on `mapped_ring_buffer`.
- A thin wrapper minimizes risk.
- Deprecation markers prevent new L0 mem imports.
- Breaking migration is unnecessary given zero external consumers.

## Wrapper contract

When migration begins:

1. New implementation lives in `nextpas.core.io.mapped.ring_buffer`.
2. Old `nextpas.core.mem.mapped_ring_buffer` becomes a thin wrapper that:
   - uses the new unit in implementation.
   - re-exports the same types with compatibility aliases.
   - adds a `{$WARNING 'mapped_ring_buffer is deprecated: use nextpas.core.io.mapped.ring_buffer'}` directive.
3. Old `nextpas.core.mem.mapped_ring_buffer.sharded` follows the same pattern.
4. After one release cycle, the old wrapper is removed.

## What not to do during migration

- Do not change public type names.
- Do not break the sharded wrapper.
- Do not add new public API.

## Consumer replay matrix

When the actual migration begins, these gates must all pass:

| Gate | Purpose |
|------|---------|
| `make -C core/tests/nextpas.core.mem/test_l0_dependency_boundaries test` | No new L0 violations |
| `make -C core/tests/nextpas.core.mem/test_memory_map_compile_gate clean test` | memory_map compile truth |
| `make -C core/tests/nextpas.core.mem/test_memory_map_allocator clean test` | memory_map_allocator behavior |
| `make -C core/tests/nextpas.core.mem/test_mapped_slab_pool clean test` | slab_pool behavior (indirect) |
| `make -C core/tests/nextpas.core.mem/test_mapped_ring_buffer_compile_gate test` | Old wrapper still compiles |
| `make -C core/tests/nextpas.core.io/test_mapped_ring_buffer_compile_gate test` | New owner compiles |
| `make -C core/tests/nextpas.core.io/test_io_flow clean test` | io.mapped consumer |
| `make -C core/tests/nextpas.core.fs/test_fs_text clean test` | fs consumer (uses io.mapped) |
| `make -C core/tests/nextpas.core.mem/test_sharded_pools clean test` | sharded pools behavior |
| `git diff --check` | Whitespace hygiene |
| `make hygiene` | Build hygiene |

All gates must pass with heaptrc `0 unfreed memory blocks` where applicable.

## Stop rules

Immediately report `Needs Review` if any of these conditions are met:

1. The migration touches `memory_map` ownership or public API.
2. The migration requires new shared-memory IPC policy (naming, lifecycle, security).
3. The migration pulls `mapped_slab_pool` into relocation scope.
4. The wrapper strategy breaks `mapped_ring_buffer.sharded` behavior.
5. Any consumer replay gate fails and cannot be fixed with a minimal wrapper adjustment.
6. The migration introduces new L0 boundary violations.
7. The migration expands `io.mapped` public surface beyond the ring-buffer contract.
