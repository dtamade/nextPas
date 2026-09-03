# nextpas.core.window.dpi 代码契约

**模块路径**：`core/src/nextpas.core.window.dpi*.pas`（4 文件：`base` + `intf` + `impl` + 门面 `window.dpi`）
**层级**：L2（见 `core/docs/core-module-registry.md` `window.dpi` 行；依赖 L0-L1 + `bytes.ops` 单源 direct, no `window.impl` cross-Owner, L2→L1 single source）
**Owner**：`window.dpi`（core-window lane；`base` 仅纯数据，`impl` 单源校验/扩容 direct `bytes.ops`）
**Public facade**：yes（`nextpas.core.window.dpi` 门面纯 re-export + inline 转发，四件套 `base←intf←impl←门面`）
**Truth level**：`source-contract`
**最后更新**：2026-09-02（独立文档归属修复：12.5 `docs/<module>/CONTRACT.md`，原仅复用 `docs/window/CONTRACT.md:47`）
**上游家族**：`nextpas.core.window` 家族（`core/docs/window/CONTRACT.md §1/§7.1 INV-15` 为家族总览，本文件为 `window.dpi` 独立契约源；业务以本 CONTRACT 为准，缺能力先反哺 `bytes.ops` owner）

---

## 1. 模块定位

`window.dpi` 承载 INV-15 per-monitor 重排（多显示器 DPI 监听与订阅可撤销），为 `window` 家族提供 `TWindowDpiInfo/Options/IWindowDpi/IWindowDpiSubscription` 最小闭包。独立 L2 公共模块，不经 `nextpas.core.window` 门面 re-export，DPI 诚实表不变量由本模块承载。

---

## 2. 四件套布局

| 单元 | 职责 |
|------|------|
| `nextpas.core.window.dpi.base` | `TWindowDpiMonitorId`/`TWindowDpiInfo`/`TWindowDpiOptions`/`EWindowDpiError` 纯数据类型，零行为 |
| `nextpas.core.window.dpi.intf` | `IWindowDpi`/`IWindowDpiSubscription` + `TWindowDpiChangedHandler/Method/Proc` |
| `nextpas.core.window.dpi.impl` | `CheckWindowDpiOptions` + `WindowDpiGrowCapacity` 单源 `bytes.ops` + `TWindowDpiImpl` 端到端载体 + `CreateWindowDpi` 工厂 |
| `nextpas.core.window.dpi` | 门面：纯 re-export + `inline` 转发 |

依赖 `base←intf←impl←门面`，守四件套与 L0-L3；`base/intf` 零后端。

---

## 3. 核心类型（base）

```pascal
TWindowDpiMonitorId = type UInt32;
TWindowDpiInfo = record MonitorId: TWindowDpiMonitorId; ScaleFactor: Double; Width, Height: Integer; end;
TWindowDpiOptions = record MonitorId: TWindowDpiMonitorId; ListenPerMonitor: Boolean; end;
function DefaultWindowDpiOptions: TWindowDpiOptions; inline;
function DefaultWindowDpiInfo: TWindowDpiInfo; inline;

EWindowDpiError = class(ENextPasError); // ecInternal
EWindowDpiInvalidOptions = class(EWindowDpiError);
```

---

## 4. 接口契约（intf）

```pascal
IWindowDpiSubscription = interface
  ['{A1B2C3D4-2001-4F60-9A8B-C0D1E2F3A201}']
  procedure Unsubscribe; // 幂等
  function IsActive: Boolean;
end;
IWindowDpi = interface
  ['{A1B2C3D4-2001-4F60-9A8B-C0D1E2F3A202}']
  function GetScaleFactor: Double;
  function GetMonitorScale(AMonitor: TWindowDpiMonitorId): Double;
  function Subscribe(AHandler: TWindowDpiChangedHandler): IWindowDpiSubscription; overload;
  function Subscribe(AHandler: TWindowDpiChangedMethod): IWindowDpiSubscription; overload;
  function Subscribe(AHandler: TWindowDpiChangedProc): IWindowDpiSubscription; overload;
  procedure NotifyChanged(const AInfo: TWindowDpiInfo);
  function GetOptions: TWindowDpiOptions;
  procedure SetOptions(const AOptions: TWindowDpiOptions);
  property Options: TWindowDpiOptions read GetOptions write SetOptions;
end;
TWindowDpiChangedHandler = reference to procedure(const AInfo: TWindowDpiInfo);
TWindowDpiChangedMethod = procedure(const AInfo: TWindowDpiInfo) of object;
TWindowDpiChangedProc = procedure(const AInfo: TWindowDpiInfo);
```

