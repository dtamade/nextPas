# nextpas.core.js 代码契约

**模块路径**：`core/src/nextpas.core.js*.pas`（已落地 22 单元：base/intf/fake/quickjs.ffi/quickjs.loader/quickjs/quickjs.value/value.store/lifecycle/pure.host/pure.value/pure.predicates/eval/pure.base/pure/pure.impl/js888/v8/chakra/registry/factory/门面；另含 host/value 兼容薄别名 2，不计入 22；pure.impl 为兼容薄别名存量保留，新代码 uses pure）
**层级**：L2（只依赖 L0–L1；同层允许单向依赖，例 js→json 见 core-module-registry:50，禁止循环；`webview` 等 L3 可依赖本模块）
**Owner**：`codex/core-js`
**最后更新**：2026-09-03
**版本**：2.7（22 单元 + host/value 薄别名 2 不计阈值；单源 pure.host/pure.value/pure.predicates/js.eval，体积与阈值见 §1 体积指引）

---

## 概要

无窗 JS 执行：以 `IJsRuntime / IJsContext` 承载 GC 堆与全局对象，`TJsValue` 轻量句柄 + `IJsValueRef` 自动根化双层值语义，宿主函数三形态绑定，`Eval/TryEval` 同步 exactly-once，超时/内存限可中断；后端首选 QuickJS FFI，纯 Pascal 与 V8 后续尾部追加。

**阅读顺序**：`README.md`（定位）→ 本契约（冻结面）→ `DESIGN.md`（决策）→ `ROADMAP.md`（执行）→ `ACCEPTANCE.md`（验收）→ `TESTING/SECURITY/BENCHMARKS`（方法）→ `AI_GUIDE`（执行纪律）。

---

## 1. 源文件与职责（S1 目标）

