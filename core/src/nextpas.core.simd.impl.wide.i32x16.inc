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
