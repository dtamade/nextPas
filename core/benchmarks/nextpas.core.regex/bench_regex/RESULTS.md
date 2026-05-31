# Regex Benchmark Results (2026-05-31)

Input: 10,000 bytes of text with embedded patterns.

## Results (ns/op, lower is better)

| Scenario | nextpas | Go | Rust | vs Go | vs Rust |
|----------|--------:|---:|-----:|------:|--------:|
| Literal IsMatch | 3,022 | 4,491 | 359 | **1.49x faster** | 0.12x (8.4x slower) |
| Digit Find (\d+) | 7,747 | 56,308 | 5,994 | **7.27x faster** | 0.77x (1.3x slower) |
| Alternation (4 alts) | 23,145 | 459,154 | 1,002 | **19.8x faster** | 0.04x (23x slower) |
| Compile (date pattern) | 2,949 | 10,441 | 585,877 | **3.54x faster** | **199x faster** |
| IsFullMatch (^[a-z]+$) | 23,839 | 54,436 | 5,220 | **2.28x faster** | 0.22x (4.6x slower) |
| Case-Insensitive (?i) | 6,022 | 194,807 | 1,488 | **32.3x faster** | 0.25x (4x slower) |
| Capture Groups (date) | 23,565 | 241,764 | 737 | **10.3x faster** | 0.03x (32x slower) |
| FindAll (\w+) | 115,746 | 507,491 | 86,862 | **4.38x faster** | 0.75x (1.3x slower) |
| ReplaceAll (\d+->NUM) | 46,180 | 392,281 | 27,358 | **8.50x faster** | 0.59x (1.7x slower) |
| Split (\s+) | 43,647 | — | — | — | — |
| FindIter (\w+) | 1,705,418 | — | — | — | — |
| Large 100KB literal | 60,209 | — | — | — | — |

## Analysis

### vs Go regexp (all scenarios faster)
- **Geometric mean: ~7x faster than Go**
- Compile: 3.5x faster (lightweight Thompson NFA vs Go's full RE2)
- Case-insensitive: 32x faster (SIMD case-fold literal scan)
- Alternation: 20x faster (DFA + literal alternation fast path)
- Capture groups: 10x faster (NFA with direct slot tracking)

### vs Rust regex
- **Compile: 199x faster** (Rust regex does heavy DFA precompilation)
- Digit Find / FindAll: within 1.3x of Rust (competitive)
- Literal IsMatch: 8.4x slower (Rust uses Aho-Corasick + SIMD memchr)
- Alternation: 23x slower (Rust uses Teddy SIMD multi-pattern)
- Capture Groups: 32x slower (Rust uses lazy DFA + NFA hybrid)

### Key Takeaways
1. **Compilation is our strongest point** — 199x faster than Rust, 3.5x faster than Go
2. **Matching is competitive with Go** — consistently 2-32x faster
3. **Gap with Rust is in SIMD-heavy paths** — Rust's Teddy/memchr gives it literal search advantage
4. **Next optimization targets:** SIMD literal scan (close the 8x gap), Teddy multi-pattern

## Environment
- CPU: x86_64
- FPC: 3.3.1 trunk, -O2
- Go: 1.22+
- Rust: regex 1.10+, --release
