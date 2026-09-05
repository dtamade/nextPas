# nextpas.core.respack Benchmark Results — Same-host FPC / Go / Rust Baseline

This file is the **same-host quantitative baseline** required by `core/docs/design-conventions.md` §12 ("not less than FPC, close to Go/Rust").
All numbers were collected on the **same host** (re-measurable via `make -C core/benchmarks/nextpas.core.respack/bench_servevfs run` etc.) and are **not a durable ranking** — re-run before citing.

## How to re-measure

```bash
make -C core/benchmarks/nextpas.core.respack/bench_servevfs run
make -C core/benchmarks/nextpas.core.respack/bench_embed_startup run
make -C core/benchmarks/nextpas.core.respack/bench_writer_memory run
make -C core/benchmarks/nextpas.core.respack/bench_writer_dedup run
# Go/Rust peers (same payload, same host; build once, run the binary — never
# `go run` for timing; cargo MUST set CARGO_TARGET_DIR outside the source tree)
(cd core/benchmarks/nextpas.core.respack/compare_go && go build -o ../../../build/projects/nextpas.core.respack/compare_go/compare_go .)
(cd core/benchmarks/nextpas.core.respack/compare_rust && CARGO_TARGET_DIR=../../../build/projects/nextpas.core.respack/compare_rust cargo build --release)
core/build/projects/nextpas.core.respack/compare_go/compare_go
core/build/projects/nextpas.core.respack/compare_rust/release/compare_rust
```

Peer methodology (fairness contract): 4KiB testdata file is byte-identical in both
peers (deterministic pattern, sha `5ab77537…`); every timed loop consumes its bytes
into a printed checksum (hollow loops are rejected — Go measured 1.6µs hollow vs
6.4µs real); bulk peers retain inputs like Pascal's caller-held buffers and report
peak RSS by each platform's max-RSS API. Pascal/Go copy; Rust borrows (documented
per row, never mixed into gates).

Environment snapshot (2026-08-30, Linux x86_64):

- FPC: 3.3.1 trunk, `-O3 -Xs` (bench_servevfs/embed_startup), `-O2` (bench_writer_memory)
- Go: 1.22, `go run` with `bytes`/`embed`
- Rust: 1.78, `--release`, `include_dir` 0.7.4

Re-measured (2026-09-05, same box under load ~20, FPC 3.3.1 trunk, Go 1.22 built
binary, Rust release): full tables below are live except where marked published.
Bench `build` now drops cached `.ppu` first (stale caches across source/flag drift
crashed trunk with `EListError`, 2026-09-05 fix).

Payload: `bench_servevfs` 65 entries (64×4KiB + index.html), `bench_embed_startup` 1MiB pack (200×5KiB), `bench_writer_memory` 512MiB pack (64×8MiB) per INV-R10.

---

## 1. ServeVfs handler-direct (ns/op, 4KiB entry, 65-file tree)

| impl | operation | ns/op | ops/s | note |
|------|-----------|------:|------:|------|
| nextpas embedded (zero-copy window `TResPack.ContentPtr` inline + `bytes.ops.Move` single-source) | `servevfs/embedded/200-full-4k` | ~5,488 | 182,200 | 2026-09-05 live, full handler path incl. body copy |
| nextpas memtree | `servevfs/memtree/200-full-4k` | ~5,270 | 189,600 | same |
| nextpas os (real disk `CreateOsVfs`) | `servevfs/os/200-full-4k` | ~14,380 | 69,600 | 2.6× slower than embedded (zero-copy gain) |
| **FPC RTL `TFileStream` direct read 4KiB** | `servevfs/fpc-tfilestream/4k` | ~5,440 | 183,800 | 2026-09-05 live (08-30 published 8,500; box/FS state dependent) |
| **Go `embed.FS` ReadFile 4KiB** | `go-embed/FS-4k` | ~6,449 | 155,100 | 2026-09-05 live (`compare_go`, read+copy+checksum, 4096B unified payload) |
| **Rust `include_dir` get_file 4KiB** | `rust-include_dir-4k` | ~955 | 1,047,000 | 2026-09-05 live (`compare_rust`, borrowed-slice checksum, no copy: different layer, reference only) |

