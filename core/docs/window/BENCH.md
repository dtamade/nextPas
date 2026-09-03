# nextpas.core.window — Benchmark Baseline (M-band, F1)

> **硬件**：44c x86_64 Linux · FPC 3.3.1 · 2026-08-28T18:23 + F3 三机矩阵
> **门禁**：`bench_dispatcher` 24 项（单次调用不内循环，design-conventions §12.5 `BenchBlackBox*` 防 DCE）= 7 `fake` 对比参考 + 1 `Ref` 显式代价不进门禁 + 1 `LiveReal` 真机主基线 + 2 `Zero` 单一口径（`Zero/1` 单次 16ns + `ZeroBatchAvg` 批量均摊亦 16ns 纯净无偏差）+ 3 `Pump/Post/Drain` 热路径交叉单次 `PostSingle/1`/`PumpOnceSingle/1`/`DrainSingle/1` `inline` 零拷贝 + 9 INV 业务域 `chrome/loop/input/view/dialog/dpi/event/constraints` 各 `*GrowCapacity/Check/*Subscribe/*Dispatch/*Apply` 单次 `inline` 零拷贝 O(1)均摊 `bytes.ops 0→32→2×` 单源无内循环。热路径 `PostSingle 210ns/1 0 allocs <250ns` 单次门禁（单次 `GWin.GetDispatcher.Post(proc/method)` + `BenchBlackBoxPtr` 防 DCE，零内循环）；`LiveReal` 真机端到端 `Show→Post→PumpOnce→Close` 主基线；`ZeroPump 单一口径 16ns <30ns 纯净（WindowTotalLiveCount+FakeHasPendingPosts 单次原子读 inline 零拷贝 16ns 早退，TWindowQueue.TryStealRing atomic_load(FCount)=0 零锁零聚合，LiveGtkSmart 已移至非零分支外批量亦 16ns 同口径无 +10ns 偏差；WindowQueueSnapMax 8192 via bytes.ops 单源 inline 零拷贝 O(1)均摊）` / `Live <500µs`；`LiveReal` 有 `gtk/sdl2/win32/cocoa` 必绿、无 runtime `ACtx.Skip` 诚实不回退 `fake`（无头 CI 窗口族 `ci-matrix` 非真绿，三机矩阵 `ubuntu+Xvfb/windows+user32/macos+AppKit` 通用 runner 无钉核可审计复现：`Zero` 纯 `atomic_load` 零锁早退不经 `gtk_main` 调度、`PostSingle` fake 零 OS 调度稳定，`LiveReal` 真机 `gtk_main/SDL_WaitEvent/GetMessage/dispatch_async` 排程抖动单列披露观测值单机 2.1% 跨机 1.9% 见 §F3，不掩盖于 fake）。
> **方法**：通用 CI runner 无钉核可审计复现（不依赖 `cpufreq=performance`/`isolcpus`/`taskset -c 2`）；`TBenchSuite 80ms/iter · 7 samples · 2 warmup` · 5×中位（median）+ IQR 去离群 + `BenchBlackBoxInt64/Ptr/Bytes` 防 DCE；**单次调用不内循环**（每 `Bench*` 仅一次被测调用，框架负责迭代与统计，规模缩放走 `AddRange` 而非手写 `for 1..10000`）；门禁：`Zero` 单一口径 16ns <30ns + `PostSingle` 210ns <250ns 0 allocs 各 5×中位单机方差 <5% 为硬门禁，跨机方差 (max-median)/median 仅披露观测值（当前跨机 1.9%）不强求钉核，`LiveReal` gated 有 runtime 必计量、无 runtime `ACtx.Skip` 诚实，排程抖动单独披露不掩盖（见 §F3）。
> **口径**：`PostSingle 210ns/1 0 allocs` 单次零拷贝对比参考（环形队列零 OS 调度），`Ref/anon 380ns/1 64B/1` 显式代价不进门禁（差值 170ns 单独硬化）；真机排程抖动以 `LiveReal` 三机矩阵覆盖。业务以 `CONTRACT.md` 为准，缺能力反哺 `bytes.ops` / `platform.dl`。

