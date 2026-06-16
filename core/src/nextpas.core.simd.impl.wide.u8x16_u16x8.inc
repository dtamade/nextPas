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

