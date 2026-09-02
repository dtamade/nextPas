{**
 * nextpas.core.canvas.raster.fill.gradient - 渐变梯形填充 LUT+CHUNK
 * L2 实现子模块，零堆/复用 bytes.ops 单源，inline/零拷贝，分块 64 批式 blend。
 *}
unit nextpas.core.canvas.raster.fill.gradient;

{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.graphics.base,
  nextpas.core.graphics.path,
  nextpas.core.image.base,
  nextpas.core.vector.tess;

procedure FillTrapezoidsGradientImpl(var ABitmap: TBitmap; const ATraps: array of TTrapezoid; const AGrad: TGradient; const ABounds: TRect; ARadial: Boolean; const AClipR: TRect; AHasClip: Boolean);

function SampleGradient(const AGrad: TGradient; t: Single): TColor32; inline;

implementation

uses
  nextpas.core.base,
  nextpas.core.math,
  nextpas.core.simd.raster;

function SampleGradient(const AGrad: TGradient; t: Single): TColor32; inline;
var
  n, i, lo, hi, mid: Integer;
  c0, c1: TColor32;
  s0, s1, lt: Single;
  r0, g0, b0, a0, r1, g1, b1, a1, rr, gg, bb, aa: Byte;
begin
  n := AGrad.ColorCount;
  if n = 0 then Exit(TColor32(0));
  if n = 1 then Exit(AGrad.GetColor(0));
  if t <= 0 then Exit(AGrad.GetColor(0));
  if t >= 1 then Exit(AGrad.GetColor(n - 1));
  if AGrad.StopCount = 0 then
  begin
    i := Trunc(t * (n - 1));
    if i < 0 then i := 0 else if i >= n - 1 then i := n - 2;
    s0 := i / (n - 1);
    s1 := (i + 1) / (n - 1);
    c0 := AGrad.GetColor(i);
    c1 := AGrad.GetColor(i + 1);
  end
  else
  begin
    lo := 0; hi := n - 1;
    while hi - lo > 1 do
    begin
      mid := (lo + hi) shr 1;
      if t < AGrad.GetStop(mid) then hi := mid else lo := mid;
    end;
    i := lo;
    if i < 0 then i := 0 else if i >= n - 1 then i := n - 2;
    s0 := AGrad.GetStop(i);
    s1 := AGrad.GetStop(i + 1);
    c0 := AGrad.GetColor(i);
    c1 := AGrad.GetColor(i + 1);
  end;
  if Abs(s1 - s0) < 1e-6 then Exit(c0);
  lt := (t - s0) / (s1 - s0);
  if lt < 0 then lt := 0 else if lt > 1 then lt := 1;
  r0 := Byte((LongWord(c0) shr 16) and $FF); g0 := Byte((LongWord(c0) shr 8) and $FF);
  b0 := Byte(LongWord(c0) and $FF); a0 := Byte((LongWord(c0) shr 24) and $FF);
  r1 := Byte((LongWord(c1) shr 16) and $FF); g1 := Byte((LongWord(c1) shr 8) and $FF);
  b1 := Byte(LongWord(c1) and $FF); a1 := Byte((LongWord(c1) shr 24) and $FF);
  rr := Byte(Round(r0 + lt * (r1 - r0)));
  gg := Byte(Round(g0 + lt * (g1 - g0)));
  bb := Byte(Round(b0 + lt * (b1 - b0)));
  aa := Byte(Round(a0 + lt * (a1 - a0)));
  Result := Color32(rr, gg, bb, aa);
end;

procedure FillTrapezoidsGradientImpl(var ABitmap: TBitmap; const ATraps: array of TTrapezoid; const AGrad: TGradient; const ABounds: TRect; ARadial: Boolean; const AClipR: TRect; AHasClip: Boolean);
const
  LUT_N = 256;
  CHUNK_SIZE = 64;
var
  I, Y, YStart, YEnd, W, H, X0, X1: Integer;
  Tr: TTrapezoid;
  DH, T: Single;
  XL, XR: Single;
  t0, stepT, invW: Single;
  Row, P: PByte;
  CX, CY, Rad, Dx0, Dy0, stepDx, stepDy, Dist: Single;
  UseInv: Boolean;
  Inv: TMat2D;
  InvA, InvB, InvC, InvD, InvTx, InvTy: Single;
  rowBaseX, rowBaseY, py: Single;
  n, c, seg: Integer;
  Lut: array[0..255] of LongWord;
  Chunk: array[0..63] of LongWord;
  cnt, off, rem, j, idx: Integer;
  tt, lt, s0, s1: Single;
  Dx, Dy: Single;
  c0, c1: LongWord;
  r0, g0, b0, a0, r1, g1, b1, a1, rr, gg, bb, aa: Byte;
  hasStops: Boolean;
  allOpaque: Boolean;
begin
  if ABitmap.IsEmpty then Exit;
  W := ABitmap.Width; H := ABitmap.Height;
  if ABounds.IsEmpty then Exit;
  n := AGrad.ColorCount;
  if n = 0 then Exit;
  hasStops := AGrad.StopCount > 0;
  if n = 1 then
    for c := 0 to LUT_N - 1 do Lut[c] := LongWord(AGrad.GetColor(0))
  else if not hasStops then
  begin
    for c := 0 to LUT_N - 1 do
    begin
      tt := c / (LUT_N - 1) * (n - 1);
      seg := Trunc(tt);
      if seg < 0 then seg := 0 else if seg >= n - 1 then seg := n - 2;
      lt := tt - seg;
      c0 := LongWord(AGrad.GetColor(seg)); c1 := LongWord(AGrad.GetColor(seg + 1));
      r0 := Byte((c0 shr 16) and $FF); g0 := Byte((c0 shr 8) and $FF); b0 := Byte(c0 and $FF); a0 := Byte((c0 shr 24) and $FF);
      r1 := Byte((c1 shr 16) and $FF); g1 := Byte((c1 shr 8) and $FF); b1 := Byte(c1 and $FF); a1 := Byte((c1 shr 24) and $FF);
      rr := Byte(Round(r0 + lt * (r1 - r0))); gg := Byte(Round(g0 + lt * (g1 - g0)));
      bb := Byte(Round(b0 + lt * (b1 - b0))); aa := Byte(Round(a0 + lt * (a1 - a0)));
      Lut[c] := LongWord(rr) shl 16 or LongWord(gg) shl 8 or LongWord(bb) or LongWord(aa) shl 24;
    end;
  end
  else
  begin
    seg := 0;
    for c := 0 to LUT_N - 1 do
    begin
      tt := c / (LUT_N - 1);
      while (seg < n - 2) and (tt > AGrad.GetStop(seg + 1)) do Inc(seg);
      if seg < 0 then seg := 0 else if seg >= n - 1 then seg := n - 2;
      s0 := AGrad.GetStop(seg); s1 := AGrad.GetStop(seg + 1);
      c0 := LongWord(AGrad.GetColor(seg)); c1 := LongWord(AGrad.GetColor(seg + 1));
      if Abs(s1 - s0) < 1e-6 then lt := 0 else
      begin
        lt := (tt - s0) / (s1 - s0);
        if lt < 0 then lt := 0 else if lt > 1 then lt := 1;
      end;
      r0 := Byte((c0 shr 16) and $FF); g0 := Byte((c0 shr 8) and $FF); b0 := Byte(c0 and $FF); a0 := Byte((c0 shr 24) and $FF);
      r1 := Byte((c1 shr 16) and $FF); g1 := Byte((c1 shr 8) and $FF); b1 := Byte(c1 and $FF); a1 := Byte((c1 shr 24) and $FF);
      rr := Byte(Round(r0 + lt * (r1 - r0))); gg := Byte(Round(g0 + lt * (g1 - g0)));
      bb := Byte(Round(b0 + lt * (b1 - b0))); aa := Byte(Round(a0 + lt * (a1 - a0)));
      Lut[c] := LongWord(rr) shl 16 or LongWord(gg) shl 8 or LongWord(bb) or LongWord(aa) shl 24;
    end;
  end;
  UseInv := AGrad.Transform.IsInvertible;
  if UseInv then
  begin
    Inv := AGrad.Transform.Inverse; InvA := Inv.A; InvB := Inv.B; InvC := Inv.C; InvD := Inv.D; InvTx := Inv.Tx; InvTy := Inv.Ty;
  end
  else
  begin InvA := 1; InvB := 0; InvC := 0; InvD := 1; InvTx := 0; InvTy := 0; end;
  CX := ABounds.X + ABounds.W * 0.5; CY := ABounds.Y + ABounds.H * 0.5;
  if ABounds.W > ABounds.H then Rad := ABounds.W * 0.5 else Rad := ABounds.H * 0.5;
  if Rad < EPSILON then Rad := 1;
  if ABounds.W < EPSILON then invW := 0 else invW := 1 / ABounds.W;
  ABitmap.EnsureUnique;
  for I := 0 to High(ATraps) do
  begin
    Tr := ATraps[I];
    if IsNaN(Tr.Y0) or IsInfinite(Tr.Y0) or IsNaN(Tr.Y1) or IsInfinite(Tr.Y1) or
       IsNaN(Tr.XL0) or IsInfinite(Tr.XL0) or IsNaN(Tr.XL1) or IsInfinite(Tr.XL1) or
       IsNaN(Tr.XR0) or IsInfinite(Tr.XR0) or IsNaN(Tr.XR1) or IsInfinite(Tr.XR1) then Continue;
    DH := Tr.Y1 - Tr.Y0;
    if Abs(DH) < EPSILON then Continue;
    YStart := Trunc(Tr.Y0); YEnd := Trunc(Tr.Y1);
    if (YEnd <= 0) or (YStart >= H) then Continue;
    if YStart < 0 then YStart := 0; if YEnd > H then YEnd := H;
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
      if DH <= 1.01 then begin XL := Tr.XL0; XR := Tr.XR0; end
      else
      begin
        T := (Single(Y) + 0.5 - Tr.Y0) / DH;
        if T < 0 then T := 0 else if T > 1 then T := 1;
        XL := Tr.XL0 + T * (Tr.XL1 - Tr.XL0);
        XR := Tr.XR0 + T * (Tr.XR1 - Tr.XR0);
      end;
      X0 := Trunc(XL + 0.5); X1 := Trunc(XR + 0.5);
      if X0 < 0 then X0 := 0; if X1 > W then X1 := W;
      if AHasClip then
      begin
        if X1 <= Trunc(AClipR.X) then Continue;
        if X0 >= Trunc(AClipR.X + AClipR.W) then Continue;
        if X0 < Trunc(AClipR.X) then X0 := Trunc(AClipR.X);
        if X1 > Trunc(AClipR.X + AClipR.W) then X1 := Trunc(AClipR.X + AClipR.W);
      end;
      if X1 <= X0 then Continue;
      Row := ABitmap.UnsafeMutableRowPtr(Y);
      py := Single(Y) + 0.5;
      if UseInv then begin rowBaseX := InvC * py + InvTx; rowBaseY := InvD * py + InvTy; end
      else begin rowBaseX := 0; rowBaseY := 0; end;
      if not ARadial then
      begin
        if UseInv then begin t0 := (InvA * (Single(X0) + 0.5) + rowBaseX - ABounds.X) * invW; stepT := InvA * invW; end
        else begin t0 := (Single(X0) + 0.5 - ABounds.X) * invW; stepT := invW; end;
        off := 0; rem := X1 - X0;
        while rem > 0 do
        begin
          cnt := rem; if cnt > CHUNK_SIZE then cnt := CHUNK_SIZE;
          allOpaque := True;
          for j := 0 to cnt - 1 do
          begin
            tt := t0 + Single(off + j) * stepT;
            if tt < 0 then tt := 0 else if tt > 1 then tt := 1;
            idx := Trunc(tt * 255); if idx < 0 then idx := 0 else if idx > 255 then idx := 255;
            Chunk[j] := Lut[idx];
            if Byte((Chunk[j] shr 24) and $FF) <> 255 then allOpaque := False;
          end;
          P := Row + (X0 + off) * 4;
          if allOpaque then RasterCopySpan(P, @Chunk[0], cnt) else RasterBlendVaried(P, @Chunk[0], cnt);
          off := off + cnt; rem := rem - cnt;
        end;
      end
      else
      begin
        if UseInv then begin Dx0 := InvA * (Single(X0) + 0.5) + rowBaseX - CX; Dy0 := InvB * (Single(X0) + 0.5) + rowBaseY - CY; stepDx := InvA; stepDy := InvB; end
        else begin Dx0 := Single(X0) + 0.5 - CX; Dy0 := py - CY; stepDx := 1; stepDy := 0; end;
        off := 0; rem := X1 - X0;
        while rem > 0 do
        begin
          cnt := rem; if cnt > CHUNK_SIZE then cnt := CHUNK_SIZE;
          allOpaque := True;
          for j := 0 to cnt - 1 do
          begin
            Dx := Dx0 + Single(off + j) * stepDx; Dy := Dy0 + Single(off + j) * stepDy;
            Dist := Sqrt(Dx * Dx + Dy * Dy); tt := Dist / Rad;
            if tt < 0 then tt := 0 else if tt > 1 then tt := 1;
            idx := Trunc(tt * 255); if idx < 0 then idx := 0 else if idx > 255 then idx := 255;
            Chunk[j] := Lut[idx];
            if Byte((Chunk[j] shr 24) and $FF) <> 255 then allOpaque := False;
          end;
          P := Row + (X0 + off) * 4;
          if allOpaque then RasterCopySpan(P, @Chunk[0], cnt) else RasterBlendVaried(P, @Chunk[0], cnt);
          off := off + cnt; rem := rem - cnt;
        end;
      end;
    end;
  end;
end;

end.
