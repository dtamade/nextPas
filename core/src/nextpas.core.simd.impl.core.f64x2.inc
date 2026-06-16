// === F64x2 Operations Implementation ===
// F64x2 高级 API 实现

function VecF64x2Add(const a, b: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AddF64x2) then
    Result := dispatch^.AddF64x2(a, b)
  else
  begin
    Result.d[0] := a.d[0] + b.d[0];
    Result.d[1] := a.d[1] + b.d[1];
  end;
end;

function VecF64x2Sub(const a, b: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SubF64x2) then
    Result := dispatch^.SubF64x2(a, b)
  else
  begin
    Result.d[0] := a.d[0] - b.d[0];
    Result.d[1] := a.d[1] - b.d[1];
  end;
end;

function VecF64x2Mul(const a, b: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MulF64x2) then
    Result := dispatch^.MulF64x2(a, b)
  else
  begin
    Result.d[0] := a.d[0] * b.d[0];
    Result.d[1] := a.d[1] * b.d[1];
  end;
end;

function VecF64x2Div(const a, b: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.DivF64x2) then
    Result := dispatch^.DivF64x2(a, b)
  else
  begin
    Result.d[0] := a.d[0] / b.d[0];
    Result.d[1] := a.d[1] / b.d[1];
  end;
end;

// F64x2 比较操作 - 使用派发表

function VecF64x2CmpEq(const a, b: TVecF64x2): TMask2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpEqF64x2) then
    Result := dispatch^.CmpEqF64x2(a, b)
  else begin
    Result := 0;
    if a.d[0] = b.d[0] then Result := Result or 1;
    if a.d[1] = b.d[1] then Result := Result or 2;
  end;
end;

function VecF64x2CmpLt(const a, b: TVecF64x2): TMask2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLtF64x2) then
    Result := dispatch^.CmpLtF64x2(a, b)
  else begin
    Result := 0;
    if a.d[0] < b.d[0] then Result := Result or 1;
    if a.d[1] < b.d[1] then Result := Result or 2;
  end;
end;

function VecF64x2CmpLe(const a, b: TVecF64x2): TMask2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLeF64x2) then
    Result := dispatch^.CmpLeF64x2(a, b)
  else begin
    Result := 0;
    if a.d[0] <= b.d[0] then Result := Result or 1;
    if a.d[1] <= b.d[1] then Result := Result or 2;
  end;
end;

function VecF64x2CmpGt(const a, b: TVecF64x2): TMask2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGtF64x2) then
    Result := dispatch^.CmpGtF64x2(a, b)
  else begin
    Result := 0;
    if a.d[0] > b.d[0] then Result := Result or 1;
    if a.d[1] > b.d[1] then Result := Result or 2;
  end;
end;

function VecF64x2CmpGe(const a, b: TVecF64x2): TMask2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGeF64x2) then
    Result := dispatch^.CmpGeF64x2(a, b)
  else begin
    Result := 0;
    if a.d[0] >= b.d[0] then Result := Result or 1;
    if a.d[1] >= b.d[1] then Result := Result or 2;
  end;
end;

function VecF64x2CmpNe(const a, b: TVecF64x2): TMask2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpNeF64x2) then
    Result := dispatch^.CmpNeF64x2(a, b)
  else begin
    Result := 0;
    if a.d[0] <> b.d[0] then Result := Result or 1;
    if a.d[1] <> b.d[1] then Result := Result or 2;
  end;
end;

function VecF64x2Abs(const a: TVecF64x2): TVecF64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AbsF64x2) then
    Result := LDispatch^.AbsF64x2(a)
  else
  begin
    Result.d[0] := Abs(a.d[0]);
    Result.d[1] := Abs(a.d[1]);
  end;
end;

function VecF64x2Sqrt(const a: TVecF64x2): TVecF64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.SqrtF64x2) then
    Result := LDispatch^.SqrtF64x2(a)
  else
  begin
    Result.d[0] := Sqrt(a.d[0]);
    Result.d[1] := Sqrt(a.d[1]);
  end;
end;

function VecF64x2Min(const a, b: TVecF64x2): TVecF64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.MinF64x2) then
    Result := LDispatch^.MinF64x2(a, b)
  else
  begin
    if a.d[0] < b.d[0] then Result.d[0] := a.d[0] else Result.d[0] := b.d[0];
    if a.d[1] < b.d[1] then Result.d[1] := a.d[1] else Result.d[1] := b.d[1];
  end;
end;

function VecF64x2Max(const a, b: TVecF64x2): TVecF64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.MaxF64x2) then
    Result := LDispatch^.MaxF64x2(a, b)
  else
  begin
    if a.d[0] > b.d[0] then Result.d[0] := a.d[0] else Result.d[0] := b.d[0];
    if a.d[1] > b.d[1] then Result.d[1] := a.d[1] else Result.d[1] := b.d[1];
  end;
end;

// === F64x2 Extended Math Functions ===