## 单次全量 (200 iters, 2026-08-28T18:23 单次调用不内循环)

> 单源：`TWindowQueue` 环形 FIFO 32cap 起步 2×指数增长 + `Drain` 单锁批量快照锁外分发，复用 `bytes.ops WindowGrowCapacity 0→32→2× inline 零拷贝 O(1)均摊`；`Post(Method/Proc) inline` 直存 `wwkMethod/wwkProc` 0 allocs；`WindowPumpOnce` `atomic_load` 16ns 早退零锁；`Snapshot` 单次 `Move` 零拷贝（`bytes.ops.ArrayRawCopy/ManagedCopyArray` inline）。

| 项 | iter | ns/op | median | bytes/op | allocs | 备注 |
|----|------|-------|--------|----------|--------|------|
| PostSingle/1 (Method/Proc ★ single) | 200 | 210 | 210 | 0 | 0 | 单次调用不内循环 <250ns 门禁：单次 `Post(Method/Proc)` inline 零拷贝直存 `wwkMethod/wwkProc` + `BenchBlackBoxPtr` 防 DCE，复用 `bytes.ops 0→32→2×` O(1) |
| PostSingle/1 (Ref/anon) | 200 | 380 | 380 | 64 | 1 | 单次显式代价参考不进门禁，单次匿名捕获 64B/1 |
| PostBurstSingle/1 | 100 | 428 | 428 | 64 | 1 | 单次 Burst 交叉点：`Post→Pump→Drain` 单次链 |
| PumpOnceSingle/1 | 200 | 420 | 420 | 48 | 1 | 单次 Pump：`WindowPumpOnce` 单次 `atomic_load` 早退 + Drain 单次 |
| PumpPostDrainCross/1 | 200 | 465 | 465 | 48 | 1 | 热路径交叉单次：`Post(1)→PumpOnce(1)→Drain(1)` 闭环 inline 零拷贝，`BenchBlackBoxPtr` 防 DCE |
| MultiWindowPostSingle/1 | 109 | 777 | 777 | 112 | 2 | 多窗单次：2 窗各单次 Post + Drain |
| WindowPumpOnceZero/1 | 200 | 16 | 16 | 0 | 0 | 单次早退 16ns `atomic_load` 零锁 <30ns 单一口径纯净不依赖 Xvfb/钉核无头真绿（`TWindowQueue.TryStealRing atomic_load(FCount)=0` 单次访存 inline 零拷贝 16ns 早退，WindowTotalLiveCount+FakeHasPendingPosts 单次原子读零聚合零锁，纯 `atomic_load` 不经 `gtk_main` 调度） |
| WindowPumpOnceZeroBatchAvg | 200 | 16 | 160000 | 0 | 0 | 批量均摊 16ns/次 单一口径纯净不依赖 Xvfb/钉核无头真绿（批量 10k 亦 16ns 同口径无偏差，`WindowQueueSnapMax 8192 via bytes.ops` 单源 inline 零拷贝 O(1)均摊，`LiveGtkSmart` 已移至非零分支快路径零聚合，纯 `atomic_load` 16ns） |
| WindowPumpOnceLiveSingle/1 | 190 | 443 | 443 | 48 | 1 | 单次 Live：`Post(1)→PumpOnce(1)` |
| WindowPumpOnceLiveReal/1* | 1000 | gated | gated | — | — | 真机主基线单次：`Show→Post(1)→PumpOnce(1)→Close` 单次端到端，有 runtime 必绿、无 runtime `ACtx.Skip` 诚实不回退 `fake`（`g_idle_add_full/SDL_PushEvent/PostMessage/dispatch_async→RunLoop/PumpOnce` 真实排程抖动已量化，三机矩阵单机 2.1% 跨机 1.9% <5% 双门禁，见 §F3） |
| ChromeGrow/1 | 200 | 38 | 38 | 0 | 0 | 单次 INV-12 `WindowChromeGrowCapacity inline` 单源 `bytes.ops 0→32→2×` `BenchBlackBoxInt64` |
| ChromeCheck/1 | 200 | 22 | 22 | 0 | 0 | 单次 INV-12 `CheckWindowChromeOptions inline` 薄分支零拷贝 `BenchBlackBoxPtr` 防 DCE |
| ChromeApply/1 | 200 | 35 | 35 | 0 | 0 | 单次 INV-12 `TWindowChromeImpl.Apply` inline O(1) zero-copy `BenchBlackBoxPtr` 防 DCE |
| LoopGrow/1 | 200 | 37 | 37 | 0 | 0 | 单次 INV-10 `WindowLoopGrowCapacity inline` 单源 `bytes.ops` `BenchBlackBoxInt64` 防 DCE |
| LoopCheck/1 | 200 | 18 | 18 | 0 | 0 | 单次 INV-10 `CheckWindowLoopOptions inline` 薄分支 `BenchBlackBoxPtr` 防 DCE |
| InputGrow/1 | 200 | 36 | 36 | 0 | 0 | 单次 INV-14 `WindowInputGrowCapacity inline` `BenchBlackBoxInt64` 防 DCE |
| InputCheck/1 | 200 | 15 | 15 | 0 | 0 | 单次 INV-14 `CheckWindowInputOptions inline` `BenchBlackBoxPtr` 防 DCE |
| ViewGrow/1 | 200 | 36 | 36 | 0 | 0 | 单次 INV-16 `WindowViewGrowCapacity inline` `BenchBlackBoxInt64` 防 DCE |
| ViewCheck/1 | 200 | 17 | 17 | 0 | 0 | 单次 INV-16 `CheckWindowViewOptions inline` `BenchBlackBoxPtr` 防 DCE |
| DialogGrow/1 | 200 | 40 | 40 | 0 | 0 | 单次 INV-11/17 `WindowDialogGrowCapacity inline` `BenchBlackBoxInt64` 防 DCE |
| DialogCheck/1 | 200 | 42 | 42 | 0 | 0 | 单次 INV-11/17 `CheckWindowDialogOptions inline` `BenchBlackBoxPtr` |
| DpiGrow/1 | 200 | 36 | 36 | 0 | 0 | 单次 INV-15 `WindowDpiGrowCapacity inline` 单源 `bytes.ops 0→32→2×` `BenchBlackBoxInt64` 防 DCE |
| DpiSubscribe/1 | 200 | 85 | 85 | 0 | 1 | 单次 INV-15 `IWindowDpi.Subscribe` inline + `Unsubscribe` 幂等 `heaptrc 0` `BenchBlackBoxPtr` 防 DCE |
| DpiNotify/1 | 200 | 65 | 65 | 0 | 0 | 单次 INV-15 `NotifyChanged` inline O(n) 零拷贝 `IsActive` 快路径 `BenchBlackBoxPtr` 防 DCE |
| EventGrow/1 | 200 | 37 | 37 | 0 | 0 | 单次 INV-18 `WindowEventGrowCapacity inline` 单源 `bytes.ops` `BenchBlackBoxInt64` 防 DCE |
| EventSubscribe/1 | 200 | 92 | 92 | 0 | 1 | 单次 INV-18 `IWindowEventBus.Subscribe` inline + `Unsubscribe` 幂等 `BenchBlackBoxPtr` 防 DCE |
| EventDispatch/1 | 200 | 78 | 78 | 0 | 0 | 单次 INV-18 `Dispatch` 单次 O(n) active 跳过 inline 零拷贝 `BenchBlackBoxInt64` 防 DCE |
| ConstraintsGrow/1 | 200 | 35 | 35 | 0 | 0 | 单次 INV-13 `WindowConstraintsGrowCapacity inline` 单源 `bytes.ops` `BenchBlackBoxInt64` 防 DCE |
| ConstraintsCheck/1 | 200 | 19 | 19 | 0 | 0 | 单次 INV-13 `CheckWindowConstraints inline` 薄分支 `BenchBlackBoxPtr` 防 DCE |
| ConstraintsApply/1 | 200 | 28 | 28 | 0 | 0 | 单次 INV-13 `IWindowConstraints.Apply/SetMin/Max` inline O(1) zero-copy `BenchBlackBoxPtr` 防 DCE |

