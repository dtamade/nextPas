# nextpas.core.math Final API Migration Design

This document records stable design decisions for the final-state math migration.
Detailed behavior contracts live in `API.md`; this design record stays compact.

## Target

`nextpas.core.math.*` is the only official framework math API for scalar math,
trig, vectors, matrices, quaternions, transforms, easing, deterministic random,
and noise.

The final API rejects a long-term `Vectors` compatibility bridge.

## Design Inputs

- Current nextPas math, platform math, and SIMD sources under `core/src/`.
- Existing focused test projects under `core/tests/nextpas.core.math/`.
- Useful semantics from `fafafa.game` math sources, treated as input only.
- `core/docs/design-conventions.md` for module shape, facade rules, layering,
  and test layout.

## Non-Goals

- Do not work in dirty `main` or compiler worktrees from this lane.
- Do not restore `nextpas.core.math.ffi.pas`.
- Do not make `fafafa.game` `Vectors` names public nextPas API.
- Do not expose `VectorsSIMD` or backend-private SIMD details as math API.
- Do not run final performance claims before API, behavior, leak, and surface
  contracts are stable.

## Chosen Approach

Use final API, tests first, and framework-owned rewrites.

Rejected alternatives:

- Big-bang copy from `fafafa.game`: too much legacy ownership and dependency
  drift.
- Compatibility bridge first: creates two public math truths and delays API
  freeze.

## Module Ownership

Public modules:

- `nextpas.core.math`
- `nextpas.core.math.scalar`
- `nextpas.core.math.trig`
- `nextpas.core.math.vec`
- `nextpas.core.math.mat`
- `nextpas.core.math.quat`
- `nextpas.core.math.transform`
- `nextpas.core.math.easing`
- `nextpas.core.math.random`

Internal implementation modules:

- `nextpas.core.math.impl.scalar`
- `nextpas.core.math.impl.simd`

The root facade explicitly re-exports public types, constants, and functions.
Implementation detail modules are not consumer-facing namespaces.

## Platform And Trig Strategy

Trig must not depend on a public naked `external 'm'` route. The safe route is
validated by source-contract tests, current-host focused runtime tests, and host
matrix evidence.

Current status:

- Linux local gates are the repeatable local proof path.
- Win64 compile-only gates are forced compile truth, not Windows runtime/link
  proof.
- macOS and Windows host link/runtime smokes remain required before final
  cross-platform completion.

## SIMD Strategy

SIMD acceleration must consume `nextpas.core.simd` public facades only.

`nextpas.core.math.impl.simd` is an internal candidate seam. Public value-type
methods must stay scalar until profiling and focused behavior tests justify a
cutover. Benchmarks may record candidate evidence, but benchmark labels are not
public API commitments.

## Documentation Strategy

- `API.md` owns detailed public behavior contracts and command references.
- `README.md` owns onboarding, module list, and common gates.
- `GOAL_TREE.md` owns roadmap position, milestone gates, and active backlog.
- This file owns stable design choices and rejected alternatives.

This separation prevents control-plane documents from becoming duplicated API
specifications.

## Verification Strategy

Minimum slice closure:

- RED contract or behavior proof before implementation.
- Focused math gate for the changed surface.
- Heaptrc `0 unfreed memory blocks` for Pascal behavior/resource tests.
- `git diff --check`.
- `make hygiene`.
- Small commit with retained/excluded file boundaries.

Typical gates:

- `make -C core core-math-api-surface-smoke`
- `make -C core core-math-facade-local-smoke`
- `make -C core core-math-trig-local-smoke`
- `make -C core core-math-full-local-smoke`

## Remaining Design Work

- Hardening exact trig identity implementation paths.
- Deciding vector non-finite and signed-zero public contracts where not yet
  fully explicit.
- Adding SIMD source-contract guards before any public cutover.
- Obtaining macOS/Windows host trig link/runtime evidence.
- Executing the `fafafa.game` cutover without making legacy names public.
