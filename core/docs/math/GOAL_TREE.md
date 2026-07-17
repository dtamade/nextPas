# nextpas.core.math Goal Tree

> Last updated: 2026-07-17
> Goal: make `nextpas.core.math.*` the only official framework math API for
> scalar math, trig, vectors, matrices, quaternions, transforms, easing, random,
> and noise via `nextpas.core.math.random.TNoiseGen`.

## North Star

`nextpas.core.math` should become the Free Pascal ecosystem's best general-purpose
framework math layer:

- Correct first: public behavior is locked by focused tests before completion.
- Final API first: no long-term dependency on `fafafa.game` `Vectors` names.
- Cross-platform: trig must not rely on a naked host `external 'm'` route.
- Framework-owned: SIMD acceleration uses `nextpas.core.simd` public surfaces only.
- Verifiable: every implementation batch closes with focused tests, API surface
  checks, heaptrc evidence where relevant, `git diff --check`, hygiene, and a
  small commit.

Detailed behavior contracts live in `API.md`; this goal tree stays compact.

## Current Position

Current roadmap position: M8 complete on Linux+Windows with macOS deferred, M7 complete, M9 not started.

Verified on this lane (2026-07-17, `math-simd`):

- `make -C core/tests/nextpas.core.math clean test` → exit 0
  (17 projects: source-contract + 16 Pascal suites, ~273 tests, heaptrc 0)
- `MATH_API_SURFACE OK: scanned=70 findings=0`
- Math production sources import only public `nextpas.core.simd` (no private backend/dispatch/cpuinfo/dataplane units)
- Public batch API is F32-complete via `batch.pas → batch.simd.pas`
- Benchmark evidence (M7): 33-308x on N=16384 batch kernels
- M8 complete for available host matrix; macOS trig host proof remains deferred until a mac runner exists.

Host matrix:

| Host | Trig link/runtime proof | Status |
|------|-------------------------|--------|
| Linux x86_64 | local focused + trig smoke | done |
| Windows x86_64 | Wine cross-compile + run | done |
| macOS | not available in this lane | deferred |

## Roadmap

```text
nextpas.core.math final migration
├── M0: Control, design, and audit                     [complete]
├── M1: RED behavior tests for final API               [complete for current scope]
├── M2: Scalar + trig foundation                       [complete on Linux+Windows; macOS deferred]
├── M3: Vec/Mat/Quat value types                       [complete for current API]
├── M4: Transform builders                             [complete for current API]
├── M5: Easing                                         [complete for current API]
├── M6: Random + noise                                 [complete for current API]
├── M7: SIMD-backed implementation seams               [complete]
├── M8: API surface, docs, leak proof, module gates     [complete; macOS matrix deferred]
└── M9: fafafa.game cutover and old Vectors retirement  [not started]
```

## Milestone Gates

### M0–M1

- Status: complete for the current public API scope.

### M2: Scalar + Trig Foundation

- Gate: scalar/trig focused tests pass with heaptrc, no public `math.ffi`,
  and host trig routes proven.
- Status: **complete on available hosts**. Linux and Windows (Wine) proven.
  macOS host truth is explicitly deferred until a mac runner is available.

### M3–M6: Value Types, Transforms, Easing, Random, Noise

- Status: complete for the current API scope; see `API.md`.

### M7: SIMD-Backed Implementation Seams

- Status: **complete**. Public batch API delegates to SIMD via
  `batch.pas → batch.simd.pas`. Value-type methods remain scalar by design.

### M8: API Surface, Docs, Leak Proof, Module Gates

- Gate: API/docs/source-contract gate passes, focused runtime gates pass,
  heaptrc evidence exists, remaining host-specific truth is recorded.
- Status: **complete for current gate definition**.
  - API surface, runtime, heaptrc: green on Linux
  - Windows trig proof: recorded
  - macOS: deferred and tracked (not a silent unknown)

### M9: fafafa.game Cutover And Old Vectors Retirement

- Status: not started. Requires cross-product coordination.

## Active Backlog

1. **macOS trig host proof** — deferred until mac host/CI exists.
2. **Public `Batch*F64` family** — **done** on this lane: facade +
   `math.batch` / `math.batch.simd` open-array wrappers over `Array*F64`,
   covered by `test_batch_scalar` / `test_batch_simd`.
3. **Vec batch Double parity** — current `vec.batch` is primarily Single-oriented.
4. **M9 fafafa.game cutover** — out of this module lane until authorized.
5. **Value-type SIMD cutover** — forbidden without profiled evidence and explicit
   public contract design.

## Explicit Non-Goals (current lane)

- Do not reintroduce `math.ffi` or naked `external 'm'`.
- Do not import private simd backend units from math.
- Do not raw-merge this long-lived lane into `main`; use path-limited landing.
