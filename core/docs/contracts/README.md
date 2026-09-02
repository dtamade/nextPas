# nextpas.core.contracts

`nextpas.core.contracts` is the L0 assertion helper surface. It provides
fail-fast pre-condition guards that reuse `nextpas.core.base` exception
taxonomy (`EInvalidArgument`/`EArgumentNil`) and compile to no-ops when
`NEXTPAS_CORE_CONTRACTS` is off.

- Layer: L0 (depends on `base`/`errors` taxonomy only, via `nextpas.core.base`).
- Public facade: `src/nextpas.core.contracts.pas`.
- Dependency policy: L0 root only (`base`/`exception`); no `SysUtils`/`platform`/`io`.
- Truth: `source-contract` + `focused-runtime` (contracts lane 1.1, `focused-runtime`).
- Four-piece: facade-only (no base/intf/ffi split; procedures are inline forwarders).

## Gate

```bash
make -C core/tests/nextpas.core.contracts clean test
```

See [CONTRACT.md](CONTRACT.md) for API and build-flag behavior.
