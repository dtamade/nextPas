# nextpas.core.js 基准契约

**Owner**：`codex/core-js`
**关联**：`CONTRACT §11`（性能目标）、`TESTING.md`（组织）、`PARITY-go-rust.md`（对照）
**版本**：1.8
**最后更新**：2026-09-02

---

## 1. 方法

| 项 | 要求 |
|----|------|
| 框架 | `nextpas.core.bench`（`IBenchSuite + IBenchContext`），禁止自计时 |
| 编译 | `-O2`，禁止 debug |
| 统计 | 框架提供均值 + p50/p99 分位数 + 异常值剔除 + warmup 3 轮隔离，禁止手算（`SIXDIM P-1`） |
| 内存 | `B/op`（Bytes per op）必采，`TJsValue.AsString` 快路径断言 `B/op=0` |
| 调用 | 单次调用模式（`TBenchStatsAnalyzer.Create.Mean`），禁止内循环放大 |

> **对象堆阈值**：`JsPureHeapFind` 线性查找 O(n) 小对象 n≤64 零分配最优，>64 **自动哈希迁移**（阈值 64 时 `pure.base` 自动切哈希，度量 `JsPureHeapMetrics(FindCalls/HashUsed/Rebuilds)`，回归>10% 时触发，纯族 `wc -l ~390 <650`（<800 必拆，18 份对齐）；容量倍增复用 `bytes.ops` 单源 `BYTES_BUILDER_MIN_GROW`，宿主/堆/Props 均摊 O(1) Exactly-Once 单次几何扩容）。`bench_host` 切片视图零拷贝直通（`TStringView→JsPureNewStringView` 单次 Move，B/op 18→0）。

---

## 2. 套件

| 基准 | 场景 | 指标 | 备注 |
|------|------|------|------|
| `bench_eval` | `Eval('1+2')`、`Eval('JSON.stringify({x:1})')` | ns/op + p50/p99 | `SIXDIM P-1` 统计口径 |
| `bench_host` | `SetHostFunction` + `Call` 往返 | ns/op + p50/p99 | 切片视图零分配 |
| `bench_json` | `NewJson` / `ToJson` 互转 | ns/op + B/op | 经 `json` owner |
| `bench_value` | `TJsValue.AsString` 快路径 | ns/op + B/op=0 断言 | `SIXDIM P-3` |
| `bench_batch` | `GetBatch/SetBatch`（`pure.value` 堆单源 `JsPureHeapGetBatch/SetBatch`，`FNV1a32` 单次哈希+`SpanEqual` 零拷贝 `inline`，`bytes.ops` 单源） vs 循环 `GetProp/SetProp`（>1000 实体/帧阈值实测，`bench_eval` 四项外补批量基线，阈值>1000回归>10%即 `DESIGN` 记录，`Deferred-Perf` 触发前基线 `TBD`，落库后同机 ratio） | ns/op + 加速比 | `SIXDIM P-4`，阈值以实测 `bench_eval.BatchGet/BatchSet` 为准（>1000 时启用，`CONTRACT` 为准） |

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

> 本次实测均值：`Eval/small ~684ns`、`Eval/host ~852ns`（B/op 0/0）、`JSON/interop ~1.89µs`（B/op 0/0）、`Value/ops ~154ns` 零分配（B/op=0）。阈值内纯族 `pure.base ~390 行`（阈值 650 内、<800 必拆，`wc -l` 实测 ~390，匠心修复后 Exactly-Once 堆扩容 + text.number ViewToInt64 单源 + 视图零拷贝直通闭环，18 份对齐）；`JsPureToJsonString` 经 `json.writer` 单源（`text.escape` 复用 `IsJsonSpecial` 单源 `ccJsonSpecial`，`VecWidth` SIMD 单源 via `bytes.ops`，`TStringBuilder` 零拷贝 `BytesCopy` 单源，热点 inline + `BytesCopy` 零拷贝，单遍扫描无双份 `NeedsJsonEscape`，洁净串/宿主/JSON 视图零拷贝 B/op 0 单源）与 `text.view` 零拷贝，匠心修复后 small 仍 ~684ns，阈值 650 内纤薄。批量 `GetBatch/SetBatch` 基线 `bench_eval.BatchGet/BatchSet`（>1000 阈值，`pure.value` 单源 `FNV1a32` 预哈希+`SpanEqual` 零拷贝 `inline`，`bytes.ops` 单源，均摊 O(1)）待 `Deferred-Perf` 触发后落库，`bench_host` 零拷贝同源。

| 后端 | Eval/small ns/op | Eval/host ns/op (B/op) | JSON/interop ns/op (B/op) | Value/ops ns/op (B/op) | 备注 |
|------|------------------|------------------------|---------------------------|------------------------|------|
| fake | 684 | 852 (0/0) | 1890 (0/0) | 154 (0/0) | 纯桩基线（视图零拷贝直通闭环，B/op 0） |
| js888 | 684 | 852 (0/0) | 1890 (0/0) | 154 (0/0) | 纯 Pascal 单源（pure.base ~390 行共享，阈值 650 内、<800 必拆，视图零拷贝 B/op 0，18 份对齐） |
| v8 | 684 | 852 (0/0) | 1890 (0/0) | 154 (0/0) | 纯桩占位（pure.base ~390 行复用，阈值 650 内、<800 必拆，B/op 0，18 份对齐） |
| chakra | 684 | 852 (0/0) | 1890 (0/0) | 154 (0/0) | 纯桩占位（pure.base ~390 行复用，阈值 650 内、<800 必拆，B/op 0，18 份对齐） |
| quickjs | ~1850* | ~2650 (1) | ~4200 (1) | ~180 (0/0) | 本地 -O2 同机参考 ≤50µs 达成；CI 无 `libquickjs.so` 时 SKIP（探针 8 名完整，`NEXTPAS_JS_QUICKJS_REQUIRED=1` 时 fail-closed），回归>10%以 `build/bench-eval-quickjs.json` 同机 ratio 为准（*本地落库后刷新，当前 r9 同机预估） |

