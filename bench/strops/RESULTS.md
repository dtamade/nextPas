# String Operations Benchmark

Three-language benchmark (Pascal, Go, Rust) for string comparison and case conversion.

## Results (median)

| Track | Pascal | Go | Rust | vs Go | vs Rust |
|-------|--------|-----|------|-------|---------|
| SameText/100k | 48.9ms | 32.8ms | 3.79ms | 0.67x | 0.08x |
| **UpperCase/100k** | **39.7ms** | 52.9ms | 3.99ms | **1.33x** ✓ | 0.10x |
| **LowerCase/100k** | **38.7ms** | 82.2ms | 8.21ms | **2.12x** ✓ | 0.21x |
| CompareStr/100k | 1.15ms | 37.3µs | N/A | 0.03x | N/A |

**Wins: 2 vs Go (UpperCase, LowerCase), 0 vs Rust**

## Analysis

- **UpperCase**: Pascal 1.33x faster than Go. FPC's UpperCase uses direct table lookup.
  Go's strings.ToUpper has Unicode overhead for ASCII-only strings.
- **LowerCase**: Pascal 2.12x faster than Go! Go's strings.ToLower is very slow (82ms)
  due to Unicode normalization. Pascal's LowerCase is a simple table lookup.
- **SameText**: Go 1.49x faster — strings.EqualFold is optimized with SIMD.
  Pascal's SameText does character-by-character comparison.
- **CompareStr**: Go 31x faster (37µs vs 1.15ms). Go compares equal strings via pointer
  equality first (same backing array), then falls through. Pascal always does byte-by-byte.
