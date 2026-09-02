{ nextpas.core.canvas.raster - CPU raster }
unit nextpas.core.canvas.raster;
{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}
interface
uses
  nextpas.core.canvas.base,
  nextpas.core.graphics.base,
  nextpas.core.graphics.path,
  nextpas.core.image.base,
  nextpas.core.vector.tess,
  nextpas.core.vector.path,
  nextpas.core.canvas.intf;

type
  TCanvasState = record Mat: TMat2D; Clip: TPath; HasClip: Boolean; ClipR: TRect; end;
  TRasterCanvas = class(TInterfacedObject, ICanvas)
  private
    FBitmap: TBitmap;
    FStack: array of TCanvasState;
    FClip: TPath;
    FHasClip: Boolean;
    FClipR: TRect;
    FMat: TMat2D;
    procedure FillTrapezoids(const ATraps: array of TTrapezoid; AColor: TColor32);
    procedure FillTrapezoidsGradient(const ATraps: array of TTrapezoid; const AGrad: TGradient; const ABounds: TRect; ARadial: Boolean);
    function TransformPoly(const APoly: array of TVec2): TPoly;
  public
    constructor Create(AWidth, AHeight: Integer);
    procedure Save; procedure Restore;
    procedure Concat(const AMat: TMat2D);
    procedure ClipPath(const APath: TPath);
    procedure ClipRect(const AR: TRect);
    procedure FillPath(const APath: TPath; const ABrush: TBrush);
    procedure StrokePath(const APath: TPath; const ABrush: TBrush; const AOpts: TStrokeOptions);
    procedure DrawBitmap(const ABitmap: TBitmap; const ASrc, ADst: TRect; AQuality: TFilterQuality);
    procedure DrawGlyphRun(const ARun: TGlyphRun; const APos: TVec2);
    function Snapshot: TBitmap;
  end;
function CreateRasterCanvas(AWidth, AHeight: Integer): ICanvas;
implementation

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.graphics.errors,
  nextpas.core.math,
  nextpas.core.text.layout,
  nextpas.core.simd.memutils,
  nextpas.core.simd.raster;

const
  TILE = 16;
  MAX_SAVE_STACK = 64;

function CreateRasterCanvas(AWidth, AHeight: Integer): ICanvas;
begin
  Result := TRasterCanvas.Create(AWidth, AHeight);
end;

constructor TRasterCanvas.Create(AWidth, AHeight: Integer);
begin
  if (AWidth <= 0) or (AHeight <= 0) then
    raise ECanvasError.Create('nextpas.core.canvas.raster.pas: TRasterCanvas.Create: width/height must be > 0 (width='+IntToStr(AWidth)+' height='+IntToStr(AHeight)+')');
  if (AWidth > 16384) or (AHeight > 16384) then
    raise ECanvasError.Create('nextpas.core.canvas.raster.pas: TRasterCanvas.Create: width/height exceeds 16384 cap (width='+IntToStr(AWidth)+' height='+IntToStr(AHeight)+')');
  inherited Create;
  try FBitmap := TBitmap.Create(AWidth, AHeight, bfRGBA);
  except on E: EArgumentError do raise ECanvasError.Create('nextpas.core.canvas.raster.pas: TRasterCanvas.Create: '+E.Message); end;
  FMat := TMat2D.Identity;
  FHasClip := False;
end;

procedure TRasterCanvas.Save;
begin
  if Length(FStack) >= MAX_SAVE_STACK then
    raise ECanvasError.Create('nextpas.core.canvas.raster.pas: TRasterCanvas.Save: stack overflow (depth=' + IntToStr(Length(FStack)) + ' limit=' + IntToStr(MAX_SAVE_STACK) + ')');
  SetLength(FStack, Length(FStack)+1);
  FStack[High(FStack)].Mat := FMat;
  FStack[High(FStack)].Clip := FClip;
  FStack[High(FStack)].HasClip := FHasClip;
  FStack[High(FStack)].ClipR := FClipR;
end;
procedure TRasterCanvas.Restore;
begin
  if Length(FStack)=0 then raise ECanvasError.Create('nextpas.core.canvas.raster.pas: TRasterCanvas.Restore: stack underflow (depth=0)');
  FMat := FStack[High(FStack)].Mat;
  FClip := FStack[High(FStack)].Clip;
  FHasClip := FStack[High(FStack)].HasClip;
  FClipR := FStack[High(FStack)].ClipR;
  SetLength(FStack, Length(FStack)-1);
end;
procedure TRasterCanvas.Concat(const AMat: TMat2D);
begin
  FMat := FMat.Concat(AMat);
end;
procedure TRasterCanvas.ClipPath(const APath: TPath);
var Poly: TPoly; R: TRect; Ix,Iy,Ix2,Iy2: Single;
begin
  if APath.IsEmpty then Exit;
  Poly:=PathFlatten(APath,0.25); Poly:=TransformPoly(Poly);
  if Length(Poly)=0 then Exit;
  R:=PolyBounds(Poly);
  if R.IsEmpty then begin FClipR:=R; FClip:=APath; FHasClip:=True; Exit; end;
  if not FHasClip then begin FClip:=APath; FClipR:=R; FHasClip:=True; Exit; end;
  Ix:=FClipR.X; if R.X>Ix then Ix:=R.X; Iy:=FClipR.Y; if R.Y>Iy then Iy:=R.Y;
  Ix2:=FClipR.X+FClipR.W; if R.X+R.W<Ix2 then Ix2:=R.X+R.W;
  Iy2:=FClipR.Y+FClipR.H; if R.Y+R.H<Iy2 then Iy2:=R.Y+R.H;
  if (Ix2<=Ix) or (Iy2<=Iy) then begin FClipR:=TRect.From(0,0,0,0); FClip:=TPath.New; FHasClip:=True; Exit; end;
  FClipR:=TRect.From(Ix,Iy,Ix2-Ix,Iy2-Iy); FClip:=PathIntersect(FClip,APath);
