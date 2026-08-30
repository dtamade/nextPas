# nextpas.core.js 基准契约

**Owner**：`codex/core-js`
**关联**：`CONTRACT §11`（性能目标）、`TESTING.md`（组织）、`PARITY-go-rust.md`（对照）
**版本**：1.0
**最后更新**：2026-08-30

---

## 1. 方法

| 项 | 要求 |
|----|------|
| 框架 | `nextpas.core.bench`（`IBenchSuite + IBenchContext`），禁止自计时 |
| 编译 | `-O2`，禁止 debug |
| 统计 | 框架提供均值/分位数/异常值剔除，禁止手算 |
| 调用 | 单次调用模式（`TBenchStatsAnalyzer.Create.Mean`），禁止内循环放大 |

---

## 2. 套件

| 基准 | 场景 | 指标 |
|------|------|------|
| `bench_eval` | `Eval('1+2')`、`Eval('JSON.stringify({x:1})')` | ns/op |
| `bench_host` | `SetHostFunction` + `Call` 往返 | ns/op |
| `bench_json` | `NewJson` / `ToJson` 互转 | ns/op + B/op |
| `bench_value` | `TJsValue.AsString` 快路径 | ns/op（零分配断言） |

---

## 3. 目标与基线

| 场景 | 目标 | 基线状态 |
|------|------|----------|
| `Eval('1+2')` fake | ≤10µs | S1 后落库 |
| `Eval('1+2')` QuickJS | ≤50µs | S1 后落库 |
| `HostFunction` 往返 | ≤5µs | S1 后落库 |
| `AsString` 快路径 | 零分配 | S1 后落库 |

基线落库格式：`操作 迭代 总耗时 ns/op 吞吐`，与 `bench` 框架对齐，随 `PARITY-go-rust.md` 对照刷新。

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

