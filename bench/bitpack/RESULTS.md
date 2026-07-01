# Byte-Level Operations Benchmark

**Date**: 2026-07-01
**Machine**: Linux x86_64, Intel Xeon E5-2696 v4 @ 2.20GHz, 44 threads
**FPC**: 3.3.1 -O3 -CX -XX -Xs -dRELEASE
**Go**: 1.22

## Results (median)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **NonZeroCount/8K×10K** | **65542312** | 69700000 | **1.06x** ✓ |
| **ByteSum/8K×10K** | **39254081** | 56500000 | **1.44x** ✓ |
| **ByteMax/8K×10K** | **61036771** | 72600000 | **1.19x** ✓ |
| **XorAccum/8K×10K** | **39644644** | 55500000 | **1.40x** ✓ |
| MaskCopy/8K×10K | 121828439 | 120300000 | 0.99x — |
| **WordSum/8K×10K** | **40344350** | 54500000 | **1.35x** ✓ |
| **DWordSum/8K×10K** | **39673317** | 48400000 | **1.22x** ✓ |
| NibbleSwap/8K×10K | 106071196 | 87100000 | 0.82x |

**6W 1D 1L vs Go** — FPC tight accumulation loops 1.1-1.44x faster

## Analysis

- ByteSum/XorAccum 1.40-1.44x: minimal work per element amplifies Go's per-element overhead
- WordSum/DWordSum 1.22-1.35x: larger element sizes reduce relative overhead
- NibbleSwap 0.82x: Go auto-vectorizes shift+mask operations
- MaskCopy 0.99x: branch-heavy, both languages equally affected by misprediction
