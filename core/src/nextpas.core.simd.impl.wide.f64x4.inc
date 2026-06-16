// === F64x4 Operations Implementation ===
// F64x4 (256-bit, 4x Double) 高级 API 实现

function VecF64x4Add(const a, b: TVecF64x4): TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AddF64x4) then
    Result := LDispatch^.AddF64x4(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.SubF64x4) then
    Result := LDispatch^.SubF64x4(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.MulF64x4) then
    Result := LDispatch^.MulF64x4(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.DivF64x4) then
    Result := LDispatch^.DivF64x4(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.RcpF64x4) then
    Result := LDispatch^.RcpF64x4(a)
  else
    for LIndex := 0 to 3 do
      Result.d[LIndex] := 1.0 / a.d[LIndex];
end;

function VecF64x4CmpEq(const a, b: TVecF64x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpEqF64x4) then
    Result := dispatch^.CmpEqF64x4(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CmpLtF64x4) then
    Result := dispatch^.CmpLtF64x4(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CmpLeF64x4) then
    Result := dispatch^.CmpLeF64x4(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CmpGtF64x4) then
    Result := dispatch^.CmpGtF64x4(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CmpGeF64x4) then
    Result := dispatch^.CmpGeF64x4(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CmpNeF64x4) then
    Result := dispatch^.CmpNeF64x4(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.AbsF64x4) then
    Result := LDispatch^.AbsF64x4(a)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.SqrtF64x4) then
    Result := LDispatch^.SqrtF64x4(a)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.MinF64x4) then
    Result := LDispatch^.MinF64x4(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.MaxF64x4) then
    Result := LDispatch^.MaxF64x4(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.ReduceAddF64x4) then
    Result := LDispatch^.ReduceAddF64x4(a)
  else
    Result := a.d[0] + a.d[1] + a.d[2] + a.d[3];
end;

function VecF64x4ReduceMin(const a: TVecF64x4): Double;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ReduceMinF64x4) then
    Result := LDispatch^.ReduceMinF64x4(a)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.ReduceMaxF64x4) then
    Result := LDispatch^.ReduceMaxF64x4(a)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.ReduceMulF64x4) then
    Result := LDispatch^.ReduceMulF64x4(a)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.FmaF64x4) then
    Result := LDispatch^.FmaF64x4(a, b, c)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.FloorF64x4) then
    Result := LDispatch^.FloorF64x4(a)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CeilF64x4) then
    Result := LDispatch^.CeilF64x4(a)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.RoundF64x4) then
    Result := LDispatch^.RoundF64x4(a)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.TruncF64x4) then
    Result := LDispatch^.TruncF64x4(a)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.ClampF64x4) then
    Result := LDispatch^.ClampF64x4(a, minVal, maxVal)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.LoadF64x4) then
    Result := LDispatch^.LoadF64x4(p)
  else
    Move(p^, Result, SizeOf(TVecF64x4));
end;

procedure VecF64x4Store(p: PDouble; const a: TVecF64x4);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.StoreF64x4) then
    LDispatch^.StoreF64x4(p, a)
  else
    Move(a, p^, SizeOf(TVecF64x4));
end;

function VecF64x4Splat(value: Double): TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.SplatF64x4) then
    Result := LDispatch^.SplatF64x4(value)
  else
    for LIndex := 0 to 3 do Result.d[LIndex] := value;
end;

function VecF64x4Zero: TVecF64x4;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ZeroF64x4) then
    Result := LDispatch^.ZeroF64x4()
  else
    FillChar(Result, SizeOf(Result), 0);
end;

