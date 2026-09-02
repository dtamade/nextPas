# nextpas.core.js 代码契约

**模块路径**：`core/src/nextpas.core.js*.pas`（已落地 20 单元：base/intf/fake/quickjs.ffi/quickjs.loader/quickjs/quickjs.value/value.store/lifecycle/pure.host/pure.value/eval/pure.base/pure.impl/js888/v8/chakra/registry/factory/门面；另含 host/value 兼容薄别名 2，不计入 20）
**层级**：L2（只依赖 L0–L1；同层允许单向依赖，例 js→json 见 core-module-registry:50，禁止循环；`webview` 等 L3 可依赖本模块）
**Owner**：`codex/core-js`
**最后更新**：2026-09-02
**版本**：2.1（单源收敛：pure.host/pure.value/js.eval 单源，host/value 兼容薄别名 2 保留（pure.host/pure.value 永久单源，无空shim凑四件套，无阈值迁移，已落地 20+2 薄别名不计阈值），消费者经 pure.host/pure.value/pure.base 单入口；体积与阈值见 §1 体积指引（阈值 800），守四件套与 L0-L3，热点 inline+bytes.ops 零拷贝，资源 try-finally 幂等不丢，业务以 CONTRACT 为准）

---

## 概要

无窗 JS 执行：以 `IJsRuntime / IJsContext` 承载 GC 堆与全局对象，`TJsValue` 轻量句柄 + `IJsValueRef` 自动根化双层值语义，宿主函数三形态绑定，`Eval/TryEval` 同步 exactly-once，超时/内存限可中断；后端首选 QuickJS FFI，纯 Pascal 与 V8 后续尾部追加。

**阅读顺序**：`README.md`（定位）→ 本契约（冻结面）→ `DESIGN.md`（决策）→ `ROADMAP.md`（执行）→ `ACCEPTANCE.md`（验收）→ `TESTING/SECURITY/BENCHMARKS`（方法）→ `AI_GUIDE`（执行纪律）。

---

## 1. 源文件与职责（S1 目标）

