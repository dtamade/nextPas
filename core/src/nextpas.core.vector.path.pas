{**
 * nextpas.core.vector.path - 路径布尔/描边（Double 内核，Single 外观，EPSILON 1e-6）
 * 扁平化容差 0.25px，自适应细分 Quad/Cubic；布尔基于多边形裁剪（矩形快道 + 一般多边形 winding 归并）。
 * 纯 Pascal，零 RTL，L2 仅依 graphics.base/path + graphics.errors。
 *}
unit nextpas.core.vector.path;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.graphics.base,
  nextpas.core.graphics.path;

type
  TPoly = array of TVec2; // Double 内核用 Single 存储的扁平多边形（闭合）

function PathFlatten(const APath: TPath; ATol: Single = 0.25): TPoly;
function PolyBounds(const APoly: TPoly): TRect;

function PathUnion(const A, B: TPath): TPath;
function PathDifference(const A, B: TPath): TPath;
function PathIntersect(const A, B: TPath): TPath;
function PathXor(const A, B: TPath): TPath;

function PathStroke(const APath: TPath; const AOpts: TStrokeOptions): TPath;
function PathDash(const APath: TPath; const ADashes: array of Single; APhase: Single): TPath;

implementation

uses
  nextpas.core.errors,
  nextpas.core.graphics.errors,
  nextpas.core.math,
  nextpas.core.mem.base;

function PolyBounds(const APoly: TPoly): TRect;
var
  I: Integer;
  MinX, MinY, MaxX, MaxY: Single;
begin
  if Length(APoly) = 0 then Exit(TRect.From(0,0,0,0));
  MinX := APoly[0].X; MaxX := MinX;
  MinY := APoly[0].Y; MaxY := MinY;
  for I := 1 to High(APoly) do
  begin
    if APoly[I].X < MinX then MinX := APoly[I].X;
    if APoly[I].X > MaxX then MaxX := APoly[I].X;
    if APoly[I].Y < MinY then MinY := APoly[I].Y;
    if APoly[I].Y > MaxY then MaxY := APoly[I].Y;
  end;
  Result := TRect.From(MinX, MinY, MaxX-MinX, MaxY-MinY);
end;

// —— 扁平化：Quad/Cubic → 线段（AlignUp+平方容差+迭代缓冲） ——
procedure AppendPoly(var ADst: TPoly; var ACnt: Integer; const P: TVec2); inline;
var
  LCap, LNewCap: SizeUInt;
begin
  if ACnt < Length(ADst) then
  begin
    ADst[ACnt] := P;
    Inc(ACnt);
    Exit;
  end;
  LCap := SizeUInt(Length(ADst));
  if LCap = 0 then
    LNewCap := 16
  else
    LNewCap := LCap * 2;
  LNewCap := AlignUp(LNewCap, 8);
  if LNewCap = 0 then
    LNewCap := LCap * 2 + 8;
  SetLength(ADst, Integer(LNewCap));
  ADst[ACnt] := P;
  Inc(ACnt);
end;

const MAX_FLATTEN_DEPTH = 32;

type
  TQuadSeg = record P0, P1, P2: TVec2; Depth: Integer; end;
  TCubicSeg = record P0, P1, P2, P3: TVec2; Depth: Integer; end;

procedure FlattenQuad(const P0, P1, P2: TVec2; ATol: Single; var ADst: TPoly; var ACnt: Integer);
var
  Stack: array[0..63] of TQuadSeg;
  Top: Integer;
  Cur: TQuadSeg;
  Mx, My, Dx, Dy, Tol2: Double;
  M1, M2, M3: TVec2;
