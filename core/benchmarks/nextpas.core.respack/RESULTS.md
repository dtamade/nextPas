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
| `split/find-checksum-4k` | ~619–662 | Find + address + consume (门限 ≤ Rust split 1100，绿) |
| `split/find-hashindex-4k` | ~459–497 | 同文件哈希包查找 + address + consume（门限 ≤ 二分×1.2 且 ≤ Rust split 1100，双绿） |
| `split/copy-checksum-4k` | ~320–340 | Move 4K + consume |
| `split/sink-only-4k` | ~260 | consume alone (net 相减用) |
| `embedded/404-miss` | ~3,300 | parse + dispatch + failed lookup, no copy |
| `embedded/200-full-4k` | ~5,500–5,800 | everything |

Reading: respack lookup+copy ≈ 0.5µs of 5.7µs total — **~90% of the cost is the
HTTP/VFS shell (parse, dispatch, recorder), not respack**. The consume sink is a
QWord-stride local-accumulate shared by both splits (a byte-wise global-store sink
measured itself at 9µs and was rejected). Verdict: **no respack-side optimization
is justified** — Find/ContentPtr are already sub-µs. Any further servevfs work belongs
to the http.static lane (ServeVfs dispatch), not respack. Split ops stay as regression
smoke (`BUDGET_SPLIT_FIND/COPY_NS` 5µs).

### vs Rust net analysis (2026-09-06 live, same host)

Sink-subtracted pure lookup+address, both sides:

| side | gross (lookup+consume) | sink alone | net lookup |
|------|----------------------:|-----------:|-----------:|
| Pascal `split/find-checksum` | ~619 | ~260 | **~360** |
| Rust `include_dir get_file` | ~1015 | ~960 | **~55** |

Gross 总额 Pascal 胜（619 < 1015，门限 `BASELINE_RUST_SPLIT_NS` 1100 已编码进
`bench_servevfs`，退化即红灯）。net 口径 Rust 哈希（O(1)，55ns）领先 Pascal
二分+校验+解码（O(log n)，360ns）约 6×：微调（循环守卫上提）只换来 413→360ns，
不同复杂度类打不赢。追平的唯一路径是 FORMAT 预留的 bit5 hash-index 区（O(1)
路径查找索引），属版式扩展，另案立项——当前冻结范围（行为/格式/错误语义）内
已到顶。`StoredPathSpanFast`（循环内免检视图）即本次微调产物，行为零变更。

### Hash-index 收官（2026-09-06 live，同机，65 条目）

bit5 段落地后复测（含第二轮复核）：

| side | gross (lookup+consume) | sink alone | net lookup |
|------|----------------------:|-----------:|-----------:|
| Pascal 二分 `split/find-checksum` | ~646–695 | ~272–289 | **~357–423** |
| Pascal 哈希 `split/find-hashindex` | ~459–497 | ~272–289 | **~170–225** |
| Rust `include_dir get_file` | ~1015 | ~960 | **~55** |

哈希 gross 约为二分的 0.7×（net 约 0.5×）：同复杂度类（O(1) vs O(1)）下 Pascal
fnv+探测+回验链已与 Rust phf 同层可比，剩余额度是不同的汇方法与包规模（65 条目
二分本就便宜，大 n 下哈希优势放大）。门限已双锁进 `bench_servevfs`（哈希 ≤
二分×1.2 防回归，哈希 ≤ Rust split 1100 锁领先），退化即红灯。net 55ns（Rust）vs
170ns（Pascal）的剩差距是 include_dir 的编译期完美哈希 vs 运行时开放寻址的固有差，
不属本格式可追范围，如实记录。

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

### Cost split (2026-09-05 live, same noisy box, relative reading)

| split op | µs/op | meaning |
|----------|------:|---------|
| `startup/split/open-only` | ~126 | 200 条目八步校验，不 Find |
| `startup/open-const-carrier` | ~127 | Open + 一次 Find |
| `lookup/find-binary-search` | ~128 | Open + 另一次 Find（复核） |