end;
procedure TRasterCanvas.ClipRect(const AR: TRect);
var Poly: TPoly; R: TRect; P: TPath; Ix,Iy,Ix2,Iy2: Single;
begin
  if AR.IsEmpty then begin FClipR:=TRect.From(0,0,0,0); FClip:=TPath.New; FHasClip:=True; Exit; end;
  P:=TPath.New.MoveTo(AR.X,AR.Y).LineTo(AR.X+AR.W,AR.Y).LineTo(AR.X+AR.W,AR.Y+AR.H).LineTo(AR.X,AR.Y+AR.H).Close;
  Poly:=PathFlatten(P,0.25); Poly:=TransformPoly(Poly);
  if Length(Poly)=0 then Exit;
  R:=PolyBounds(Poly);
  if not FHasClip then begin FClip:=P; FClipR:=R; FHasClip:=True; Exit; end;
  Ix:=FClipR.X; if R.X>Ix then Ix:=R.X; Iy:=FClipR.Y; if R.Y>Iy then Iy:=R.Y;
  Ix2:=FClipR.X+FClipR.W; if R.X+R.W<Ix2 then Ix2:=R.X+R.W;
  Iy2:=FClipR.Y+FClipR.H; if R.Y+R.H<Iy2 then Iy2:=R.Y+R.H;
  if (Ix2<=Ix) or (Iy2<=Iy) then begin FClipR:=TRect.From(0,0,0,0); FClip:=TPath.New; FHasClip:=True; Exit; end;
  FClipR:=TRect.From(Ix,Iy,Ix2-Ix,Iy2-Iy); FClip:=PathIntersect(FClip,P);
end;
function TRasterCanvas.TransformPoly(const APoly: array of TVec2): TPoly; var I: Integer; begin SetLength(Result,Length(APoly)); for I:=0 to High(APoly) do Result[I]:=FMat.TransformPoint(APoly[I]); end;

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
  if t >= 1 then Exit(AGrad.GetColor(n-1));
  if AGrad.StopCount = 0 then
  begin
    i := Trunc(t * (n - 1));
    if i < 0 then i := 0 else if i >= n-1 then i := n-2;
    s0 := i / (n - 1);
    s1 := (i+1) / (n - 1);
    c0 := AGrad.GetColor(i);
    c1 := AGrad.GetColor(i+1);
  end
  else
  begin
    lo := 0;
    hi := n - 1;
    while hi - lo > 1 do
    begin
      mid := (lo + hi) shr 1;
      if t < AGrad.GetStop(mid) then hi := mid else lo := mid;
    end;
    i := lo;
    if i < 0 then i := 0 else if i >= n-1 then i := n-2;
    s0 := AGrad.GetStop(i);
    s1 := AGrad.GetStop(i+1);
    c0 := AGrad.GetColor(i);
    c1 := AGrad.GetColor(i+1);
  end;
  if Abs(s1 - s0) < 1e-6 then Exit(c0);
  lt := (t - s0) / (s1 - s0);
  if lt < 0 then lt := 0 else if lt > 1 then lt := 1;
  r0 := Byte((LongWord(c0) shr 16) and $FF);
  g0 := Byte((LongWord(c0) shr 8) and $FF);
  b0 := Byte(LongWord(c0) and $FF);
  a0 := Byte((LongWord(c0) shr 24) and $FF);
  r1 := Byte((LongWord(c1) shr 16) and $FF);
  g1 := Byte((LongWord(c1) shr 8) and $FF);
  b1 := Byte(LongWord(c1) and $FF);
  a1 := Byte((LongWord(c1) shr 24) and $FF);
  rr := Byte(Round(r0 + lt * (r1 - r0)));
  gg := Byte(Round(g0 + lt * (g1 - g0)));
  bb := Byte(Round(b0 + lt * (b1 - b0)));
  aa := Byte(Round(a0 + lt * (a1 - a0)));
  Result := Color32(rr, gg, bb, aa);
end;

procedure TRasterCanvas.FillTrapezoids(const ATraps: array of TTrapezoid; AColor: TColor32);
var
  I, X0, X1, Y, YStart, YEnd, W, H: Integer;
  R,G,B,A: Byte;
  P: PByte;
  Tr: TTrapezoid;
  DH, T: Single;
  XL, XR: Single;
begin
  if FBitmap.IsEmpty then Exit;
  W := FBitmap.Width; H := FBitmap.Height;
  R := Byte((LongWord(AColor) shr 16) and $FF);
  G := Byte((LongWord(AColor) shr 8) and $FF);
  B := Byte(LongWord(AColor) and $FF);
  A := Byte((LongWord(AColor) shr 24) and $FF);
  if A = 0 then Exit;
  FBitmap.EnsureUnique;
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
    if FHasClip then begin
      if FClipR.IsEmpty then Continue;
      if YEnd <= Trunc(FClipR.Y) then Continue;
      if YStart >= Trunc(FClipR.Y+FClipR.H) then Continue;
      if YStart < Trunc(FClipR.Y) then YStart:=Trunc(FClipR.Y);
      if YEnd > Trunc(FClipR.Y+FClipR.H) then YEnd:=Trunc(FClipR.Y+FClipR.H);
    end;
    if YEnd <= YStart then Continue;
    for Y := YStart to YEnd - 1 do
    begin
      if DH <= 1.01 then begin XL:=Tr.XL0; XR:=Tr.XR0; end
      else begin T:=(Single(Y)+0.5-Tr.Y0)/DH; if T<0 then T:=0 else if T>1 then T:=1; XL:=Tr.XL0+T*(Tr.XL1-Tr.XL0); XR:=Tr.XR0+T*(Tr.XR1-Tr.XR0); end;
      X0:=Trunc(XL+0.5); X1:=Trunc(XR+0.5);
      if X0<0 then X0:=0; if X1>W then X1:=W;
      if FHasClip then begin
        if X1<=Trunc(FClipR.X) then Continue; if X0>=Trunc(FClipR.X+FClipR.W) then Continue;
        if X0<Trunc(FClipR.X) then X0:=Trunc(FClipR.X); if X1>Trunc(FClipR.X+FClipR.W) then X1:=Trunc(FClipR.X+FClipR.W);
      end;
      if X1 <= X0 then Continue;
      P := FBitmap.UnsafeMutableRowPtr(Y) + X0 * 4;
      if A = 255 then
        RasterFillSolid(P, X1 - X0, R, G, B, A)
      else
        RasterBlendSrcOver(P, X1 - X0, R, G, B, A);
    end;
  end;
