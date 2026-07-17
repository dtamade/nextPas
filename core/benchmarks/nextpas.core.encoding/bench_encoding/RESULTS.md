# nextpas.core.encoding Benchmark Results

This file is a **historical snapshot** of local measurements. It is **not current CI performance truth**.
Numbers below were collected on the **same host** under FPC/Go/Rust and may drift with CPU and toolchain.

## How to re-measure

```bash
make -C benchmarks/nextpas.core.encoding/bench_encoding clean run
```

Optional filters (see `nextpas.core.bench`):

- `NEXTPAS_BENCH_FILTER`
- `NEXTPAS_BENCH_MAX_ITERS`

## Environment (snapshot, 2026-05-30)

- Platform: Linux x86_64, same host for FPC / Go / Rust
- FPC: 3.3.1 trunk, -O2
- Data size: 10,000 bytes; comparator loops: 1000 iters

## Snapshot (µs/op on 10KB)

| Op | FPC nextpas | Go | Rust (naive encode-only) |
|----|------------:|---:|-------------------------:|
| Base64.Encode | ~36 | ~30 | ~35 |
| Base64.Decode | ~27 | ~28 | — |
| Hex.Encode | ~14 | ~53 | ~34 |
| Hex.Decode | ~22 | ~41 | — |

## Notes

- Go uses `encoding/base64` and `encoding/hex`.
- Rust comparator is encode-only naive (no crate, no decode path).
- Relative ranking is not a durable ranking; re-run before citing performance claims.