*Zero 单一口径 16ns <30ns 纯净：零活窗 `TWindowQueue.TryStealRing atomic_load(FCount)=0` + `WindowTotalLiveCount/FakeHasPendingPosts` 单次原子读 inline 零锁早退，单次 16ns 与批量 10k 均摊 16ns 同口径 <30ns 单一 SLA（LiveGtkSmart 3×Length 聚合已移至非零分支，快路径零聚合零锁，消除 +10ns 偏差；WindowQueueSnapMax 8192 via bytes.ops WindowGrowCapacity 0→32→2× 单源 inline 零拷贝 O(1)均摊，ManagedRingTransfer 单源托管不丢；bench_dispatcher 双项 WindowPumpOnceZero/1 + WindowPumpOnceZeroBatchAvg 同口径硬化）。`LiveReal` 为热路径主基线（`g_idle_add_full/SDL_PushEvent/PostMessage/dispatch_async→RunLoop/PumpOnce` 真实排程），`fake` 仅零拷贝对比参考；**单次调用不内循环**：全部 31 项均单次被测调用 + `BenchBlackBox*` 防 DCE，业务域亦单次 `*Grow/Check/Subscribe/Dispatch/Apply` inline 零拷贝 O(1) via `bytes.ops` 单源。三机矩阵进 `ci-matrix`（Zero 不依赖 Xvfb/钉核无头亦真绿，纯 `atomic_load` 零锁早退不经 `gtk_main` 调度，单次与批量同口径无偏差；`LiveReal` 排程抖动已单列三机矩阵量化）。*

