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

// === I32x8 Operations Implementation ===
// I32x8 高级 API 实现

function VecI32x8Add(const a, b: TVecI32x8): TVecI32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AddI32x8) then
    Result := dispatch^.AddI32x8(a, b)
  else
  begin
    for i := 0 to 7 do
      Result.i[i] := a.i[i] + b.i[i];
  end;
end;

function VecI32x8Sub(const a, b: TVecI32x8): TVecI32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SubI32x8) then
    Result := dispatch^.SubI32x8(a, b)
  else
  begin
    for i := 0 to 7 do
      Result.i[i] := a.i[i] - b.i[i];
  end;
end;

function VecI32x8Mul(const a, b: TVecI32x8): TVecI32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MulI32x8) then
    Result := dispatch^.MulI32x8(a, b)
  else
  begin
    for i := 0 to 7 do
      Result.i[i] := a.i[i] * b.i[i];
  end;
end;

function VecI32x8And(const a, b: TVecI32x8): TVecI32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndI32x8) then
    Result := dispatch^.AndI32x8(a, b)
  else
  begin
    for i := 0 to 7 do
      Result.i[i] := a.i[i] and b.i[i];
  end;
end;

function VecI32x8Or(const a, b: TVecI32x8): TVecI32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.OrI32x8) then
    Result := dispatch^.OrI32x8(a, b)
  else
  begin
    for i := 0 to 7 do
      Result.i[i] := a.i[i] or b.i[i];
  end;
end;

function VecI32x8Xor(const a, b: TVecI32x8): TVecI32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.XorI32x8) then
    Result := dispatch^.XorI32x8(a, b)
  else
  begin
    for i := 0 to 7 do
      Result.i[i] := a.i[i] xor b.i[i];
  end;
end;

function VecI32x8Not(const a: TVecI32x8): TVecI32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.NotI32x8) then
    Result := dispatch^.NotI32x8(a)
  else
  begin
    for i := 0 to 7 do
      Result.i[i] := not a.i[i];
  end;
end;

function VecI32x8AndNot(const a, b: TVecI32x8): TVecI32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndNotI32x8) then
    Result := dispatch^.AndNotI32x8(a, b)
  else
  begin
    for i := 0 to 7 do
      Result.i[i] := (not a.i[i]) and b.i[i];
  end;
end;

function VecI32x8ShiftLeft(const a: TVecI32x8; count: Integer): TVecI32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
    LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 32 then
  begin
    for i := 0 to 7 do
      Result.i[i] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftLeftI32x8) then
    Result := dispatch^.ShiftLeftI32x8(a, LCount)
  else
  begin
    for i := 0 to 7 do
      Result.i[i] := a.i[i] shl LCount;
  end;
end;

function VecI32x8ShiftRight(const a: TVecI32x8; count: Integer): TVecI32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
    LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 32 then
  begin
    for i := 0 to 7 do
      Result.i[i] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftRightI32x8) then
    Result := dispatch^.ShiftRightI32x8(a, LCount)
  else
  begin
    for i := 0 to 7 do
      Result.i[i] := Int32(UInt32(a.i[i]) shr LCount);
  end;
end;

function VecI32x8ShiftRightArith(const a: TVecI32x8; count: Integer): TVecI32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
    LCount: Integer;
begin
  LCount := count;
  if LCount < 0 then
  begin
    Result := a;
    Exit;
  end;

  if LCount >= 32 then
  begin
    for i := 0 to 7 do
      if a.i[i] < 0 then
        Result.i[i] := -1
      else
        Result.i[i] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftRightArithI32x8) then
    Result := dispatch^.ShiftRightArithI32x8(a, LCount)
  else
  begin
    for i := 0 to 7 do
      Result.i[i] := SarLongint(a.i[i], LCount);
  end;
end;

function VecI32x8CmpEq(const a, b: TVecI32x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpEqI32x8) then
    Result := dispatch^.CmpEqI32x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.i[i] = b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI32x8CmpLt(const a, b: TVecI32x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLtI32x8) then
    Result := dispatch^.CmpLtI32x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.i[i] < b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI32x8CmpGt(const a, b: TVecI32x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGtI32x8) then
    Result := dispatch^.CmpGtI32x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.i[i] > b.i[i] then Result := Result or (1 shl i);
  end;
end;

// 添加 I32x8 缺失比较函数
function VecI32x8CmpLe(const a, b: TVecI32x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLeI32x8) then
    Result := dispatch^.CmpLeI32x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.i[i] <= b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI32x8CmpGe(const a, b: TVecI32x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGeI32x8) then
    Result := dispatch^.CmpGeI32x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.i[i] >= b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI32x8CmpNe(const a, b: TVecI32x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpNeI32x8) then
    Result := dispatch^.CmpNeI32x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.i[i] <> b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI32x8Min(const a, b: TVecI32x8): TVecI32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MinI32x8) then
    Result := dispatch^.MinI32x8(a, b)
  else
  begin
    for i := 0 to 7 do
      if a.i[i] < b.i[i] then
        Result.i[i] := a.i[i]
      else
        Result.i[i] := b.i[i];
  end;
end;

function VecI32x8Max(const a, b: TVecI32x8): TVecI32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MaxI32x8) then
    Result := dispatch^.MaxI32x8(a, b)
  else
  begin
    for i := 0 to 7 do
      if a.i[i] > b.i[i] then
        Result.i[i] := a.i[i]
      else
        Result.i[i] := b.i[i];
  end;
end;

// === U32x8 Operations Implementation ===
// U32x8 (256-bit Unsigned) 高级 API 实现

function VecU32x8Add(const a, b: TVecU32x8): TVecU32x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AddU32x8) then
    Result := LDispatch^.AddU32x8(a, b)
  else
    for LIndex := 0 to 7 do
      Result.u[LIndex] := a.u[LIndex] + b.u[LIndex];
end;

function VecU32x8Sub(const a, b: TVecU32x8): TVecU32x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.SubU32x8) then
    Result := LDispatch^.SubU32x8(a, b)
  else
    for LIndex := 0 to 7 do
      Result.u[LIndex] := a.u[LIndex] - b.u[LIndex];
end;

function VecU32x8Mul(const a, b: TVecU32x8): TVecU32x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.MulU32x8) then
    Result := LDispatch^.MulU32x8(a, b)
  else
    for LIndex := 0 to 7 do
      Result.u[LIndex] := a.u[LIndex] * b.u[LIndex];
end;

function VecU32x8And(const a, b: TVecU32x8): TVecU32x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AndU32x8) then
    Result := LDispatch^.AndU32x8(a, b)
  else
    for LIndex := 0 to 7 do
      Result.u[LIndex] := a.u[LIndex] and b.u[LIndex];
end;

function VecU32x8Or(const a, b: TVecU32x8): TVecU32x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.OrU32x8) then
    Result := LDispatch^.OrU32x8(a, b)
  else
    for LIndex := 0 to 7 do
      Result.u[LIndex] := a.u[LIndex] or b.u[LIndex];
end;

function VecU32x8Xor(const a, b: TVecU32x8): TVecU32x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.XorU32x8) then
    Result := LDispatch^.XorU32x8(a, b)
  else
    for LIndex := 0 to 7 do
      Result.u[LIndex] := a.u[LIndex] xor b.u[LIndex];
end;

function VecU32x8Not(const a: TVecU32x8): TVecU32x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.NotU32x8) then
    Result := LDispatch^.NotU32x8(a)
  else
    for LIndex := 0 to 7 do
      Result.u[LIndex] := not a.u[LIndex];
end;

function VecU32x8AndNot(const a, b: TVecU32x8): TVecU32x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AndNotU32x8) then
    Result := LDispatch^.AndNotU32x8(a, b)
  else
    for LIndex := 0 to 7 do
      Result.u[LIndex] := (not a.u[LIndex]) and b.u[LIndex];
end;

function VecU32x8ShiftLeft(const a: TVecU32x8; count: Integer): TVecU32x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
  LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 32 then
  begin
    for LIndex := 0 to 7 do
      Result.u[LIndex] := 0;
    Exit;
  end;

  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ShiftLeftU32x8) then
    Result := LDispatch^.ShiftLeftU32x8(a, LCount)
  else
    for LIndex := 0 to 7 do
      Result.u[LIndex] := a.u[LIndex] shl LCount;