function VecF64x2Fma(const a, b, c: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.FmaF64x2(a, b, c);
end;

// === F64x2 Rounding Functions ===

function VecF64x2Floor(const a: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.FloorF64x2(a);
end;

function VecF64x2Ceil(const a: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.CeilF64x2(a);
end;

function VecF64x2Round(const a: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.RoundF64x2(a);
end;

function VecF64x2Trunc(const a: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.TruncF64x2(a);
end;

function VecF64x2Clamp(const a, minVal, maxVal: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.ClampF64x2(a, minVal, maxVal);
end;

function VecF64x2ReduceAdd(const a: TVecF64x2): Double;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ReduceAddF64x2) then
    Result := LDispatch^.ReduceAddF64x2(a)
  else
    Result := a.d[0] + a.d[1];
end;

function VecF64x2ReduceMin(const a: TVecF64x2): Double;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ReduceMinF64x2) then
    Result := LDispatch^.ReduceMinF64x2(a)
  else if a.d[0] < a.d[1] then
    Result := a.d[0]
  else
    Result := a.d[1];
end;

function VecF64x2ReduceMax(const a: TVecF64x2): Double;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ReduceMaxF64x2) then
    Result := LDispatch^.ReduceMaxF64x2(a)
  else if a.d[0] > a.d[1] then
    Result := a.d[0]
  else
    Result := a.d[1];
end;

function VecF64x2ReduceMul(const a: TVecF64x2): Double;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ReduceMulF64x2) then
    Result := LDispatch^.ReduceMulF64x2(a)
  else
    Result := a.d[0] * a.d[1];
end;

// F64x2 memory operations
function VecF64x2Load(p: PDouble): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.LoadF64x2) then
    Result := dispatch^.LoadF64x2(p)
  else
  begin
    Result.d[0] := p[0];
    Result.d[1] := p[1];
  end;
end;

procedure VecF64x2Store(p: PDouble; const a: TVecF64x2);
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.StoreF64x2) then
    dispatch^.StoreF64x2(p, a)
  else
  begin
    p[0] := a.d[0];
    p[1] := a.d[1];
  end;
end;

function VecF64x2Splat(value: Double): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SplatF64x2) then
    Result := dispatch^.SplatF64x2(value)
  else
  begin
    Result.d[0] := value;
    Result.d[1] := value;
  end;
end;

function VecF64x2Zero: TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ZeroF64x2) then
    Result := dispatch^.ZeroF64x2()
  else
  begin
    Result.d[0] := 0.0;
    Result.d[1] := 0.0;
  end;
end;

function VecF64x2Select(const mask: TMask2; const a, b: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SelectF64x2) then
    Result := dispatch^.SelectF64x2(mask, a, b)
  else
  begin
    // 标量回退实现
    if (mask and 1) <> 0 then Result.d[0] := a.d[0] else Result.d[0] := b.d[0];
    if (mask and 2) <> 0 then Result.d[1] := a.d[1] else Result.d[1] := b.d[1];
  end;
end;

// 缺失的 Select 操作实现

function VecI32x4Select(const mask: TVecI32x4; const a, b: TVecI32x4): TVecI32x4;
var
  dispatch: PSimdDispatchTable;
  i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SelectI32x4) then
    Result := dispatch^.SelectI32x4(mask, a, b)
  else
  begin
    for i := 0 to 3 do
      Result.i[i] := (a.i[i] and mask.i[i]) or (b.i[i] and (not mask.i[i]));
  end;
end;

function VecF32x8Select(const mask: TVecU32x8; const a, b: TVecF32x8): TVecF32x8;
var
  dispatch: PSimdDispatchTable;
  i: Integer;
  la, lb, lr: UInt32;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SelectF32x8) then
    Result := dispatch^.SelectF32x8(mask, a, b)
  else
  begin
    for i := 0 to 7 do
    begin
      la := PDWord(@a.f[i])^;
      lb := PDWord(@b.f[i])^;
      lr := (la and mask.u[i]) or (lb and (not mask.u[i]));
      PDWord(@Result.f[i])^ := lr;
    end;
  end;
end;

function VecF64x4Select(const mask: TVecU64x4; const a, b: TVecF64x4): TVecF64x4;
var
  dispatch: PSimdDispatchTable;
  i: Integer;
  la64, lb64, lr64: UInt64;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SelectF64x4) then
    Result := dispatch^.SelectF64x4(mask, a, b)
  else
  begin
    for i := 0 to 3 do
    begin
      la64 := PQWord(@a.d[i])^;
      lb64 := PQWord(@b.d[i])^;
      lr64 := (la64 and mask.u[i]) or (lb64 and (not mask.u[i]));
      PQWord(@Result.d[i])^ := lr64;
    end;
  end;
end;

// Mask Operations Implementation
function Mask2All(mask: TMask2): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask2All(mask);
end;

function Mask2Any(mask: TMask2): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask2Any(mask);
end;

