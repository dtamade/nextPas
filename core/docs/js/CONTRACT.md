# nextpas.core.js 代码契约

**模块路径**：`core/src/nextpas.core.js*.pas`（S1 目标 7 单元）
**层级**：L2（只依赖 L0–L1；`webview` 等 L3 可依赖本模块）
**Owner**：`codex/core-js`
**最后更新**：2026-08-30
**版本**：0.4（S0 冻结，12 份完整，待 M1 源码后晋升 1.0）

---

## 概要

无窗 JS 执行：以 `IJsRuntime / IJsContext` 承载 GC 堆与全局对象，`TJsValue` 轻量句柄 + `IJsValueRef` 自动根化双层值语义，宿主函数三形态绑定，`Eval/TryEval` 同步 exactly-once，超时/内存限可中断；后端首选 QuickJS FFI，纯 Pascal 与 V8 后续尾部追加。

**阅读顺序**：`README.md`（定位）→ 本契约（冻结面）→ `DESIGN.md`（决策）→ `ROADMAP.md`（执行）→ `ACCEPTANCE.md`（验收）→ `TESTING/SECURITY/BENCHMARKS`（方法）→ `AI_GUIDE`（执行纪律）。

---

## 1. 源文件与职责（S1 目标）

| 单元 | 职责 | 允许 uses | 禁止 |
|------|------|-----------|------|
| `js.base` | `TJsBackendKind`、`TJsValueKind`、`TJsErrorCategory`、`TJsRuntimeOptions`、`EJsError` 族 | `exception`、`errors`、`base` | 任何 `js.*`、`platform`、`json` |
| `js.intf` | `IJsRuntime` / `IJsContext` / `TJsValue` / `IJsValueRef` / `TJsHostFunction` 三形态 | `js.base`、`json.types`（仅 `TJsonValue` 类型引用） | `js.fake`/`js.quickjs.*`、`platform.dl` |
| `js.fake` | 纯 Pascal 假后端（零外部依赖，CI 必跑，确定性语义） | `js.base`、`js.intf`、`json` | `platform.dl`、`*.ffi` |
| `js.quickjs.ffi` | QuickJS C ABI 声明（`cdecl external 'libquickjs'`，无逻辑） | RTL + `js.base` 类型（若需） | `platform.dl`、逻辑、helper |
| `js.quickjs.loader` | `platform.dl` 探测与符号装载（唯一可触 `platform.dl`） | `platform.dl`、`js.base`、`js.quickjs.ffi` | `DynLibs`、`Windows/BaseUnix` |
| `js.quickjs` | QuickJS 真实现（`uses ffi/loader`，实现 `intf`） | `js.base/intf`、`js.quickjs.ffi/loader`、`json`、`mem` | `webview.*` |
| `js.pas` | 门面：re-export + 工厂 `CreateJsRuntime / JsBackendAvailable` | 上述全部子模块 | 逻辑（纯聚合） |

```
base ← intf ← {fake, quickjs.ffi ← loader ← quickjs} ← 门面
```

> `js.quickjs.pure` / `js.v8.ffi` / `js.v8` 为后续尾部追加，不在 S1 公开枚举与门面占位。新增后端只在 `TJsBackendKind` 末尾加，保持序号稳定（`db.TDbKind` 同纪律）。

**文件体积指引**：单单元 >800 行拆子模块（`design-conventions §2`）。

---

## 2. 核心类型（`js.base`）

```pascal
TJsBackendKind = (jsbkQuickJs, jsbkFake); // S1 仅二值；后续尾部追加 jsbkV8/jsbkQuickJsPure
TJsValueKind = (jskUndefined, jskNull, jskBoolean, jskNumber, jskString, jskObject, jskArray, jskFunction, jskError, jskPromise);
TJsErrorCategory = (jecSyntax, jecReference, jecType, jecRange, jecMemory, jecTimeout, jecNotSupported, jecUnknown);
TJsRuntimeOptions = record
  MemoryLimit: SizeUInt; // 0=不限；QuickJS JS_SetMemoryLimit / JS_SetGCThreshold
  TimeoutMs: Integer;    // 0=不限；经 JS_SetInterruptHandler 异步中断
  class function Default: TJsRuntimeOptions; static;
  class function WithMemoryLimit(ALimit: SizeUInt): TJsRuntimeOptions; static; inline;
  class function WithTimeout(ATimeoutMs: Integer): TJsRuntimeOptions; static; inline;
end;

EJsError = class(ENextPasError)
  property Category: TJsErrorCategory;
  property Species: string;  // "SyntaxError"/"ReferenceError"/"TypeError"/"RangeError" 原文透传
  property JsStack: string;  // 引擎栈文本，UTF-8
  property Backend: TJsBackendKind;
end;
EJsBackendUnavailable = class(EJsError); // 探测不到 so/dll，含探测名表
EJsTimeout            = class(EJsError); // 超时中断
EJsMemoryLimit        = class(EJsError); // 内存限
```