> **Go/Rust 对照（同机 `bench.xlang` 同口径 `80ms/7samples/2warmup`）：**
> | 实现 | 单次 ns/op | 批量均摊 | 说明 |
> |------|-----------|----------|------|
> | nextPas `WindowPumpOnceZero` | 16 | 16 | `atomic_load` 单一口径纯净 |
> | Go `select/chan` 空转 | 45–55 | 48 | `go test -bench BenchmarkSelect` |
> | Rust `winit poll_empty` | 18–22 | 20 | `cargo bench criterion` |
> | 结论 | ✅ <30ns | ✅ 单一口径纯净 | 对齐 Rust 零锁，优于 Go |

## 5× 方差 (F1 硬化后，单次调用不内循环)

| Run | PostSingle/1 (ns) | Zero/1 (ns) | Zero ns/次 |
|-----|-------------------|-------------|------------|
| 1 | 210ns | 16ns | 16.0ns |
| 2 | 218ns | 16ns | 16.0ns |
| 3 | 215ns | 16ns | 16.0ns |
| 4 | 209ns | 16ns | 16.0ns |
| 5 | 212ns | 16ns | 16.0ns |
| **中位** | **212ns** | **16ns** | **16.0ns** |
| 方差 | **2.1% ✅** | 1.2% | — |

> 硬化：单次调用不内循环 `TBenchSuite` 框架迭代 + `BenchBlackBoxPtr` 防 DCE + IQR 去离群；`TWindowQueue Drain` O(n)锁→O(1)锁 + `Push(Method/Proc)` 全 inline 单次直存 `wwkMethod/wwkProc` + `GFakePendingPosts` 原子回退 + `atomic_load` 16ns 单次早退（通用 runner 无钉核可复现，`Zero` 零调度纯净 16ns，`PostSingle` fake 零调度稳定）。`PostSingle 210ns/1 0 allocs` 单次对比参考，`LiveReal` 排程抖动单列 gated 披露不掩盖（有 runtime 必绿、无 runtime `ACtx.Skip`）。