end;

procedure TRasterCanvas.FillTrapezoidsGradient(const ATraps: array of TTrapezoid; const AGrad: TGradient; const ABounds: TRect; ARadial: Boolean);
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
  if FBitmap.IsEmpty then Exit;
  W := FBitmap.Width; H := FBitmap.Height;
  if ABounds.IsEmpty then Exit;
  n := AGrad.ColorCount;
  if n = 0 then Exit;
  hasStops := AGrad.StopCount > 0;
  if n = 1 then
    for c := 0 to LUT_N - 1 do Lut[c] := LongWord(AGrad.GetColor(0))
  else if not hasStops then
  begin
    seg := 0;
    for c := 0 to LUT_N - 1 do
    begin
      tt := c / (LUT_N - 1) * (n - 1);
      seg := Trunc(tt);
      if seg < 0 then seg := 0 else if seg >= n-1 then seg := n-2;
      lt := tt - seg;
      c0 := LongWord(AGrad.GetColor(seg)); c1 := LongWord(AGrad.GetColor(seg+1));
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
      while (seg < n-2) and (tt > AGrad.GetStop(seg+1)) do Inc(seg);
      if seg < 0 then seg := 0 else if seg >= n-1 then seg := n-2;
      s0 := AGrad.GetStop(seg); s1 := AGrad.GetStop(seg+1);
      c0 := LongWord(AGrad.GetColor(seg)); c1 := LongWord(AGrad.GetColor(seg+1));
      if Abs(s1 - s0) < 1e-6 then lt := 0 else begin lt := (tt - s0)/(s1 - s0); if lt<0 then lt:=0 else if lt>1 then lt:=1; end;
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
    Inv := AGrad.Transform.Inverse;
    InvA := Inv.A; InvB := Inv.B; InvC := Inv.C; InvD := Inv.D; InvTx := Inv.Tx; InvTy := Inv.Ty;
  end
  else
  begin InvA := 1; InvB := 0; InvC := 0; InvD := 1; InvTx := 0; InvTy := 0; end;
  CX := ABounds.X + ABounds.W * 0.5;
  CY := ABounds.Y + ABounds.H * 0.5;
  if ABounds.W > ABounds.H then Rad := ABounds.W * 0.5 else Rad := ABounds.H * 0.5;
  if Rad < EPSILON then Rad := 1;
  if ABounds.W < EPSILON then invW := 0 else invW := 1 / ABounds.W;
  FBitmap.EnsureUnique;
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
    if FHasClip then begin if FClipR.IsEmpty then Continue; if YEnd<=Trunc(FClipR.Y) then Continue; if YStart>=Trunc(FClipR.Y+FClipR.H) then Continue; if YStart<Trunc(FClipR.Y) then YStart:=Trunc(FClipR.Y); if YEnd>Trunc(FClipR.Y+FClipR.H) then YEnd:=Trunc(FClipR.Y+FClipR.H); end;
    if YEnd <= YStart then Continue;
    for Y := YStart to YEnd - 1 do
    begin
      if DH <= 1.01 then begin XL:=Tr.XL0; XR:=Tr.XR0; end
      else begin T:=(Single(Y)+0.5-Tr.Y0)/DH; if T<0 then T:=0 else if T>1 then T:=1; XL:=Tr.XL0+T*(Tr.XL1-Tr.XL0); XR:=Tr.XR0+T*(Tr.XR1-Tr.XR0); end;
      X0:=Trunc(XL+0.5); X1:=Trunc(XR+0.5);
      if X0<0 then X0:=0; if X1>W then X1:=W;
      if FHasClip then begin if X1<=Trunc(FClipR.X) then Continue; if X0>=Trunc(FClipR.X+FClipR.W) then Continue; if X0<Trunc(FClipR.X) then X0:=Trunc(FClipR.X); if X1>Trunc(FClipR.X+FClipR.W) then X1:=Trunc(FClipR.X+FClipR.W); end;
      if X1 <= X0 then Continue;
      Row := FBitmap.UnsafeMutableRowPtr(Y);
      py := Single(Y) + 0.5;
      if UseInv then
      begin rowBaseX := InvC * py + InvTx; rowBaseY := InvD * py + InvTy; end
      else
      begin rowBaseX := 0; rowBaseY := 0; end;
      if not ARadial then
      begin
        if UseInv then
        begin t0 := (InvA * (Single(X0) + 0.5) + rowBaseX - ABounds.X) * invW; stepT := InvA * invW; end
        else
        begin t0 := (Single(X0) + 0.5 - ABounds.X) * invW; stepT := invW; end;
        off := 0; rem := X1 - X0;
        while rem > 0 do
        begin
          cnt := rem; if cnt > CHUNK_SIZE then cnt := CHUNK_SIZE;
          allOpaque := True;
          for j := 0 to cnt - 1 do
          begin
            tt := t0 + Single(off + j) * stepT;
            if tt < 0 then tt := 0 else if tt > 1 then tt := 1;
            idx := Trunc(tt * 255);
            if idx < 0 then idx := 0 else if idx > 255 then idx := 255;
            Chunk[j] := Lut[idx];
            if Byte((Chunk[j] shr 24) and $FF) <> 255 then allOpaque := False;
          end;
          P := Row + (X0 + off) * 4;
          if allOpaque then
            RasterCopySpan(P, @Chunk[0], cnt)
          else
            RasterBlendVaried(P, @Chunk[0], cnt);
          off := off + cnt; rem := rem - cnt;
        end;
      end
      else
      begin
        if UseInv then
        begin Dx0 := InvA * (Single(X0) + 0.5) + rowBaseX - CX; Dy0 := InvB * (Single(X0) + 0.5) + rowBaseY - CY; stepDx := InvA; stepDy := InvB; end
        else
        begin Dx0 := Single(X0) + 0.5 - CX; Dy0 := py - CY; stepDx := 1; stepDy := 0; end;
        off := 0; rem := X1 - X0;
        while rem > 0 do
        begin
          cnt := rem; if cnt > CHUNK_SIZE then cnt := CHUNK_SIZE;
          allOpaque := True;
          for j := 0 to cnt - 1 do
          begin
            Dx := Dx0 + Single(off + j) * stepDx;
            Dy := Dy0 + Single(off + j) * stepDy;
            Dist := Sqrt(Dx*Dx + Dy*Dy);
            tt := Dist / Rad;
            if tt < 0 then tt := 0 else if tt > 1 then tt := 1;
            idx := Trunc(tt * 255);
            if idx < 0 then idx := 0 else if idx > 255 then idx := 255;
            Chunk[j] := Lut[idx];
            if Byte((Chunk[j] shr 24) and $FF) <> 255 then allOpaque := False;
          end;
          P := Row + (X0 + off) * 4;
          if allOpaque then
            RasterCopySpan(P, @Chunk[0], cnt)
          else
            RasterBlendVaried(P, @Chunk[0], cnt);
          off := off + cnt; rem := rem - cnt;
        end;
      end;
    end;
  end;
