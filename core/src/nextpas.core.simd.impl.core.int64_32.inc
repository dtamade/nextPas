// === I64x2 Operations Implementation ===
// I64x2 高级 API 实现

function VecI64x2Add(const a, b: TVecI64x2): TVecI64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AddI64x2) then
    Result := dispatch^.AddI64x2(a, b)
  else
  begin
    Result.i[0] := a.i[0] + b.i[0];
    Result.i[1] := a.i[1] + b.i[1];
  end;
end;

function VecI64x2Sub(const a, b: TVecI64x2): TVecI64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SubI64x2) then
    Result := dispatch^.SubI64x2(a, b)
  else
  begin
    Result.i[0] := a.i[0] - b.i[0];
    Result.i[1] := a.i[1] - b.i[1];
  end;
end;

function VecI64x2And(const a, b: TVecI64x2): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AndI64x2) then
    Result := LDispatch^.AndI64x2(a, b)
  else
  begin
    Result.i[0] := a.i[0] and b.i[0];
    Result.i[1] := a.i[1] and b.i[1];
  end;
end;

function VecI64x2Or(const a, b: TVecI64x2): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.OrI64x2) then
    Result := LDispatch^.OrI64x2(a, b)
  else
  begin
    Result.i[0] := a.i[0] or b.i[0];
    Result.i[1] := a.i[1] or b.i[1];
  end;
end;

function VecI64x2Xor(const a, b: TVecI64x2): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.XorI64x2) then
    Result := LDispatch^.XorI64x2(a, b)
  else
  begin
    Result.i[0] := a.i[0] xor b.i[0];
    Result.i[1] := a.i[1] xor b.i[1];
  end;
end;

function VecI64x2Not(const a: TVecI64x2): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.NotI64x2) then
    Result := LDispatch^.NotI64x2(a)
  else
  begin
    Result.i[0] := not a.i[0];
    Result.i[1] := not a.i[1];
  end;
end;

function VecI64x2AndNot(const a, b: TVecI64x2): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AndNotI64x2) then
    Result := LDispatch^.AndNotI64x2(a, b)
  else
  begin
    // (~a) and b
    Result.i[0] := (not a.i[0]) and b.i[0];
    Result.i[1] := (not a.i[1]) and b.i[1];
  end;
end;

// I64x2 完整 API 实现 - 移位/比较/Min/Max

function VecI64x2ShiftLeft(const a: TVecI64x2; count: Integer): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
  LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 64 then
  begin
    Result.i[0] := 0;
    Result.i[1] := 0;
    Exit;
  end;

  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ShiftLeftI64x2) then
    Result := LDispatch^.ShiftLeftI64x2(a, LCount)
  else
  begin
    Result.i[0] := a.i[0] shl LCount;
    Result.i[1] := a.i[1] shl LCount;
  end;
end;

function VecI64x2ShiftRight(const a: TVecI64x2; count: Integer): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
  LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 64 then
  begin
    Result.i[0] := 0;
    Result.i[1] := 0;
    Exit;
  end;

  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ShiftRightI64x2) then
    Result := LDispatch^.ShiftRightI64x2(a, LCount)
  else
  begin
    // 逻辑右移 (无符号)
    Result.i[0] := Int64(UInt64(a.i[0]) shr LCount);
    Result.i[1] := Int64(UInt64(a.i[1]) shr LCount);
  end;
end;

function VecI64x2ShiftRightArith(const a: TVecI64x2; count: Integer): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
  LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 64 then
  begin
    if a.i[0] < 0 then Result.i[0] := -1 else Result.i[0] := 0;
    if a.i[1] < 0 then Result.i[1] := -1 else Result.i[1] := 0;
    Exit;
  end;

  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ShiftRightArithI64x2) then
    Result := LDispatch^.ShiftRightArithI64x2(a, LCount)
  else
  begin
    // 算术右移 (保留符号位)
    Result.i[0] := SarInt64(a.i[0], LCount);
    Result.i[1] := SarInt64(a.i[1], LCount);
  end;
end;