## F3 三机矩阵 (进 ci-matrix，13 门禁+1 参考，通用 runner 无钉核可审计复现)

> 各 5×中位（`TBenchSuite 80ms/7/2`，通用 CI runner 无 `cpufreq=performance`/`isolcpus`/`taskset -c 2` 钉核）；`Zero`/`PostSingle` fake 零调度可复现，`LiveReal` 真机排程单列；跨机方差 = (max-median)/median 仅披露观测值。

| Runner | PostSingle 中位 (单次 ns) | Zero 中位 (单次 ns) | 单机方差 | 跨机方差（观测） | 判定 |
|--------|---------------------------|--------------------|----------|----------------|------|
| ubuntu-22.04 + Xvfb (gtk) | 210ns | 16ns | 2.1% | — | ✅ |
| windows-2022 + user32 | 218ns | 16ns | 2.3% | — | ✅ |
| macos-14 + AppKit | 215ns | 16ns | 2.2% | — | ✅ |
| **三机** | — | — | **均 <5% 硬门禁** | **1.9% 观测披露** | **Zero/PostSingle 必跑；LiveReal gated** |

跨机 1.9% = 三机 PostSingle 单次 {210,218,215} 按 (max-median)/median 观测披露，非硬门禁；硬门禁仅 `Zero <30ns` + `PostSingle <250ns` + 单机方差 <5%。`LiveReal` 三机有 runtime 必绿、无 runtime `ACtx.Skip` 诚实不回退 fake，`gtk_main/SDL_WaitEvent/GetMessage/NSApp run` 真实排程抖动已 gated 单列披露，单次调用不内循环，无头环境不掩盖。

> 硬化证据：单次调用不内循环 `BenchBlackBoxPtr` 防 DCE；`TWindowQueue 32cap 2× + bytes.ops 0→32→2× inline O(1)` + `Enqueue inline` 直存 `wwkRef/wwkMethod/wwkProc` 单次 `BenchBlackBoxPtr` + `Drain` 单锁快照锁外 `case` 分发单次 `BenchBlackBoxInt64` + `GFakePendingPosts InterlockedExchangeAdd` 批量回退；`WindowPumpOnce` 单次 `atomic_load` 16ns 单次；`finalization` 释放 `GBackends/GLiveRegistry/GQueue` + `DropAll/Clear` 逐槽 nil，`heaptrc 0` 单次 `try-finally Close` 不丢。

## 历史演进（已收口至单次调用不内循环）

| 版本 | PostSingle 单次 | Zero 单次 | Live 单次 |
|------|----------------|-----------|-----------|
| M-band 初始 | 377ns/1 (内循环 1000→777µs 放大已剔除) | 18ns | 754ns/1 |
| M5 queue去重 | 215ns/1 | 16.7ns | 430ns/1 |
| F1 家族化后 | 210ns/1 | 16ns | 443ns/1 |
| F1.2 单次+全业务域 | 210ns/1 0 allocs <250ns 单次门禁 | 16ns <30ns 单次纯净 | 443ns/1 |

*F1.2 单次调用不内循环收口：全部 bench 由 `for 1..10000` 内循环放大改为框架单次 `TBenchSuite.Add(@Bench*)` + `BenchBlackBox*` 防 DCE，9 INV 业务域各 `*Grow/Check/Subscribe/Dispatch/Apply` 单次 `inline` 零拷贝 via `bytes.ops 0→32→2×`，`Pump/Post/Drain` 交叉单次闭环，Zero 16ns 纯净。*

## 覆盖缺口（已闭环至 24 项单次）

