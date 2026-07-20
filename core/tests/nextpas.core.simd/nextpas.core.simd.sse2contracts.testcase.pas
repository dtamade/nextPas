unit nextpas.core.simd.sse2contracts.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

interface

uses
  nextpas.core.text.conv, nextpas.core.test, nextpas.core.simd,
  nextpas.core.simd.testcase, nextpas.core.simd.base,
  nextpas.core.simd.dispatch, nextpas.core.simd.scalar;

type
  TTestCase_SSE2Contracts = class(TSimdVectorAsmStatefulTestCase)
  protected
    function TryLoadSSE2AndScalarTables(out aSSE2Table, aScalarTable: TSimdDispatchTable): Boolean;
    procedure AssertVecF32x16Equals(const aMessage: string; const aExpected, aActual: TVecF32x16; aDelta: Single = 0.0);
    procedure AssertVecF64x8Equals(const aMessage: string; const aExpected, aActual: TVecF64x8; aDelta: Double = 0.0);
    procedure AssertVecI32x16Equals(const aMessage: string; const aExpected, aActual: TVecI32x16);
    procedure AssertVecI64x4Equals(const aMessage: string; const aExpected, aActual: TVecI64x4);
    procedure AssertVecU32x8Equals(const aMessage: string; const aExpected, aActual: TVecU32x8);
    procedure AssertVecU64x4Equals(const aMessage: string; const aExpected, aActual: TVecU64x4);
    procedure AssertVecI64x8Equals(const aMessage: string; const aExpected, aActual: TVecI64x8);
    procedure AssertByteArrayEquals(const aMessage: string; const aExpected, aActual: array of Byte);
  published
    procedure Test_SSE2_WideFloatSlots_Stay_BackendOwned_And_Keep_ScalarParity;
    procedure Test_SSE2_WideIntegerSlots_Stay_BackendOwned_And_Keep_ScalarParity;
    procedure Test_SSE2_NarrowI64U64ScalarReuseSlots_Stay_On_BaseScalar;
    procedure Test_SSE2_FacadeSlots_Stay_BackendOwned_And_Keep_ScalarParity;
    procedure Test_SSE2_VectorAsmRoundTrip_Rebuild_Preserves_Representative_Bindings;
  end;

implementation

function TTestCase_SSE2Contracts.TryLoadSSE2AndScalarTables(out aSSE2Table, aScalarTable: TSimdDispatchTable): Boolean;
begin
  Result := TryGetRegisteredBackendDispatchTable(sbSSE2, aSSE2Table)
    and TryGetRegisteredBackendDispatchTable(sbScalar, aScalarTable);
  if not Result then
    Exit(False);
  Result := aSSE2Table.BackendInfo.Available;
end;

procedure TTestCase_SSE2Contracts.AssertVecF32x16Equals(const aMessage: string; const aExpected, aActual: TVecF32x16; aDelta: Single);
var
  LIndex: Integer;
begin
  for LIndex := 0 to 15 do
    CheckNear(aExpected.f[LIndex], aActual.f[LIndex], aDelta, aMessage + ' lane ' + IntToStr(LIndex));
end;

procedure TTestCase_SSE2Contracts.AssertVecF64x8Equals(const aMessage: string; const aExpected, aActual: TVecF64x8; aDelta: Double);
var
  LIndex: Integer;
begin
  for LIndex := 0 to 7 do
    CheckNear(aExpected.d[LIndex], aActual.d[LIndex], aDelta, aMessage + ' lane ' + IntToStr(LIndex));
end;

procedure TTestCase_SSE2Contracts.AssertVecI32x16Equals(const aMessage: string; const aExpected, aActual: TVecI32x16);
var
  LIndex: Integer;
begin
  for LIndex := 0 to 15 do
    CheckEqual(aExpected.i[LIndex], aActual.i[LIndex], aMessage + ' lane ' + IntToStr(LIndex));
end;

procedure TTestCase_SSE2Contracts.AssertVecI64x4Equals(const aMessage: string; const aExpected, aActual: TVecI64x4);
var
  LIndex: Integer;
begin
  for LIndex := 0 to 3 do
    CheckEqual(aExpected.i[LIndex], aActual.i[LIndex], aMessage + ' lane ' + IntToStr(LIndex));
end;

procedure TTestCase_SSE2Contracts.AssertVecU32x8Equals(const aMessage: string; const aExpected, aActual: TVecU32x8);
var
  LIndex: Integer;
begin
  for LIndex := 0 to 7 do
    CheckEqual(aExpected.u[LIndex], aActual.u[LIndex], aMessage + ' lane ' + IntToStr(LIndex));