| 单元 | 职责 | 允许 uses | 禁止 |
|------|------|-----------|------|
| `js.base` | `TJsBackendKind`、`TJsValueKind`、`TJsErrorCategory`、`TJsRuntimeOptions`、`EJsError` 族 + `JsTrimEquals` + `CheckJsRuntimeOptions` | `exception`、`base` | `js.*`、`platform`、`json`、`text.view` |
| `js.intf` | `IJsRuntime` / `IJsContext` / `TJsValue` / `IJsValueRef` / `TJsHostFunction` 三形态（**后端无关**，不暴露 `JSValue`）| `js.base`、`json.types`（仅 `TJsonValue` 类型引用，interface 窄缝；implementation 经 `bytes.ops`+`js.pure.value` 单源单缝 `json.writer`/`text.*` single source via `pure.value`，L2→L2 单向 `js→json` 单点、cycle-gated、无反向 `json`→`js`，`bytes.ops` `SpanToString`/`BytesCopy` inline 零拷贝，`try..finally`/`Done` 不丢，见 module-registry allowlist） | `js.fake`/`js.quickjs.*`/`js.js888`、`platform.dl` |
| `js.fake` | 纯 Pascal 假后端（零外部依赖，CI 必跑，确定性语义） | `js.base`、`js.intf`、`json` | `platform.dl`、`*.ffi` |
| `js.quickjs.ffi` | QuickJS C ABI 声明（`cdecl external 'libquickjs'`，无逻辑） | RTL + `js.base` 类型（若需） | `platform.dl`、逻辑、helper |
| `js.quickjs.loader` | `platform.dl` 探测与符号装载（唯一可触 `platform.dl`，Vault 隔离幂等缓存，跨平台 8 名探测 `JS_QUICKJS_PROBE_NAMES[0..7]` 单源常量拥有者（`js.base` 纯类型载体零探针，INV-1 零 `quickjs/v8`），热点 inline+零拷贝，资源 try-finally 幂等不丢，守 design-conventions §2 红线 2：循环/几何体 out-of-line） | `platform.dl`（唯一 `dl` 缝 L0 `platform.dl` 单源）、`js.base`（类型 `TJsBackendKind` 等后端无关词汇，`JS_QUICKJS_PROBE_NAMES` 已下沉至 loader 单源，无 ifdef 双写，探针 8 名跨平台单表经 `bytes.ops StringJoin` 单源 comma-join `BuildProbeNames`）、`js.quickjs.ffi`、`bytes.ops`（`BytesZero` FillChar SIMD 单源 L1，`BytesCopy` Move 单源 inline 零拷贝 单次 `StringJoin` 零拷贝 `BytesCopy` 单源 inline 单遍 `O(n)` 预计总局限单 `SetLength` 单 alloc，无 `TBufStringBuilder` 几何重复 `try-finally`，`BytesGrowCapacity` 几何）、`sync.vault`（`SyncVaultEnsureLock` 单源 lazy Exactly-Once out-of-line loop per §2，`VaultRef` inline 薄转发，`IMutex→platform.sync`）、`atomic`（`atomic_load/store/compare_exchange` L0 单源，`GVaultInit` 64B 友好） | `DynLibs`、`Windows/BaseUnix` |
| `js.value.store` | 纯存储单源（`Heap+Global` via `pure.base` single source `bytes.ops+mem.dynarray` 几何 `BYTES_BUILDER_MIN_GROW 64→2×` 均摊O1, 零FFI/零dl, 独立`js.value`语义, `inline`零拷贝 via `text.view`） | `js.base/intf`、`js.pure.base`、`text.view`、`bytes.ops` | `platform.dl`、`*.ffi`、`webview.*` |
| `js.quickjs.value` | QuickJS 镜像装饰器（装饰`js.value.store`纯存储, `QjsHeap` via `FFI` single source `bytes.ops+mem.dynarray` 几何, `QJS互转` single source via `bytes.ops`零拷贝, `FFI枚举/镜像Set/Delete` exactly-once Free不丢, `inline`热路径, `Pure+QjsHeap`组合消除双堆耦合） | `js.base/intf`、`js.value.store`、`js.quickjs.ffi`、`bytes.ops` | `platform.dl` (仅loader), `webview.*` |
| `js.quickjs` | QuickJS 真实现（`uses value.store/quickjs.value+ffi/loader`，实现 `intf`，装饰器组合 `Pure+QjsHeap` 单Store字段） | `js.base/intf`、`js.value.store`、`js.quickjs.ffi/loader/value`、`js.pure.base/host/value`、`js.eval`、`js.lifecycle`、`text.view`、`bytes.ops`、`json`、`mem` | `webview.*` |
| `js.lifecycle` | 纯上下文生命周期 owner（`GPureClosed` 紧凑 4B `epoch*2+closed` generation-tagged atomic acquire/release + `atomic_fetch_add` lock-free id + 2^32 wrap freelist retry (long service not DoS, bounded recycling, generation-epoch protects ABA per INV-7) + `GPureFree` freelist via `collections.freelist` single source (`bytes.ops`几何 `BytesNextCapacity` + `mem.dynarray` Exactly-Once poke amortized O(1) inline零拷贝 + 4x半缩 half-shrink) , `GPureNextId/Len/Lock` plain (GPureClosed 紧凑4B/10k~40KB), IsAlive single acquire + relaxed Len (I-Cache/零拷贝, bulk IsValid zero barrier), spinlock resize with 5ms deadline backoff to avoid starvation, `bytes.ops` 几何 + `collections.freelist` 单源，bulk IsValid 零原子 via FValid，幂等 `JsPureClose` 不丢+`atomic_compare_exchange` generation去重+`generation mismatch`强一致 per INV-7，L0 `atomic/bytes/collections.freelist/platform.thread/platform.time` 单源，守 L0-L3，四件套 `base` 仅类型载体，奢华留白 64B pad 单注释） | `base`、`atomic`、`bytes.ops`、`collections.freelist`、`platform.thread`、`platform.time` | `json`、`platform.dl`、`*.ffi`、`webview.*` |
| `js.pure.base` | 纯族共享基座（`js.pure.base` 纯类型载体 per four-piece，base零依赖：仅 `js.base` 单依赖，`TJsPureProp` raw `Kind+StrVal` via `pure.value` inline 零拷贝，守 `base←intf` 单向） | `js.base` | `platform.dl`、`*.ffi`、`webview.*`、`js.intf`、`text.view`、`json`、`collections.*` |
| `js.pure.predicates` | 常量谓词单源池（`JS_PRED_LITERALS/JS_PRED_SENTINELS` + `JsPredTryNumber`，`text.scan/text.number` L1 owner 单源，`bytes.ops` 零拷贝 `inline`，`try-finally` 不丢） | `js.base/intf`、`text.view/scan/number`、`bytes.ops`、`js.pure.value` | `platform.dl`、`*.ffi`、`webview.*` |
| `js.pure` | 纯族标准聚合门面（机械四件套 `base←runtime/context←门面`，Runtime+Context 薄聚合 Host→`pure.host` O(1) 桶、Value→`pure.value`、IO via `js.eval` 单源，95% 复用 `js888/v8/chakra`，零 FFI/零 `platform.dl`，热点 inline+`BytesCopy` 零拷贝，资源幂等不丢，wc -l ~40 <800） | `js.base/intf`、`js.pure.base`、`js.pure.host`、`js.pure.value`、`js.pure.runtime`、`js.pure.context`、`js.eval`、`text.view`、`json`、`platform.thread/fs` | `platform.dl`、`*.ffi`、`webview.*` |
| `js.pure.impl` | 兼容薄别名（已收敛至标准门面 `pure.pas`，存量 uses 兼容保留，新代码应 uses `pure`，纯 re-export 无逻辑，零 FFI，复用 `pure` 单源） | `js.base/intf`、`js.pure.base`、`js.pure.host`、`js.pure.value`、`js.pure.runtime`、`js.pure.context` | `platform.dl`、`*.ffi`、`webview.*` |
| `js.js888` | 纯 Pascal 后端（`jsbkJs888`，零 FFI/零 dl，恒可用） | `js.base/intf`、`js.pure.base`、`js.pure`、`json`、`mem` | `platform.dl`、`*.ffi`、`webview.*` |
| `js.v8` | 纯 Pascal V8 占位（`jsbkV8`，零 FFI/零 dl，恒可用，S3 可演进为真 V8） | `js.base/intf`、`js.pure.base`、`js.pure`、`json`、`mem` | `platform.dl`、`*.ffi`、`webview.*` |
| `js.chakra` | 纯 Pascal Chakra 占位（`jsbkChakra`，零 FFI/零 dl，恒可用，S3 可演进为真 Chakra） | `js.base/intf`、`js.pure.base`、`js.pure`、`json`、`mem` | `platform.dl`、`*.ffi`、`webview.*` |
| `js.registry` | 后端注册表：L2 唯一扇出 owner，5 后端工厂与探测单源（`O(1)` 枚举索引 `JsRegisterBackend` 扩展优雅，`CreateJsRuntime`/`JsBackendAvailable` 单源分发，内置 `fake/js888/v8/chakra=恒可用` + `jsbkQuickJs=JsQuickJsIsAvailable/Load 含探针名表 via loader `JsQuickJsProbeNames` 单源 `js.quickjs.loader`（`js.base` 纯类型载体零探针，探针单源已下沉 loader），`bytes.ops` 单源 inline 零拷贝 SpanTrim/SpanEqual+BytesCopy + `pure.base` 几何 BytesNextCapacity，资源幂等 `JsPureClose/StoreClear` exactly-once，守 `base←registry` 零循环；**线程安全 vault 单 owner 模块化隔离（非裸全局，经 VaultRef inline 单源访问，`sync.vault SyncVaultEnsureLock` 单源 lazy Exactly-Once out-of-line loop per §2，GVaultInit 原子 Exactly-Once，IMutex→platform.sync acquire/release 原子保护 O(1) 快照零锁外派发，64B 友好，热点 inline+atomic_thread_fence 零拷贝，资源 try-finally/IMutex 不丢，loader/registry 共用 vault 单源消除克隆）**） | `js.base/intf` + `fake/js888/v8/chakra/quickjs/loader` + `sync.mutex/sync.vault→platform.sync`/`atomic`/`bytes.ops`（唯一扇出点 vault 单缝显式收敛，`sync.vault` 懒初始化单源，工厂传递扇出经 registry 单缝，L2→L1/L0 单向，非掩盖） | `json` 直接依赖（仅经 intf/pure.base 间接）、`platform.dl`（仅经 loader） |
| `js.factory` | 工厂：`CreateJsRuntime / JsBackendAvailable` 薄转发至 `registry` 单源（`CheckJsRuntimeOptions(ABackend)` 显式透传归因，无默认，要求调用方显式传真实 `AKind`） | `js.base/intf` + `js.registry` | `json` 直接依赖、`platform.dl`、直引后端 |
| `js.pas` | 门面：纯 re-export（`inline` 薄转发至 `js.factory`，零分支零探测） | `js.base/intf/factory` | 逻辑 |

```
base ← intf ← {fake, quickjs.ffi, value.store, quickjs.value, quickjs, lifecycle, pure.base ← pure(pure.runtime+pure.context) ← {js888, v8, chakra}} ← registry ← factory ← 门面 〔pure.impl 为兼容薄别名，新代码 uses pure；机械四件套 pure.base←runtime/context←门面〕
         ↑ 依赖闭包见 §1 体积指引（阈值 800 单一，hygiene 抽样）
