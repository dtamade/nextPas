# Float64 Operations Benchmark

**Date**: 2026-07-01
**Machine**: Linux x86_64, Intel Xeon E5-2696 v4 @ 2.20GHz, 44 threads
**FPC**: 3.3.1 -O3 -CX -XX -Xs -dRELEASE
**Go**: 1.22

## Results (median)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **EuclideanDist/10K×10K** | **110599302** | 149000000 | **1.35x** ✓ |
| **WeightedSum/10K×10K** | **128268899** | 190700000 | **1.49x** ✓ |
| ClampNormalize/10K×10K | 293651184 | 301000000 | 1.03x — |
| **FMAccum/10K×10K** | **111690552** | 189400000 | **1.70x** ✓ |
| **DAXPY/10K×10K** | **167988593** | 186400000 | **1.11x** ✓ |

**4W 1D vs Go** — FPC tighter loop codegen vs Go bounds check + write barrier on float64 arrays

## Analysis

- FMAccum 1.70x: `sum += a[i]*b[i] + c[i]` — FPC generates tighter accumulation loop
- WeightedSum 1.49x: combined read + write + accumulate
- EuclideanDist 1.35x: squared difference accumulation
- DAXPY 1.11x: `c[i] = α*a[i] + b[i]` — more work per element, smaller advantage
- ClampNormalize 1.03x: two-pass algorithm, complex control flow
