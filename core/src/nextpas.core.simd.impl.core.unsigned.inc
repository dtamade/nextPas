// === Unsigned operator overloads (128/256/512-bit) ===

operator + (const a, b: TVecU32x4): TVecU32x4;
begin
  Result := VecU32x4Add(a, b);
end;

operator - (const a, b: TVecU32x4): TVecU32x4;
begin
  Result := VecU32x4Sub(a, b);
end;

operator * (const a, b: TVecU32x4): TVecU32x4;
begin
  Result := VecU32x4Mul(a, b);
end;

operator and (const a, b: TVecU32x4): TVecU32x4;
begin
  Result := VecU32x4And(a, b);
end;

operator or (const a, b: TVecU32x4): TVecU32x4;
begin
  Result := VecU32x4Or(a, b);
end;

operator xor (const a, b: TVecU32x4): TVecU32x4;
begin
  Result := VecU32x4Xor(a, b);
end;

operator not (const a: TVecU32x4): TVecU32x4;
begin
  Result := VecU32x4Not(a);
end;

operator + (const a, b: TVecU64x2): TVecU64x2;
begin
  Result := VecU64x2Add(a, b);
end;

operator - (const a, b: TVecU64x2): TVecU64x2;
begin
  Result := VecU64x2Sub(a, b);
end;

operator and (const a, b: TVecU64x2): TVecU64x2;
begin
  Result := VecU64x2And(a, b);
end;

operator or (const a, b: TVecU64x2): TVecU64x2;
begin
  Result := VecU64x2Or(a, b);
end;

operator xor (const a, b: TVecU64x2): TVecU64x2;
begin
  Result := VecU64x2Xor(a, b);
end;

operator not (const a: TVecU64x2): TVecU64x2;
begin
  Result := VecU64x2Not(a);
end;

operator + (const a, b: TVecU16x8): TVecU16x8;
begin
  Result := VecU16x8Add(a, b);
end;

operator - (const a, b: TVecU16x8): TVecU16x8;
begin
  Result := VecU16x8Sub(a, b);
end;

operator * (const a, b: TVecU16x8): TVecU16x8;
begin
  Result := VecU16x8Mul(a, b);
end;

operator and (const a, b: TVecU16x8): TVecU16x8;
begin
  Result := VecU16x8And(a, b);
end;

operator or (const a, b: TVecU16x8): TVecU16x8;
begin
  Result := VecU16x8Or(a, b);
end;

operator xor (const a, b: TVecU16x8): TVecU16x8;
begin
  Result := VecU16x8Xor(a, b);
end;

operator not (const a: TVecU16x8): TVecU16x8;
begin
  Result := VecU16x8Not(a);
end;

operator + (const a, b: TVecU8x16): TVecU8x16;
begin
  Result := VecU8x16Add(a, b);
end;

operator - (const a, b: TVecU8x16): TVecU8x16;
begin
  Result := VecU8x16Sub(a, b);
end;

operator and (const a, b: TVecU8x16): TVecU8x16;
begin
  Result := VecU8x16And(a, b);
end;

operator or (const a, b: TVecU8x16): TVecU8x16;
begin
  Result := VecU8x16Or(a, b);
end;

operator xor (const a, b: TVecU8x16): TVecU8x16;
begin
  Result := VecU8x16Xor(a, b);
end;

operator not (const a: TVecU8x16): TVecU8x16;
begin
  Result := VecU8x16Not(a);
end;

operator + (const a, b: TVecU32x8): TVecU32x8;
begin
  Result := VecU32x8Add(a, b);
end;

operator - (const a, b: TVecU32x8): TVecU32x8;
begin
  Result := VecU32x8Sub(a, b);
end;

operator * (const a, b: TVecU32x8): TVecU32x8;
begin
  Result := VecU32x8Mul(a, b);
end;

operator and (const a, b: TVecU32x8): TVecU32x8;
begin
  Result := VecU32x8And(a, b);
