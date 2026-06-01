# nextpas.core.toml Benchmark Results

Date: 2026-06-01
Platform: Linux x86_64, FPC 3.3.1 trunk, -O2
Machine: same host for all measurements

## Parse Performance

| Benchmark | nextpas (ns/op) | Go BurntSushi/toml (ns/op) | Rust toml (ns/op) |
|-----------|----------------:|---------------------------:|------------------:|
| small (216B, 10 keys) | 3,139 | 56,492 | 14,761 |
| medium (1.6KB, ~50 keys) | 16,843 | 428,586 | 120,960 |
| large (12KB, ~700 keys) | 231,982 | 5,257,958 | 1,622,621 |

## Ratios

| Comparison | small | medium | large |
|------------|------:|-------:|------:|
| nextpas vs Go BurntSushi/toml | **18.0x faster** | **25.4x faster** | **22.7x faster** |
| nextpas vs Rust toml crate | **4.7x faster** | **7.2x faster** | **7.0x faster** |

## Additional Benchmarks (nextpas only)

| Benchmark | ns/op | ops/s |
|-----------|------:|------:|
| string-heavy (100 strings, 7.5KB) | 43,341 | 23,073 |
| long-string (10KB value + escaped) | 14,017 | 71,343 |
| facade (parse + interface wrapper) | 3,042 | 328,737 |
| access (3 key lookups) | 334 | 2,994,613 |
| arena allocator (medium) | 16,591 | 60,273 |
| arena allocator (large) | 243,683 | 4,104 |

## Throughput

| Size | nextpas MB/s | Go MB/s | Rust MB/s |
|------|-------------:|--------:|----------:|
| small (216B) | 68.8 | 3.8 | 14.6 |
| medium (1.6KB) | 94.6 | 3.9 | 13.7 |
| large (12KB) | 53.1 | 2.3 | 7.6 |

## Analysis

- nextpas TOML parser is 18-25x faster than Go's BurntSushi/toml (the standard Go library)
- nextpas is 4.7-7.2x faster than Rust's toml crate (the standard Rust library)
- Peak throughput ~95 MB/s on medium documents
- Key access is sub-microsecond (334 ns for 3 lookups)
- Arena allocator shows no overhead vs default allocator
- String-heavy workloads maintain good performance (175 KB/s per string)

## Why nextpas is faster

1. SIMD structural scanner (SSE2 vectorized whitespace/delimiter detection)
2. Zero-copy string references for unescaped values
3. Arena-based node allocation (single large buffer, no per-node malloc)
4. Lazy hash index for O(1) key lookup on large tables
5. No reflection/type-system overhead (direct DOM construction)
