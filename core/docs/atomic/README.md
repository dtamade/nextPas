# nextpas.core.atomic

`nextpas.core.atomic` owns L0 atomic primitives and lock-free building blocks
needed by lower layers. It must not pull in scheduler, collection, or runtime
policy from upper layers.

## Boundary

- Layer: L0.
- Public facade: `src/nextpas.core.atomic.pas`.
- Dependency policy: L0 only.
- Boundary truth: `source-contract`.
- Runtime truth: `focused-runtime` for the current atomic operations.

Higher-level coordination belongs in `sync`, `thread`, `async`, or owner
modules that depend downward on this primitive surface.
