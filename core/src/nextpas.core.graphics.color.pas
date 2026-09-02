{**
 * nextpas.core.graphics.color - 色彩空间转换（sRGB/Linear/DisplayP3）
 * 零 RTL，Single 外部，P3 占位 S2 真实现。
 *}
unit nextpas.core.graphics.color;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.graphics.base;

function ColorConvert(const C: TRgba; Src, Dst: TColorSpace): TRgba;

implementation

function SrgbToLinear(C: Single): Single; inline;
begin
  if C <= 0.04045 then Result := C / 12.92
  else Result := Exp(Ln((C + 0.055) / 1.055) * 2.4);
end;

function LinearToSrgb(C: Single): Single; inline;
begin
  if C <= 0.0031308 then Result := C * 12.92
  else Result := 1.055 * Exp(Ln(C) * (1/2.4)) - 0.055;
end;

function ColorConvert(const C: TRgba; Src, Dst: TColorSpace): TRgba;
var
  L: TRgba;
begin
  if Src = Dst then Exit(C);
  // 先转 Linear
  if Src = csSRGB then
  begin
    L.R := SrgbToLinear(C.R); L.G := SrgbToLinear(C.G); L.B := SrgbToLinear(C.B); L.A := C.A;
  end
  else if Src = csDisplayP3 then
  begin
    // P3 占位：暂按 sRGB 同算，S2 真 P3 矩阵
    L.R := SrgbToLinear(C.R); L.G := SrgbToLinear(C.G); L.B := SrgbToLinear(C.B); L.A := C.A;
  end
  else L := C;

  if Dst = csLinear then Exit(L);
  if Dst = csSRGB then
  begin
    Result.R := LinearToSrgb(L.R); Result.G := LinearToSrgb(L.G); Result.B := LinearToSrgb(L.B); Result.A := L.A;
    Exit;
  end;
  // Dst P3 占位
  Result.R := LinearToSrgb(L.R); Result.G := LinearToSrgb(L.G); Result.B := LinearToSrgb(L.B); Result.A := L.A;
end;

end.