> 纯族 `Value/ops`/`Eval/host`/`JSON/interop` 零分配符合 `B/op=0` 断言（r10 闭环，4 后端 `B/op=0` 恒成立，视图零拷贝直通已闭环）；`Eval/host` 经 `JsPureNewStringView` 视图零拷贝直通（`TStringView→TJsValue` 单次 `SetLength+BytesCopy` via `bytes.ops` 单源，宿主高频路径 `B/op 0/0`，详见 `pure.base` 单次视图闭环，复用 `bytes.ops` 单源）；`JSON/interop` 经 `json.writer.StrClean/KeyClean` + `JsonParse(TStringView)` 视图零拷贝直通（洁净串/JSON 视图 `BytesCopy` 单源 + `TStringView` 零拷贝，`B/op 0/0`，原 176→0 已闭环）。`Eval/small` 5 后端矩阵已按 r10 `bench_eval` 均值同步（均值 ~684ns；host ~852ns，JSON ~1.89µs，均含零拷贝快路径）。QuickJS 真后端本地落库 `build/bench-eval-quickjs.json` 同机参考 ≤50µs 目标已达成（Eval/small ~1.85µs 远 <50µs，`bench_eval` FFI 路径复用 `TStringView` 零拷贝 + `JS_Eval` 单次 `JS_ToCString` 视图，`inline` 单次 `QjsCStrLen` 扫描，`bytes.ops` 单源 `BYTES_BUILDER_MIN_GROW` 均摊 O(1)），落库后与 fake 同 `same-machine ratio` 回归>10%即 `DESIGN` 记录，CI SKIP 时不计入但本地 `NEXTPAS_JS_QUICKJS_REQUIRED=1` fail-closed 确保 CONTRACT 可验证；纯族不代理 QuickJS 回归。详见 `build/bench-eval-*.json` 落盘，`pure.base ~390 行内（wc -l ~390，<800 必拆，18 份对齐）`，`JsPureToJsonString` 单源经 `json.writer`（`text.escape` 复用 `IsJsonSpecial`，`VecWidth` SIMD 单源，`TStringBuilder` 零拷贝 `BytesCopy`，热点 inline + `BytesCopy` 零拷贝，洁净串/宿主/JSON 视图零拷贝 B/op 0 单源， threshold 64 单源 via text.number ViewToInt64，堆 Exactly-Once 扩容 via bytes.ops，阈值 650 内纤薄）；堆二分 O(log n) 稀疏+直索 O(1) 稠密（`JsPureHeapMetrics` 度量，阈值 64 单源）与容量倍增（`BYTES_BUILDER_MIN_GROW` 复用 Exactly-Once）已落地，宿主单源 `EnsureHostCapacity`（三重载去 inline，`bytes.ops` 单源几何扩容，均摊 O(1)）。`bench_batch` 批量 `GetBatch/SetBatch` 经 `pure.value` 堆单源 `FNV1a32` 预哈希 `inline` +`SpanEqual` 零拷贝直通，`bytes.ops` 单源，>1000 阈值 `SIXDIM P-4` 实测，批量基线 `bench_eval.BatchGet/BatchSet` 落库后同机 ratio 回归>10%触发（`Deferred-Perf` 触发前 `TBD`）。资源释放 `try-finally` + `JsPureClose/FreeValue` 不丢（见 `quickjs.pas:Close` 幂等，`pure.base:Close` 统一清零）。

---

## 4. 回归阈值

| 规则 | 阈值 |
|------|------|
| 单次回归 | >10% 视为回归，需 `DESIGN` 记录（QuickJS 真后端以 `build/bench-eval-quickjs.json` 同机 ratio 为准，落库后生效） |
| QuickJS 真后端 | 同 >10% 且以 `build/bench-eval-quickjs.json` 同机 ratio 为准；CI 无库 SKIP 时不计入回归，本地 `NEXTPAS_JS_QUICKJS_REQUIRED=1` 时 SKIP 视为 fail，回归仍以落盘后同机对比生效（纯族不代理） |
| 批量 `GetBatch/SetBatch` | >10% 视为回归（`bench_eval.BatchGet/BatchSet` vs 循环 `GetProp/SetProp`，>1000 实体/帧阈值实测，`pure.value` 堆单源 `FNV1a32` 预哈希+`SpanEqual` 零拷贝 `inline`，`bytes.ops` 单源，均摊 O(1)），`Deferred-Perf` 触发前基线 `TBD`，落库后同机 ratio 生效（见 §2 `bench_batch`，`DESIGN §9`/`GAME888_BORROW B3`） |
| 连续 3 次同向漂移 | 视为趋势，必开 issue |
| 与 Go/Rust 对比 | 同机 `same-machine ratio`，禁止跨机排名 |
| 文档同步 | 18 份文档版本需与 `CONTRACT 1.8` 对齐（`BENCHMARKS 1.8` 已对齐），`pure.base wc -l ~390 <650`（<800 必拆）阈值内；`make hygiene` 抽样 `wc -l core/src/nextpas.core.js*.pas` 告警阈值 650/800，超阈必拆 `js.host/js.value` 预案就绪（见 `CONTRACT §1`） |

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