end;

procedure TTestCase_SSE2Contracts.AssertVecU64x4Equals(const aMessage: string; const aExpected, aActual: TVecU64x4);
var
  LIndex: Integer;
begin
  for LIndex := 0 to 3 do
    CheckEqual(QWord(aExpected.u[LIndex]), QWord(aActual.u[LIndex]), aMessage + ' lane ' + IntToStr(LIndex));
end;

procedure TTestCase_SSE2Contracts.AssertVecI64x8Equals(const aMessage: string; const aExpected, aActual: TVecI64x8);
var
  LIndex: Integer;
begin
  for LIndex := 0 to 7 do
    CheckEqual(aExpected.i[LIndex], aActual.i[LIndex], aMessage + ' lane ' + IntToStr(LIndex));
end;

procedure TTestCase_SSE2Contracts.AssertByteArrayEquals(const aMessage: string; const aExpected, aActual: array of Byte);
var
  LIndex: Integer;
begin
  CheckEqual(Length(aExpected), Length(aActual), aMessage + ' length');
  for LIndex := 0 to High(aExpected) do
    CheckEqual(aExpected[LIndex], aActual[LIndex], aMessage + ' byte ' + IntToStr(LIndex));
end;

procedure TTestCase_SSE2Contracts.Test_SSE2_WideFloatSlots_Stay_BackendOwned_And_Keep_ScalarParity;
var
  LSSE2Table: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LF32A, LF32B, LF32C: TVecF32x16;
  LF64A, LF64B, LF64C: TVecF64x8;
  LExpectedF32, LActualF32: TVecF32x16;
  LExpectedF64, LActualF64: TVecF64x8;
  LMask16: TMask16;
  LMask8: TMask8;
  LSourceF32, LStoreF32SSE2, LStoreF32Scalar: array[0..15] of Single;
  LSourceF64, LStoreF64SSE2, LStoreF64Scalar: array[0..7] of Double;
  LIndex: Integer;
