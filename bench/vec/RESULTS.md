# Vec / Array Operations Benchmark

Three-language benchmark (Pascal, Go, Rust) for raw array operations.

## Tracks

| Track | Description |
|-------|-------------|
| Array/Fill/1M | FillChar 1M Int64 |
| Array/Sum/1M | Sum 1M Int64 via pointer |
| Array/Reverse/1M | Reverse 1M Int64 array in-place |
| Array/Scan/100k | 100k × 100k full scan (O(n²)) |

## Results (single run, 3 rounds)

| Track | Pascal | Go | Rust | vs Go | vs Rust |
|-------|--------|-----|------|-------|---------|
| Array/Fill/1M | 396µs | 372µs | 792µs | 0.94x | 2.00x ✓ |
| Array/Sum/1M | 791µs | 384µs | 312µs | 0.49x | 0.39x |
| Array/Reverse/1M | 711µs | 815µs | 486µs | **1.15x** ✓ | 0.68x |
| Array/Scan/100k | 38.6ms | 21.7ms | 33.1ms | 0.56x | 0.86x |

**Wins: 1 vs Go (Reverse), 1 vs Rust (Fill)**

## Analysis

- **Fill**: Pascal and Go are close (FPC FillChar vs Go zero-init). Rust slower because criterion
  allocates per-iteration.
- **Sum**: Go and Rust auto-vectorize simple loops. FPC -O3 does not auto-vectorize, leaving
  ~2x gap against Go, ~2.5x against Rust.
- **Reverse**: Pascal wins vs Go (pointer swap vs Go bounds-checked swap). Rust fastest (memcpy).
- **Scan**: O(n²) cache-thrashing workload. Go's simpler inner loop + auto-vectorization wins.

## Conclusion

Raw array benchmarks heavily favor compilers with auto-vectorization (Go, Rust, LLVM).
Pascal's advantage is in abstractions with zero overhead (record methods, interfaces),
not in tight numeric loops against auto-vectorizing compilers.

This track scores 1W vs Go — focus optimization effort elsewhere.