end;

operator or (const a, b: TVecU32x8): TVecU32x8;
begin
  Result := VecU32x8Or(a, b);
end;

operator xor (const a, b: TVecU32x8): TVecU32x8;
begin
  Result := VecU32x8Xor(a, b);
end;

operator not (const a: TVecU32x8): TVecU32x8;
begin
  Result := VecU32x8Not(a);
end;

operator + (const a, b: TVecU64x4): TVecU64x4;
begin
  Result := VecU64x4Add(a, b);
end;

operator - (const a, b: TVecU64x4): TVecU64x4;
begin
  Result := VecU64x4Sub(a, b);
end;

operator and (const a, b: TVecU64x4): TVecU64x4;
begin
  Result := VecU64x4And(a, b);
end;

operator or (const a, b: TVecU64x4): TVecU64x4;
begin
  Result := VecU64x4Or(a, b);
end;

operator xor (const a, b: TVecU64x4): TVecU64x4;
begin
  Result := VecU64x4Xor(a, b);
end;

operator not (const a: TVecU64x4): TVecU64x4;
begin
  Result := VecU64x4Not(a);
end;

operator + (const a, b: TVecU32x16): TVecU32x16;
begin
  Result := VecU32x16Add(a, b);
end;

operator - (const a, b: TVecU32x16): TVecU32x16;
begin
  Result := VecU32x16Sub(a, b);
end;

operator * (const a, b: TVecU32x16): TVecU32x16;
begin
  Result := VecU32x16Mul(a, b);
end;

operator and (const a, b: TVecU32x16): TVecU32x16;
begin
  Result := VecU32x16And(a, b);
end;

operator or (const a, b: TVecU32x16): TVecU32x16;
begin
  Result := VecU32x16Or(a, b);
end;

operator xor (const a, b: TVecU32x16): TVecU32x16;
begin
  Result := VecU32x16Xor(a, b);
end;

operator not (const a: TVecU32x16): TVecU32x16;
begin
  Result := VecU32x16Not(a);
end;

operator + (const a, b: TVecU64x8): TVecU64x8;
begin
  Result := VecU64x8Add(a, b);
end;

operator - (const a, b: TVecU64x8): TVecU64x8;
begin
  Result := VecU64x8Sub(a, b);
end;

operator and (const a, b: TVecU64x8): TVecU64x8;
begin
  Result := VecU64x8And(a, b);
end;

operator or (const a, b: TVecU64x8): TVecU64x8;
begin
  Result := VecU64x8Or(a, b);
end;

operator xor (const a, b: TVecU64x8): TVecU64x8;
begin
  Result := VecU64x8Xor(a, b);
end;

operator not (const a: TVecU64x8): TVecU64x8;
begin
  Result := VecU64x8Not(a);
end;

operator + (const a, b: TVecU8x64): TVecU8x64;
begin
  Result := VecU8x64Add(a, b);
end;

operator - (const a, b: TVecU8x64): TVecU8x64;
begin
  Result := VecU8x64Sub(a, b);
end;

operator and (const a, b: TVecU8x64): TVecU8x64;
begin
  Result := VecU8x64And(a, b);
end;

operator or (const a, b: TVecU8x64): TVecU8x64;
begin
  Result := VecU8x64Or(a, b);
end;

operator xor (const a, b: TVecU8x64): TVecU8x64;
begin
  Result := VecU8x64Xor(a, b);
end;

operator not (const a: TVecU8x64): TVecU8x64;
begin
  Result := VecU8x64Not(a);
end;
{$POP}

function VecI32x4Mul(const a, b: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MulI32x4) then
    Result := dispatch^.MulI32x4(a, b)
  else
  begin
    Result.i[0] := a.i[0] * b.i[0];
    Result.i[1] := a.i[1] * b.i[1];
    Result.i[2] := a.i[2] * b.i[2];
    Result.i[3] := a.i[3] * b.i[3];
  end;