begin
  if not TryLoadSSE2AndScalarTables(LSSE2Table, LScalarTable) then
    Exit;

  CheckTrue(Assigned(LSSE2Table.CoreVectors.AddF32x16), 'SSE2 AddF32x16 should be assigned');
  CheckTrue(Assigned(LSSE2Table.CoreVectors.FmaF32x16), 'SSE2 FmaF32x16 should be assigned');
  CheckTrue(Assigned(LSSE2Table.CoreVectors.SelectF32x16), 'SSE2 SelectF32x16 should be assigned');
  CheckTrue(Assigned(LSSE2Table.CoreVectors.AddF64x8), 'SSE2 AddF64x8 should be assigned');
  CheckTrue(Assigned(LSSE2Table.CoreVectors.FmaF64x8), 'SSE2 FmaF64x8 should be assigned');
  CheckTrue(Assigned(LSSE2Table.CoreVectors.SelectF64x8), 'SSE2 SelectF64x8 should be assigned');

  CheckTrue(Pointer(LSSE2Table.CoreVectors.AddF32x16) <> Pointer(LScalarTable.CoreVectors.AddF32x16), 'SSE2 AddF32x16 should leave scalar slot');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.FmaF32x16) <> Pointer(LScalarTable.CoreVectors.FmaF32x16), 'SSE2 FmaF32x16 should leave scalar slot');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.SelectF32x16) <> Pointer(LScalarTable.CoreVectors.SelectF32x16), 'SSE2 SelectF32x16 should leave scalar slot');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.AddF64x8) <> Pointer(LScalarTable.CoreVectors.AddF64x8), 'SSE2 AddF64x8 should leave scalar slot');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.FmaF64x8) <> Pointer(LScalarTable.CoreVectors.FmaF64x8), 'SSE2 FmaF64x8 should leave scalar slot');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.SelectF64x8) <> Pointer(LScalarTable.CoreVectors.SelectF64x8), 'SSE2 SelectF64x8 should leave scalar slot');

  LMask16 := TMask16($A55A);
  LMask8 := TMask8($A5);
  for LIndex := 0 to 15 do
  begin
    LF32A.f[LIndex] := (LIndex - 6) * 0.5;
    LF32B.f[LIndex] := (LIndex and 3) + 1.0;
    LF32C.f[LIndex] := (2 - (LIndex and 3)) * 0.25;
    LSourceF32[LIndex] := LIndex + 0.125;
  end;
  for LIndex := 0 to 7 do
  begin
    LF64A.d[LIndex] := (LIndex - 3) * 0.25;
    LF64B.d[LIndex] := (LIndex and 3) + 0.5;
    LF64C.d[LIndex] := (1 - (LIndex and 1)) * 0.125;
    LSourceF64[LIndex] := LIndex + 0.0625;
  end;

  LActualF32 := LSSE2Table.CoreVectors.AddF32x16(LF32A, LF32B);
  LExpectedF32 := ScalarAddF32x16(LF32A, LF32B);
  AssertVecF32x16Equals('SSE2 AddF32x16 scalar parity', LExpectedF32, LActualF32);

  LActualF32 := LSSE2Table.CoreVectors.FmaF32x16(LF32A, LF32B, LF32C);
  LExpectedF32 := ScalarFmaF32x16(LF32A, LF32B, LF32C);
  AssertVecF32x16Equals('SSE2 FmaF32x16 scalar parity', LExpectedF32, LActualF32);

  LActualF32 := LSSE2Table.CoreVectors.SelectF32x16(LMask16, LF32A, LF32B);
  LExpectedF32 := ScalarSelectF32x16(LMask16, LF32A, LF32B);
  AssertVecF32x16Equals('SSE2 SelectF32x16 scalar parity', LExpectedF32, LActualF32);

  LActualF32 := LSSE2Table.CoreVectors.LoadF32x16(@LSourceF32[0]);
  LExpectedF32 := ScalarLoadF32x16(@LSourceF32[0]);
  AssertVecF32x16Equals('SSE2 LoadF32x16 scalar parity', LExpectedF32, LActualF32);
  LSSE2Table.CoreVectors.StoreF32x16(@LStoreF32SSE2[0], LActualF32);
  ScalarStoreF32x16(@LStoreF32Scalar[0], LExpectedF32);
  for LIndex := 0 to 15 do
    CheckNear(LStoreF32Scalar[LIndex], LStoreF32SSE2[LIndex], 0.0, 'SSE2 StoreF32x16 scalar parity lane ' + IntToStr(LIndex));

  LActualF64 := LSSE2Table.CoreVectors.AddF64x8(LF64A, LF64B);
  LExpectedF64 := ScalarAddF64x8(LF64A, LF64B);
  AssertVecF64x8Equals('SSE2 AddF64x8 scalar parity', LExpectedF64, LActualF64);

  LActualF64 := LSSE2Table.CoreVectors.FmaF64x8(LF64A, LF64B, LF64C);
  LExpectedF64 := ScalarFmaF64x8(LF64A, LF64B, LF64C);
  AssertVecF64x8Equals('SSE2 FmaF64x8 scalar parity', LExpectedF64, LActualF64);

  LActualF64 := LSSE2Table.CoreVectors.SelectF64x8(LMask8, LF64A, LF64B);
  LExpectedF64 := ScalarSelectF64x8(LMask8, LF64A, LF64B);
  AssertVecF64x8Equals('SSE2 SelectF64x8 scalar parity', LExpectedF64, LActualF64);

  LActualF64 := LSSE2Table.CoreVectors.LoadF64x8(@LSourceF64[0]);
  LExpectedF64 := ScalarLoadF64x8(@LSourceF64[0]);
  AssertVecF64x8Equals('SSE2 LoadF64x8 scalar parity', LExpectedF64, LActualF64);
  LSSE2Table.CoreVectors.StoreF64x8(@LStoreF64SSE2[0], LActualF64);
  ScalarStoreF64x8(@LStoreF64Scalar[0], LExpectedF64);
  for LIndex := 0 to 7 do
    CheckNear(LStoreF64Scalar[LIndex], LStoreF64SSE2[LIndex], 0.0, 'SSE2 StoreF64x8 scalar parity lane ' + IntToStr(LIndex));
end;

procedure TTestCase_SSE2Contracts.Test_SSE2_WideIntegerSlots_Stay_BackendOwned_And_Keep_ScalarParity;
var
  LSSE2Table: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LI32A, LI32B, LI32Expected, LI32Actual: TVecI32x16;
  LI64A, LI64B, LI64Expected, LI64Actual: TVecI64x4;
  LU32A, LU32B, LU32Expected, LU32Actual: TVecU32x8;
  LU64A, LU64B, LU64Expected, LU64Actual: TVecU64x4;
  LI64x8A, LI64x8B, LI64x8Expected, LI64x8Actual: TVecI64x8;
  LIndex: Integer;