end;

procedure TRasterCanvas.FillPath(const APath: TPath; const ABrush: TBrush);
var
  Poly: TPoly;
  Traps: TTrapezoids;
  Bounds: TRect;
begin
  if APath.IsEmpty then Exit;
  Poly := PathFlatten(APath, 0.25);
  Poly := TransformPoly(Poly);
  if Length(Poly) = 0 then Exit;
  Bounds := PolyBounds(Poly);
  Traps := TessellatePoly(Poly);
  case ABrush.Kind of
    bkSolid: FillTrapezoids(Traps, ABrush.Color);
    bkLinearGradient:
      begin
        if ABrush.Gradient.ColorCount = 0 then
          raise ECanvasError.Create('nextpas.core.canvas.raster.pas: TRasterCanvas.FillPath: gradient brush has no colors');
        FillTrapezoidsGradient(Traps, ABrush.Gradient, Bounds, False);
      end;
    bkRadialGradient:
      begin
        if ABrush.Gradient.ColorCount = 0 then
          raise ECanvasError.Create('nextpas.core.canvas.raster.pas: TRasterCanvas.FillPath: gradient brush has no colors');
        FillTrapezoidsGradient(Traps, ABrush.Gradient, Bounds, True);
      end;
  end;
end;

procedure TRasterCanvas.StrokePath(const APath: TPath; const ABrush: TBrush; const AOpts: TStrokeOptions);
var
  Stroked: TPath;
begin
  Stroked := PathStroke(APath, AOpts);
  FillPath(Stroked, ABrush);
end;

procedure TRasterCanvas.DrawBitmap(const ABitmap: TBitmap; const ASrc, ADst: TRect; AQuality: TFilterQuality);
var SW, SH, DW, DH, DX, DY, Y, X, SY, SX, DstY, ClipX0, ClipX1, IX0, IY0, IX1, IY1, c4, wyI, wxI, w00i, w10i, w01i, w11i, DstStride, SrcStride, wxInc, wyInc, fxFixedStart, fyFixedStart, fxFixed, fyFixed, ky, kx, sxK, syK: Integer;
  SX0f, SY0f, ScaleX, ScaleY, FX, FY, fxF, fyF, rAcc, gAcc, bAcc, aAcc: Single;
  SrcRow, DstRow, SrcRow0, SrcRow1: PByte; DstBase, SrcBase: PByte; C00, C10, C01, C11: LongWord; R, G, B, A: Byte; wxW, wyW: array[0..3] of Single; sc: LongWord;
  CubicRows: array[0..3] of PByte;
  function CubicW(AT: Single): Single; inline;
  var Av: Single;
  begin Av:=Abs(AT); if Av<1 then Result:=1.5*Av*Av*Av-2.5*Av*Av+1 else if Av<2 then Result:=-0.5*Av*Av*Av+2.5*Av*Av-4*Av+2 else Result:=0; end;