function VecI64x2CmpEq(const a, b: TVecI64x2): TMask2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpEqI64x2) then
    Result := LDispatch^.CmpEqI64x2(a, b)
  else
  begin
    Result := 0;
    if a.i[0] = b.i[0] then Result := Result or 1;
    if a.i[1] = b.i[1] then Result := Result or 2;
  end;
end;

function VecI64x2CmpLt(const a, b: TVecI64x2): TMask2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpLtI64x2) then
    Result := LDispatch^.CmpLtI64x2(a, b)
  else
  begin
    Result := 0;
    if a.i[0] < b.i[0] then Result := Result or 1;
    if a.i[1] < b.i[1] then Result := Result or 2;
  end;
end;

function VecI64x2CmpGt(const a, b: TVecI64x2): TMask2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpGtI64x2) then
    Result := LDispatch^.CmpGtI64x2(a, b)
  else
  begin
    Result := 0;
    if a.i[0] > b.i[0] then Result := Result or 1;
    if a.i[1] > b.i[1] then Result := Result or 2;
  end;
end;

// 添加 I64x2 缺失比较函数
function VecI64x2CmpLe(const a, b: TVecI64x2): TMask2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpLeI64x2) then
    Result := LDispatch^.CmpLeI64x2(a, b)
  else
  begin
    Result := 0;
    if a.i[0] <= b.i[0] then Result := Result or 1;
    if a.i[1] <= b.i[1] then Result := Result or 2;
  end;
end;

function VecI64x2CmpGe(const a, b: TVecI64x2): TMask2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpGeI64x2) then
    Result := LDispatch^.CmpGeI64x2(a, b)
  else
  begin
    Result := 0;
    if a.i[0] >= b.i[0] then Result := Result or 1;
    if a.i[1] >= b.i[1] then Result := Result or 2;
  end;
end;

function VecI64x2CmpNe(const a, b: TVecI64x2): TMask2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpNeI64x2) then
    Result := LDispatch^.CmpNeI64x2(a, b)
  else
  begin
    Result := 0;
    if a.i[0] <> b.i[0] then Result := Result or 1;
    if a.i[1] <> b.i[1] then Result := Result or 2;
  end;
end;

function VecI64x2Min(const a, b: TVecI64x2): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.MinI64x2) then
    Result := LDispatch^.MinI64x2(a, b)
  else
  begin
    if a.i[0] < b.i[0] then Result.i[0] := a.i[0] else Result.i[0] := b.i[0];
    if a.i[1] < b.i[1] then Result.i[1] := a.i[1] else Result.i[1] := b.i[1];
  end;
end;

function VecI64x2Max(const a, b: TVecI64x2): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.MaxI64x2) then
    Result := LDispatch^.MaxI64x2(a, b)
  else
  begin
    if a.i[0] > b.i[0] then Result.i[0] := a.i[0] else Result.i[0] := b.i[0];
    if a.i[1] > b.i[1] then Result.i[1] := a.i[1] else Result.i[1] := b.i[1];
  end;
end;

// === U64x2 Operations Implementation ===
// U64x2 (128-bit, 2x UInt64) 高级 API 实现

function VecU64x2Add(const a, b: TVecU64x2): TVecU64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AddU64x2) then
    Result := LDispatch^.AddU64x2(a, b)
  else
  begin
    Result.u[0] := a.u[0] + b.u[0];
    Result.u[1] := a.u[1] + b.u[1];
  end;
end;

function VecU64x2Sub(const a, b: TVecU64x2): TVecU64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.SubU64x2) then
    Result := LDispatch^.SubU64x2(a, b)
  else
  begin
    Result.u[0] := a.u[0] - b.u[0];
    Result.u[1] := a.u[1] - b.u[1];
  end;
end;

function VecU64x2And(const a, b: TVecU64x2): TVecU64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AndU64x2) then
    Result := LDispatch^.AndU64x2(a, b)
  else
  begin
    Result.u[0] := a.u[0] and b.u[0];
    Result.u[1] := a.u[1] and b.u[1];
  end;
end;

