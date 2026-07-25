# Numeric error budget (F-014)

> Status: near-parity policy (not libm ULP certification)  
> Last updated: 2026-07-26

## Policy

| Surface | Error policy | Evidence |
|---------|--------------|----------|
| math.scalar / math.trig (System intrinsic export) | Host FPC/nextPas intrinsic semantics | focused math suites |
| math Batch* via simd Array* | Backend parity to scalar baseline | batch_simd / array correctness |
| NEON transcendentals (Sin/Exp/Cos/Log sample) | **near-parity** vs scalar, not bit-equal | `design-c5-transcendentals.md`, near-parity tests |
| simd.mathutil poly (Sin/Ln/ArcTan2 F32) | documented poly accuracy (~1e-7 rel class) | unit tests + mathutil comments |

## Non-goals

- Full libm ULP tables across all backends
- Claiming bit-identical x86 vs NEON transcendental leaves

## Consumer guidance

Prefer **math** public API for application correctness. Use **simd Array*** only when
you own length/alignment and accept near-parity on experimental NEON paths.
