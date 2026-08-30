# nextpas.core.js 代码契约（S0 草案）

**模块路径**：`core/src/nextpas.core.js*.pas`（S1 目标 7 单元）
**层级**：L2（只依赖 L0–L1；`webview` 等 L3 可依赖本模块）
**Owner**：`codex/core-js`
**最后更新**：2026-08-30
**版本**：0.1（S0 文档设计，未冻结）

---

## 1. 源文件与职责（S1 目标）

| 单元 | 职责 |
|------|------|
| `js.base` | `TJsBackendKind`、`TJsValueKind`、`TJsErrorCategory`、`TJsRuntimeOptions`、`EJsError` 载体 |
| `js.intf` | `IJsRuntime` / `IJsContext` / `TJsValue` / `IJsValueRef` / `TJsHostFunction` 契约 |
| `js.fake` | 纯 Pascal 假后端（零外部依赖，CI 必跑） |
| `js.quickjs.ffi` | QuickJS C ABI 声明（`cdecl external`，无逻辑） |
| `js.quickjs.loader` | `platform.dl` 探测与符号装载（唯一可触 `platform.dl`） |
| `js.quickjs` | QuickJS 真实现（`uses ffi/loader`） |
| `js.pas` | 门面：re-export + 工厂 `CreateJsRuntime / JsBackendAvailable` |

依赖方向：`base ← intf ← {fake, quickjs.ffi←loader←quickjs} ← 门面`。

> `js.quickjs.pure` / `js.v8.*` 为后续尾部追加，不在 S1 公开枚举与门面占位。

---

## 2. 核心类型（`js.base`）

```pascal
TJsBackendKind = (jsbkQuickJs, jsbkFake); // S1 仅二值；后续尾部追加 jsbkV8/jsbkQuickJsPure
TJsValueKind = (jskUndefined, jskNull, jskBoolean, jskNumber, jskString, jskObject, jskArray, jskFunction, jskError, jskPromise);
TJsErrorCategory = (jecSyntax, jecReference, jecType, jecRange, jecMemory, jecTimeout, jecNotSupported, jecUnknown);
TJsRuntimeOptions = record
  MemoryLimit: SizeUInt; // 0=不限；QuickJS JS_SetMemoryLimit
  TimeoutMs: Integer;    // 0=不限；经 JS_SetInterruptHandler 异步中断
  class function Default: TJsRuntimeOptions; static;
end;

EJsError = class(ENextPasError)
  property Category: TJsErrorCategory;
  property Species: string;  // "SyntaxError"/"ReferenceError" 原文透传
  property JsStack: string;  // 引擎栈文本
  property Backend: TJsBackendKind;
end;
EJsBackendUnavailable = class(EJsError); // 探测不到 so/dll
EJsTimeout = class(EJsError);
```

**校验**：`TJsRuntimeOptions` 字段 `>=0`，非法抛 `EJsError(jecUnknown)`；`MemoryLimit` 超限 fail-closed。

---

## 3. 接口契约（`js.intf`）

对外一律 interface（COM 引用计数）+ 值语义 `TJsValue` record 双层（抄 `json` 双层：`TJsonValue` 借用视图 + `IJsonDocument` 寿命锚）。

### 3.1 值语义

```pascal
TJsValue = record // 轻量句柄，16 字节以内，零接口开销；寿命绑所属 IJsContext
  function Kind: TJsValueKind;
  function IsUndefined/IsNull/IsBool/IsNumber/IsString/IsObject/IsArray/IsFunction/IsError: Boolean;
  function AsBool: Boolean; function AsDouble: Double; function AsString: string;
  function AsJson: string; // 经 json.builder 转义，不手写拼接
  // 便捷出参
  function TryAsBool(out V: Boolean): Boolean;
end;

IJsValueRef = interface // ergonomic 自动 Dup/Free 包装，存 TJsValue 句柄
  function Value: TJsValue;
end;
```

`TJsValue` 持 `JSValue` 句柄 + 所属 `IJsContext` 弱引用，`Dup/Free` 由 `IJsValueRef` 或手动 `Ctx.Retain/Release` 管理；`Ctx` 释放后一切 `TJsValue` 失效（fail-fast）。

### 3.2 运行时与上下文

```pascal
IJsRuntime = interface
  ['{...}']
  function Kind: TJsBackendKind;
  function NewContext: IJsContext;
  procedure SetMemoryLimit(ALimit: SizeUInt);
end;

IJsContext = interface
  ['{...}']
  function Runtime: IJsRuntime;
  function Eval(const ACode: string; const AFileName: string = ''): TJsValue; // 同步抛 EJsError
  function TryEval(const ACode: string; out AValue: TJsValue): Boolean;       // 失败返回 False
  function NewString(const AStr: string): TJsValue;
  function NewObject: TJsValue;
  function Global: TJsValue;
  function GetProp(const AObj: TJsValue; const AName: string): TJsValue;
  procedure SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue);
  procedure SetHostFunction(const AName: string; AHandler: TJsHostFunction); overload;
  procedure SetHostFunction(const AName: string; AHandler: TJsHostMethod); overload;
  procedure SetHostFunction(const AName: string; AHandler: TJsHostProc); overload;
  procedure Tick; // 驱动 QuickJS pending jobs / V8 microtasks；无头场景幂等
  procedure CollectGarbage;
end;

TJsHostFunction = reference to function(ACtx: IJsContext; AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
TJsHostMethod   = function(ACtx: IJsContext; AThis: TJsValue; const AArgs: array of TJsValue): TJsValue of object;
TJsHostProc     = function(ACtx: IJsContext; AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
```

