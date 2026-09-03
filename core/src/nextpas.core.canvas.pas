{**
 * nextpas.core.canvas - 画布门面（ICanvas + Raster）
 * 纯 re-export，无逻辑；base←intf←raster←facade。
 *}
unit nextpas.core.canvas;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.canvas.base,
  nextpas.core.canvas.intf,
  nextpas.core.canvas.raster;

type
  TFilterQuality = nextpas.core.canvas.base.TFilterQuality;
  TBrush = nextpas.core.canvas.intf.TBrush;
  TBrushKind = nextpas.core.canvas.intf.TBrushKind;
  TGlyphRun = nextpas.core.canvas.intf.TGlyphRun;
  ICanvas = nextpas.core.canvas.intf.ICanvas;
  ICanvasGuard = nextpas.core.canvas.intf.ICanvasGuard;

function CreateRasterCanvas(AWidth, AHeight: Integer): ICanvas; inline;

implementation

function CreateRasterCanvas(AWidth, AHeight: Integer): ICanvas;
begin
  Result := nextpas.core.canvas.raster.CreateRasterCanvas(AWidth, AHeight);
end;

end.
