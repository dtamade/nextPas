# Regex Benchmark Results (2026-06-01, post-SIMD optimization)

Input: 10,000 bytes of text with embedded patterns.

## Results (ns/op, lower is better)

| Scenario | nextpas | Go | Rust | vs Go | vs Rust |
|----------|--------:|---:|-----:|------:|--------:|
| Literal IsMatch | 886 | 3,907 | 3,970 | **4.4x faster** | **4.5x faster** |
| Digit Find (\d+) | 7,862 | 54,340 | 5,425 | **6.9x faster** | 1.4x slower |
| Alternation (4 alts) | 4,787 | 463,531 | 913 | **96.8x faster** | 5.2x slower |
| Compile (date pattern) | 2,994 | 11,065 | 572,892 | **3.7x faster** | **191x faster** |
| IsFullMatch (^[a-z]+$) | 24,752 | 54,971 | 5,260 | **2.2x faster** | 4.7x slower |
| Case-Insensitive (?i) | 6,972 | 240,867 | 1,749 | **34.5x faster** | 4.0x slower |
| Capture Groups (date) | 24,392 | 275,278 | 1,278 | **11.3x faster** | 19.1x slower |
| FindAll (\w+) | 117,098 | 402,820 | 86,288 | **3.4x faster** | 1.4x slower |
| ReplaceAll (\d+->NUM) | 47,185 | 339,918 | 29,641 | **7.2x faster** | 1.6x slower |
| Split (\s+) | 44,337 | — | — | — | — |
| FindIter (\w+) | 1,707,997 | — | — | — | — |
| Large 100KB literal | 109,757 | — | — | — | — |

## Analysis

### vs Go regexp (all scenarios faster)
- **Geometric mean: ~10x faster than Go**
- Literal IsMatch: 4.4x faster (AVX2 ScanFindSubstring)
- Alternation: 97x faster (Teddy SSSE3 multi-pattern)
- Case-insensitive: 35x faster (SIMD case-fold literal scan)
- Capture groups: 11x faster (NFA with direct slot tracking)

### vs Rust regex
- **Compile: 191x faster** (Rust regex does heavy DFA precompilation)
- **Literal IsMatch: 4.5x faster** (AVX2 first+last byte scan beats Rust's memchr on this input)
- Digit Find / FindAll / ReplaceAll: within 1.4-1.6x of Rust (competitive)
- Alternation: 5.2x slower (Rust's Teddy is more advanced — 8-pattern, 256-bit)
- Capture Groups: 19x slower (Rust uses lazy DFA + NFA hybrid)

### Key Improvements Since Last Measurement
1. **Literal IsMatch: 3,022 → 886 ns (3.4x faster)** — AVX2 ScanFindSubstring
2. **Alternation: 23,145 → 4,787 ns (4.8x faster)** — Teddy SSSE3 integration
3. **Now FASTER than Rust on literal search** (886 vs 3,970 ns)

### Remaining Optimization Targets
1. Capture groups: lazy DFA for non-capturing prefix
2. IsFullMatch: DFA-only path for simple patterns
3. Alternation: AVX2 Teddy (32-byte buckets)

## Environment
- CPU: x86_64 with SSE2/SSSE3/AVX2
- FPC: 3.3.1 trunk, -O2
- Go: 1.22+
- Rust: regex 1.10+, --release