**宿主函数**执行在 `IJsContext` 所属线程（QuickJS 线程亲和），抛异常自动转 `EJsError`；`AArgs` 切片零拷贝视图，不隐式构造 `interface` 数组。

### 3.3 工厂

```pascal
function CreateJsRuntime(AKind: TJsBackendKind = jsbkQuickJs; const AOptions: TJsRuntimeOptions = Default): IJsRuntime;
function JsBackendAvailable(AKind: TJsBackendKind): Boolean; // 探测 so/dll 存在性
function DefaultJsRuntimeOptions: TJsRuntimeOptions; inline;
```

---

## 4. 错误与失败契约

| API | 失败行为 |
|-----|----------|
| `CreateJsRuntime(jsbkQuickJs)` 探测不到库 | 抛 `EJsBackendUnavailable`（含探测名表） |
| `IJsContext.Eval` 语法/运行时错误 | 抛 `EJsError`，`Category` 归一（`jecSyntax/jecReference/jecType/jecRange`），`Species/JsStack` 透传 |
| `TryEval` | 失败 `False`， `AValue=jskUndefined`，不抛 |
| 超时/内存限 | `EJsTimeout` / `EJsError(jecMemory)`，`Tick` 后可恢复或需重建 `Context` |
| 非法 `TJsValue` 访问 | 安全默认（`AsInt=0/AsStr=''`），不抛；`TryAs*` 显式分叉 |

---

## 5. Lifetime / 所有权

- `IJsRuntime / IJsContext / IJsValueRef`：COM 引用计数，出作用域自动 `JS_FreeContext/FreeRuntime/FreeValue`。
- `TJsValue`：借用所属 `IJsContext` 堆句柄，`Context` 必须活过所有 `TJsValue` 使用；跨线程传递前先经 `IJsValueRef` 桩化或 `AsJson` 序列化。
- `Tick / CollectGarbage`：幂等；`Context.Close` 后一切方法抛 `EJsError(jecUnknown)`。

---

## 6. 不变量

- **INV-1** `base/intf` 不出现任何后端 `ffi/loader` 符号（source-contract 冻结）。
- **INV-2** `*.ffi` 只含 `cdecl external` 声明，不含逻辑；`*.loader` 唯一可触 `platform.dl`，禁止 `DynLibs`。
- **INV-3** `TJsBackendKind` 尾部追加纪律：新后端只在末尾加，保持序号稳定（`db.TDbKind` 同纪律）。
- **INV-4** `Eval` 同步 exactly-once：成功得 `TJsValue`，失败抛 `EJsError`；无同步 `Eval` 的异步变体（`webview.Eval` 的异步是 IPC 特化，不在本模块）。
- **INV-5** 序列化一律经 `json` owner，不手写字符串扫描。

---

## 7. 依赖边界

- 允许：`base`、`errors`、`json`、`text.view/builder`、`mem`、`platform.dl`（仅 loader）
- 禁止：`L3` 任何模块（`http/webview/tui`）反向依赖；`*.ffi` 外的生产单元出现 `Windows/BaseUnix/DynLibs`

---

## 8. 测试门禁（S1）

| 门禁 | 载体 | 要求 |
|------|------|------|
| 契约测试（CI 必跑） | `tests/nextpas.core.js/test_js_*` 全走 `fake` | `Eval` round-trip、类型判断、`TryEval` 分叉、宿主函数 `this/args`、错误 `Category/Species`、`Tick` 幂等 |
| 运行时（本地/Linux） | `test_js_quickjs_runtime` | 探测到 `libquickjs.so*` 才跑；`1+2=3`、`JSON` 互转、超时中断、`webview` 桥脚本 dry-run |
| source-contract | `tests/architecture/source_contracts` | INV-1/INV-2、L2 层级单向依赖 |
| benchmark | `benchmarks/nextpas.core.js/bench_eval` | `Eval` ns/op、`HostFunction` 往返（`nextpas.core.bench` 框架） |

---

## 9. Deferred 登记簿

| 能力 | 类别 | 触发条件 |
|------|------|----------|
| ES Module / import map / VFS 资源加载 | deferred-Mod | 首个需 `import` 的消费方出现 |
| V8 后端 / QuickJS 纯 Pascal 后端 | deferred-Backend | 性能或零依赖闭环需求出现 |
| Promise/async 显式 `Tick` 策略扩展 | deferred-Runtime | 真 `await` 消费方出现 |
| Worker/SharedArrayBuffer | deferred-Thread | 多线程脚本需求出现 |

规则：Deferred ≠ 计划内；触发前不占位、不留半成品接口。
