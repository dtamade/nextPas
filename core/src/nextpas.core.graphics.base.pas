{**
 * nextpas.core.graphics.base - 图形 L1 值类型底座（Color/Rect/Mat2D，Single 外部，零 bytes/font）
 * 单文件 ≤800 行，TPath 在 graphics.path，ColorConvert 在 graphics.color。
 *}
unit nextpas.core.graphics.base;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.base,
  nextpas.core.math.vec,
  nextpas.core.math.mat.base;

type
  { TColor32 - $AARRGGBB sRGB }
  TColor32 = type LongWord;

  TRgba = record
    R, G, B, A: Single;
  end;

  TBlendMode = (
    bmNormal, bmMultiply, bmScreen, bmOverlay, bmDarken, bmLighten,
    bmColorDodge, bmColorBurn, bmHardLight, bmSoftLight, bmDifference,
    bmExclusion, bmHue, bmSaturation, bmColor, bmLuminosity,
    bmPlus, bmSrcOver, bmSrcIn, bmSrcOut, bmSrcAtop,
    bmDstOver, bmDstIn, bmDstOut, bmDstAtop, bmXor, bmClear, bmPlusLighter
  );

  TColorSpace = (csSRGB, csLinear, csDisplayP3);

  TVec2 = record
    X, Y: Single;
    class function Create(AX, AY: Single): TVec2; static; inline;
  end;

  TRect = record
    X, Y, W, H: Single;
    class function From(AX, AY, AW, AH: Single): TRect; static;
    function IsEmpty: Boolean; inline;
    function Area: Single; inline;
  end;

  TMat2D = record
    A, B, C, D, Tx, Ty: Single; // [A C Tx; B D Ty; 0 0 1]
    class function Identity: TMat2D; static; inline;
    class function Translate(DX, DY: Single): TMat2D; static;
    class function Scale(SX, SY: Single): TMat2D; static;
    class function Rotate(Rad: Single): TMat2D; static;
    function Concat(const M: TMat2D): TMat2D; inline;
    function IsInvertible: Boolean; inline;
    function Inverse: TMat2D;
    function TransformPoint(const P: TVec2): TVec2; inline;
  end;

  TGlyphRun = record
    Glyphs: array of LongWord;
    Positions: array of TVec2;
    Scale: Single;
    function IsEmpty: Boolean; inline;
  end;

const
  EPSILON = 1e-6;

{ Bridge to math.vec / math.mat — single source for geometry types. }
function Vec2ToMath(const A: TVec2): TVec2f; inline;
function Vec2FromMath(const A: TVec2f): TVec2; inline;
function Mat2DToMat3f(const A: TMat2D): TMat3f; inline;
function Mat3fToMat2D(const A: TMat3f): TMat2D; inline;

function Color32(R, G, B: Byte; A: Byte = 255): TColor32; inline;
function Color32ToRgba(C: TColor32): TRgba; inline;
function RgbaToColor32(const C: TRgba): TColor32; inline;
function Color32R(C: TColor32): Byte; inline;
function Color32G(C: TColor32): Byte; inline;
function Color32B(C: TColor32): Byte; inline;
function Color32A(C: TColor32): Byte; inline;
procedure Color32Decompose(C: TColor32; out R, G, B, A: Byte); inline;
function RgbaToPixelLE(R, G, B, A: Byte): LongWord; inline;

implementation

uses
  nextpas.core.errors,
  nextpas.core.math,
  nextpas.core.math.scalar;

class function TVec2.Create(AX, AY: Single): TVec2;
begin
  Result.X := AX;
  Result.Y := AY;
end;

class function TRect.From(AX, AY, AW, AH: Single): TRect;
begin
  RequireFinite(AX, 'nextpas.core.graphics.base.pas: TRect.From: AX must be finite');
  RequireFinite(AY, 'nextpas.core.graphics.base.pas: TRect.From: AY must be finite');
  RequireFinite(AW, 'nextpas.core.graphics.base.pas: TRect.From: AW must be finite');
  RequireFinite(AH, 'nextpas.core.graphics.base.pas: TRect.From: AH must be finite');
  if (AW < 0) or (AH < 0) then
    raise EArgumentError.Create('nextpas.core.graphics.base.pas: TRect.From: W/H must be >= 0');
  Result.X := AX;
  Result.Y := AY;
  Result.W := AW;
  Result.H := AH;
end;

function TRect.IsEmpty: Boolean;
begin
  Result := (W <= 0) or (H <= 0);
end;

function TRect.Area: Single;
begin
  if IsEmpty then Exit(0);
  Result := W * H;
end;

class function TMat2D.Identity: TMat2D;
begin
  Result.A := 1; Result.B := 0; Result.C := 0; Result.D := 1; Result.Tx := 0; Result.Ty := 0;
end;