---

## 5. 实现契约（impl）

- `TWindowDpiImpl = class(TInterfacedObject, IWindowDpi)`：INV-15 端到端载体，`FOptions/FScale/FNextId/FSubs/FCount` 值类型+接口数组，`Create` 默认 `DefaultWindowDpiOptions`、`Create(AOptions)` 校验后持有、`GetScaleFactor/GetMonitorScale` inline 零拷贝、`Subscribe` 三重载单源 `EnsureCapacity` + 存储 `TWindowDpiSubscriptionImpl`、`NotifyChanged` 校验 `ScaleFactor>0` 后 inline 零拷贝 O(n) 遍历已订阅且 `IsActive` 者、`SetOptions` 薄分支校验；COM 引用计数自动释放，无手写 Free。
- `TWindowDpiSubscriptionImpl = class(TInterfacedObject, IWindowDpiSubscription)`：`FActive/FId`，`Unsubscribe` 幂等置 `FActive:=False`，`IsActive` inline 零拷贝。
- `CheckWindowDpiOptions`：`MonitorId` 0 为主屏任意 UInt32 合法，`ListenPerMonitor` 标志零校验，`inline` 薄分支。
- `WindowDpiGrowCapacity(ACurrent: Integer): Integer; inline`：`Result := BytesGrowCapacity(ACurrent)` 单源 `bytes.ops 0→32→2×` 幂二 direct (no `window.impl`), `inline` 零额外调用 O(1)均摊；门面同签名 `inline` 转发 L2→L1。
- `CreateWindowDpi(: TWindowDpiOptions): IWindowDpi; inline`：`TWindowDpiImpl.Create` 薄转发，门面同签名 `inline` 转发。

---

## 6. 不变量

- **INV-15**（本模块）：per-monitor 重排最小闭包，DPI 监听可撤销，`NotifyChanged` inline 零拷贝 O(n) 已订阅分发，未落地前不提供假装 API。
- **INV-3**：`base/intf` 零后端。
- 单源：`WindowDpiGrowCapacity` 唯一源 `bytes.ops`。

---

## 7. 性能

- `WindowDpiGrowCapacity`：`inline` 单次 `BytesGrowCapacity`，`0→32→2×` O(1)均摊，零拷贝（纯算术）；`CheckWindowDpiOptions` 为 `inline` 薄分支；`NotifyChanged` 为 inline 零拷贝 O(n) 遍历已订阅。
- `TWindowDpiImpl.GetScaleFactor/GetMonitorScale/GetOptions/SetOptions/Subscribe`：`inline` O(1) zero-copy（字段读/写或单次接口存储，零堆分配外 `EnsureCapacity` 单源 `bytes.ops`）；`CreateWindowDpi` 为 `inline` 单次 `TWindowDpiImpl.Create` 零额外调用。
- 证据：`core/src/nextpas.core.window.dpi.impl.pas:57-58` 与门面 `window.dpi.pas` `inline` 转发。

---

## 8. 稳定性

- `TWindowDpiImpl` 无句柄，仅值类型 `FOptions/FScale` + 接口数组 `FSubs`，COM 引用计数自动释放，`Destroy` 循环 `FSubs[I]:=nil` + `SetLength(FSubs,0)` 托管释放不丢；`Unsubscribe` 幂等，`NotifyChanged` 校验失败抛 `EWindowDpiInvalidOptions` 由边界捕获；`heaptrc 0`（家族门禁）。
- 资源释放：`EnsureCapacity` 纯 `SetLength` 扩容，失败不丢旧 `FSubs`；`Clear` 路径由 `Destroy` 覆盖。

---

## 9. 测试与门禁

| 门禁 | 载体 | 要求 |
|------|------|------|
| source-contract | `test_window_source_contracts` | 四件套、零后端、单源 inline、TWindowDpiImpl 载体 |
| 契约测试 | `tests/nextpas.core.window/test_*` | 默认 `ListenPerMonitor=True`、`NotifyChanged` ScaleFactor>0 校验、GrowCapacity 单源、Subscribe/Unsubscribe 可撤销 |

---

## 10. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-09-02 | 1.0 | 独立 CONTRACT 落地，满足 12.5 归属 |

