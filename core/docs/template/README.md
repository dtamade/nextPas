# nextpas.core.template

`nextpas.core.template` is the L3 text template engine (Go `text/template`
simplified). Supports variable substitution, conditionals, loops, pipe filters,
comparison operators, custom functions, local assignment, `with` scope and
`define`/`template` blocks, with parse-error fail-fast and context-isolated
rendering.

- Layer: L3 (depends on L0-L2: `text.conv` for `TryStrToInt64`, `errors` taxonomy).
- Public facade: `src/nextpas.core.template.pas`.
- Dependency policy: L0-L2 only; no `SysUtils` format duplication, no raw host units.
- Truth: `source-contract` (`core-module-registry` L3 `template`; `module-registry` deprecated alias).
- Four-piece: facade-only single-unit (record `TTemplate`/`TTemplateContext`, no separate base/intf/ffi).

## Gates

```bash
make -C core/tests/nextpas.core.template clean test
```

See [CONTRACT.md](CONTRACT.md) for grammar, filters, lifetime, and inline/zero-copy evidence.