```

> **纯后端族保证**：`js.js888/js.v8/js.chakra`（`jsbkJs888/jsbkV8/jsbkChakra`）均为**零 FFI/零 platform.dl/零 so、恒可用**，与 `js.fake` 同约束；尾部追加只在 `TJsBackendKind` 末尾加，保持序号稳定（`db.TDbKind` 同纪律）。—— `js.base/js.intf` 为后端无关契约，加新纯后端时零改动，仅新增一单元 + 门面分支 + 枚举尾部一项。

**纯后端扩展契约**（保证可插拔）：
- `js.base` 的 `TJsBackendKind/TJsValueKind/TJsErrorCategory/TJsRuntimeOptions` 为**后端无关**词汇，纯后端直接复用，不新增类型
- `js.intf` 的 `TJsValue` 为**不透明句柄**（当前 QuickJS 侧存 `JSValue`，纯侧可存自有 `TJsPureValue` 句柄 + `Context` 弱引用，版图同为 16B），对外 `Kind/As*/TryAs*` 语义完全一致
- `js.js888/js.v8/js.chakra` 禁止 `uses platform.dl/ffi`，只 `uses js.base/js.intf/json/mem`，与 `js.fake` 同约束，`source-contract` 同检
- 工厂 `CreateJsRuntime(jsbkJs888/jsbkV8/jsbkChakra)` 走纯分支，`JsBackendAvailable(..)=True` 恒真（零 so 探测）

**文件体积指引**：单单元阈值 800（单一阈值，超阈必拆）。

- 门禁：`wc -l core/src/nextpas.core.js*.pas` 抽样 + `make hygiene` 必过。
- 实测均 <800：`js.intf` ~144、`js.base` ~147、`js.lifecycle` ~205、`js.eval` ~180、`js.pure.predicates` ~60、`js.pure.host` ~400、`js.pure.value` ~490、`js.pure.base` ~45、`js.pure` ~40（`pure.runtime` ~45 + `pure.context` ~360，`pure.impl` 兼容别名 ~40）、`js.value.store` ~120、`js.quickjs.value` ~390、`js.registry` ~210、`js.factory`/`门面` ~50、`js888/v8/chakra` ~30、`ffi/loader` <50、`js.fake` ~380。
- 单源收敛：`threshold 16` via `pure.hash`、`哨兵 5×` via `js.eval`、`常量谓词` via `js.pure.predicates`（`pure.base` 零重复，门禁见 §9/source-contract）。
- 性能：热点 `inline` + `bytes.ops BytesCopy/SpanEqual` 零拷贝单源（`TByteSpan` 视图 + `Move`），`try-finally` 幂等不丢。

---

## 2. 核心类型（`js.base`）

```pascal
TJsBackendKind = (jsbkQuickJs, jsbkFake, jsbkJs888, jsbkV8, jsbkChakra); // 尾部追加纪律：新增只在末尾，保持序号稳定（db.TDbKind 同纪律）；js888/v8/chakra 恒可用，QuickJS 需 so 探测
TJsValueKind = (jskUndefined, jskNull, jskBoolean, jskNumber, jskString, jskObject, jskArray, jskFunction, jskError, jskPromise, jskSymbol, jskBigInt, jskInteger); // 后端无关；Symbol/BigInt 为后端无关能力，后端可降级返回对应 kind；jskInteger 为整数数值的 Kind 携带标记，零FPU区分整数/浮点，尾部追加保持序号稳定，QjsFromTJsValue 热路径单分支 Kind 比较替代 Trunc 往返避免 2^53 损失
TJsErrorCategory = (jecSyntax, jecReference, jecType, jecRange, jecMemory, jecTimeout, jecNotSupported, jecUnknown); // 后端无关
TJsRuntimeOptions = record
  MemoryLimit: SizeUInt; // 0=不限；QuickJS JS_SetMemoryLimit / JS_SetGCThreshold
  TimeoutMs: Integer;    // 0=不限；经 JS_SetInterruptHandler 异步中断
  InterruptSampleInterval: Cardinal; // 0=默认1024，可配1..65536 采样间隔，1逐次高及时 15-30%→1024惰性→65536稀疏，权衡长循环超时及时性/开销
  class function Default: TJsRuntimeOptions; static;
  class function WithMemoryLimit(ALimit: SizeUInt): TJsRuntimeOptions; static; inline;
  class function WithTimeout(ATimeoutMs: Integer): TJsRuntimeOptions; static; inline;
  class function WithInterruptSampleInterval(AInterval: Cardinal): TJsRuntimeOptions; static; inline;
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
| `InterruptSampleInterval` | `0=1024` 默认，`1..65536` 可配采样阈值，`QjsInterruptShouldAbort` 采样 `N` 次/syscall，`1` 逐次高及时 `15-30%` 开销，`1024` 惰性平衡，`65536` 低开销长尾延迟，`JsInterruptSampleIntervalNormalized` 单源归一，`SetInterruptSampleInterval` 运行时/上下文可动态调参 |
| `CheckJsRuntimeOptions(ABackend)` | 负值（若经有符号 API 误传）抛 `EJsError(jecUnknown, Backend=ABackend)`，`ABackend` 显式透传调用方真实 `AKind`（无默认，`jsbkQuickJs/jsbkV8/jsbkFake` 必须显式传，诊断归因不失真），不静默截断 |

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
- `CreateJsRuntime(jsbkQuickJs)` 探测不到时抛 `EJsBackendUnavailable`，消息含跨平台探测名表 `libquickjs.so.1/so.0/.so, libquickjs.dylib/1.dylib, quickjs.dll/libquickjs.dll, quickjs`（`JS_QUICKJS_PROBE_NAMES[0..7]` 单源拥有于 `js.quickjs.loader`，`js.base` 纯类型载体零探针，Windows 首探 `quickjs.dll`，macOS 首探 `dylib`）。

