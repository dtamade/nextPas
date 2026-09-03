unit nextpas.core.tui.canvas;

{**
 * @desc 字符像素画布（tui.canvas 子域聚合门面）。
 *
 * re-export 全部子件。注意：FPC 不保证 interface uses 的符号对消费者
 * 传递可见，实际使用请按需直接 use 子件（base/raster/edit/...）；
 * 门面主要用于文档化"该域提供哪些能力"。
 *   - base       TCanvasDoc / TCanvasCell / 多层管理 / 脏矩形
 *   - raster     Bresenham 直线、矩形、椭圆光栅化（回调输出）
 *   - edit       增量编辑、撤销/重做栈、差量应用
 *   - view       TCanvasView 文档↔屏幕坐标变换与行脏标记
 *   - clipboard  应用内剪贴板（矩形快照复制/粘贴）
 *   - floodfill  4-连通区域种子填充（CanvasFloodFill4）
 *   - export     活动层导出 txt / ansi
 *   - docstore   文档持久化 JSON 序列化（CanvasDocSaveToJson/LoadFromJson）
 *  边界：本门面为 `canvas.*` 子家族聚合（`canvas.base`←`canvas.intf`←聚合门面），
 *  不寄居 `nextpas.core.tui` 主包；主包聚合零分配，`HEAPTRC_GATE=1` heaptrc0 双路径固化，
 *  `bytes.ops` 单源零拷贝（`RowPtr`/`CellPtr`/`CanvasCellSpan` inline）不复制像素。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui.canvas.base,
  nextpas.core.tui.canvas.raster,
  nextpas.core.tui.canvas.edit,
  nextpas.core.tui.canvas.view,
  nextpas.core.tui.canvas.clipboard,
  nextpas.core.tui.canvas.floodfill,
  nextpas.core.tui.canvas.export,
  nextpas.core.tui.canvas.docstore;

implementation

end.