# nextpas.core.platform

L0 OS foundation for nextPas. Owns host raw FFI and portable feature facades.
Not an FPC `BaseUnix` / `Windows` / `SysUtils` compatibility layer.

## Authority

| Document | Role |
| --- | --- |
| [master-spec.md](master-spec.md) | Owner boundaries, truth tiers, readiness/completion split |
| [goal-tree.md](goal-tree.md) | Phase state and evidence gaps |
| [runtime-truth-matrix.md](runtime-truth-matrix.md) | Host/seam truth with evidence labels only |
| [CONTRACT.md](CONTRACT.md) | Module contract: APIs, invariants, errors, ownership |
| [RETURN-SEMANTICS.md](RETURN-SEMANTICS.md) | Three-tier return model + RTL isolation freeze |
| [ERROR-HANDLING.md](ERROR-HANDLING.md) | **Error authority**: live `PLATFORM_ERR_*` table (must match `error.pas`) |
| [QUICKSTART.md](QUICKSTART.md) | Common usage patterns |
| [API-REFERENCE.md](API-REFERENCE.md) | Public API catalog; error names must match ERROR-HANDLING (no phantoms) |

## Current truth (one line)

Linux x86_64 is `focused-runtime` across facade modules. Windows has Wine smoke
plus partial real-Windows runtime; macOS / FreeBSD / Android remain
`source-contract` / `forced-compile`. See [goal-tree.md](goal-tree.md).

## Focused verification

```bash
# Module-local examples
make focused FOCUS=core/tests/nextpas.core.platform.process/test_platform_process
make focused FOCUS=core/tests/nextpas.core.platform.console/test_platform_console
make focused FOCUS=core/tests/nextpas.core.platform.pty/test_platform_pty
make focused FOCUS=core/tests/nextpas.core.platform.args/test_platform_args
make focused FOCUS=core/tests/nextpas.core.platform.error/test_platform_error
make focused FOCUS=core/tests/nextpas.core.platform/test_platform_return_semantics_contract
make focused FOCUS=core/tests/nextpas.core.platform/test_platform
make focused FOCUS=core/tests/nextpas.core.platform/test_platform_goal_tree_contract

# Architecture boundary
make -C core/tests/architecture/source_contracts host-raw-ffi-audit
make hygiene
```

## Source layout

```
core/src/nextpas.core.platform*.pas     feature facades + host base/ffi
core/tests/nextpas.core.platform*/      focused runtime / wine / compile gates
core/docs/platform/                     this documentation set
```

Root unit `nextpas.core.platform` re-exports a thin info/time surface. Prefer
feature units (`platform.files`, `platform.process`, ...) for real work.

## Historical / non-authority

These remain for history or migration reference; do not treat as current truth:

- [api-reference.md](api-reference.md) — superseded by `API-REFERENCE.md`
- [ROADMAP.md](ROADMAP.md) — historical roadmap snapshot (**ignore embedded 8.56 score**)
- [ROADMAP-v2.md](ROADMAP-v2.md) — planning snapshot; verify against goal-tree
- [GOVERNANCE-PLAN.md](GOVERNANCE-PLAN.md), daily reports, [TEST-COVERAGE-REPORT.md](TEST-COVERAGE-REPORT.md), [API-CONSISTENCY-PLAN.md](API-CONSISTENCY-PLAN.md)
- [USABILITY-ASSESSMENT.md](USABILITY-ASSESSMENT.md) — body is 2026-07-06 historical; **only the top banner score is current** (wave-4)
- `../platform-ffi-*` — ABI evidence indexes until fully folded here
