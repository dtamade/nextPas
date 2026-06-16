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