---

## 4. 错误与失败契约

| API | 失败行为 |
|-----|----------|
| `CreateJsRuntime(jsbkQuickJs)` 探测不到库 | 抛 `EJsBackendUnavailable`（消息含跨平台 8 名表 `so.1/so.0/.so/dylib/1.dylib/dll`，见 `JS_QUICKJS_PROBE_NAMES` 单源 `js.quickjs.loader`） |
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
- **INV-7** `TJsValue` 悬垂安全双轨：`IsValid` bulk零屏障 (FValid only, zero atomic, thread-affine hot bulk) vs `IsAlive`强一致 (FValid+acquire `GPureClosed` 紧凑4B `epoch*2+closed` generation-tagged atomic acquire `GPureClosed` via `js.lifecycle` single source, `generation mismatch`即强一致closed, cross-thread/post-Close safe)；`Context` 释放后 `IsAlive=False`/`IsClosed=True`，旧 `TJsValue.FContextId` 与同Idx新Context的 `epoch` 错配亦判 `IsClosed=True` (freelist复用不误判), `IsValid`仍可能`True`→悬垂风险需显式切`IsAlive`/`IsClosed`，`As*`零值不抛，`TryAs*`→`False`；bulk热点守`IsValid`零成本，强一致显式`acquire`单源 via `js.lifecycle` (见 `js.intf` 104/121 vs 127/128 `IsValid`零屏障 vs `IsAlive` acquire；`GPureClosed`紧凑4B 10k~40KB, `GPureFree` 4x阈值半缩)。

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
- `TryEvalFile` 读文件受 `JS_PURE_FILE_MAX_BYTES`（canonical 64MiB single source via `bytes.ops BYTES_BULK_PARSE_MAX_BYTES` L1 owner, `FORMAT_BULK_PARSE_MAX_BYTES` alias via same `bytes.ops` single source, 无 L2→L2, `bytes.ops BytesCopy` 零拷贝单源 inline, `platform.fs` 直读 + `try-finally` 释放不丢）约束，超限 `False`（与 `json` bulk 64MiB 同值同源）。

