# nextpas.core.window.input 代码契约

**模块路径**：`core/src/nextpas.core.window.input*.pas`（4 文件：`base` + `intf` + `impl` + 门面 `window.input`）
**层级**：L2（见 `core/docs/core-module-registry.md` `window.input` 行；依赖 L0-L1 + `bytes.ops` 单源 direct, no `window.impl` cross-Owner, L2→L1 single source）
**Owner**：`window.input`（core-window lane；`base` 仅纯数据，`impl` 单源扩容 direct `bytes.ops`）
**Public facade**：yes（四件套 `base←intf←impl←门面`）
**Truth level**：`source-contract`
**最后更新**：2026-09-02（独立文档归属修复：12.5 `docs/<module>/CONTRACT.md`，原仅复用 `docs/window/CONTRACT.md:43`）
**上游家族**：`nextpas.core.window` 家族（`core/docs/window/CONTRACT.md §1/§7.1 INV-14` 为家族总览，本文件为 `window.input` 独立契约源；业务以本 CONTRACT 为准，缺能力先反哺 `bytes.ops` owner）

---

## 1. 模块定位

`window.input` 承载 INV-14 输入栈（键鼠/触摸/滚轮/IME 细分），为 `directui/game` 提供 `TWindowInputKind/Event/Options/IWindowInput` 最小闭包。新 `EventKind` 5+ 已由本模块承载，独立 L2，不经 `nextpas.core.window` 门面 re-export。

---

## 2. 四件套布局

| 单元 | 职责 |
|------|------|
| `nextpas.core.window.input.base` | `TWindowInputKind`/`TWindowInputEvent`(托管 string)/`TWindowInputEventView`(视图 TStringView)+`TWindowInputOptions`/`EWindowInputError` 纯数据类型，托管/视图分层复用 `bytes.ops` Span/View 零拷贝 |
| `nextpas.core.window.input.intf` | `IWindowInput` + `TWindowInputHandler/Method/Proc` + `TWindowInputViewHandler/Method/Proc`(视图零拷贝) |
| `nextpas.core.window.input.impl` | `CheckWindowInputOptions` + `WindowInputGrowCapacity` 单源 `bytes.ops` + `WindowInputEventToView/FromView` 视图/托管桥接 `bytes.ops` 单源 |
| `nextpas.core.window.input` | 门面：纯 re-export + `inline` 转发(含 `WindowInputEventToView/FromView/WindowInputViewTextSpan`) |

依赖 `base←intf←impl←门面`，守四件套与 L0-L3；`base/intf` 零后端。

---

## 3. 核心类型（base）

```pascal
TWindowInputKind = (wikKeyDown, wikKeyUp, wikMouseDown, wikMouseUp, wikMouseMove, wikWheel, wikTouch, wikImeCommit);
// 视图变体：零拷贝非托管，Text 为 TStringView (bytes.ops TByteSpan 单源)，inline O(1) 无分配，生命周期绑调用栈/消息
TWindowInputEventView = record Kind: TWindowInputKind; KeyCode: Integer; X,Y,DeltaX,DeltaY: Integer; Text: TStringView; end;
// 托管变体：拥有 string，需拷贝，资源由编译器托管析构不丢
TWindowInputEvent = record Kind: TWindowInputKind; KeyCode: Integer; X,Y,DeltaX,DeltaY: Integer; Text: string; end;
TWindowInputOptions = record EnableKey, EnableMouse, EnableTouch, EnableIme: Boolean; // 默认 True,True,False,False end;
function DefaultWindowInputOptions: TWindowInputOptions; inline;
// 托管/视图桥接 — inline O(1) 零拷贝视图 / 单次 Move 拷贝托管，bytes.ops 单源 TByteSpan/TStringView
function WindowInputEventToView(const AEvent: TWindowInputEvent): TWindowInputEventView; inline; // managed→view: TStringView.FromStr 零拷贝
function WindowInputEventFromView(const AView: TWindowInputEventView): TWindowInputEvent; inline; // view→managed: ToString 单次拷贝
function WindowInputViewTextSpan(const AView: TWindowInputEventView): TByteSpan; inline; // view Text→TByteSpan 零拷贝 bytes.ops 单源
EWindowInputError = class(ENextPasError);
EWindowInputInvalidOptions = class(EWindowInputError);
```

---

## 4. 接口契约（intf）

```pascal
IWindowInput = interface
  ['{A1B2C3D4-1003-4F60-9A8B-C0D1E2F3A102}']
  procedure HandleEvent(const AEvent: TWindowInputEvent); // 托管入口
  procedure HandleEventView(const AEvent: TWindowInputEventView); // 视图零拷贝入口 inline 无分配
  function GetOptions: TWindowInputOptions;
  procedure SetOptions(const AOptions: TWindowInputOptions);
  property Options: TWindowInputOptions read GetOptions write SetOptions;
end;
TWindowInputHandler = reference to procedure(const AEvent: TWindowInputEvent);
TWindowInputMethod = procedure(const AEvent: TWindowInputEvent) of object;
TWindowInputProc = procedure(const AEvent: TWindowInputEvent);
TWindowInputViewHandler = reference to procedure(const AEvent: TWindowInputEventView);
TWindowInputViewMethod = procedure(const AEvent: TWindowInputEventView) of object;
TWindowInputViewProc = procedure(const AEvent: TWindowInputEventView);
```