begin
  if not TryLoadSSE2AndScalarTables(LSSE2Table, LScalarTable) then
    Exit;

  CheckTrue(Assigned(LSSE2Table.CoreVectors.AddI32x16), 'SSE2 AddI32x16 should be assigned');
  CheckTrue(Assigned(LSSE2Table.CoreVectors.AddI64x4), 'SSE2 AddI64x4 should be assigned');
  CheckTrue(Assigned(LSSE2Table.CoreVectors.AddU32x8), 'SSE2 AddU32x8 should be assigned');
  CheckTrue(Assigned(LSSE2Table.CoreVectors.AddU64x4), 'SSE2 AddU64x4 should be assigned');
  CheckTrue(Assigned(LSSE2Table.CoreVectors.AddI64x8), 'SSE2 AddI64x8 should be assigned');

  CheckTrue(Pointer(LSSE2Table.CoreVectors.AddI32x16) <> Pointer(LScalarTable.CoreVectors.AddI32x16), 'SSE2 AddI32x16 should leave scalar slot');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.AddI64x4) <> Pointer(LScalarTable.CoreVectors.AddI64x4), 'SSE2 AddI64x4 should leave scalar slot');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.AddU32x8) <> Pointer(LScalarTable.CoreVectors.AddU32x8), 'SSE2 AddU32x8 should leave scalar slot');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.AddU64x4) <> Pointer(LScalarTable.CoreVectors.AddU64x4), 'SSE2 AddU64x4 should leave scalar slot');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.AddI64x8) <> Pointer(LScalarTable.CoreVectors.AddI64x8), 'SSE2 AddI64x8 should leave scalar slot');

  for LIndex := 0 to 15 do
  begin
    LI32A.i[LIndex] := (LIndex * 37) - 150;
    LI32B.i[LIndex] := 200 - (LIndex * 11);
  end;
  LI32Actual := LSSE2Table.CoreVectors.AddI32x16(LI32A, LI32B);
  LI32Expected := ScalarAddI32x16(LI32A, LI32B);
  AssertVecI32x16Equals('SSE2 AddI32x16 scalar parity', LI32Expected, LI32Actual);
  CheckEqual(Integer(ScalarCmpNeI32x16(LI32A, LI32B)), Integer(LSSE2Table.CoreVectors.CmpNeI32x16(LI32A, LI32B)), 'SSE2 CmpNeI32x16 scalar parity');
  LI32Actual := LSSE2Table.CoreVectors.MinI32x16(LI32A, LI32B);
  LI32Expected := ScalarMinI32x16(LI32A, LI32B);
  AssertVecI32x16Equals('SSE2 MinI32x16 scalar parity', LI32Expected, LI32Actual);

  for LIndex := 0 to 3 do
  begin
    LI64A.i[LIndex] := (LIndex * 1000000000) - 17;
    LI64B.i[LIndex] := 500 - (LIndex * 23);
    LU64A.u[LIndex] := QWord(LIndex) * 987654321 + 17;
    LU64B.u[LIndex] := QWord(1000 - LIndex * 19);
  end;
  LI64Actual := LSSE2Table.CoreVectors.AddI64x4(LI64A, LI64B);
  LI64Expected := ScalarAddI64x4(LI64A, LI64B);
  AssertVecI64x4Equals('SSE2 AddI64x4 scalar parity', LI64Expected, LI64Actual);
  LI64Actual := LSSE2Table.CoreVectors.ShiftRightArithI64x4(LI64A, 3);
  LI64Expected := ScalarShiftRightArithI64x4(LI64A, 3);
  AssertVecI64x4Equals('SSE2 ShiftRightArithI64x4 scalar parity', LI64Expected, LI64Actual);
  CheckEqual(Integer(ScalarCmpLtI64x4(LI64A, LI64B)), Integer(LSSE2Table.CoreVectors.CmpLtI64x4(LI64A, LI64B)), 'SSE2 CmpLtI64x4 scalar parity');

  for LIndex := 0 to 7 do
  begin
    LU32A.u[LIndex] := DWord(LIndex) * 101 + 3;
    LU32B.u[LIndex] := DWord(400 - LIndex * 17);
    LI64x8A.i[LIndex] := (LIndex * 1000000) - 33;
    LI64x8B.i[LIndex] := (LIndex * 11) - 20;
  end;
  LU32Actual := LSSE2Table.CoreVectors.AddU32x8(LU32A, LU32B);
  LU32Expected := ScalarAddU32x8(LU32A, LU32B);
  AssertVecU32x8Equals('SSE2 AddU32x8 scalar parity', LU32Expected, LU32Actual);
  CheckEqual(Integer(ScalarCmpNeU32x8(LU32A, LU32B)), Integer(LSSE2Table.CoreVectors.CmpNeU32x8(LU32A, LU32B)), 'SSE2 CmpNeU32x8 scalar parity');
  LU32Actual := LSSE2Table.CoreVectors.MinU32x8(LU32A, LU32B);
  LU32Expected := ScalarMinU32x8(LU32A, LU32B);
  AssertVecU32x8Equals('SSE2 MinU32x8 scalar parity', LU32Expected, LU32Actual);

  LU64Actual := LSSE2Table.CoreVectors.AddU64x4(LU64A, LU64B);
  LU64Expected := ScalarAddU64x4(LU64A, LU64B);
  AssertVecU64x4Equals('SSE2 AddU64x4 scalar parity', LU64Expected, LU64Actual);
  LU64Actual := LSSE2Table.CoreVectors.ShiftRightU64x4(LU64A, 4);
  LU64Expected := ScalarShiftRightU64x4(LU64A, 4);
  AssertVecU64x4Equals('SSE2 ShiftRightU64x4 scalar parity', LU64Expected, LU64Actual);
  CheckEqual(Integer(ScalarCmpNeU64x4(LU64A, LU64B)), Integer(LSSE2Table.CoreVectors.CmpNeU64x4(LU64A, LU64B)), 'SSE2 CmpNeU64x4 scalar parity');

  LI64x8Actual := LSSE2Table.CoreVectors.AddI64x8(LI64x8A, LI64x8B);
  LI64x8Expected := ScalarAddI64x8(LI64x8A, LI64x8B);
  AssertVecI64x8Equals('SSE2 AddI64x8 scalar parity', LI64x8Expected, LI64x8Actual);
  CheckEqual(Integer(ScalarCmpNeI64x8(LI64x8A, LI64x8B)), Integer(LSSE2Table.CoreVectors.CmpNeI64x8(LI64x8A, LI64x8B)), 'SSE2 CmpNeI64x8 scalar parity');
