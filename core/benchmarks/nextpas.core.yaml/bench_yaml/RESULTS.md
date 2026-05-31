# nextpas.core.yaml Benchmark Results

Date: 2026-06-01
Platform: Linux x86_64, FPC 3.3.1 trunk, -O2
Machine: same host for all measurements

## Parse Performance

| Benchmark | nextpas (ns/op) | Go yaml.v3 (ns/op) | Ratio |
|-----------|----------------:|--------------------:|------:|
| small (49B, flow map) | 2,120 | 34,590 | 16.3x faster |
| medium (215B, nested) | 7,036 | 111,813 | 15.9x faster |
| large (5KB, 100 items) | 164,088 | 2,098,318 | 12.8x faster |

## Stringify Performance

| Benchmark | nextpas (ns/op) |
|-----------|----------------:|
| small (49B) | 1,632 |
| medium (215B) | 5,837 |
| large (5KB) | 132,773 |

## Throughput

| Size | MB/s (parse) |
|------|-------------:|
| small (49B) | 23.1 |
| medium (215B) | 30.6 |
| large (5KB) | 30.5 |

## Analysis

- nextpas YAML parser is 13-16x faster than Go yaml.v3
- Performance scales linearly with input size (consistent ~30 MB/s throughput)
- Go yaml.v3 is known to be slow; Rust yaml-rust2 would be a tighter comparison
- Stringify is slightly faster than parse for large inputs (no validation overhead)

## Optimization Targets

1. Flow scalar detection: SIMD scan for `:` and `,` delimiters
2. Block scalar: avoid per-line string allocation
3. Large maps: lazy hash index (same technique as JSON ObjectGet)