end;

function VecI32x4And(const a, b: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndI32x4) then
    Result := dispatch^.AndI32x4(a, b)
  else
  begin
    Result.i[0] := a.i[0] and b.i[0];
    Result.i[1] := a.i[1] and b.i[1];
    Result.i[2] := a.i[2] and b.i[2];
    Result.i[3] := a.i[3] and b.i[3];
  end;
end;

function VecI32x4Or(const a, b: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.OrI32x4) then
    Result := dispatch^.OrI32x4(a, b)
  else
  begin
    Result.i[0] := a.i[0] or b.i[0];
    Result.i[1] := a.i[1] or b.i[1];
    Result.i[2] := a.i[2] or b.i[2];
    Result.i[3] := a.i[3] or b.i[3];
  end;
end;

function VecI32x4Xor(const a, b: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.XorI32x4) then
    Result := dispatch^.XorI32x4(a, b)
  else
  begin
    Result.i[0] := a.i[0] xor b.i[0];
    Result.i[1] := a.i[1] xor b.i[1];
    Result.i[2] := a.i[2] xor b.i[2];
    Result.i[3] := a.i[3] xor b.i[3];
  end;
end;

function VecI32x4Not(const a: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.NotI32x4) then
    Result := dispatch^.NotI32x4(a)
  else
  begin
    Result.i[0] := not a.i[0];
    Result.i[1] := not a.i[1];
    Result.i[2] := not a.i[2];
    Result.i[3] := not a.i[3];
  end;
end;

function VecI32x4AndNot(const a, b: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndNotI32x4) then
    Result := dispatch^.AndNotI32x4(a, b)
  else
  begin
    Result.i[0] := (not a.i[0]) and b.i[0];
    Result.i[1] := (not a.i[1]) and b.i[1];
    Result.i[2] := (not a.i[2]) and b.i[2];
    Result.i[3] := (not a.i[3]) and b.i[3];
  end;
end;

function VecI32x4ShiftLeft(const a: TVecI32x4; count: Integer): TVecI32x4;
var dispatch: PSimdDispatchTable;
    LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 32 then
  begin
    Result.i[0] := 0;
    Result.i[1] := 0;
    Result.i[2] := 0;
    Result.i[3] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftLeftI32x4) then
    Result := dispatch^.ShiftLeftI32x4(a, LCount)
  else
  begin
    Result.i[0] := a.i[0] shl LCount;
    Result.i[1] := a.i[1] shl LCount;
    Result.i[2] := a.i[2] shl LCount;
    Result.i[3] := a.i[3] shl LCount;
  end;
end;

function VecI32x4ShiftRight(const a: TVecI32x4; count: Integer): TVecI32x4;
var dispatch: PSimdDispatchTable;
    LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 32 then
  begin
    Result.i[0] := 0;
    Result.i[1] := 0;
    Result.i[2] := 0;
    Result.i[3] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftRightI32x4) then
    Result := dispatch^.ShiftRightI32x4(a, LCount)
  else
  begin
    // Logical shift (unsigned)
    Result.i[0] := Int32(UInt32(a.i[0]) shr LCount);
    Result.i[1] := Int32(UInt32(a.i[1]) shr LCount);
    Result.i[2] := Int32(UInt32(a.i[2]) shr LCount);
    Result.i[3] := Int32(UInt32(a.i[3]) shr LCount);
  end;
end;

function VecI32x4ShiftRightArith(const a: TVecI32x4; count: Integer): TVecI32x4;
var dispatch: PSimdDispatchTable;
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
    if a.i[0] < 0 then Result.i[0] := -1 else Result.i[0] := 0;
    if a.i[1] < 0 then Result.i[1] := -1 else Result.i[1] := 0;
    if a.i[2] < 0 then Result.i[2] := -1 else Result.i[2] := 0;
    if a.i[3] < 0 then Result.i[3] := -1 else Result.i[3] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftRightArithI32x4) then
    Result := dispatch^.ShiftRightArithI32x4(a, LCount)
  else
  begin
    // Arithmetic shift (signed)
    Result.i[0] := SarLongint(a.i[0], LCount);
    Result.i[1] := SarLongint(a.i[1], LCount);
    Result.i[2] := SarLongint(a.i[2], LCount);
    Result.i[3] := SarLongint(a.i[3], LCount);
  end;