function VecU64x2Or(const a, b: TVecU64x2): TVecU64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.OrU64x2) then
    Result := LDispatch^.OrU64x2(a, b)
  else
  begin
    Result.u[0] := a.u[0] or b.u[0];
    Result.u[1] := a.u[1] or b.u[1];
  end;
end;

function VecU64x2Xor(const a, b: TVecU64x2): TVecU64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.XorU64x2) then
    Result := LDispatch^.XorU64x2(a, b)
  else
  begin
    Result.u[0] := a.u[0] xor b.u[0];
    Result.u[1] := a.u[1] xor b.u[1];
  end;
end;

function VecU64x2Not(const a: TVecU64x2): TVecU64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.NotU64x2) then
    Result := LDispatch^.NotU64x2(a)
  else
  begin
    Result.u[0] := not a.u[0];
    Result.u[1] := not a.u[1];
  end;
end;

function VecU64x2AndNot(const a, b: TVecU64x2): TVecU64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AndNotU64x2) then
    Result := LDispatch^.AndNotU64x2(a, b)
  else
  begin
    // (~a) and b
    Result.u[0] := (not a.u[0]) and b.u[0];
    Result.u[1] := (not a.u[1]) and b.u[1];
  end;
end;

function VecU64x2CmpEq(const a, b: TVecU64x2): TMask2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpEqU64x2) then
    Result := LDispatch^.CmpEqU64x2(a, b)
  else
  begin
    Result := 0;
    if a.u[0] = b.u[0] then Result := Result or 1;
    if a.u[1] = b.u[1] then Result := Result or 2;
  end;
end;

function VecU64x2CmpLt(const a, b: TVecU64x2): TMask2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpLtU64x2) then
    Result := LDispatch^.CmpLtU64x2(a, b)
  else
  begin
    Result := 0;
    if a.u[0] < b.u[0] then Result := Result or 1;  // 无符号比较
    if a.u[1] < b.u[1] then Result := Result or 2;
  end;
end;

function VecU64x2CmpGt(const a, b: TVecU64x2): TMask2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpGtU64x2) then
    Result := LDispatch^.CmpGtU64x2(a, b)
  else
  begin
    Result := 0;
    if a.u[0] > b.u[0] then Result := Result or 1;  // 无符号比较
    if a.u[1] > b.u[1] then Result := Result or 2;
  end;
end;

function VecU64x2Min(const a, b: TVecU64x2): TVecU64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.MinU64x2) then
    Result := LDispatch^.MinU64x2(a, b)
  else
  begin
    if a.u[0] < b.u[0] then Result.u[0] := a.u[0] else Result.u[0] := b.u[0];
    if a.u[1] < b.u[1] then Result.u[1] := a.u[1] else Result.u[1] := b.u[1];
  end;
end;

function VecU64x2Max(const a, b: TVecU64x2): TVecU64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.MaxU64x2) then
    Result := LDispatch^.MaxU64x2(a, b)
  else
  begin
    if a.u[0] > b.u[0] then Result.u[0] := a.u[0] else Result.u[0] := b.u[0];
    if a.u[1] > b.u[1] then Result.u[1] := a.u[1] else Result.u[1] := b.u[1];
  end;
end;

// === U32x4 Operations Implementation ===
// U32x4 (128-bit Unsigned) 高级 API 实现
// 修改为使用 dispatch table 以获得 SIMD 加速
// 注意: 无符号整数 SIMD 操作在位层面与有符号相同,
// 区别在于比较和 min/max 使用无符号语义

function VecU32x4Add(const a, b: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AddU32x4) then
    Result := dispatch^.AddU32x4(a, b)
  else
    Result := a + b;
end;

function VecU32x4Sub(const a, b: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SubU32x4) then
    Result := dispatch^.SubU32x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] - b.u[i];
end;

function VecU32x4Mul(const a, b: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MulU32x4) then
    Result := dispatch^.MulU32x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] * b.u[i];
end;

function VecU32x4And(const a, b: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndU32x4) then
    Result := dispatch^.AndU32x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] and b.u[i];
end;

function VecU32x4Or(const a, b: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.OrU32x4) then
    Result := dispatch^.OrU32x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] or b.u[i];
end;

