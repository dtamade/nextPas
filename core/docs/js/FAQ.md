# nextpas.core.js FAQ / 运营手册

**Owner**：`codex/core-js`
**版本**：1.0
**最后更新**：2026-08-30

---

## 1. 常见问题

**Q: `CreateJsRuntime(jsbkQuickJs)` 抛 `EJsBackendUnavailable` 怎么办？**
A: 未安装 `libquickjs.so.1`。`JsBackendAvailable(jsbkQuickJs)` 先探，`False` 时回退 `jsbkFake`（CI）或提示安装。错误消息含探测名表。

**Q: `TJsValue` 能跨线程传吗？**
A: 不能。`TJsValue` 借用 `IJsContext` 堆句柄，跨线程前 `AsJson` 或 `IJsValueRef` 桩化。`IJsContext.Eval` 绑定创建线程，跨线程调用抛 `EJsError(jecUnknown)`。

**Q: 超时后还能用同一个 Context 吗？**
A: QuickJS 可以（`Tick` 后继续），V8 需重建 `Context`。契约显式区分，见 `CONTRACT §7`。

**Q: 为什么 `AsString` 不抛异常？**
A: 安全默认 `''`，失败路径用 `TryAsString` 分叉，避免热循环异常开销。

**Q: `fake` 和 `quickjs` 行为差异？**
A: `fake` 确定性语义（`1+2=3`、模拟超时/内存限），用于 CI 零依赖契约测试；`quickjs` 真 ES2020 语义，需 `libquickjs.so`。

---

## 2. 运营

| 项 | 操作 |
|----|------|
| 安装 QuickJS | `apt install libquickjs1` 或 `libquickjs-dev`（Debian），`JsBackendAvailable` 探测 `so.1→so.0` |
| CI | 默认 `fake` 全绿；`quickjs_runtime` 仅有库时跑，`NEXTPAS_JS_QUICKJS_REQUIRED=1` 强制 |
| 调试 | `EJsError.Species/JsStack` 透传；`console.log` 需宿主显式注册（Deferred） |
| 热重载 | 不在 `js` 内置，game888 的 `Watch/CheckAndReload` 为消费侧参考（`GAME888_BORROW.md`），`js` 触发条件为首个热重载消费方 |
| 升级 | `TJsBackendKind` 尾部追加，`CreateJsRuntime` 工厂一行切换 |

---

## 3. 性能陷阱

| 陷阱 | 规避 |
|------|------|
| 循环内 `IJsValueRef` 频繁 `AddRef/Release` | 用 `TJsValue` 轻量句柄，跨作用域再桩化 |
| `AArgs: array of TJsValue` 误当堆数组 | 切片视图，零拷贝，直接 `AArgs[0].AsString` |
| 大 JSON 手写拼接 | 必经 `json` owner `NewJson/ToJson` |

---

## 4. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-30 | 1.0 | 首版 |