end;

procedure TTestCase_SSE2Contracts.Test_SSE2_NarrowI64U64ScalarReuseSlots_Stay_On_BaseScalar;
var
  LSSE2Table: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aSSE2Slot: Pointer);
  begin
    CheckTrue(aSSE2Slot <> nil, 'SSE2 ' + aLabel + ' should stay assigned');
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aSSE2Slot), 'SSE2 ' + aLabel + ' should intentionally reuse the base scalar slot');
  end;
begin
  if not TryLoadSSE2AndScalarTables(LSSE2Table, LScalarTable) then
    Exit;

  AssertSlotReusesScalar('ShiftLeftI64x2', Pointer(LScalarTable.CoreVectors.ShiftLeftI64x2), Pointer(LSSE2Table.CoreVectors.ShiftLeftI64x2));
  AssertSlotReusesScalar('ShiftRightI64x2', Pointer(LScalarTable.CoreVectors.ShiftRightI64x2), Pointer(LSSE2Table.CoreVectors.ShiftRightI64x2));
  AssertSlotReusesScalar('ShiftRightArithI64x2', Pointer(LScalarTable.CoreVectors.ShiftRightArithI64x2), Pointer(LSSE2Table.CoreVectors.ShiftRightArithI64x2));
  AssertSlotReusesScalar('MinI64x2', Pointer(LScalarTable.CoreVectors.MinI64x2), Pointer(LSSE2Table.CoreVectors.MinI64x2));
  AssertSlotReusesScalar('MaxI64x2', Pointer(LScalarTable.CoreVectors.MaxI64x2), Pointer(LSSE2Table.CoreVectors.MaxI64x2));

  AssertSlotReusesScalar('AddU64x2', Pointer(LScalarTable.CoreVectors.AddU64x2), Pointer(LSSE2Table.CoreVectors.AddU64x2));
  AssertSlotReusesScalar('SubU64x2', Pointer(LScalarTable.CoreVectors.SubU64x2), Pointer(LSSE2Table.CoreVectors.SubU64x2));
  AssertSlotReusesScalar('AndU64x2', Pointer(LScalarTable.CoreVectors.AndU64x2), Pointer(LSSE2Table.CoreVectors.AndU64x2));
  AssertSlotReusesScalar('OrU64x2', Pointer(LScalarTable.CoreVectors.OrU64x2), Pointer(LSSE2Table.CoreVectors.OrU64x2));
  AssertSlotReusesScalar('XorU64x2', Pointer(LScalarTable.CoreVectors.XorU64x2), Pointer(LSSE2Table.CoreVectors.XorU64x2));
  AssertSlotReusesScalar('NotU64x2', Pointer(LScalarTable.CoreVectors.NotU64x2), Pointer(LSSE2Table.CoreVectors.NotU64x2));
  AssertSlotReusesScalar('AndNotU64x2', Pointer(LScalarTable.CoreVectors.AndNotU64x2), Pointer(LSSE2Table.CoreVectors.AndNotU64x2));
  AssertSlotReusesScalar('CmpEqU64x2', Pointer(LScalarTable.CoreVectors.CmpEqU64x2), Pointer(LSSE2Table.CoreVectors.CmpEqU64x2));
  AssertSlotReusesScalar('CmpLtU64x2', Pointer(LScalarTable.CoreVectors.CmpLtU64x2), Pointer(LSSE2Table.CoreVectors.CmpLtU64x2));
  AssertSlotReusesScalar('CmpGtU64x2', Pointer(LScalarTable.CoreVectors.CmpGtU64x2), Pointer(LSSE2Table.CoreVectors.CmpGtU64x2));
  AssertSlotReusesScalar('MinU64x2', Pointer(LScalarTable.CoreVectors.MinU64x2), Pointer(LSSE2Table.CoreVectors.MinU64x2));
  AssertSlotReusesScalar('MaxU64x2', Pointer(LScalarTable.CoreVectors.MaxU64x2), Pointer(LSSE2Table.CoreVectors.MaxU64x2));
