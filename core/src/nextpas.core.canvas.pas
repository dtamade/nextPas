{**
 * nextpas.core.canvas - 画布门面（ICanvas + Raster）
 *}
unit nextpas.core.canvas;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.canvas.intf,
  nextpas.core.canvas.raster;

function CreateRasterCanvas(AWidth, AHeight: Integer): ICanvas; inline;

type
  TFilterQuality = nextpas.core.canvas.intf.TFilterQuality;
  TBrush = nextpas.core.canvas.intf.TBrush;
  TBrushKind = nextpas.core.canvas.intf.TBrushKind;
  TGlyphRun = nextpas.core.canvas.intf.TGlyphRun;
  ICanvas = nextpas.core.canvas.intf.ICanvas;

implementation

function CreateRasterCanvas(AWidth, AHeight: Integer): ICanvas;
begin Result := nextpas.core.canvas.raster.CreateRasterCanvas(AWidth, AHeight); end;

end.