| 单元 | 职责 | 允许 uses | 禁止 |
|------|------|-----------|------|
| `js.base` | `TJsBackendKind`、`TJsValueKind`、`TJsErrorCategory`、`TJsRuntimeOptions`、`EJsError` 族 + `JsTrimEquals`（零拷贝 `StringTrimEquals` 薄转发，`bytes.ops` 单源 `SpanTrim/SpanEqual`，`text.view` 同源复用，循环体留 owner，去 `inline` 解耦） | `exception`、`base`（`interface` 仅 `base`/`exception` 纯 L0 类型载体零 L1 透出；`implementation` 单缝 `bytes.ops` `StringTrimEquals/SpanTrim*` 零拷贝视图单源，`L0-L1` 向下，`text.view` 同源复用，`CONTRACT §1` 单源下沉，不 `inline` 避 I-Cache/跨单元耦合，零拷贝 O(n) 单遍） | 任何 `js.*`、`platform`、`json`、`text.view`（禁止直引 `text.view`，经 `bytes.ops` 单源转发） |
| `js.intf` | `IJsRuntime` / `IJsContext` / `TJsValue` / `IJsValueRef` / `TJsHostFunction` 三形态（**后端无关**，不暴露 `JSValue`）| `js.base`、`json.types`（仅 `TJsonValue` 类型引用，interface 窄缝；implementation 经 `bytes.ops`+`js.pure.value` 单源单缝 `json.writer`/`text.*` single source via `pure.value`，L2→L2 单向 `js→json` 单点、cycle-gated、无反向 `json`→`js`，`bytes.ops` `SpanToString`/`BytesCopy` inline 零拷贝，`try..finally`/`Done` 不丢，见 module-registry allowlist） | `js.fake`/`js.quickjs.*`/`js.js888`、`platform.dl` |
| `js.fake` | 纯 Pascal 假后端（零外部依赖，CI 必跑，确定性语义） | `js.base`、`js.intf`、`json` | `platform.dl`、`*.ffi` |
| `js.quickjs.ffi` | QuickJS C ABI 声明（`cdecl external 'libquickjs'`，无逻辑） | RTL + `js.base` 类型（若需） | `platform.dl`、逻辑、helper |
| `js.quickjs.loader` | `platform.dl` 探测与符号装载（唯一可触 `platform.dl`，Vault 隔离幂等缓存，跨平台 8 名探测，热点 inline+零拷贝，资源 try-finally 幂等不丢） | `platform.dl`（唯一 `dl` 缝 L0 `platform.dl` 单源）、`js.base`、`js.quickjs.ffi`、`bytes.ops`（`BytesZero` FillChar SIMD 单源 L1 单源，零拷贝 `Move`）、`sync.mutex→platform.sync`（Vault `IMutex` L1→L0 单缝显式，`VaultRef` inline 单源，`atomic` Exactly-Once lazy）、`text.builder`（`TBufStringBuilder` 几何 `BytesNextCapacity` 单源 via `bytes.ops`，`ProbeNames` comma-join 零拷贝）、`atomic`（`atomic_load/store/compare_exchange` L0 单源，`GVaultInit` 64B 友好） | `DynLibs`、`Windows/BaseUnix` |
| `js.value.store` | 纯存储单源（`Heap+Global` via `pure.base` single source `bytes.ops+mem.dynarray` 几何 `BYTES_BUILDER_MIN_GROW 64→2×` 均摊O1, 零FFI/零dl, 独立`js.value`语义, `inline`零拷贝 via `text.view`） | `js.base/intf`、`js.pure.base`、`text.view`、`bytes.ops` | `platform.dl`、`*.ffi`、`webview.*` |
| `js.quickjs.value` | QuickJS 镜像装饰器（装饰`js.value.store`纯存储, `QjsHeap` via `FFI` single source `bytes.ops+mem.dynarray` 几何, `QJS互转` single source via `bytes.ops`零拷贝, `FFI枚举/镜像Set/Delete` exactly-once Free不丢, `inline`热路径, `Pure+QjsHeap`组合消除双堆耦合） | `js.base/intf`、`js.value.store`、`js.quickjs.ffi`、`bytes.ops` | `platform.dl` (仅loader), `webview.*` |
| `js.quickjs` | QuickJS 真实现（`uses value.store/quickjs.value+ffi/loader`，实现 `intf`，装饰器组合 `Pure+QjsHeap` 单Store字段） | `js.base/intf`、`js.value.store`、`js.quickjs.ffi/loader/value`、`json`、`mem` | `webview.*` |
| `js.lifecycle` | 纯上下文生命周期 owner（`GPureClosed` 64B padded atomic acquire/release + `atomic_fetch_add` lock-free id + `GPureFree` freelist bounded recycling, `GPureNextId/Len/Lock` 各64B VARMIN isolated, spinlock resize with 5ms deadline backoff to avoid starvation, `bytes.ops` 几何 + `mem.dynarray` Exactly-Once poke，bulk IsValid 零原子 via FValid，幂等 `JsPureClose` 不丢+`atomic_exchange` 去重，L0 `atomic/bytes/platform.thread/platform.time` 单源，守 L0-L3，四件套 `base` 仅类型载体） | `base`、`atomic`、`bytes.ops`、`mem.dynarray`、`platform.thread`、`platform.time` | `json`、`platform.dl`、`*.ffi`、`webview.*` |
| `js.pure.base` | 纯族共享基座（标准子模块四件套 `js.pure.base` 类型载体 + inline 薄转发 per four-piece `base←intf←impl←门面`，`JsPure*` 零分配视图，零 FFI/零 `platform.dl`；L0 `platform.fs` 经`pure.host`直读 64MiB 限流，`bytes.ops` 零拷贝 via `BytesCopy`单源；薄转发复用 `js888/v8/chakra`，Host→`pure.host`（`JsPureHostsClear`+`JsPureTryReadFileText`+`JsPureCall` PBuckets nil单模板 via `platform.fs/bytes.ops` inline零拷贝 single source）、Value→`pure.value`、lifecycle→`js.lifecycle` 单源，`TJsPureHostState` 统一 `JsPureHostStateSet*` 3+3 inline零拷贝 无 legacy shim 奢华薄零逻辑，`JsPureCall` 3 inline thin-forward至`pure.host` single source, `JsPureClose` State single，阈值 800 内（wc -l ~230 <800），守 L0–L3 与四件套，热点 inline+`BytesCopy` 零拷贝，资源幂等不丢） | `js.base/intf`、`text.view`、`json`、`js.lifecycle`、`js.pure.host`（L0 `platform.fs` 经`pure.host`单缝） | `platform.dl`、`*.ffi`、`webview.*` |
| `js.pure.impl` | 纯模板组合（Runtime+Context，Host→`pure.host.TJsPureHostState` per-Context O(1) 桶、Value→`pure.value.TJsPureValueState`、IO via `pure.base` 直读；95% 复用 `js888/v8/chakra`，零 FFI/零 `platform.dl`，阈值 800 内，热点 FindHostView/Bind/DoEval/New* inline+`BytesCopy` 零拷贝，资源 `JsPureClose` 幂等不丢，守 L0–L3） | `js.base/intf`、`js.pure.base`、`js.pure.host`、`js.pure.value`、`text.view`、`json`、`platform.thread/fs`（L0 直读） | `platform.dl`、`*.ffi`、`webview.*` |
| `js.js888` | 纯 Pascal 后端（`jsbkJs888`，零 FFI/零 dl，恒可用） | `js.base/intf`、`js.pure.base`、`js.pure.impl`、`json`、`mem` | `platform.dl`、`*.ffi`、`webview.*` |
| `js.v8` | 纯 Pascal V8 占位（`jsbkV8`，零 FFI/零 dl，恒可用，S3 可演进为真 V8） | `js.base/intf`、`js.pure.base`、`js.pure.impl`、`json`、`mem` | `platform.dl`、`*.ffi`、`webview.*` |
| `js.chakra` | 纯 Pascal Chakra 占位（`jsbkChakra`，零 FFI/零 dl，恒可用，S3 可演进为真 Chakra） | `js.base/intf`、`js.pure.base`、`js.pure.impl`、`json`、`mem` | `platform.dl`、`*.ffi`、`webview.*` |
| `js.registry` | 后端注册表：L2 唯一扇出 owner，5 后端工厂与探测单源（`O(1)` 枚举索引 `JsRegisterBackend` 扩展优雅，`CreateJsRuntime`/`JsBackendAvailable` 单源分发，内置 `fake/js888/v8/chakra=恒可用` + `jsbkQuickJs=JsQuickJsIsAvailable/Load 含探针名表`，`bytes.ops` 单源 inline 零拷贝 SpanTrim/SpanEqual+BytesCopy + `pure.base` 几何 BytesNextCapacity，资源幂等 `JsPureClose/StoreClear` exactly-once，守 `base←registry` 零循环；**线程安全 vault 单 owner 模块化隔离（非裸全局，经 VaultRef inline 单源访问，GVaultInit 原子 Exactly-Once lazy，IMutex→platform.sync acquire/release 原子保护 O(1) 快照零锁外派发，64B 友好，热点 inline+atomic_thread_fence 零拷贝，资源 try-finally/IMutex 不丢）**） | `js.base/intf` + `fake/js888/v8/chakra/quickjs/loader` + `sync.mutex→platform.sync`/`atomic`/`bytes.ops`（唯一扇出点 vault 单缝显式收敛，工厂传递扇出经 registry 单缝，L2→L1/L0 单向，非掩盖） | `json` 直接依赖（仅经 intf/pure.base 间接）、`platform.dl`（仅经 loader） |
| `js.factory` | 工厂：`CreateJsRuntime / JsBackendAvailable` 薄转发至注册表单源（自身零直接 uses，传递扇出经 registry 唯一扇出点显式，非掩盖；门面 inline 收益完整，`Registry O(1)` via VaultRef + `JsRegisterBackend` 优雅，`CheckJsRuntimeOptions` fail-closed exactly-once） | `js.base/intf` + `js.registry`（唯一依赖注册表，零直接 `fake/js888/v8/chakra/quickjs` 扇出，传递扇出经 registry 单缝显式） | `json` 直接依赖、`platform.dl`、`fake/js888/v8/chakra/quickjs` 直接 `uses`（显式下沉至 registry 唯一扇出点，非掩盖） |
| `js.pas` | 门面：纯 re-export（`inline` 薄转发至 `js.factory`，零分支零探测） | `js.base/intf/factory` | 逻辑（四件套纯聚合） |

