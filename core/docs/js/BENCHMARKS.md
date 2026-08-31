# nextpas.core.js 基准契约

**Owner**：`codex/core-js`
**关联**：`CONTRACT §11`（性能目标）、`TESTING.md`（组织）、`PARITY-go-rust.md`（对照）
**版本**：1.2
**最后更新**：2026-08-31

---

## 1. 方法

| 项 | 要求 |
|----|------|
| 框架 | `nextpas.core.bench`（`IBenchSuite + IBenchContext`），禁止自计时 |
| 编译 | `-O2`，禁止 debug |
| 统计 | 框架提供均值 + p50/p99 分位数 + 异常值剔除 + warmup 3 轮隔离，禁止手算（`SIXDIM P-1`） |
| 内存 | `B/op`（Bytes per op）必采，`TJsValue.AsString` 快路径断言 `B/op=0` |
| 调用 | 单次调用模式（`TBenchStatsAnalyzer.Create.Mean`），禁止内循环放大 |

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
| `Eval('1+2')` fake | ≤10µs | S1 后落库 |
| `Eval('1+2')` QuickJS | ≤50µs | S1 后落库 |
| `HostFunction` 往返 | ≤5µs | S1 后落库 |
| `AsString` 快路径 | 零分配 | S1 后落库 |

基线落库格式：`操作 迭代 总耗时 ns/op 吞吐`，与 `bench` 框架对齐，随 `PARITY-go-rust.md` 对照刷新。

### 3.1 实测基线（2026-08-31, Linux x86_64 44c, FPC 3.3.1, -O2, bench_eval 5 后端矩阵 · M3b）

| 后端 | Eval/small ns/op | Eval/host ns/op (B/op) | JSON/interop ns/op (B/op) | Value/ops ns/op (B/op) | 备注 |
|------|------------------|------------------------|---------------------------|------------------------|------|
| fake | 179 | 493 (18/1) | 1685 (176/1) | 72 (0/0) | 纯桩基线 |
| js888 | 633 | 606 (18/1) | 1612 (176/1) | 94 (0/0) | 纯 Pascal 单源（pure.base 338 行共享） |
| v8 | 1089 | 933 (18/1) | 1878 (176/1) | 77 (0/0) | 纯桩占位（pure.base 复用） |
| chakra | 962 | 561 (18/1) | 1879 (176/1) | 50 (0/0) | 纯桩占位（pure.base 复用） |
| quickjs | SKIP | SKIP | SKIP | SKIP | 无 `libquickjs.so`（探针 8 名完整，`NEXTPAS_JS_QUICKJS_REQUIRED=1` 时 fail-closed） |

> 纯族 `Value/ops` 零分配符合 `B/op=0` 断言（M3b 同步，4 后端 `B/op=0` 恒成立）；`Eval/host` 的 18B/1 alloc 为宿主参 `TStringView→string` 单次分配，后续 `js888 M3c` 将归零。`Eval/small` 5 后端矩阵已按 2026-08-31 最新 `bench_eval` 刷新（fake 179 / js888 633 / v8 1089 / chakra 962 / quickjs SKIPPED）。详见 `build/bench-eval-*.json` 落盘。

---

## 4. 回归阈值

| 规则 | 阈值 |
|------|------|
| 单次回归 | >10% 视为回归，需 `DESIGN` 记录 |
| 连续 3 次同向漂移 | 视为趋势，必开 issue |
| 与 Go/Rust 对比 | 同机 `same-machine ratio`，禁止跨机排名 |

---

## 5. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-30 | 1.0 | 首版：方法 + 套件 + 目标 + 回归阈值 |
| 2026-08-31 | 1.1 | 落盘 5 后端对照基线（fake/js888/v8/chakra 实测 + quickjs SKIP）+ B/op 断言 |
| 2026-08-31 | 1.2 | M3b 刷新：Eval/small 5 后端矩阵按最新 bench 同步（fake 179 / js888 633 / v8 1089 / chakra 962 / quickjs SKIPPED）+ Value/ops 零分配同步 + 纯族 338 行体量标注 |

