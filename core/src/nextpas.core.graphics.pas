{**
 * nextpas.core.graphics - 图形 L1 门面：纯 re-export，消费方 uses 此单元即可。
 * 门面通过 inline 转发聚合 base/color/path 的公共 API，无自有逻辑，符合设计规范门面职责
 *}
unit nextpas.core.graphics;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.graphics.base,
  nextpas.core.graphics.color,
  nextpas.core.graphics.path;

type
  TColor32 = nextpas.core.graphics.base.TColor32;
  TRgba = nextpas.core.graphics.base.TRgba;
  TBlendMode = nextpas.core.graphics.base.TBlendMode;
  TColorSpace = nextpas.core.graphics.base.TColorSpace;
  TVec2 = nextpas.core.graphics.base.TVec2;
  TRect = nextpas.core.graphics.base.TRect;
  TMat2D = nextpas.core.graphics.base.TMat2D;

  TPath = nextpas.core.graphics.path.TPath;
  TPathBuilder = nextpas.core.graphics.path.TPathBuilder;
  TPathVerb = nextpas.core.graphics.path.TPathVerb;
  TLineCap = nextpas.core.graphics.path.TLineCap;
  TLineJoin = nextpas.core.graphics.path.TLineJoin;
  TStrokeOptions = nextpas.core.graphics.path.TStrokeOptions;
  TGradientKind = nextpas.core.graphics.path.TGradientKind;
  TGradient = nextpas.core.graphics.path.TGradient;

function Color32(R, G, B: Byte; A: Byte = 255): TColor32; inline;
function Color32ToRgba(C: TColor32): TRgba; inline;
function RgbaToColor32(const C: TRgba): TColor32; inline;
function ColorConvert(const C: TRgba; Src, Dst: TColorSpace): TRgba; inline;

implementation

function Color32(R, G, B: Byte; A: Byte): TColor32;
begin
  Result := nextpas.core.graphics.base.Color32(R, G, B, A);
end;

function Color32ToRgba(C: TColor32): TRgba;
begin
  Result := nextpas.core.graphics.base.Color32ToRgba(C);
end;

function RgbaToColor32(const C: TRgba): TColor32;
begin
  Result := nextpas.core.graphics.base.RgbaToColor32(C);
end;

function ColorConvert(const C: TRgba; Src, Dst: TColorSpace): TRgba;
begin
  Result := nextpas.core.graphics.color.ColorConvert(C, Src, Dst);
end;

end.