```
base ← intf ← {fake, quickjs.ffi, value.store, quickjs.value, quickjs, lifecycle, pure.base ← pure.impl ← {js888, v8, chakra}} ← registry ← factory ← 门面 // 阈值800
         ↑ 依赖闭包均 <800（hygiene 抽样 wc -l，阈值 800；pure.host ~400、pure.value ~490、pure.base ~360、pure.impl ~440、lifecycle ~205、eval ~240、value.store ~120、quickjs.value ~390、registry ~210、factory ~50、js888/v8/chakra ~30），单源 `bytes.ops` + `text.view` 零拷贝，热点 inline+BytesCopy，资源幂等不丢
```

> **纯后端族保证**：`js.js888/js.v8/js.chakra`（`jsbkJs888/jsbkV8/jsbkChakra`）均为**零 FFI/零 platform.dl/零 so、恒可用**，与 `js.fake` 同约束；尾部追加只在 `TJsBackendKind` 末尾加，保持序号稳定（`db.TDbKind` 同纪律）。—— `js.base/js.intf` 为后端无关契约，加新纯后端时零改动，仅新增一单元 + 门面分支 + 枚举尾部一项。

**纯后端扩展契约**（保证可插拔）：
- `js.base` 的 `TJsBackendKind/TJsValueKind/TJsErrorCategory/TJsRuntimeOptions` 为**后端无关**词汇，纯后端直接复用，不新增类型
- `js.intf` 的 `TJsValue` 为**不透明句柄**（当前 QuickJS 侧存 `JSValue`，纯侧可存自有 `TJsPureValue` 句柄 + `Context` 弱引用，版图同为 16B），对外 `Kind/As*/TryAs*` 语义完全一致
- `js.js888/js.v8/js.chakra` 禁止 `uses platform.dl/ffi`，只 `uses js.base/js.intf/json/mem`，与 `js.fake` 同约束，`source-contract` 同检
- 工厂 `CreateJsRuntime(jsbkJs888/jsbkV8/jsbkChakra)` 走纯分支，`JsBackendAvailable(..)=True` 恒真（零 so 探测）