end;

procedure TTestCase_SSE2Contracts.Test_SSE2_FacadeSlots_Stay_BackendOwned_And_Keep_ScalarParity;
var
  LSSE2Table: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LBufA, LBufB, LRevSSE2, LRevScalar: array[0..31] of Byte;
  LValidUtf8: array[0..6] of Byte;
  LInvalidUtf8: array[0..2] of Byte;
  LLowerSSE2, LLowerScalar: AnsiString;
  LUpperSSE2, LUpperScalar: AnsiString;
  LCaseA, LCaseB: AnsiString;
  LHaystack: AnsiString;
  LNeedle: AnsiString;
  LFirstSSE2, LLastSSE2: SizeUInt;
  LFirstScalar, LLastScalar: SizeUInt;
  LBoolSSE2, LBoolScalar: Boolean;
  LIndex: Integer;
begin
  if not TryLoadSSE2AndScalarTables(LSSE2Table, LScalarTable) then
    Exit;

  CheckTrue(Assigned(LSSE2Table.Memory.DiffRange), 'SSE2 MemDiffRange should be assigned');
  CheckTrue(Assigned(LSSE2Table.Memory.Reverse), 'SSE2 MemReverse should be assigned');
  CheckTrue(Assigned(LSSE2Table.Memory.ToLowerAscii), 'SSE2 ToLowerAscii should be assigned');
  CheckTrue(Assigned(LSSE2Table.Memory.ToUpperAscii), 'SSE2 ToUpperAscii should be assigned');
  CheckTrue(Assigned(LSSE2Table.Memory.AsciiIEqual), 'SSE2 AsciiIEqual should be assigned');
  CheckTrue(Assigned(LSSE2Table.Memory.BytesIndexOf), 'SSE2 BytesIndexOf should be assigned');
  CheckTrue(Assigned(LSSE2Table.Memory.Utf8Validate), 'SSE2 Utf8Validate should be assigned');

  CheckTrue(Pointer(LSSE2Table.Memory.DiffRange) <> Pointer(LScalarTable.Memory.DiffRange), 'SSE2 MemDiffRange should leave scalar slot');
  CheckTrue(Pointer(LSSE2Table.Memory.Reverse) <> Pointer(LScalarTable.Memory.Reverse), 'SSE2 MemReverse should leave scalar slot');
  CheckTrue(Pointer(LSSE2Table.Memory.ToLowerAscii) <> Pointer(LScalarTable.Memory.ToLowerAscii), 'SSE2 ToLowerAscii should leave scalar slot');
  CheckTrue(Pointer(LSSE2Table.Memory.ToUpperAscii) <> Pointer(LScalarTable.Memory.ToUpperAscii), 'SSE2 ToUpperAscii should leave scalar slot');
  CheckTrue(Pointer(LSSE2Table.Memory.AsciiIEqual) <> Pointer(LScalarTable.Memory.AsciiIEqual), 'SSE2 AsciiIEqual should leave scalar slot');
  CheckTrue(Pointer(LSSE2Table.Memory.BytesIndexOf) <> Pointer(LScalarTable.Memory.BytesIndexOf), 'SSE2 BytesIndexOf should leave scalar slot');
  CheckTrue(Pointer(LSSE2Table.Memory.Utf8Validate) <> Pointer(LScalarTable.Memory.Utf8Validate), 'SSE2 Utf8Validate should leave scalar slot');

  for LIndex := 0 to High(LBufA) do
  begin
    LBufA[LIndex] := Byte((LIndex * 13) and $FF);
    LBufB[LIndex] := LBufA[LIndex];
    LRevSSE2[LIndex] := LBufA[LIndex];
    LRevScalar[LIndex] := LBufA[LIndex];
  end;
  LBufB[5] := $FF;
  LBufB[23] := $7E;

  LBoolSSE2 := LSSE2Table.Memory.DiffRange(@LBufA[0], @LBufB[0], Length(LBufA), LFirstSSE2, LLastSSE2);
  LBoolScalar := MemDiffRange_Scalar(@LBufA[0], @LBufB[0], Length(LBufA), LFirstScalar, LLastScalar);
  CheckEqual(LBoolScalar, LBoolSSE2, 'SSE2 MemDiffRange scalar parity bool');
  CheckEqual(LFirstScalar, LFirstSSE2, 'SSE2 MemDiffRange scalar parity first diff');
  CheckEqual(LLastScalar, LLastSSE2, 'SSE2 MemDiffRange scalar parity last diff');

  LSSE2Table.Memory.Reverse(@LRevSSE2[0], Length(LRevSSE2));
  MemReverse_Scalar(@LRevScalar[0], Length(LRevScalar));
  AssertByteArrayEquals('SSE2 MemReverse scalar parity', LRevScalar, LRevSSE2);

  LLowerSSE2 := 'AbC-xyZ09';
  LLowerScalar := LLowerSSE2;
  UniqueString(LLowerSSE2);
  UniqueString(LLowerScalar);
  LSSE2Table.Memory.ToLowerAscii(Pointer(LLowerSSE2), Length(LLowerSSE2));
  ToLowerAscii_Scalar(Pointer(LLowerScalar), Length(LLowerScalar));
  CheckEqual(string(LLowerScalar), string(LLowerSSE2), 'SSE2 ToLowerAscii scalar parity');

  LUpperSSE2 := 'AbC-xyZ09';
  LUpperScalar := LUpperSSE2;
  UniqueString(LUpperSSE2);
  UniqueString(LUpperScalar);
  LSSE2Table.Memory.ToUpperAscii(Pointer(LUpperSSE2), Length(LUpperSSE2));
  ToUpperAscii_Scalar(Pointer(LUpperScalar), Length(LUpperScalar));
  CheckEqual(string(LUpperScalar), string(LUpperSSE2), 'SSE2 ToUpperAscii scalar parity');

  LCaseA := 'SiMd-Case-123';
  LCaseB := 'sImD-cAsE-123';
  CheckEqual(AsciiIEqual_Scalar(Pointer(LCaseA), Pointer(LCaseB), Length(LCaseA)), LSSE2Table.Memory.AsciiIEqual(Pointer(LCaseA), Pointer(LCaseB), Length(LCaseA)), 'SSE2 AsciiIEqual scalar parity');

  LHaystack := 'prefix-Case-suffix';
  LNeedle := 'Case';
  CheckEqual(BytesIndexOf_Scalar(Pointer(LHaystack), Length(LHaystack), Pointer(LNeedle), Length(LNeedle)), LSSE2Table.Memory.BytesIndexOf(Pointer(LHaystack), Length(LHaystack), Pointer(LNeedle), Length(LNeedle)), 'SSE2 BytesIndexOf scalar parity');

  LValidUtf8[0] := Ord('A');
  LValidUtf8[1] := $E4;
  LValidUtf8[2] := $B8;
  LValidUtf8[3] := $AD;
  LValidUtf8[4] := $E6;
  LValidUtf8[5] := $96;
  LValidUtf8[6] := $87;
  LInvalidUtf8[0] := $E2;
  LInvalidUtf8[1] := $82;
  LInvalidUtf8[2] := $41;

  CheckEqual(Utf8Validate_Scalar(@LValidUtf8[0], Length(LValidUtf8)), LSSE2Table.Memory.Utf8Validate(@LValidUtf8[0], Length(LValidUtf8)), 'SSE2 Utf8Validate valid scalar parity');
  CheckEqual(Utf8Validate_Scalar(@LInvalidUtf8[0], Length(LInvalidUtf8)), LSSE2Table.Memory.Utf8Validate(@LInvalidUtf8[0], Length(LInvalidUtf8)), 'SSE2 Utf8Validate invalid scalar parity');