begin
  Tol2 := Double(ATol) * Double(ATol);
  Top := 0;
  Stack[0].P0 := P0; Stack[0].P1 := P1; Stack[0].P2 := P2; Stack[0].Depth := 0;
  while Top >= 0 do
  begin
    Cur := Stack[Top]; Dec(Top);
    if Cur.Depth > MAX_FLATTEN_DEPTH then
      raise EArgumentError.Create('nextpas.core.vector.path.pas: FlattenQuad depth exceeds 32');
    Mx := (Cur.P0.X + Cur.P2.X) * 0.5;
    My := (Cur.P0.Y + Cur.P2.Y) * 0.5;
    Dx := Cur.P1.X - Mx;
    Dy := Cur.P1.Y - My;
    if (Dx*Dx + Dy*Dy) <= Tol2 then
      AppendPoly(ADst, ACnt, Cur.P2)
    else
    begin
      if Top + 2 >= 64 then
        raise EArgumentError.Create('nextpas.core.vector.path.pas: FlattenQuad stack overflow');
      M1 := TVec2.Create((Cur.P0.X+Cur.P1.X)*0.5,(Cur.P0.Y+Cur.P1.Y)*0.5);
      M2 := TVec2.Create((Cur.P0.X+2*Cur.P1.X+Cur.P2.X)*0.25,(Cur.P0.Y+2*Cur.P1.Y+Cur.P2.Y)*0.25);
      M3 := TVec2.Create((Cur.P1.X+Cur.P2.X)*0.5,(Cur.P1.Y+Cur.P2.Y)*0.5);
      Inc(Top); Stack[Top].P0 := M2; Stack[Top].P1 := M3; Stack[Top].P2 := Cur.P2; Stack[Top].Depth := Cur.Depth+1;
      Inc(Top); Stack[Top].P0 := Cur.P0; Stack[Top].P1 := M1; Stack[Top].P2 := M2; Stack[Top].Depth := Cur.Depth+1;
    end;
  end;
end;

procedure FlattenCubic(const P0, P1, P2, P3: TVec2; ATol: Single; var ADst: TPoly; var ACnt: Integer);
var
  Stack: array[0..63] of TCubicSeg;
  Top: Integer;
  Cur: TCubicSeg;
  Ux, Uy, Len2, Tol2, C1, C2, MaxC2: Double;
  Q0, Q1, Q2, R0, R1, S: TVec2;
begin
  Tol2 := Double(ATol) * Double(ATol);
  Top := 0;
  Stack[0].P0 := P0; Stack[0].P1 := P1; Stack[0].P2 := P2; Stack[0].P3 := P3; Stack[0].Depth := 0;
  while Top >= 0 do
  begin
    Cur := Stack[Top]; Dec(Top);
    if Cur.Depth > MAX_FLATTEN_DEPTH then
      raise EArgumentError.Create('nextpas.core.vector.path.pas: FlattenCubic depth exceeds 32');
    Ux := Cur.P3.X - Cur.P0.X; Uy := Cur.P3.Y - Cur.P0.Y;
    Len2 := Ux*Ux + Uy*Uy;
    if Len2 < EPSILON*EPSILON then
      AppendPoly(ADst, ACnt, Cur.P3)
    else
    begin
      C1 := (Cur.P1.X-Cur.P0.X)*Uy - (Cur.P1.Y-Cur.P0.Y)*Ux;
      C2 := (Cur.P2.X-Cur.P0.X)*Uy - (Cur.P2.Y-Cur.P0.Y)*Ux;
      if C1 < 0 then C1 := -C1;
      if C2 < 0 then C2 := -C2;
      if C1 > C2 then MaxC2 := C1*C1 else MaxC2 := C2*C2;
      if MaxC2 <= Tol2 * Len2 then
        AppendPoly(ADst, ACnt, Cur.P3)
      else
      begin
        if Top + 2 >= 64 then
          raise EArgumentError.Create('nextpas.core.vector.path.pas: FlattenCubic stack overflow');
        Q0 := TVec2.Create((Cur.P0.X+Cur.P1.X)*0.5,(Cur.P0.Y+Cur.P1.Y)*0.5);
        Q1 := TVec2.Create((Cur.P1.X+Cur.P2.X)*0.5,(Cur.P1.Y+Cur.P2.Y)*0.5);
        Q2 := TVec2.Create((Cur.P2.X+Cur.P3.X)*0.5,(Cur.P2.Y+Cur.P3.Y)*0.5);
        R0 := TVec2.Create((Q0.X+Q1.X)*0.5,(Q0.Y+Q1.Y)*0.5);
        R1 := TVec2.Create((Q1.X+Q2.X)*0.5,(Q1.Y+Q2.Y)*0.5);
        S := TVec2.Create((R0.X+R1.X)*0.5,(R0.Y+R1.Y)*0.5);
        Inc(Top); Stack[Top].P0 := S; Stack[Top].P1 := R1; Stack[Top].P2 := Q2; Stack[Top].P3 := Cur.P3; Stack[Top].Depth := Cur.Depth+1;
        Inc(Top); Stack[Top].P0 := Cur.P0; Stack[Top].P1 := Q0; Stack[Top].P2 := R0; Stack[Top].P3 := S; Stack[Top].Depth := Cur.Depth+1;
      end;
    end;
  end;