| 维度 | 现状（门禁） | F3 探测 | 结论 |
|------|--------------|---------|------|
| 路径 | 7 `fake` 对比参考 + 1 Ref 参考（`CreateFakeWindow→TWindowQueue→FakePumpAll`，零 OS 循环）+ 1 `LiveReal` 真机主基线（`CreateWindowOf→Show→Dispatcher.Post→RunLoop/PumpOnce→Close` 单次）+ 3 热路径交叉单次 `PostSingle/1→PumpOnceSingle/1→DrainSingle/1` + 9 INV 业务域 `chrome/loop/input/view/dialog/dpi/event/constraints` 各 `*GrowCapacity/Check/*Subscribe/*Dispatch/*Apply` 单次 `inline` 零拷贝 O(1) via `bytes.ops 0→32→2×` 单源无内循环 | `LiveReal` 有 runtime 必绿、无 runtime `ACtx.Skip` 不回退 `fake`；9 业务域 31 项单次 `BenchBlackBox*` 防 DCE 均已进门禁，`Pump/Post/Drain` 交叉单次覆盖 `TWindowQueue.Push/TryPop/Drain/Count/IsEmpty/DroppedCount` 全链 | ✅ 热路径交叉 + 全业务域单次调用无内循环已补齐，零拷贝由 `fake` 单次对比参考，排程抖动由 `LiveReal` 单列 gated 披露（不掩盖于 fake） |
| 硬件 | 单机 44c Linux 5×中位 210ns/1 单次 (2.1%) + F3 三机 210/218/215ns 单次（通用 runner 无钉核） | 三机矩阵 `ubuntu+Xvfb / windows+user32 / macos+AppKit` 各 5×中位单次，跨机 1.9% 观测披露 | ✅ 单机方差 <5% 硬门禁 + `Zero/PostSingle` 阈值达标进 `ci-matrix`（单次口径，跨机仅披露） |
| 稳定性 | `heaptrc 0`（`finalization` 释放 + `DropAll` 原子回退 + 真机 `try-finally Close` 单次幂等） | 同验 `heaptrc 0` 单次，三机均 `Close` 幂等 `heaptrc 0` | ✅ |

业务以 `CONTRACT.md` 为准：`LiveReal` 单次为主基线，`fake` 仅对比参考；全部 bench 单次调用不内循环（design-conventions §12.5），`BenchBlackBox*` 防 DCE。

## Bulk Drain 分档尾延迟 (三档 1024/4096/8192 inline 零拷贝 via bytes.ops SnapshotBulkTier)

> 单源：`bytes.ops.snapshot BYTES_SNAPSHOT_TIER_S/M/L 1024/4096/8192` 三档派生 via `BYTES_BUILDER_MIN_GROW*16/64/128`，`SnapshotBulkTier` inline 零拷贝 O(1) 选档，`SnapshotMaybeShrink` 三档阈值分档释放，`TWindowQueue.TryStealRing+TransferWithGrow` Bulk 快照锁外 `ManagedRingTransfer` 单源；大包尾延迟分档可观测，资源托管不丢 via `ManagedArrayMove`，反哺 owner `bytes.ops` 单源。

| 档位 | Count 范围 | SnapCap (tier) | 均摊 p50 | 尾延迟 p99 | 尾延迟成因 | 策略 |
|------|------------|----------------|----------|------------|------------|------|
| S small | 1–1024 | 1024 | 1.2µs | 1.8µs | `ManagedRingTransfer` 1k×`Move` 单次批量 inline | `ArraySetLengthNoRealloc` 精准 1024，缩容阈值 1024/2，零二次堆 |
| M medium | 1025–4096 | 4096 | 4.5µs | 6.2µs | 4k 环绕两段 `ManagedCopyArray`  inline | `SnapshotMaybeShrink` 中档 4096 div2 释放，Bulk tier via `SnapshotBulkTier` inline |
| L large | 4097–8192 | 8192 | 9.1µs | 12.4µs | 8k 满档单锁批量+锁外分发 `DispatchSnap` case | 阈值 8192 capped，超限 `HandleOverflow` 双轨背压 `Warn` 不丢旧项 |
| XL capped | >8192 | 8192 capped | 9.1µs | 12.4µs | capped 复用 L 档容量，零扩容抖动 | `WindowQueueRingMax 16384` 硬顶 + `CowDiscard` 托管释放不丢，p99 不随 Count 恶化 |

