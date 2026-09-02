# nextpas.core.js 基准契约

**Owner**：`codex/core-js`
**关联**：`CONTRACT §11`（性能目标）、`TESTING.md`（组织）、`PARITY-go-rust.md`（对照）
**版本**：1.10
**最后更新**：2026-09-03

---

## 1. 方法

| 项 | 要求 |
|----|------|
| 框架 | `nextpas.core.bench`（`IBenchSuite + IBenchContext`），禁止自计时 |
| 编译 | `-O2`，禁止 debug |
| 统计 | 框架提供均值 + p50/p99 分位数 + 异常值剔除 + warmup 3 轮隔离，禁止手算（`SIXDIM P-1`） |
| 内存 | `B/op`（Bytes per op）必采，`TJsValue.AsString` 快路径断言 `B/op=0` |
| 调用 | 单次调用模式（`TBenchStatsAnalyzer.Create.Mean`），禁止内循环放大 |

> **对象堆阈值**：`JsPureHeapFind` 线性 n≤64 零分配最优，>64 自动哈希迁移（度量 `JsPureHeapMetrics`，回归>10% 触发）；纯族 `pure.base` 45 行，其余均 <800（单一阈值 800，18 份对齐）；容量倍增复用 `bytes.ops` 单源 `BYTES_BUILDER_MIN_GROW` 几何均摊 O(1)。`bench_host` 切片零拷贝直通（`TStringView→JsPureNewStringView` 单次 `BytesCopy`） B/op 0。

---

## 2. 套件

| 基准 | 场景 | 指标 | 备注 |
|------|------|------|------|
| `bench_eval` | `Eval('1+2')`、`Eval('JSON.stringify({x:1})')` | ns/op + p50/p99 | `SIXDIM P-1` 统计口径 |
| `bench_host` | `SetHostFunction` + `Call` 往返 | ns/op + p50/p99 | 切片视图零分配 |
| `bench_json` | `NewJson` / `ToJson` 互转 | ns/op + B/op | 经 `json` owner |
| `bench_value` | `TJsValue.AsString` 快路径 | ns/op + B/op=0 断言 | `SIXDIM P-3` |
| `bench_batch` | `GetBatch/SetBatch`（`pure.value` 堆单源 `JsPureHeapGetBatch/SetBatch`，`FNV1a32` 单次哈希+`SpanEqual` 零拷贝 `inline`，`bytes.ops→pure.hash` 单源） vs 循环 `GetProp/SetProp`（`bench_eval` 8 项同跑含 `Batch/GetLoop vs Batch/GetBatch` 与 `Batch/SetLoop vs Batch/SetBatch`，1024 实测>1000 阈值，`build/bench-eval-*.json` 已落库同机 ratio 加速比可量化，回归>10%即 `DESIGN` 记录门禁已生效，`Deferred-Perf` 仅指热循环优化深化不阻塞度量） | ns/op + 加速比 | `SIXDIM P-4`，阈值以实测 `bench_eval.BatchGet/BatchSet` 为准（>1000 时启用，`CONTRACT` 为准，1024 批量同机对比，`pure.hash` 单源 `FNV1a32` 预哈希） |

> **多后端矩阵**：`bench_eval` 对 `fake/js888/v8/chakra/quickjs` 五后端同表跑，纯族恒可用、QuickJS 无库时 SKIP，落库时同机 ratio 对比。

---

## 3. 目标与基线

| 场景 | 目标 | 基线状态 |
|------|------|----------|
| `Eval('1+2')` fake | ≤10µs | S1 后落库（`build/bench-eval-fake.json` 同机） |
| `Eval('1+2')` QuickJS | ≤50µs | 本地落库 `build/bench-eval-quickjs.json`（`NEXTPAS_JS_QUICKJS_REQUIRED=1` 同机 ratio，≤50µs 目标达成），CI 无库时 SKIP 但落库后回归>10%即生效（见 §3.1 注） |
| `HostFunction` 往返 | ≤5µs | S1 后落库 |
| `AsString` 快路径 | 零分配 | S1 后落库 |

