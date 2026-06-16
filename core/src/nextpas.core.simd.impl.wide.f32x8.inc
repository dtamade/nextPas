// === F32x8 Operations Implementation ===
// F32x8 (256-bit) 高级 API 实现

function VecF32x8Add(const a, b: TVecF32x8): TVecF32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AddF32x8) then
    Result := dispatch^.AddF32x8(a, b)
  else
  begin
    for i := 0 to 7 do
      Result.f[i] := a.f[i] + b.f[i];
  end;
end;

function VecF32x8Sub(const a, b: TVecF32x8): TVecF32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SubF32x8) then
    Result := dispatch^.SubF32x8(a, b)
  else
  begin
    for i := 0 to 7 do
      Result.f[i] := a.f[i] - b.f[i];
  end;
end;

function VecF32x8Mul(const a, b: TVecF32x8): TVecF32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MulF32x8) then
    Result := dispatch^.MulF32x8(a, b)
  else
  begin
    for i := 0 to 7 do
      Result.f[i] := a.f[i] * b.f[i];
  end;
end;

function VecF32x8Div(const a, b: TVecF32x8): TVecF32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.DivF32x8) then
    Result := dispatch^.DivF32x8(a, b)
  else
  begin
    for i := 0 to 7 do
      Result.f[i] := a.f[i] / b.f[i];
  end;
end;

function VecF32x8CmpEq(const a, b: TVecF32x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpEqF32x8) then
    Result := dispatch^.CmpEqF32x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.f[i] = b.f[i] then Result := Result or (1 shl i);
  end;
end;

function VecF32x8CmpLt(const a, b: TVecF32x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLtF32x8) then
    Result := dispatch^.CmpLtF32x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.f[i] < b.f[i] then Result := Result or (1 shl i);
  end;
end;

function VecF32x8CmpLe(const a, b: TVecF32x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLeF32x8) then
    Result := dispatch^.CmpLeF32x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.f[i] <= b.f[i] then Result := Result or (1 shl i);
  end;
end;

function VecF32x8CmpGt(const a, b: TVecF32x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGtF32x8) then
    Result := dispatch^.CmpGtF32x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.f[i] > b.f[i] then Result := Result or (1 shl i);
  end;
end;

function VecF32x8CmpGe(const a, b: TVecF32x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGeF32x8) then
    Result := dispatch^.CmpGeF32x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.f[i] >= b.f[i] then Result := Result or (1 shl i);
  end;
end;

function VecF32x8CmpNe(const a, b: TVecF32x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpNeF32x8) then
    Result := dispatch^.CmpNeF32x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.f[i] <> b.f[i] then Result := Result or (1 shl i);
  end;
end;

function VecF32x8Abs(const a: TVecF32x8): TVecF32x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AbsF32x8) then
    Result := LDispatch^.AbsF32x8(a)
  else
    for LIndex := 0 to 7 do
      Result.f[LIndex] := Abs(a.f[LIndex]);
end;

function VecF32x8Sqrt(const a: TVecF32x8): TVecF32x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.SqrtF32x8) then
    Result := LDispatch^.SqrtF32x8(a)
  else
    for LIndex := 0 to 7 do
      Result.f[LIndex] := Sqrt(a.f[LIndex]);
end;

function VecF32x8Min(const a, b: TVecF32x8): TVecF32x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.MinF32x8) then
    Result := LDispatch^.MinF32x8(a, b)
  else
    for LIndex := 0 to 7 do
      if a.f[LIndex] < b.f[LIndex] then
        Result.f[LIndex] := a.f[LIndex]
      else
        Result.f[LIndex] := b.f[LIndex];
end;

function VecF32x8Max(const a, b: TVecF32x8): TVecF32x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.MaxF32x8) then
    Result := LDispatch^.MaxF32x8(a, b)
  else
    for LIndex := 0 to 7 do
      if a.f[LIndex] > b.f[LIndex] then
        Result.f[LIndex] := a.f[LIndex]
      else
        Result.f[LIndex] := b.f[LIndex];
end;

