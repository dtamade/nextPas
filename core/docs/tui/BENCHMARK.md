# nextpas.core.tui Benchmark Results

> Measured on: Linux x86_64, FPC 3.3.1-trunk, -O2
> Date: 2026-06-02
> Host: Debian Linux 6.12.74+deb13+1-amd64, x86_64
> Baseline type: single local run; use repeated medians for regression decisions

Run all TUI benchmarks:

```bash
FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc benchmarks/nextpas.core.tui/run_all.sh
```

## Buffer diff baseline at 200x50

| Benchmark | ns/op | ops/s |
| --- | ---: | ---: |
| DiffInto 200x50 (10 changed rows) | 46,898 | 21,323 |
| DiffInto 200x50 (identical) | 27,019 | 37,011 |

The identical-buffer fast path is about 1.7x faster than the changed-row case. The changed-row case
still leaves broad headroom against a 16 ms frame budget.

## Widget render baseline at 120x40

| Benchmark | ns/op | ops/s |
| --- | ---: | ---: |
| Full render 120x40 (block+list+para+gauge) | 157,966 | 6,330 |
| Block only 120x40 | 47,424 | 21,087 |
| SetString 120x40 (40 rows) | 16,183 | 61,793 |

The full composite render is about 158 us per frame, well below the 16 ms target for 60 FPS. The
SetString case records raw buffer write throughput for a full 120x40 surface.

## Input parsing baseline

| Benchmark | ns/op | ops/s |
| --- | ---: | ---: |
| ParseOne ASCII key | 89 | 11,259,233 |
| ParseOne CSI arrow | 112 | 8,907,575 |
| ParseOne SGR mouse (incomplete) | 96 | 10,438,086 |
| ParseOne UTF-8 CJK | 83 | 12,099,360 |

Input parsing is far below any realistic terminal input rate, including CSI and UTF-8 paths.

## Layout solving baseline

| Benchmark | ns/op | ops/s |
| --- | ---: | ---: |
| VerticalSplit 3 constraints | 349 | 2,865,830 |
| HorizontalSplit 5 constraints | 415 | 2,408,901 |
| Grid 4x4 uniform | 2,062 | 484,943 |
| Grid 8x8 uniform | 4,332 | 230,850 |

Even the 8x8 grid case is below 4.4 us, so layout cost remains small compared with render and diff.

## CI verifies benchmark availability, not absolute speed

The GitHub workflow runs `benchmarks/nextpas.core.tui/run_all.sh` as a smoke check. This proves the
four benchmark projects compile and execute after API changes.

The workflow does not enforce ns/op thresholds. Hosted runners are noisy, and hard limits would mix
real regressions with scheduler, CPU, and thermal variance. Stable performance regression checks
need fixed hardware, pinned compiler settings, repeated sampling, and a stored median baseline.

## Cross-runtime comparison boundary

The repository already has platform-level FPC RTL, Go, and Rust comparison benchmarks under
`benchmarks/platform-comparison/`. Those cover shared platform operations such as path handling,
file checks, mmap, and random bytes.

The TUI benchmarks in this document measure nextpas-specific terminal buffer diffing, widget
rendering, input parsing, and layout solving. Numeric Go or Rust comparisons should only be added
after equivalent terminal buffer and widget workloads exist in those runtimes. Until then, this file
records the FreePascal TUI baseline only.

## Summary

- Full render: about 158 us, far below 16 ms.
- Diff: about 47 us for changed rows and 27 us for identical buffers.
- Input parsing: below 0.12 us per event.
- Layout: below 4.4 us for the current grid workload.
- Hot paths use AVX2+SSE2 `StringDisplayWidth` acceleration and dirty-row bitmap diff skipping.