class function TMat2D.Translate(DX, DY: Single): TMat2D;
begin
  RequireFinite(DX, 'nextpas.core.graphics.base.pas: TMat2D.Translate: DX must be finite');
  RequireFinite(DY, 'nextpas.core.graphics.base.pas: TMat2D.Translate: DY must be finite');
  Result := Identity;
  Result.Tx := DX; Result.Ty := DY;
end;

class function TMat2D.Scale(SX, SY: Single): TMat2D;
begin
  RequireFinite(SX, 'nextpas.core.graphics.base.pas: TMat2D.Scale: SX must be finite');
  RequireFinite(SY, 'nextpas.core.graphics.base.pas: TMat2D.Scale: SY must be finite');
  Result := Identity;
  Result.A := SX; Result.D := SY;
end;

class function TMat2D.Rotate(Rad: Single): TMat2D;
var
  S, Cc: Single;
begin
  RequireFinite(Rad, 'nextpas.core.graphics.base.pas: TMat2D.Rotate: Rad must be finite');
  S := Sin(Rad);
  Cc := Cos(Rad);
  Result.A := Cc; Result.B := S; Result.C := -S; Result.D := Cc;
  Result.Tx := 0; Result.Ty := 0;
end;

function TMat2D.Concat(const M: TMat2D): TMat2D;
begin
  RequireFinite(A, 'nextpas.core.graphics.base.pas: TMat2D.Concat: matrix contains NaN/Inf');
  RequireFinite(B, 'nextpas.core.graphics.base.pas: TMat2D.Concat: matrix contains NaN/Inf');
  RequireFinite(C, 'nextpas.core.graphics.base.pas: TMat2D.Concat: matrix contains NaN/Inf');
  RequireFinite(D, 'nextpas.core.graphics.base.pas: TMat2D.Concat: matrix contains NaN/Inf');
  RequireFinite(Tx, 'nextpas.core.graphics.base.pas: TMat2D.Concat: matrix contains NaN/Inf');
  RequireFinite(Ty, 'nextpas.core.graphics.base.pas: TMat2D.Concat: matrix contains NaN/Inf');
  RequireFinite(M.A, 'nextpas.core.graphics.base.pas: TMat2D.Concat: matrix contains NaN/Inf');
  RequireFinite(M.B, 'nextpas.core.graphics.base.pas: TMat2D.Concat: matrix contains NaN/Inf');
  RequireFinite(M.C, 'nextpas.core.graphics.base.pas: TMat2D.Concat: matrix contains NaN/Inf');
  RequireFinite(M.D, 'nextpas.core.graphics.base.pas: TMat2D.Concat: matrix contains NaN/Inf');
  RequireFinite(M.Tx, 'nextpas.core.graphics.base.pas: TMat2D.Concat: matrix contains NaN/Inf');
  RequireFinite(M.Ty, 'nextpas.core.graphics.base.pas: TMat2D.Concat: matrix contains NaN/Inf');
  Result.A := A * M.A + C * M.B;
  Result.B := B * M.A + D * M.B;
  Result.C := A * M.C + C * M.D;
  Result.D := B * M.C + D * M.D;
  Result.Tx := A * M.Tx + C * M.Ty + Tx;
  Result.Ty := B * M.Tx + D * M.Ty + Ty;
end;

function TMat2D.IsInvertible: Boolean;
var
  Det: Single;
begin
  if IsNaN(A) or IsInfinite(A) or IsNaN(B) or IsInfinite(B) or
     IsNaN(C) or IsInfinite(C) or IsNaN(D) or IsInfinite(D) or
     IsNaN(Tx) or IsInfinite(Tx) or IsNaN(Ty) or IsInfinite(Ty) then
    Exit(False);
  Det := A * D - B * C;
  if IsNaN(Det) or IsInfinite(Det) then
    Exit(False);
  Result := Abs(Det) >= EPSILON;
end;

function TMat2D.Inverse: TMat2D;
var
  Det, InvDet: Single;
begin
  RequireFinite(A, 'nextpas.core.graphics.base.pas: TMat2D.Inverse: matrix contains NaN/Inf');
  RequireFinite(B, 'nextpas.core.graphics.base.pas: TMat2D.Inverse: matrix contains NaN/Inf');
  RequireFinite(C, 'nextpas.core.graphics.base.pas: TMat2D.Inverse: matrix contains NaN/Inf');
  RequireFinite(D, 'nextpas.core.graphics.base.pas: TMat2D.Inverse: matrix contains NaN/Inf');
  RequireFinite(Tx, 'nextpas.core.graphics.base.pas: TMat2D.Inverse: matrix contains NaN/Inf');
  RequireFinite(Ty, 'nextpas.core.graphics.base.pas: TMat2D.Inverse: matrix contains NaN/Inf');
  Det := A * D - B * C;
  if IsNaN(Det) or IsInfinite(Det) or (Abs(Det) < EPSILON) then
    raise EArgumentError.Create('nextpas.core.graphics.base.pas: TMat2D not invertible');
  InvDet := 1 / Det;
  Result.A := D * InvDet;
  Result.B := -B * InvDet;
  Result.C := -C * InvDet;
  Result.D := A * InvDet;
  Result.Tx := -(Result.A * Tx + Result.C * Ty);
  Result.Ty := -(Result.B * Tx + Result.D * Ty);
