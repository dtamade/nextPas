# nextpas.core.js 目标树

**Owner**：`codex/core-js`
**层级**：L2
**关联**：`CONTRACT.md`（冻结面）、`ROADMAP.md`（执行）、`ACCEPTANCE.md`（验收）
**版本**：0.4（S0 冻结）

---

## S0 文档冻结（当前）

- 产出：18 份完整（`README/CONTRACT/DESIGN/GOAL_TREE/WEBVIEW_LINK/PARITY` 0.5 + `ROADMAP/ACCEPTANCE/AI_GUIDE/TESTING/SECURITY/BENCHMARKS/REVIEW/SIXDIM_REVIEW/CHANGELOG/GAME888_BORROW/FAQ/DECISIONS` 1.0；纯后端可插拔保证见 `DESIGN §9`）
- 门禁：`ACCEPTANCE G-M0` 18 份全绿 + `make hygiene` pass + `SIXDIM P0` 清零，不改 `core-module-registry`
- 完成标志：`REVIEW H1–H3` 清零 + `SIXDIM P0` 6 项清零，18 份互链闭环
- 证据：`git diff --check` 0 + `ls core/docs/js/*.md | wc -l` 18

---

## S1 首个源码家族（7 单元 + 假后端）

| 目标 | 内容 | 门禁 | 证据 |
|------|------|------|------|
| `js.base` | `TJsBackendKind(jsbkQuickJs,jsbkFake)`、`TJsValueKind`、`EJsError` 族、`TJsRuntimeOptions` | `source-contract` INV-1/INV-3 | `check_source_contracts.py` pass |
| `js.intf` | `IJsRuntime/IJsContext/TJsValue/IJsValueRef`、宿主三形态、`Tick` | 同上 | `fpc -vh` 0 hint |
| `js.fake` | 确定性 `Eval('1+2')=3`、`TryEval` 分叉、错误 `Category/Species`、超时/内存限模拟 | `focused-runtime(fake)` 全绿 | `test_js_fake` + `heaptrc 0` |
| `js.quickjs.ffi/loader/quickjs` | `libquickjs.so.1/0` 探测、`JS_Eval/Call/Interrupt` 真链路、超时/内存限 | `test_js_quickjs_runtime`（探测到才跑） | `NEXTPAS_JS_QUICKJS_REQUIRED=1` 强制 |
| 门面 | `CreateJsRuntime/JsBackendAvailable` re-export | `source-contract` 层级单向 | `hygiene` 0 |
| 文档 | `CONTRACT 1.0` 冻结、`PARITY` 初版、`bench_eval` 骨架 | `hygiene` | `bench_eval` 可编译 |

**注册**：`core-module-registry.md` 新增 `js L2 source-contract + focused-runtime(fake)`，`quickjs` 运行时为 `S1-runtime` 增量，`bench_eval` 基线待落库。

**测试布局**（`design-conventions §12`）：

```
core/tests/nextpas.core.js/
  test_js_base/              # base 类型与错误族
  test_js_fake/              # 契约全量走 fake
  test_js_quickjs_runtime/   # 真链路
core/benchmarks/nextpas.core.js/bench_eval/
core/examples/nextpas.core.js/demo_js/
```

---

## S2 联动与加固

| 目标 | 内容 | 触发 |
|------|------|------|
| `webview` 适配 | `webview.fake` 可选 `JsContext` 注入，`Eval` 仍经 `Dispatcher.Post` 异步兑现，守 `exactly-once` | `webview.fake` 需真语义回归 |
| `json` 互通 | `NewJson/ToJson` 全量，`bench_eval` 含 `AsJson` ns/op | `json` 消费方联调 |
| 加固 | 超时中断精确性、`TJsValue` 悬垂 `IsValid` 模糊、宿主循环引用用例 | S1 回归 |

门禁：`webview` 13 门 + `js` 3 门双绿，`bench_eval` 基线落库。

---

## S3 后端扩展（尾部追加，**纯 Pas 保证**）

| 目标 | 内容 | 条件 | 保证 |
|------|------|------|------|
| `js.js888` | 纯 Pascal 后端（零 so/零 FFI/零 dl），`jsbkJs888` 尾部追加，`js.intf` 零改动，同契约 `Eval/TryEval/宿主/JSON/超时` 全绿 | 零依赖闭环需求 | `js.base/intf` 不动，仅 `+js.js888.pas` + `+jsbkJs888` + 工厂分支（见 `DESIGN §9`） |
| `js.v8.ffi/loader/v8` | V8 C++ 桥（`libv8.so`），`jsbkV8` 尾部追加，`TerminateExecution` 语义 | 性能需求 | 同尾部纪律 |

纪律：枚举尾部追加，序号稳定；`ffi` 无逻辑，`loader` 唯一 `platform.dl`；**纯后端与 `fake` 同约束**（禁 `platform.dl/ffi`），`TJsValue` 不透明已隔离 QuickJS `JSValue`。

---

## S4 高级能力（Deferred 触发）

- ES Module / import map / VFS（首个 `import` 消费方）
- Promise 调度显式化（真 `await` 消费方）
- Worker / Inspector（多线程/诊断需求）

未触发前不占位，不留半成品接口（`CONTRACT §12`）。

---

## 晋升门槛

| 级别 | 条件 | 证据 |
|------|------|------|
| `source-contract` | `base/intf` 不含后端符号（含纯后端预留，不暴露 `JSValue`），`ffi` 无逻辑，`loader` 唯一 `platform.dl`，`js.js888` 禁 `platform.dl` | `check_source_contracts.py` pass |
| `focused-runtime` | `test_js_fake` + `test_js_base` 全绿 + `heaptrc 0` | `make focused` 全绿 |
| `S1-runtime` | `test_js_quickjs_runtime`（有库）全绿；`S3` 后 `test_js_js888_runtime` 恒绿（零 so） | 本地 + Linux CI |
| `Production Ready` | `S2` 联动全绿 + `bench_eval` 基线落库（含纯/QuickJS 双基线） + `hygiene/source-contract` 双 pass | 13+3 门 + bench |

---

## 非目标

- 替代 `webview` 的渲染 JS（带窗场景仍走 `webview`）
- 浏览器完整 `window/document` 环境（无 DOM）
- 同步 `webview.Eval`（禁止，`webview CONTRACT §4`）

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-30 | 0.2 | 初版 S0–S4 |
| 2026-08-30 | 0.3 | 生产级：门禁证据/测试布局/晋升证据显式化 |
| 2026-08-30 | 0.4 | 冻结：12 份完整化，S0 产出与门禁对齐 ACCEPTANCE G-M0 |