end;

function VecU32x8ShiftRight(const a: TVecU32x8; count: Integer): TVecU32x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
  LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 32 then
  begin
    for LIndex := 0 to 7 do
      Result.u[LIndex] := 0;
    Exit;
  end;

  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ShiftRightU32x8) then
    Result := LDispatch^.ShiftRightU32x8(a, LCount)
  else
    for LIndex := 0 to 7 do
      Result.u[LIndex] := a.u[LIndex] shr LCount;
end;

function VecU32x8CmpEq(const a, b: TVecU32x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpEqU32x8) then
    Result := LDispatch^.CmpEqU32x8(a, b)
  else
  begin
    Result := 0;
    for LIndex := 0 to 7 do
      if a.u[LIndex] = b.u[LIndex] then
        Result := Result or (TMask8(1) shl LIndex);
  end;
end;

function VecU32x8CmpLt(const a, b: TVecU32x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpLtU32x8) then
    Result := LDispatch^.CmpLtU32x8(a, b)
  else
  begin
    Result := 0;
    for LIndex := 0 to 7 do
      if a.u[LIndex] < b.u[LIndex] then
        Result := Result or (TMask8(1) shl LIndex);
  end;
end;

function VecU32x8CmpGt(const a, b: TVecU32x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpGtU32x8) then
    Result := LDispatch^.CmpGtU32x8(a, b)
  else
  begin
    Result := 0;
    for LIndex := 0 to 7 do
      if a.u[LIndex] > b.u[LIndex] then
        Result := Result or (TMask8(1) shl LIndex);
  end;
end;

function VecU32x8CmpLe(const a, b: TVecU32x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpLeU32x8) then
    Result := LDispatch^.CmpLeU32x8(a, b)
  else
  begin
    Result := 0;
    for LIndex := 0 to 7 do
      if a.u[LIndex] <= b.u[LIndex] then
        Result := Result or (TMask8(1) shl LIndex);
  end;
end;

function VecU32x8CmpGe(const a, b: TVecU32x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpGeU32x8) then
    Result := LDispatch^.CmpGeU32x8(a, b)
  else
  begin
    Result := 0;
    for LIndex := 0 to 7 do
      if a.u[LIndex] >= b.u[LIndex] then
        Result := Result or (TMask8(1) shl LIndex);
  end;
end;

function VecU32x8CmpNe(const a, b: TVecU32x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpNeU32x8) then
    Result := LDispatch^.CmpNeU32x8(a, b)
  else
  begin
    Result := 0;
    for LIndex := 0 to 7 do
      if a.u[LIndex] <> b.u[LIndex] then
        Result := Result or (TMask8(1) shl LIndex);
  end;
end;

function VecU32x8Min(const a, b: TVecU32x8): TVecU32x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.MinU32x8) then
    Result := LDispatch^.MinU32x8(a, b)
  else
    for LIndex := 0 to 7 do
      if a.u[LIndex] < b.u[LIndex] then
        Result.u[LIndex] := a.u[LIndex]
      else
        Result.u[LIndex] := b.u[LIndex];
end;

function VecU32x8Max(const a, b: TVecU32x8): TVecU32x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.MaxU32x8) then
    Result := LDispatch^.MaxU32x8(a, b)
  else
    for LIndex := 0 to 7 do
      if a.u[LIndex] > b.u[LIndex] then
        Result.u[LIndex] := a.u[LIndex]
      else
        Result.u[LIndex] := b.u[LIndex];
end;

// === I64x4 Operations Implementation ===
// I64x4 (256-bit, 4x64-bit signed) 高级 API 实现
// 使用 dispatch table 以获得 AVX2 加速

function VecI64x4Add(const a, b: TVecI64x4): TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AddI64x4) then
    Result := dispatch^.AddI64x4(a, b)
  else
    for i := 0 to 3 do
      Result.i[i] := a.i[i] + b.i[i];
end;

function VecI64x4Sub(const a, b: TVecI64x4): TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SubI64x4) then
    Result := dispatch^.SubI64x4(a, b)
  else
    for i := 0 to 3 do
      Result.i[i] := a.i[i] - b.i[i];
end;

function VecI64x4And(const a, b: TVecI64x4): TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndI64x4) then
    Result := dispatch^.AndI64x4(a, b)
  else
    for i := 0 to 3 do
      Result.i[i] := a.i[i] and b.i[i];
end;

function VecI64x4Or(const a, b: TVecI64x4): TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.OrI64x4) then
    Result := dispatch^.OrI64x4(a, b)
  else
    for i := 0 to 3 do
      Result.i[i] := a.i[i] or b.i[i];
end;

function VecI64x4Xor(const a, b: TVecI64x4): TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.XorI64x4) then
    Result := dispatch^.XorI64x4(a, b)
  else
    for i := 0 to 3 do
      Result.i[i] := a.i[i] xor b.i[i];
end;

function VecI64x4Not(const a: TVecI64x4): TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.NotI64x4) then
    Result := dispatch^.NotI64x4(a)
  else
    for i := 0 to 3 do
      Result.i[i] := not a.i[i];
end;

function VecI64x4AndNot(const a, b: TVecI64x4): TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndNotI64x4) then
    Result := dispatch^.AndNotI64x4(a, b)
  else
    for i := 0 to 3 do
      Result.i[i] := (not a.i[i]) and b.i[i];
end;

function VecI64x4ShiftLeft(const a: TVecI64x4; count: Integer): TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
    LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 64 then
  begin
    for i := 0 to 3 do
      Result.i[i] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftLeftI64x4) then
    Result := dispatch^.ShiftLeftI64x4(a, LCount)
  else
    for i := 0 to 3 do
      Result.i[i] := a.i[i] shl LCount;
end;

function VecI64x4ShiftRight(const a: TVecI64x4; count: Integer): TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
    LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 64 then
  begin
    for i := 0 to 3 do
      Result.i[i] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftRightI64x4) then
    Result := dispatch^.ShiftRightI64x4(a, LCount)
  else
    for i := 0 to 3 do
      Result.i[i] := Int64(UInt64(a.i[i]) shr LCount);  // logical shift
end;

function VecI64x4ShiftRightArith(const a: TVecI64x4; count: Integer): TVecI64x4;
var
  dispatch: PSimdDispatchTable;
  i: Integer;
  LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 64 then
  begin
    for i := 0 to 3 do
      if a.i[i] < 0 then Result.i[i] := -1 else Result.i[i] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftRightArithI64x4) then
    Result := dispatch^.ShiftRightArithI64x4(a, LCount)
  else
    for i := 0 to 3 do
      Result.i[i] := SarInt64(a.i[i], LCount);
end;

function VecI64x4CmpEq(const a, b: TVecI64x4): TMask4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpEqI64x4) then
    Result := dispatch^.CmpEqI64x4(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 3 do
      if a.i[i] = b.i[i] then
        Result := Result or (1 shl i);
  end;
end;

function VecI64x4CmpLt(const a, b: TVecI64x4): TMask4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLtI64x4) then
    Result := dispatch^.CmpLtI64x4(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 3 do
      if a.i[i] < b.i[i] then
        Result := Result or (1 shl i);
  end;
end;

function VecI64x4CmpGt(const a, b: TVecI64x4): TMask4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGtI64x4) then
    Result := dispatch^.CmpGtI64x4(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 3 do
      if a.i[i] > b.i[i] then
        Result := Result or (1 shl i);
  end;
end;

function VecI64x4CmpLe(const a, b: TVecI64x4): TMask4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLeI64x4) then
    Result := dispatch^.CmpLeI64x4(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 3 do
      if a.i[i] <= b.i[i] then
        Result := Result or (1 shl i);
  end;
end;

function VecI64x4CmpGe(const a, b: TVecI64x4): TMask4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGeI64x4) then
    Result := dispatch^.CmpGeI64x4(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 3 do
      if a.i[i] >= b.i[i] then
        Result := Result or (1 shl i);
  end;
end;

function VecI64x4CmpNe(const a, b: TVecI64x4): TMask4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpNeI64x4) then
    Result := dispatch^.CmpNeI64x4(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 3 do
      if a.i[i] <> b.i[i] then
        Result := Result or (1 shl i);
  end;
end;

function VecI64x4Load(p: PInt64): TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.LoadI64x4) then
    Result := dispatch^.LoadI64x4(p)
  else
    for i := 0 to 3 do
      Result.i[i] := (p + i)^;
