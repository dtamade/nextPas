# nextpas.core.js

> L2 抽象 JS 引擎：后端无关的 `IJsRuntime / IJsContext / TJsValue` 契约，QuickJS FFI 首落地，QuickJS 纯 Pascal 与 V8 后续可插拔。`webview` 等 L3 可在不反向依赖的前提下复用本契约。

**层级**：L2（系统能力，只依赖 L0–L1；`webview/config/template` 等 L3 可依赖本模块）
**Owner**：`codex/core-js` lane（`js` 家族）
**状态**：S0 文档冻结（12 份生产级，待 M1 源码）→ S1 目标 `source-contract + focused-runtime(fake)`
**最后更新**：2026-08-30
**版本**：0.5（S0 冻结，15 份完整，含 game888 借鉴与 FAQ/决策）

## 1. 模块定位

`js` 解决**脚本执行**，与 `json`（数据交换）、`webview`（带窗 JS 运行时）互补：

| 模块 | 解决 | 运行时 | 依赖 |
|------|------|--------|------|
| `json` | 数据序列化/反序列化 | 无 GC 堆，arena 借用视图 | L2 |
| `js` | 无窗脚本执行、宿主函数绑定、超时/内存限 | 每 `Runtime` 一 GC 堆，每 `Context` 一全局对象 | L2（本模块） |
| `webview` | 带窗 HTML/JS + 桥 `__npw.invoke` | WebKitGTK/WebView2/WK 各自引擎 | L3，**可选**依赖 `js` |

`js` 不替代 `webview` 的渲染 JS，而是为 `fake` 测试、无头规则、模板预编译、服务端脚本提供**可嵌入、可超时、可测**的 JS。

**设计对标**：`crypto` 多后端（pure/openssl）、`compress` 的 `lz4.ffi → lz4.native`、`db` 的 `sqlite/pg` 适配器同范式。

## 2. 家族布局（S1 目标 7 单元）

| 单元 | 职责 | 备注 |
|------|------|------|
| `nextpas.core.js.base` | `TJsBackendKind`、`TJsValueKind`、`TJsErrorCategory`、`TJsRuntimeOptions`、`EJsError` 载体 | 纯数据类型，零后端依赖 |
| `nextpas.core.js.intf` | `IJsRuntime` / `IJsContext` / `TJsValue` / `IJsValueRef` / `TJsHostFunction` 三形态 | 小接口+组合，引用计数自动释放 |
| `nextpas.core.js.fake` | 纯 Pascal 假后端（零外部依赖，CI 必跑） | 确定性语义，模拟超时/内存限 |
| `nextpas.core.js.quickjs.ffi` | QuickJS C ABI 声明（`cdecl external 'libquickjs'`） | 只含声明，不含逻辑 |
| `nextpas.core.js.quickjs.loader` | `platform.dl` 探测与符号装载 | 唯一可触 `platform.dl` 的单元 |
| `nextpas.core.js.quickjs` | QuickJS 真实现 | `uses ffi/loader`，实现 `intf` |
| `nextpas.core.js.pas` | 门面 re-export + 工厂 `CreateJsRuntime / JsBackendAvailable` | 纯聚合，不含逻辑 |

```
base ← intf ← {fake, quickjs.ffi ← loader ← quickjs} ← 门面
```

> `js.quickjs.pure` / `js.v8.ffi` / `js.v8` 为后续尾部追加，不在 S1 公开枚举与门面占位（`db.TDbKind` 尾部追加纪律）。新增后端只在 `TJsBackendKind` 末尾加，序号稳定。

**允许依赖**：`base`、`errors`、`exception`、`json`、`text`、`mem`、`platform.dl`（仅 loader）。
**禁止依赖**：`L3` 任何模块（`http/webview/tui`）反向依赖；`*.ffi` 外的生产单元出现 `Windows/BaseUnix/DynLibs/ctypes`。

## 3. 快速开始

### 3.1 基础求值

```pascal
uses nextpas.core.js;

var
  RT: IJsRuntime;
  CX: IJsContext;
  V: TJsValue;
begin
  RT := CreateJsRuntime(jsbkQuickJs); // 探测不到 libquickjs 时抛 EJsBackendUnavailable
  CX := RT.NewContext;
  V := CX.Eval('1+2');
  Assert(V.AsInt = 3);
  CX.Tick; // 空转幂等；有 Promise 时驱动 microtasks
end;
```

### 3.2 宿主函数绑定

