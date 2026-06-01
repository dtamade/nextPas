# nextpas.core.tui

Terminal UI 渲染框架——把 ratatui 的核心思想（immediate mode、双缓冲 diff、数组化 cell 布局）以 FreePascal 原生方式实现。

## 快速开始

```pascal
uses nextpas.core.tui;

var
  App: TTuiApp;
begin
  App := TTuiApp.Create;
  App.OnRender := @MyRender;
  App.Run;
end;
```

## 架构

```
L3 框架层（只依赖 L0-L2）

数据流：TCell → TBuffer → Diff → TAnsiBackend → stdout
事件流：stdin → PollEvent → TEvent → 消费方
帧循环：BeginFrame → Render → EndFrame（merge overlay → diff → flush → swap）
```

## 门面 API

消费方优先 `uses nextpas.core.tui`。门面显式 re-export 基础类型、布局/事件 helper、
widget 接口和 builder 类，让文档中的自然名称（如 `TRect`、`IWidget`、`TBlock`）可直接使用。
旧的 `TTui*` / `ITui*` 兼容别名保留，便于已有调用方平滑迁移。

`TWidgetAdapter` 保留为小型扩展点：当消费方已有自定义渲染函数，或需要桥接外部 widget
实现时，可以把非空 `TWidgetRenderFn` 包装成 `IWidget`。传入 nil render function 会 fail-fast。

## 模块清单

| 模块 | 职责 |
|------|------|
| `tui.base` | TRect / TPosition / TSize / TMargin / TDirection |
| `tui.color` | TColor（4 字节 packed，Reset/Indexed/Rgb） |
| `tui.modifier` | TModifier（SGR 属性位集） |
| `tui.style` | TStyle（Fg/Bg/Ul + AddMod/SubMod，Patch 语义） |
| `tui.cell` | TCell（40 字节 packed，23 字节内联 glyph） |
| `tui.buffer` | TBuffer（连续 cell 数组，diff 引擎） |
| `tui.overlay` | TOverlayBuffer（稀疏覆盖层） |
| `tui.text` | TSpan / TLine / TText（grapheme-aware 样式文本树） |
| `tui.layout` | TLayout + TConstraint（约束求解器） |
| `tui.event` | TEvent（键盘/鼠标/resize） |
| `tui.input` | ParseOne（字节流 → TEvent） |
| `tui.terminal` | TTerminal（帧生命周期 + 事件循环） |
| `tui.app` | TApp（应用循环） |
| `tui.widget.*` | 40 个 widget（block/paragraph/list/table/gauge/...） |

## Widget 接口设计

```pascal
// IWidget 基础渲染契约
IWidget = interface
  procedure Render(const AArea: TRect; ABuffer: TBuffer);
end;

// IBlock 容器接口（被其他 widget 引用）
IBlock = interface(IWidget)
  function Inner(const AArea: TRect): TRect;
  function WithBorders(ABorders: TBorders): IBlock;
  function WithTitle(const ATitle: AnsiString): IBlock;
end;

// 使用
var Block: IBlock;
begin
  Block := TBlock.New.WithBorders(BORDERS_ALL).WithTitle('Dashboard');
  Block.Render(Area, Buffer);
end;
```

## 依赖

- `nextpas.core.text.width`（grapheme-aware Unicode 显示宽度）
- `nextpas.core.text.grapheme`（UAX#29 grapheme cluster 分段）
- `nextpas.core.text.utf8`（UTF-8 解码）
- `nextpas.core.text.builder`（TStringBuilder，ANSI 输出）
- `nextpas.core.platform.console`（raw mode / read / write / wait）
- `nextpas.core.platform.signal`（SIGWINCH / SIGTERM）
- `nextpas.core.platform.time`（monotonic clock）

## 设计原则

1. **Immediate mode** — widget 不持有渲染状态，每帧重新描述 UI
2. **热路径零分配** — cell 数组连续、PCell 指针直写、QWord×5 diff
3. **接口优先** — IWidget/IBlock/IListWidget，COM 引用计数自动释放
4. **Platform facade** — 不碰 host ABI，全部通过 platform.console/signal/time