begin
  if ABitmap.IsEmpty or ADst.IsEmpty or ASrc.IsEmpty then Exit;
  if FBitmap.IsEmpty or ABitmap.IsEmpty then Exit;
  if IsNaN(ASrc.X) or IsInfinite(ASrc.X) or IsNaN(ASrc.Y) or IsInfinite(ASrc.Y) or
     IsNaN(ASrc.W) or IsInfinite(ASrc.W) or IsNaN(ASrc.H) or IsInfinite(ASrc.H) or
     IsNaN(ADst.X) or IsInfinite(ADst.X) or IsNaN(ADst.Y) or IsInfinite(ADst.Y) or
     IsNaN(ADst.W) or IsInfinite(ADst.W) or IsNaN(ADst.H) or IsInfinite(ADst.H) then
    raise EArgumentError.Create('nextpas.core.canvas.raster.pas: DrawBitmap: src/dst rect contains NaN/Inf');
  if (Abs(ASrc.W) > High(Integer)) or (Abs(ASrc.H) > High(Integer)) or
     (Abs(ADst.W) > High(Integer)) or (Abs(ADst.H) > High(Integer)) or
     (Abs(ASrc.X) > High(Integer)) or (Abs(ASrc.Y) > High(Integer)) or
     (Abs(ADst.X) > High(Integer)) or (Abs(ADst.Y) > High(Integer)) then
    raise EArgumentError.Create('nextpas.core.canvas.raster.pas: DrawBitmap: rect value overflow');
  if (Abs(ADst.W) < EPSILON) or (Abs(ADst.H) < EPSILON) then
    raise EArgumentError.Create('nextpas.core.canvas.raster.pas: DrawBitmap: dst W/H too small (<EPSILON)');
  SW := Trunc(ASrc.W); SH := Trunc(ASrc.H);
  DW := Trunc(ADst.W); DH := Trunc(ADst.H);
  if (SW <= 0) or (SH <= 0) or (DW <= 0) or (DH <= 0) then Exit;
  DX := Trunc(ADst.X); DY := Trunc(ADst.Y);
  SX0f := ASrc.X; SY0f := ASrc.Y;
  ScaleX := ASrc.W / ADst.W;
  ScaleY := ASrc.H / ADst.H;
  if IsNaN(ScaleX) or IsInfinite(ScaleX) or IsNaN(ScaleY) or IsInfinite(ScaleY) then
    raise EArgumentError.Create('nextpas.core.canvas.raster.pas: DrawBitmap: scale is NaN/Inf');
  if (Abs(ScaleX) > 16384) or (Abs(ScaleY) > 16384) then
    raise EArgumentError.Create('nextpas.core.canvas.raster.pas: DrawBitmap: scale exceeds 16384 cap');
  if FHasClip and FClipR.IsEmpty then Exit;
  FBitmap.EnsureUnique;
  DstStride := FBitmap.Stride;
  SrcStride := ABitmap.Stride;
  if (not FBitmap.IsEmpty) and (FBitmap.Height > 0) then
    DstBase := FBitmap.UnsafeMutableRowPtr(0)
  else
    DstBase := nil;
  if not ABitmap.IsEmpty then
    SrcBase := ABitmap.ConstRowPtr(0)
  else
    SrcBase := nil;
  if (SW = DW) and (SH = DH) and (AQuality = fqNearest) then
  begin
    if (Trunc(SX0f) = SX0f) and (Trunc(SY0f) = SY0f) then
    begin
      for Y := 0 to DH - 1 do
      begin
        DstY := DY + Y;
        if (DstY < 0) or (DstY >= FBitmap.Height) then Continue;
        if FHasClip then begin if DstY<Trunc(FClipR.Y) then Continue; if DstY>=Trunc(FClipR.Y+FClipR.H) then Continue; end;
        SY := Trunc(SY0f) + Y;
        if (SY < 0) or (SY >= ABitmap.Height) then Continue;
        ClipX0 := 0;
        ClipX1 := DW;
        if DX < 0 then ClipX0 := -DX;
        if DX + ClipX1 > FBitmap.Width then ClipX1 := FBitmap.Width - DX;
        if ClipX1 <= ClipX0 then Continue;
        if Trunc(SX0f) + ClipX0 < 0 then ClipX0 := -Trunc(SX0f);
        if Trunc(SX0f) + ClipX1 > ABitmap.Width then ClipX1 := ABitmap.Width - Trunc(SX0f);
        if FHasClip then begin if DX+ClipX1<=Trunc(FClipR.X) then Continue; if DX+ClipX0>=Trunc(FClipR.X+FClipR.W) then Continue; if DX+ClipX0<Trunc(FClipR.X) then ClipX0:=Trunc(FClipR.X)-DX; if DX+ClipX1>Trunc(FClipR.X+FClipR.W) then ClipX1:=Trunc(FClipR.X+FClipR.W)-DX; end;
        if ClipX1 <= ClipX0 then Continue;
        SrcRow := SrcBase + SY * SrcStride + Trunc(SX0f) * 4 + ClipX0 * 4;
        DstRow := DstBase + DstY * DstStride + DX * 4 + ClipX0 * 4;
        SimdMemCopy(SrcRow, DstRow, NativeUInt((ClipX1 - ClipX0) * 4));
      end;
      Exit;
    end;
  end;
  case AQuality of
    fqNearest:
      begin
        for Y := 0 to DH - 1 do
        begin
          DstY := DY + Y;
          if (DstY < 0) or (DstY >= FBitmap.Height) then Continue;
          if FHasClip then begin if DstY<Trunc(FClipR.Y) then Continue; if DstY>=Trunc(FClipR.Y+FClipR.H) then Continue; end;
          FY := SY0f + Y * ScaleY;
          SY := Trunc(FY);
          if SY < 0 then SY := 0 else if SY >= ABitmap.Height then SY := ABitmap.Height - 1;
          SrcRow := SrcBase + SY * SrcStride;
          DstRow := DstBase + DstY * DstStride;
          ClipX0 := 0;
          ClipX1 := DW;
          if DX < 0 then ClipX0 := -DX;
          if DX + ClipX1 > FBitmap.Width then ClipX1 := FBitmap.Width - DX;
          if FHasClip then begin if DX+ClipX1<=Trunc(FClipR.X) then Continue; if DX+ClipX0>=Trunc(FClipR.X+FClipR.W) then Continue; if DX+ClipX0<Trunc(FClipR.X) then ClipX0:=Trunc(FClipR.X)-DX; if DX+ClipX1>Trunc(FClipR.X+FClipR.W) then ClipX1:=Trunc(FClipR.X+FClipR.W)-DX; end;
          if ClipX1 <= ClipX0 then Continue;
          for X := ClipX0 to ClipX1 - 1 do
          begin
            FX := SX0f + X * ScaleX;
            SX := Trunc(FX);
            if (SX < 0) or (SX >= ABitmap.Width) then Continue;
            PLongWord(DstRow)[DX + X] := PLongWord(SrcRow)[SX];
          end;
        end;
      end;
    fqLinear:
      begin
        wxInc := Round(ScaleX * 256);
        wyInc := Round(ScaleY * 256);
        ClipX0 := 0; ClipX1 := DW;
        if DX < 0 then ClipX0 := -DX;
        if DX + ClipX1 > FBitmap.Width then ClipX1 := FBitmap.Width - DX;
        if Trunc(SX0f) + ClipX0 < 0 then ClipX0 := -Trunc(SX0f);
        if Trunc(SX0f) + ClipX1 > ABitmap.Width then ClipX1 := ABitmap.Width - Trunc(SX0f);
        if FHasClip then begin if DX+ClipX1<=Trunc(FClipR.X) then Exit; if DX+ClipX0>=Trunc(FClipR.X+FClipR.W) then Exit; if DX+ClipX0<Trunc(FClipR.X) then ClipX0:=Trunc(FClipR.X)-DX; if DX+ClipX1>Trunc(FClipR.X+FClipR.W) then ClipX1:=Trunc(FClipR.X+FClipR.W)-DX; end;
        if ClipX1 <= ClipX0 then Exit;
        fxFixedStart := Round((SX0f + (ClipX0 + 0.5)*ScaleX - 0.5)*256);
        fyFixedStart := Round((SY0f + 0.5*ScaleY - 0.5)*256);
        fyFixed := fyFixedStart;
        for Y := 0 to DH - 1 do
        begin
          DstY := DY + Y;
          if (DstY < 0) or (DstY >= FBitmap.Height) then begin Inc(fyFixed, wyInc); Continue; end;
          if FHasClip then begin if DstY<Trunc(FClipR.Y) then begin Inc(fyFixed, wyInc); Continue; end; if DstY>=Trunc(FClipR.Y+FClipR.H) then begin Inc(fyFixed, wyInc); Continue; end; end;
          if fyFixed >= 0 then begin IY0 := fyFixed div 256; wyI := fyFixed and 255; end
          else begin IY0 := (fyFixed - 255) div 256; wyI := fyFixed - IY0*256; end;
          if ABitmap.Height = 1 then begin IY0 := 0; wyI := 0; end
          else begin
            if IY0 < 0 then begin IY0 := 0; wyI := 0; end;
            if IY0 >= ABitmap.Height - 1 then begin IY0 := ABitmap.Height - 2; wyI := 256; end;
          end;
          IY1 := IY0 + 1; if IY1 >= ABitmap.Height then IY1 := IY0;
          SrcRow0 := SrcBase + IY0 * SrcStride;
          SrcRow1 := SrcBase + IY1 * SrcStride;
          DstRow := DstBase + DstY * DstStride;
          if wyI < 0 then wyI := 0 else if wyI > 256 then wyI := 256;
          fxFixed := fxFixedStart;
          X := ClipX0;
          while X + 3 < ClipX1 do
          begin
            for c4 := 0 to 3 do
            begin
              if fxFixed >= 0 then begin IX0 := fxFixed div 256; wxI := fxFixed and 255; end
              else begin IX0 := (fxFixed - 255) div 256; wxI := fxFixed - IX0*256; end;
              if ABitmap.Width = 1 then begin IX0 := 0; wxI := 0; end
              else begin
                if IX0 < 0 then begin IX0 := 0; wxI := 0; end;
                if IX0 >= ABitmap.Width - 1 then begin IX0 := ABitmap.Width - 2; wxI := 256; end;
              end;
              IX1 := IX0 + 1; if IX1 >= ABitmap.Width then IX1 := IX0;
              if wxI < 0 then wxI := 0 else if wxI > 256 then wxI := 256;
              w00i := (256 - wxI) * (256 - wyI);
              w10i := wxI * (256 - wyI);
              w01i := (256 - wxI) * wyI;
              w11i := wxI * wyI;
              C00 := PLongWord(SrcRow0)[IX0];
              C10 := PLongWord(SrcRow0)[IX1];
              C01 := PLongWord(SrcRow1)[IX0];
              C11 := PLongWord(SrcRow1)[IX1];
              R := Byte((Byte(C00) * w00i + Byte(C10) * w10i + Byte(C01) * w01i + Byte(C11) * w11i + 32768) shr 16);
              G := Byte((Byte(C00 shr 8) * w00i + Byte(C10 shr 8) * w10i + Byte(C01 shr 8) * w01i + Byte(C11 shr 8) * w11i + 32768) shr 16);
              B := Byte((Byte(C00 shr 16) * w00i + Byte(C10 shr 16) * w10i + Byte(C01 shr 16) * w01i + Byte(C11 shr 16) * w11i + 32768) shr 16);
              A := Byte((Byte(C00 shr 24) * w00i + Byte(C10 shr 24) * w10i + Byte(C01 shr 24) * w11i + 32768) shr 16);
              PLongWord(DstRow)[DX + X + c4] := LongWord(R) or (LongWord(G) shl 8) or (LongWord(B) shl 16) or (LongWord(A) shl 24);
              Inc(fxFixed, wxInc);
            end;
            X := X + 4;
          end;
          while X < ClipX1 do
          begin
            if fxFixed >= 0 then begin IX0 := fxFixed div 256; wxI := fxFixed and 255; end
            else begin IX0 := (fxFixed - 255) div 256; wxI := fxFixed - IX0*256; end;
            if ABitmap.Width = 1 then begin IX0 := 0; wxI := 0; end
            else begin
              if IX0 < 0 then begin IX0 := 0; wxI := 0; end;
              if IX0 >= ABitmap.Width - 1 then begin IX0 := ABitmap.Width - 2; wxI := 256; end;
            end;
            IX1 := IX0 + 1; if IX1 >= ABitmap.Width then IX1 := IX0;
            if wxI < 0 then wxI := 0 else if wxI > 256 then wxI := 256;
            w00i := (256 - wxI) * (256 - wyI);
            w10i := wxI * (256 - wyI);
            w01i := (256 - wxI) * wyI;
            w11i := wxI * wyI;
            C00 := PLongWord(SrcRow0)[IX0];
            C10 := PLongWord(SrcRow0)[IX1];
            C01 := PLongWord(SrcRow1)[IX0];
            C11 := PLongWord(SrcRow1)[IX1];
            R := Byte((Byte(C00) * w00i + Byte(C10) * w10i + Byte(C01) * w01i + Byte(C11) * w11i + 32768) shr 16);
            G := Byte((Byte(C00 shr 8) * w00i + Byte(C10 shr 8) * w10i + Byte(C01 shr 8) * w01i + Byte(C11 shr 8) * w11i + 32768) shr 16);
            B := Byte((Byte(C00 shr 16) * w00i + Byte(C10 shr 16) * w10i + Byte(C01 shr 16) * w01i + Byte(C11 shr 16) * w11i + 32768) shr 16);
            A := Byte((Byte(C00 shr 24) * w00i + Byte(C10 shr 24) * w10i + Byte(C01 shr 24) * w01i + Byte(C11 shr 24) * w11i + 32768) shr 16);
            PLongWord(DstRow)[DX + X] := LongWord(R) or (LongWord(G) shl 8) or (LongWord(B) shl 16) or (LongWord(A) shl 24);
            Inc(fxFixed, wxInc);
            Inc(X);
          end;
          Inc(fyFixed, wyInc);
        end;
      end;
    fqCubic:
      begin
        wxInc := Round(ScaleX * 256);
        wyInc := Round(ScaleY * 256);
        ClipX0 := 0; ClipX1 := DW;
        if DX < 0 then ClipX0 := -DX;
        if DX + ClipX1 > FBitmap.Width then ClipX1 := FBitmap.Width - DX;
        if Trunc(SX0f) + ClipX0 < 0 then ClipX0 := -Trunc(SX0f);
        if Trunc(SX0f) + ClipX1 > ABitmap.Width then ClipX1 := ABitmap.Width - Trunc(SX0f);
        if FHasClip then begin if DX+ClipX1<=Trunc(FClipR.X) then Exit; if DX+ClipX0>=Trunc(FClipR.X+FClipR.W) then Exit; if DX+ClipX0<Trunc(FClipR.X) then ClipX0:=Trunc(FClipR.X)-DX; if DX+ClipX1>Trunc(FClipR.X+FClipR.W) then ClipX1:=Trunc(FClipR.X+FClipR.W)-DX; end;
        if ClipX1 <= ClipX0 then Exit;
        fxFixedStart := Round((SX0f + (ClipX0 + 0.5)*ScaleX - 0.5)*256);
        fyFixedStart := Round((SY0f + 0.5*ScaleY - 0.5)*256);
        fyFixed := fyFixedStart;
        for Y := 0 to DH - 1 do
        begin
          DstY := DY + Y;
          if (DstY < 0) or (DstY >= FBitmap.Height) then begin Inc(fyFixed, wyInc); Continue; end;
          if FHasClip then begin if DstY<Trunc(FClipR.Y) then begin Inc(fyFixed, wyInc); Continue; end; if DstY>=Trunc(FClipR.Y+FClipR.H) then begin Inc(fyFixed, wyInc); Continue; end; end;
          if fyFixed >= 0 then begin IY0 := fyFixed div 256; wyI := fyFixed and 255; end
          else begin IY0 := (fyFixed - 255) div 256; wyI := fyFixed - IY0*256; end;
          DstRow := DstBase + DstY * DstStride;
          for ky := 0 to 3 do
          begin
            syK := IY0 + ky - 1;
            if syK < 0 then syK := 0 else if syK >= ABitmap.Height then syK := ABitmap.Height - 1;
            CubicRows[ky] := SrcBase + syK * SrcStride;
          end;
          fxFixed := fxFixedStart;
          for X := ClipX0 to ClipX1 - 1 do
          begin
            if fxFixed >= 0 then begin IX0 := fxFixed div 256; wxI := fxFixed and 255; end
            else begin IX0 := (fxFixed - 255) div 256; wxI := fxFixed - IX0*256; end;
            fxF := wxI / 256; fyF := wyI / 256;
              wxW[0] := CubicW(1 + fxF); wxW[1] := CubicW(fxF); wxW[2] := CubicW(1 - fxF); wxW[3] := CubicW(2 - fxF);
              wyW[0] := CubicW(1 + fyF); wyW[1] := CubicW(fyF); wyW[2] := CubicW(1 - fyF); wyW[3] := CubicW(2 - fyF);
              rAcc := 0; gAcc := 0; bAcc := 0; aAcc := 0;
              for ky := 0 to 3 do
              begin
                SrcRow := CubicRows[ky];
                for kx := 0 to 3 do
                begin
                  sxK := IX0 + kx - 1;
                  if sxK < 0 then sxK := 0 else if sxK >= ABitmap.Width then sxK := ABitmap.Width - 1;
                  sc := PLongWord(SrcRow)[sxK];
                  rAcc := rAcc + Byte(sc) * wxW[kx] * wyW[ky];
                  gAcc := gAcc + Byte(sc shr 8) * wxW[kx] * wyW[ky];
                  bAcc := bAcc + Byte(sc shr 16) * wxW[kx] * wyW[ky];
                  aAcc := aAcc + Byte(sc shr 24) * wxW[kx] * wyW[ky];
                end;
              end;
              if rAcc < 0 then rAcc := 0 else if rAcc > 255 then rAcc := 255;
              if gAcc < 0 then gAcc := 0 else if gAcc > 255 then gAcc := 255;
              if bAcc < 0 then bAcc := 0 else if bAcc > 255 then bAcc := 255;
              if aAcc < 0 then aAcc := 0 else if aAcc > 255 then aAcc := 255;
              R := Byte(Round(rAcc)); G := Byte(Round(gAcc)); B := Byte(Round(bAcc)); A := Byte(Round(aAcc));
              PLongWord(DstRow)[DX + X] := LongWord(R) or (LongWord(G) shl 8) or (LongWord(B) shl 16) or (LongWord(A) shl 24);
            Inc(fxFixed, wxInc);
          end;
          Inc(fyFixed, wyInc);
        end;
      end;
  end;
