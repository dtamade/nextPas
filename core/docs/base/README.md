# nextpas.core.base

`nextpas.core.base` is the L0 root type and utility surface. It owns the shared
carrier types, size constants, and low-level helper contracts that other core
modules can use without importing a higher layer.

## Boundary

- Layer: L0.
- Public facade: `src/nextpas.core.base.pas`.
- Dependency policy: bootstrap RTL plus documented L0 root exceptions only.
- Boundary truth: `source-contract`.
- Runtime truth: `focused-runtime` for public helpers and carrier behavior.

Broader runtime policy belongs in owner modules such as `platform`, `mem`, or
`system`; `base` stays small enough for those owners to depend on it.
