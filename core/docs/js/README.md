# nextpas.core.js

> 抽象 JS 引擎抽象层：后端无关的 `IJsRuntime / IJsContext / TJsValue` 契约，QuickJS FFI 首落地，QuickJS 纯 Pascal 与 V8 后续可插拔。`webview` 可在 L3 复用本契约而不反向依赖。

**层级**：L2（系统能力，只依赖 L0–L1；`webview` 等 L3 可依赖本模块）
**Owner**：`codex/core-js` lane（`js` 家族）
**状态**：S0 文档设计（无源码落地，registry 尚未注册）

## 为什么需要本模块

- **统一心智**：`json` 解决数据交换，`js` 解决脚本执行。两者互为桥：`TJsValue ⇄ JsonStringify/Parse` 经 `json` owner，不手写转义。
- **多后端**：QuickJS（轻量可嵌入）、QuickJS 纯 Pascal（后期零外部依赖）、V8（性能与现代语法）共享同一接口，消费方 `CreateJsRuntime(jsbkQuickJs)` 一行切换。
- **与 `webview` 联动**：`webview` 的 `__npw` 桥已有一套 JS 运行时（WebKitGTK/WebView2/WK）。`js` 不替代它，而是为 `fake` 测试、无头预检、规则脚本等提供**无窗 JS**，并在 `webview.fake` 中可选注入真语义（见 `WEBVIEW_LINK.md`）。

## 家族布局（S1 目标）

| 单元 | 职责 | 备注 |
|------|------|------|
| `nextpas.core.js.base` | `TJsBackendKind`、`TJsValueKind`、`TJsRuntimeOptions`、`EJsError` 载体 | 纯数据类型，禁止依赖后端 |
| `nextpas.core.js.intf` | `IJsRuntime` / `IJsContext` / `TJsValue` / `IJsValueRef` / 宿主回调契约 | 小接口+组合，引用计数自动释放 |
| `nextpas.core.js.fake` | 无头纯 Pascal 假后端（零外部依赖） | CI 必跑，确定性语义 |
| `nextpas.core.js.quickjs.ffi` | QuickJS C ABI 声明（`cdecl external 'qjs'`） | 只含声明，不含逻辑 |
| `nextpas.core.js.quickjs.loader` | `platform.dl` 探测与符号装载 | 唯一可触 `platform.dl` 的单元 |
| `nextpas.core.js.quickjs` | QuickJS 真实现 | `uses ffi/loader`，实现 `intf` |
| `nextpas.core.js.pas` | 门面 re-export + 工厂 `CreateJsRuntime / JsBackendAvailable` | 纯聚合，不含逻辑 |

依赖方向：`base ← intf ← {fake, quickjs.ffi←loader←quickjs} ← 门面`；`webview` 的可选适配活在 `webview` 家族，不进本家族。

> `quickjs.pure` 与 `v8.*` 为后续尾部追加枚举/单元，不在 S1 公开面预占位（`db.TDbKind` 尾部追加纪律）。

## 快速开始（S1 形态）

```pascal
uses nextpas.core.js;

var
  RT: IJsRuntime;
  CX: IJsContext;
  V: TJsValue;
begin
  RT := CreateJsRuntime(jsbkQuickJs); // 不可用时抛 EJsBackendUnavailable
  CX := RT.NewContext;
  V := CX.Eval('1+2');                 // 同步抛 EJsError，成功得 TJsValue
  WriteLn(V.AsInt);                    // 3
  CX.SetHostFunction('echo',
    function(ACtx: IJsContext; AThis: TJsValue; const AArgs: array of TJsValue): TJsValue
    begin
      Result := ACtx.NewString(AArgs[0].AsString);
    end);
  CX.Eval('echo("hello")');
end;
```

`TryEval` 供需分叉的调用方；`IJsValueRef` 供需自动 `Dup/Free` 的便捷路径（见 CONTRACT）。

## 与 webview 的关系

`js` 是 L2 底座，`webview` 是 L3 消费者。复用只在三处：JSON 同源、错误码映射、`fake` 可选注入真语义。详见 `WEBVIEW_LINK.md`。

## 文档索引

- `CONTRACT.md` — 公开 API、错误与不变量、测试门禁
- `WEBVIEW_LINK.md` — 与 `webview` 的联动设计与 Deferred 登记
- `PARITY-go-rust.md` — Go `goja` / Rust `rquickjs/boa` 对标（后续补）

## 稳定性

S0 仅文档，不承诺 API 冻结。S1 首个源码家族落地时以 `source-contract + focused-runtime(fake)` 入 `core-module-registry.md`。
