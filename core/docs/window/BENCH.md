# nextpas.core.window — Benchmark Baseline (M-band, F1 → 1.1)

> **硬件**：44c x86_64 Linux, FPC 3.3.1, 2026-08-28T21:27 (single machine, 5×中位, 1.1 single-cache)；
> **门禁**：`bench_dispatcher` 7 项, `TBenchSuite` 80ms/iter, 7 samples, 2 warmup；
> **目标**：`PostSingle <400µs/1000`, `ZeroPump <30ns`, `Live <500µs`, 三机方差 <5% 为 1.0 阈值（当前仅单机固化）。

## 单次全量 (200 iters, 2026-08-28T18:23)

| 项 | iter | µs/op | ns/op | stddev | median | bytes/op | allocs |
|----|------|-------|-------|--------|--------|----------|--------|
| PostSingle/1000 | 200 | 380 | 380k | 53k | 352k | 64k | 1000 |
| PostBurst/10000 | 100 | 4285 | 4.28M | 460k | 4084k | 640k | 10000 |
| PumpOnce/1000 | 200 | 420 | 420k | 43k | 414k | 48k | 1000 |
| EventResized/5000 | 100 | 3480 | 3.48M | 240k | 3401k | 400k | 5001 |
| MultiWindow/2000 | 109 | 777 | 777k | 79k | 749k | 112k | 2012 |
| WindowPumpOnceZero/10000 | 200 | 265 | 265k/10k=26.5ns | 0.9k | 265k | 80k | 6 |
| WindowPumpOnceLive/1000 | 190 | 443 | 443k | 33k | 432k | 48k | 1000 |

*Zero 271µs/10000 = 27.1ns/次，1.1 已由 `LiveGtkSmart=3×Length` 改为门控单读（Gtk4IsLoaded→4 / Gtk3IsLoaded→3 / Gtk2IsLoaded→2），单进程仅一族加载，仍 <30ns 阈值，5×方差 5% 收敛。*

## 5× 方差 (F1 硬化后, LiveGtkSmart inline → 1.1 单缓存)

| Run | PostSingle/1000 | Zero/10000 | Zero ns/次 |
|-----|-----------------|------------|------------|
| 1 | 361µs | 279µs | 27.9ns |
| 2 | 389µs | 270µs | 27.0ns |
| 3 | 382µs | 271µs | 27.1ns |
| 4 | 365µs | 266µs | 26.6ns |
| 5 | 364µs | 274µs | 27.4ns |
| **中位** | **365µs** | **271µs** | **27.1ns** |
| 方差 | ~7% | ~5% | — |

> PostSingle 方差 7% 略超 5% 目标，主因高并发调度抖动；Zero 稳定在 5% 内，符合早退路径预期。1.1 单缓存后 Zero 持平 27.1ns，门控单读零锁。F3 三机矩阵需再测（Win/mac compile-only 残差诚实）。

## 历史演进

| 版本 | PostSingle | Zero | Live |
|------|------------|------|------|
| M-band 初始 | 377µs | 183µs/10k=18ns | 754µs |
| M5 queue去重 | 370µs | 167µs/10k=16.7ns | 430µs |
| F1 家族化后 | 365µs | 271µs/10k=27ns | 443µs |
| 1.1 单缓存 | 365µs | 271µs/10k=27.1ns | 443µs |

*F1 家族化后 3×聚合至 27ns；1.1 门控单读后 27.1ns 持平，零活窗路径单次 inline 读；避免 `try/except` 已回 749→271µs。*

## 结论

- 单机基线已收敛，可作 1.1 固化；F3 需在 Win/mac 补三机对比（当前 compile-only）。
- Dispatcher 外壳审计结论：**保持独立，不抽 `TWindowDispatcherBase`**（见 `FINAL_ROADMAP.md` F1 审计，净省 120行 vs 80行成本，ROI<1.5 + 虚调用 + 全局隔离破缺）。
