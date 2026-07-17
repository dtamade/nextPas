// === F64x4 Operations Implementation ===
// F64x4 (256-bit, 4x Double) 高级 API 实现

function VecF64x4Add(const a, b: TVecF64x4): TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.AddF64x4) then
    Result := LDispatch^.CoreVectors.AddF64x4(a, b)
  else
    for LIndex := 0 to 3 do
      Result.d[LIndex] := a.d[LIndex] + b.d[LIndex];
end;

function VecF64x4Sub(const a, b: TVecF64x4): TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.SubF64x4) then
    Result := LDispatch^.CoreVectors.SubF64x4(a, b)
  else
    for LIndex := 0 to 3 do
      Result.d[LIndex] := a.d[LIndex] - b.d[LIndex];
end;

function VecF64x4Mul(const a, b: TVecF64x4): TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.MulF64x4) then
    Result := LDispatch^.CoreVectors.MulF64x4(a, b)
  else
    for LIndex := 0 to 3 do
      Result.d[LIndex] := a.d[LIndex] * b.d[LIndex];
end;

function VecF64x4Div(const a, b: TVecF64x4): TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.DivF64x4) then
    Result := LDispatch^.CoreVectors.DivF64x4(a, b)
  else
    for LIndex := 0 to 3 do
      Result.d[LIndex] := a.d[LIndex] / b.d[LIndex];
end;

function VecF64x4Rcp(const a: TVecF64x4): TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.RcpF64x4) then
    Result := LDispatch^.CoreVectors.RcpF64x4(a)
  else
    for LIndex := 0 to 3 do
      Result.d[LIndex] := 1.0 / a.d[LIndex];
end;

function VecF64x4CmpEq(const a, b: TVecF64x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpEqF64x4) then
    Result := dispatch^.CoreVectors.CmpEqF64x4(a, b)
  else
  begin
    Result := 0;
    if a.d[0] = b.d[0] then Result := Result or 1;
    if a.d[1] = b.d[1] then Result := Result or 2;
    if a.d[2] = b.d[2] then Result := Result or 4;
    if a.d[3] = b.d[3] then Result := Result or 8;
  end;
end;

function VecF64x4CmpLt(const a, b: TVecF64x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpLtF64x4) then
    Result := dispatch^.CoreVectors.CmpLtF64x4(a, b)
  else
  begin
    Result := 0;
    if a.d[0] < b.d[0] then Result := Result or 1;
    if a.d[1] < b.d[1] then Result := Result or 2;
    if a.d[2] < b.d[2] then Result := Result or 4;
    if a.d[3] < b.d[3] then Result := Result or 8;
  end;
end;

function VecF64x4CmpLe(const a, b: TVecF64x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpLeF64x4) then
    Result := dispatch^.CoreVectors.CmpLeF64x4(a, b)
  else
  begin
    Result := 0;
    if a.d[0] <= b.d[0] then Result := Result or 1;
    if a.d[1] <= b.d[1] then Result := Result or 2;
    if a.d[2] <= b.d[2] then Result := Result or 4;
    if a.d[3] <= b.d[3] then Result := Result or 8;
  end;
end;

function VecF64x4CmpGt(const a, b: TVecF64x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpGtF64x4) then
    Result := dispatch^.CoreVectors.CmpGtF64x4(a, b)
  else
  begin
    Result := 0;
    if a.d[0] > b.d[0] then Result := Result or 1;
    if a.d[1] > b.d[1] then Result := Result or 2;
    if a.d[2] > b.d[2] then Result := Result or 4;
    if a.d[3] > b.d[3] then Result := Result or 8;
  end;
end;

function VecF64x4CmpGe(const a, b: TVecF64x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpGeF64x4) then
    Result := dispatch^.CoreVectors.CmpGeF64x4(a, b)
  else
  begin
    Result := 0;
    if a.d[0] >= b.d[0] then Result := Result or 1;
    if a.d[1] >= b.d[1] then Result := Result or 2;
    if a.d[2] >= b.d[2] then Result := Result or 4;
    if a.d[3] >= b.d[3] then Result := Result or 8;
  end;
end;

function VecF64x4CmpNe(const a, b: TVecF64x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpNeF64x4) then
    Result := dispatch^.CoreVectors.CmpNeF64x4(a, b)
  else
  begin
    Result := 0;
    if a.d[0] <> b.d[0] then Result := Result or 1;
    if a.d[1] <> b.d[1] then Result := Result or 2;
    if a.d[2] <> b.d[2] then Result := Result or 4;
    if a.d[3] <> b.d[3] then Result := Result or 8;
  end;
end;

function VecF64x4Abs(const a: TVecF64x4): TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.AbsF64x4) then
    Result := LDispatch^.CoreVectors.AbsF64x4(a)
  else
    for LIndex := 0 to 3 do
      Result.d[LIndex] := Abs(a.d[LIndex]);
end;

function VecF64x4Sqrt(const a: TVecF64x4): TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.SqrtF64x4) then
    Result := LDispatch^.CoreVectors.SqrtF64x4(a)
  else
    for LIndex := 0 to 3 do
      Result.d[LIndex] := Sqrt(a.d[LIndex]);
end;