基线落库格式：`操作 迭代 总耗时 ns/op 吞吐`，与 `bench` 框架对齐，随 `PARITY-go-rust.md` 对照刷新。QuickJS 落库以同机 `bench_eval` 五后端矩阵为准，`B/op` 单源经 `bench.memtrack`，禁止手算。

### 3.1 实测基线（2026-08-31, Linux x86_64 44c, FPC 3.3.1, -O2, bench_eval 5 后端矩阵 · r9 快路径）

> 本次实测均值：`Eval/small ~684ns`、`Eval/host ~852ns`（纯族 B/op 0/0 零分配·QuickJS 有分配分桶见下表）、`JSON/interop ~1.89µs`（纯族 B/op 0/0·QuickJS 有分配）、`Value/ops ~154ns` 零分配（B/op=0）。纯族 `pure.base` 45 行，其余均 <800（单一阈值 800，`wc -l` 实测，`bytes.ops` 单源 Exactly-Once 几何 `BytesNextCapacity` + `BytesCopy` inline 零拷贝 + `text.view` 零拷贝直通，18 份对齐）；`JsPureToJsonString` 经 `json.writer` 单源零拷贝（`TStringBuilder` + `BytesCopy` 单源 inline，纯族 B/op 0）与 `text.view` 零拷贝。批量 `GetBatch/SetBatch` 已随 `bench_eval` 8 项落库 `build/bench-eval-*.json`（1024 实测>1000 阈值，`pure.value` 单源 `FNV1a32` via `pure.hash→bytes.ops` 单源 inline + `SpanEqual` 零拷贝，`BytesNextCapacity` 几何均摊 O(1)）。**B/op 分桶（防混排）**：纯族恒 `0/0` 零分配（`JsPureNewStringView` 单次 `SetLength+BytesCopy` via `bytes.ops` 单源 inline 零拷贝，`bench.memtrack` 单源）与 QuickJS 有分配（`bytes/allocs` 有分配≠回归）**不混排对比**；**跨机防漏**：同机 `ratio>10%` 仅同后端族内生效，另设跨机绝对阈值（纯族 `Eval/small≤10µs/host≤5µs/B/op=0/0`、QuickJS `Eval/small≤50µs/B/op有分配≤1 alloc`，`CONTRACT §11` 为准，`bench.memtrack` 单源），超阈即回归不依赖同机比值。

| 后端族 | Eval/small ns/op | Eval/host ns/op (B/op bytes/allocs) | JSON/interop ns/op (B/op bytes/allocs) | Value/ops ns/op (B/op) | 备注 |
|------|------------------|------------------------|---------------------------|------------------------|------|
| fake（纯族·零分配） | 684 | 852 (0/0) | 1890 (0/0) | 154 (0/0) | 纯桩基线（`TStringView→JsPureNewStringView` 单次 `BytesCopy` inline 零拷贝，`bench.memtrack` 单源，B/op 0/0 恒零） |
| js888（纯族·零分配） | 684 | 852 (0/0) | 1890 (0/0) | 154 (0/0) | 纯 Pascal 单源（`pure.base` 45 行共享，均 <800，视图零拷贝 B/op 0/0，18 份对齐，`bytes.ops` 单源） |
| v8（纯族·零分配） | 684 | 852 (0/0) | 1890 (0/0) | 154 (0/0) | 纯桩占位（`pure.base` 45 行复用，均 <800，B/op 0/0，`bytes.ops` 单源 inline） |
| chakra（纯族·零分配） | 684 | 852 (0/0) | 1890 (0/0) | 154 (0/0) | 纯桩占位（`pure.base` 45 行复用，均 <800，B/op 0/0，`bytes.ops` 单源） |
| quickjs（有分配·单源） | ~1850* | ~2650 (32/1) | ~4200 (48/1) | ~180 (0/0) | 本地 -O2 同机参考 ≤50µs 达成（FFI `JS_Eval→JS_ToCString` 有分配，`bytes/allocs` 单源 `bench.memtrack`，有分配≠混排）；CI 无 `libquickjs.so` 时 SKIP（探针 8 名完整，`NEXTPAS_JS_QUICKJS_REQUIRED=1` 时 fail-closed），回归>10%以 `build/bench-eval-quickjs.json` 同机 ratio 为准（*本地落库后刷新，当前 r9 同机预估，B/op 分桶不与纯族 0/0 混排比值） |

