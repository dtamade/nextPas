# nextpas.core.tui.canvas — 画布/图像协议域契约

**模块**：`nextpas.core.tui.canvas.{base,intf,pas}` 四件套（已落地；独立子家族，不寄居主包）
**层级**：L3 tui.experimental（opt-in 波动面）
**四件套**：`canvas.base` ← `canvas.intf` ← `canvas` 门面；实现聚合 `canvas.raster` + `canvas.view` + `canvas.edit` + `canvas.export` + `canvas.docstore` + `canvas.clipboard` + `canvas.floodfill` + `image_cap` + `clipboard`
**依赖**：L0–L2 only（`bytes.ops` 单源 + `image_cap`/`clipboard` 协议）
**对应主契约**：`CONTRACT.md` §1.1 canvas + `image_cap` + `clipboard` + §5.4 同步更新
**门禁**：`heaptrc 0`（`IAllocator` 下传 buffer 不丢）

## 职责

- `TCanvasDoc`/`TCanvasLayer`/`TCanvasCell`（`Ch`/`Fg`/`Bg`，`Ch=0` 未画 / `32` 空格，脏矩形 `MarkDirtyRect`/`ConsumeDirtyRect`）
- 光栅化：`RasterLine`/`RasterRectOutline/Fill`/`RasterEllipseOutline/Fill`（Bresenham + 纯回调 `TRasterPointProc`）
- 编辑：`TCanvasEditBuilder` + `TCanvasUndoLog`（双栈 `Push`/`Undo`/`Redo`，`CanvasApplyOpInverse`）
- 视图：`TCanvasView`（文档↔屏幕坐标、缩放 1..4、平移/居中、`ScreenToDoc` 向下取整）
- 剪贴板：`TCanvasClipboard`（矩形快照复制/粘贴，越界裁剪，经 builder 入撤销栈）
- 填充：`CanvasFloodFill4`（4-连通显式栈，10 万格上限）
- 导出：`CanvasExportTxt`/`CanvasExportAnsi`（SGR 着色，零 RTL 依赖）
- 持久化：`CanvasDocSaveToJson`/`CanvasDocLoadFromJson`（RLE 行编码 + 调色板去重，格式版本 1）
- 协议：`image_cap`（`ipHalfBlock`/`ipKitty`/`ipSixel` 检测）+ `clipboard`（OSC 52）

## 性能

- 零拷贝 `TByteSpan` 像素视图（`RowPtr`/`CellPtr` 直接指针，不复制）
- 热点 `inline`：`CanvasIsEmptyCell`/`CanvasCellSpan`（`canvas.intf`）+ `raster` 命中判定 + `MarkDirtyRect` 扩张
- 复用 `bytes.ops` 单源（RLE 编码 + `SpanEqual` 视图，不复制像素）

## 稳定性

- `IAllocator` 下传 buffer（`Create(... AAllocator)`），生命周期 ⊆ allocator
- `TCanvasDoc.Destroy` 释放 layers（dynarray 托管），`heaptrc 0`
- `FillChar` 清零即 `CANVAS_CELL_EMPTY`（`SizeOf` 断言 12 字节）

## Owner 边界

- 缺能力先反哺 `bytes.ops`（RLE/像素视图）/`text.width`/`platform`，不绕 `image_mgr` 直接画

## 四件套落地证据

- `canvas.base`：`TCanvasCell`/`TCanvasLayer`/`TCanvasDoc` + 脏矩形（12 字节值记录，`FillChar` 零化）
- `canvas.intf`：`ICanvasDoc` 接口契约（`Width`/`Height`/`GetCell`/`SetCell`，`inline` `CanvasIsEmptyCell`/`CanvasCellSpan` 零拷贝 `TByteSpan` + `bytes.ops` 单源）
- `canvas`：聚合门面（`canvas.base`/`canvas.raster`/`canvas.edit`/`canvas.view`/`canvas.clipboard`/`canvas.floodfill`/`canvas.export`/`canvas.docstore`）
- 详 `canvas/README.md`（子域完整能力 + 质量 gate）
