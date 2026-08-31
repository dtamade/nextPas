# js × Go / Rust 对标

**范围**：`nextpas.core.js`（S1 目标：QuickJS FFI + fake）
**标杆**：Go `dop251/goja` / `rogchap/v8go`；Rust `rquickjs` / `boa_engine`
**版本**：1.0rc（11 单元 pure.base 单源 352 行 + 5 gate 全绿，M3b 均值同步，与 CONTRACT 1.0rc/BENCHMARKS 1.3 对齐，18 份对齐）

---

## 评分卡（S1 目标）

| 维度 | 分 (0–10) | 说明 |
|------|-----------|------|
| **正确性 Correctness** | 目标 9 | QuickJS ES2020 语法全量，错误 `Category/Species/JsStack` 透传，`fake` 确定性语义 |
| **可用性 Usability** | 目标 8 | `CreateJsRuntime → NewContext → Eval` 一行式，宿主三形态，`TryEval` 分叉，`NewJson/ToJson` |
| **性能 Performance** | 目标 7 | `Eval('1+2') ≤50µs` FFI 路径，`fake` ≤10µs，`bench_eval` 基线落库 |
| **可测性 Testability** | 目标 9 | `fake` 零依赖 CI 必跑，`quickjs_runtime` 探测隔离 |
| **可移植性 Portability** | 目标 8 | `libquickjs.so.1/0` 幂等探测，`pure` 后端兜底 Deferred |
| **综合** | — | S1 后以 `bench_eval` 实测复核 |

---

## Essential 矩阵

| 能力 | Go `goja` / `v8go` | Rust `rquickjs` / `boa` | nextpas S1 目标 | 状态 |
|------|-------------------|-----------------|----------------|------|
| 无窗 Eval | `goja.RunString` / `v8go.RunScript` | `rquickjs::Context::eval` | `IJsContext.Eval/TryEval` | 目标 |
| 宿主函数 | `Set(name, func)` | `ctx.globals().set` | `SetHostFunction` 三形态 | 目标 |
| 超时中断 | `Interrupt`（goja）/ `TerminateExecution`（v8go） | `set_interrupt_handler` | `TJsRuntimeOptions.TimeoutMs` + `JS_SetInterruptHandler` | 目标 |
| 内存限 | — | `set_memory_limit` | `MemoryLimit` | 目标 |
| JSON 互通 | `Marshal` / `JSON.stringify` | `serde` | `NewJson/ToJson` 经 `json` owner | 目标 |
| Value 模型 | `goja.Value` 统一接口 | `rquickjs::Value` 克隆 | `TJsValue` record + `IJsValueRef` 双层 | 目标 |
| ES Module | `require`（goja） | `module`（rquickjs） | Deferred（VFS 触发） | Deferred |
| Worker | — | — | Deferred | Deferred |
| Inspector | — | `inspector` | Deferred | Deferred |

---

## 差异与诚实 residual

- `goja` 纯 Go 无 FFI，闭环但 ES2020 子集；`js` QuickJS 需 `libquickjs.so`（`JsBackendAvailable` 探测，不可用时 `fake`），但 ES2020 全量。
- `v8go` 需 `libv8` 多版本，体积大；`js` V8 为后续尾部追加，不在 S1，避免首版超重。
- Rust `rquickjs` 的 `Async` 调度与 `js.Tick` 同“需驱动”语义，非自动；`js` 同纪律（`Tick` 幂等）。
- `boa` 纯 Rust，零 FFI，但性能低于 QuickJS C；`js` 的 `pure` 后端同 deferred 定位。
- `js` 的 `TJsValue` 双层借用视图为 Pascal 特化，Go/Rust 无直接对应，但语义等价于 `TJsonValue` 借用。

---

## 基准对照（S1 后落库）

| 场景 | nextpas 目标 | Go `goja` 参考 | Rust `rquickjs` 参考 |
|------|--------------|----------------|---------------------|
| `Eval('1+2')` | ≤50µs（QuickJS）/ ≤10µs（fake） | ~30µs | ~20µs |
| `HostFunction` 往返 | ≤5µs | ~5µs | ~3µs |
| `AsJson` 互转 | 待测 | — | — |

> S1 后以 `bench_eval`（`nextpas.core.bench` 框架）在 `-O2` 下实测刷新本表。

---

## 测试入口（S1）

```bash
make focused FOCUS=core/tests/nextpas.core.js/test_js_fake
make focused FOCUS=core/tests/nextpas.core.js/test_js_quickjs_runtime   # 需 libquickjs
make -C core/benchmarks/nextpas.core.js/bench_eval run
```

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-30 | 0.2 | 初版矩阵 |
| 2026-08-30 | 0.3 | 生产级：评分五维/基准对照/残差显式化 |
| 2026-08-30 | 0.4 | 冻结：版本对齐 12 份完整 |
| 2026-08-30 | 0.7 | 实测：bench_eval 5 后端（fake 164ns / js888 194ns / v8 170ns / chakra 200ns）全绿，目标 ≤10µs 达成 |
| 2026-08-31 | 0.8 | 11 单元 pure.base 单源 338 行 + V8/Chakra Close 幂等 + 5 gate 全绿，18 份对齐 |
| 2026-08-31 | 0.9 | M3b 同步：BENCHMARKS Eval/small 5 后端刷新（179/633/1089/962/SKIP）+ Value/ops 零分配同步 + 纯族 338 行体量阈值内标注（18 份对齐） |
| 2026-08-31 | 0.10 | 文档完整性修复：BENCHMARKS 1.3 同步实测均值 ~660ns（645/660/631/660）/ host ~1.5µs 加权 / B/op 18/176 + pure.base 352 行阈值550内统一，18 份对齐 |
| 2026-08-31 | 1.0rc | 冻结候选：距1.0仅文档版本滞后，CONTRACT/DESIGN 0.10→1.0rc，BENCHMARKS 1.3 保持，其余引用同步 1.0rc，18份对齐 |