end;

procedure VecI64x4Store(p: PInt64; const a: TVecI64x4);
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.StoreI64x4) then
    dispatch^.StoreI64x4(p, a)
  else
    for i := 0 to 3 do
      (p + i)^ := a.i[i];
end;

function VecI64x4Splat(value: Int64): TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SplatI64x4) then
    Result := dispatch^.SplatI64x4(value)
  else
    for i := 0 to 3 do
      Result.i[i] := value;
end;

function VecI64x4Zero: TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ZeroI64x4) then
    Result := dispatch^.ZeroI64x4()
  else
    for i := 0 to 3 do
      Result.i[i] := 0;
end;

// === U64x4 Operations Implementation ===
// U64x4 (256-bit, 4x64-bit unsigned) 高级 API 实现
// 使用 dispatch table 以获得 AVX2 加速

function VecU64x4Add(const a, b: TVecU64x4): TVecU64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AddU64x4) then
    Result := dispatch^.AddU64x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] + b.u[i];
end;

function VecU64x4Sub(const a, b: TVecU64x4): TVecU64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SubU64x4) then
    Result := dispatch^.SubU64x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] - b.u[i];
end;

function VecU64x4And(const a, b: TVecU64x4): TVecU64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndU64x4) then
    Result := dispatch^.AndU64x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] and b.u[i];
end;

function VecU64x4Or(const a, b: TVecU64x4): TVecU64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.OrU64x4) then
    Result := dispatch^.OrU64x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] or b.u[i];
end;

function VecU64x4Xor(const a, b: TVecU64x4): TVecU64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.XorU64x4) then
    Result := dispatch^.XorU64x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] xor b.u[i];
end;

function VecU64x4Not(const a: TVecU64x4): TVecU64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.NotU64x4) then
    Result := dispatch^.NotU64x4(a)
  else
    for i := 0 to 3 do
      Result.u[i] := not a.u[i];
end;

function VecU64x4ShiftLeft(const a: TVecU64x4; count: Integer): TVecU64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
    LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 64 then
  begin
    for i := 0 to 3 do
      Result.u[i] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftLeftU64x4) then
    Result := dispatch^.ShiftLeftU64x4(a, LCount)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] shl LCount;
end;

function VecU64x4ShiftRight(const a: TVecU64x4; count: Integer): TVecU64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
    LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 64 then
  begin
    for i := 0 to 3 do
      Result.u[i] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftRightU64x4) then
    Result := dispatch^.ShiftRightU64x4(a, LCount)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] shr LCount;
end;

function VecU64x4CmpEq(const a, b: TVecU64x4): TMask4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpEqU64x4) then
    Result := dispatch^.CmpEqU64x4(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 3 do
      if a.u[i] = b.u[i] then
        Result := Result or (1 shl i);
  end;
end;

function VecU64x4CmpLt(const a, b: TVecU64x4): TMask4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLtU64x4) then
    Result := dispatch^.CmpLtU64x4(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 3 do
      if a.u[i] < b.u[i] then
        Result := Result or (1 shl i);
  end;
end;

function VecU64x4CmpGt(const a, b: TVecU64x4): TMask4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGtU64x4) then
    Result := dispatch^.CmpGtU64x4(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 3 do
      if a.u[i] > b.u[i] then
        Result := Result or (1 shl i);
  end;
end;

function VecU64x4CmpLe(const a, b: TVecU64x4): TMask4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLeU64x4) then
    Result := dispatch^.CmpLeU64x4(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 3 do
      if a.u[i] <= b.u[i] then
        Result := Result or (1 shl i);
  end;
end;

function VecU64x4CmpGe(const a, b: TVecU64x4): TMask4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGeU64x4) then
    Result := dispatch^.CmpGeU64x4(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 3 do
      if a.u[i] >= b.u[i] then
        Result := Result or (1 shl i);
  end;
end;

function VecU64x4CmpNe(const a, b: TVecU64x4): TMask4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpNeU64x4) then
    Result := dispatch^.CmpNeU64x4(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 3 do
      if a.u[i] <> b.u[i] then
        Result := Result or (1 shl i);
  end;
end;

function VecU64x4Splat(value: UInt64): TVecU64x4;
var i: Integer;
begin
  // U64x4 Splat 目前没有 dispatch 条目，使用直接实现
  for i := 0 to 3 do
    Result.u[i] := value;
end;

function VecU64x4Zero: TVecU64x4;
var i: Integer;
begin
  // U64x4 Zero 目前没有 dispatch 条目，使用直接实现
  for i := 0 to 3 do
    Result.u[i] := 0;
end;

// === I16x8 Operations Implementation ===
// I16x8 (128-bit, 8x16-bit signed) 高级 API 实现
// 修改为使用 dispatch table 以获得 SIMD 加速

function VecI16x8Add(const a, b: TVecI16x8): TVecI16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AddI16x8) then
    Result := dispatch^.AddI16x8(a, b)
  else
    for i := 0 to 7 do
      Result.i[i] := a.i[i] + b.i[i];
end;

function VecI16x8Sub(const a, b: TVecI16x8): TVecI16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SubI16x8) then
    Result := dispatch^.SubI16x8(a, b)
  else
    for i := 0 to 7 do
      Result.i[i] := a.i[i] - b.i[i];
end;

function VecI16x8Mul(const a, b: TVecI16x8): TVecI16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MulI16x8) then
    Result := dispatch^.MulI16x8(a, b)
  else
    for i := 0 to 7 do
      Result.i[i] := a.i[i] * b.i[i];
end;

function VecI16x8And(const a, b: TVecI16x8): TVecI16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndI16x8) then
    Result := dispatch^.AndI16x8(a, b)
  else
    for i := 0 to 7 do
      Result.i[i] := a.i[i] and b.i[i];
end;

function VecI16x8Or(const a, b: TVecI16x8): TVecI16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.OrI16x8) then
    Result := dispatch^.OrI16x8(a, b)
  else
    for i := 0 to 7 do
      Result.i[i] := a.i[i] or b.i[i];
end;

function VecI16x8Xor(const a, b: TVecI16x8): TVecI16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.XorI16x8) then
    Result := dispatch^.XorI16x8(a, b)
  else
    for i := 0 to 7 do
      Result.i[i] := a.i[i] xor b.i[i];
end;

function VecI16x8Not(const a: TVecI16x8): TVecI16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.NotI16x8) then
    Result := dispatch^.NotI16x8(a)
  else
    for i := 0 to 7 do
      Result.i[i] := not a.i[i];
end;

function VecI16x8AndNot(const a, b: TVecI16x8): TVecI16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndNotI16x8) then
    Result := dispatch^.AndNotI16x8(a, b)
  else
    for i := 0 to 7 do
      Result.i[i] := (not a.i[i]) and b.i[i];
end;

function VecI16x8ShiftLeft(const a: TVecI16x8; count: Integer): TVecI16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 16 then begin FillChar(Result, SizeOf(Result), 0); Exit; end;
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftLeftI16x8) then
    Result := dispatch^.ShiftLeftI16x8(a, count)
  else
    for i := 0 to 7 do
      Result.i[i] := a.i[i] shl count;
end;

function VecI16x8ShiftRight(const a: TVecI16x8; count: Integer): TVecI16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 16 then begin FillChar(Result, SizeOf(Result), 0); Exit; end;
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftRightI16x8) then
    Result := dispatch^.ShiftRightI16x8(a, count)
  else
    for i := 0 to 7 do
      Result.i[i] := Int16(UInt16(a.i[i]) shr count);
end;