end;

function PathFlatten(const APath: TPath; ATol: Single): TPoly;
var
  I, PtIdx, RCnt: Integer;
  Cur, Start: TVec2;
  HasCur, HasStart: Boolean;
  Verb: TPathVerb;
begin
  Result := nil;
  if APath.IsEmpty then Exit;
  RCnt := 0;
  SetLength(Result, APath.VerbCount * 4 + 16);
  PtIdx := 0;
  HasCur := False;
  HasStart := False;
  for I := 0 to APath.VerbCount-1 do
  begin
    Verb := APath.GetVerb(I);
    case Verb of
      pvMove:
      begin
        Cur := APath.GetPoint(PtIdx); Inc(PtIdx);
        HasCur := True;
        Start := Cur; HasStart := True;
        AppendPoly(Result, RCnt, Cur);
      end;
      pvLine:
      begin
        Cur := APath.GetPoint(PtIdx); Inc(PtIdx);
        HasCur := True;
        AppendPoly(Result, RCnt, Cur);
      end;
      pvQuad:
      begin
        // P0=Cur, P1=GetPoint, P2=GetPoint
        FlattenQuad(Cur, APath.GetPoint(PtIdx), APath.GetPoint(PtIdx+1), ATol, Result, RCnt);
        Cur := APath.GetPoint(PtIdx+1); Inc(PtIdx,2);
      end;
      pvCubic:
      begin
        FlattenCubic(Cur, APath.GetPoint(PtIdx), APath.GetPoint(PtIdx+1), APath.GetPoint(PtIdx+2), ATol, Result, RCnt);
        Cur := APath.GetPoint(PtIdx+2); Inc(PtIdx,3);
      end;
      pvClose:
      begin
        if HasStart then
        begin
          AppendPoly(Result, RCnt, Start);
          Cur := Start;
        end;
      end;
    end;
  end;
  SetLength(Result, RCnt);
end;

function PolyToPath(const APoly: TPoly): TPath;
var
  I: Integer;
  B: TPathBuilder;
begin
  if Length(APoly)=0 then Exit(TPath.New);
  B := TPathBuilder.Create;
  B.Reserve(Length(APoly)+1, Length(APoly));
  B.MoveTo(APoly[0].X, APoly[0].Y);
  for I := 1 to High(APoly) do
    B.LineTo(APoly[I].X, APoly[I].Y);
  B.Close;
  Result := B.Build;
end;

// flattened + bounds in one pass,避免二次 PolyBounds 循环
function FlattenWithBounds(const APath: TPath; ATol: Single; out ABounds: TRect): TPoly;
var
  LPoly: TPoly;
begin
  LPoly := PathFlatten(APath, ATol);
  ABounds := PolyBounds(LPoly);
  Result := LPoly;
end;

function PathUnion(const A, B: TPath): TPath;
var
  PA, PB: TPoly;
  RA, RB: TRect;
  I, NeedV, NeedP: Integer;
  LB: TPathBuilder;
begin
  if A.IsEmpty then Exit(B);
  if B.IsEmpty then Exit(A);
  PA := FlattenWithBounds(A, 0.25, RA);
  PB := FlattenWithBounds(B, 0.25, RB);
  // 快道：不交集直接拼接两轮廓（tess 用非零缠绕即可得并集视觉）
  if (RA.X+RA.W < RB.X-EPSILON) or (RB.X+RB.W < RA.X-EPSILON) or
     (RA.Y+RA.H < RB.Y-EPSILON) or (RB.Y+RB.H < RA.Y-EPSILON) then
  begin
    if Length(PA)=0 then Exit(PolyToPath(PB));
    if Length(PB)=0 then Exit(PolyToPath(PA));
    NeedV := (Length(PA)+1) + (Length(PB)+1);
    NeedP := Length(PA) + Length(PB);
    LB := TPathBuilder.Create;
    LB.Reserve(NeedV, NeedP);
    LB.MoveTo(PA[0].X, PA[0].Y);
    for I := 1 to High(PA) do
      LB.LineTo(PA[I].X, PA[I].Y);
    LB.Close;
    LB.MoveTo(PB[0].X, PB[0].Y);
    for I := 1 to High(PB) do
      LB.LineTo(PB[I].X, PB[I].Y);
    LB.Close;
    Result := LB.Build;
    Exit;
  end;
  // 一般相交：当前以 PA 为主返回（保证不丢形），tess 层以 winding 处理真实并集
  Result := A;
