# Exception Root Convergence Design

## Goal

Converge nextpas.core exceptions onto one official framework root without a broad repository rewrite. The first stage introduces the low-level root infrastructure, removes the public `ETimeoutError` split, converges the public out-of-memory meaning, and proves unified catch semantics with focused tests.

This work belongs to the core L0 architecture debt lane:

- Goal tree node: `G0` quality discipline and `core L0 base/errors/mem` framework foundation.
- Not in scope: compiler work, HTTP behavior changes, broad performance work, or whole-repository exception migration.

## Current State

The repository has three incompatible roots or near-roots:

- `nextpas.core.base`
  - Defines `ECore = class(Exception)`.
  - Defines public `ETimeoutError`, `EOutOfMemory`, `EArgumentNil`, `EInvalidArgument`, and other legacy exceptions under `ECore`.
- `nextpas.core.errors`
  - Defines `ENextPasError = class(Exception)`.
  - Carries `TErrorCategory`, `Inner`, and `OwnsInner`.
  - Defines another public `ETimeoutError` and `EOutOfMemoryError`.
- `nextpas.core.mem.error`
  - Defines `EAllocError = class(ECore)`.
  - Defines another `EOutOfMemory = class(EAllocError)`.

This creates unstable catch semantics. A caller cannot rely on one framework root, and same-name exceptions are not necessarily the same runtime type.

## Design

### Official Root Unit

Add `nextpas.core.exception` as the lower-level L0 exception contract.

This unit owns:

- `TErrorCategory`.
- `ENextPasError`, the only official framework root exception.
- Category and inner-exception storage.
- Canonical common framework exceptions needed by both `base` and `errors`, including `ETimeoutError` and the canonical out-of-memory exception.

`nextpas.core.exception` depends only on `SysUtils`, so it satisfies the L0 rule.

### New Relationships

```text
SysUtils.Exception
  |
  +-- nextpas.core.exception.ENextPasError   official framework root
        |
        +-- ECore                            legacy compatibility root
        |     |
        |     +-- EArgumentNil, EInvalidArgument, ...
        |
        +-- ETimeoutError                    canonical timeout exception
        +-- EOutOfMemoryError                canonical public OOM exception
        |     |
        |     +-- EOutOfMemory               compatibility short name
        |
        +-- EAllocError                      mem allocation root
              |
              +-- mem-specific allocation subclasses
```

Target unit dependencies:

```text
nextpas.core.exception  -> SysUtils only
nextpas.core.base       -> nextpas.core.exception, SysUtils
nextpas.core.errors     -> nextpas.core.exception, SysUtils
nextpas.core.mem.error  -> nextpas.core.exception
```

There is no `nextpas.core.base -> nextpas.core.errors` dependency.

### `nextpas.core.base`

`base` remains the root type carrier for constants, aliases, callbacks, spans, and legacy base exceptions. It re-exports canonical exception names from `nextpas.core.exception` through type aliases where possible.

`ECore` remains as a compatibility root in stage 1, but it now inherits from `ENextPasError`. This makes existing `on E: ECore` and new `on E: ENextPasError` catch semantics both work for old base-derived exceptions.

`ECore` is not the long-term public root. The deprecation route is:

1. Stage 1: keep it source-compatible and make it catchable as `ENextPasError`.
2. Later stages: migrate module-specific roots from `ECore` to `ENextPasError` or a module root under it.
3. Final stage: stop documenting `ECore` as a public root and eventually remove it when downstream compatibility allows.

### `nextpas.core.errors`

`errors` becomes the public taxonomy/facade unit for common framework exceptions. It no longer defines a second `ENextPasError`, `TErrorCategory`, `ETimeoutError`, or OOM root. It aliases or re-exports canonical types from `nextpas.core.exception`, while preserving constructor/category behavior.

This keeps existing `uses nextpas.core.errors` consumers working while moving ownership down to the proper layer.

### `nextpas.core.mem.error`

`mem.error` keeps allocation-specific error codes and `TAllocResult`. It no longer owns a separate public OOM meaning.