function VecI16x8ShiftRightArith(const a: TVecI16x8; count: Integer): TVecI16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 16 then
  begin
    for i := 0 to 7 do
      if a.i[i] < 0 then Result.i[i] := -1 else Result.i[i] := 0;
    Exit;
  end;
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftRightArithI16x8) then
    Result := dispatch^.ShiftRightArithI16x8(a, count)
  else
    for i := 0 to 7 do
      Result.i[i] := SarSmallint(a.i[i], count);
end;

function VecI16x8CmpEq(const a, b: TVecI16x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpEqI16x8) then
    Result := dispatch^.CmpEqI16x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.i[i] = b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI16x8CmpLt(const a, b: TVecI16x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLtI16x8) then
    Result := dispatch^.CmpLtI16x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.i[i] < b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI16x8CmpGt(const a, b: TVecI16x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGtI16x8) then
    Result := dispatch^.CmpGtI16x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.i[i] > b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI16x8CmpLe(const a, b: TVecI16x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLeI16x8) then
    Result := dispatch^.CmpLeI16x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.i[i] <= b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI16x8CmpGe(const a, b: TVecI16x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGeI16x8) then
    Result := dispatch^.CmpGeI16x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.i[i] >= b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI16x8CmpNe(const a, b: TVecI16x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpNeI16x8) then
    Result := dispatch^.CmpNeI16x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.i[i] <> b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI16x8Min(const a, b: TVecI16x8): TVecI16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MinI16x8) then
    Result := dispatch^.MinI16x8(a, b)
  else
    for i := 0 to 7 do
      if a.i[i] < b.i[i] then
        Result.i[i] := a.i[i]
      else
        Result.i[i] := b.i[i];
end;

function VecI16x8Max(const a, b: TVecI16x8): TVecI16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MaxI16x8) then
    Result := dispatch^.MaxI16x8(a, b)
  else
    for i := 0 to 7 do
      if a.i[i] > b.i[i] then
        Result.i[i] := a.i[i]
      else
        Result.i[i] := b.i[i];
end;

// === I8x16 Operations Implementation ===
// I8x16 (128-bit, 16x8-bit signed) 高级 API 实现
// 修改为使用 dispatch table 以获得 SIMD 加速

function VecI8x16Add(const a, b: TVecI8x16): TVecI8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AddI8x16) then
    Result := dispatch^.AddI8x16(a, b)
  else
    for i := 0 to 15 do
      Result.i[i] := a.i[i] + b.i[i];
end;

function VecI8x16Sub(const a, b: TVecI8x16): TVecI8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SubI8x16) then
    Result := dispatch^.SubI8x16(a, b)
  else
    for i := 0 to 15 do
      Result.i[i] := a.i[i] - b.i[i];
end;

function VecI8x16And(const a, b: TVecI8x16): TVecI8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndI8x16) then
    Result := dispatch^.AndI8x16(a, b)
  else
    for i := 0 to 15 do
      Result.i[i] := a.i[i] and b.i[i];
end;

function VecI8x16Or(const a, b: TVecI8x16): TVecI8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.OrI8x16) then
    Result := dispatch^.OrI8x16(a, b)
  else
    for i := 0 to 15 do
      Result.i[i] := a.i[i] or b.i[i];
end;

function VecI8x16Xor(const a, b: TVecI8x16): TVecI8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.XorI8x16) then
    Result := dispatch^.XorI8x16(a, b)
  else
    for i := 0 to 15 do
      Result.i[i] := a.i[i] xor b.i[i];
end;

function VecI8x16Not(const a: TVecI8x16): TVecI8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.NotI8x16) then
    Result := dispatch^.NotI8x16(a)
  else
    for i := 0 to 15 do
      Result.i[i] := not a.i[i];
end;

function VecI8x16AndNot(const a, b: TVecI8x16): TVecI8x16;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AndNotI8x16) then
    Result := LDispatch^.AndNotI8x16(a, b)
  else if (LDispatch <> nil) and Assigned(LDispatch^.NotI8x16) and Assigned(LDispatch^.AndI8x16) then
  begin
    Result := LDispatch^.AndI8x16(LDispatch^.NotI8x16(a), b);
  end
  else
    for LIndex := 0 to 15 do
      Result.i[LIndex] := (not a.i[LIndex]) and b.i[LIndex];
end;

function VecI8x16CmpEq(const a, b: TVecI8x16): TMask16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpEqI8x16) then
    Result := dispatch^.CmpEqI8x16(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 15 do
      if a.i[i] = b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI8x16CmpLt(const a, b: TVecI8x16): TMask16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLtI8x16) then
    Result := dispatch^.CmpLtI8x16(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 15 do
      if a.i[i] < b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI8x16CmpGt(const a, b: TVecI8x16): TMask16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGtI8x16) then
    Result := dispatch^.CmpGtI8x16(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 15 do
      if a.i[i] > b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI8x16CmpLe(const a, b: TVecI8x16): TMask16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLeI8x16) then
    Result := dispatch^.CmpLeI8x16(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 15 do
      if a.i[i] <= b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI8x16CmpGe(const a, b: TVecI8x16): TMask16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGeI8x16) then
    Result := dispatch^.CmpGeI8x16(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 15 do
      if a.i[i] >= b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI8x16CmpNe(const a, b: TVecI8x16): TMask16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpNeI8x16) then
    Result := dispatch^.CmpNeI8x16(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 15 do
      if a.i[i] <> b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI8x16Min(const a, b: TVecI8x16): TVecI8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MinI8x16) then
    Result := dispatch^.MinI8x16(a, b)
  else
    for i := 0 to 15 do
      if a.i[i] < b.i[i] then
        Result.i[i] := a.i[i]
      else
        Result.i[i] := b.i[i];
end;

function VecI8x16Max(const a, b: TVecI8x16): TVecI8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MaxI8x16) then
    Result := dispatch^.MaxI8x16(a, b)
  else
    for i := 0 to 15 do
      if a.i[i] > b.i[i] then
        Result.i[i] := a.i[i]
      else
        Result.i[i] := b.i[i];
end;

// === U8x16 Operations Implementation ===
// U8x16 (128-bit, 16x UInt8) 高级 API 实现
// 修改为使用 dispatch table 以获得 SIMD 加速

function VecU8x16Add(const a, b: TVecU8x16): TVecU8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AddU8x16) then
    Result := dispatch^.AddU8x16(a, b)
  else
    for i := 0 to 15 do
      Result.u[i] := a.u[i] + b.u[i];
end;

function VecU8x16Sub(const a, b: TVecU8x16): TVecU8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SubU8x16) then
    Result := dispatch^.SubU8x16(a, b)
  else
    for i := 0 to 15 do
      Result.u[i] := a.u[i] - b.u[i];
end;

function VecU8x16And(const a, b: TVecU8x16): TVecU8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndU8x16) then
    Result := dispatch^.AndU8x16(a, b)
  else
    for i := 0 to 15 do
      Result.u[i] := a.u[i] and b.u[i];
end;

function VecU8x16Or(const a, b: TVecU8x16): TVecU8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.OrU8x16) then
    Result := dispatch^.OrU8x16(a, b)
  else
    for i := 0 to 15 do
      Result.u[i] := a.u[i] or b.u[i];
end;

function VecU8x16Xor(const a, b: TVecU8x16): TVecU8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.XorU8x16) then
    Result := dispatch^.XorU8x16(a, b)
  else
    for i := 0 to 15 do
      Result.u[i] := a.u[i] xor b.u[i];
end;

function VecU8x16Not(const a: TVecU8x16): TVecU8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.NotU8x16) then
    Result := dispatch^.NotU8x16(a)
  else
    for i := 0 to 15 do
      Result.u[i] := not a.u[i];
end;

function VecU8x16AndNot(const a, b: TVecU8x16): TVecU8x16;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AndNotU8x16) then
    Result := LDispatch^.AndNotU8x16(a, b)
  else if (LDispatch <> nil) and Assigned(LDispatch^.NotU8x16) and Assigned(LDispatch^.AndU8x16) then
  begin
    Result := LDispatch^.AndU8x16(LDispatch^.NotU8x16(a), b);
  end
  else
    for LIndex := 0 to 15 do
      Result.u[LIndex] := (not a.u[LIndex]) and b.u[LIndex];
end;

