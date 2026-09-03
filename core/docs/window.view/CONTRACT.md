# nextpas.core.window.view 代码契约

**模块路径**：`core/src/nextpas.core.window.view*.pas`（4 文件：`base` + `intf` + `impl` + 门面 `window.view`）
**层级**：L2（见 `core/docs/core-module-registry.md` `window.view` 行；依赖 L0-L1 + `bytes.ops` 单源 direct, no `window.impl` cross-Owner, L2→L1 single source）
**Owner**：`window.view`（core-window lane；`base` 仅纯数据，`impl` 单源校验/扩容 direct `bytes.ops`）
**Public facade**：yes（四件套 `base←intf←impl←门面`）
**Truth level**：`source-contract`
**最后更新**：2026-09-02（独立文档归属修复：12.5 `docs/<module>/CONTRACT.md`，原仅复用 `docs/window/CONTRACT.md:44`）
**上游家族**：`nextpas.core.window` 家族（`core/docs/window/CONTRACT.md §1/§7.1 INV-16` 为家族总览，本文件为 `window.view` 独立契约源；业务以本 CONTRACT 为准，缺能力先反哺 `bytes.ops` owner）

---

## 1. 模块定位

`window.view` 承载 INV-16 多视图/通信，为单窗多 `View` 场景提供 `TWindowViewId/Options/IWindowView/IWindowViewHost` 最小闭包。独立 L2，不经 `nextpas.core.window` 门面 re-export。

---

## 2. 四件套布局

| 单元 | 职责 |
|------|------|
| `nextpas.core.window.view.base` | `TWindowViewId`/`TWindowViewOptions`/`EWindowViewError` 纯数据类型 |
| `nextpas.core.window.view.intf` | `IWindowView` + `IWindowViewHost` |
| `nextpas.core.window.view.impl` | `CheckWindowViewOptions` + `WindowViewGrowCapacity` 单源 `bytes.ops` |
| `nextpas.core.window.view` | 门面：纯 re-export + `inline` 转发 |

依赖 `base←intf←impl←门面`，守四件套与 L0-L3；`base/intf` 零后端。

---

## 3. 核心类型（base）

```pascal
TWindowViewId = type UInt32;
TWindowViewOptions = record
  Id: TWindowViewId;
  Title: string;
  Width, Height: Integer; // >=0，默认 800×600
end;
function DefaultWindowViewOptions: TWindowViewOptions; inline;

EWindowViewError = class(ENextPasError);
EWindowViewInvalidOptions = class(EWindowViewError);
```

---

## 4. 接口契约（intf）

```pascal
IWindowView = interface
  ['{A1B2C3D4-1004-4F60-9A8B-C0D1E2F3A103}']
  function GetId: TWindowViewId;
  function GetOptions: TWindowViewOptions;
  procedure SetOptions(const AOptions: TWindowViewOptions);
  property Id: TWindowViewId read GetId;
  property Options: TWindowViewOptions read GetOptions write SetOptions;
end;
IWindowViewHost = interface
  ['{A1B2C3D4-1004-4F60-9A8B-C0D1E2F3A104}']
  function CreateView(const AOptions: TWindowViewOptions): IWindowView;
  procedure DestroyView(AId: TWindowViewId);
  function FindView(AId: TWindowViewId): IWindowView;
end;
```

---

## 5. 实现契约（impl）

- `CheckWindowViewOptions`：校验 `Width>=0`/`Height>=0`，违例抛 `EWindowViewInvalidOptions`（`CreateFmt`），`inline` 薄分支。
- `WindowViewGrowCapacity(ACurrent: Integer/SizeUInt): Integer/SizeUInt; inline`：`Result := BytesGrowCapacity(ACurrent)` 单源 `0→32→2×` 幂二 direct (no `window.impl`)，`inline` O(1) 均摊；门面同签名 `inline` 转发 L2→L1。

---

## 6. 不变量

- **INV-16**：多 view/通信最小闭包。
- **INV-3**：`base/intf` 零后端。
- 单源：`WindowViewGrowCapacity` 唯一源 `bytes.ops`。

---

## 7. 性能

- `WindowViewGrowCapacity`：`inline` 单次 `BytesGrowCapacity`，`0→32→2×` O(1) 均摊，零拷贝；`CheckWindowViewOptions` 为 `inline` 薄分支。
- 证据：`core/src/nextpas.core.window.view.impl.pas:5-11` `inline` `BytesGrowCapacity` direct (no `window.impl`) 与门面 `window.view.pas` `inline` 单源 L2→L1。

---

## 8. 稳定性

- 无堆分配/句柄；`heaptrc 0`；`FindView` 无值返回 `nil`（不抛异常），`DestroyView` 幂等由宿主保证。

---

## 9. 测试与门禁

| 门禁 | 载体 | 要求 |
|------|------|------|
| source-contract | `test_window_source_contracts` | 四件套、零后端、单源 |
| 契约测试 | `tests/nextpas.core.window/test_*` | 无效 Width/Height 抛错、GrowCapacity 单源 |

---

## 10. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-09-02 | 1.0 | 独立 CONTRACT 落地，满足 12.5 归属 |