end;

function TMat2D.TransformPoint(const P: TVec2): TVec2;
begin
  RequireFinite(A, 'nextpas.core.graphics.base.pas: TMat2D.TransformPoint: matrix/point contains NaN/Inf');
  RequireFinite(B, 'nextpas.core.graphics.base.pas: TMat2D.TransformPoint: matrix/point contains NaN/Inf');
  RequireFinite(C, 'nextpas.core.graphics.base.pas: TMat2D.TransformPoint: matrix/point contains NaN/Inf');
  RequireFinite(D, 'nextpas.core.graphics.base.pas: TMat2D.TransformPoint: matrix/point contains NaN/Inf');
  RequireFinite(Tx, 'nextpas.core.graphics.base.pas: TMat2D.TransformPoint: matrix/point contains NaN/Inf');
  RequireFinite(Ty, 'nextpas.core.graphics.base.pas: TMat2D.TransformPoint: matrix/point contains NaN/Inf');
  RequireFinite(P.X, 'nextpas.core.graphics.base.pas: TMat2D.TransformPoint: matrix/point contains NaN/Inf');
  RequireFinite(P.Y, 'nextpas.core.graphics.base.pas: TMat2D.TransformPoint: matrix/point contains NaN/Inf');
  Result.X := A * P.X + C * P.Y + Tx;
  Result.Y := B * P.X + D * P.Y + Ty;
end;

function TGlyphRun.IsEmpty: Boolean;
begin
  Result := Length(Glyphs) = 0;
end;

function Vec2ToMath(const A: TVec2): TVec2f;
begin
  Result := TVec2f.Create(A.X, A.Y);
end;

function Vec2FromMath(const A: TVec2f): TVec2;
begin
  Result := TVec2.Create(A.X, A.Y);
end;

function Mat2DToMat3f(const A: TMat2D): TMat3f;
begin
  Result := TMat3f.Create(A.A, A.C, A.Tx, A.B, A.D, A.Ty, 0, 0, 1);
end;

function Mat3fToMat2D(const A: TMat3f): TMat2D;
begin
  Result.A := A.Data[0, 0];
  Result.B := A.Data[1, 0];
  Result.C := A.Data[0, 1];
  Result.D := A.Data[1, 1];
  Result.Tx := A.Data[0, 2];
  Result.Ty := A.Data[1, 2];
end;

function Color32(R, G, B: Byte; A: Byte): TColor32;
begin
  Result := TColor32((LongWord(A) shl 24) or (LongWord(R) shl 16) or (LongWord(G) shl 8) or LongWord(B));
end;

function Color32ToRgba(C: TColor32): TRgba;
begin
  Result.A := ((LongWord(C) shr 24) and $FF) / 255;
  Result.R := ((LongWord(C) shr 16) and $FF) / 255;
  Result.G := ((LongWord(C) shr 8) and $FF) / 255;
  Result.B := (LongWord(C) and $FF) / 255;
end;

function RgbaToColor32(const C: TRgba): TColor32;
var
  R, G, B, A: LongWord;
begin
  if C.R < 0 then R := 0 else if C.R > 1 then R := 255 else R := Round(C.R * 255);
  if C.G < 0 then G := 0 else if C.G > 1 then G := 255 else G := Round(C.G * 255);
  if C.B < 0 then B := 0 else if C.B > 1 then B := 255 else B := Round(C.B * 255);
  if C.A < 0 then A := 0 else if C.A > 1 then A := 255 else A := Round(C.A * 255);
  Result := TColor32((A shl 24) or (R shl 16) or (G shl 8) or B);
end;

function Color32R(C: TColor32): Byte;
begin
  Result := Byte((LongWord(C) shr 16) and $FF);
end;

function Color32G(C: TColor32): Byte;
begin
  Result := Byte((LongWord(C) shr 8) and $FF);
end;

function Color32B(C: TColor32): Byte;
begin
  Result := Byte(LongWord(C) and $FF);
end;

function Color32A(C: TColor32): Byte;
begin
  Result := Byte((LongWord(C) shr 24) and $FF);
end;

procedure Color32Decompose(C: TColor32; out R, G, B, A: Byte);
begin
  R := Byte((LongWord(C) shr 16) and $FF);
  G := Byte((LongWord(C) shr 8) and $FF);
  B := Byte(LongWord(C) and $FF);
  A := Byte((LongWord(C) shr 24) and $FF);
end;

function RgbaToPixelLE(R, G, B, A: Byte): LongWord;
begin
  Result := LongWord(R) or (LongWord(G) shl 8) or (LongWord(B) shl 16) or (LongWord(A) shl 24);
end;

end.
