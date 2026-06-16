# nextpas.core.errors

`nextpas.core.errors` is the public L0 error facade. It exposes the stable error
taxonomy used by higher layers while keeping canonical exception definitions in
the root exception family.

## Boundary

- Layer: L0.
- Public facade: `src/nextpas.core.errors.pas`.
- Dependency policy: L0 taxonomy units only.
- Boundary truth: `source-contract`.
- Runtime truth: `focused-runtime` for category and exception behavior.

New modules should consume this facade for public error names instead of
creating local taxonomies.