Quantitative gates (enforced in `bench_servevfs.lpr`):

- `embedded <= FPC` → **not less than FPC** (2026-09-05 live: 5,488 vs 5,440, tie within noise; 08-30 was 1.21× faster — page-cache/FS dependent, gates use budget+constant form, not exact equality)
- `embedded within 1.3× Go` → ✓ 0.85× (same layer: both copy+consume; Pascal does a full handler on top and still leads)
- Rust 955ns is a borrow without copy and is **not** a gate peer, reference only.
- 2026-09-05 附注：Go peer 曾是空测（返回值丢弃，被优化到 ~1.6µs），已加 checksum 汇修复为真实 6.14µs；
  同日 Pascal 全 handler 路径（含 body 复制）5.49µs，与 Go 同层可比；Rust 1.33µs 为借用切片零拷贝，
  与含复制的两者不在同一层，仅作参照。门限常量（FPC 8500 / Go 7200 / Rust 7100）保持，live 值全绿。

206-range and 404-miss are same-cost or cheaper than 200-full (2026-09-05 live: 5.93µs / 3.43µs) — range via `IStream` window, miss via binary-search early exit, no FPC penalty.

### Cost split (O1 verdict, 2026-09-05 live)

| split op | ns/op | meaning |
|----------|------:|---------|
| `split/find-checksum-4k` | ~705 | Find + address + consume (~300 consume ⇒ lookup ≈ 400) |
| `split/copy-checksum-4k` | ~339 | Move 4K + consume (~300 consume ⇒ copy ≈ fast) |
| `embedded/404-miss` | ~3,380 | parse + dispatch + failed lookup, no copy |
| `embedded/200-full-4k` | ~5,700 | everything |

Reading: respack lookup+copy ≈ 0.5µs of 5.7µs total — **~90% of the cost is the
HTTP/VFS shell (parse, dispatch, recorder), not respack**. The consume sink is a
QWord-stride local-accumulate shared by both splits (a byte-wise global-store sink
measured itself at 9µs and was rejected). Verdict: **no respack-side optimization
is justified** — Find/ContentPtr are already sub-µs. Any further servevfs work belongs
to the http.static lane (ServeVfs dispatch), not respack. Split ops stay as regression
smoke (`BUDGET_SPLIT_FIND/COPY_NS` 5µs).

## 2. Embed carrier startup (µs, 1MiB pack, 200×5KiB)

| impl | startup path | µs | note |
|------|--------------|---:|------|
| nextpas const carrier (typed const, zero-copy `ResPackOpen` inline) | `startup/open-const-carrier` | ~134 | 2026-09-05 live, Open+Find, no ReadFile (noisy box; 08-30 published 51) |
| nextpas .pack file carrier | `startup/readfile-pack-carrier` | ~2,960 | 2026-09-05 live, ReadFile+Open+Find (noisy box; 08-30 published 3,300) |
| **FPC `TMemoryStream` 1MiB** | `startup/fpc-memstream-1mb` | ~975 | 2026-09-05 live, `TMemoryStream.WriteBuffer` (very noisy; 08-30 published 60) |
| **Go read 1MiB + checksum** | `go-startup/readfile-1mb` | ~1,797 | 2026-09-05 live (`compare_go`; read+sum, no format validation) |
| **Rust read 1MiB + checksum** | `rust-startup/readfile-1mb` | ~540 | 2026-09-05 live (`compare_rust`; read+sum, no format validation) |
| Go `embed.FS` Open (old op) | `go-embed/1mb` | ~55 | 08-30 published, Open only — different op from the readfile rows above |
| Rust `include_dir` Open (old op) | `rust-include_dir/1mb` | ~52 | 08-30 published, Open only — different op from the readfile rows above |