```pascal
CX.SetHostFunction('echo',
  function(ACtx: IJsContext; AThis: TJsValue; const AArgs: array of TJsValue): TJsValue
  begin
    // AArgs[0] 是 JS 传入的首参，AsString 安全默认 ''，TryAs* 显式分叉
    Result := ACtx.NewString('got:' + AArgs[0].AsString);
  end);
WriteLn(CX.Eval('echo("hi")').AsString); // got:hi
```

三形态（`reference / of object / proc`）同 `design-conventions §8`，内部统一 `reference` 存储。`AName` 按 JS Identifier 校验（`^[A-Za-z_$][A-Za-z0-9_$]*(\.[A-Za-z_$][...])*`），非法抛 `EJsError(jecSyntax)`。

### 3.3 错误与超时

```pascal
try
  CX.Eval('foo(');
except
  on E: EJsError do
    WriteLn(E.Category, ' ', E.Species, ' ', E.JsStack); // jecSyntax SyntaxError ...
end;

RT := CreateJsRuntime(jsbkQuickJs, TJsRuntimeOptions.WithTimeout(50)); // 50ms 中断
try CX.Eval('while(true){}'); except on E: EJsTimeout do ... end;
```

### 3.4 JSON 互通（经 json owner）

```pascal
uses nextpas.core.json, nextpas.core.js;

var J: IJsonDocument; V: TJsValue;
J := JsonParse('{"x":1}');
V := CX.NewJson(J.Root);      // TJsonValue → TJsValue
J := CX.ToJson(V);            // TJsValue → IJsonDocument
```

序列化一律经 `json` owner，不手写转义（`INV-5`）。

### 3.5 TryEval 分叉（无异常路径）

```pascal
var V: TJsValue;
if not CX.TryEval('bad(', V) then
  WriteLn('parse failed, V=jskUndefined')
else
  WriteLn(V.AsString);
```

## 4. 架构速览

```
L2 js:  base(intf 无) → intf → {fake, quickjs.ffi←loader←quickjs} → 门面(js.pas)
L3 webview:  ... → {bridge,fake,gtk} → factory → 门面 ─(可选 uses)→ js.intf
              适配活在 webview 家族，js 永不 uses webview
```

- **双层值模型**：`TJsValue` record 轻量句柄（16B，零接口）+ `IJsValueRef` 自动根化（抄 `json` 的 `TJsonValue + IJsonDocument`）。
- **同步 Eval**：`js.Eval` 同线程同步，`webview.Eval` 异步 exactly-once，二者不混用；`webview.fake` 可选注入 `IJsContext` 时仍经 `Dispatcher.Post` 兑现。
- **FFI 纪律**：`*.ffi` 只含 `cdecl external`，`*.loader` 唯一可触 `platform.dl`，探测 `libquickjs.so.1 → .so.0 → quickjs` 幂等缓存。

详见 `DESIGN.md` 与 `CONTRACT.md §6/§9`。

## 5. 线程与生命周期

- `IJsRuntime / IJsContext` **线程亲和**：QuickJS `JSRuntime` 非线程安全，`IJsContext.Eval` 必须在创建线程调用；`webview` 侧 `Dispatcher.IsOnMainThread` 即 `JsContext` 所在线程。跨线程 `Eval` fail-fast 抛 `EJsError(jecUnknown)`。
- `TJsValue` 借用所属 `IJsContext` 堆句柄，`Context` 必须活过所有 `TJsValue` 使用；跨线程前先 `AsJson` 或 `IJsValueRef` 桩化。
- `Tick / CollectGarbage` 幂等；`IsClosed=True` 后一切方法抛 `EJsError(jecUnknown)`。
- `SetHostFunction` 闭包寿命与 `IJsContext` 绑定；捕获 `IJsContext` 时需弱引用或作用域桩，避免循环引用。

## 6. 错误模型

| 场景 | 异常 | Category |
|------|------|----------|
| 探测不到库 | `EJsBackendUnavailable` | `jecUnknown`，消息含探测名表 |
| 语法/运行时 | `EJsError` | `jecSyntax/jecReference/jecType/jecRange`，`Species/JsStack` 透传 |
| 超时 | `EJsTimeout` | `jecTimeout` |
| 内存限 | `EJsMemoryLimit` | `jecMemory` |
| 非法值访问 | 安全默认 `0/''/False` | 不抛，`TryAs*` 分叉 |

归一：`SyntaxError→jecSyntax`、`ReferenceError→jecReference`、`TypeError→jecType`、`RangeError→jecRange`、`InternalError/OOM→jecMemory`、`Interrupt→jecTimeout`。

## 7. 安全