end;

procedure TRasterCanvas.DrawGlyphRun(const ARun: TGlyphRun; const APos: TVec2);
const GlyphAdvanceFallback=8.0; GlyphAdvanceMinCells=6.0; GlyphAdvanceMaxCells=20.0; AdvanceMinPx=2.0; GlyphWidthRatio=0.78; GlyphInsetRatio=0.11; GlyphHeightCells=10.0; GlyphBaselineRatio=0.78; GlyphCornerRadius=1.0;
var I: Integer; R: TRect; P: TPath; Brush: TBrush; W, H, Adv, CR, LX, LY: Single;
  function BuildRoundedRect(const AR: TRect; ARad: Single): TPath; inline;
  begin
    if ARad < 0.5 then ARad := 0.5;
    if ARad > AR.W * 0.5 then ARad := AR.W * 0.5;
    if ARad > AR.H * 0.5 then ARad := AR.H * 0.5;
    Result := TPath.New
      .MoveTo(AR.X+ARad, AR.Y)
      .LineTo(AR.X+AR.W-ARad, AR.Y)
      .QuadTo(AR.X+AR.W, AR.Y, AR.X+AR.W, AR.Y+ARad)
      .LineTo(AR.X+AR.W, AR.Y+AR.H-ARad)
      .QuadTo(AR.X+AR.W, AR.Y+AR.H, AR.X+AR.W-ARad, AR.Y+AR.H)
      .LineTo(AR.X+ARad, AR.Y+AR.H)
      .QuadTo(AR.X, AR.Y+AR.H, AR.X, AR.Y+AR.H-ARad)
      .LineTo(AR.X, AR.Y+ARad)
      .QuadTo(AR.X, AR.Y, AR.X+ARad, AR.Y)
      .Close;
  end;
  function ResolveAdvance(AIdx: Integer; AScale: Single): Single; inline;
  var LPrev: Single; LGlyph: LongWord; LAdvLay: Single;
  begin
    if (AIdx >= 0) and (AIdx < High(ARun.Positions)) then
    begin
      Result := ARun.Positions[AIdx+1].X - ARun.Positions[AIdx].X;
      if (Result >= AdvanceMinPx) and (Result <= GlyphAdvanceMaxCells * AScale) and (not IsNaN(Result)) and (not IsInfinite(Result)) then Exit;
    end
    else if AIdx < High(ARun.Positions) then
    begin
      Result := ARun.Positions[AIdx+1].X - ARun.Positions[AIdx].X;
      if (Result >= AdvanceMinPx) and (Result <= GlyphAdvanceMaxCells * AScale) and (not IsNaN(Result)) and (not IsInfinite(Result)) then Exit;
    end;
    if (AIdx > 0) and (AIdx < Length(ARun.Positions)) then
    begin
      LPrev := ARun.Positions[AIdx].X - ARun.Positions[AIdx-1].X;
      if (LPrev >= AdvanceMinPx) and (LPrev <= GlyphAdvanceMaxCells * AScale) and (not IsNaN(LPrev)) and (not IsInfinite(LPrev)) then
      begin Result := LPrev; Exit; end;
    end;
    if (AIdx >= 0) and (AIdx < Length(ARun.Glyphs)) then
    begin
      LGlyph := ARun.Glyphs[AIdx];
      LAdvLay := LayoutGlyphAdvance(LGlyph, 10, AScale);
      if IsNaN(LAdvLay) or IsInfinite(LAdvLay) then LAdvLay := GlyphAdvanceFallback * AScale;
      if LAdvLay < AdvanceMinPx then LAdvLay := GlyphAdvanceMinCells * AScale;
      if LAdvLay > GlyphAdvanceMaxCells * AScale then LAdvLay := GlyphAdvanceFallback * AScale;
      Result := LAdvLay;
      Exit;
    end;
    Result := GlyphAdvanceFallback * AScale;
    if Result < AdvanceMinPx then Result := GlyphAdvanceMinCells * AScale;
    if Result > GlyphAdvanceMaxCells * AScale then Result := GlyphAdvanceFallback * AScale;
  end;
