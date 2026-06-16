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