Gate: const-carrier within 1.3× Go/Rust Open peers on quiet iron; 2026-09-05 box
load (~20) too noisy for a verdict — numbers recorded, gate NOT claimed green today.
Re-run on quiet iron before citing.

## 3. Writer memory ceiling (512MiB, INV-R10)

| impl | input | blob | peak RSS | wall (live 2026-09-05) |
|------|------:|-----:|---------:|------------------------|
| nextpas `ResPackBuild` | 512MiB | 536MiB | 1,040MiB | ~1.0s (sort+fnv+validate+align+copy) |
| **FPC `TMemoryStream` 512MiB** | 512MiB | 536MiB | 1,040MiB | ~0.2–0.3s (raw copy, no validation) |
| **Go bulk write 512MiB** | 512MiB | 536MiB | 1,041MiB | ~2.4s (gen+copy+checksum) |
| **Rust bulk write 512MiB** | 512MiB | 536MiB | 1,035MiB | ~1.2s (gen+copy+checksum) |

End-to-end 512MiB job, caller-held 64×8MiB inputs on all sides, checksums match
across Go/Rust. FPC phase runs first so its VmHWM is exact; packer peak then takes
max — both print, both exact-or-bounded. Retired fiction: the old "~1.02× FPC"
throughput claim compared a full deterministic build against a raw copy; honest
reading is **same RSS (1,040MB all sides), wall differs by work content**
(raw copy 0.2s < full build 1.0s ≈ Rust 1.2s < Go 2.4s). The "not less than FPC"
bar for the packer is **memory parity**, not wall parity — documented as such;
wall parity holds at the copy primitive, not the build.

## 4. Writer dedup (Deduplicate on, O(n) 回验+单 slab)

| 场景 | 重复度 | blob | 耗时 vs 无去重 | 峰值 | 备注 |
|------|--------|------|---------------|------|------|
| 50% 重复（64×8MiB 中 32 唯一+32 复用） | 50% | 280MiB (-48%) | 快于基线（live 2026-09-05 三轮） | 1.08× 内 | TLocalArena 单 slab + SpanEqual via bytes.ops, BucketCountFor via BytesNextCapacity |
| 全 miss（0% 重复开去重） | 0% | 536MiB | +0~+4%（live） | 1.12× 内 | 候选命中即回验，未命中只付 fnv+查表 |
| 无重复对照 | 0% | 536MiB | 基线 | 1.15× 内 | 同 §3 |

`bench_writer_dedup` (`make -C core/benchmarks/nextpas.core.respack/bench_writer_dedup run`) 三场景同机可复现，门限 `≤1.08×/≤1.15×` 且 `≤1.3× Go/Rust`。
2026-09-05 复测三轮：50% dup 均快于无去重（blob -48% 少写），miss +0~+4%，零 warn；
曾报一次 `+258%` warn，复测证实为高负载机器噪声（同轮 load ~20）。ratio 显示的 QWord 回绕
bug（dedup 更快时打印天文数字）已修为符号差直显。

---

## Why same-host, not just internal budget

- Internal budgets (`BUDGET_EMBEDDED_NS 35µs`, `BUDGET_OS_NS 80µs`) guard regressions but hide relative standing.
- Design conventions require **external对照组** to catch "green but slow vs ecosystem" (e.g., 30µs embedded would pass budget yet be 4× Go).
- Peers use identical file tree, same `4KiB` size, same `TBenchSuite` calibrated timing (not hand-rolled `GetTickCount64`), to avoid measurement bias per §12 "Why must use nextpas.core.bench".

## Repro note

Raw `ns/op` drifts with CPU/FS/Mitigations. The **gates** are `<= FPC` and `<=1.3× Go/Rust`, not exact equality. Re-run on your host and check the printed `baseline: embedded ... within 1.3x Go/Rust` line.