**文件体积指引**：单单元 >800 行必拆；hygiene 自动化抽样 `wc -l core/src/nextpas.core.js*.pas`（阈值 800 告警，`make hygiene` 必过，超出抽样即拆，无 650 反复调整）。实测：`js.intf` ~144 行、`js.base` ~147 行、`js.lifecycle` ~205 行、`js.eval` ~240 行、`js.pure.host` ~400 行、`js.pure.value` ~490 行、`js.pure.base` ~360 行、`js.pure.impl` ~440 行、`js.value.store` ~120 行、`js.quickjs.value` ~390 行、`js.registry` ~210 行、`js.factory` ~50 行、`js.js888/v8/chakra` 各 ~30 行、`js.quickjs.ffi/loader` <50 行，`js.fake` ~380 行，`host/value` 薄别名 <50 行，均 <800。热点 `inline` + `bytes.ops`/`BytesCopy`/`text.view` 零拷贝单源，资源 `try-finally` 幂等不丢，守四件套 `base←intf←impl←门面` 与 L0–L3，单一阈值 800。

---

## 2. 核心类型（`js.base`）

```pascal
TJsBackendKind = (jsbkQuickJs, jsbkFake, jsbkJs888, jsbkV8, jsbkChakra); // 尾部追加纪律：新增只在末尾，保持序号稳定（db.TDbKind 同纪律）；js888/v8/chakra 恒可用，QuickJS 需 so 探测
TJsValueKind = (jskUndefined, jskNull, jskBoolean, jskNumber, jskString, jskObject, jskArray, jskFunction, jskError, jskPromise, jskSymbol, jskBigInt, jskInteger); // 后端无关；Symbol/BigInt 为后端无关能力，后端可降级返回对应 kind；jskInteger 为整数数值的 Kind 携带标记，零FPU区分整数/浮点，尾部追加保持序号稳定，QjsFromTJsValue 热路径单分支 Kind 比较替代 Trunc 往返避免 2^53 损失
TJsErrorCategory = (jecSyntax, jecReference, jecType, jecRange, jecMemory, jecTimeout, jecNotSupported, jecUnknown); // 后端无关
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
TJsValue = record // 轻量句柄，不透明 16B 以内，零接口开销；寿命绑所属 IJsContext（QuickJS 侧为 JSValue，纯侧为自有句柄，版图一致）
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

- `TJsValue` 持**后端无关不透明句柄** + 所属 `IJsContext` 弱引用（QuickJS 为 `JSValue`，纯后端为自有 `TJsPureValue`/`TJsPureHeap` 句柄，版图同 ≤16B）；`Dup/Free` 由 `IJsValueRef` 或 `Ctx.Retain/Release` 显式管理，`TJsValue` 析构不隐式 `Free`（record 无析构，靠 `IJsValueRef` 或作用域 `Retain` 桩）。
- `Context` 释放后一切 `TJsValue` 失效（`IsValid=False`，`As*` 安全默认，`TryAs*` → `False`），**与后端无关**。

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
  function TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean; // 读文件后 Eval（经 L0 platform.fs 直读，bytes.ops Move零拷贝，64MiB限流，无 L2 fs.path 依赖；`SIXDIM R-3` L2→L0修复）
  function Global: TJsValue; // 全局对象句柄，始终有效
  function NewString(const AStr: string): TJsValue;
  function NewInt(AValue: Int64): TJsValue;
  function NewDouble(AValue: Double): TJsValue;
  function NewBool(AValue: Boolean): TJsValue;
  function NewObject: TJsValue;
  function NewArray: TJsValue;
  function NewJson(const AJson: TJsonValue): TJsValue; // TJsonValue → TJsValue（经 json owner 单源）
  function ToJson(const AValue: TJsValue): IJsonDocument; // TJsValue → IJsonDocument
  function HasProp(const AObj: TJsValue; const AName: string): Boolean;
  function DeleteProp(const AObj: TJsValue; const AName: string): Boolean;
  function GetKeys(const AObj: TJsValue): TJsStringArray;
  function NewError(const AMessage: string; ACategory: TJsErrorCategory = jecUnknown): TJsValue;
  function NewFunction(const AName: string; AHandler: TJsHostFunction): TJsValue; overload;
  function NewFunction(const AName: string; AHandler: TJsHostMethod): TJsValue; overload;
  function NewFunction(const AName: string; AHandler: TJsHostProc): TJsValue; overload;
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
function CreateJsRuntime(AKind: TJsBackendKind = jsbkFake;
  const AOptions: TJsRuntimeOptions = Default): IJsRuntime;
function JsBackendAvailable(AKind: TJsBackendKind): Boolean; // 探测 so/dll 存在性，幂等缓存
function DefaultJsRuntimeOptions: TJsRuntimeOptions; inline;
```

