# nextPas Text Operations Benchmark

**Date**: 2026-06-29
**Machine**: Linux 6.12.74, Intel Xeon E5-2696 v4 @ 2.20GHz, 44 threads
**Versions**: nextPas (FPC 3.3.1) -O3, Go 1.22, Rust 1.78 (criterion)

## Results

| Track              | Pascal     | Go        | Rust      | vs Go         | vs Rust       |
| ------------------ | ---------- | --------- | --------- | ------------- | ------------- |
| IntToStr/100k      | 9.01 ms    | 6.55 ms   | 6.96 ms   | 0.73x (Go)    | 0.77x         |
| Base64Enc/4KB      | 12.50 µs   | 5.66 µs   | 3.32 µs   | 0.45x (Go)    | 0.27x         |
| Base64Dec/5.3KB    | 16.01 µs   | 6.89 µs   | 3.66 µs   | 0.43x (Go)    | 0.23x         |
| **HexEnc/1KB**     | **1.26 µs**| 1.54 µs   | 5.04 µs   | **1.23x ✓**   | **4.01x ✓**   |
| **StrReplace/10KB**| **6.31 µs**| 11.02 µs  | 2.76 µs   | **1.75x ✓**   | 0.44x         |
| **JSON/Parse/404B**| **6.20 µs**| 17.86 µs  | 3.29 µs   | **2.88x ✓**   | 0.53x         |

**Score: vs Go 3W 0D 3L · vs Rust 2W 0D 4L**

## Analysis

### Wins (Pascal beats Go)

- **HexEnc/1KB**: 1.23x faster — pure-Pascal hex encode with lookup table, no alloc overhead
- **StrReplace/10KB**: 1.75x faster — FPC string replacement avoids Go's reflect-heavy ReplaceAll
- **JSON/Parse/404B**: 2.88x faster — nextpas.core.json SAX parser dominates Go's encoding/json reflect path

### Losses (Pascal slower)

- **IntToStr/100k**: Go 1.37x — FPC IntToStr does heap alloc per string; Go uses stack buffer via strconv.Append
- **Base64Enc/4KB**: Go 2.21x — Go's base64 uses hand-optimized assembly (AVX2); pure Pascal loop
- **Base64Dec/5.3KB**: Go 2.33x — same assembly advantage on decode side
- **Base64** (vs Rust): 3.7-4.4x — Rust base64 crate also uses SIMD

### Notes

- Base64 gap is unfixable without adding SIMD assembly to nextpas.core.encoding.base64
- IntToStr gap is a managed-type allocation issue; could be fixed with arena/string interning
- StrReplace win grows with string size; at 10KB Pascal's direct memory scan dominates
