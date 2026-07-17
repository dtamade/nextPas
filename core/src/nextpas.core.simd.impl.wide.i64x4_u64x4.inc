// === I64x4 Operations Implementation ===
// I64x4 (256-bit, 4x64-bit signed) 高级 API 实现
// 使用 dispatch table 以获得 AVX2 加速

function VecI64x4Add(const a, b: TVecI64x4): TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.AddI64x4) then
    Result := dispatch^.CoreVectors.AddI64x4(a, b)
  else
    for i := 0 to 3 do
      Result.i[i] := a.i[i] + b.i[i];
end;

function VecI64x4Sub(const a, b: TVecI64x4): TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.SubI64x4) then
    Result := dispatch^.CoreVectors.SubI64x4(a, b)
  else
    for i := 0 to 3 do
      Result.i[i] := a.i[i] - b.i[i];
end;

function VecI64x4And(const a, b: TVecI64x4): TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.AndI64x4) then
    Result := dispatch^.CoreVectors.AndI64x4(a, b)
  else
    for i := 0 to 3 do
      Result.i[i] := a.i[i] and b.i[i];
end;

function VecI64x4Or(const a, b: TVecI64x4): TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.OrI64x4) then
    Result := dispatch^.CoreVectors.OrI64x4(a, b)
  else
    for i := 0 to 3 do
      Result.i[i] := a.i[i] or b.i[i];
end;

function VecI64x4Xor(const a, b: TVecI64x4): TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.XorI64x4) then
    Result := dispatch^.CoreVectors.XorI64x4(a, b)
  else
    for i := 0 to 3 do
      Result.i[i] := a.i[i] xor b.i[i];
end;

function VecI64x4Not(const a: TVecI64x4): TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.NotI64x4) then
    Result := dispatch^.CoreVectors.NotI64x4(a)
  else
    for i := 0 to 3 do
      Result.i[i] := not a.i[i];
end;

function VecI64x4AndNot(const a, b: TVecI64x4): TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.AndNotI64x4) then
    Result := dispatch^.CoreVectors.AndNotI64x4(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.ShiftLeftI64x4) then
    Result := dispatch^.CoreVectors.ShiftLeftI64x4(a, LCount)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.ShiftRightI64x4) then
    Result := dispatch^.CoreVectors.ShiftRightI64x4(a, LCount)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.ShiftRightArithI64x4) then
    Result := dispatch^.CoreVectors.ShiftRightArithI64x4(a, LCount)
  else
    for i := 0 to 3 do
      Result.i[i] := SarInt64(a.i[i], LCount);
end;

function VecI64x4CmpEq(const a, b: TVecI64x4): TMask4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpEqI64x4) then
    Result := dispatch^.CoreVectors.CmpEqI64x4(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpLtI64x4) then
    Result := dispatch^.CoreVectors.CmpLtI64x4(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpGtI64x4) then
    Result := dispatch^.CoreVectors.CmpGtI64x4(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpLeI64x4) then
    Result := dispatch^.CoreVectors.CmpLeI64x4(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpGeI64x4) then
    Result := dispatch^.CoreVectors.CmpGeI64x4(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpNeI64x4) then
    Result := dispatch^.CoreVectors.CmpNeI64x4(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.LoadI64x4) then
    Result := dispatch^.CoreVectors.LoadI64x4(p)
  else
    for i := 0 to 3 do
      Result.i[i] := (p + i)^;
end;

procedure VecI64x4Store(p: PInt64; const a: TVecI64x4);
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.StoreI64x4) then
    dispatch^.CoreVectors.StoreI64x4(p, a)
  else
    for i := 0 to 3 do
      (p + i)^ := a.i[i];
end;

function VecI64x4Splat(value: Int64): TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.SplatI64x4) then
    Result := dispatch^.CoreVectors.SplatI64x4(value)
  else
    for i := 0 to 3 do
      Result.i[i] := value;
end;

function VecI64x4Zero: TVecI64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.ZeroI64x4) then
    Result := dispatch^.CoreVectors.ZeroI64x4()
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.AddU64x4) then
    Result := dispatch^.CoreVectors.AddU64x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] + b.u[i];
end;

function VecU64x4Sub(const a, b: TVecU64x4): TVecU64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.SubU64x4) then
    Result := dispatch^.CoreVectors.SubU64x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] - b.u[i];
end;

function VecU64x4And(const a, b: TVecU64x4): TVecU64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.AndU64x4) then
    Result := dispatch^.CoreVectors.AndU64x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] and b.u[i];
end;

function VecU64x4Or(const a, b: TVecU64x4): TVecU64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.OrU64x4) then
    Result := dispatch^.CoreVectors.OrU64x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] or b.u[i];
end;

function VecU64x4Xor(const a, b: TVecU64x4): TVecU64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.XorU64x4) then
    Result := dispatch^.CoreVectors.XorU64x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] xor b.u[i];
end;

function VecU64x4Not(const a: TVecU64x4): TVecU64x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.NotU64x4) then
    Result := dispatch^.CoreVectors.NotU64x4(a)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.ShiftLeftU64x4) then
    Result := dispatch^.CoreVectors.ShiftLeftU64x4(a, LCount)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.ShiftRightU64x4) then
    Result := dispatch^.CoreVectors.ShiftRightU64x4(a, LCount)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] shr LCount;
end;

function VecU64x4CmpEq(const a, b: TVecU64x4): TMask4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpEqU64x4) then
    Result := dispatch^.CoreVectors.CmpEqU64x4(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpLtU64x4) then
    Result := dispatch^.CoreVectors.CmpLtU64x4(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpGtU64x4) then
    Result := dispatch^.CoreVectors.CmpGtU64x4(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpLeU64x4) then
    Result := dispatch^.CoreVectors.CmpLeU64x4(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpGeU64x4) then
    Result := dispatch^.CoreVectors.CmpGeU64x4(a, b)
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
  if (dispatch <> nil) and Assigned(dispatch^.CoreVectors.CmpNeU64x4) then
    Result := dispatch^.CoreVectors.CmpNeU64x4(a, b)
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