function Mask2None(mask: TMask2): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask2None(mask);
end;

function Mask2PopCount(mask: TMask2): Integer;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask2PopCount(mask);
end;

function Mask2FirstSet(mask: TMask2): Integer;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask2FirstSet(mask);
end;

function Mask4All(mask: TMask4): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask4All(mask);
end;

function Mask4Any(mask: TMask4): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask4Any(mask);
end;

function Mask4None(mask: TMask4): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask4None(mask);
end;

function Mask4PopCount(mask: TMask4): Integer;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask4PopCount(mask);
end;

function Mask4FirstSet(mask: TMask4): Integer;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask4FirstSet(mask);
end;

function Mask8All(mask: TMask8): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask8All(mask);
end;

function Mask8Any(mask: TMask8): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask8Any(mask);
end;

function Mask8None(mask: TMask8): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask8None(mask);
end;

function Mask8PopCount(mask: TMask8): Integer;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask8PopCount(mask);
end;

function Mask8FirstSet(mask: TMask8): Integer;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask8FirstSet(mask);
end;

function Mask16All(mask: TMask16): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask16All(mask);
end;

function Mask16Any(mask: TMask16): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask16Any(mask);
end;

function Mask16None(mask: TMask16): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask16None(mask);
end;

function Mask16PopCount(mask: TMask16): Integer;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask16PopCount(mask);
end;

function Mask16FirstSet(mask: TMask16): Integer;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask16FirstSet(mask);
end;

// === I32x4 Operations Implementation ===
// I32x4 高级 API 实现

function VecI32x4Add(const a, b: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AddI32x4) then
    Result := dispatch^.AddI32x4(a, b)
  else
  begin
    Result.i[0] := a.i[0] + b.i[0];
    Result.i[1] := a.i[1] + b.i[1];
    Result.i[2] := a.i[2] + b.i[2];
    Result.i[3] := a.i[3] + b.i[3];
  end;
end;

function VecI32x4Sub(const a, b: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SubI32x4) then
    Result := dispatch^.SubI32x4(a, b)
  else
  begin
    Result.i[0] := a.i[0] - b.i[0];
    Result.i[1] := a.i[1] - b.i[1];
    Result.i[2] := a.i[2] - b.i[2];
    Result.i[3] := a.i[3] - b.i[3];
  end;
end;

// === Core Operator Overloads Implementation ===

operator + (const a, b: TVecF32x4): TVecF32x4;
begin
  Result := VecF32x4Add(a, b);
end;

operator - (const a, b: TVecF32x4): TVecF32x4;
begin
  Result := VecF32x4Sub(a, b);
end;

operator * (const a, b: TVecF32x4): TVecF32x4;
begin
  Result := VecF32x4Mul(a, b);
end;

operator / (const a, b: TVecF32x4): TVecF32x4;
begin
  Result := VecF32x4Div(a, b);
end;

operator - (const a: TVecF32x4): TVecF32x4;
begin
  Result := VecF32x4Sub(VecF32x4Splat(0.0), a);
end;

operator * (const a: TVecF32x4; s: Single): TVecF32x4;
begin
  Result := VecF32x4Mul(a, VecF32x4Splat(s));
end;

operator * (s: Single; const a: TVecF32x4): TVecF32x4;
begin
  Result := VecF32x4Mul(VecF32x4Splat(s), a);
end;

operator / (const a: TVecF32x4; s: Single): TVecF32x4;
begin
  Result := VecF32x4Div(a, VecF32x4Splat(s));
end;

operator + (const a, b: TVecF64x2): TVecF64x2;
begin
  Result := VecF64x2Add(a, b);
end;

operator - (const a, b: TVecF64x2): TVecF64x2;
begin
  Result := VecF64x2Sub(a, b);
end;

operator * (const a, b: TVecF64x2): TVecF64x2;
begin
  Result := VecF64x2Mul(a, b);
end;

operator / (const a, b: TVecF64x2): TVecF64x2;
begin
  Result := VecF64x2Div(a, b);
end;

operator - (const a: TVecF64x2): TVecF64x2;
begin
  Result := VecF64x2Sub(VecF64x2Splat(0.0), a);
end;

{$PUSH}{$R-}{$Q-}
operator + (const a, b: TVecI32x4): TVecI32x4;
begin
  Result := VecI32x4Add(a, b);
end;

operator - (const a, b: TVecI32x4): TVecI32x4;
begin
  Result := VecI32x4Sub(a, b);
end;

operator * (const a, b: TVecI32x4): TVecI32x4;
begin
  Result := VecI32x4Mul(a, b);
end;

operator - (const a: TVecI32x4): TVecI32x4;
var zero: TVecI32x4;
begin
  zero.i[0] := 0; zero.i[1] := 0; zero.i[2] := 0; zero.i[3] := 0;
  Result := VecI32x4Sub(zero, a);
end;
{$POP}

{$PUSH}{$R-}{$Q-}