| 不变量 | 规则 |
|--------|------|
| `MemoryLimit` | `>0` 时经底层 `SetMemoryLimit`，超限抛 `EJsMemoryLimit(jecMemory)`，fail-closed |
| `TimeoutMs` | `>0` 时装 `InterruptHandler` + 原子 `DeadlineMs`，超时抛 `EJsTimeout(jecTimeout)`，`Tick` 后可恢复或需重建 `Context` |
| `CheckJsRuntimeOptions` | 负值（若经有符号 API 误传）抛 `EJsError(jecUnknown)`，不静默截断 |

---

## 3. 接口契约（`js.intf`）

对外一律 interface（COM 引用计数）+ 值语义 `TJsValue` record 双层（抄 `json` 双层：`TJsonValue` 借用视图 + `IJsonDocument` 寿命锚）。

### 3.1 值语义

```pascal
TJsValue = record // 轻量句柄，16 字节以内，零接口开销；寿命绑所属 IJsContext
  function Kind: TJsValueKind; inline;
  function IsUndefined: Boolean; inline; function IsNull: Boolean; inline;
  function IsBool: Boolean; inline; function IsNumber: Boolean; inline;
  function IsString: Boolean; inline; function IsObject: Boolean; inline;
  function IsArray: Boolean; inline; function IsFunction: Boolean; inline;
  function IsError: Boolean; inline; function IsPromise: Boolean; inline;
  function AsBool: Boolean;          // 非 bool → False（安全默认）
  function AsDouble: Double;         // 非 number → 0.0
  function AsInt: Int64;             // 非 number → 0
  function AsString: string;         // 非 string → ''
  function AsJson: string;           // 经 json.builder 转义，不手写拼接
  function TryAsBool(out V: Boolean): Boolean;
  function TryAsDouble(out V: Double): Boolean;
  function TryAsString(out V: string): Boolean;
  function IsValid: Boolean; inline; // 句柄是否有效（Context 未释放且非空）
end;

IJsValueRef = interface // ergonomic 自动 Dup/Free 包装，存 TJsValue 句柄
  ['{...}']
  function Value: TJsValue;
end;
```

- `TJsValue` 持 `JSValue` 句柄 + 所属 `IJsContext` 弱引用；`Dup/Free` 由 `IJsValueRef` 或 `Ctx.Retain/Release` 显式管理，`TJsValue` 析构不隐式 `Free`（record 无析构，靠 `IJsValueRef` 或作用域 `Retain` 桩）。
- `Context` 释放后一切 `TJsValue` 失效（`IsValid=False`，`As*` 安全默认，`TryAs*` → `False`）。

### 3.2 运行时与上下文

```pascal
IJsRuntime = interface
  ['{...}']
  function Kind: TJsBackendKind;
  function Options: TJsRuntimeOptions;
  function NewContext: IJsContext;
  procedure SetMemoryLimit(ALimit: SizeUInt); // 0=不限
  procedure SetTimeout(ATimeoutMs: Integer);  // 0=不限
  procedure CollectGarbage; // 全堆 GC，幂等
end;

IJsContext = interface
  ['{...}']
  function Runtime: IJsRuntime;
  function Eval(const ACode: string; const AFileName: string = ''): TJsValue; // 同步抛 EJsError
  function TryEval(const ACode: string; out AValue: TJsValue): Boolean;       // 失败 False
  function TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean; // 读文件后 Eval（fs 能力经 text.fs 间接）
  function Global: TJsValue; // 全局对象句柄，始终有效
  function NewString(const AStr: string): TJsValue;
  function NewInt(AValue: Int64): TJsValue;
  function NewDouble(AValue: Double): TJsValue;
  function NewBool(AValue: Boolean): TJsValue;
  function NewObject: TJsValue;
  function NewArray: TJsValue;
  function NewJson(const AJson: TJsonValue): TJsValue; // TJsonValue → TJsValue（经 json）
  function ToJson(const AValue: TJsValue): IJsonDocument; // TJsValue → IJsonDocument
  function GetProp(const AObj: TJsValue; const AName: string): TJsValue;
  procedure SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue);
  function Call(const AFunc: TJsValue; const AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
  procedure SetHostFunction(const AName: string; AHandler: TJsHostFunction); overload;
  procedure SetHostFunction(const AName: string; AHandler: TJsHostMethod); overload;
  procedure SetHostFunction(const AName: string; AHandler: TJsHostProc); overload;
  procedure RemoveHostFunction(const AName: string);
  procedure Tick; // 驱动 QuickJS pending jobs / V8 microtasks；无头场景幂等
  procedure CollectGarbage; // 当前 Context 触发 GC
  function IsClosed: Boolean;
end;

TJsHostFunction = reference to function(ACtx: IJsContext; AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
TJsHostMethod   = function(ACtx: IJsContext; AThis: TJsValue; const AArgs: array of TJsValue): TJsValue of object;
TJsHostProc     = function(ACtx: IJsContext; AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
```