回调三重载遵循 design-conventions §8（`reference/method/proc` 并存，内部统一 `reference` 存储）；视图三重载同理，零拷贝 `TStringView/TByteSpan` 单源 `bytes.ops`，`ToView/FromView` inline O(1) 无额外分配或单次拷贝。

---

## 5. 实现契约（impl）

- `CheckWindowInputOptions`：当前空校验（保留校验点，`inline`），未来新增输入校验需落于此单源。
- `WindowInputGrowCapacity(ACurrent: Integer): Integer; inline`：`Result := BytesGrowCapacity(ACurrent)` 单源 `0→32→2×` 幂二 direct (no `window.impl`)，`inline` O(1) 均摊；门面同签名 `inline` 转发 L2→L1。
- `WindowInputEventToView/FromView`：`base` 定义单源 `inline`，`impl` 仅薄转发（`Result:=base.WindowInputEventToView`），证零拷贝 `TStringView.FromStr/ToString/ToSpan` 单源 `bytes.ops`，view 无分配 view→managed 单次 `Move` 拷贝，资源由 `string` 托管析构 `try-finally` 不丢。

---

## 6. 不变量

- **INV-14**：输入栈细分最小闭包，新 `EventKind` 由本模块承载；托管/视图分层 — `TWindowInputEvent`(string 托管) 与 `TWindowInputEventView`(TStringView/TByteSpan 零拷贝视图) 双态，桥接 `WindowInputEventToView/FromView` 单源 `bytes.ops`。
- **INV-3**：`base/intf` 零后端（`base` 仅依赖 `base/errors/text.view` L0-L1，`text.view` 单源 `bytes.ops`）。
- 单源：`WindowInputGrowCapacity` 唯一源 `bytes.ops` direct (no `window.impl` cross-Owner, L2→L1)；`ToView/FromView/ViewTextSpan` 唯一源 `base`→`bytes.ops` `TByteSpan/TStringView` 零拷贝。

---

## 7. 性能

- `WindowInputGrowCapacity`：`inline` 单次 `BytesGrowCapacity`，`0→32→2×` O(1) 均摊，零拷贝；`HandleEvent` 为直派，无额外分配。
- `WindowInputEventToView/FromView/ViewTextSpan`：`inline` O(1) — `ToView` 为 `TStringView.FromStr` 指针+长度赋值零拷贝无分配，`ViewTextSpan` 为 `ToSpan` 指针+长度赋值零拷贝，`FromView` 为单次 `ToString` Move 拷贝（`bytes.ops` 单源），`impl` 薄转发、门面 `inline` 转发零额外调用。
- 证据：`core/src/nextpas.core.window.input.base.pas:10-14` `inline` 零拷贝视图（`TStringView.FromStr/ToSpan` 单源 `bytes.ops`）与 `core/src/nextpas.core.window.input.impl.pas:10-13` 薄转发 `inline` + 门面 `core/src/nextpas.core.window.input.pas:14-16` `inline` 单源；`bytes.ops` 零拷贝 `TByteSpan` 视图语义复用，`heaptrc 0`。

---

## 8. 稳定性

- 托管：`TWindowInputEvent.Text: string` 由编译器托管，事件记录拷贝/赋值自动 `CopyArray/FinalizeArray`（`bytes.ops.ManagedCopyArray/FinalizeArray` 单源语义），异常路径 `try-finally` 自动释放，`heaptrc 0` 不丢；视图：`TWindowInputEventView.Text: TStringView/TByteSpan` 非托管零拷贝，生命周期绑调用栈/消息缓冲，不分配不需释放，`FromView` 单次 `ToString` 分配由调用方托管析构。
- 事件分发由 `window` 家族主线程纪律保证（`Post/Close` 跨线程安全，其余 UI 亲和）。

---

## 9. 测试与门禁

| 门禁 | 载体 | 要求 |
|------|------|------|
| source-contract | `test_window_source_contracts` | 四件套、零后端、单源 |
| 契约测试 | `tests/nextpas.core.window/test_*` | `DefaultWindowInputOptions` 默认值、GrowCapacity 单源 |

---

## 10. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-09-02 | 1.0 | 独立 CONTRACT 落地，满足 12.5 归属 |
| 2026-09-02 | 1.1 | 修复 `TWindowInputEvent` 扁平 `string`：分层托管 `TWindowInputEvent`(string) 与视图 `TWindowInputEventView`(TStringView/TByteSpan 零拷贝)，`WindowInputEventToView/FromView/ViewTextSpan` 单源 `bytes.ops` `inline` 零拷贝，守四件套与 L0-L3，`heaptrc 0` 不丢 |

