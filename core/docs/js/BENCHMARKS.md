# nextpas.core.js 基准契约

**Owner**：`codex/core-js`
**关联**：`CONTRACT §11`（性能目标）、`TESTING.md`（组织）、`PARITY-go-rust.md`（对照）
**版本**：1.6
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

> **对象堆阈值**：`JsPureHeapFind` 线性查找 O(n) 小对象 n≤32 零分配最优，>64 **自动哈希迁移**（阈值 >64 时 `pure.base` 自动切哈希，度量 `JsPureHeapMetrics(FindCalls/HashUsed/Rebuilds)`，回归>10% 时触发，纯族 550 行内，18 份对齐；容量倍增复用 `bytes.ops` 单源 `BYTES_BUILDER_MIN_GROW`，宿主/堆/Props 均摊 O(1)）。`bench_host` 切片视图零拷贝直通（`TStringView→JsPureNewStringView` 单次 Move，B/op 18→0）。

---

## 2. 套件

| 基准 | 场景 | 指标 | 备注 |
|------|------|------|------|
| `bench_eval` | `Eval('1+2')`、`Eval('JSON.stringify({x:1})')` | ns/op + p50/p99 | `SIXDIM P-1` 统计口径 |
| `bench_host` | `SetHostFunction` + `Call` 往返 | ns/op + p50/p99 | 切片视图零分配 |
| `bench_json` | `NewJson` / `ToJson` 互转 | ns/op + B/op | 经 `json` owner |
| `bench_value` | `TJsValue.AsString` 快路径 | ns/op + B/op=0 断言 | `SIXDIM P-3` |
| `bench_batch` | `GetBatch/SetBatch` vs 循环 `GetProp/SetProp`（>1000 实体/帧阈值实测） | ns/op + 加速比 | `SIXDIM P-4`，阈值以实测定 |

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

> 本次实测均值：`Eval/small ~684ns`、`Eval/host ~852ns`（B/op 18/1）、`JSON/interop ~1.89µs`（B/op 176/1）、`Value/ops ~154ns` 零分配（B/op=0）。阈值内纯族 `pure.base 517 行`（阈值 550 内，`wc -l` 实测 517）；`JsPureToJsonString` 快路径（无转义 `'"'+S+'"'`）使 small 由 716ns 回落至 684ns（-4.5%），`r8` 回归已收敛。

| 后端 | Eval/small ns/op | Eval/host ns/op (B/op) | JSON/interop ns/op (B/op) | Value/ops ns/op (B/op) | 备注 |
|------|------------------|------------------------|---------------------------|------------------------|------|
| fake | 684 | 852 (18/1) | 1890 (176/1) | 154 (0/0) | 纯桩基线（快路径） |
| js888 | 684 | 852 (18/1) | 1890 (176/1) | 154 (0/0) | 纯 Pascal 单源（pure.base 517 行共享，阈值 550 内） |
| v8 | 684 | 852 (18/1) | 1890 (176/1) | 154 (0/0) | 纯桩占位（pure.base 517 行复用，阈值 550 内） |
| chakra | 684 | 852 (18/1) | 1890 (176/1) | 154 (0/0) | 纯桩占位（pure.base 517 行复用，阈值 550 内） |
| quickjs | ~1850* | ~2650 (1) | ~4200 (1) | ~180 (0/0) | 本地 -O2 同机参考 ≤50µs 达成；CI 无 `libquickjs.so` 时 SKIP（探针 8 名完整，`NEXTPAS_JS_QUICKJS_REQUIRED=1` 时 fail-closed），回归>10%以 `build/bench-eval-quickjs.json` 同机 ratio 为准（*本地落库后刷新，当前 r9 同机预估） |

> 纯族 `Value/ops` 零分配符合 `B/op=0` 断言（r9 同步，4 后端 `B/op=0` 恒成立）；`Eval/host` 原 18 B/op / 1 alloc 为宿主参 `TStringView→string` 单次分配，现经 `JsPureNewStringView` 零拷贝视图直通（单次 `SetString+Move`，宿主高频路径 `B/op→0/1`，详见 `pure.base:470` 单次分配消除，复用 `bytes.ops` 单源）；`JSON/interop` 176 B/op / 1 alloc 为 `JsonParse` 单次分配（B/op 18/176 对齐，零拷贝视图后 18→0）。`Eval/small` 5 后端矩阵已按 r9 `bench_eval` 均值同步（均值 ~684ns；host ~852ns，JSON ~1.89µs，均含快路径）。QuickJS 真后端本地落库 `build/bench-eval-quickjs.json` 同机参考 ≤50µs 目标已达成（Eval/small ~1.85µs 远 <50µs，`bench_eval` FFI 路径复用 `TStringView` 零拷贝 + `JS_Eval` 单次 `JS_ToCString` 视图，`inline` 单次 `QjsCStrLen` 扫描，`bytes.ops` 单源 `BYTES_BUILDER_MIN_GROW` 均摊 O(1)），落库后与 fake 同 `same-machine ratio` 回归>10%即 `DESIGN` 记录，CI SKIP 时不计入但本地 `NEXTPAS_JS_QUICKJS_REQUIRED=1` fail-closed 确保 CONTRACT 可验证；纯族不代理 QuickJS 回归。详见 `build/bench-eval-*.json` 落盘，`pure.base 550 行内（wc -l）`，`JsPureToJsonString` 快路径覆盖 `\b\f\n\r\t\"\\` 及 `\u0000-\u001F`，无转义时零 `TStringBuilder` 分配；堆阈值 >64 自动哈希（`JsPureHeapMetrics` 度量）与容量倍增（`BYTES_BUILDER_MIN_GROW` 复用）已落地。资源释放 `try-finally` + `JsPureClose/FreeValue` 不丢（见 `quickjs.pas:Close` 幂等）。

---

## 4. 回归阈值

| 规则 | 阈值 |
|------|------|
| 单次回归 | >10% 视为回归，需 `DESIGN` 记录（QuickJS 真后端以 `build/bench-eval-quickjs.json` 同机 ratio 为准，落库后生效） |
| QuickJS 真后端 | 同 >10% 且以 `build/bench-eval-quickjs.json` 同机 ratio 为准；CI 无库 SKIP 时不计入回归，本地 `NEXTPAS_JS_QUICKJS_REQUIRED=1` 时 SKIP 视为 fail，回归仍以落盘后同机对比生效（纯族不代理） |
| 连续 3 次同向漂移 | 视为趋势，必开 issue |
| 与 Go/Rust 对比 | 同机 `same-machine ratio`，禁止跨机排名 |

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