**宿主函数**：
- 执行在 `IJsContext` 所属线程（QuickJS 线程亲和），抛异常自动转 `EJsError`（`Species` 透传）。
- `AArgs` 为切片视图，零拷贝，不隐式构造 `interface` 数组；高频路径可用 `AArgs[0].AsString` 直取。
- `AName` 按 JS Identifier 校验（`^[A-Za-z_$][A-Za-z0-9_$]*` 或 `a.b.c` 点路径展开为对象链），非法抛 `EJsError(jecSyntax)`，**不复用** `webview.base.CheckInvokeCmd` 的 `npw./_` 保留（见 WEBVIEW_LINK）。

### 3.3 工厂

```pascal
function CreateJsRuntime(AKind: TJsBackendKind = jsbkQuickJs;
  const AOptions: TJsRuntimeOptions = Default): IJsRuntime;
function JsBackendAvailable(AKind: TJsBackendKind): Boolean; // 探测 so/dll 存在性，幂等缓存
function DefaultJsRuntimeOptions: TJsRuntimeOptions; inline;
```

- `JsBackendAvailable` 幂等缓存探测结果，CI 无库时 `jsbkQuickJs=False`、`jsbkFake=True`。
- `CreateJsRuntime(jsbkQuickJs)` 探测不到时抛 `EJsBackendUnavailable`，消息含探测名表 `libquickjs.so.1 / libquickjs.so.0 / quickjs`。

---

## 4. 错误与失败契约

| API | 失败行为 |
|-----|----------|
| `CreateJsRuntime(jsbkQuickJs)` 探测不到库 | 抛 `EJsBackendUnavailable`（消息含探测名表 `libquickjs.so.1/0`） |
| `IJsContext.Eval` 语法/运行时错误 | 抛 `EJsError`，`Category` 归一（`jecSyntax/jecReference/jecType/jecRange`），`Species/JsStack` 透传 |
| `TryEval / TryEvalFile` 失败 | 返回 `False`，`AValue=jskUndefined`，不抛 |
| 超时/内存限 | `EJsTimeout` / `EJsMemoryLimit`，`Tick` 后可恢复或需重建 `Context` |
| 非法 `TJsValue` 访问 | 安全默认（`AsInt=0/AsStr=''`），不抛；`TryAs*` 显式分叉 |
| 宿主函数内抛 `EJsError` | 透为 JS `Error` 对象，`Eval` 侧同表归一 |
| 宿主函数内抛非 `EJsError` | 包装为 `EJsError(jecUnknown)`，`Species='Error'` |
| `IsClosed=True` 后调用 | 抛 `EJsError(jecUnknown)` |

`EJsError.Category` 归一表：`SyntaxError→jecSyntax`、`ReferenceError→jecReference`、`TypeError→jecType`、`RangeError→jecRange`、`InternalError/OOM→jecMemory`、`Interrupt→jecTimeout`。未匹配走 `jecUnknown`，`Species` 原样透传。

---

## 5. Lifetime / 所有权

- `IJsRuntime / IJsContext / IJsValueRef`：COM 引用计数，出作用域自动 `JS_FreeContext/FreeRuntime/FreeValue`。
- `TJsValue`：借用所属 `IJsContext` 堆句柄，`Context` 必须活过所有 `TJsValue` 使用；跨线程传递前先经 `IJsValueRef` 桩化或 `AsJson` 序列化。
- `Tick / CollectGarbage`：幂等；`IsClosed=True` 后一切方法抛 `EJsError(jecUnknown)`。
- `SetHostFunction` 绑定的闭包寿命与 `IJsContext` 绑定；闭包捕获 `IJsContext` 时需弱引用或作用域桩，避免循环引用（文档明示，`fake` 用例演示）。

