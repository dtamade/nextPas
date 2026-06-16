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

