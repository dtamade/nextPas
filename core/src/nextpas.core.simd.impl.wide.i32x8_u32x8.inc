// === I32x8 Operations Implementation ===
// I32x8 高级 API 实现

function VecI32x8Add(const a, b: TVecI32x8): TVecI32x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.AddI32x8) then
    Result := dispatch^.CoreVectors.AddI32x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.SubI32x8) then
    Result := dispatch^.CoreVectors.SubI32x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.MulI32x8) then
    Result := dispatch^.CoreVectors.MulI32x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.AndI32x8) then
    Result := dispatch^.CoreVectors.AndI32x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.OrI32x8) then
    Result := dispatch^.CoreVectors.OrI32x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.XorI32x8) then
    Result := dispatch^.CoreVectors.XorI32x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.NotI32x8) then
    Result := dispatch^.CoreVectors.NotI32x8(a)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.AndNotI32x8) then
    Result := dispatch^.CoreVectors.AndNotI32x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.ShiftLeftI32x8) then
    Result := dispatch^.CoreVectors.ShiftLeftI32x8(a, LCount)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.ShiftRightI32x8) then
    Result := dispatch^.CoreVectors.ShiftRightI32x8(a, LCount)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.ShiftRightArithI32x8) then
    Result := dispatch^.CoreVectors.ShiftRightArithI32x8(a, LCount)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpEqI32x8) then
    Result := dispatch^.CoreVectors.CmpEqI32x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpLtI32x8) then
    Result := dispatch^.CoreVectors.CmpLtI32x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpGtI32x8) then
    Result := dispatch^.CoreVectors.CmpGtI32x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpLeI32x8) then
    Result := dispatch^.CoreVectors.CmpLeI32x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpGeI32x8) then
    Result := dispatch^.CoreVectors.CmpGeI32x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpNeI32x8) then
    Result := dispatch^.CoreVectors.CmpNeI32x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.MinI32x8) then
    Result := dispatch^.CoreVectors.MinI32x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.MaxI32x8) then
    Result := dispatch^.CoreVectors.MaxI32x8(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.AddU32x8) then
    Result := LDispatch^.CoreVectors.AddU32x8(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.SubU32x8) then
    Result := LDispatch^.CoreVectors.SubU32x8(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.MulU32x8) then
    Result := LDispatch^.CoreVectors.MulU32x8(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.AndU32x8) then
    Result := LDispatch^.CoreVectors.AndU32x8(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.OrU32x8) then
    Result := LDispatch^.CoreVectors.OrU32x8(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.XorU32x8) then
    Result := LDispatch^.CoreVectors.XorU32x8(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.NotU32x8) then
    Result := LDispatch^.CoreVectors.NotU32x8(a)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.AndNotU32x8) then
    Result := LDispatch^.CoreVectors.AndNotU32x8(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.ShiftLeftU32x8) then
    Result := LDispatch^.CoreVectors.ShiftLeftU32x8(a, LCount)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.ShiftRightU32x8) then
    Result := LDispatch^.CoreVectors.ShiftRightU32x8(a, LCount)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.CmpEqU32x8) then
    Result := LDispatch^.CoreVectors.CmpEqU32x8(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.CmpLtU32x8) then
    Result := LDispatch^.CoreVectors.CmpLtU32x8(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.CmpGtU32x8) then
    Result := LDispatch^.CoreVectors.CmpGtU32x8(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.CmpLeU32x8) then
    Result := LDispatch^.CoreVectors.CmpLeU32x8(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.CmpGeU32x8) then
    Result := LDispatch^.CoreVectors.CmpGeU32x8(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.CmpNeU32x8) then
    Result := LDispatch^.CoreVectors.CmpNeU32x8(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.MinU32x8) then
    Result := LDispatch^.CoreVectors.MinU32x8(a, b)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.MaxU32x8) then
    Result := LDispatch^.CoreVectors.MaxU32x8(a, b)
  else
    for LIndex := 0 to 7 do
      if a.u[LIndex] > b.u[LIndex] then
        Result.u[LIndex] := a.u[LIndex]
      else
        Result.u[LIndex] := b.u[LIndex];
end;