---

## 6. 不变量

- **INV-1** `base/intf` 不出现任何后端 `ffi/loader` 符号（source-contract 冻结）。
- **INV-2** `*.ffi` 只含 `cdecl external` 声明，不含逻辑；`*.loader` 唯一可触 `platform.dl`，禁止 `DynLibs`。
- **INV-3** `TJsBackendKind` 尾部追加纪律：新后端只在末尾加，保持序号稳定（`db.TDbKind` 同纪律）。
- **INV-4** `Eval/TryEval` 同步 exactly-once：`Eval` 成功得 `TJsValue`，失败抛 `EJsError`；无异步变体（`webview.Eval` 的异步是 IPC 特化，不在本模块）。
- **INV-5** 序列化一律经 `json` owner，不手写字符串扫描。
- **INV-6** 宿主函数重入：宿主内再 `Eval` 同一 `Context` 允许（可重入），但禁止并发 `Eval`（线程亲和 fail-fast）。
- **INV-7** `TJsValue` 悬垂安全：`Context` 释放后 `IsValid=False`，`As*` 零值不抛，`TryAs*`→`False`。

---

## 7. 线程模型

- **线程亲和**：`IJsRuntime / IJsContext` 绑定创建线程，跨线程 `Eval` 抛 `EJsError(jecUnknown)`（debug 断言）。
- **中断**：`TimeoutMs>0` 时 `JS_SetInterruptHandler` 以原子 `DeadlineMs` 轮询；超时后 `Eval` 抛 `EJsTimeout`，`Tick` 后可继续或重建 `Context`（QuickJS 中断后堆仍可用，V8 需 `TerminateExecution`）。
- 与 `webview` 联动时：`webview.Dispatcher.IsOnMainThread` 即 `JsContext` 所在线程，`webview` 的异步 `Eval` 经 `Dispatcher.Post` 兑现，不与 `js` 的同步 `Eval` 混用。

---

## 8. 安全模型

- `Eval` 不做沙箱 beyond `MemoryLimit / Timeout`；`SetHostFunction` 暴露面即攻击面，默认不暴露 `os/fs/process`。
- 二进制走 `TBytes` + `AsJson` base64（`encoding` owner），不做裸二进制帧。
- `MemoryLimit` 超限 fail-closed，不静默回收。
- `TryEvalFile` 读文件受 `FORMAT_BULK_PARSE_MAX_BYTES`（`nextpas.core.format.limits`，默认 64 MiB）约束，超限抛 `EArgumentError`（与 `json` 同约束）。

---

## 9. 依赖边界

- 允许：`base`、`errors`、`exception`、`json`、`text.view/builder`、`mem`、`platform.dl`（仅 loader）
- 禁止：`L3` 任何模块（`http/webview/tui`）反向依赖；`*.ffi` 外的生产单元出现 `Windows/BaseUnix/DynLibs/ctypes`；`base/intf` 出现 `platform.dl` 或后端符号

**Source-contract 扫描**（`core/tests/architecture/check_source_contracts.py`）：

| 规则 | 扫描 | 失败判据 |
|------|------|----------|
| INV-1 | `grep -R "quickjs\|v8" core/src/nextpas.core.js.base.pas core/src/nextpas.core.js.intf.pas` | 命中即 fail |
| INV-2 | `grep -R "platform\.dl\|DynLibs" core/src/nextpas.core.js*.ffi.pas` | 非 loader 命中即 fail |
| L2 层级 | `import` 闭包不得含 `nextpas.core.webview/http/tui` | 命中即 fail |
| FFI 纯度 | `*.ffi` 不含 `implementation` 逻辑（仅 `interface` + `cdecl external`） | 含 `begin` 即告警 |

---

## 10. 测试门禁（S1）