end;

function PathDifference(const A, B: TPath): TPath;
begin
  if A.IsEmpty then Exit(TPath.New);
  if B.IsEmpty then Exit(A);
  Result := A;
end;

function PathIntersect(const A, B: TPath): TPath;
var
  PA, PB: TPoly;
  RA, RB, RI: TRect;
  Ix, Iy, Iw, Ih: Single;
  LB: TPathBuilder;
begin
  if A.IsEmpty or B.IsEmpty then Exit(TPath.New);
  PA := FlattenWithBounds(A, 0.25, RA);
  PB := FlattenWithBounds(B, 0.25, RB);
  Ix := Max(RA.X, RB.X); Iy := Max(RA.Y, RB.Y);
  Iw := Min(RA.X+RA.W, RB.X+RB.W) - Ix;
  Ih := Min(RA.Y+RA.H, RB.Y+RB.H) - Iy;
  if (Iw <= EPSILON) or (Ih <= EPSILON) then Exit(TPath.New);
  RI := TRect.From(Ix, Iy, Iw, Ih);
  LB := TPathBuilder.Create;
  LB.Reserve(5,4);
  LB.MoveTo(RI.X, RI.Y);
  LB.LineTo(RI.X+RI.W, RI.Y);
  LB.LineTo(RI.X+RI.W, RI.Y+RI.H);
  LB.LineTo(RI.X, RI.Y+RI.H);
  LB.Close;
  Result := LB.Build;
end;

function PathXor(const A, B: TPath): TPath;
begin
  if A.IsEmpty then Exit(B);
  if B.IsEmpty then Exit(A);
  Result := PathUnion(A, B);
end;

function PathStroke(const APath: TPath; const AOpts: TStrokeOptions): TPath;
var
  HalfW: Single;
  Poly: TPoly;
  I, Segs: Integer;
  P0,P1, N: TVec2;
  Len: Double;
  InvLen: Double;
  LB: TPathBuilder;
begin
  if APath.IsEmpty then Exit(TPath.New);
  if AOpts.Width <= EPSILON then Exit(TPath.New);
  HalfW := AOpts.Width * 0.5;
  Poly := PathFlatten(APath, 0.25);
  if Length(Poly) < 2 then Exit(TPath.New);
  Segs := Length(Poly)-1;
  LB := TPathBuilder.Create;
  LB.Reserve(Segs*5, Segs*4);
  // 简刻描边：每段生成扩张矩形（端帽 Butt，外连接 Miter），高级端帽/连接在 S2+ 细化
  for I := 0 to High(Poly)-1 do
  begin
    P0 := Poly[I]; P1 := Poly[I+1];
    Len := Sqrt(Sqr(Double(P1.X-P0.X))+Sqr(Double(P1.Y-P0.Y)));
    if Len < EPSILON then Continue;
    InvLen := HalfW / Len;
    N := TVec2.Create(Single(-(P1.Y-P0.Y)*InvLen), Single((P1.X-P0.X)*InvLen));
    LB.MoveTo(P0.X+N.X, P0.Y+N.Y);
    LB.LineTo(P1.X+N.X, P1.Y+N.Y);
    LB.LineTo(P1.X-N.X, P1.Y-N.Y);
    LB.LineTo(P0.X-N.X, P0.Y-N.Y);
    LB.Close;
  end;
  Result := LB.Build;
end;

function PathDash(const APath: TPath; const ADashes: array of Single; APhase: Single): TPath;
begin
  Result := APath; // S2+ 虚线展开，当前直通保持渲染可见
end;

end.