end;

procedure TTestCase_SSE2Contracts.Test_SSE2_VectorAsmRoundTrip_Rebuild_Preserves_Representative_Bindings;
var
  LSSE2DisabledTable: TSimdDispatchTable;
  LSSE2EnabledTable: TSimdDispatchTable;
  LSSE2DisabledAgainTable: TSimdDispatchTable;
begin
  GetDispatchTable;

  SetVectorAsmEnabled(False);
  if not TryGetRegisteredBackendDispatchTable(sbSSE2, LSSE2DisabledTable) then
    Exit;
  if not LSSE2DisabledTable.BackendInfo.Available then
    Exit;
  CheckTrue(TrySetActiveBackend(sbSSE2), 'TrySetActiveBackend(sbSSE2) should succeed with vector asm disabled');
  CheckEqual(Ord(sbSSE2), Ord(GetCurrentBackend), 'Current backend should be SSE2 with vector asm disabled');

  SetVectorAsmEnabled(True);
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbSSE2, LSSE2EnabledTable), 'TryGetRegisteredBackendDispatchTable(sbSSE2) should succeed with vector asm enabled');
  CheckTrue(TrySetActiveBackend(sbSSE2), 'TrySetActiveBackend(sbSSE2) should succeed with vector asm enabled');
  CheckEqual(Ord(sbSSE2), Ord(GetCurrentBackend), 'Current backend should stay SSE2 with vector asm enabled');

  SetVectorAsmEnabled(False);
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbSSE2, LSSE2DisabledAgainTable), 'TryGetRegisteredBackendDispatchTable(sbSSE2) should succeed after round-trip disable');
  CheckTrue(TrySetActiveBackend(sbSSE2), 'TrySetActiveBackend(sbSSE2) should succeed after vector asm round-trip');
  CheckEqual(Ord(sbSSE2), Ord(GetCurrentBackend), 'Current backend should stay SSE2 after vector asm round-trip');

  CheckTrue(Pointer(LSSE2DisabledTable.CoreVectors.AddF32x16) = Pointer(LSSE2EnabledTable.CoreVectors.AddF32x16), 'SSE2 AddF32x16 binding should be stable across vector-asm rebuilds');
  CheckTrue(Pointer(LSSE2DisabledTable.CoreVectors.SelectF64x8) = Pointer(LSSE2EnabledTable.CoreVectors.SelectF64x8), 'SSE2 SelectF64x8 binding should be stable across vector-asm rebuilds');
  CheckTrue(Pointer(LSSE2DisabledTable.CoreVectors.AddI64x8) = Pointer(LSSE2EnabledTable.CoreVectors.AddI64x8), 'SSE2 AddI64x8 binding should be stable across vector-asm rebuilds');
  CheckTrue(Pointer(LSSE2DisabledTable.Memory.DiffRange) = Pointer(LSSE2EnabledTable.Memory.DiffRange), 'SSE2 MemDiffRange binding should be stable across vector-asm rebuilds');
  CheckTrue(Pointer(LSSE2DisabledTable.Memory.Utf8Validate) = Pointer(LSSE2EnabledTable.Memory.Utf8Validate), 'SSE2 Utf8Validate binding should be stable across vector-asm rebuilds');

  CheckTrue(Pointer(LSSE2DisabledTable.CoreVectors.AddF32x16) = Pointer(LSSE2DisabledAgainTable.CoreVectors.AddF32x16), 'SSE2 AddF32x16 binding should round-trip back to the original slot');
  CheckTrue(Pointer(LSSE2DisabledTable.CoreVectors.SelectF64x8) = Pointer(LSSE2DisabledAgainTable.CoreVectors.SelectF64x8), 'SSE2 SelectF64x8 binding should round-trip back to the original slot');
  CheckTrue(Pointer(LSSE2DisabledTable.CoreVectors.AddI64x8) = Pointer(LSSE2DisabledAgainTable.CoreVectors.AddI64x8), 'SSE2 AddI64x8 binding should round-trip back to the original slot');
  CheckTrue(Pointer(LSSE2DisabledTable.Memory.DiffRange) = Pointer(LSSE2DisabledAgainTable.Memory.DiffRange), 'SSE2 MemDiffRange binding should round-trip back to the original slot');
  CheckTrue(Pointer(LSSE2DisabledTable.Memory.Utf8Validate) = Pointer(LSSE2DisabledAgainTable.Memory.Utf8Validate), 'SSE2 Utf8Validate binding should round-trip back to the original slot');
end;


end.