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

| 域 | 用例 | 断言 | 追溯 |
|----|------|------|------|
| 值语义 | `Is*` 全类型、`As*` 安全默认、`TryAs*` 分叉 | `Kind` 正确，非法 `As*` 零值，`TryAs*` false | INV-7 |
| Eval | `1+2=3`、`JSON` 互转、`TryEval` 分叉、`TryEvalFile`（经 `fs.path.Abs`） | 成功值 + 失败 false + `jskUndefined` | INV-4/5 |
| 错误 | `SyntaxError→jecSyntax` 等 6 类 + `Species/JsStack` 透传 | Category 归一，Species 非空 | CONTRACT §4 |
| 宿主 | `SetHostFunction` 三形态、`this/args`、`RemoveHostFunction`、空 `AArgs` 切片零分配 | 三形态等价，`AArgs` 切片正确，`B/op=0` | INV-6, R-2 |
| 线程 | 跨线程 `Eval` fail-fast（debug 断言 / release 抛） | `EJsError(jecUnknown)` | CONTRACT §7 |
| 悬垂 | `Context` 释放后 `TJsValue.IsValid=false`、`Close` 幂等二次 no-op | `As*` 零值，`TryAs*` false，二次 `Close` 不抛 | INV-7, S-3 |
| 超时/内存 | `TimeoutMs` 中断、`MemoryLimit` fail-closed（fake 模拟原子 DeadlineMs） | `EJsTimeout`/`EJsMemoryLimit` | CONTRACT §7 |
| Tick/GC | `Tick` 幂等、`CollectGarbage` 幂等、`IsClosed` 后除 `Close` 外抛 | 多次调用不崩，`IsClosed=True` 后 `Eval` 抛 | S-3 |
| 零分配 | `TJsValue.AsString` 快路径 `B/op=0`（`nextpas.core.bench` `B/op`） | `bench_value` 断言 `BytesPerOp=0` | P-3 |
| 复用 | `fake` 作为通用 test double 注入 `config/template`（非仅 webview） | 同契约走 `fake` 绿 | R-2 |

> **INV→用例映射**（`SIXDIM S-1`）：`INV-1` 由 `source-contract` 扫描守（`grep`），`INV-2` 由 FFI 纯度扫描，`INV-3` 由枚举稳定性回归，`INV-4` 由 Eval/TryEval 分叉，`INV-5` 由 `NewJson/ToJson` 互转，`INV-6` 由宿主重入/并发 fail-fast，`INV-7` 由悬垂矩阵。

---

## 4. 边界与失败路径（必测）

| 输入 | 期望 | 备注 |
|------|------|------|
| `AName=""` 或 `a..b` 非法 | `EJsError(jecSyntax)` |  |
| `AArgs=[]` 空参 | `AsString` 安全默认，`B/op=0` | P-3 零分配 |
| `Eval("bad(")` 语法错 | `EJsError(jecSyntax)` + `JsStack` 非空 |  |
| `TryEvalFile("nope.js")` 不存在 | `False` | 路径经 `fs.path` 复用 |
| `IsClosed=True` 后 `Eval` | `EJsError(jecUnknown)` |  |
| `IsClosed=True` 后 `Close` 二次 | no-op 不抛，`IsClosed` 仍 `True` | S-3 幂等 |
| `MemoryLimit=0`（不限） | 不抛 |  |

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

