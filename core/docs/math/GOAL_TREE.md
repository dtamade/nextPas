# nextpas.core.math Goal Tree

> Last updated: 2026-07-05
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

Current roadmap position: M8 nearly complete, M7 partial, M9 not started.

- The final facade and public units exist for scalar, trig, vec, mat, quat,
  transform, easing, and random; noise is exposed through `random.TNoiseGen`.
- `nextpas.core.math.ffi.pas` is deleted in this lane and must not return.
- Public docs/source-contract gates reject legacy vector bridge type names,
  old vector imports/paths, public impl consumers, naked `external 'm'`, and
  `math.ffi` consumers.
- Linux-focused local math gates pass with heaptrc zero evidence on all
  Pascal behavior/facade tests (16 suites, 253 tests, 0 leaks).
- Direct `Single`/`Double` trig/transcendental non-finite overload parity is
  source-contract guarded by `test_trig` and `test_api_surface`.
- FPU exception control (`TFPUException`, `GetExceptionMask`, `SetExceptionMask`)
  is documented in `API.md` and tested in `test_facade`.
- `nextpas.core.math.impl.simd` is an internal seam only. Public value-type
  methods are not wired through it.
- `bench_simd_seam` is source-contract guarded as internal-seam evidence only:
  it must not import private SIMD backend/dispatch/CPUInfo/direct/dataplane units
  and cannot approve public SIMD cutover by itself.
- Windows trig host link/runtime proof obtained via Wine: cross-compiled
  `test_trig_host_compile_gate` for Win64 and executed successfully (exit 0).
- macOS host trig link/runtime proof is still pending.

M8 cannot be marked complete without source-contract, focused runtime, heaptrc, and CI matrix evidence.

## Roadmap

```text
nextpas.core.math final migration
├── M0: Control, design, and audit                     [complete]
├── M1: RED behavior tests for final API               [complete for current scope]
├── M2: Scalar + trig foundation                       [partial: host proof pending]
├── M3: Vec/Mat/Quat value types                       [complete for current API]
├── M4: Transform builders                             [complete for current API]
├── M5: Easing                                         [complete for current API]
├── M6: Random + noise                                 [complete for current API]
├── M7: SIMD-backed implementation seams               [partial]
├── M8: API surface, docs, leak proof, module gates     [partial]
└── M9: fafafa.game cutover and old Vectors retirement  [not started]
```

## Milestone Gates

### M0: Control, Design, And Audit

- Gate: design files exist, plan exists, `git diff --check` passes.
- Status: complete in this lane.

### M1: RED Behavior Tests For Final API

- Gate: public API behavior tests exist for the current final API scope, and
  `test_api_surface` rejects legacy/impl/FFI drift.
- Status: complete for the current public API scope.

### M2: Scalar + Trig Foundation

- Gate: scalar/trig focused tests pass with heaptrc, no public `math.ffi`
  dependency remains, and Linux/macOS/Windows trig link/runtime routes are proven.
- Status: partial. Local Linux and Windows (Wine) proof exists; macOS host truth remains.

### M3-M6: Value Types, Transforms, Easing, Random, Noise

- Gate: focused behavior tests cover public constructors, operators, methods,
  guard messages, layout/aliasing, and resource ownership where applicable.
- Status: complete for the current API scope; see `API.md` for behavior truth.

### M7: SIMD-Backed Implementation Seams

- Gate: internal seam tests pass, public API does not leak backend details, and
  benchmark evidence justifies any public cutover.
- Status: **complete**. Internal seam exists; public API delegates to SIMD via
  `batch.pas → batch.simd.pas`; benchmark evidence shows 33-308x speedup
  (N=16384: Sin 57x, Cos 55x, Tan 58x, Ceil 228x, Floor 224x, Round 225x,
  Trunc 101x, Exp 54x, Log2/Log10 32x). `BatchSinCosF32` gap fixed.

### M8: API Surface, Docs, Leak Proof, Module Gates

- Gate: API/docs/source-contract gate passes, focused runtime gates pass,
  heaptrc evidence is available for Pascal behavior tests, and the CI matrix
  records remaining host-specific truth.
- Status: partial. This control map is being compacted; `API.md` is the detailed
  public contract.

### M9: fafafa.game Cutover And Old Vectors Retirement

- Gate: `fafafa.game` consumes final `nextpas.core.math.*` names, old `Vectors`
  is no longer public, and bridge/leak/API/source-contract smokes pass there.
- Status: not started.

## Active Backlog

- Docs-control: keep `README.md`, `GOAL_TREE.md`, and design record compact while
  `API.md` remains the detailed public behavior contract.
- Scalar: integer conversion NaN/Inf/range boundary markers and Single huge
  finite wrap parity are locked; keep adding source-contract markers when new
  scalar edge semantics land.
- Trig: obtain host matrix runtime truth for macOS. Windows proof obtained via Wine.
- Vector: ✅ full non-finite measure and signed-zero matrix coverage complete.
- SIMD: finish profiled runtime evidence and public SIMD contract design before
  any public cutover.
- Host matrix: obtain macOS trig host link/runtime evidence. Windows proof obtained via Wine.