function VecU8x16CmpEq(const a, b: TVecU8x16): TMask16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpEqU8x16) then
    Result := dispatch^.CmpEqU8x16(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 15 do
      if a.u[i] = b.u[i] then Result := Result or (1 shl i);
  end;
end;

function VecU8x16CmpLt(const a, b: TVecU8x16): TMask16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLtU8x16) then
    Result := dispatch^.CmpLtU8x16(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 15 do
      if a.u[i] < b.u[i] then Result := Result or (1 shl i);  // 无符号比较
  end;
end;

function VecU8x16CmpGt(const a, b: TVecU8x16): TMask16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGtU8x16) then
    Result := dispatch^.CmpGtU8x16(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 15 do
      if a.u[i] > b.u[i] then Result := Result or (1 shl i);  // 无符号比较
  end;
end;

function VecU8x16CmpLe(const a, b: TVecU8x16): TMask16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLeU8x16) then
    Result := dispatch^.CmpLeU8x16(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 15 do
      if a.u[i] <= b.u[i] then Result := Result or (1 shl i);
  end;
end;

function VecU8x16CmpGe(const a, b: TVecU8x16): TMask16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGeU8x16) then
    Result := dispatch^.CmpGeU8x16(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 15 do
      if a.u[i] >= b.u[i] then Result := Result or (1 shl i);
  end;
end;

function VecU8x16CmpNe(const a, b: TVecU8x16): TMask16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpNeU8x16) then
    Result := dispatch^.CmpNeU8x16(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 15 do
      if a.u[i] <> b.u[i] then Result := Result or (1 shl i);
  end;
end;

function VecU8x16Min(const a, b: TVecU8x16): TVecU8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MinU8x16) then
    Result := dispatch^.MinU8x16(a, b)
  else
    for i := 0 to 15 do
      if a.u[i] < b.u[i] then
        Result.u[i] := a.u[i]
      else
        Result.u[i] := b.u[i];
end;

function VecU8x16Max(const a, b: TVecU8x16): TVecU8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MaxU8x16) then
    Result := dispatch^.MaxU8x16(a, b)
  else
    for i := 0 to 15 do
      if a.u[i] > b.u[i] then
        Result.u[i] := a.u[i]
      else
        Result.u[i] := b.u[i];
end;

// === U16x8 Operations Implementation ===
// U16x8 (128-bit, 8x UInt16) 高级 API 实现
// 修改为使用 dispatch table 以获得 SIMD 加速

function VecU16x8Add(const a, b: TVecU16x8): TVecU16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AddU16x8) then
    Result := dispatch^.AddU16x8(a, b)
  else
    for i := 0 to 7 do
      Result.u[i] := a.u[i] + b.u[i];
end;

function VecU16x8Sub(const a, b: TVecU16x8): TVecU16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SubU16x8) then
    Result := dispatch^.SubU16x8(a, b)
  else
    for i := 0 to 7 do
      Result.u[i] := a.u[i] - b.u[i];
end;

function VecU16x8Mul(const a, b: TVecU16x8): TVecU16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MulU16x8) then
    Result := dispatch^.MulU16x8(a, b)
  else
    for i := 0 to 7 do
      Result.u[i] := a.u[i] * b.u[i];
end;

function VecU16x8And(const a, b: TVecU16x8): TVecU16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndU16x8) then
    Result := dispatch^.AndU16x8(a, b)
  else
    for i := 0 to 7 do
      Result.u[i] := a.u[i] and b.u[i];
end;

function VecU16x8Or(const a, b: TVecU16x8): TVecU16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.OrU16x8) then
    Result := dispatch^.OrU16x8(a, b)
  else
    for i := 0 to 7 do
      Result.u[i] := a.u[i] or b.u[i];
end;

function VecU16x8Xor(const a, b: TVecU16x8): TVecU16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.XorU16x8) then
    Result := dispatch^.XorU16x8(a, b)
  else
    for i := 0 to 7 do
      Result.u[i] := a.u[i] xor b.u[i];
end;

function VecU16x8Not(const a: TVecU16x8): TVecU16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.NotU16x8) then
    Result := dispatch^.NotU16x8(a)
  else
    for i := 0 to 7 do
      Result.u[i] := not a.u[i];
end;

function VecU16x8AndNot(const a, b: TVecU16x8): TVecU16x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AndNotU16x8) then
    Result := LDispatch^.AndNotU16x8(a, b)
  else if (LDispatch <> nil) and Assigned(LDispatch^.NotU16x8) and Assigned(LDispatch^.AndU16x8) then
  begin
    Result := LDispatch^.AndU16x8(LDispatch^.NotU16x8(a), b);
  end
  else
    for LIndex := 0 to 7 do
      Result.u[LIndex] := (not a.u[LIndex]) and b.u[LIndex];
end;

function VecU16x8ShiftLeft(const a: TVecU16x8; count: Integer): TVecU16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 16 then begin FillChar(Result, SizeOf(Result), 0); Exit; end;
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftLeftU16x8) then
    Result := dispatch^.ShiftLeftU16x8(a, count)
  else
    for i := 0 to 7 do
      Result.u[i] := a.u[i] shl count;
end;

function VecU16x8ShiftRight(const a: TVecU16x8; count: Integer): TVecU16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 16 then begin FillChar(Result, SizeOf(Result), 0); Exit; end;
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftRightU16x8) then
    Result := dispatch^.ShiftRightU16x8(a, count)
  else
    for i := 0 to 7 do
      Result.u[i] := a.u[i] shr count;
end;

function VecU16x8CmpEq(const a, b: TVecU16x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpEqU16x8) then
    Result := dispatch^.CmpEqU16x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.u[i] = b.u[i] then Result := Result or (1 shl i);
  end;
end;

function VecU16x8CmpLt(const a, b: TVecU16x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLtU16x8) then
    Result := dispatch^.CmpLtU16x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.u[i] < b.u[i] then Result := Result or (1 shl i);  // 无符号比较
  end;
end;

function VecU16x8CmpGt(const a, b: TVecU16x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGtU16x8) then
    Result := dispatch^.CmpGtU16x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.u[i] > b.u[i] then Result := Result or (1 shl i);  // 无符号比较
  end;
end;

function VecU16x8CmpLe(const a, b: TVecU16x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLeU16x8) then
    Result := dispatch^.CmpLeU16x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.u[i] <= b.u[i] then Result := Result or (1 shl i);
  end;
end;

function VecU16x8CmpGe(const a, b: TVecU16x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGeU16x8) then
    Result := dispatch^.CmpGeU16x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.u[i] >= b.u[i] then Result := Result or (1 shl i);
  end;
end;

function VecU16x8CmpNe(const a, b: TVecU16x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpNeU16x8) then
    Result := dispatch^.CmpNeU16x8(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 7 do
      if a.u[i] <> b.u[i] then Result := Result or (1 shl i);
  end;
end;

function VecU16x8Min(const a, b: TVecU16x8): TVecU16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MinU16x8) then
    Result := dispatch^.MinU16x8(a, b)
  else
    for i := 0 to 7 do
      if a.u[i] < b.u[i] then
        Result.u[i] := a.u[i]
      else
        Result.u[i] := b.u[i];
end;

function VecU16x8Max(const a, b: TVecU16x8): TVecU16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MaxU16x8) then
    Result := dispatch^.MaxU16x8(a, b)
  else
    for i := 0 to 7 do
      if a.u[i] > b.u[i] then
        Result.u[i] := a.u[i]
      else
        Result.u[i] := b.u[i];
end;

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

// === F64x8 Operations Implementation ===
// F64x8 (512-bit, 8x Double) 高级 API 实现