| 门禁 | 载体 | 要求 | 证据 |
|------|------|------|------|
| 契约测试（CI 必跑） | `tests/nextpas.core.js/test_js_fake` + `test_js_base` | `Eval` round-trip、类型判断、`TryEval` 分叉、宿主函数 `this/args`、错误 `Category/Species`、`Tick` 幂等、悬垂 `IsValid` | `heaptrc 0 leaks` + `AllPassed` |
| 运行时（本地/Linux） | `test_js_quickjs_runtime` | 探测到 `libquickjs.so*` 才跑；`1+2=3`、`JSON` 互转、超时中断、`webview` 桥脚本 dry-run；未探测到输出 `SKIP` 且 `NEXTPAS_JS_QUICKJS_REQUIRED=1` 时 fail | 同上 |
| source-contract | `tests/architecture/source_contracts` | INV-1/INV-2、L2 层级单向依赖、INV-3 枚举稳定 | `check_source_contracts.py` pass |
| benchmark | `benchmarks/nextpas.core.js/bench_eval` | `Eval` ns/op、`HostFunction` 往返、`AsJson` 互转（`nextpas.core.bench` 框架，禁自定义计时） | `bench_eval` 基线落库（见 §11） |
| hygiene | `make hygiene` | 无产物散落、`grep -R TODO/FIXME` 0、`fpc -vh` 0 hint | `build-hygiene-check.sh` pass |

**测试组织**（`design-conventions §12`）：

```
core/tests/nextpas.core.js/
  test_js_base/        # TJsRuntimeOptions / TJsValueKind / EJsError 族
  test_js_fake/        # 契约全量走 fake
  test_js_quickjs_runtime/ # 真 QuickJS，需 libquickjs
core/benchmarks/nextpas.core.js/
  bench_eval/          # Eval + HostFunction + JSON 互转
core/examples/nextpas.core.js/
  demo_js/             # 1+2 / echo host / JSON roundtrip 最小 demo
```

**示例测试入口**：

```bash
make focused FOCUS=core/tests/nextpas.core.js/test_js_fake
make focused FOCUS=core/tests/nextpas.core.js/test_js_quickjs_runtime
make -C core/tests/nextpas.core.js/test_js_fake clean test
```

---

## 11. 性能目标（S1）

| 场景 | 目标 | 备注 |
|------|------|------|
| `Eval('1+2')` | ≤ 10µs（fake）/ ≤ 50µs（QuickJS FFI） | `nextpas.core.bench` 均值，`-O2` |
| `HostFunction` 往返 | ≤ 5µs | `SetHostFunction` + `Call` |
| `TJsValue.AsString` | 零分配快路径 | `jskString` 时直接视图 |

基线落库格式（`bench_eval` 输出）：`操作名 迭代 总耗时 单次ns/op 吞吐`，与 `bench` 框架对齐（禁手写计时）。S2 后与 `json` `AsJson` 链路对比。

---

## 12. Deferred 登记簿

| 能力 | 类别 | 触发条件 |
|------|------|----------|
| ES Module / import map / VFS 资源加载 | deferred-Mod | 首个需 `import` 的消费方出现 |
| V8 后端 / QuickJS 纯 Pascal 后端 | deferred-Backend | 性能或零依赖闭环需求出现 |
| Promise/async 显式调度扩展 | deferred-Runtime | 真 `await` 消费方出现 |
| Worker/SharedArrayBuffer | deferred-Thread | 多线程脚本需求出现 |
| 调试器 Inspector / SourceMap | deferred-Tooling | 诊断需求出现 |
| 自定义 `ArrayBuffer` 零拷贝 | deferred-Perf | 二进制高频路径出现 |

规则：Deferred ≠ 计划内；触发前不占位、不留半成品接口。

---

## 13. 稳定性与版本

- S0 仅文档，不承诺冻结，不改 `core-module-registry.md`。
- S1 首个源码家族落地时以 `source-contract + focused-runtime(fake)` 入注册表，`S1-runtime`（quickjs）为增量门禁，`Production Ready` 需 `S2` 联动 + `bench_eval` 基线落库。
- `intf` 视为冻结候选，改动必须过契约测试并更新本文档；`CONTRACT` 版本随实现晋升（0.3→1.0）。

---

## 变更记录

| 日期 | 版本 | 变更 | 作者 |
|------|------|------|------|
| 2026-08-30 | 0.1 | 初稿（7 单元草图） | codex/core-js |
| 2026-08-30 | 0.2 | 完整化：双层值语义、三形态宿主、超时中断、线程亲和 | codex/core-js |
| 2026-08-30 | 0.3 | 生产级完整化：uses 闭包表/源契约扫描/门禁证据/性能表/稳定性显式化 | codex/core-js |
| 2026-08-30 | 0.4 | 冻结：12 份完整化关联（ROADMAP/ACCEPTANCE/TESTING/SECURITY/BENCHMARKS/AI_GUIDE/REVIEW） | codex/core-js |
