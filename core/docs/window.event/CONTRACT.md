# nextpas.core.window.event 代码契约

**模块路径**：`core/src/nextpas.core.window.event*.pas`（4 文件：`base` + `intf` + `impl` + 门面 `window.event`）
**层级**：L2（见 `core/docs/core-module-registry.md` `window.event` 行；依赖 L0-L1 + `bytes.ops` 单源 direct, no `window.impl` cross-Owner, L2→L1 single source）
**Owner**：`window.event`（core-window lane；`base` 仅纯数据，`impl` 单源校验/扩容 direct `bytes.ops`）
**Public facade**：yes（`nextpas.core.window.event` 门面纯 re-export + inline 转发，四件套 `base←intf←impl←门面`）
**Truth level**：`source-contract`
**最后更新**：2026-09-02（独立文档归属修复：12.5 `docs/<module>/CONTRACT.md`，原仅复用 `docs/window/CONTRACT.md:48`）
**上游家族**：`nextpas.core.window` 家族（`core/docs/window/CONTRACT.md §1/§7.1 INV-18` 为家族总览，本文件为 `window.event` 独立契约源；业务以本 CONTRACT 为准，缺能力先反哺 `bytes.ops` owner）

---

## 1. 模块定位

`window.event` 承载 INV-18 事件反注册句柄（可撤销 `TWindowEventHandle` 非覆盖），为 `window` 家族提供 `IWindowEventBus/IWindowEventSubscription` 最小闭包。独立 L2 公共模块，不经 `nextpas.core.window` 门面 re-export，高频换 handler 场景由本模块承载（`IWindow.OnEvent` 保留覆盖语义兼容存量，新增订阅路径可多句柄并存）。

---

## 2. 四件套布局

| 单元 | 职责 |
|------|------|
| `nextpas.core.window.event.base` | `TWindowEventHandle`/`TWindowEventBusOptions`/`EWindowEventError` 纯数据类型，零行为 |
| `nextpas.core.window.event.intf` | `IWindowEventSubscription` + `IWindowEventBus` + `TWindowEventHandler/Method/Proc`（复用 `window.base` event 变体） |
| `nextpas.core.window.event.impl` | `CheckWindowEventBusOptions` + `WindowEventGrowCapacity` 单源 `bytes.ops` + `TWindowEventBusImpl` 端到端载体 + `CreateWindowEventBus` 工厂 |
| `nextpas.core.window.event` | 门面：纯 re-export + `inline` 转发 |

依赖 `base←intf←impl←门面`，守四件套与 L0-L3；`base/intf` 零后端。

---

## 3. 核心类型（base）

```pascal
TWindowEventHandle = record Id: UInt64; Generation: UInt32; class function Invalid: TWindowEventHandle; static; inline; function IsValid: Boolean; inline; end;
TWindowEventBusOptions = record MaxHandlers: Integer; end; // 0 = 不限制，默认 0
function DefaultWindowEventBusOptions: TWindowEventBusOptions; inline;

EWindowEventError = class(ENextPasError); // ecInternal
EWindowEventInvalidOptions = class(EWindowEventError);
EWindowEventHandleInvalid = class(EWindowEventError);
```

---

## 4. 接口契约（intf）

```pascal
IWindowEventSubscription = interface
  ['{A1B2C3D4-2002-4F60-9A8B-C0D1E2F3A211}']
  function GetHandle: TWindowEventHandle;
  procedure Unsubscribe; // 幂等
  function IsActive: Boolean;
  property Handle: TWindowEventHandle read GetHandle;
end;
IWindowEventBus = interface
  ['{A1B2C3D4-2002-4F60-9A8B-C0D1E2F3A212}']
  function Subscribe(AHandler: TWindowEventHandler): IWindowEventSubscription; overload;
  function Subscribe(AHandler: TWindowEventMethod): IWindowEventSubscription; overload;
  function Subscribe(AHandler: TWindowEventProc): IWindowEventSubscription; overload;
  procedure Unsubscribe(const AHandle: TWindowEventHandle);
  procedure Clear;
  function Count: Integer;
  procedure Dispatch(const AEvent: TWindowEvent);
  function GetOptions: TWindowEventBusOptions;
  procedure SetOptions(const AOptions: TWindowEventBusOptions);
  property Options: TWindowEventBusOptions read GetOptions write SetOptions;
end;
```

回调三重载遵循 design-conventions §8（`reference/method/proc` 并存，内部统一变体存储）。

---

## 5. 实现契约（impl）