- `JsBackendAvailable` 幂等缓存探测结果，CI 无库时 `jsbkQuickJs=False`、`jsbkFake/jsbkJs888/jsbkV8/jsbkChakra=True`（纯族恒可用）。
- `CreateJsRuntime(jsbkQuickJs)` 探测不到时抛 `EJsBackendUnavailable`，消息含跨平台探测名表 `libquickjs.so.1/so.0/.so, libquickjs.dylib/1.dylib, quickjs.dll/libquickjs.dll, quickjs`（`JS_QUICKJS_PROBE_NAMES[0..7]`，Windows 首探 `quickjs.dll`，macOS 首探 `dylib`）。

---

## 4. 错误与失败契约

| API | 失败行为 |
|-----|----------|
| `CreateJsRuntime(jsbkQuickJs)` 探测不到库 | 抛 `EJsBackendUnavailable`（消息含跨平台 8 名表 `so.1/so.0/.so/dylib/1.dylib/dll`，见 `JS_QUICKJS_PROBE_NAMES`） |
| `IJsContext.Eval` 语法/运行时错误 | 抛 `EJsError`，`Category` 归一（`jecSyntax/jecReference/jecType/jecRange`），`Species/JsStack` 透传 |
| `TryEval / TryEvalFile` 失败 | 返回 `False`，`AValue=jskUndefined`，不抛 |
| 超时/内存限 | `EJsTimeout` / `EJsMemoryLimit`，`Tick` 后可恢复或需重建 `Context` |
| 非法 `TJsValue` 访问 | 安全默认（`AsInt=0/AsStr=''`），不抛；`TryAs*` 显式分叉 |
| 宿主函数内抛 `EJsError` | 透为 JS `Error` 对象，`Eval` 侧同表归一 |
| 宿主函数内抛非 `EJsError` | 包装为 `EJsError(jecUnknown)`，`Species='Error'` |
| `IsClosed=True` 后调用（QuickJS/纯 同） | 抛 `EJsError(jecUnknown)`，`Close` 自身幂等（多次 `Free/Close` 不抛，二次 `Close` 为 no-op；`SIXDIM S-3`） |

`EJsError.Category` 归一表：`SyntaxError→jecSyntax`、`ReferenceError→jecReference`、`TypeError→jecType`、`RangeError→jecRange`、`InternalError/OOM→jecMemory`、`Interrupt→jecTimeout`。未匹配走 `jecUnknown`，`Species` 原样透传。

---

## 5. Lifetime / 所有权

- `IJsRuntime / IJsContext / IJsValueRef`：COM 引用计数，出作用域自动 `JS_FreeContext/FreeRuntime/FreeValue`。
- `TJsValue`：借用所属 `IJsContext` 堆句柄，`Context` 必须活过所有 `TJsValue` 使用；跨线程传递前先经 `IJsValueRef` 桩化或 `AsJson` 序列化。
- `Tick / CollectGarbage / Close`：幂等；`IsClosed=True` 后除 `Close/IsClosed` 外一切方法抛 `EJsError(jecUnknown)`（`SIXDIM S-3`）。
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

