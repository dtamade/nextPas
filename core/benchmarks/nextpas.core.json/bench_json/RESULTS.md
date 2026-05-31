# nextpas.core.json Benchmark Results

Date: 2026-06-01
Platform: Linux x86_64, FPC 3.3.1 trunk, -O2
Machine: same host for all measurements

## Parse Performance

| Benchmark | nextpas (ns/op) | FPC fpjson (ns/op) | Go encoding/json (ns/op) | Rust serde_json (ns/op) | Rust simd-json (ns/op) |
|-----------|----------------:|-------------------:|-------------------------:|------------------------:|-----------------------:|
| small (52B) | 1,435 | 2,661 | 1,956 | 603 | 613 |
| medium (250B) | 4,321 | 9,906 | 14,463 | 2,622 | 1,932 |
| large (5.4KB) | 111,207 | 253,547 | 300,514 | — | — |

## Stringify Performance

| Benchmark | nextpas (ns/op) | FPC fpjson (ns/op) | Go encoding/json (ns/op) | Rust serde_json (ns/op) |
|-----------|----------------:|-------------------:|-------------------------:|------------------------:|
| medium (250B) | 1,320 | 7,914 | 15,483 | 641 |
| large (5.4KB) | — | — | 379,565 | — |

## Access Performance

| Benchmark | nextpas (ns/op) | FPC fpjson (ns/op) |
|-----------|----------------:|-------------------:|
| ObjectGet+AsInt | 75 | 158 |

## Ratios

| Comparison | Parse (small) | Parse (medium) | Stringify (medium) |
|------------|:-------------:|:--------------:|:------------------:|
| nextpas vs FPC fpjson | 1.9x faster | 2.3x faster | 6.0x faster |
| nextpas vs Go encoding/json | 1.4x faster | 3.3x faster | 11.7x faster |
| nextpas vs Rust serde | 2.4x slower | 1.6x slower | 2.1x slower |
| nextpas vs Rust simd-json | 2.3x slower | 2.2x slower | — |

## Analysis

- nextpas is 2-6x faster than FPC fpjson, 1.4-3.3x faster than Go encoding/json
- Rust serde_json is ~2x faster on parse (typed deserialization vs DOM), ~2x on stringify
- simd-json advantage is minimal over serde for small inputs on this machine
- Access (ObjectGet) is 2x faster than fpjson due to lazy hash index
- Go encoding/json stringify is extremely slow (15x slower than nextpas)

## Optimization Targets

1. Parse hot path: string copy reduction (zero-copy for unescaped strings)
2. Stringify: pre-sized buffer allocation based on input size estimate
3. Large document: SIMD whitespace skip already active, consider SIMD string scan
