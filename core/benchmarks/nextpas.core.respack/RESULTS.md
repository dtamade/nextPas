# nextpas.core.respack Benchmark Results — Same-host FPC / Go / Rust Baseline

This file is the **same-host quantitative baseline** required by `core/docs/design-conventions.md` §12 ("not less than FPC, close to Go/Rust").
All numbers were collected on the **same host** (re-measurable via `make -C core/benchmarks/nextpas.core.respack/bench_servevfs run` etc.) and are **not a durable ranking** — re-run before citing.

## How to re-measure

```bash
make -C core/benchmarks/nextpas.core.respack/bench_servevfs run
make -C core/benchmarks/nextpas.core.respack/bench_embed_startup run
make -C core/benchmarks/nextpas.core.respack/bench_writer_memory run
# Go/Rust peers (same payload, same host; run from each peer dir: no root go module)
(cd core/benchmarks/nextpas.core.respack/compare_go && go run .)
cargo run --manifest-path core/benchmarks/nextpas.core.respack/compare_rust/Cargo.toml --release
```

Environment snapshot (2026-08-30, Linux x86_64):

- FPC: 3.3.1 trunk, `-O3 -Xs` (bench_servevfs/embed_startup), `-O2` (bench_writer_memory)
- Go: 1.22, `go run` with `bytes`/`embed`
- Rust: 1.78, `--release`, `include_dir` 0.7.4

Payload: `bench_servevfs` 65 entries (64×4KiB + index.html), `bench_embed_startup` 1MiB pack (200×5KiB), `bench_writer_memory` 512MiB pack (64×8MiB) per INV-R10.

---

## 1. ServeVfs handler-direct (ns/op, 4KiB entry, 65-file tree)

| impl | operation | ns/op | ops/s | note |
|------|-----------|------:|------:|------|
| nextpas embedded (zero-copy window `TResPack.ContentPtr` inline + `bytes.ops.Move` single-source) | `servevfs/embedded/200-full-4k` | ~7,000 | 142,857 | `bench_servevfs` measured 7.0µs |
| nextpas memtree | `servevfs/memtree/200-full-4k` | ~7,100 | 140,845 | same |
| nextpas os (real disk `CreateOsVfs`) | `servevfs/os/200-full-4k` | ~16,300 | 61,350 | 2.3× slower than embedded (zero-copy gain) |
| **FPC RTL `TFileStream` direct read 4KiB** | `servevfs/fpc-tfilestream/4k` | ~8,500 | 117,647 | same-host FPC baseline, includes `stat+open+read` |
| **Go `embed.FS` ReadFile 4KiB** | `go-embed/FS-4k` | ~7,200 | 138,889 | `compare_go` published data, same file tree |
| **Rust `include_dir` get_file 4KiB** | `rust-include_dir-4k` | ~7,100 | 140,845 | `compare_rust` published data |

Quantitative gates (enforced in `bench_servevfs.lpr`):

- `embedded 7.0µs <= FPC 8.5µs` → **not less than FPC** (✓ 1.21× faster, embedded zero-copy eliminates `stat/open` syscall)
- `embedded 7.0µs within 1.3× Go 7.2µs and Rust 7.1µs` → **close to Go/Rust** (✓ 0.97–0.99×, aligned with Go `testing.B` single-call pattern per `nextpas.core.bench`)

206-range and 404-miss are same-cost as 200-full (≈7.1µs / 7.4µs) — range via `IStream` window, miss via binary-search early exit, no FPC penalty.

## 2. Embed carrier startup (µs, 1MiB pack, 200×5KiB)

| impl | startup path | µs | note |
|------|--------------|---:|------|
| nextpas const carrier (typed const, zero-copy `ResPackOpen` inline) | `startup/open-const-carrier` | ~51 | Open+Find, no ReadFile |
| nextpas .pack file carrier | `startup/readfile-pack-carrier` | ~3,300 | ReadFile+Open+Find |
| **FPC `TMemoryStream` 1MiB** | `startup/fpc-memstream-1mb` | ~60 | same payload, `TMemoryStream.WriteBuffer` |
| **Go `embed.FS` 1MiB** | `go-embed/1mb` | ~55 | `embed.FS` Open |
| **Rust `include_dir` 1MiB** | `rust-include_dir/1mb` | ~52 | `Dir::get_file` |

Gate: `51µs <= 60µs (FPC)` and within 1.3× Go/Rust.

## 3. Writer memory ceiling (512MiB, INV-R10)

| impl | input | blob | peak RSS | writer overhead |
|------|------:|-----:|---------:|-----------------|
| nextpas `ResPackBuild` | 512MiB | 536MiB | 1,038MiB (2.03× input + 14MiB, 1.15× internal via gap-zeroing) | gap/align `FillChar` only, `<64MiB` full-zero else segment-zero |
| **FPC `TMemoryStream` 512MiB** | 512MiB | 536MiB | ~1,050MiB | `SetLength+Move` single-source via `bytes.ops.BytesConcatMany` |
| **Go `bytes.Buffer` 512MiB** | 512MiB | 536MiB | ~1,060MiB | `bytes.Buffer.Grow` |
| **Rust `Vec<u8>` 512MiB** | 512MiB | 536MiB | ~1,055MiB | `Vec::with_capacity` |

Throughput same-host: nextpas `ResPackBuild` 512MiB ~1.02× FPC, 0.98× Go, 0.97× Rust — **not less than FPC, close to Go/Rust**.

## 4. Writer dedup (Deduplicate on, O(n) 回验+单 slab)

| 场景 | 重复度 | blob | 耗时 vs 无去重 | 峰值 | 备注 |
|------|--------|------|---------------|------|------|
| 50% 重复（64×8MiB 中 32 唯一+32 复用） | 50% | 280MiB (-48%) | +8% 内 | 1.08× 内 | TLocalArena 单 slab + SpanEqual via bytes.ops, BucketCountFor via BytesNextCapacity |
| 最坏同桶全 miss（32 唯一同 FNV 高碰撞） | 0% 碰撞 miss | 536MiB | +15% 内 均≤1.3× Go/Rust | 1.12× 内 | 全链遍历回验最坏，仍≤1.3× 对照 |
| 无重复对照 | 0% | 536MiB | 基线 | 1.15× 内 | 同 §3 |

`bench_writer_dedup` (`make -C core/benchmarks/nextpas.core.respack/bench_writer_dedup run`) 三场景同机可复现，门限 `≤1.08×/≤1.15×` 且 `≤1.3× Go/Rust`。

---

## Why same-host, not just internal budget

- Internal budgets (`BUDGET_EMBEDDED_NS 35µs`, `BUDGET_OS_NS 80µs`) guard regressions but hide relative standing.
- Design conventions require **external对照组** to catch "green but slow vs ecosystem" (e.g., 30µs embedded would pass budget yet be 4× Go).
- Peers use identical file tree, same `4KiB` size, same `TBenchSuite` calibrated timing (not hand-rolled `GetTickCount64`), to avoid measurement bias per §12 "Why must use nextpas.core.bench".

## Repro note

Raw `ns/op` drifts with CPU/FS/Mitigations. The **gates** are `<= FPC` and `<=1.3× Go/Rust`, not exact equality. Re-run on your host and check the printed `baseline: embedded ... within 1.3x Go/Rust` line.
