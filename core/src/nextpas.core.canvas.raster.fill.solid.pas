{**
 * nextpas.core.canvas.raster.fill.solid - 纯色梯形填充
 * L2 实现子模块，零堆/复用 bytes.ops 单源，inline/零拷贝。
 *}
unit nextpas.core.canvas.raster.fill.solid;

{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.graphics.base,
  nextpas.core.image.base,
  nextpas.core.vector.tess;

procedure FillTrapezoidsSolid(var ABitmap: TBitmap; const ATraps: array of TTrapezoid; AColor: TColor32; const AClipR: TRect; AHasClip: Boolean);

implementation

uses
  nextpas.core.base,
  nextpas.core.math,
  nextpas.core.simd.raster;

procedure FillTrapezoidsSolid(var ABitmap: TBitmap; const ATraps: array of TTrapezoid; AColor: TColor32; const AClipR: TRect; AHasClip: Boolean);
var
  I, X0, X1, Y, YStart, YEnd, W, H: Integer;
  R, G, B, A: Byte;
  P: PByte;
  Tr: TTrapezoid;
  DH, T: Single;
  XL, XR: Single;
begin
  if ABitmap.IsEmpty then Exit;
  W := ABitmap.Width;
  H := ABitmap.Height;
  R := Byte((LongWord(AColor) shr 16) and $FF);
  G := Byte((LongWord(AColor) shr 8) and $FF);
  B := Byte(LongWord(AColor) and $FF);
  A := Byte((LongWord(AColor) shr 24) and $FF);
  if A = 0 then Exit;
  ABitmap.EnsureUnique;
  for I := 0 to High(ATraps) do
  begin
    Tr := ATraps[I];
    if IsNaN(Tr.Y0) or IsInfinite(Tr.Y0) or IsNaN(Tr.Y1) or IsInfinite(Tr.Y1) or
       IsNaN(Tr.XL0) or IsInfinite(Tr.XL0) or IsNaN(Tr.XL1) or IsInfinite(Tr.XL1) or
       IsNaN(Tr.XR0) or IsInfinite(Tr.XR0) or IsNaN(Tr.XR1) or IsInfinite(Tr.XR1) then Continue;
    DH := Tr.Y1 - Tr.Y0;
    if Abs(DH) < EPSILON then Continue;
    YStart := Trunc(Tr.Y0);
    YEnd := Trunc(Tr.Y1);
    if (YEnd <= 0) or (YStart >= H) then Continue;
    if YStart < 0 then YStart := 0;
    if YEnd > H then YEnd := H;
    if AHasClip then
    begin
      if AClipR.IsEmpty then Continue;
      if YEnd <= Trunc(AClipR.Y) then Continue;
      if YStart >= Trunc(AClipR.Y + AClipR.H) then Continue;
      if YStart < Trunc(AClipR.Y) then YStart := Trunc(AClipR.Y);
      if YEnd > Trunc(AClipR.Y + AClipR.H) then YEnd := Trunc(AClipR.Y + AClipR.H);
    end;
    if YEnd <= YStart then Continue;
    for Y := YStart to YEnd - 1 do
    begin
      if DH <= 1.01 then
      begin
        XL := Tr.XL0;
        XR := Tr.XR0;
      end
      else
      begin
        T := (Single(Y) + 0.5 - Tr.Y0) / DH;
        if T < 0 then T := 0 else if T > 1 then T := 1;
        XL := Tr.XL0 + T * (Tr.XL1 - Tr.XL0);
        XR := Tr.XR0 + T * (Tr.XR1 - Tr.XR0);
      end;
      X0 := Trunc(XL + 0.5);
      X1 := Trunc(XR + 0.5);
      if X0 < 0 then X0 := 0;
      if X1 > W then X1 := W;
      if AHasClip then
      begin
        if X1 <= Trunc(AClipR.X) then Continue;
        if X0 >= Trunc(AClipR.X + AClipR.W) then Continue;
        if X0 < Trunc(AClipR.X) then X0 := Trunc(AClipR.X);
        if X1 > Trunc(AClipR.X + AClipR.W) then X1 := Trunc(AClipR.X + AClipR.W);
      end;
      if X1 <= X0 then Continue;
      P := ABitmap.UnsafeMutableRowPtr(Y) + X0 * 4;
      if A = 255 then
        RasterFillSolid(P, X1 - X0, R, G, B, A)
      else
        RasterBlendSrcOver(P, X1 - X0, R, G, B, A);
    end;
  end;
end;

end.
