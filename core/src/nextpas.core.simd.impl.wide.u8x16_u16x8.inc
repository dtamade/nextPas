// === U8x16 Operations Implementation ===
// U8x16 (128-bit, 16x UInt8) 高级 API 实现
// 修改为使用 dispatch table 以获得 SIMD 加速

function VecU8x16Add(const a, b: TVecU8x16): TVecU8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.AddU8x16) then
    Result := dispatch^.CoreVectors.AddU8x16(a, b)
  else
    for i := 0 to 15 do
      Result.u[i] := a.u[i] + b.u[i];
end;

function VecU8x16Sub(const a, b: TVecU8x16): TVecU8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.SubU8x16) then
    Result := dispatch^.CoreVectors.SubU8x16(a, b)
  else
    for i := 0 to 15 do
      Result.u[i] := a.u[i] - b.u[i];
end;

function VecU8x16And(const a, b: TVecU8x16): TVecU8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.AndU8x16) then
    Result := dispatch^.CoreVectors.AndU8x16(a, b)
  else
    for i := 0 to 15 do
      Result.u[i] := a.u[i] and b.u[i];
end;

function VecU8x16Or(const a, b: TVecU8x16): TVecU8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.OrU8x16) then
    Result := dispatch^.CoreVectors.OrU8x16(a, b)
  else
    for i := 0 to 15 do
      Result.u[i] := a.u[i] or b.u[i];
end;

function VecU8x16Xor(const a, b: TVecU8x16): TVecU8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.XorU8x16) then
    Result := dispatch^.CoreVectors.XorU8x16(a, b)
  else
    for i := 0 to 15 do
      Result.u[i] := a.u[i] xor b.u[i];
end;

function VecU8x16Not(const a: TVecU8x16): TVecU8x16;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.NotU8x16) then
    Result := dispatch^.CoreVectors.NotU8x16(a)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.AndNotU8x16) then
    Result := LDispatch^.CoreVectors.AndNotU8x16(a, b)
  else if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.NotU8x16) and Assigned(LDispatch^.CoreVectors.AndU8x16) then
  begin
    Result := LDispatch^.CoreVectors.AndU8x16(LDispatch^.CoreVectors.NotU8x16(a), b);
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpEqU8x16) then
    Result := dispatch^.CoreVectors.CmpEqU8x16(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpLtU8x16) then
    Result := dispatch^.CoreVectors.CmpLtU8x16(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpGtU8x16) then
    Result := dispatch^.CoreVectors.CmpGtU8x16(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpLeU8x16) then
    Result := dispatch^.CoreVectors.CmpLeU8x16(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpGeU8x16) then
    Result := dispatch^.CoreVectors.CmpGeU8x16(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpNeU8x16) then
    Result := dispatch^.CoreVectors.CmpNeU8x16(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.MinU8x16) then
    Result := dispatch^.CoreVectors.MinU8x16(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.MaxU8x16) then
    Result := dispatch^.CoreVectors.MaxU8x16(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.AddU16x8) then
    Result := dispatch^.CoreVectors.AddU16x8(a, b)
  else
    for i := 0 to 7 do
      Result.u[i] := a.u[i] + b.u[i];
end;

function VecU16x8Sub(const a, b: TVecU16x8): TVecU16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.SubU16x8) then
    Result := dispatch^.CoreVectors.SubU16x8(a, b)
  else
    for i := 0 to 7 do
      Result.u[i] := a.u[i] - b.u[i];
end;

function VecU16x8Mul(const a, b: TVecU16x8): TVecU16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.MulU16x8) then
    Result := dispatch^.CoreVectors.MulU16x8(a, b)
  else
    for i := 0 to 7 do
      Result.u[i] := a.u[i] * b.u[i];
end;

function VecU16x8And(const a, b: TVecU16x8): TVecU16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.AndU16x8) then
    Result := dispatch^.CoreVectors.AndU16x8(a, b)
  else
    for i := 0 to 7 do
      Result.u[i] := a.u[i] and b.u[i];
end;

function VecU16x8Or(const a, b: TVecU16x8): TVecU16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.OrU16x8) then
    Result := dispatch^.CoreVectors.OrU16x8(a, b)
  else
    for i := 0 to 7 do
      Result.u[i] := a.u[i] or b.u[i];
end;

function VecU16x8Xor(const a, b: TVecU16x8): TVecU16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.XorU16x8) then
    Result := dispatch^.CoreVectors.XorU16x8(a, b)
  else
    for i := 0 to 7 do
      Result.u[i] := a.u[i] xor b.u[i];
end;

function VecU16x8Not(const a: TVecU16x8): TVecU16x8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.NotU16x8) then
    Result := dispatch^.CoreVectors.NotU16x8(a)
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
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.AndNotU16x8) then
    Result := LDispatch^.CoreVectors.AndNotU16x8(a, b)
  else if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.NotU16x8) and Assigned(LDispatch^.CoreVectors.AndU16x8) then
  begin
    Result := LDispatch^.CoreVectors.AndU16x8(LDispatch^.CoreVectors.NotU16x8(a), b);
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.ShiftLeftU16x8) then
    Result := dispatch^.CoreVectors.ShiftLeftU16x8(a, count)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.ShiftRightU16x8) then
    Result := dispatch^.CoreVectors.ShiftRightU16x8(a, count)
  else
    for i := 0 to 7 do
      Result.u[i] := a.u[i] shr count;
end;

function VecU16x8CmpEq(const a, b: TVecU16x8): TMask8;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpEqU16x8) then
    Result := dispatch^.CoreVectors.CmpEqU16x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpLtU16x8) then
    Result := dispatch^.CoreVectors.CmpLtU16x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpGtU16x8) then
    Result := dispatch^.CoreVectors.CmpGtU16x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpLeU16x8) then
    Result := dispatch^.CoreVectors.CmpLeU16x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpGeU16x8) then
    Result := dispatch^.CoreVectors.CmpGeU16x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpNeU16x8) then
    Result := dispatch^.CoreVectors.CmpNeU16x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.MinU16x8) then
    Result := dispatch^.CoreVectors.MinU16x8(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.MaxU16x8) then
    Result := dispatch^.CoreVectors.MaxU16x8(a, b)
  else
    for i := 0 to 7 do
      if a.u[i] > b.u[i] then
        Result.u[i] := a.u[i]
      else
        Result.u[i] := b.u[i];
end;

