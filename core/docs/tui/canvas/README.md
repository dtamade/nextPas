# nextpas.core.tui.canvas — 字符像素画布

**域**: `nextpas.core.tui.canvas`（tui 名空间下的独立子域，不修改任何已封板的 tui 单元）

**状态**: 新增子域 · 基础能力已交付（doc/raster/edit/view/clipboard/floodfill/export + 测试 + 基准 + 示例）

## 定位

每个终端格 = 一个像素（`TCanvasCell`：字形码点 + 前景色 + 背景色）。本子域提供
"字符像素绘图"所需的模型层能力，与 tui 既有的 widget/Buffer 体系互补、但独立：

- **不做**渲染输出（那是 `TBuffer`/widget 的职责）
- **不做**光标/输入交互（那是应用层职责）
- **提供**文档模型、光栅化算法、增量撤销栈、视口变换——绘图类应用（像素画、
  图表、地图编辑器）可直接套用

## 组成

| 单元 | 内容 |
|------|------|
| `nextpas.core.tui.canvas.base` | `TCanvasCell`/`TCanvasLayer`/`TCanvasDoc`：多层字符像素文档、脏矩形、CellPtr/RowPtr 热路径 |
| `nextpas.core.tui.canvas.raster` | `RasterLine`（Bresenham 顺序点）、`RasterRectOutline/Fill`、`RasterEllipseOutline/Fill`，纯回调输出 |
| `nextpas.core.tui.canvas.edit` | `TCanvasEditBuilder` 收集增量、`TCanvasUndoLog` 双栈撤销、`CanvasApplyOp(Inverse)` |
| `nextpas.core.tui.canvas.view` | `TCanvasView`：文档↔屏幕坐标、缩放 1..4、平移/居中、屏幕行脏标记 |
| `nextpas.core.tui.canvas.clipboard` | `TCanvasClipboard`：应用内单槽剪贴板（矩形快照复制/粘贴、越界裁剪、经 builder 入撤销栈） |
| `nextpas.core.tui.canvas.floodfill` | `CanvasFloodFill4`：4-连通种子填充（显式栈、10 万格上限、增量可撤销） |
| `nextpas.core.tui.canvas.export` | `CanvasExportTxt`/`CanvasExportAnsi`：活动层导出纯字形 / SGR 着色文本（零 RTL 依赖） |
| `nextpas.core.tui.canvas.docstore` | `CanvasDocSaveToJson`/`CanvasDocLoadFromJson`：文档↔JSON 持久化（RLE 行编码 + 调色板去重，格式版本 1） |
| `nextpas.core.tui.canvas` | 聚合门面（纯 re-export） |

## 快速上手

```pascal
uses
  nextpas.core.tui.color,
  nextpas.core.tui.canvas.base,
  nextpas.core.tui.canvas.raster,
  nextpas.core.tui.canvas.edit;   { 按需 use 子件; 聚合门面不保证符号传递可见 }

type
  TStroke = class
    B: TCanvasEditBuilder;
    C: TCanvasCell;
    procedure OnPoint(AX, AY: Integer);
  end;

procedure TStroke.OnPoint(AX, AY: Integer);
begin
  B.SetPixel(AX, AY, C);            { 写文档 + 记录增量 }
end;

var
  D: TCanvasDoc;
  B: TCanvasEditBuilder;
  U: TCanvasUndoLog;
  S: TStroke;
  Op: TCanvasEditOp;
begin
  D := TCanvasDoc.Create(80, 24);   { 默认 1 层 'Layer 1' }
  B := TCanvasEditBuilder.Create(D, 0);
  U := TCanvasUndoLog.Create;
  S := TStroke.Create;
  try
    S.B := B;
    S.C := CanvasMakeCell(Ord('*'), TUI_GREEN, TUI_BLACK);
    RasterLine(0, 0, 79, 23, @S.OnPoint);
    U.Push(B.ToOp);                 { 一笔即一步撤销 }
    ...
    Op := U.Undo;
    CanvasApplyOpInverse(D, Op);    { 撤销: 逆序写旧值 }
  finally
    S.Free; U.Free; B.Free; D.Free;
  end;
end;
```

> `Raster*` 回调类型是 `procedure(...) of object`，传类/记录方法即可（见上方
> `TStroke`）；示例另有完整版可运行：`examples/nextpas.core.tui.canvas/demo_canvas`。

## 语义约定

- `TCanvasCell.Ch = 0` 表示"未画"格（渲染时空格无样式）；`Ch = 32` 表示显式背景空格。
- `TCanvasCell` 是 12 字节纯值记录（`LongWord` + 两个 4 字节 `TColor`），整块
  `FillChar` 清零即得 `CANVAS_CELL_EMPTY`；该布局由 `SizeOf` 编译期断言守护。
- 层索引 0 为底层（先绘制），`LayerVisible = False` 的层由渲染器跳过。
- 脏矩形区间闭合，写路径自动累积，`ConsumeDirtyRect` 每帧消费一次。
- `TCanvasView` 的 `ScreenToDoc*` 用向下取整除法（平移可为负）；`SetZoom` 以
  中心文档点为锚重算原点。

## 与 `nextpas.core.tui.widget.canvas` 的区别

`widget.canvas` 是被动渲染的 Braille 点阵控件（`ICanvas`，布尔点阵、`DrawCircle`
等简单图元，用于 widget 内嵌绘图）。本子域是**数据模型层**：字符像素 + 图层 +
完整光栅化 + 增量撤销 + 视口变换。二者可组合（widget 显示 canvas 文档），
但 API 无交集。

## 质量

- 测试：`tests/nextpas.core.tui.canvas/` 4 个 suite（doc 15 / raster 18 / edit 10 /
  view 12），`make test` 全绿、heaptrc 0 泄漏。
- 基准：`benchmarks/nextpas.core.tui.canvas/bench_canvas`（`make run`）。
- 示例：`examples/nextpas.core.tui.canvas/demo_canvas`（`make run`，ASCII 快照输出）。

## 迁移路径（tuiDesign888 等既有应用）

原 `td888_doc/raster/edit/view` → 本子域的对应类型：

| 原项目 | 本子域 |
|--------|--------|
| `TDoc` / `TDocCell` / `TLayer` | `TCanvasDoc` / `TCanvasCell` / `TCanvasLayer` |
| `TPointProc` | `TRasterPointProc` |
| `TEditOp` / `TUndoManager` / `TEditBuilder` | `TCanvasEditOp` / `TCanvasUndoLog` / `TCanvasEditBuilder` |
| `TDesignView` | `TCanvasView` |
| 默认层名 `'图层1'` | `CANVAS_DEFAULT_LAYER_NAME`（`'Layer 1'`，语言中立） |
| `RasterLinePts`（与 `RasterLine` 同实现） | 已合并为 `RasterLine` 单一入口 |
| `ApplyOp` / `ApplyOpInverse` | `CanvasApplyOp` / `CanvasApplyOpInverse` |