# nextpas.core.js 决策日志（ADR）

**Owner**：`codex/core-js`
**版本**：1.0
**最后更新**：2026-08-30

> 每条决策按 `ADR-编号：标题 — 状态` 记录，含上下文、决策、后果。

---

## ADR-001：双层值模型抄 json

- **状态**：已决
- **上下文**：全 `interface` 热循环 `AddRef/Release` 开销大
- **决策**：`TJsValue record(16B 借用) + IJsValueRef interface(寿命锚)`，抄 `json`
- **后果**：需 `IsValid/TryAs*` 守卫，测试冻结

## ADR-002：动探而非静链

- **状态**：已决
- **上下文**：game888 静链 `{$linklib quickjs}` 单二进制 vs 框架需多后端与 `fake` 兜底
- **决策**：`platform.dl` 动探 `libquickjs.so.1/0`，`JsBackendAvailable` 幂等
- **后果**：需 `libquickjs.so`，CI 用 `fake` 兜底；与 game888 对偶（`GAME888_BORROW.md §4`）

## ADR-003：同步 Eval vs 异步

- **状态**：已决
- **上下文**：`webview.Eval` 异步 exactly-once，`js` 无窗场景需同步
- **决策**：`js.Eval` 同步抛 `EJsError`，`webview.fake` 注入时仍经 `Dispatcher.Post` 异步兑现
- **后果**：二者不混用

## ADR-004：尾部追加枚举

- **状态**：已决
- **上下文**：`TJsBackendKind` 需可扩展 `jsbkV8/jsbkQuickJsPure` 而不破坏序号
- **决策**：尾部追加纪律（`db.TDbKind` 同款）
- **后果**：`source-contract` 冻结，新后端只在末尾加

## ADR-005：批处理 Deferred

- **状态**：已决
- **上下文**：game888 `ecs_batch_get/set` 降 FFI 开销
- **决策**：S1 不加 API，`>1000` 实体/帧热循环触发时加 `GetBatch/SetBatch`
- **后果**：首版零额外 API，性能触发时再加

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-30 | 1.0 | 首版 ADR-001–005 |