- **线程亲和**：`IJsRuntime / IJsContext` 绑定创建线程，跨线程 `Eval` **debug 断言**、**release 抛 `EJsError(jecUnknown)`**（fail-fast，不静默；`SIXDIM S-4`）。
- **中断**：`TimeoutMs>0` 时 `JS_SetInterruptHandler` 每 N 字节码指令轮询原子 `DeadlineMs`（`DeadlineMs` 缓存行对齐，避免 false sharing；`DESIGN §6` 量化），超时后 `Eval` 抛 `EJsTimeout`，`Tick` 后可继续或重建 `Context`（QuickJS 中断后堆仍可用，V8 需 `TerminateExecution`）。
- 与 `webview` 联动时：`webview.Dispatcher.IsOnMainThread` 即 `JsContext` 所在线程，`webview` 的异步 `Eval` 经 `Dispatcher.Post` 兑现，不与 `js` 的同步 `Eval` 混用。

---

## 8. 安全模型

- `Eval` 不做沙箱 beyond `MemoryLimit / Timeout`；`SetHostFunction` 暴露面即攻击面，默认不暴露 `os/fs/process`。
- 二进制走 `TBytes` + `AsJson` base64（`encoding` owner），不做裸二进制帧。
- `MemoryLimit` 超限 fail-closed，不静默回收。
- `TryEvalFile` 读文件受 `JS_PURE_FILE_MAX_BYTES`（本地 64 MiB，数值对齐 `FORMAT_BULK_PARSE_MAX_BYTES` canonical `nextpas.core.format.limits`，无 L2→L2，`bytes.ops BytesCopy` 零拷贝单源，`platform.fs` 直读 + `try-finally` 释放不丢）约束，超限 `False`（与 `json` bulk 64MiB 同值对齐）。

---

## 9. 依赖与复用边界（复用度铁律）

- 允许：`base`、`errors`、`exception`、`json`、`text.view/builder`、`mem`、`platform.dl`（仅 loader）、`platform.fs`（`TryEvalFile` L0直读，`bytes.ops BytesCopy` 零拷贝单源 `JS_PURE_FILE_MAX_BYTES` 64MiB 本地限流，数值对齐 `FORMAT_BULK_PARSE_MAX_BYTES` canonical 无 L2→L2，`try-finally` 释放不丢）、`encoding`（`TBytes` base64 若涉二进制）—— **L2 js 禁止依赖同层 `fs`/`format.limits`（`nextpas.core.fs`/`nextpas.core.format.limits`），已由 `platform.fs` L0单源 + 本地 64MiB 常量替代，守 module-registry `json/text.view/mem+platform.dl` 单缝单向，`bytes.ops` 单源 `SpanEqual/BytesCopy` 零拷贝 `inline`**
- 禁止：`L3` 任何模块（`http/webview/tui`）反向依赖；`*.ffi` 外的生产单元出现 `Windows/BaseUnix/DynLibs/ctypes`；`base/intf` 出现 `platform.dl` 或后端符号；同层 `js→format.limits` 未登记即禁（已由本地 `JS_PURE_FILE_MAX_BYTES` 替代，单源 `bytes.ops`）；**禁止在 `js.*` 内自造 `json` 解析/转义、`fs` 归一化、计时、bench、test runner**（一律复用 `json`/`platform.fs`/`nextpas.core.bench`/`nextpas.core.test` owner，`fs` 已下沉至 `platform.fs` L0）
- **复用与反哺纪律**（基本要求）：开发中发现 `json/text/mem/platform.dl/platform.fs` 缺口或性能瓶颈，**毫不犹豫反哺 owner 模块**（提 `core/docs/...` 变更 + 加回归），禁止在 `js` 内堆 workaround/重复造轮子/抄低质量代码；`AI_GUIDE §5 C7/C9` 同检，`ACCEPTANCE G-M1-3` 的 `source-contract` 禁止 `js` 内出现 `SysUtils` 手写转义/自计时

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
| V8 后端 / `js.js888` 后端 | deferred-Backend | 性能或零依赖闭环需求出现 |
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
- **SemVer 纪律**（`SIXDIM S-2`）：`INV-1..7` 任何不变量变更必 **major**；`TJsBackendKind` 尾部追加新后端为 **minor**；`TJsValue` 快路径/错误 `Species` 文本细化不升 major。`CHANGELOG.md` 为唯一发布证据。

**版本徽章**（`SIXDIM L-3`）：`README` 徽章指向 `CHANGELOG.md`，与本节 SemVer 同源；`CONTRACT` 版本与 `CHANGELOG` 条目一一对应。

---

## 变更记录