- `Eval` 不做沙箱 beyond `MemoryLimit / Timeout`；`SetHostFunction` 暴露面即攻击面，默认不暴露 `os/fs/process`。
- 二进制走 `TBytes` + `AsJson` base64（`encoding` owner），不做裸二进制帧。
- `MemoryLimit` 超限 fail-closed，不静默回收。

## 8. 测试与基准

```bash
# S1 契约（CI 必跑，零外部依赖）
make focused FOCUS=core/tests/nextpas.core.js/test_js_fake
make focused FOCUS=core/tests/nextpas.core.js/test_js_base

# S1 运行时（探测到 libquickjs 才跑）
make focused FOCUS=core/tests/nextpas.core.js/test_js_quickjs_runtime

# 源契约与卫生
make hygiene
python3 core/tests/architecture/check_source_contracts.py  # INV-1/INV-2/层级

# 基准（nextpas.core.bench 框架，禁自定义计时）
make -C core/benchmarks/nextpas.core.js/bench_eval run
```

门禁矩阵见 `CONTRACT.md §10`，性能目标 `Eval('1+2') ≤10µs fake / ≤50µs QuickJS`。

## 9. 与 webview 的联动

`js` 是 L2 底座，`webview` 是 L3 消费者。复用仅三处：**JSON 同源、错误码映射、`fake` 可选注入真语义**，适配活在 `webview` 家族，不进本家族。详见 `WEBVIEW_LINK.md`。

## 10. 文档索引（12 份完整）

| 文档 | 内容 | 关联 |
|------|------|------|
| `CONTRACT.md` | 公开 API、错误与不变量、依赖边界、测试/性能门禁（冻结候选） | `ACCEPTANCE` 验收 |
| `DESIGN.md` | 架构决策：为何 QuickJS 首选、双层值模型、FFI 纪律、取舍与风险 | `REVIEW` 决策 |
| `GOAL_TREE.md` | S0–S5 阶段目标与晋升门槛 | `ROADMAP` 执行 |
| `ROADMAP.md` | 里程碑 M0–M5、交付物、依赖图、风险、版本 | `ACCEPTANCE` DoD |
| `ACCEPTANCE.md` | DoD、门禁矩阵、证据链、晋升规则 | `ROADMAP` 退出条件 |
| `TESTING.md` | 组织、覆盖矩阵、边界、CI | `CONTRACT §10` |
| `SECURITY.md` | 威胁模型、缓解、攻击面 | `CONTRACT §8` |
| `BENCHMARKS.md` | 方法、套件、目标、回归阈值 | `CONTRACT §11` |
| `WEBVIEW_LINK.md` | 与 `webview` 的联动、时序图与 Deferred | `DESIGN §7` |
| `PARITY-go-rust.md` | Go `goja` / Rust `rquickjs/boa` 对标与残差 | `BENCHMARKS` |
| `GAME888_BORROW.md` | game888 借鉴审计（6 借鉴 + 4 不借鉴 + 静链/动探） | `DESIGN` |
| `FAQ.md` | 常见问题/运营/性能陷阱 | `CONTRACT/SECURITY` |
| `DECISIONS.md` | ADR-001–005 决策日志 | `DESIGN` |
| `AI_GUIDE.md` | 现代 AI 开发规范（agent/审查/验证） | 全模块 |
| `REVIEW.md` | 穿透式审查：H1–H3 硬差距 + N1–N7 幼稚病 | 0.3→0.4 依据 |

## 11. 稳定性与注册

- S0 仅文档，不承诺 API 冻结，不改 `core-module-registry.md`。
- S1 首个源码家族落地时以 `source-contract + focused-runtime(fake)` 入注册表，`focused-runtime` 以 `fake` 契约测试为准，`quickjs` 运行时为 `S1-runtime` 增量门禁，`Production Ready` 需 `S2` 联动 + `bench_eval` 基线落库。
- 公共 API 变更纪律：`intf` 视为冻结候选，改动必须过契约测试并更新 `CONTRACT.md`。

## 12. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-30 | 0.1 | 初稿（7 单元草图） |
| 2026-08-30 | 0.2 | 完整化：双层值语义、三形态宿主、超时中断、线程亲和 |
| 2026-08-30 | 0.3 | 生产级完整化：架构速览/错误表/安全/测试基准显式化 |
| 2026-08-30 | 0.4 | 冻结：12 份完整（ROADMAP/ACCEPTANCE/AI_GUIDE/TESTING/SECURITY/BENCHMARKS/REVIEW 补齐，索引闭环） |
| 2026-08-30 | 0.5 | 增补：15 份完整（GAME888_BORROW/FAQ/DECISIONS，DESIGN 反哺批处理/静链动探） |