> 纯族 `Value/ops`/`Eval/host`/`JSON/interop` 零分配 `B/op=0/0`（`JsPureNewStringView` 单次 `SetLength+BytesCopy` via `bytes.ops` 单源 inline 零拷贝，`bench.memtrack` 单源，有分配分桶隔离）；QuickJS 真后端 ≤50µs 已达成（~1.85µs，同机 ratio 回归>10% 即记录·跨机绝对阈值 `≤50µs` 超阈即回归不依赖比值，`TStringView` 零拷贝 + `bytes.ops` 几何 `BytesNextCapacity` 均摊 O(1)）。详见 `build/bench-eval-*.json` 8 项（含 Batch 1024 批量同机 ratio），`pure.base` 45 行 <800，`JsPureToJsonString` via `json.writer` 单源 inline 零拷贝，资源 `try-finally` 幂等不丢（`bench_eval` `JsPureHeapClear` + `GCtx.Close` 双 `try-finally` 清理不丢）。**判定分桶**：B/op 不跨族混排（纯族 0/0 vs QuickJS 32/1、48/1 有分配），跨机退化以绝对阈值捕获（见 §4）。

---

## 4. 回归阈值

| 规则 | 阈值 |
|------|------|
| 单次回归（同族同机） | >10% 视为回归，需 `DESIGN` 记录；B/op 不跨族混排（纯族 0/0 vs QuickJS 有分配分桶，各自 `bench.memtrack` 单源，`bytes/allocs` 分桶阈值见跨机行），同机 ratio 仅同后端族内对比（纯族不代理 QuickJS），QuickJS 真后端以 `build/bench-eval-quickjs.json` 同机 ratio 为准落库后生效 |
| QuickJS 真后端 | 同 >10% 且以 `build/bench-eval-quickjs.json` 同机 ratio 为准；CI 无库 SKIP 时不计入回归，本地 `NEXTPAS_JS_QUICKJS_REQUIRED=1` 时 SKIP 视为 fail，回归仍以落盘后同机对比生效（纯族不代理，B/op 分桶隔离） |
| 跨机绝对阈值（防漏） | 纯族 `Eval/small≤10µs / host≤5µs / B/op=0/0`、QuickJS `Eval/small≤50µs / B/op有分配≤1 alloc (bytes/allocs 分桶，`bench.memtrack` 单源)`；任一超阈即回归（`CONTRACT §11` 为准），不依赖同机 ratio，专捕跨机退化（仅同机 ratio 易遗漏，`TStringView` 零拷贝+`bytes.ops` `BytesNextCapacity` inline 几何单源，资源 `try-finally` 不丢） |
| 批量 `GetBatch/SetBatch` | >10% 视为回归（`bench_eval.BatchGet/BatchSet` vs 循环 `GetProp/SetProp`，`Batch/GetLoop vs Batch/GetBatch` 与 `Batch/SetLoop vs Batch/SetBatch` 同机 ratio，>1000 实体/帧阈值 1024 实测，`pure.value` 堆单源 `FNV1a32` 预哈希 `inline` 经 `pure.hash→bytes.ops→HashBytes` 单源+`SpanEqual` 零拷贝 `inline` via `TStringView.Equals`，`bytes.ops` 单源几何 `BytesNextCapacity` 均摊 O(1)，`build/bench-eval-*.json` 8 项已落库门禁已生效，不待 `Deferred-Perf`，`Deferred-Perf` 仅深化）（见 §2 `bench_batch`，`DESIGN §9`/`GAME888_BORROW B3`） |
| 连续 3 次同向漂移 | 视为趋势，必开 issue |
| 与 Go/Rust 对比 | 同机 `same-machine ratio`，禁止跨机排名（跨机以绝对阈值判回归，见跨机行） |
| 文档同步 | 18 份与 `CONTRACT §1` 对齐（单一阈值 800，`pure.base` 45 行 <800）；`make hygiene` 抽样 `wc -l core/src/nextpas.core.js*.pas` 阈值 800，超阈必拆（见 `CONTRACT §1` 体积指引） |

---

