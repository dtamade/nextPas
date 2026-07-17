# L1 Layer Goal Tree

L1 is the portable runtime layer above L0: text, bytes, collections, sync,
thread, time, io, async, and related helpers. L0 owns host ABI; L1 must not
reach into raw host units.

## Truth Levels

| Level | Claim |
| --- | --- |
| `source-contract` | Static ownership and dependency shape is locked. |
| `forced-compile` | A host branch compiles under a forced target. |
| `focused-runtime` | A focused gate runs on a real host. |
| `ci-matrix` | Runtime proof repeats across a named CI host/arch set. |

Do not promote a module past the strongest evidence tier it currently holds.

## Evidence

L0/L1 kernel evidence rows (module source-contract gates pin these strings):

| Module | Surface | Evidence |
| --- | --- | --- |
| `atomic` | 原子操作 (Load/Store/CAS/Fetch*, 全内存序) | source-contract / forced compile / focused runtime: atomic 43/43 |
| `lockfree` | 无锁 (MPMC/SPSC/MPSC/Stack/Deque) | source-contract / focused runtime / stress: lockfree stress 14/14 |

| Domain | Owner modules | Current evidence |
| --- | --- | --- |
| Text / bytes / encoding | `text`, `bytes`, `encoding` | `source-contract` + `focused-runtime` on Linux |
| Containers | `collections`, `lockfree` | `focused-runtime`; stress gates where present |
| Sync / thread / time | `sync`, `thread`, `time`, `stopwatch` | `focused-runtime` on Linux; Windows via consumers |
| IO / async | `io`, `async` | Linux `focused-runtime`; Windows poller via platform/`io.reactor` |
| Test harness | `test` | `focused-runtime` used by module gates |

Raw host units (`Windows`, `BaseUnix`, `Unix`, `DynLibs`, `ctypes`) remain
outside L1. Host truth enters through `platform` or explicit allowlisted debt.

## Governance gates

- Architecture source contracts: module registry, L0 dependency boundary,
  host raw-FFI ownership, governance docs.
- L0 must not depend on L1 except via explicit debt allowlist entries with
  owner and retirement route named in the landing report.
- Module public facades stay in `core/src/nextpas.core.<module>.pas`.
- New L1 modules must appear in `core/docs/core-module-registry.md` before
  claiming readiness.

Gate entry:

```bash
make -C core/tests/architecture/source_contracts clean test
```

## Next priorities

1. Keep L1 consumers off raw host units; route through `platform`.
2. Retire L0→L1 transitional debt (`system` text/io/path/fs, `simd` parallel
   GEMM thread) when owner routes exist.
3. Hold Windows/macOS claims at the tier with real evidence only
   (`forced-compile`, `focused-runtime`, or `ci-matrix`).
4. Expand focused gates where API surface grew without runtime proof.

## Non-goals

- L1 is not an FPC RTL compatibility layer.
- L1 does not own host ABI declarations.
- Status labels without an evidence tier are invalid.