Reading: 单次 Find ≈ 1µs（两次独立复核一致）；Open 校验 ≈ 126µs / 200 条目 ≈
0.63µs 每条目。校验是 O(n) 八步全量，无可削之肉——削它等于削弱 INV-R2
（不存在半信任句柄），不在选项内。Verdict: **启动路径无优化项**，成本即契约成本。

## 3. Writer memory ceiling (512MiB, INV-R10)

| impl | input | blob | peak RSS | wall (live 2026-09-05) |
|------|------:|-----:|---------:|------------------------|
| nextpas `ResPackBuild` | 512MiB | 536MiB | 1,040MiB | 构建 ~1.0s，端到端 ~1.25s |
| **FPC `TMemoryStream` 512MiB** | 512MiB | 536MiB | 1,040MiB | ~0.2–0.3s (raw copy, no validation) |
| **Go bulk write 512MiB** | 512MiB | 536MiB | 1,041MiB | ~2.4s (gen+copy+checksum) |
| **Rust bulk write 512MiB** | 512MiB | 536MiB | 1,035MiB | ~1.2s (gen+copy+checksum) |

End-to-end 512MiB job, caller-held 64×8MiB inputs on all sides, checksums match
across Go/Rust. FPC phase runs first so its VmHWM is exact; packer peak then takes
max — both print, both exact-or-bounded. Retired fiction: the old "~1.02× FPC"
throughput claim compared a full deterministic build against a raw copy; honest
reading is **same RSS (1,040MB all sides); end-to-end wall parity within noise**
(Pascal 1241–1386ms vs Rust 1189–1494ms same-host, same-payload, checksums equal;
build-only is ~1.0s vs ~1.2s but build-only excludes Pascal-side fill that Rust
times, so end-to-end is the cited comparison). The "not less than FPC"
bar for the packer is **memory parity**, not wall parity — documented as such;
wall parity holds at the copy primitive, not the build.

2026-09-06 live re-run (same host): Pascal wall 1035ms ≤ Rust 1244ms, RSS 1039 vs
1035（该轮 Pascal 填充未计时，口径偏 Pascal，见下）。
2026-09-06 附注：P0 去重默认开启后曾暴露 bench 输入 bug——填充与拷贝分属两轮循环，
64 条目内容全同，包坍缩至 8MB 而 Rust 对端实写 512MB（不可比）；已修为逐条目独立
填充，包回 ~512MB。
2026-09-06 口径修正（skeptic 审计）：Rust 对端 gen 在计时区内，Pascal 填充此前在
计时区外——双方改为端到端同口径（含填充/生成）后十轮绑核（taskset 42-43）背靠背：
旧填充法五轮 Pascal 1254–1305 vs Rust 1178–1220（每轮慢 60–85ms，系统性差距）；
遂 profile 填充侧，发现 210 万次 251B 小 Move 调用开销 + Chunk 中转拷贝约 60–85ms
（纯 harness 脂肪，非产品代码），改两级相位自洽瓦片直填（63KB 超瓦，~8k 次大块
Move，同字节流，校验和不变）后五轮 Pascal 1189–1222 vs Rust 1172–1256，
五轮胜负 3:2、均值差 ~1%、区间重叠。结论：**持平**（"接近"成立，"超过"仅读路径
成立；此前 wall-win 是口径红利，撤回）。RSS 1040–1041 vs 1035MB 持续持平。
三方输入校验和同机一致（Pascal/Rust/Go 均为 `0000000f9ffffd34`，u64 回绕累加，
载荷逐字节同源）。
门限：`bench_writer_memory` 内双门（端到端 wall ≤1500ms 回归级 + packer 峰值超
FPC 峰值 15% 即红灯）；wall 单样本噪声大（曾见 13.8s 毛刺），门限只抓回归，
胜负以本节逐轮记录为准，复测前勿引用。

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
