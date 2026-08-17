unit nextpas.core.tui.canvas;

{**
 * @desc 字符像素画布（tui.canvas 子域聚合门面）。
 *
 * 纯 re-export：一个 uses 即获得画布四件套——
 *   - base   TCanvasDoc / TCanvasCell / 多层管理 / 脏矩形
 *   - raster Bresenham 直线、矩形、椭圆光栅化（回调输出）
 *   - edit   增量编辑、撤销/重做栈、差量应用
 *   - view   TCanvasView 文档↔屏幕坐标变换与行脏标记
 *
 * 若只需其中一部分，可直接 use 对应子件，不必引入整域。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui.canvas.base,
  nextpas.core.tui.canvas.raster,
  nextpas.core.tui.canvas.edit,
  nextpas.core.tui.canvas.view;

implementation

end.