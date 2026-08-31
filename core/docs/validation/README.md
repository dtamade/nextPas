# nextpas.core.validation

`nextpas.core.validation` is the L2 validation helpers module. It provides a
fluent builder API (`TValidator`) with error collection (`TValidationResult`)
that accumulates all failures instead of stopping at the first, reusing L0
carrier types and avoiding `SysUtils` duplication.

- Layer: L2 (depends on L0-L1: `base` exception taxonomy, record helpers).
- Public facade: `src/nextpas.core.validation.pas`.
- Dependency policy: L0-L1 only; no `SysUtils`, no `platform` raw units.
- Truth: `focused-runtime` (`module-registry` L2 `validation`).
- Four-piece: facade-only single-unit (record API, no separate base/intf/ffi; helpers are inline-friendly pure functions).

## Gates

```bash
make -C core/tests/nextpas.core.validation clean test
```

See [CONTRACT.md](CONTRACT.md) for API, invariants, and performance notes (inline chain, zero-copy `TValidationErrors` growth).