- `TWindowEventBusImpl = class(TInterfacedObject, IWindowEventBus)`：INV-18 端到端载体，`FOptions/FNextId/FGeneration/FSubs/FHandlers/FCount`，`Create` 默认 `DefaultWindowEventBusOptions`、`Create(AOptions)` 校验后持有、`Subscribe` 三重载校验 `Assigned` 且 `MaxHandlers`（>0 时达上限抛 `EWindowEventInvalidOptions`）后 `EnsureCapacity` 单源 `bytes.ops` 并以 `WindowEventVariantFrom*` 直存变体、`Unsubscribe(Handle)` 末尾换位 `RemoveAt` O(1) inline 零拷贝 + `WindowEventVariantClear` 逐槽 nil、`Clear` 循环 `WindowEventVariantClear` + `FActive:=False` + `FSubs[I]:=nil`、`Count` inline 单字段读、`Dispatch` 快照遍历 `IsActive` 者 `WindowEventVariantDispatch` inline 零拷贝 O(n)、`SetOptions` 薄分支校验；COM 引用计数自动释放，无手写 Free。
- `TWindowEventSubscriptionImpl = class(TInterfacedObject, IWindowEventSubscription)`：`FHandle/FActive/FOwner`，`Create(AHandle,AOwner)`，`Unsubscribe` 幂等（`if not FActive then Exit`）并回代理 `Bus.Unsubscribe(FHandle)` 后 `FOwner:=nil`，`IsActive/GetHandle` inline 零拷贝。
- `CheckWindowEventBusOptions`：校验 `MaxHandlers>=0`，违例抛 `EWindowEventInvalidOptions`（`CreateFmt`），`inline` 薄分支。
- `WindowEventGrowCapacity(ACurrent: Integer): Integer; inline`：`Result := BytesGrowCapacity(ACurrent)` 单源 `bytes.ops 0→32→2×` 幂二 direct (no `window.impl`), `inline` 零额外调用 O(1)均摊；门面同签名 `inline` 转发 L2→L1。
- `CreateWindowEventBus(: TWindowEventBusOptions): IWindowEventBus; inline`：`TWindowEventBusImpl.Create` 薄转发，门面同签名 `inline` 转发。

---

## 6. 不变量

- **INV-18**（本模块）：事件反注册句柄最小闭包，可撤销 `TWindowEventHandle`（`Id+Generation`）非覆盖（多句柄并存），`Unsubscribe` 幂等 `heaptrc 0`；`IWindow.OnEvent` 覆盖语义保留兼容存量，新路径走 `IWindowEventBus`。
- **INV-3**：`base/intf` 零后端。
- 单源：`WindowEventGrowCapacity` 唯一源 `bytes.ops`；`TWindowEventVariant` 变体直存 `wwkRef/wwkMethod/wwkProc` 单源复用 `window.base/intf`。

---

## 7. 性能

- `WindowEventGrowCapacity`：`inline` 单次 `BytesGrowCapacity`，`0→32→2×` O(1)均摊，零拷贝（纯算术）；`CheckWindowEventBusOptions` 为 `inline` 薄分支；`Count/GetHandle/IsActive` 为 inline 单字段读。
- `Subscribe/Unsubscribe/Clear/Dispatch`：`Subscribe` 单次 `EnsureCapacity` 单源 `bytes.ops` inline 零拷贝 + 变体直存零额外调用；`Unsubscribe` 末尾换位 O(1) inline 零拷贝；`Clear` 逐槽 `WindowEventVariantClear` nil 复位不丢；`Dispatch` 快照 inline 零拷贝 O(n) 分发。
- 证据：`core/src/nextpas.core.window.event.impl.pas:62-64` 与门面 `window.event.pas` `inline` 转发。

---

## 8. 稳定性

- `TWindowEventBusImpl` 持有 `FSubs: array of IWindowEventSubscription` + `FHandlers: array of TWindowEventVariant`，COM 引用计数自动释放，`Destroy` 循环 `WindowEventVariantClear(FHandlers[I])` + `FSubs[I]:=nil` + `SetLength(*,0)` 托管释放不丢；`RemoveAt/Clear` 逐槽 `WindowEventVariantClear` + `FSubs:=nil` 复位，`TWindowEventSubscriptionImpl.Unsubscribe` 幂等且互斥回代理；校验失败抛异常由边界捕获；`heaptrc 0`（家族门禁）。
- 资源释放：`EnsureCapacity` 双数组 `SetLength` 单源扩容，失败不丢旧数据；`Dispatch` 不持有锁，快照分发零拷贝。

---

## 9. 测试与门禁

| 门禁 | 载体 | 要求 |
|------|------|------|
| source-contract | `test_window_source_contracts` | 四件套、零后端、单源 inline、TWindowEventBusImpl 载体 |
| 契约测试 | `tests/nextpas.core.window/test_*` | 无效 handler 抛 `EWindowEventHandleInvalid`、MaxHandlers 达限抛错、GrowCapacity 单源、Subscribe/Unsubscribe/Clear/Dispatch 端到端、Handle 非覆盖多句柄、幂等 Unsubscribe |

---

## 10. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-09-02 | 1.0 | 独立 CONTRACT 落地，满足 12.5 归属 |