function VecF32x8ReduceAdd(const a: TVecF32x8): Single;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ReduceAddF32x8) then
    Result := LDispatch^.ReduceAddF32x8(a)
  else
  begin
    Result := a.f[0];
    for LIndex := 1 to 7 do
      Result := Result + a.f[LIndex];
  end;
end;

function VecF32x8ReduceMin(const a: TVecF32x8): Single;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ReduceMinF32x8) then
    Result := LDispatch^.ReduceMinF32x8(a)
  else
  begin
    Result := a.f[0];
    for LIndex := 1 to 7 do
      if a.f[LIndex] < Result then
        Result := a.f[LIndex];
  end;
end;

function VecF32x8ReduceMax(const a: TVecF32x8): Single;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ReduceMaxF32x8) then
    Result := LDispatch^.ReduceMaxF32x8(a)
  else
  begin
    Result := a.f[0];
    for LIndex := 1 to 7 do
      if a.f[LIndex] > Result then
        Result := a.f[LIndex];
  end;
end;

function VecF32x8ReduceMul(const a: TVecF32x8): Single;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ReduceMulF32x8) then
    Result := LDispatch^.ReduceMulF32x8(a)
  else
  begin
    Result := a.f[0];
    for LIndex := 1 to 7 do
      Result := Result * a.f[LIndex];
  end;
end;

function VecF32x8Load(p: PSingle): TVecF32x8;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.LoadF32x8) then
    Result := dispatch^.LoadF32x8(p)
  else
    Move(p^, Result, SizeOf(TVecF32x8));
end;

procedure VecF32x8Store(p: PSingle; const a: TVecF32x8);
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.StoreF32x8) then
    dispatch^.StoreF32x8(p, a)
  else
    Move(a, p^, SizeOf(TVecF32x8));
end;

function VecF32x8Splat(value: Single): TVecF32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SplatF32x8) then
    Result := dispatch^.SplatF32x8(value)
  else
    for i := 0 to 7 do Result.f[i] := value;
end;

function VecF32x8Zero: TVecF32x8;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ZeroF32x8) then
    Result := dispatch^.ZeroF32x8()
  else
    FillChar(Result, SizeOf(Result), 0);
end;

// F32x8 extended math

function VecF32x8Fma(const a, b, c: TVecF32x8): TVecF32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.FmaF32x8) then
    Result := dispatch^.FmaF32x8(a, b, c)
  else
    for i := 0 to 7 do
      Result.f[i] := a.f[i] * b.f[i] + c.f[i];
end;

function VecF32x8Floor(const a: TVecF32x8): TVecF32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
    v: Single;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.FloorF32x8) then
    Result := dispatch^.FloorF32x8(a)
  else
    for i := 0 to 7 do
    begin
      v := Int(a.f[i]);
      if (a.f[i] < v) then v := v - 1.0;
      Result.f[i] := v;
    end;
end;

function VecF32x8Ceil(const a: TVecF32x8): TVecF32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
    v: Single;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CeilF32x8) then
    Result := dispatch^.CeilF32x8(a)
  else
    for i := 0 to 7 do
    begin
      v := Int(a.f[i]);
      if (a.f[i] > v) then v := v + 1.0;
      Result.f[i] := v;
    end;
end;

function VecF32x8Round(const a: TVecF32x8): TVecF32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.RoundF32x8) then
    Result := dispatch^.RoundF32x8(a)
  else
    for i := 0 to 7 do
      Result.f[i] := Round(a.f[i]);
end;

function VecF32x8Trunc(const a: TVecF32x8): TVecF32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.TruncF32x8) then
    Result := dispatch^.TruncF32x8(a)
  else
    for i := 0 to 7 do
      Result.f[i] := Int(a.f[i]);
end;

function VecF32x8Clamp(const a, minVal, maxVal: TVecF32x8): TVecF32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
    v: Single;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ClampF32x8) then
    Result := dispatch^.ClampF32x8(a, minVal, maxVal)
  else
    for i := 0 to 7 do
    begin
      v := a.f[i];
      if v < minVal.f[i] then v := minVal.f[i];
      if v > maxVal.f[i] then v := maxVal.f[i];
      Result.f[i] := v;
    end;
end;

