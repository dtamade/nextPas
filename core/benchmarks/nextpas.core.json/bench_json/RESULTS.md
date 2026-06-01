# nextpas.core.json Benchmark Results

Date: 2026-06-01 (post-optimization)
Platform: Linux x86_64, FPC 3.3.1 trunk, -O2
Machine: same host for all measurements

## Parse Performance (facade API — includes class creation overhead)

| Benchmark | nextpas (ns/op) | FPC fpjson (ns/op) | Go encoding/json (ns/op) | Rust serde_json (ns/op) | Rust simd-json (ns/op) |
|-----------|----------------:|-------------------:|-------------------------:|------------------------:|-----------------------:|
| small (52B) | 1,402 | 2,818 | 1,956 | 603 | 613 |
| medium (250B) | 4,057 | 10,844 | 14,463 | 2,622 | 1,932 |
| large (5.4KB) | 103,065 | 252,199 | 300,514 | — | — |

## Parse Performance (raw parser — no facade overhead)

| Benchmark | nextpas raw (ns/op) | Rust serde_json (ns/op) | Ratio |
|-----------|--------------------:|------------------------:|------:|
| small (52B) | 725 | 603 | 1.20x slower |
| medium (250B) | 2,764 | 2,622 | 1.05x slower |

## Stringify Performance

| Benchmark | nextpas (ns/op) | FPC fpjson (ns/op) | Go encoding/json (ns/op) | Rust serde_json (ns/op) |
|-----------|----------------:|-------------------:|-------------------------:|------------------------:|
| medium (250B) | 590 | 8,089 | 15,483 | 632 |

## Access Performance

| Benchmark | nextpas (ns/op) | FPC fpjson (ns/op) |
|-----------|----------------:|-------------------:|
| ObjectGet+AsInt | 55 | 175 |

## Ratios

| Comparison | Parse (small) | Parse (medium) | Stringify (medium) |
|------------|:-------------:|:--------------:|:------------------:|
| nextpas vs FPC fpjson | 2.0x faster | 2.7x faster | 13.7x faster |
| nextpas vs Go encoding/json | 1.4x faster | 3.6x faster | 26.2x faster |
| nextpas raw vs Rust serde | 1.20x slower | **1.05x slower** | **1.07x faster** |

## Analysis

- nextpas is 2-14x faster than FPC fpjson, 1.4-26x faster than Go encoding/json
- Raw parser (no class overhead) nearly matches Rust serde_json on medium inputs
- Stringify now BEATS Rust serde_json (590 vs 632 ns/op)
- Facade overhead (~600ns for class creation) dominates on small inputs
- Access (ObjectGet) is 3.2x faster than fpjson due to lazy hash index
- Go encoding/json stringify is extremely slow (14x slower than nextpas)

## Optimizations Applied

1. String arena — 4KB pre-allocated buffer, zero heap calls for most strings
2. Merged SIMD scan — control char + backslash check in single OR operation
3. Scanner no-escape fast path — skip OddBackslashEscaped when no backslash
4. Scanner in-string skip — skip 6x VecCmpEq when entire chunk is inside string
5. Combined allocation — nodes + arena in single malloc (Init overhead -33%)
6. Direct-write stringify — KeyClean/StrClean bypass AppendChar via Tail pointer