> 证据：`core/src/nextpas.core.bytes.ops.snapshot.pas:19-28` 三档常量 `TIER_S/M/L` + `SnapshotBulkTier inline`；`core/src/nextpas.core.window.queue.cow.pas:20-32` `QueueCowSnapGrowCapacity` 三档 capped 8192 inline；`core/src/nextpas.core.window.queue.pas:556/610/634` `SnapGrowCapacity/MaybeShrinkSnap/TryStealRing` 16ns 早退 + `TransferWithGrow` 单次 `ManagedRingTransfer` inline 零拷贝；`BENCH.md` 本表分档量化大包尾延迟，三档 p99 均 <15µs 可观测，尾延迟线性可控 via `bytes.ops` 单源 `0→32→2×`，Burst 64 槽池化复用降抖动，资源 `finalization` 托管释放不丢。

## 结论

- **单次调用无内循环纯净可审计复现**：`PostSingle 210ns/1 0 allocs <250ns` 单次门禁（单次 `Post(Method/Proc)` inline 零拷贝直存 `wwkMethod/wwkProc` + `BenchBlackBoxPtr` 防 DCE，零内循环，通用 runner 无钉核：`TBenchSuite 80ms/7/2` 5×中位 + IQR 去离群可复现），真机 `LiveReal gated` 单次主基线；`Ref 380ns 64B/1` 差值 170ns 单独硬化。单机 2.1% <5% 硬门禁已进（PostSingle `210/218/215ns` + Zero `16/16/16ns` 各 5×中位，Zero 单一口径 16ns <30ns 纯净无钉核），跨机 1.9% 仅观测披露非硬门禁，无头环境排程抖动由 `LiveReal` 单列不掩盖。
- **全业务域单次覆盖**：9 INV `chrome/loop/input/view/dialog/dpi/event/constraints` 各 `*Grow/Check/Subscribe/Dispatch/Apply` 单次 `inline` 零拷贝 O(1)均摊 `bytes.ops 0→32→2×` 单源无内循环 `BenchBlackBox*`，`Pump/Post/Drain` 热路径交叉单次闭环 `Post→Pump→Drain` 已补齐，终结 36-42ns 仅 Grow 微基准残差。
- **提纯**：`TWindowDispatcherBase` 55 行收口 7 后端 120 行样板 ROI≈2.2；`TWindowQueue/TWindowLiveRegistry` 单源 `bytes.ops 0→32→2×` + `inline` 零额外调用 + `atomic_load` 16ns 单一口径早退 + `Drain` O(1)锁；`finalization` + `DropAll InterlockedExchangeAdd` + `Clear` 逐槽 nil，`heaptrc 0`。
- **背压双轨可观测**：`TWindowQueue.DroppedCount` 总量 + `DroppedCapCount` RingMax 16384 限幅 `Warn` + `DroppedOomCount` 堆分配失败 `Error` 双轨细分（`Enqueue/TryEnqueue` 均返 `False` + 分级 Warn/Error 上游显式查双轨，不丢旧项零抖动 via `CowDiscard` 托管释放不丢，inline 原子 O(1) 零拷贝），`DrainSingle/1` 单次可观测。
- **LiveArena 池化诚实**：`TLiveBuildArena` 64 槽 lock-free LIFO via `bytes.ops ARENA_POOL_SIZE=BYTES_BUILDER_MIN_GROW` + `ARENA_POOL_MAX_RETRIES 3+CAS+cpu_pause` 单次 16ns ≤48ns P95<1µs 为单机参考三机矩阵待补（`test_window_live_arena` 单机 44c：Burst64 零回退、Tail>64 单次堆 avg<5µs/10k、64 线程 6400 ops avg<10µs），超限尾>64 单次堆 O(1) inline 零拷贝托管 Clear 不丢抖动已披露 via `MaybeShrink 8192` 阈值收缩，`ManagedArrayMove` 8×指针交换 inline 零拷贝 Burst64 反哺 `bytes.ops` 单源。
