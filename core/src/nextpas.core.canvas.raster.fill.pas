{**
 * nextpas.core.canvas.raster.fill - trapezoid fill facade
 * 纯 re-export，零逻辑，四件套门面，<800行，复用 bytes.ops 单源。
 *}
unit nextpas.core.canvas.raster.fill;

{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.graphics.base,
  nextpas.core.graphics.path,
  nextpas.core.image.base,
  nextpas.core.vector.tess,
  nextpas.core.canvas.raster.fill.solid,
  nextpas.core.canvas.raster.fill.gradient;

procedure FillTrapezoids(var ABitmap: TBitmap; const ATraps: array of TTrapezoid; AColor: TColor32; const AClipR: TRect; AHasClip: Boolean); inline;
procedure FillTrapezoidsGradient(var ABitmap: TBitmap; const ATraps: array of TTrapezoid; const AGrad: TGradient; const ABounds: TRect; ARadial: Boolean; const AClipR: TRect; AHasClip: Boolean); inline;
function SampleGradient(const AGrad: TGradient; t: Single): TColor32; inline;

implementation

procedure FillTrapezoids(var ABitmap: TBitmap; const ATraps: array of TTrapezoid; AColor: TColor32; const AClipR: TRect; AHasClip: Boolean); inline;
begin
  nextpas.core.canvas.raster.fill.solid.FillTrapezoidsSolid(ABitmap, ATraps, AColor, AClipR, AHasClip);
end;

procedure FillTrapezoidsGradient(var ABitmap: TBitmap; const ATraps: array of TTrapezoid; const AGrad: TGradient; const ABounds: TRect; ARadial: Boolean; const AClipR: TRect; AHasClip: Boolean); inline;
begin
  nextpas.core.canvas.raster.fill.gradient.FillTrapezoidsGradientImpl(ABitmap, ATraps, AGrad, ABounds, ARadial, AClipR, AHasClip);
end;

function SampleGradient(const AGrad: TGradient; t: Single): TColor32; inline;
begin
  Result := nextpas.core.canvas.raster.fill.gradient.SampleGradient(AGrad, t);
end;

end.
