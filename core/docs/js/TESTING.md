# nextpas.core.js 测试契约

**Owner**：`codex/core-js`
**关联**：`CONTRACT.md §10`（门禁）、`ACCEPTANCE.md`（DoD）、`AI_GUIDE.md`（生成规范）、`design-conventions §12`（组织）
**版本**：1.0
**最后更新**：2026-08-30

---

## 1. 测试组织

```
core/tests/nextpas.core.js/
  test_js_base/              # TJsBackendKind / TJsValueKind / TJsRuntimeOptions / EJsError 族
  test_js_fake/              # 契约全量（CI 必跑，零外部依赖）
  test_js_quickjs_runtime/   # 真 QuickJS（需 libquickjs，探测隔离）
core/benchmarks/nextpas.core.js/
  bench_eval/                # Eval / HostFunction / JSON 互转（nextpas.core.bench）
core/examples/nextpas.core.js/
  demo_js/                   # 1+2 / echo / JSON 三段最小 demo
```

每个测试/基准/示例为独立 `.lpr`，各自 `Makefile` 含 `clean` + `test`（或 `run`）。

---

## 2. 框架

| 项 | 要求 |
|----|------|
| 单元测试 | `nextpas.core.test`（`TTestSuite + TSuiteRunner + Check*/SoftCheck*`），禁止手写 runner |
| 基准 | `nextpas.core.bench`（`IBenchSuite + IBenchContext`），禁止 `GetTickCount64` 自计时 |
| 入口 | `.lpr` 标准模板（见 `design-conventions §12`），`Halt(1)` on fail |

---

## 3. 覆盖矩阵（`test_js_fake` 40+ 用例）

| 域 | 用例 | 断言 |
|----|------|------|
| 值语义 | `Is*` 全类型、`As*` 安全默认、`TryAs*` 分叉 | `Kind` 正确，非法 `As*` 零值，`TryAs*` false |
| Eval | `1+2=3`、`JSON` 互转、`TryEval` 分叉、`TryEvalFile` | 成功值 + 失败 false + `jskUndefined` |
| 错误 | `SyntaxError→jecSyntax` 等 6 类 + `Species/JsStack` 透传 | Category 归一，Species 非空 |
| 宿主 | `SetHostFunction` 三形态、`this/args`、`RemoveHostFunction` | 三形态等价，`AArgs` 切片正确 |
| 线程 | 跨线程 `Eval` fail-fast | `EJsError(jecUnknown)` |
| 悬垂 | `Context` 释放后 `TJsValue.IsValid=false` | `As*` 零值，`TryAs*` false |
| 超时/内存 | `TimeoutMs` 中断、`MemoryLimit` fail-closed（fake 模拟） | `EJsTimeout`/`EJsMemoryLimit` |
| Tick/GC | `Tick` 幂等、`CollectGarbage` 幂等、`IsClosed` 后抛 | 多次调用不崩 |

---

## 4. 边界与失败路径（必测）

| 输入 | 期望 |
|------|------|
| `AName=""` 或 `a..b` 非法 | `EJsError(jecSyntax)` |
| `AArgs=[]` 空参 | `AsString` 安全默认 |
| `Eval("bad(")` 语法错 | `EJsError(jecSyntax)` + `JsStack` 非空 |
| `TryEvalFile("nope.js")` 不存在 | `False` |
| `IsClosed=True` 后 `Eval` | `EJsError(jecUnknown)` |
| `MemoryLimit=0`（不限） | 不抛 |

---

## 5. 内存与泄漏

- 编译标志：`-gh -dHEAPTRC_ACTIVE`
- 门禁：`0 unfreed memory blocks`（所有 focused 套件）
- 追踪分配器：`TJsRuntimeOptions` 超限路径需 heaptrc 0

---

## 6. CI 矩阵

| 环境 | 运行 |
|------|------|
| Linux CI（无 libquickjs） | `test_js_base` + `test_js_fake` 必绿，`quickjs_runtime` SKIP |
| Linux 本地（有 libquickjs） | 全量绿（含 `quickjs_runtime` + `bench_eval`） |
| 无库强制 | `NEXTPAS_JS_QUICKJS_REQUIRED=1` 时 SKIP 视为 fail |

---

## 7. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-30 | 1.0 | 首版：组织 + 覆盖矩阵 + 边界 + CI |