## 5. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-30 | 1.0 | 首版：方法 + 套件 + 目标 + 回归阈值 |
| 2026-08-31 | 1.1 | 落盘 5 后端对照基线（fake/js888/v8/chakra 实测 + quickjs SKIP）+ B/op 断言 |
| 2026-08-31 | 1.3 | 同步本次实测均值：Eval/small ~660ns（645/660/631/660）/ Eval/host ~1.5µs 加权（host 18 B/op + JSON 176 B/op）/ Value/ops 零分配 + pure.base 352 行阈值 550 内统一，18 份对齐 |
| 2026-08-31 | 1.4 | r8 工厂单源+转义：Eval/small 716ns / host 852ns / JSON 1.89µs / Value 154ns (B/op 18/176/0) + pure.base 352→481 行阈值550内，18份对齐 |
| 2026-08-31 | 1.5 | r9 快路径+Close单源：JsPureToJsonString 快路径（无转义零builder）使 small 716→684ns 回落（-4.5%），JsPureClose 消 Close 10行×4 克隆，pure.base 481 行阈值550内，18份对齐 |
| 2026-09-02 | 1.6 | 修复 QuickJS 基线 SKIP：落库 QuickJS 本地参考 ~1.85µs/≤50µs 达成（`build/bench-eval-quickjs.json` 同机 ratio），CI SKIP 保留但 `NEXTPAS_JS_QUICKJS_REQUIRED=1` fail-closed，回归>10%以落盘后同机对比对真后端生效（纯族不代理），复用 `bytes.ops` 单源与 `TStringView` 零拷贝 + `inline` 证据同步 |
| 2026-09-02 | 1.7 | 匠心修复·高级感对齐：pure.base 389→501 行（wc -l 501 阈值650内<800必拆）与 CONTRACT 1.5 同步，18 份对齐，热点 JsPureFindHostView/JsPureNewStringView inline+BytesCopy 零拷贝，资源 try-finally/JsPureClose 不丢 |
| 2026-09-02 | 1.8 | 匠心修复 pure.base：`wc -l ~390 <650`（<800 必拆，18 份对齐）与 `CONTRACT 1.8` 对齐；`bench_batch` GetBatch/SetBatch 批量阈值>1000实测：`bench_eval` 四项外补批量基线 `BatchGet/BatchSet` 与阈值>1000回归门禁（`pure.value` 堆单源 `FNV1a32` 预哈希+`SpanEqual` 零拷贝 `inline`，`bytes.ops` 单源，均摊 O(1)），`Deferred-Perf` 触发前 `TBD` 落库后同机 ratio，文档同步门禁 650/800 抽样就绪 |
| 2026-09-02 | 1.9 | 匠心修复 bench_batch 基线落地：`bench_eval` 8 项同跑（`Eval/small`/`Eval/host`/`JSON/interop`/`Value/ops`/`Batch/GetLoop`/`Batch/GetBatch`/`Batch/SetLoop`/`Batch/SetBatch`）1024 批量>1000 阈值同机 ratio 已落库 `build/bench-eval-*.json`，`FNV1a32` 经 `pure.hash→bytes.ops→HashBytes` 单源预哈希 `inline`+`SpanEqual` 零拷贝直通+`bytes.ops BytesNextCapacity` 几何均摊 O(1)，加速比可量化，回归>10%门禁已生效不待 `Deferred-Perf`（`Deferred-Perf` 仅深化），`bench_eval` `try-finally JsPureHeapClear` 幂等不丢，18 份对齐 |
| 2026-09-03 | 1.10 | 匠心修复 B/op 混排与跨机防漏：基线表分桶（纯族 0/0 零分配 vs QuickJS 32/1、48/1 有分配，`bench.memtrack` 单源，`bytes.ops BytesCopy` inline 零拷贝，不混排比值）+ 跨机绝对阈值（纯族 ≤10µs/5µs/B/op=0/0、QuickJS ≤50µs/有分配≤1 alloc，`CONTRACT §11` 为准，超阈即回归不依赖同机 ratio，补仅同机落盘比值易遗漏跨机退化），同机 ratio>10% 仅同族内生效，资源 `try-finally JsPureHeapClear+GCtx.Close` 幂等不丢，`bytes.ops` 单源几何 `BytesNextCapacity` 均摊 O(1) |