`EAllocError` moves under `ENextPasError`, with `Error: TAllocError` preserved. The mem-specific `EOutOfMemory` becomes a compatibility name tied to the canonical OOM lineage. If FPC aliasing cannot preserve `EOutOfMemory.Create(aError, aMsg)` safely, stage 1 will keep a mem-specific subclass under the canonical OOM root, but the public catch contract must satisfy:

- `EOutOfMemory` is catchable as `ENextPasError`.
- `EOutOfMemory` is catchable as the canonical OOM public type.
- `EAllocError` is catchable as `ENextPasError`.

### Timeout Convergence

`ETimeoutError` has one canonical class in `nextpas.core.exception`.

Both `nextpas.core.base.ETimeoutError` and `nextpas.core.errors.ETimeoutError` resolve to that canonical class. This is the key first-stage fix because HTTP H1 has type-identity logic for timeout read failures.

### Out-Of-Memory Convergence

The official public OOM root is `EOutOfMemoryError`. The short `EOutOfMemory` remains as a compatibility name because collection, SIMD, and mem modules already use it widely.

Stage 1 rule:

- `EOutOfMemory` and `EOutOfMemoryError` are in the same canonical lineage.
- Catching `EOutOfMemoryError` catches compatibility `EOutOfMemory`.
- Catching `ENextPasError` catches both.

This keeps old source code compiling while giving new code a stable explicit public name.

## Migration Order

Stage 1:

- Add `nextpas.core.exception`.
- Move or alias common exception ownership into it.
- Update `base`, `errors`, and `mem.error` inheritance/aliasing.
- Add focused tests proving unified root, timeout identity, and OOM compatibility.
- Keep HTTP changes mechanical only if the timeout test requires qualification.

Stage 2:

- Migrate module roots that still inherit `ECore`, starting with `nextpas.core.tui.error`.
- Migrate direct `ECore.Create` raises in collections to specific exceptions.
- Add focused tests for each migrated module root.

Stage 3:

- Gradually move modules that use both `base` and `errors` to depend on only the unit they need.
- Prefer `nextpas.core.exception` only for root catch contracts, and `nextpas.core.errors` for taxonomy.

Stage 4:

- Stop documenting `ECore` as a framework root.
- Consider removal only after source compatibility policy allows it.

## First Stage Boundaries

Allowed files:

- `src/nextpas.core.exception.pas`
- `src/nextpas.core.base.pas`
- `src/nextpas.core.errors.pas`
- `src/nextpas.core.mem.error.pas`
- `tests/nextpas.core.exception/test_exception_root/*`
- `tests/nextpas.core.errors/test_errors/test_errors.lpr`
- `tests/nextpas.core.mem/test_exception_root/*` if needed for allocation-specific coverage
- `task_plan.md`, `findings.md`, `progress.md`
- this design and implementation plan

HTTP files are not part of the first-stage edit set unless a focused timeout identity test shows a source ambiguity that must be mechanically qualified. No HTTP protocol behavior, parser behavior, benchmark behavior, or request/response logic changes are allowed.

## Verification

Focused verification for stage 1:

- `make -C tests/nextpas.core.exception/test_exception_root clean test`
- `make -C tests/nextpas.core.errors/test_errors clean test`
- `make -C tests/nextpas.core.mem/test_exception_root clean test` if created
- `make -C tests/nextpas.core.http/test_http_server clean test` only if timeout identity touches HTTP test/source references

Every focused test must report zero failures and heaptrc `0 unfreed memory blocks`.

## Risks

- FPC type aliases for classes may not support every constructor compatibility shape. If this blocks OOM convergence, keep compatibility subclasses in the canonical lineage instead of forcing an unsafe alias.
- `SysUtils` also defines `EOutOfMemory`; unqualified names in units that use `SysUtils` may remain ambiguous. First-stage tests must include qualified references from both `base` and `errors`.
- Existing build logs under tests may mention old units. They are not source truth and should not be edited.
