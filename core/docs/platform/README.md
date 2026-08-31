# nextpas.core.platform

L0 OS foundation for nextPas. Owns host raw FFI and portable feature facades.
Not an FPC `BaseUnix` / `Windows` / `SysUtils` compatibility layer.

## Authority

| Document | Role |
| --- | --- |
| [ROADMAP.md](ROADMAP.md) | **Sole forward-execution plan** (phases D0–D5, acceptance criteria) |
| [master-spec.md](master-spec.md) | Owner boundaries, truth tiers, readiness/completion split |
| [goal-tree.md](goal-tree.md) | Phase state log and evidence gaps (not the forward queue) |
| [runtime-truth-matrix.md](runtime-truth-matrix.md) | Host/seam truth with evidence labels only |
| [CONTRACT.md](CONTRACT.md) | Module contract: APIs, invariants, errors, ownership |
| [RETURN-SEMANTICS.md](RETURN-SEMANTICS.md) | Three-tier return model + RTL isolation freeze |
| [ERROR-HANDLING.md](ERROR-HANDLING.md) | **Error authority**: live `PLATFORM_ERR_*` table (must match `error.pas`) |
| [QUICKSTART.md](QUICKSTART.md) | Common usage patterns |
| [API-REFERENCE.md](API-REFERENCE.md) | Public API catalog; error names must match ERROR-HANDLING (no phantoms) |
| [residual-roadmap.md](residual-roadmap.md) | Closed residual program LT0–LT3 + dual-IO/F6 freeze; remaining host work → ROADMAP |
| [host-capability-matrix.md](host-capability-matrix.md) | Per-API-family host honesty table (audit F-015) |

## Current truth (one line)

Linux x86_64 is `focused-runtime` across facade modules. Windows has Wine smoke
plus **`ci-matrix` 28 platform gates** (GHA, including console); macOS / FreeBSD /
Android remain `source-contract` / `forced-compile` / best-effort. Evidence:
[goal-tree.md](goal-tree.md). Usability **8.21** is maintenance-only. **Execute
work from [ROADMAP.md](ROADMAP.md)**, not from open-ended assessment waves or
historical ROADMAP-v2.

## Focused verification

```bash
# Module-local examples
make focused FOCUS=core/tests/nextpas.core.platform.console/test_platform_console
make focused FOCUS=core/tests/nextpas.core.platform.error/test_platform_error
make focused FOCUS=core/tests/nextpas.core.platform/test_platform_return_semantics_contract
make focused FOCUS=core/tests/nextpas.core.platform/test_platform_docs_live_patterns
make focused FOCUS=core/tests/nextpas.core.platform/test_platform
make focused FOCUS=core/tests/nextpas.core.platform/test_platform_goal_tree_contract

# Architecture boundary
make -C core/tests/architecture/source_contracts host-raw-ffi-audit
make hygiene
```

## Recommended uses (feature units)

| Need | Unit |
|------|------|
| OS/CPU info, monotonic time | `nextpas.core.platform` or `.info` / `.time` |
| Files / dirs | `.files` / `.fs` / `.path` |
| Process / pipes | `.process` / `.pipe` (prefer `*_ex`; **no** new `platform_io_*` call sites) |
| Sockets | `.socket` |
| Sync / threads | `.sync` / `.thread` |
| Console / TTY | `.console` (read/write: value/sentinel `-1` on failure) |
| Errors | `.error` (`PLATFORM_ERR_*`) |

Root unit `nextpas.core.platform` re-exports a thin info/time surface only;
prefer feature units (`platform.files`, `platform.process`, ...) for real work.

## Source layout

```
core/src/nextpas.core.platform*.pas     feature facades + host base/ffi
core/tests/nextpas.core.platform*/      focused runtime / wine / compile gates
core/docs/platform/                     this documentation set
```

## Historical / non-authority

历史参考仅归档，不作为事实。