end;

function VecI32x4CmpEq(const a, b: TVecI32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpEqI32x4) then
    Result := dispatch^.CmpEqI32x4(a, b)
  else
  begin
    Result := 0;
    if a.i[0] = b.i[0] then Result := Result or 1;
    if a.i[1] = b.i[1] then Result := Result or 2;
    if a.i[2] = b.i[2] then Result := Result or 4;
    if a.i[3] = b.i[3] then Result := Result or 8;
  end;
end;

function VecI32x4CmpLt(const a, b: TVecI32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLtI32x4) then
    Result := dispatch^.CmpLtI32x4(a, b)
  else
  begin
    Result := 0;
    if a.i[0] < b.i[0] then Result := Result or 1;
    if a.i[1] < b.i[1] then Result := Result or 2;
    if a.i[2] < b.i[2] then Result := Result or 4;
    if a.i[3] < b.i[3] then Result := Result or 8;
  end;
end;

function VecI32x4CmpGt(const a, b: TVecI32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGtI32x4) then
    Result := dispatch^.CmpGtI32x4(a, b)
  else
  begin
    Result := 0;
    if a.i[0] > b.i[0] then Result := Result or 1;
    if a.i[1] > b.i[1] then Result := Result or 2;
    if a.i[2] > b.i[2] then Result := Result or 4;
    if a.i[3] > b.i[3] then Result := Result or 8;
  end;
end;

// 添加 I32x4 缺失比较函数
function VecI32x4CmpLe(const a, b: TVecI32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLeI32x4) then
    Result := dispatch^.CmpLeI32x4(a, b)
  else
  begin
    Result := 0;
    if a.i[0] <= b.i[0] then Result := Result or 1;
    if a.i[1] <= b.i[1] then Result := Result or 2;
    if a.i[2] <= b.i[2] then Result := Result or 4;
    if a.i[3] <= b.i[3] then Result := Result or 8;
  end;
end;

function VecI32x4CmpGe(const a, b: TVecI32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGeI32x4) then
    Result := dispatch^.CmpGeI32x4(a, b)
  else
  begin
    Result := 0;
    if a.i[0] >= b.i[0] then Result := Result or 1;
    if a.i[1] >= b.i[1] then Result := Result or 2;
    if a.i[2] >= b.i[2] then Result := Result or 4;
    if a.i[3] >= b.i[3] then Result := Result or 8;
  end;
end;

function VecI32x4CmpNe(const a, b: TVecI32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpNeI32x4) then
    Result := dispatch^.CmpNeI32x4(a, b)
  else
  begin
    Result := 0;
    if a.i[0] <> b.i[0] then Result := Result or 1;
    if a.i[1] <> b.i[1] then Result := Result or 2;
    if a.i[2] <> b.i[2] then Result := Result or 4;
    if a.i[3] <> b.i[3] then Result := Result or 8;
  end;
end;

function VecI32x4Min(const a, b: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MinI32x4) then
    Result := dispatch^.MinI32x4(a, b)
  else
  begin
    for i := 0 to 3 do
      if a.i[i] < b.i[i] then
        Result.i[i] := a.i[i]
      else
        Result.i[i] := b.i[i];
  end;
end;

function VecI32x4Max(const a, b: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MaxI32x4) then
    Result := dispatch^.MaxI32x4(a, b)
  else
  begin
    for i := 0 to 3 do
      if a.i[i] > b.i[i] then
        Result.i[i] := a.i[i]
      else
        Result.i[i] := b.i[i];
  end;
end;

