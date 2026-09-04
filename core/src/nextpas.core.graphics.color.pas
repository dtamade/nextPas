{**
 * nextpas.core.graphics.color - 色彩空间转换（sRGB/Linear/DisplayP3）
 * S2 真 P3 矩阵（线性域 3x3，经 XYZ D65），gamma 用 LUT 线性插值批化 + inline 零拷贝。
 * Single 外部，P3 同 sRGB 传递函数，仅线性域矩阵分流。
 *}
unit nextpas.core.graphics.color;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.graphics.base;

function ColorConvert(const C: TRgba; Src, Dst: TColorSpace): TRgba;

implementation

uses
  nextpas.core.math;

const
  // sRGB linear -> Display P3 linear (D65), via XYZ (Lindbloom)
  // [ 0.8224619 0.1775380 0.0; 0.0331941 0.9668058 0.0; 0.0170827 0.0723974 0.9105199 ]
  SRGB_TO_P3_M00 = 0.8224619696; SRGB_TO_P3_M01 = 0.1775380;    SRGB_TO_P3_M02 = 0.0;
  SRGB_TO_P3_M10 = 0.0331941;    SRGB_TO_P3_M11 = 0.9668058;   SRGB_TO_P3_M12 = 0.0;
  SRGB_TO_P3_M20 = 0.0170827;    SRGB_TO_P3_M21 = 0.0723974;   SRGB_TO_P3_M22 = 0.9105199;
  // Display P3 linear -> sRGB linear (inverse)
  P3_TO_SRGB_M00 = 1.2249401;  P3_TO_SRGB_M01 = -0.2249401; P3_TO_SRGB_M02 = 0.0;
  P3_TO_SRGB_M10 = -0.0420569; P3_TO_SRGB_M11 = 1.0420569;  P3_TO_SRGB_M12 = 0.0;
  P3_TO_SRGB_M20 = -0.0196376; P3_TO_SRGB_M21 = -0.0786361; P3_TO_SRGB_M22 = 1.0982736;

const
  LUT_N = 1024;
  LUT_SCALE = LUT_N - 1; // 1023

var
  GLutS2L: array[0..LUT_N - 1] of Single;
  GLutL2S: array[0..LUT_N - 1] of Single;

{ LUT 插值：Single 输入 [0,1] 零堆、单次 Move/lerp，无 per-pixel Ln/Exp }
function SrgbToLinearFast(C: Single): Single; inline;
var
  F: Single;
  I: Integer;
  T: Single;
begin
  if C <= 0.0 then Exit(0.0);
  if C >= 1.0 then Exit(1.0);
  if C <= 0.04045 then Exit(C * 0.07739938080495357); // 1/12.92
  F := C * LUT_SCALE;
  I := Trunc(F);
  if I >= LUT_SCALE then Exit(GLutS2L[LUT_SCALE]);
  T := F - I;
  Result := GLutS2L[I] * (1.0 - T) + GLutS2L[I + 1] * T; // lerp, inline, zero-copy
end;

function LinearToSrgbFast(C: Single): Single; inline;
var
  F: Single;
  I: Integer;
  T: Single;
begin
  if C <= 0.0 then Exit(0.0);
  if C >= 1.0 then Exit(1.0);
  if C <= 0.0031308 then Exit(C * 12.92);
  F := C * LUT_SCALE;
  I := Trunc(F);
  if I >= LUT_SCALE then Exit(GLutL2S[LUT_SCALE]);
  T := F - I;
  Result := GLutL2S[I] * (1.0 - T) + GLutL2S[I + 1] * T;
end;

function GammaDecode(const C: TRgba): TRgba; inline;
begin
  Result.R := SrgbToLinearFast(C.R);
  Result.G := SrgbToLinearFast(C.G);
  Result.B := SrgbToLinearFast(C.B);
  Result.A := C.A;
end;

function GammaEncode(const C: TRgba): TRgba; inline;
begin
  Result.R := LinearToSrgbFast(C.R);
  Result.G := LinearToSrgbFast(C.G);
  Result.B := LinearToSrgbFast(C.B);
  Result.A := C.A;
end;

function LinearSrgbToP3(const L: TRgba): TRgba; inline;
begin
  Result.R := SRGB_TO_P3_M00 * L.R + SRGB_TO_P3_M01 * L.G + SRGB_TO_P3_M02 * L.B;
  Result.G := SRGB_TO_P3_M10 * L.R + SRGB_TO_P3_M11 * L.G + SRGB_TO_P3_M12 * L.B;
  Result.B := SRGB_TO_P3_M20 * L.R + SRGB_TO_P3_M21 * L.G + SRGB_TO_P3_M22 * L.B;
  Result.A := L.A;
end;

function LinearP3ToSrgb(const L: TRgba): TRgba; inline;
begin
  Result.R := P3_TO_SRGB_M00 * L.R + P3_TO_SRGB_M01 * L.G + P3_TO_SRGB_M02 * L.B;
  Result.G := P3_TO_SRGB_M10 * L.R + P3_TO_SRGB_M11 * L.G + P3_TO_SRGB_M12 * L.B;
  Result.B := P3_TO_SRGB_M20 * L.R + P3_TO_SRGB_M21 * L.G + P3_TO_SRGB_M22 * L.B;
  Result.A := L.A;
end;

function ColorConvert(const C: TRgba; Src, Dst: TColorSpace): TRgba;
var
  L: TRgba; // canonical linear sRGB
  Tmp: TRgba;
begin
  if Src = Dst then Exit(C);
  // Src -> linear sRGB (single source, no duplicate three-line)
  case Src of
    csSRGB: L := GammaDecode(C);
    csDisplayP3:
      begin
        Tmp := GammaDecode(C); // P3 gamma same as sRGB
        L := LinearP3ToSrgb(Tmp); // S2 真矩阵
      end;
    csLinear: L := C;
  end;
  if Dst = csLinear then Exit(L);
  case Dst of
    csSRGB: Result := GammaEncode(L);
    csDisplayP3:
      begin
        Tmp := LinearSrgbToP3(L); // S2 真矩阵
        Result := GammaEncode(Tmp);
      end;
    csLinear: Result := L; // already handled, keep for completeness
  else
    Result := L;
  end;
end;

var
  GLutInitDone: Boolean = False;

procedure InitLut;
var
  I: Integer;
  V: Single;
begin
  if GLutInitDone then Exit;
  for I := 0 to LUT_N - 1 do
  begin
    V := I / LUT_SCALE;
    // init 单次 Power 填充，per-pixel 仅 LUT lerp，无 Ln/Exp 逐像素
    if V <= 0.04045 then GLutS2L[I] := V / 12.92
    else GLutS2L[I] := Power(Double((V + 0.055) / 1.055), 2.4);
    if V <= 0.0031308 then GLutL2S[I] := V * 12.92
    else GLutL2S[I] := 1.055 * Power(V, Double(1.0 / 2.4)) - 0.055;
  end;
  GLutInitDone := True;
end;

initialization
  InitLut;

end.
