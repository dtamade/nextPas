{**
 * nextpas.core.canvas.raster - CPU 光栅（Tile 16x16 架构占位 + 扫描线填充，Double 梯形→整数覆盖）
 * 单线程录制，Save/Restore 栈；Fill 用 tess 梯形，Stroke 复用 PathStroke。
 * 已接入跨平台内联光栅层 nextpas.core.simd.raster（FillSolid/BlendSrcOver 直联 SSE2/标量，不走分发表，可内联）。
 * L2 依赖：单向引用 L2 vector.tess/vector.path 与 L2 image.base（canvas→vector/image），无反向；同层循环受控监控（610 行，阈 800）。
 *}
unit nextpas.core.canvas.raster;

{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.graphics.base,
  nextpas.core.graphics.path,
  nextpas.core.image.base,
  nextpas.core.vector.tess,
  nextpas.core.vector.path,
  nextpas.core.canvas.intf;

type
  TCanvasState = record Mat: TMat2D; Clip: TPath; HasClip: Boolean; end;
  TRasterCanvas = class(TInterfacedObject, ICanvas)
  private
    FBitmap: TBitmap;
    FStack: array of TCanvasState;
    FClip: TPath;
    FHasClip: Boolean;
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
  nextpas.core.bytes.binary,
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
  inherited Create;
  FBitmap := TBitmap.Create(AWidth, AHeight, bfRGBA);
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
end;

procedure TRasterCanvas.Restore;
begin
  if Length(FStack)=0 then raise ECanvasError.Create('nextpas.core.canvas.raster.pas: TRasterCanvas.Restore: stack underflow (depth=0)');
  FMat := FStack[High(FStack)].Mat;
  FClip := FStack[High(FStack)].Clip;
  FHasClip := FStack[High(FStack)].HasClip;
  SetLength(FStack, Length(FStack)-1);
end;

procedure TRasterCanvas.Concat(const AMat: TMat2D);
begin
  FMat := FMat.Concat(AMat);
end;

procedure TRasterCanvas.ClipPath(const APath: TPath);
begin
  FClip := APath;
  FHasClip := not APath.IsEmpty;
end;

procedure TRasterCanvas.ClipRect(const AR: TRect);
begin
  FClip := TPath.New.MoveTo(AR.X, AR.Y).LineTo(AR.X+AR.W, AR.Y).LineTo(AR.X+AR.W, AR.Y+AR.H).LineTo(AR.X, AR.Y+AR.H).Close;
  FHasClip := not AR.IsEmpty;
end;

function TRasterCanvas.TransformPoly(const APoly: array of TVec2): TPoly;
var
  I: Integer;
begin
  SetLength(Result, Length(APoly));
  for I := 0 to High(APoly) do
    Result[I] := FMat.TransformPoint(APoly[I]);
end;

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
    // 二分查找替代线性 while，O(log n)；stops 递增已在 TBrush.ValidateGradient 保证
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
    // tile 剔除：完全在可视外跳过
    if (YEnd <= 0) or (YStart >= H) then Continue;
    if YStart < 0 then YStart := 0;
    if YEnd > H then YEnd := H;
    if YEnd <= YStart then Continue;
    for Y := YStart to YEnd - 1 do
    begin
      if DH <= 1.01 then
      begin
        XL := Tr.XL0; XR := Tr.XR0;
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
      if X1 <= X0 then Continue;
      // encapsulated RowPtr, stride already 64B aligned via mem.base.AlignUp
      P := FBitmap.RowPtr(Y) + X0 * 4;
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
  n, c, k: Integer;
  LocalColors: TColor32Array;
  LocalStops: TSingleArray;
  Lut: array[0..255] of LongWord;
  Chunk: array[0..63] of LongWord;
  hasStops: Boolean;
  cnt, off, rem, j, idx: Integer;
  tt: Single;
  Dx, Dy: Single;
  col: LongWord;
  R, G, B, A: Byte;
  invAlpha: Integer;
  Tv: Integer;
  allOpaque: Boolean;
begin
  if FBitmap.IsEmpty then Exit;
  W := FBitmap.Width; H := FBitmap.Height;
  if ABounds.IsEmpty then Exit;
  n := AGrad.ColorCount;
  if n = 0 then Exit;
  SetLength(LocalColors, n);
  for c := 0 to n - 1 do LocalColors[c] := AGrad.GetColor(c);
  hasStops := AGrad.StopCount > 0;
  if hasStops then
  begin
    SetLength(LocalStops, n);
    for c := 0 to n - 1 do LocalStops[c] := AGrad.GetStop(c);
  end
  else
    SetLength(LocalStops, 0);
  // build LUT O(n*256) once, per-pixel O(1) lookup, avoids per-pixel binary search+GetColor
  for c := 0 to LUT_N - 1 do
  begin
    tt := c / (LUT_N - 1);
    Lut[c] := LongWord(SampleGradient(AGrad, tt));
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
    if YEnd <= YStart then Continue;
    for Y := YStart to YEnd - 1 do
    begin
      if DH <= 1.01 then
      begin XL := Tr.XL0; XR := Tr.XR0; end
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
      if X1 <= X0 then Continue;
      Row := FBitmap.RowPtr(Y);
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
          for j := 0 to cnt - 1 do
          begin
            tt := t0 + Single(off + j) * stepT;
            if tt < 0 then tt := 0 else if tt > 1 then tt := 1;
            idx := Trunc(tt * 255);
            if idx < 0 then idx := 0 else if idx > 255 then idx := 255;
            Chunk[j] := Lut[idx];
          end;
          P := Row + (X0 + off) * 4;
          allOpaque := True;
          for j := 0 to cnt - 1 do
            if Byte((Chunk[j] shr 24) and $FF) <> 255 then begin allOpaque := False; Break; end;
          if allOpaque then
            SimdMemCopy(@Chunk[0], P, NativeUInt(cnt * 4))
          else
          begin
            for j := 0 to cnt - 1 do
            begin
              col := Chunk[j];
              R := Byte((col shr 16) and $FF);
              G := Byte((col shr 8) and $FF);
              B := Byte(col and $FF);
              A := Byte((col shr 24) and $FF);
              if A = 0 then Continue;
              if A = 255 then
                PLongWord(P + j * 4)^ := col
              else
              begin
                invAlpha := 255 - A;
                Tv := Integer(R) * Integer(A) + Integer(P[j*4]) * invAlpha; P[j*4] := Byte((Tv + 1 + (Tv shr 8)) shr 8);
                Tv := Integer(G) * Integer(A) + Integer(P[j*4+1]) * invAlpha; P[j*4+1] := Byte((Tv + 1 + (Tv shr 8)) shr 8);
                Tv := Integer(B) * Integer(A) + Integer(P[j*4+2]) * invAlpha; P[j*4+2] := Byte((Tv + 1 + (Tv shr 8)) shr 8);
                Tv := Integer(P[j*4+3]) * invAlpha; P[j*4+3] := Byte(Integer(A) + (Tv + 1 + (Tv shr 8)) shr 8);
              end;
            end;
          end;
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
          end;
          P := Row + (X0 + off) * 4;
          allOpaque := True;
          for j := 0 to cnt - 1 do
            if Byte((Chunk[j] shr 24) and $FF) <> 255 then begin allOpaque := False; Break; end;
          if allOpaque then
            SimdMemCopy(@Chunk[0], P, NativeUInt(cnt * 4))
          else
          begin
            for j := 0 to cnt - 1 do
            begin
              col := Chunk[j];
              R := Byte((col shr 16) and $FF);
              G := Byte((col shr 8) and $FF);
              B := Byte(col and $FF);
              A := Byte((col shr 24) and $FF);
              if A = 0 then Continue;
              if A = 255 then
                PLongWord(P + j * 4)^ := col
              else
              begin
                invAlpha := 255 - A;
                Tv := Integer(R) * Integer(A) + Integer(P[j*4]) * invAlpha; P[j*4] := Byte((Tv + 1 + (Tv shr 8)) shr 8);
                Tv := Integer(G) * Integer(A) + Integer(P[j*4+1]) * invAlpha; P[j*4+1] := Byte((Tv + 1 + (Tv shr 8)) shr 8);
                Tv := Integer(B) * Integer(A) + Integer(P[j*4+2]) * invAlpha; P[j*4+2] := Byte((Tv + 1 + (Tv shr 8)) shr 8);
                Tv := Integer(P[j*4+3]) * invAlpha; P[j*4+3] := Byte(Integer(A) + (Tv + 1 + (Tv shr 8)) shr 8);
              end;
            end;
          end;
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
var
  SW, SH, DW, DH, DX, DY: Integer;
  SX0f, SY0f: Single;
  ScaleX, ScaleY: Single;
  Y, X, SY, SX, DstY: Integer;
  ClipX0, ClipX1: Integer;
  SrcRow, DstRow: PByte;
  SrcRow0, SrcRow1: PByte;
  FX, FY, FX1, FY1: Single;
  IX0, IY0, IX1, IY1: Integer;
  WX, WY: Single;
  W00, W10, W01, W11: Single;
  C00, C10, C01, C11: LongWord;
  R, G, B, A: Byte;
  c4, wyI, wxI: Integer;
  w00i, w10i, w01i, w11i: Integer;
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
  SW := Trunc(ASrc.W); SH := Trunc(ASrc.H);
  DW := Trunc(ADst.W); DH := Trunc(ADst.H);
  if (SW <= 0) or (SH <= 0) or (DW <= 0) or (DH <= 0) then Exit;
  DX := Trunc(ADst.X); DY := Trunc(ADst.Y);
  SX0f := ASrc.X; SY0f := ASrc.Y;
  ScaleX := ASrc.W / ADst.W;
  ScaleY := ASrc.H / ADst.H;
  // fast equal-size path: row batch Move via SimdMemCopy, stride aligned
  if (SW = DW) and (SH = DH) and (AQuality = fqNearest) then
  begin
    if (Trunc(SX0f) = SX0f) and (Trunc(SY0f) = SY0f) then
    begin
      for Y := 0 to DH - 1 do
      begin
        DstY := DY + Y;
        if (DstY < 0) or (DstY >= FBitmap.Height) then Continue;
        SY := Trunc(SY0f) + Y;
        if (SY < 0) or (SY >= ABitmap.Height) then Continue;
        ClipX0 := 0;
        ClipX1 := DW;
        if DX < 0 then ClipX0 := -DX;
        if DX + ClipX1 > FBitmap.Width then ClipX1 := FBitmap.Width - DX;
        if ClipX1 <= ClipX0 then Continue;
        // source X clip
        if Trunc(SX0f) + ClipX0 < 0 then ClipX0 := -Trunc(SX0f);
        if Trunc(SX0f) + ClipX1 > ABitmap.Width then ClipX1 := ABitmap.Width - Trunc(SX0f);
        if ClipX1 <= ClipX0 then Continue;
        SrcRow := ABitmap.RowPtr(SY) + Trunc(SX0f) * 4 + ClipX0 * 4;
        DstRow := FBitmap.RowPtr(DstY) + DX * 4 + ClipX0 * 4;
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
          FY := SY0f + Y * ScaleY;
          SY := Trunc(FY);
          if SY < 0 then SY := 0 else if SY >= ABitmap.Height then SY := ABitmap.Height - 1;
          SrcRow := ABitmap.RowPtr(SY);
          DstRow := FBitmap.RowPtr(DstY);
          ClipX0 := 0;
          ClipX1 := DW;
          if DX < 0 then ClipX0 := -DX;
          if DX + ClipX1 > FBitmap.Width then ClipX1 := FBitmap.Width - DX;
          if ClipX1 <= ClipX0 then Continue;
          for X := ClipX0 to ClipX1 - 1 do
          begin
            FX := SX0f + X * ScaleX;
            SX := Trunc(FX);
            if (SX < 0) or (SX >= ABitmap.Width) then Continue;
            // direct 32-bit copy, hoisted row ptrs, no per-pixel bytes.binary call
            PLongWord(DstRow)[DX + X] := PLongWord(SrcRow)[SX];
          end;
        end;
      end;
    fqLinear, fqCubic:
      begin
        for Y := 0 to DH - 1 do
        begin
          DstY := DY + Y;
          if (DstY < 0) or (DstY >= FBitmap.Height) then Continue;
          FY := SY0f + (Y + 0.5) * ScaleY - 0.5;
          IY0 := Trunc(FY);
          FY1 := FY - IY0;
          if FY1 < 0 then begin IY0 := IY0 - 1; FY1 := FY1 + 1; end;
          if IY0 < 0 then begin IY0 := 0; FY1 := 0; end;
          if IY0 >= ABitmap.Height - 1 then begin IY0 := ABitmap.Height - 2; FY1 := 1; end;
          if ABitmap.Height = 1 then begin IY0 := 0; FY1 := 0; end;
          IY1 := IY0 + 1;
          if IY1 >= ABitmap.Height then IY1 := IY0;
          SrcRow0 := ABitmap.RowPtr(IY0);
          SrcRow1 := ABitmap.RowPtr(IY1);
          DstRow := FBitmap.RowPtr(DstY);
          ClipX0 := 0;
          ClipX1 := DW;
          if DX < 0 then ClipX0 := -DX;
          if DX + ClipX1 > FBitmap.Width then ClipX1 := FBitmap.Width - DX;
          if ClipX1 <= ClipX0 then Continue;
          // fixed-point WY 0..256, hoisted per row, integer blend with bytes.binary loads
          wyI := Round(FY1 * 256);
          if wyI < 0 then wyI := 0 else if wyI > 256 then wyI := 256;
          X := ClipX0;
          while X + 3 < ClipX1 do
          begin
            // 4-pixel batch unroll, each still bilinear but weight calc batched and uses integer fixed-point + bytes.binary batch
            for c4 := 0 to 3 do
            begin
              FX := SX0f + (X + c4 + 0.5) * ScaleX - 0.5;
              IX0 := Trunc(FX);
              FX1 := FX - IX0;
              if FX1 < 0 then begin IX0 := IX0 - 1; FX1 := FX1 + 1; end;
              if IX0 < 0 then begin IX0 := 0; FX1 := 0; end;
              if IX0 >= ABitmap.Width - 1 then begin IX0 := ABitmap.Width - 2; FX1 := 1; end;
              if ABitmap.Width = 1 then begin IX0 := 0; FX1 := 0; end;
              IX1 := IX0 + 1; if IX1 >= ABitmap.Width then IX1 := IX0;
              wxI := Round(FX1 * 256); if wxI < 0 then wxI := 0 else if wxI > 256 then wxI := 256;
              w00i := (256 - wxI) * (256 - wyI);
              w10i := wxI * (256 - wyI);
              w01i := (256 - wxI) * wyI;
              w11i := wxI * wyI;
              C00 := ReadUInt32LE(SrcRow0 + IX0 * 4);
              C10 := ReadUInt32LE(SrcRow0 + IX1 * 4);
              C01 := ReadUInt32LE(SrcRow1 + IX0 * 4);
              C11 := ReadUInt32LE(SrcRow1 + IX1 * 4);
              R := Byte((Byte(C00) * w00i + Byte(C10) * w10i + Byte(C01) * w01i + Byte(C11) * w11i + 32768) shr 16);
              G := Byte((Byte(C00 shr 8) * w00i + Byte(C10 shr 8) * w10i + Byte(C01 shr 8) * w01i + Byte(C11 shr 8) * w11i + 32768) shr 16);
              B := Byte((Byte(C00 shr 16) * w00i + Byte(C10 shr 16) * w10i + Byte(C01 shr 16) * w01i + Byte(C11 shr 16) * w11i + 32768) shr 16);
              A := Byte((Byte(C00 shr 24) * w00i + Byte(C10 shr 24) * w10i + Byte(C01 shr 24) * w01i + Byte(C11 shr 24) * w11i + 32768) shr 16);
              WriteUInt32LE(DstRow + (DX + X + c4) * 4, LongWord(R) or (LongWord(G) shl 8) or (LongWord(B) shl 16) or (LongWord(A) shl 24));
            end;
            X := X + 4;
          end;
          while X < ClipX1 do
          begin
            FX := SX0f + (X + 0.5) * ScaleX - 0.5;
            IX0 := Trunc(FX);
            FX1 := FX - IX0;
            if FX1 < 0 then begin IX0 := IX0 - 1; FX1 := FX1 + 1; end;
            if IX0 < 0 then begin IX0 := 0; FX1 := 0; end;
            if IX0 >= ABitmap.Width - 1 then begin IX0 := ABitmap.Width - 2; FX1 := 1; end;
            if ABitmap.Width = 1 then begin IX0 := 0; FX1 := 0; end;
            IX1 := IX0 + 1; if IX1 >= ABitmap.Width then IX1 := IX0;
            wxI := Round(FX1 * 256); if wxI < 0 then wxI := 0 else if wxI > 256 then wxI := 256;
            w00i := (256 - wxI) * (256 - wyI);
            w10i := wxI * (256 - wyI);
            w01i := (256 - wxI) * wyI;
            w11i := wxI * wyI;
            C00 := ReadUInt32LE(SrcRow0 + IX0 * 4);
            C10 := ReadUInt32LE(SrcRow0 + IX1 * 4);
            C01 := ReadUInt32LE(SrcRow1 + IX0 * 4);
            C11 := ReadUInt32LE(SrcRow1 + IX1 * 4);
            R := Byte((Byte(C00) * w00i + Byte(C10) * w10i + Byte(C01) * w01i + Byte(C11) * w11i + 32768) shr 16);
            G := Byte((Byte(C00 shr 8) * w00i + Byte(C10 shr 8) * w10i + Byte(C01 shr 8) * w01i + Byte(C11 shr 8) * w11i + 32768) shr 16);
            B := Byte((Byte(C00 shr 16) * w00i + Byte(C10 shr 16) * w10i + Byte(C01 shr 16) * w01i + Byte(C11 shr 16) * w11i + 32768) shr 16);
            A := Byte((Byte(C00 shr 24) * w00i + Byte(C10 shr 24) * w10i + Byte(C01 shr 24) * w01i + Byte(C11 shr 24) * w11i + 32768) shr 16);
            WriteUInt32LE(DstRow + (DX + X) * 4, LongWord(R) or (LongWord(G) shl 8) or (LongWord(B) shl 16) or (LongWord(A) shl 24));
            Inc(X);
          end;
        end;
      end;
  end;
end;

procedure TRasterCanvas.DrawGlyphRun(const ARun: TGlyphRun; const APos: TVec2);
const
  // glyph metrics derived from TGlyphRun.Scale + advance; named to avoid magic
  // 占位圆角矩形：真实字形由 font atlas/shaper 注入时无缝替换；当前由
  // graphics.text.LayoutText 产 GlyphRun（等宽占位 + Scale 打通），已闭环高级感封装
  // 比例化常量保持像素与 golden 1120e4a1 一致，待 font 层就绪再切 SDF/位图
  GlyphAdvanceFallback = 8.0;
  GlyphAdvanceMinCells = 6.0;
  GlyphAdvanceMaxCells = 20.0;
  AdvanceMinPx = 2.0;
  GlyphWidthRatio = 0.78;
  GlyphInsetRatio = 0.11;
  GlyphHeightCells = 10.0;
  GlyphBaselineRatio = 0.78;
  GlyphCornerRadius = 1.0;
var
  I: Integer;
  R: TRect;
  P: TPath;
  Brush: TBrush;
  W, H, Adv, CR: Single;
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
begin
  if ARun.IsEmpty then Exit;
  Brush := TBrush.Solid(Color32(24, 24, 24));
  CR := GlyphCornerRadius * ARun.Scale;
  if CR < 0.5 then CR := 0.5;
  if CR > 2.5 * ARun.Scale then CR := 1.0 * ARun.Scale;
  for I := 0 to High(ARun.Glyphs) do
  begin
    if ARun.Glyphs[I] = 32 then Continue;
    if I < High(ARun.Positions) then
      Adv := ARun.Positions[I+1].X - ARun.Positions[I].X
    else
      Adv := GlyphAdvanceFallback * ARun.Scale;
    if Adv < AdvanceMinPx then Adv := GlyphAdvanceMinCells * ARun.Scale;
    if Adv > GlyphAdvanceMaxCells * ARun.Scale then Adv := GlyphAdvanceFallback * ARun.Scale;
    W := Adv * GlyphWidthRatio;
    H := GlyphHeightCells * ARun.Scale;
    if W < 1 then W := 1;
    if H < 1 then H := 1;
    R := TRect.From(
      APos.X + ARun.Positions[I].X + Adv * GlyphInsetRatio,
      APos.Y + ARun.Positions[I].Y - H * GlyphBaselineRatio, W, H);
    P := BuildRoundedRect(R, CR);
    FillPath(P, Brush);
  end;
end;

function TRasterCanvas.Snapshot: TBitmap;
begin
  Result := FBitmap.Clone;
end;

end.