function VecF64x8Add(const a, b: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.AddF64x8(a, b);
end;

function VecF64x8Sub(const a, b: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.SubF64x8(a, b);
end;

function VecF64x8Mul(const a, b: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.MulF64x8(a, b);
end;

function VecF64x8Div(const a, b: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.DivF64x8(a, b);
end;

function VecF64x8CmpEq(const a, b: TVecF64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpEqF64x8(a, b);
end;

function VecF64x8CmpLt(const a, b: TVecF64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpLtF64x8(a, b);
end;

function VecF64x8CmpLe(const a, b: TVecF64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpLeF64x8(a, b);
end;

function VecF64x8CmpGt(const a, b: TVecF64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpGtF64x8(a, b);
end;

function VecF64x8CmpGe(const a, b: TVecF64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpGeF64x8(a, b);
end;

function VecF64x8CmpNe(const a, b: TVecF64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpNeF64x8(a, b);
end;

function VecF64x8Abs(const a: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.AbsF64x8(a);
end;

function VecF64x8Sqrt(const a: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.SqrtF64x8(a);
end;

function VecF64x8Min(const a, b: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.MinF64x8(a, b);
end;

function VecF64x8Max(const a, b: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.MaxF64x8(a, b);
end;

function VecF64x8Clamp(const a, minVal, maxVal: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ClampF64x8(a, minVal, maxVal);
end;

function VecF64x8Fma(const a, b, c: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.FmaF64x8(a, b, c);
end;

function VecF64x8Floor(const a: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.FloorF64x8(a);
end;

function VecF64x8Ceil(const a: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CeilF64x8(a);
end;

function VecF64x8Round(const a: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.RoundF64x8(a);
end;

function VecF64x8Trunc(const a: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.TruncF64x8(a);
end;

function VecF64x8ReduceAdd(const a: TVecF64x8): Double;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceAddF64x8(a);
end;

function VecF64x8ReduceMin(const a: TVecF64x8): Double;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceMinF64x8(a);
end;

function VecF64x8ReduceMax(const a: TVecF64x8): Double;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceMaxF64x8(a);
end;

function VecF64x8ReduceMul(const a: TVecF64x8): Double;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceMulF64x8(a);
end;

function VecF64x8Select(const mask: TMask8; const a, b: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.SelectF64x8(mask, a, b);
end;

// === F32x16 Operations Implementation ===
// F32x16 (512-bit, 16x Single) 高级 API 实现

function VecF32x16Add(const a, b: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.AddF32x16(a, b);
end;

function VecF32x16Sub(const a, b: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.SubF32x16(a, b);
end;

function VecF32x16Mul(const a, b: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.MulF32x16(a, b);
end;

function VecF32x16Div(const a, b: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.DivF32x16(a, b);
end;

function VecF32x16CmpEq_Mask(const a, b: TVecF32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpEqF32x16(a, b);
end;

function VecF32x16CmpLt_Mask(const a, b: TVecF32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpLtF32x16(a, b);
end;

function VecF32x16CmpLe_Mask(const a, b: TVecF32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpLeF32x16(a, b);
end;

function VecF32x16CmpGt_Mask(const a, b: TVecF32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpGtF32x16(a, b);
end;

function VecF32x16CmpGe_Mask(const a, b: TVecF32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpGeF32x16(a, b);
end;

function VecF32x16CmpNe_Mask(const a, b: TVecF32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpNeF32x16(a, b);
end;

function VecF32x16Abs(const a: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.AbsF32x16(a);
end;

function VecF32x16Sqrt(const a: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.SqrtF32x16(a);
end;

function VecF32x16Min(const a, b: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.MinF32x16(a, b);
end;

function VecF32x16Max(const a, b: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.MaxF32x16(a, b);
end;

function VecF32x16Clamp(const a, minVal, maxVal: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ClampF32x16(a, minVal, maxVal);
end;

function VecF32x16Fma(const a, b, c: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.FmaF32x16(a, b, c);
end;

function VecF32x16Floor(const a: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.FloorF32x16(a);
end;

function VecF32x16Ceil(const a: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CeilF32x16(a);
end;

function VecF32x16Round(const a: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.RoundF32x16(a);
end;

function VecF32x16Trunc(const a: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.TruncF32x16(a);
end;

function VecF32x16ReduceAdd(const a: TVecF32x16): Single;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceAddF32x16(a);
end;

function VecF32x16ReduceMin(const a: TVecF32x16): Single;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceMinF32x16(a);
end;

function VecF32x16ReduceMax(const a: TVecF32x16): Single;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceMaxF32x16(a);
end;

function VecF32x16ReduceMul(const a: TVecF32x16): Single;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceMulF32x16(a);
end;

function VecF32x16Select(const mask: TMask16; const a, b: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.SelectF32x16(mask, a, b);
end;

// === I32x16 Operations Implementation ===
// I32x16 高级 API 实现

function VecI32x16Add(const a, b: TVecI32x16): TVecI32x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AddI32x16) then
    Result := dispatch^.AddI32x16(a, b)
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := a.i[i] + b.i[i];
  end;
end;

function VecI32x16Sub(const a, b: TVecI32x16): TVecI32x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SubI32x16) then
    Result := dispatch^.SubI32x16(a, b)
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := a.i[i] - b.i[i];
  end;
end;

function VecI32x16Mul(const a, b: TVecI32x16): TVecI32x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MulI32x16) then
    Result := dispatch^.MulI32x16(a, b)
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := a.i[i] * b.i[i];
  end;
end;

function VecI32x16And(const a, b: TVecI32x16): TVecI32x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndI32x16) then
    Result := dispatch^.AndI32x16(a, b)
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := a.i[i] and b.i[i];
  end;
end;

function VecI32x16Or(const a, b: TVecI32x16): TVecI32x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.OrI32x16) then
    Result := dispatch^.OrI32x16(a, b)
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := a.i[i] or b.i[i];
  end;
end;

function VecI32x16Xor(const a, b: TVecI32x16): TVecI32x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.XorI32x16) then
    Result := dispatch^.XorI32x16(a, b)
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := a.i[i] xor b.i[i];
  end;
end;

function VecI32x16Not(const a: TVecI32x16): TVecI32x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.NotI32x16) then
    Result := dispatch^.NotI32x16(a)
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := not a.i[i];
  end;
end;

function VecI32x16AndNot(const a, b: TVecI32x16): TVecI32x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndNotI32x16) then
    Result := dispatch^.AndNotI32x16(a, b)
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := (not a.i[i]) and b.i[i];
  end;
end;

function VecI32x16ShiftLeft(const a: TVecI32x16; count: Integer): TVecI32x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
    LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 32 then
  begin
    for i := 0 to 15 do
      Result.i[i] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftLeftI32x16) then
    Result := dispatch^.ShiftLeftI32x16(a, LCount)
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := a.i[i] shl LCount;
  end;
end;

function VecI32x16ShiftRight(const a: TVecI32x16; count: Integer): TVecI32x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
    LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 32 then
  begin
    for i := 0 to 15 do
      Result.i[i] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftRightI32x16) then
    Result := dispatch^.ShiftRightI32x16(a, LCount)
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := Int32(UInt32(a.i[i]) shr LCount);
  end;
end;

function VecI32x16ShiftRightArith(const a: TVecI32x16; count: Integer): TVecI32x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
    LCount: Integer;
begin
  LCount := count;
  if LCount < 0 then
  begin
    Result := a;
    Exit;
  end;

  if LCount >= 32 then
  begin
    for i := 0 to 15 do
      if a.i[i] < 0 then
        Result.i[i] := -1
      else
        Result.i[i] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftRightArithI32x16) then
    Result := dispatch^.ShiftRightArithI32x16(a, LCount)
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := SarLongint(a.i[i], LCount);
  end;
end;

function VecI32x16CmpEq(const a, b: TVecI32x16): TMask16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpEqI32x16) then
    Result := dispatch^.CmpEqI32x16(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 15 do
      if a.i[i] = b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI32x16CmpLt(const a, b: TVecI32x16): TMask16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLtI32x16) then
    Result := dispatch^.CmpLtI32x16(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 15 do
      if a.i[i] < b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI32x16CmpGt(const a, b: TVecI32x16): TMask16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGtI32x16) then
    Result := dispatch^.CmpGtI32x16(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 15 do
      if a.i[i] > b.i[i] then Result := Result or (1 shl i);
  end;
end;

// 添加 I32x16 缺失比较函数
function VecI32x16CmpLe(const a, b: TVecI32x16): TMask16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLeI32x16) then
    Result := dispatch^.CmpLeI32x16(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 15 do
      if a.i[i] <= b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI32x16CmpGe(const a, b: TVecI32x16): TMask16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGeI32x16) then
    Result := dispatch^.CmpGeI32x16(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 15 do
      if a.i[i] >= b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI32x16CmpNe(const a, b: TVecI32x16): TMask16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpNeI32x16) then
    Result := dispatch^.CmpNeI32x16(a, b)
  else
  begin
    Result := 0;
    for i := 0 to 15 do
      if a.i[i] <> b.i[i] then Result := Result or (1 shl i);
  end;
end;

function VecI32x16Min(const a, b: TVecI32x16): TVecI32x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MinI32x16) then
    Result := dispatch^.MinI32x16(a, b)
  else
  begin
    for i := 0 to 15 do
      if a.i[i] < b.i[i] then
        Result.i[i] := a.i[i]
      else
        Result.i[i] := b.i[i];
  end;
end;

function VecI32x16Max(const a, b: TVecI32x16): TVecI32x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MaxI32x16) then
    Result := dispatch^.MaxI32x16(a, b)
  else
  begin
    for i := 0 to 15 do
      if a.i[i] > b.i[i] then
        Result.i[i] := a.i[i]
      else
        Result.i[i] := b.i[i];
  end;
end;

// === I64x8 Operations Implementation ===

function VecI64x8Add(const a, b: TVecI64x8): TVecI64x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AddI64x8) then
    Result := LDispatch^.AddI64x8(a, b)
  else
  begin
    for LIndex := 0 to 7 do
      Result.i[LIndex] := a.i[LIndex] + b.i[LIndex];
  end;
end;

function VecI64x8Sub(const a, b: TVecI64x8): TVecI64x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.SubI64x8) then
    Result := LDispatch^.SubI64x8(a, b)
  else
  begin
    for LIndex := 0 to 7 do
      Result.i[LIndex] := a.i[LIndex] - b.i[LIndex];
  end;
end;

function VecI64x8And(const a, b: TVecI64x8): TVecI64x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AndI64x8) then
    Result := LDispatch^.AndI64x8(a, b)
  else
  begin
    for LIndex := 0 to 7 do
      Result.i[LIndex] := a.i[LIndex] and b.i[LIndex];
  end;
end;

function VecI64x8Or(const a, b: TVecI64x8): TVecI64x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.OrI64x8) then
    Result := LDispatch^.OrI64x8(a, b)
  else
  begin
    for LIndex := 0 to 7 do
      Result.i[LIndex] := a.i[LIndex] or b.i[LIndex];
  end;
end;

function VecI64x8Xor(const a, b: TVecI64x8): TVecI64x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.XorI64x8) then
    Result := LDispatch^.XorI64x8(a, b)
  else
  begin
    for LIndex := 0 to 7 do
      Result.i[LIndex] := a.i[LIndex] xor b.i[LIndex];
  end;
end;

function VecI64x8Not(const a: TVecI64x8): TVecI64x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.NotI64x8) then
    Result := LDispatch^.NotI64x8(a)
  else
  begin
    for LIndex := 0 to 7 do
      Result.i[LIndex] := not a.i[LIndex];
  end;
end;

function VecI64x8CmpEq(const a, b: TVecI64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpEqI64x8) then
    Result := LDispatch^.CmpEqI64x8(a, b)
  else
  begin
    Result := 0;
    for LIndex := 0 to 7 do
      if a.i[LIndex] = b.i[LIndex] then
        Result := Result or (1 shl LIndex);
  end;
end;

function VecI64x8CmpLt(const a, b: TVecI64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpLtI64x8) then
    Result := LDispatch^.CmpLtI64x8(a, b)
  else
  begin
    Result := 0;
    for LIndex := 0 to 7 do
      if a.i[LIndex] < b.i[LIndex] then
        Result := Result or (1 shl LIndex);
  end;
end;

function VecI64x8CmpGt(const a, b: TVecI64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpGtI64x8) then
    Result := LDispatch^.CmpGtI64x8(a, b)
  else
  begin
    Result := 0;
    for LIndex := 0 to 7 do
      if a.i[LIndex] > b.i[LIndex] then
        Result := Result or (1 shl LIndex);
  end;
end;

function VecI64x8CmpLe(const a, b: TVecI64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpLeI64x8) then
    Result := LDispatch^.CmpLeI64x8(a, b)
  else
  begin
    Result := 0;
    for LIndex := 0 to 7 do
      if a.i[LIndex] <= b.i[LIndex] then
        Result := Result or (1 shl LIndex);
  end;
end;

function VecI64x8CmpGe(const a, b: TVecI64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpGeI64x8) then
    Result := LDispatch^.CmpGeI64x8(a, b)
  else
  begin
    Result := 0;
    for LIndex := 0 to 7 do
      if a.i[LIndex] >= b.i[LIndex] then
        Result := Result or (1 shl LIndex);
  end;
end;

function VecI64x8CmpNe(const a, b: TVecI64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpNeI64x8) then
    Result := LDispatch^.CmpNeI64x8(a, b)
  else
  begin
    Result := 0;
    for LIndex := 0 to 7 do
      if a.i[LIndex] <> b.i[LIndex] then
        Result := Result or (1 shl LIndex);
  end;
end;

function VecU32x16Add(const a, b: TVecU32x16): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.AddU32x16(a, b);
end;

function VecU32x16Sub(const a, b: TVecU32x16): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.SubU32x16(a, b);
end;

function VecU32x16Mul(const a, b: TVecU32x16): TVecU32x16; inline;
var
  LFunc: TVecU32x16MulFunc;
begin
  LFunc := TVecU32x16MulFunc(LoadSimdFacadeFastPath(g_FastVecU32x16MulPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecU32x16MulFunc(LoadSimdFacadeFastPath(g_FastVecU32x16MulPtr));
  end;
  Result := LFunc(a, b);
end;

function VecU32x16And(const a, b: TVecU32x16): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.AndU32x16(a, b);
end;

function VecU32x16Or(const a, b: TVecU32x16): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.OrU32x16(a, b);
end;

function VecU32x16Xor(const a, b: TVecU32x16): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.XorU32x16(a, b);
end;

function VecU32x16Not(const a: TVecU32x16): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.NotU32x16(a);
end;

function VecU32x16AndNot(const a, b: TVecU32x16): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.AndNotU32x16(a, b);
end;

function VecU32x16ShiftLeft(const a: TVecU32x16; count: Integer): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ShiftLeftU32x16(a, count);
end;

function VecU32x16ShiftRight(const a: TVecU32x16; count: Integer): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ShiftRightU32x16(a, count);
end;

function VecU32x16CmpEq(const a, b: TVecU32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpEqU32x16(a, b);
end;

function VecU32x16CmpLt(const a, b: TVecU32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpLtU32x16(a, b);
end;

function VecU32x16CmpGt(const a, b: TVecU32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpGtU32x16(a, b);
end;

function VecU32x16CmpLe(const a, b: TVecU32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpLeU32x16(a, b);
end;

function VecU32x16CmpGe(const a, b: TVecU32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpGeU32x16(a, b);
end;

function VecU32x16CmpNe(const a, b: TVecU32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpNeU32x16(a, b);
end;

function VecU32x16Min(const a, b: TVecU32x16): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.MinU32x16(a, b);
end;

function VecU32x16Max(const a, b: TVecU32x16): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.MaxU32x16(a, b);
end;

function VecU64x8Add(const a, b: TVecU64x8): TVecU64x8; inline;
var
  LFunc: TVecU64x8AddFunc;
begin
  LFunc := TVecU64x8AddFunc(LoadSimdFacadeFastPath(g_FastVecU64x8AddPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecU64x8AddFunc(LoadSimdFacadeFastPath(g_FastVecU64x8AddPtr));
  end;
  Result := LFunc(a, b);
end;

function VecU64x8Sub(const a, b: TVecU64x8): TVecU64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.SubU64x8(a, b);
end;

function VecU64x8And(const a, b: TVecU64x8): TVecU64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.AndU64x8(a, b);
end;

function VecU64x8Or(const a, b: TVecU64x8): TVecU64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.OrU64x8(a, b);
end;

function VecU64x8Xor(const a, b: TVecU64x8): TVecU64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.XorU64x8(a, b);
end;

function VecU64x8Not(const a: TVecU64x8): TVecU64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.NotU64x8(a);
end;

function VecU64x8ShiftLeft(const a: TVecU64x8; count: Integer): TVecU64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ShiftLeftU64x8(a, count);
end;

function VecU64x8ShiftRight(const a: TVecU64x8; count: Integer): TVecU64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ShiftRightU64x8(a, count);
end;

function VecU64x8CmpEq(const a, b: TVecU64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpEqU64x8(a, b);
end;

function VecU64x8CmpLt(const a, b: TVecU64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpLtU64x8(a, b);
end;

function VecU64x8CmpGt(const a, b: TVecU64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpGtU64x8(a, b);
end;

function VecU64x8CmpLe(const a, b: TVecU64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpLeU64x8(a, b);
end;

function VecU64x8CmpGe(const a, b: TVecU64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpGeU64x8(a, b);
end;

function VecU64x8CmpNe(const a, b: TVecU64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpNeU64x8(a, b);
end;

function VecI16x32Add(const a, b: TVecI16x32): TVecI16x32; inline;
var
  LFunc: TVecI16x32AddFunc;
begin
  LFunc := TVecI16x32AddFunc(LoadSimdFacadeFastPath(g_FastVecI16x32AddPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecI16x32AddFunc(LoadSimdFacadeFastPath(g_FastVecI16x32AddPtr));
  end;
  Result := LFunc(a, b);
end;

function VecI16x32Sub(const a, b: TVecI16x32): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.SubI16x32(a, b);
end;

function VecI16x32And(const a, b: TVecI16x32): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.AndI16x32(a, b);
end;

function VecI16x32Or(const a, b: TVecI16x32): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.OrI16x32(a, b);
end;

function VecI16x32Xor(const a, b: TVecI16x32): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.XorI16x32(a, b);
end;

function VecI16x32Not(const a: TVecI16x32): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.NotI16x32(a);
end;

function VecI16x32AndNot(const a, b: TVecI16x32): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.AndNotI16x32(a, b);
end;

function VecI16x32ShiftLeft(const a: TVecI16x32; count: Integer): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ShiftLeftI16x32(a, count);
end;

function VecI16x32ShiftRight(const a: TVecI16x32; count: Integer): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ShiftRightI16x32(a, count);
end;

function VecI16x32ShiftRightArith(const a: TVecI16x32; count: Integer): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ShiftRightArithI16x32(a, count);
end;

function VecI16x32CmpEq(const a, b: TVecI16x32): TMask32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpEqI16x32(a, b);
end;

function VecI16x32CmpLt(const a, b: TVecI16x32): TMask32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpLtI16x32(a, b);
end;

function VecI16x32CmpGt(const a, b: TVecI16x32): TMask32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpGtI16x32(a, b);
end;

function VecI16x32Min(const a, b: TVecI16x32): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.MinI16x32(a, b);
end;

function VecI16x32Max(const a, b: TVecI16x32): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.MaxI16x32(a, b);
end;

function VecI8x64Add(const a, b: TVecI8x64): TVecI8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.AddI8x64(a, b);
end;

function VecI8x64Sub(const a, b: TVecI8x64): TVecI8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.SubI8x64(a, b);
end;

function VecI8x64And(const a, b: TVecI8x64): TVecI8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.AndI8x64(a, b);
end;

function VecI8x64Or(const a, b: TVecI8x64): TVecI8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.OrI8x64(a, b);
end;

function VecI8x64Xor(const a, b: TVecI8x64): TVecI8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.XorI8x64(a, b);
end;

function VecI8x64Not(const a: TVecI8x64): TVecI8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.NotI8x64(a);
end;

function VecI8x64AndNot(const a, b: TVecI8x64): TVecI8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.AndNotI8x64(a, b);
end;

function VecI8x64CmpEq(const a, b: TVecI8x64): TMask64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpEqI8x64(a, b);
end;

function VecI8x64CmpLt(const a, b: TVecI8x64): TMask64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpLtI8x64(a, b);
end;

function VecI8x64CmpGt(const a, b: TVecI8x64): TMask64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpGtI8x64(a, b);
end;

function VecI8x64Min(const a, b: TVecI8x64): TVecI8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.MinI8x64(a, b);
end;

function VecI8x64Max(const a, b: TVecI8x64): TVecI8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.MaxI8x64(a, b);
end;

function VecU8x64Add(const a, b: TVecU8x64): TVecU8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.AddU8x64(a, b);
end;

function VecU8x64Sub(const a, b: TVecU8x64): TVecU8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.SubU8x64(a, b);
end;

function VecU8x64And(const a, b: TVecU8x64): TVecU8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.AndU8x64(a, b);
end;

function VecU8x64Or(const a, b: TVecU8x64): TVecU8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.OrU8x64(a, b);
end;

function VecU8x64Xor(const a, b: TVecU8x64): TVecU8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.XorU8x64(a, b);
end;

function VecU8x64Not(const a: TVecU8x64): TVecU8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.NotU8x64(a);
end;

function VecU8x64CmpEq(const a, b: TVecU8x64): TMask64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpEqU8x64(a, b);
end;

function VecU8x64CmpLt(const a, b: TVecU8x64): TMask64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpLtU8x64(a, b);
end;

function VecU8x64CmpGt(const a, b: TVecU8x64): TMask64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpGtU8x64(a, b);
end;

function VecU8x64Min(const a, b: TVecU8x64): TVecU8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.MinU8x64(a, b);
end;

function VecU8x64Max(const a, b: TVecU8x64): TVecU8x64; inline;
var
  LFunc: TVecU8x64MaxFunc;
begin
  LFunc := TVecU8x64MaxFunc(LoadSimdFacadeFastPath(g_FastVecU8x64MaxPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecU8x64MaxFunc(LoadSimdFacadeFastPath(g_FastVecU8x64MaxPtr));
  end;
  Result := LFunc(a, b);
end;

// === P1 Missing Functions: I32x8 Abs/Clamp (256-bit) ===

function VecI32x8Abs(const a: TVecI32x8): TVecI32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    if a.i[i] < 0 then
      Result.i[i] := -a.i[i]
    else
      Result.i[i] := a.i[i];
end;

function VecI32x8Clamp(const a, minVal, maxVal: TVecI32x8): TVecI32x8;
var i: Integer;
    v: Int32;
begin
  for i := 0 to 7 do
  begin
    v := a.i[i];
    if v < minVal.i[i] then v := minVal.i[i];
    if v > maxVal.i[i] then v := maxVal.i[i];
    Result.i[i] := v;
  end;
end;

// === P2 Completeness: I32x8 Utility Functions ===

function VecI32x8Splat(value: Int32): TVecI32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := value;
end;

function VecI32x8Zero: TVecI32x8;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

function VecI32x8Load(p: PInt32): TVecI32x8;
begin
  Move(p^, Result, SizeOf(TVecI32x8));
end;

procedure VecI32x8Store(p: PInt32; const a: TVecI32x8);
begin
  Move(a, p^, SizeOf(TVecI32x8));
end;

// === P2 Completeness: I32x8 Reduce Functions ===

function VecI32x8ReduceAdd(const a: TVecI32x8): Int32;
var i: Integer;
begin
  Result := a.i[0];
  for i := 1 to 7 do
    Result := Result + a.i[i];
end;

function VecI32x8ReduceMin(const a: TVecI32x8): Int32;
var i: Integer;
begin
  Result := a.i[0];
  for i := 1 to 7 do
    if a.i[i] < Result then
      Result := a.i[i];
end;

function VecI32x8ReduceMax(const a: TVecI32x8): Int32;
var i: Integer;
begin
  Result := a.i[0];
  for i := 1 to 7 do
    if a.i[i] > Result then
      Result := a.i[i];
end;

// === P2 Completeness: F64x4 Make + Lerp ===

function VecF64x4Make(x, y, z, w: Double): TVecF64x4;
begin
  Result.d[0] := x;
  Result.d[1] := y;
  Result.d[2] := z;
  Result.d[3] := w;
end;

function VecF64x4Lerp(const a, b: TVecF64x4; t: Double): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.d[i] := a.d[i] + t * (b.d[i] - a.d[i]);
end;
