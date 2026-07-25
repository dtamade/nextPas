# nextpas.core.math Goal Tree

> Last updated: 2026-07-26
> Goal: make `nextpas.core.math.*` the only official framework math API for
> scalar math, trig, vectors, matrices, quaternions, transforms, easing, random,
> and noise via `nextpas.core.math.random.TNoiseGen`.
> Maintenance: [`../math-simd/MAINTENANCE.md`](../math-simd/MAINTENANCE.md).

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

**math residual (M-C1 / M-V1 / M-V2): closed** on this lane (2026-07-17).
Quality wave **Q1/Q2: closed**; queue **CURRENT=IDLE** in
[`../math-simd/GOAL_QUEUE.md`](../math-simd/GOAL_QUEUE.md) — no new in-lane math
milestones.

Verified (2026-07-26 M0 maintenance re-verify, `math-simd` @ main `e9d92ab5b`):

- `make -C core/tests/nextpas.core.math clean test` → exit 0
  (Pascal suites **313** passed / 0 failed; heaptrc 0 unfreed)
- `MATH_API_SURFACE OK: scanned=71 findings=0`
- Production math imports only public `nextpas.core.simd` (no private backends)
- Public batch: scalar F32/F64 + `vec.batch` F32 core + **Double minimal parity (M-V1)**
- M8 complete for available host matrix; macOS trig host proof remains deferred until a mac runner exists.
- Shared lane simd focused **1762**/0；debt inventory in `MAINTENANCE.md`.

### Residual archive (closed)

| ID | What | Status |
|----|------|--------|
| M-C1 | Consumer smoke after NEON BatchF32 leaves | done — full math clean test green |
| M-V1 | `vec.batch` Double core ops | done — Dot/Normalize/Transform/Lerp/Clamp |
| M-V2 | Residual docs + lane mode cleanup | **done** (this file) |

### Host matrix

| Host | Trig link/runtime proof | Status |
|------|-------------------------|--------|
| Linux x86_64 | local focused + trig smoke | done |
| Windows x86_64 | Wine cross-compile + run | done |
| macOS | not available in this lane | **blocked** (see below) |

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
└── M9: fafafa.game cutover and old Vectors retirement  [blocked — product auth]
```

## Milestone Gates (summary)

- **M0–M1**: complete for current public API scope.
- **M2**: complete on available hosts (Linux + Windows/Wine). macOS deferred.
- **M3–M6**: complete for current API; see `API.md`.
- **M7**: complete. Public batch → public simd only. Value-type methods stay scalar.
- **M8**: complete for current gate definition on Linux+Windows; macOS deferred.
- **M9**: **not started / blocked** until product authorization + cross-lane plan.

## Lane mode

**math-in-lane residual closed.** Mode is now:

- **consumer-of-simd** (keep public-only simd boundary)
- **quality / pointer hygiene** via GOAL_QUEUE Wave 3 (`Q1` → `Q2` → `IDLE`)

Do not invent new math milestones in chat. Do not auto-start Wave 4 walls.

## Backlog classification

### In-lane residual (math code)

*None.* M-C1 / M-V1 / M-V2 closed.

### In-lane quality (shared queue, not math feature work)

1. ~~**Q1** — pointer freshness~~ **done**
2. ~~**Q2** — math↔simd linkage table~~ **done** (GOAL_QUEUE § linkage)

### Explicitly blocked (out of default queue)

| Item | BLOCKED_UNTIL |
|------|----------------|
| **macOS trig host proof** | macOS runner / CI host |
| **M9 fafafa.game cutover** | product authorization + cross-lane plan |
| **Value-type SIMD cutover** | profiled evidence + public contract design |

### Math lane-complete checklist

- [x] M0–M8 on available hosts
- [x] Public batch F32/F64 via public simd
- [x] `vec.batch` Double minimal parity (M-V1)
- [x] Consumer smoke after Batch leaves (M-C1)
- [x] Residual docs / backlog classification (M-V2)
- [x] M9 / macOS explicitly blocked (not silent unknowns)
- [x] Q1 pointer freshness
- [x] Q2 math↔simd linkage

## Explicit Non-Goals

- Do not reintroduce `math.ffi` or naked `external 'm'`.
- Do not import private simd backend units from math.
- Do not raw-merge this long-lived lane into `main`; use path-limited landing.
- Do not start M9 or macOS goals without lifting `BLOCKED_UNTIL`.

## Goal entry

Open [`../math-simd/GOAL_QUEUE.md`](../math-simd/GOAL_QUEUE.md) and execute **CURRENT** only.
Happy path (archive): `… → M-C1 ✅ → … → M-V1 ✅ → M-V2 ✅ → Q1 ✅ → Q2 ✅ → IDLE`.