---

## 9. 依赖与复用边界（复用度铁律）

- 允许：`base`、`errors`、`exception`、`json`、`text.view/builder`、`bytes.ops`（`SpanEqual/BytesCopy` 零拷贝 single source via `bytes.ops`，`TStringView.Equals/Slice` 零拷贝 `inline`）、`text.scan`（`ScanPredicateTable` VecWidth 表驱动 single source via `bytes.ops`/`simd.vec`，`js.eval` 薄委托复用）、`js.pure.predicates`（`JS_PRED_*` 常量谓词单源经 `text.scan/text.number` owner 单缝，`bytes.ops` 零拷贝 `inline`）、`simd.vec/simd.base`（仅 text.scan 内聚）、`mem`、`platform.dl`（仅 loader）、`platform.fs`（`TryEvalFile` L0直读 `bytes.ops BytesCopy` 零拷贝 64MiB `BYTES_BULK_PARSE_MAX_BYTES`）、`encoding`（`TBytes` base64）—— **L2 js 禁止直接 `simd.vec` 硬耦合，一律经 `text.scan`/`js.pure.predicates` 单源复用，守 module-registry 单缝单向**
- 禁止：`L3` 任何模块（`http/webview/tui`）反向依赖；`*.ffi` 外的生产单元出现 `Windows/BaseUnix/DynLibs/ctypes`；`base/intf` 出现 `platform.dl` 或后端符号；同层 `js→format.limits` 未登记即禁（已由 `bytes.ops BYTES_BULK_PARSE_MAX_BYTES` L1 single source 替代，单源 `bytes.ops`）；**禁止在 `js.*` 内自造 `json` 解析/转义、`fs` 归一化、计时、bench、test runner**（一律复用 `json`/`platform.fs`/`nextpas.core.bench`/`nextpas.core.test` owner，`fs` 已下沉至 `platform.fs` L0，`simd` 仅 `js.eval` 单遍谓词表单源 via `bytes.ops`）
- **复用与反哺纪律**（基本要求）：开发中发现 `json/text/mem/platform.dl/platform.fs` 缺口或性能瓶颈，**毫不犹豫反哺 owner 模块**（提 `core/docs/...` 变更 + 加回归），禁止在 `js` 内堆 workaround/重复造轮子/抄低质量代码；`AI_GUIDE §5 C7/C9` 同检，`ACCEPTANCE G-M1-3` 的 `source-contract` 禁止 `js` 内出现 `SysUtils` 手写转义/自计时
- **常量谓词池**（§9 ↔ §1）：`js→json` 单点已 `pure.value→json.writer` 单缝 allowlist（cycle-gated，`module-registry:50`）；`js.eval` 字面量/哨兵/数值谓词已收敛至 `js.pure.predicates` 单源谓词池（`JS_PRED_LITERALS/JS_PRED_SENTINELS` + `JsPredTryNumber` 经谓词池单缝，`text.number/text.scan` 为 L1 owner 单源，`bytes.ops` 零拷贝 `inline`，`try-finally` 不丢，缺能力反哺 owner）

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

