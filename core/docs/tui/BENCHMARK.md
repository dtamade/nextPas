# nextpas.core.tui Benchmark Results

> Measured on: Linux x86_64, FPC 3.3.1-trunk, -O2
> Date: 2026-06-01
> Hardware: (see system info)

## Buffer Diff (200x50 terminal, 10000 cells)

| Benchmark | ns/op | ops/s |
|-----------|-------|-------|
| DiffInto 200x50 (10 changed rows) | 46,563 | 21,476 |
| DiffInto 200x50 (identical) | 26,262 | 38,078 |

**Analysis:** Identical-buffer fast path is ~1.8x faster than changed case. At 21K ops/s for the changed case, this supports >300 FPS at 200x50 terminal size with comfortable headroom.

## Widget Render (120x40 terminal)

| Benchmark | ns/op | ops/s |
|-----------|-------|-------|
| Full render (block+list+para+gauge) | 119,293 | 8,383 |
| Block only 120x40 | 46,403 | 21,550 |
| SetString 120x40 (40 rows) | 16,370 | 61,087 |

**Analysis:** Full composite render at 8.3K ops/s = ~119μs per frame. Well under 16ms budget (60 FPS). SetString baseline shows buffer write throughput at 61K ops/s.

## Input Parsing

| Benchmark | ns/op | ops/s |
|-----------|-------|-------|
| ParseOne ASCII key | 99 | 10,119,511 |
| ParseOne CSI arrow | 134 | 7,474,735 |
| ParseOne SGR mouse (incomplete) | 50 | 20,152,758 |
| ParseOne UTF-8 CJK | 44 | 22,691,173 |

**Analysis:** Input parsing at 7-22M ops/s. Even the slowest case (CSI arrow at 134ns) can handle >7M events/sec — far exceeding any realistic input rate.

## Layout Solver

| Benchmark | ns/op | ops/s |
|-----------|-------|-------|
| VerticalSplit 3 constraints | 354 | 2,826,440 |
| HorizontalSplit 5 constraints | 423 | 2,365,274 |
| Grid 4x4 uniform | 2,066 | 484,018 |
| Grid 8x8 uniform | 4,351 | 229,854 |

**Analysis:** Layout solving at 230K-2.8M ops/s. Even the heaviest case (8x8 grid) at 4.3μs is negligible compared to render time.

## Summary

All benchmarks show performance well within real-time TUI requirements:
- **Render budget:** 119μs full frame << 16ms (60 FPS target)
- **Diff budget:** 47μs << 16ms
- **Input latency:** <1μs per event
- **Layout:** <5μs even for complex grids

No SIMD optimization is strictly necessary for correctness, but text.width and buffer diff are candidates for further improvement in high-throughput scenarios (e.g., streaming large text, 4K terminals).
