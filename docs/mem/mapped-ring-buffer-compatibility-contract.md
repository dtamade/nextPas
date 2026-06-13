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
