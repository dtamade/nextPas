// === I64x8 Operations Implementation ===

function VecI64x8Add(const a, b: TVecI64x8): TVecI64x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.AddI64x8) then
    Result := LDispatch^.CoreVectors.AddI64x8(a, b)
  else
  begin
    for LIndex := 0 to 7 do
      Result.i[LIndex] := a.i[LIndex] + b.i[LIndex];
  end;
end;

function VecI64x8Sub(const a, b: TVecI64x8): TVecI64x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.SubI64x8) then
    Result := LDispatch^.CoreVectors.SubI64x8(a, b)
  else
  begin
    for LIndex := 0 to 7 do
      Result.i[LIndex] := a.i[LIndex] - b.i[LIndex];
  end;
end;

function VecI64x8And(const a, b: TVecI64x8): TVecI64x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.AndI64x8) then
    Result := LDispatch^.CoreVectors.AndI64x8(a, b)
  else
  begin
    for LIndex := 0 to 7 do
      Result.i[LIndex] := a.i[LIndex] and b.i[LIndex];
  end;
end;

function VecI64x8Or(const a, b: TVecI64x8): TVecI64x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.OrI64x8) then
    Result := LDispatch^.CoreVectors.OrI64x8(a, b)
  else
  begin
    for LIndex := 0 to 7 do
      Result.i[LIndex] := a.i[LIndex] or b.i[LIndex];
  end;
end;

function VecI64x8Xor(const a, b: TVecI64x8): TVecI64x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.XorI64x8) then
    Result := LDispatch^.CoreVectors.XorI64x8(a, b)
  else
  begin
    for LIndex := 0 to 7 do
      Result.i[LIndex] := a.i[LIndex] xor b.i[LIndex];
  end;
end;

function VecI64x8Not(const a: TVecI64x8): TVecI64x8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.NotI64x8) then
    Result := LDispatch^.CoreVectors.NotI64x8(a)
  else
  begin
    for LIndex := 0 to 7 do
      Result.i[LIndex] := not a.i[LIndex];
  end;
end;

function VecI64x8CmpEq(const a, b: TVecI64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.CmpEqI64x8) then
    Result := LDispatch^.CoreVectors.CmpEqI64x8(a, b)
  else
  begin
    Result := 0;
    for LIndex := 0 to 7 do
      if a.i[LIndex] = b.i[LIndex] then
        Result := Result or (1 shl LIndex);
  end;
end;

function VecI64x8CmpLt(const a, b: TVecI64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.CmpLtI64x8) then
    Result := LDispatch^.CoreVectors.CmpLtI64x8(a, b)
  else
  begin
    Result := 0;
    for LIndex := 0 to 7 do
      if a.i[LIndex] < b.i[LIndex] then
        Result := Result or (1 shl LIndex);
  end;
end;

function VecI64x8CmpGt(const a, b: TVecI64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.CmpGtI64x8) then
    Result := LDispatch^.CoreVectors.CmpGtI64x8(a, b)
  else
  begin
    Result := 0;
    for LIndex := 0 to 7 do
      if a.i[LIndex] > b.i[LIndex] then
        Result := Result or (1 shl LIndex);
  end;
end;

function VecI64x8CmpLe(const a, b: TVecI64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.CmpLeI64x8) then
    Result := LDispatch^.CoreVectors.CmpLeI64x8(a, b)
  else
  begin
    Result := 0;
    for LIndex := 0 to 7 do
      if a.i[LIndex] <= b.i[LIndex] then
        Result := Result or (1 shl LIndex);
  end;
end;

function VecI64x8CmpGe(const a, b: TVecI64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.CmpGeI64x8) then
    Result := LDispatch^.CoreVectors.CmpGeI64x8(a, b)
  else
  begin
    Result := 0;
    for LIndex := 0 to 7 do
      if a.i[LIndex] >= b.i[LIndex] then
        Result := Result or (1 shl LIndex);
  end;
end;

function VecI64x8CmpNe(const a, b: TVecI64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CoreVectors.CmpNeI64x8) then
    Result := LDispatch^.CoreVectors.CmpNeI64x8(a, b)
  else
  begin
    Result := 0;
    for LIndex := 0 to 7 do
      if a.i[LIndex] <> b.i[LIndex] then
        Result := Result or (1 shl LIndex);
  end;
end;

function VecU32x16Add(const a, b: TVecU32x16): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.AddU32x16(a, b);
end;

function VecU32x16Sub(const a, b: TVecU32x16): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.SubU32x16(a, b);
end;

function VecU32x16Mul(const a, b: TVecU32x16): TVecU32x16;
var
  LFunc: TVecU32x16MulFunc;