function VecF64x4Min(const a, b: TVecF64x4): TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.MinF64x4) then
    Result := LDispatch^.CoreVectors.MinF64x4(a, b)
  else
    for LIndex := 0 to 3 do
      if a.d[LIndex] < b.d[LIndex] then
        Result.d[LIndex] := a.d[LIndex]
      else
        Result.d[LIndex] := b.d[LIndex];
end;

function VecF64x4Max(const a, b: TVecF64x4): TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.MaxF64x4) then
    Result := LDispatch^.CoreVectors.MaxF64x4(a, b)
  else
    for LIndex := 0 to 3 do
      if a.d[LIndex] > b.d[LIndex] then
        Result.d[LIndex] := a.d[LIndex]
      else
        Result.d[LIndex] := b.d[LIndex];
end;

function VecF64x4ReduceAdd(const a: TVecF64x4): Double;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.ReduceAddF64x4) then
    Result := LDispatch^.CoreVectors.ReduceAddF64x4(a)
  else
    Result := a.d[0] + a.d[1] + a.d[2] + a.d[3];
end;

function VecF64x4ReduceMin(const a: TVecF64x4): Double;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.ReduceMinF64x4) then
    Result := LDispatch^.CoreVectors.ReduceMinF64x4(a)
  else
  begin
    Result := a.d[0];
    for LIndex := 1 to 3 do
      if a.d[LIndex] < Result then
        Result := a.d[LIndex];
  end;
end;

function VecF64x4ReduceMax(const a: TVecF64x4): Double;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.ReduceMaxF64x4) then
    Result := LDispatch^.CoreVectors.ReduceMaxF64x4(a)
  else
  begin
    Result := a.d[0];
    for LIndex := 1 to 3 do
      if a.d[LIndex] > Result then
        Result := a.d[LIndex];
  end;
end;

function VecF64x4ReduceMul(const a: TVecF64x4): Double;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.ReduceMulF64x4) then
    Result := LDispatch^.CoreVectors.ReduceMulF64x4(a)
  else
    Result := a.d[0] * a.d[1] * a.d[2] * a.d[3];
end;

// F64x4 extended math

function VecF64x4Fma(const a, b, c: TVecF64x4): TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.FmaF64x4) then
    Result := LDispatch^.CoreVectors.FmaF64x4(a, b, c)
  else
    for LIndex := 0 to 3 do
      Result.d[LIndex] := a.d[LIndex] * b.d[LIndex] + c.d[LIndex];
end;

function VecF64x4Floor(const a: TVecF64x4): TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
  v: Double;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.FloorF64x4) then
    Result := LDispatch^.CoreVectors.FloorF64x4(a)
  else
    for LIndex := 0 to 3 do
    begin
      v := Int(a.d[LIndex]);
      if (a.d[LIndex] < v) then v := v - 1.0;
      Result.d[LIndex] := v;
    end;
end;

function VecF64x4Ceil(const a: TVecF64x4): TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
  v: Double;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.CeilF64x4) then
    Result := LDispatch^.CoreVectors.CeilF64x4(a)
  else
    for LIndex := 0 to 3 do
    begin
      v := Int(a.d[LIndex]);
      if (a.d[LIndex] > v) then v := v + 1.0;
      Result.d[LIndex] := v;
    end;
end;

function VecF64x4Round(const a: TVecF64x4): TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.RoundF64x4) then
    Result := LDispatch^.CoreVectors.RoundF64x4(a)
  else
    for LIndex := 0 to 3 do
      Result.d[LIndex] := Round(a.d[LIndex]);
end;

function VecF64x4Trunc(const a: TVecF64x4): TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.TruncF64x4) then
    Result := LDispatch^.CoreVectors.TruncF64x4(a)
  else
    for LIndex := 0 to 3 do
      Result.d[LIndex] := Int(a.d[LIndex]);
end;

function VecF64x4Clamp(const a, minVal, maxVal: TVecF64x4): TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
  v: Double;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.ClampF64x4) then
    Result := LDispatch^.CoreVectors.ClampF64x4(a, minVal, maxVal)
  else
    for LIndex := 0 to 3 do
    begin
      v := a.d[LIndex];
      if v < minVal.d[LIndex] then v := minVal.d[LIndex];
      if v > maxVal.d[LIndex] then v := maxVal.d[LIndex];
      Result.d[LIndex] := v;
    end;
end;

// F64x4 memory/utility

function VecF64x4Load(p: PDouble): TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.LoadF64x4) then
    Result := LDispatch^.CoreVectors.LoadF64x4(p)
  else
    Move(p^, Result, SizeOf(TVecF64x4));
end;

procedure VecF64x4Store(p: PDouble; const a: TVecF64x4);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.StoreF64x4) then
    LDispatch^.CoreVectors.StoreF64x4(p, a)
  else
    Move(a, p^, SizeOf(TVecF64x4));
end;

function VecF64x4Splat(value: Double): TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.SplatF64x4) then
    Result := LDispatch^.CoreVectors.SplatF64x4(value)
  else
    for LIndex := 0 to 3 do Result.d[LIndex] := value;
end;

function VecF64x4Zero: TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.ZeroF64x4) then
    Result := LDispatch^.CoreVectors.ZeroF64x4()
  else
    FillChar(Result, SizeOf(Result), 0);
end;