## 变更记录（精简）

> 完整历史见 `CHANGELOG.md`；本表仅保留近 3 版，其余归档至 CHANGELOG。

| 日期 | 版本 | 变更 | 作者 |
|------|------|------|------|
| 2026-09-02 | 2.3 | base 强耦合修复：`js.base` interface 去 `bytes.ops` 直引，能力反哺 `bytes.ops` 单源 | codex/core-js |
| 2026-09-02 | 2.4 | lifecycle 紧凑与强一致：`GPureClosed` 4B + generation-tagged + freelist 半缩 | codex/core-js |
| 2026-09-02 | 2.5 | base 双痛：探针下沉 `loader` 单源 + `CheckJsRuntimeOptions(ABackend)` 归因透传 | codex/core-js |
| 2026-09-02 | 2.6 | base 归因失真修复：`CheckJsRuntimeOptions` 去默认 `jsbkFake`，强制显式 `ABackend` 归因 | codex/core-js |
| 2026-09-03 | 2.7 | 匠心收敛：`js.pure.predicates` 单源谓词池 + `js.base` 表格可读性精简 + `js.eval` 去重 `EVAL_*` 散表 | codex/core-js |

## 附录：极简契约（可抽取候选，≤80 行）

> 精简视图（聚焦 §6 不变量，体积见 §1 单一阈值 800，业务以正文为准，缺能力反哺 owner）。

| 单元 | 职责 | 关键不变量 |
|------|------|------------|
| `js.base` | 类型载体 | 零 `quickjs/v8`，`bytes.ops` 单缝 via impl |
| `js.intf` | `IJsRuntime/Context/TJsValue` | 后端无关，不暴露 `JSValue` |
| `js.pure.base` | 纯类型载体 | base 零依赖（仅 `js.base`，`TJsValue` 去耦 raw `Kind+StrVal` via `pure.value`） |
| `js.registry/factory/门面` | 单源扇出 + 薄转发 | vault 隔离，`CheckJsRuntimeOptions` 显式归因透传（无默认） |
| 不变量 | INV-1..7 | 见 §6，§1–§5 为实现证据 |

守四件套 `base←intf←impl←门面` 与 L0–L3，`bytes.ops` 单源。