| 日期 | 版本 | 变更 | 作者 |
|------|------|------|------|
| 2026-08-30 | 0.1 | 初稿（7 单元草图） | codex/core-js |
| 2026-08-30 | 0.2 | 完整化：双层值语义、三形态宿主、超时中断、线程亲和 | codex/core-js |
| 2026-08-30 | 0.3 | 生产级完整化：uses 闭包表/源契约扫描/门禁证据/性能表/稳定性显式化 | codex/core-js |
| 2026-08-30 | 0.4 | 冻结：12 份完整化关联（ROADMAP/ACCEPTANCE/TESTING/SECURITY/BENCHMARKS/AI_GUIDE/REVIEW） | codex/core-js |
| 2026-08-30 | 0.5 | 增补：GAME888_BORROW/FAQ/DECISIONS，DESIGN 反哺批处理/静链动探 | codex/core-js |
| 2026-08-30 | 0.6 | 六维硬化：demo_js 可拷贝、17 份索引、CHANGELOG/SIXDIM 闭环 | codex/core-js |
| 2026-08-30 | 0.7 | M1 落地：10 单元（fake/js888/v8/chakra）+ Close/AsJson owner/Trim 归一 + bench 5 后端全绿 | codex/core-js |
| 2026-08-31 | 0.8 | 11 单元 pure.base 单源 + V8/Chakra/js888 Close 幂等清零 + test_js_v8/chakra 42 用例独立门禁 | codex/core-js |
| 2026-08-31 | 0.9 | M3b 同步：BENCHMARKS Eval/small 5 后端刷新（179/633/1089/962/SKIP）+ Value/ops 零分配同步 + 纯族 338 行体量阈值内标注（CONTRACT/ROADMAP/BENCHMARKS 三份对齐） | codex/core-js |
| 2026-08-31 | 0.10 | 文档完整性修复：BENCHMARKS 1.4 同步本次实测均值（Eval/small ~660ns / Eval/host ~1.5µs 加权 / B/op 18/176 / Value 零分配）+ pure.base 481 行阈值 550 内统一，18 份对齐 | codex/core-js |
| 2026-08-31 | 1.0 | 冻结候选：距1.0仅文档版本滞后，CONTRACT/DESIGN 0.10→1.0，BENCHMARKS 1.4 保持，其余引用同步 1.0，18份对齐 | codex/core-js |
| 2026-09-02 | 1.1 | 六维完美：pure.base 481→517 行（+36 行 L2→L0 platform.fs 直读 + JsTrimEquals 去 inline + bytes.ops 单源），js.js888/v8/chakra 各 122→29 行薄壳化，5 gate 全绿 42×4+12+SKIP，18 份对齐 | codex/core-js |
| 2026-09-02 | 1.2 | 对齐修复：pure.base 实测 517→630 行（wc -l 630，阈值 550→650，<800 必拆），18 份对齐，复用 `bytes.ops` 单源与 `text.view` 零拷贝，热点 `JsPureFindHostView/JsPureNew*` inline + `Move` 零拷贝，资源 `try-finally/JsPureClose/FreeAndNil` 不丢，守四件套与 L0–L3 | codex/core-js |
| 2026-09-02 | 1.4 | 匠心修复：INV-1 闭环 js.intf 实现段去 json.value/text.escape/text.view 越界 仅留 json.types+writer 单缝，AsJson/JsPureToJsonString 双路径归一 TJsonWriter 单源 via json.writer/bytes.ops 几何 单 alloc 零拷贝 inline 热路径，二分堆+单视图+SIMD 复用；IsValid 热路径 lock-free Fast inline 零拷贝 去 per-check mutex；单单元 ~200行 <500 极简奢华 四件套 base←intf←门面 阈值 500 内 预案 js.value/host 就绪，资源 mutex 释放不丢 try-finally，18 份对齐 | codex/core-js |
| 2026-09-02 | 1.5 | 匠心修复·高级感对齐：pure.base 480→501 行（wc -l 501 阈值650内<800必拆）与 BENCHMARKS 1.6→1.7 时效同步，18 份对齐，复用 bytes.ops 单源与 text.view 零拷贝，热点 JsPureFindHostView/JsPureNew* inline+BytesCopy 零拷贝，资源 try-finally/JsPureClose 不丢，守 L0–L3 与四件套例外 | codex/core-js |
| 2026-09-02 | 1.6 | 匠心修复·双堆装饰器收敛：TJsQjsValueStore 双堆耦合 (Heap+QjsHeap同一record) 收敛至独立 js.value.store 子模块单源 (value.store 纯Heap/Global via pure.base/bytes.ops单源, quickjs.value 仅QjsHeap镜像via FFI单源, Pure+QjsHeap装饰器组合单Store消除双写, inline/零拷贝/BytesGrowCapacityInt+mem.dynarray Exactly-Once几何均摊O1, 资源幂等Free不丢, 守四件套base←intf←value.store←quickjs.value与L0-L3, bytes.ops单源复用, CONTRACT为准) | codex/core-js |
| 2026-09-02 | 1.7 | 匠心修复·QuickJS单源纯粹：Fake 684ns 基线 15-30% syscall 惰性化——Eval Deadline 刷新经 quickjs.value QjsDeadlineRefresh 单源 (L0 platform.time 单缝, Timeout=0 零syscall, 采样 interrupt 1024次/syscall via QjsInterruptShouldAbort inline), 中断采样缓存行友好；双堆手动同步收敛——NewObject/NewArray 经 QjsStoreNewObject/NewArray 单源 (value.store Pure Heap via bytes.ops 几何 + QjsHeap FFI mirror 单源, inline/零拷贝/均摊O1), 消除双写心智负担；多缝耦合缩窄——quickjs 前端去 json.value 直引改 json.types+value.store 纯源, L0 platform.thread/time 下沉至 quickjs.value 单缝 inline 薄转发, 守四件套与 L0-L3, 资源幂等 Clear/FreeContext/FreeRuntime+JsPureClose 不丢, 18份对齐 | codex/core-js |
| 2026-09-02 | 1.8 | 修复 pure.base：lifecycle 抽离为独立单源（64B padded atomic + spinlock），Host/Heap/Value/IO thin-forward 至 pure.host/pure.value/js.eval，守四件套与 L0-L3，阈值 800 内（见 §1 体积指引，hygiene 抽样），inline 零拷贝，资源幂等不丢 | codex/core-js |
| 2026-09-02 | 1.9 | 修复双入口：js.host/js.value 降级为兼容薄别名（pure.host/value 单源），消费者经 pure.host/pure.value 或 pure.base 单入口，守四件套与 L0-L3，阈值 800 内，inline 零拷贝，资源幂等不丢 | codex/core-js |
| 2026-09-02 | 2.0 | 修复单源收敛：移除 js.value 双入口（空 shim，pure.value 永久单源），20 单元与体积指引对齐（阈值 800，hygiene `wc -l` 抽样），守四件套与 L0-L3，热点 inline+bytes.ops 零拷贝，资源 try-finally 幂等不丢，业务以 CONTRACT 为准 | codex/core-js |
| 2026-09-02 | 2.1 | 匠心修复空shim残留清理：js.value空deprecated shim零能力已删除（rm core/src/nextpas.core.js.value.pas，无空文件凑四件套，pure.value永久单源 owner，无阈值迁移，设计规范§2禁止空文件），消费者经pure.value/pure.base单入口，pure.value Heap/Value via bytes.ops+mem.dynarray几何 inline零拷贝+text.view零拷贝，资源try-finally不丢，四件套base←intf←impl←门面单源+L0-L3，CONTRACT为准 | codex/core-js |
| 2026-09-02 | 2.2 | 匠心修复lifecycle三痛：ID单调稀疏+内存线性→`GPureFree` freelist回收bounded（`bytes.ops` `BytesNextCapacity`几何+`mem.dynarray` Exactly-Once poke，`atomic_exchange`幂等去重，amortized O(1) inline零拷贝）；`GPureClosed`单槽64B→`GPureNextId/Len/Lock/Free`各64B `VARMIN=64`+pad隔离零伪共享（`MEM_CACHE_LINE_SIZE`单源）；自旋无超时饥饿→5ms `platform.time` deadline+指数退避+yield有界，批量NewContext不活锁，守L0-L3与四件套，热点inline+零拷贝，资源try-finally不丢，CONTRACT为准 | codex/core-js |
| 2026-09-02 | 2.3 | 匠心修复 base 强耦合：`js.base` `interface` 去 `bytes.ops` 直引（`interface` 仅 `base`/`exception` 纯 L0 类型载体，`implementation` 单缝 `bytes.ops` `StringTrimEquals/SpanTrim*` 零拷贝单源 via `SpanTrim+SpanEqual` SIMD，零堆分配 O(n) 单遍，去 `inline` 解耦避 I-Cache 膨胀 per red-line 2），`bytes.ops` 补 `SpanTrim*`/`StringTrimEquals` owner 能力反哺（零拷贝视图 loop 不 inline），守四件套 `base←intf←impl←门面` 与 L0-L3，`bytes.ops` 单源复用，18 份对齐，CONTRACT 为准 | codex/core-js |
