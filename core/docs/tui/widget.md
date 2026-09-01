# nextpas.core.tui.widget — 基础 Widget 域契约

**模块**：`nextpas.core.tui.widget.{base,intf,pas}` 四件套（聚合 `block`/`paragraph`/`list`/`table`/`tabs`/`scrollbar`/`clear`/`input` 8 核心）
**层级**：L3 tui
**四件套**：`widget.base` ← `widget.intf` ← `widget` 门面；实现聚合 8 核心 widget
**依赖**：L0–L2 only（`text.width` + `bytes.ops` 单源）
**对应主契约**：`CONTRACT.md` §1.2 IWidget/Stateful + §1.3 core 8 控件 + §5.4 同步更新
**门禁**：`IWidget` 接口 refcount 自动释放（`heaptrc 0`），零拷贝 `TRect` 裁剪

## 职责

- `IWidget` 无状态渲染契约 + `RenderStateful` 有状态扩展（`TListState`/`TTabsState` 等外部 record）
- 8 核心：`Block`/`Paragraph`/`List`/`Table`/`Tabs`/`Scrollbar`/`Clear`/`Input`（core facade）
- `HandleKey: Boolean`（True=已消费）+ `HandleMouse`（SplitPane 先例）

## 性能

- 零拷贝 `TRect` 视图裁剪（`Area.Intersection` inline，无分配）
- 热点 `inline`：`RenderStateful` 分发 + `StyleFg`/`StyleBg`/`CellApplyStyle`
- 复用 `bytes.ops` 单源（文本 grapheme 解码 `text.utf8` + `text.width`，不复制）

## 稳定性

- widget 通过 COM 接口引用计数自动释放，不丢句柄
- `Stateful` state 由调用方持有（immediate mode），无帧间悬垂

## Owner 边界

- 缺能力先反哺 `text.width`/`bytes.ops`/`platform.console`，不绕 `input`/`backend`
