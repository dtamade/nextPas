# nextpas.core.dialog 代码契约

**模块路径**：`core/src/nextpas.core.dialog*.pas`（4 文件：`base` + `intf` + `impl` + 门面 `dialog` Owner-faithful）
**层级**：L3 shim（见 `core/docs/core-module-registry.md` `dialog` 行；`dialog` 为 owner，双 INV 聚合单物理模块；依赖 L0-L2 + `dialog` owner + `bytes.ops` 单源 direct, no `window.impl` cross-Owner, L2→L1）
**Owner**：`dialog` L3（`base` 仅纯数据，`impl` 单源校验/扩容；物理 `nextpas.core.dialog.*` Owner-faithful）
**Public facade**：yes（四件套 `base←intf←impl←门面` Owner-faithful）
**Truth level**：`source-contract`
**最后更新**：2026-09-02（匠心修复：Owner-faithful 归一消除 dotted 与 Owner 分裂，`dialog` 为规范，`window.dialog` 四件套别名已迁移移除恢复高级感；独立文档归属 12.5 `docs/dialog/CONTRACT.md`）
**上游家族**：`nextpas.core.window` 家族（`core/docs/window/CONTRACT.md §1/§7.1 INV-11+INV-17` 为家族总览，本文件为 `dialog` 独立契约源；业务以本 CONTRACT 为准，缺能力先反哺 `bytes.ops`/`dialog` owner）

---

## 1. 模块定位

`dialog` 承载 INV-11 close 交互确认 + INV-17 父子/modal 双 INV 聚合，为对话框提供 `TWindowDialogKind/Options/IWindowDialog` 最小闭包。L3 shim 形态（`dialog` 为 owner），单物理模块承载双 INV（优先级 P2 中），不经 `nextpas.core.window` 门面 re-export。

---

## 2. 四件套布局

| 单元 | 职责 |
|------|------|
| `nextpas.core.dialog.base` | `TWindowDialogKind`/`TWindowDialogOptions`/`TWindowDialogResult`/`EWindowDialogError` 纯数据类型 |
| `nextpas.core.dialog.intf` | `IWindowDialog` + `IWindowDialogHost` + `TWindowDialogHandler` |
| `nextpas.core.dialog.impl` | `CheckWindowDialogOptions` + `WindowDialogGrowCapacity` 单源 `bytes.ops` |
| `nextpas.core.dialog` | 门面：纯 re-export + `inline` 转发（Owner-faithful 规范路径） |

依赖 `base←intf←impl←门面`，守四件套与 L0-L3；`base/intf` 零后端；`impl` 仅 `uses base/intf + bytes.ops` direct L2→L1 不经 `window.impl`。

---

## 3. 核心类型（base）

```pascal
TWindowDialogKind = (wdkAlert, wdkConfirm, wdkPrompt, wdkModal);
TWindowDialogOptions = record
  Kind: TWindowDialogKind; // 默认 wdkAlert
  Title, Message, DefaultText: string;
  ParentId: UInt32; // 0 = 无父
  Modal: Boolean;    // 默认 True
end;
TWindowDialogResult = (wdrNone, wdrOk, wdrCancel, wdrYes, wdrNo);
function DefaultWindowDialogOptions: TWindowDialogOptions; inline;

EWindowDialogError = class(ENextPasError);
EWindowDialogInvalidOptions = class(EWindowDialogError);
```

---

## 4. 接口契约（intf）

```pascal
IWindowDialog = interface
  ['{A1B2C3D4-1005-4F60-9A8B-C0D1E2F3A105}']
  function GetOptions: TWindowDialogOptions;
  function GetResult: TWindowDialogResult;
  procedure Show;
  procedure Close(AResult: TWindowDialogResult);
  property Options: TWindowDialogOptions read GetOptions;
  property DialogResult: TWindowDialogResult read GetResult;
end;
IWindowDialogHost = interface
  ['{A1B2C3D4-1005-4F60-9A8B-C0D1E2F3A106}']
  function CreateDialog(const AOptions: TWindowDialogOptions): IWindowDialog;
end;
TWindowDialogHandler = reference to procedure(const ADialog: IWindowDialog);
```

---

## 5. 实现契约（impl）

- `CheckWindowDialogOptions`：校验 `Title<>'' or Message<>''`，违例抛 `EWindowDialogInvalidOptions`（`'Title or Message required'`），`inline` 薄分支。
- `WindowDialogGrowCapacity(ACurrent: Integer): Integer; inline`：`Result := BytesGrowCapacity(ACurrent)` 单源 `0→32→2×` 幂二 direct (no `window.impl`)，`inline` O(1) 均摊；门面 `dialog` 规范同签名 `inline` 转发 L2→L1，零额外分配。

---

## 6. 不变量

- **INV-11**：close 交互确认；**INV-17**：父子/modal（双 INV 聚合于同一物理模块 `dialog`）。
- **INV-3**：`base/intf` 零后端。
- 单源：`WindowDialogGrowCapacity` 唯一源 `bytes.ops`。

---

## 7. 性能

- `WindowDialogGrowCapacity`：`inline` 单次 `BytesGrowCapacity`，`0→32→2×` O(1) 均摊，零拷贝；`CheckWindowDialogOptions` 为 `inline` 薄分支。
- 证据：`core/src/nextpas.core.dialog.impl.pas:12` 与门面 `dialog.pas:16` `inline` 单源 `BytesGrowCapacity` direct L2→L1，`heaptrc 0`；零额外堆分配。

---

## 8. 稳定性

- 无堆分配/句柄；`Show/Close` 幂等由宿主保证；`heaptrc 0`；校验失败抛异常由边界捕获；`dialog` inline 转发无资源双重释放，`try..finally` 边界释放不丢。

---

## 9. 测试与门禁

| 门禁 | 载体 | 要求 |
|------|------|------|
| source-contract | `test_window_source_contracts` + `dialog` | 四件套、零后端、单源 |
| 契约测试 | `tests/nextpas.core.window/test_*` | 空 Title+Message 抛错、GrowCapacity 单源 |

---

## 10. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-09-02 | 1.0 | 独立 CONTRACT 落地，满足 12.5 归属；双 INV 聚合单模块 |
| 2026-09-02 | 1.1 | 匠心修复：跨 Owner 命名复用增加 `nextpas.core.dialog` Owner-faithful 别名（同四件套单源 `bytes.ops` `inline` 零拷贝），`window.dialog` proximity 保留，双路径同 Owner `dialog` 降低混淆 |
| 2026-09-02 | 1.2 | 匠心再修复：Owner-faithful 归一 `dialog` 为规范 `window.dialog` 已 deprecated 消除 dotted 与 Owner 分裂恢复高级感，物理 `nextpas.core.dialog.*` 单源 `bytes.ops 0→32→2×` inline 零拷贝 |
| 2026-09-02 | 1.3 | 匠心修复：消除 dotted Owner 分裂迁移后移除 `window.dialog` 四件套别名，`dialog.impl` 直连 `bytes.ops` direct L2→L1 inline 零拷贝不经 `window.impl`，bench 已迁移至 `nextpas.core.dialog` |