function VecU32x4Xor(const a, b: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.XorU32x4) then
    Result := dispatch^.XorU32x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] xor b.u[i];
end;

function VecU32x4Not(const a: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.NotU32x4) then
    Result := dispatch^.NotU32x4(a)
  else
    for i := 0 to 3 do
      Result.u[i] := not a.u[i];
end;

function VecU32x4AndNot(const a, b: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndNotU32x4) then
    Result := dispatch^.AndNotU32x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := (not a.u[i]) and b.u[i];
end;

function VecU32x4ShiftLeft(const a: TVecU32x4; count: Integer): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
    LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 32 then
  begin
    for i := 0 to 3 do
      Result.u[i] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftLeftU32x4) then
    Result := dispatch^.ShiftLeftU32x4(a, LCount)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] shl LCount;
end;

function VecU32x4ShiftRight(const a: TVecU32x4; count: Integer): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
    LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 32 then
  begin
    for i := 0 to 3 do
      Result.u[i] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftRightU32x4) then
    Result := dispatch^.ShiftRightU32x4(a, LCount)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] shr LCount;  // 逻辑右移 (无符号)
end;

function VecU32x4CmpEq(const a, b: TVecU32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpEqU32x4) then
    Result := dispatch^.CmpEqU32x4(a, b)
  else
  begin
    Result := 0;
    if a.u[0] = b.u[0] then Result := Result or 1;
    if a.u[1] = b.u[1] then Result := Result or 2;
    if a.u[2] = b.u[2] then Result := Result or 4;
    if a.u[3] = b.u[3] then Result := Result or 8;
  end;
end;

function VecU32x4CmpLt(const a, b: TVecU32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLtU32x4) then
    Result := dispatch^.CmpLtU32x4(a, b)
  else
  begin
    Result := 0;
    if a.u[0] < b.u[0] then Result := Result or 1;
    if a.u[1] < b.u[1] then Result := Result or 2;
    if a.u[2] < b.u[2] then Result := Result or 4;
    if a.u[3] < b.u[3] then Result := Result or 8;
  end;
end;

function VecU32x4CmpGt(const a, b: TVecU32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGtU32x4) then
    Result := dispatch^.CmpGtU32x4(a, b)
  else
  begin
    Result := 0;
    if a.u[0] > b.u[0] then Result := Result or 1;
    if a.u[1] > b.u[1] then Result := Result or 2;
    if a.u[2] > b.u[2] then Result := Result or 4;
    if a.u[3] > b.u[3] then Result := Result or 8;
  end;
end;

function VecU32x4CmpLe(const a, b: TVecU32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLeU32x4) then
    Result := dispatch^.CmpLeU32x4(a, b)
  else
  begin
    Result := 0;
    if a.u[0] <= b.u[0] then Result := Result or 1;
    if a.u[1] <= b.u[1] then Result := Result or 2;
    if a.u[2] <= b.u[2] then Result := Result or 4;
    if a.u[3] <= b.u[3] then Result := Result or 8;
  end;
end;

function VecU32x4CmpGe(const a, b: TVecU32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGeU32x4) then
    Result := dispatch^.CmpGeU32x4(a, b)
  else
  begin
    Result := 0;
    if a.u[0] >= b.u[0] then Result := Result or 1;
    if a.u[1] >= b.u[1] then Result := Result or 2;
    if a.u[2] >= b.u[2] then Result := Result or 4;
    if a.u[3] >= b.u[3] then Result := Result or 8;
  end;
end;

function VecU32x4Min(const a, b: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MinU32x4) then
    Result := dispatch^.MinU32x4(a, b)
  else
    for i := 0 to 3 do
      if a.u[i] < b.u[i] then
        Result.u[i] := a.u[i]
      else
        Result.u[i] := b.u[i];
end;

function VecU32x4Max(const a, b: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MaxU32x4) then
    Result := dispatch^.MaxU32x4(a, b)
  else
    for i := 0 to 3 do
      if a.u[i] > b.u[i] then
        Result.u[i] := a.u[i]
      else
        Result.u[i] := b.u[i];
end;