begin
  LFunc := TVecU32x16MulFunc(LoadSimdFacadeFastPath(g_FastVecU32x16MulPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecU32x16MulFunc(LoadSimdFacadeFastPath(g_FastVecU32x16MulPtr));
  end;
  Result := LFunc(a, b);
end;

function VecU32x16And(const a, b: TVecU32x16): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.AndU32x16(a, b);
end;

function VecU32x16Or(const a, b: TVecU32x16): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.OrU32x16(a, b);
end;

function VecU32x16Xor(const a, b: TVecU32x16): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.XorU32x16(a, b);
end;

function VecU32x16Not(const a: TVecU32x16): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.NotU32x16(a);
end;

function VecU32x16AndNot(const a, b: TVecU32x16): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.AndNotU32x16(a, b);
end;

function VecU32x16ShiftLeft(const a: TVecU32x16; count: Integer): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.ShiftLeftU32x16(a, count);
end;

function VecU32x16ShiftRight(const a: TVecU32x16; count: Integer): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.ShiftRightU32x16(a, count);
end;

function VecU32x16CmpEq(const a, b: TVecU32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpEqU32x16(a, b);
end;

function VecU32x16CmpLt(const a, b: TVecU32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpLtU32x16(a, b);
end;

function VecU32x16CmpGt(const a, b: TVecU32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpGtU32x16(a, b);
end;

function VecU32x16CmpLe(const a, b: TVecU32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpLeU32x16(a, b);
end;

function VecU32x16CmpGe(const a, b: TVecU32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpGeU32x16(a, b);
end;

function VecU32x16CmpNe(const a, b: TVecU32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpNeU32x16(a, b);
end;

function VecU32x16Min(const a, b: TVecU32x16): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.MinU32x16(a, b);
end;

function VecU32x16Max(const a, b: TVecU32x16): TVecU32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.MaxU32x16(a, b);
end;

function VecU64x8Add(const a, b: TVecU64x8): TVecU64x8;
var
  LFunc: TVecU64x8AddFunc;
begin
  LFunc := TVecU64x8AddFunc(LoadSimdFacadeFastPath(g_FastVecU64x8AddPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecU64x8AddFunc(LoadSimdFacadeFastPath(g_FastVecU64x8AddPtr));
  end;
  Result := LFunc(a, b);
end;

function VecU64x8Sub(const a, b: TVecU64x8): TVecU64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.SubU64x8(a, b);
end;

function VecU64x8And(const a, b: TVecU64x8): TVecU64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.AndU64x8(a, b);
end;

function VecU64x8Or(const a, b: TVecU64x8): TVecU64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.OrU64x8(a, b);
end;

function VecU64x8Xor(const a, b: TVecU64x8): TVecU64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.XorU64x8(a, b);
end;

function VecU64x8Not(const a: TVecU64x8): TVecU64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.NotU64x8(a);
end;

function VecU64x8ShiftLeft(const a: TVecU64x8; count: Integer): TVecU64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.ShiftLeftU64x8(a, count);
end;

function VecU64x8ShiftRight(const a: TVecU64x8; count: Integer): TVecU64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.ShiftRightU64x8(a, count);
end;

function VecU64x8CmpEq(const a, b: TVecU64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpEqU64x8(a, b);
end;

function VecU64x8CmpLt(const a, b: TVecU64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpLtU64x8(a, b);
end;

function VecU64x8CmpGt(const a, b: TVecU64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpGtU64x8(a, b);
end;

function VecU64x8CmpLe(const a, b: TVecU64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpLeU64x8(a, b);
end;

function VecU64x8CmpGe(const a, b: TVecU64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpGeU64x8(a, b);
end;

function VecU64x8CmpNe(const a, b: TVecU64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpNeU64x8(a, b);
end;

function VecI16x32Add(const a, b: TVecI16x32): TVecI16x32; inline;
var
  LFunc: TVecI16x32AddFunc;
begin
  LFunc := TVecI16x32AddFunc(LoadSimdFacadeFastPath(g_FastVecI16x32AddPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecI16x32AddFunc(LoadSimdFacadeFastPath(g_FastVecI16x32AddPtr));
  end;
  Result := LFunc(a, b);
end;

function VecI16x32Sub(const a, b: TVecI16x32): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.SubI16x32(a, b);
end;

function VecI16x32And(const a, b: TVecI16x32): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.AndI16x32(a, b);
end;

function VecI16x32Or(const a, b: TVecI16x32): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.OrI16x32(a, b);
end;

function VecI16x32Xor(const a, b: TVecI16x32): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.XorI16x32(a, b);
end;

function VecI16x32Not(const a: TVecI16x32): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.NotI16x32(a);
end;

function VecI16x32AndNot(const a, b: TVecI16x32): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.AndNotI16x32(a, b);
end;

function VecI16x32ShiftLeft(const a: TVecI16x32; count: Integer): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.ShiftLeftI16x32(a, count);
end;

function VecI16x32ShiftRight(const a: TVecI16x32; count: Integer): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.ShiftRightI16x32(a, count);
end;

function VecI16x32ShiftRightArith(const a: TVecI16x32; count: Integer): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.ShiftRightArithI16x32(a, count);
end;

function VecI16x32CmpEq(const a, b: TVecI16x32): TMask32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpEqI16x32(a, b);
end;

function VecI16x32CmpLt(const a, b: TVecI16x32): TMask32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpLtI16x32(a, b);
end;

function VecI16x32CmpGt(const a, b: TVecI16x32): TMask32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpGtI16x32(a, b);
end;

function VecI16x32CmpLe(const a, b: TVecI16x32): TMask32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpLeI16x32(a, b);
end;

function VecI16x32CmpGe(const a, b: TVecI16x32): TMask32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpGeI16x32(a, b);
end;

function VecI16x32CmpNe(const a, b: TVecI16x32): TMask32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpNeI16x32(a, b);
end;

function VecI16x32Min(const a, b: TVecI16x32): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.MinI16x32(a, b);
end;

function VecI16x32Max(const a, b: TVecI16x32): TVecI16x32;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.MaxI16x32(a, b);
end;

function VecI8x64Add(const a, b: TVecI8x64): TVecI8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.AddI8x64(a, b);
end;

function VecI8x64Sub(const a, b: TVecI8x64): TVecI8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.SubI8x64(a, b);
end;

function VecI8x64And(const a, b: TVecI8x64): TVecI8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.AndI8x64(a, b);
end;

function VecI8x64Or(const a, b: TVecI8x64): TVecI8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.OrI8x64(a, b);
end;

function VecI8x64Xor(const a, b: TVecI8x64): TVecI8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.XorI8x64(a, b);
end;

function VecI8x64Not(const a: TVecI8x64): TVecI8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.NotI8x64(a);
end;

function VecI8x64AndNot(const a, b: TVecI8x64): TVecI8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.AndNotI8x64(a, b);
end;

function VecI8x64CmpEq(const a, b: TVecI8x64): TMask64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpEqI8x64(a, b);
end;

function VecI8x64CmpLt(const a, b: TVecI8x64): TMask64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpLtI8x64(a, b);
end;

function VecI8x64CmpGt(const a, b: TVecI8x64): TMask64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpGtI8x64(a, b);
end;

function VecI8x64CmpLe(const a, b: TVecI8x64): TMask64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpLeI8x64(a, b);
end;

function VecI8x64CmpGe(const a, b: TVecI8x64): TMask64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpGeI8x64(a, b);
end;

function VecI8x64CmpNe(const a, b: TVecI8x64): TMask64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpNeI8x64(a, b);
end;

function VecI8x64Min(const a, b: TVecI8x64): TVecI8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.MinI8x64(a, b);
end;

function VecI8x64Max(const a, b: TVecI8x64): TVecI8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.MaxI8x64(a, b);
end;

function VecU8x64Add(const a, b: TVecU8x64): TVecU8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.AddU8x64(a, b);
end;

function VecU8x64Sub(const a, b: TVecU8x64): TVecU8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.SubU8x64(a, b);
end;

function VecU8x64And(const a, b: TVecU8x64): TVecU8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.AndU8x64(a, b);
end;

function VecU8x64Or(const a, b: TVecU8x64): TVecU8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.OrU8x64(a, b);
end;

function VecU8x64Xor(const a, b: TVecU8x64): TVecU8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.XorU8x64(a, b);
end;

function VecU8x64Not(const a: TVecU8x64): TVecU8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.NotU8x64(a);
end;

function VecU8x64CmpEq(const a, b: TVecU8x64): TMask64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpEqU8x64(a, b);
end;

function VecU8x64CmpLt(const a, b: TVecU8x64): TMask64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpLtU8x64(a, b);
end;

function VecU8x64CmpGt(const a, b: TVecU8x64): TMask64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpGtU8x64(a, b);
end;

function VecU8x64CmpLe(const a, b: TVecU8x64): TMask64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpLeU8x64(a, b);
end;

function VecU8x64CmpGe(const a, b: TVecU8x64): TMask64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpGeU8x64(a, b);
end;

function VecU8x64CmpNe(const a, b: TVecU8x64): TMask64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.CmpNeU8x64(a, b);
end;

function VecU8x64Min(const a, b: TVecU8x64): TVecU8x64;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CoreVectors.MinU8x64(a, b);
end;

function VecU8x64Max(const a, b: TVecU8x64): TVecU8x64; inline;
var
  LFunc: TVecU8x64MaxFunc;
begin
  LFunc := TVecU8x64MaxFunc(LoadSimdFacadeFastPath(g_FastVecU8x64MaxPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecU8x64MaxFunc(LoadSimdFacadeFastPath(g_FastVecU8x64MaxPtr));
  end;
  Result := LFunc(a, b);
end;