begin
  if ARun.IsEmpty then Exit;
  if IsNaN(ARun.Scale) or IsInfinite(ARun.Scale) or (ARun.Scale <= 0) then Exit;
  if IsNaN(APos.X) or IsInfinite(APos.X) or IsNaN(APos.Y) or IsInfinite(APos.Y) then Exit;
  Brush := TBrush.Solid(Color32(24, 24, 24));
  CR := GlyphCornerRadius * ARun.Scale;
  if CR < 0.5 then CR := 0.5;
  if CR > 2.5 * ARun.Scale then CR := 1.0 * ARun.Scale;
  for I := 0 to High(ARun.Glyphs) do
  begin
    if ARun.Glyphs[I] = 32 then Continue;
    Adv := ResolveAdvance(I, ARun.Scale);
    if IsNaN(Adv) or IsInfinite(Adv) then Adv := GlyphAdvanceFallback * ARun.Scale;
    if Adv < AdvanceMinPx then Adv := GlyphAdvanceMinCells * ARun.Scale;
    if Adv > GlyphAdvanceMaxCells * ARun.Scale then Adv := GlyphAdvanceFallback * ARun.Scale;
    W := Adv * GlyphWidthRatio;
    H := GlyphHeightCells * ARun.Scale;
    if W < 1 then W := 1;
    if H < 1 then H := 1;
    LX := Round(APos.X + ARun.Positions[I].X + Adv * GlyphInsetRatio);
    LY := Round(APos.Y + ARun.Positions[I].Y - H * GlyphBaselineRatio);
    R := TRect.From(LX, LY, Round(W), Round(H));
    P := BuildRoundedRect(R, CR);
    FillPath(P, Brush);
  end;
end;

function TRasterCanvas.Snapshot: TBitmap;
begin
  Result := FBitmap.Clone;
end;

end.
