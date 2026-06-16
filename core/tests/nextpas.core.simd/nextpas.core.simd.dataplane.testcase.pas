unit nextpas.core.simd.dataplane.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

interface

uses
  Classes, nextpas.core.text.conv, fpcunit, testregistry,
  nextpas.core.simd,
  nextpas.core.simd.testcase,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.direct,
  nextpas.core.simd.dataplane,
  nextpas.core.simd.scalar;

type
  TTestCase_DataPlane = class(TSimdVectorAsmStatefulTestCase)
  published
    procedure Test_DataPlane_CurrentSnapshot_Matches_Dispatch_And_Direct;
    procedure Test_DataPlane_BoundSlots_Match_CurrentDispatch_And_PublicAbi;
    procedure Test_DataPlane_ExplicitRebind_WithoutDispatchMutation_PreservesSnapshot;
    procedure Test_DataPlane_BackendRoundTrip_Reuses_PreviouslyPublishedSnapshot;
    procedure Test_DataPlane_VectorAsmRoundTrip_Reuses_PreviouslyPublishedSnapshot;
    procedure Test_DataPlane_CompareMaskSnapshot_Follows_CurrentDispatchSemantics;
    procedure Test_DataPlane_WideBitwiseShiftSnapshot_Follows_CurrentDispatchSemantics;
    procedure Test_DataPlane_WideArithmeticMinMaxSnapshot_Follows_CurrentDispatchSemantics;
    procedure Test_DataPlane_Rebind_Tracks_ControlPlane_Switch;
  end;

implementation

procedure TTestCase_DataPlane.Test_DataPlane_CurrentSnapshot_Matches_Dispatch_And_Direct;
var
  LDataPlane: PSimdDataPlane;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
begin
  LDataPlane := GetCurrentSimdDataPlane;
  LDispatch := GetDispatchTable;
  LDirectDispatch := GetDirectDispatchTable;

  AssertTrue('data-plane snapshot should be assigned', LDataPlane <> nil);
  AssertTrue('dispatch table should be assigned', LDispatch <> nil);
  AssertTrue('direct dispatch table should be assigned', LDirectDispatch <> nil);
  AssertTrue('data-plane dispatch should match GetDispatchTable',
    LDataPlane^.Dispatch = LDispatch);
  AssertTrue('direct dispatch should match data-plane dispatch',
    LDirectDispatch = LDataPlane^.Dispatch);
  AssertEquals('data-plane active backend should match dispatch backend',
    Ord(LDispatch^.Backend), Ord(LDataPlane^.ActiveBackend));
end;

procedure TTestCase_DataPlane.Test_DataPlane_BoundSlots_Match_CurrentDispatch_And_PublicAbi;
var
  LDataPlane: PSimdDataPlane;
  LDispatch: PSimdDispatchTable;
  LApi: PNextPasSimdPublicApi;
begin
  LDataPlane := GetCurrentSimdDataPlane;
  LDispatch := GetDispatchTable;
  LApi := GetSimdPublicApi;

  AssertTrue('data-plane snapshot should be assigned', LDataPlane <> nil);
  AssertTrue('dispatch table should be assigned', LDispatch <> nil);
  AssertTrue('public API table should be assigned', LApi <> nil);

  AssertTrue('VecF32x4Add fast path should match dispatch slot',
    LDataPlane^.VecF32x4AddPtr = Pointer(LDispatch^.AddF32x4));
  AssertTrue('VecI16x32Add fast path should match dispatch slot',
    LDataPlane^.VecI16x32AddPtr = Pointer(LDispatch^.AddI16x32));
  AssertTrue('VecU32x16Mul fast path should match dispatch slot',
    LDataPlane^.VecU32x16MulPtr = Pointer(LDispatch^.MulU32x16));
  AssertTrue('VecU64x8Add fast path should match dispatch slot',
    LDataPlane^.VecU64x8AddPtr = Pointer(LDispatch^.AddU64x8));
  AssertTrue('VecU8x64Max fast path should match dispatch slot',
    LDataPlane^.VecU8x64MaxPtr = Pointer(LDispatch^.MaxU8x64));

  AssertTrue('MemEqual binding should match dispatch slot',
    LDataPlane^.MemEqualPtr = Pointer(LDispatch^.MemEqual));
  AssertTrue('MemFindByte binding should match dispatch slot',
    LDataPlane^.MemFindBytePtr = Pointer(LDispatch^.MemFindByte));
  AssertTrue('MemDiffRange binding should match dispatch slot',
    LDataPlane^.MemDiffRangePtr = Pointer(LDispatch^.MemDiffRange));
  AssertTrue('SumBytes binding should match dispatch slot',
    LDataPlane^.SumBytesPtr = Pointer(LDispatch^.SumBytes));
  AssertTrue('CountByte binding should match dispatch slot',
    LDataPlane^.CountBytePtr = Pointer(LDispatch^.CountByte));
  AssertTrue('BitsetPopCount binding should match dispatch slot',
    LDataPlane^.BitsetPopCountPtr = Pointer(LDispatch^.BitsetPopCount));
  AssertTrue('Utf8Validate binding should match dispatch slot',
    LDataPlane^.Utf8ValidatePtr = Pointer(LDispatch^.Utf8Validate));
  AssertTrue('AsciiIEqual binding should match dispatch slot',
    LDataPlane^.AsciiIEqualPtr = Pointer(LDispatch^.AsciiIEqual));
  AssertTrue('BytesIndexOf binding should match dispatch slot',
    LDataPlane^.BytesIndexOfPtr = Pointer(LDispatch^.BytesIndexOf));
  AssertTrue('MemCopy binding should match dispatch slot',
    LDataPlane^.MemCopyPtr = Pointer(LDispatch^.MemCopy));
  AssertTrue('MemSet binding should match dispatch slot',
    LDataPlane^.MemSetPtr = Pointer(LDispatch^.MemSet));
  AssertTrue('ToLowerAscii binding should match dispatch slot',
    LDataPlane^.ToLowerAsciiPtr = Pointer(LDispatch^.ToLowerAscii));
  AssertTrue('ToUpperAscii binding should match dispatch slot',
    LDataPlane^.ToUpperAsciiPtr = Pointer(LDispatch^.ToUpperAscii));
  AssertTrue('MemReverse binding should match dispatch slot',
    LDataPlane^.MemReversePtr = Pointer(LDispatch^.MemReverse));
  AssertTrue('MinMaxBytes binding should match dispatch slot',
    LDataPlane^.MinMaxBytesPtr = Pointer(LDispatch^.MinMaxBytes));

  AssertTrue('public API active backend should match data-plane active backend',
    Integer(LApi^.ActiveBackendId) = Ord(LDataPlane^.ActiveBackend));
end;

procedure TTestCase_DataPlane.Test_DataPlane_ExplicitRebind_WithoutDispatchMutation_PreservesSnapshot;
var
  LBefore: PSimdDataPlane;
  LAfter: PSimdDataPlane;
  LApiBefore: PNextPasSimdPublicApi;
  LApiAfter: PNextPasSimdPublicApi;
begin
  LBefore := GetCurrentSimdDataPlane;
  LApiBefore := GetSimdPublicApi;
  AssertTrue('data-plane snapshot should be assigned before explicit same-dispatch rebind',
    LBefore <> nil);
  AssertTrue('public API table should be assigned before explicit same-dispatch rebind',
    LApiBefore <> nil);

  RebindDirectDispatch;
  LAfter := GetCurrentSimdDataPlane;
  LApiAfter := GetSimdPublicApi;

  AssertTrue('data-plane snapshot should be assigned after explicit same-dispatch rebind',
    LAfter <> nil);
  AssertTrue('public API table should be assigned after explicit same-dispatch rebind',
    LApiAfter <> nil);
  AssertTrue('explicit rebind without dispatch mutation should preserve the published snapshot',
    PtrUInt(LBefore) = PtrUInt(LAfter));
  AssertTrue('public API table should reuse the same published metadata table when the data-plane snapshot is unchanged',
    PtrUInt(LApiBefore) = PtrUInt(LApiAfter));
end;

procedure TTestCase_DataPlane.Test_DataPlane_BackendRoundTrip_Reuses_PreviouslyPublishedSnapshot;
var
  LInitial: PSimdDataPlane;
  LMiddle: PSimdDataPlane;
  LFinal: PSimdDataPlane;
  LOriginalBackend: TSimdBackend;
  LTargetBackend: TSimdBackend;
  LDispatchable: TSimdBackendArray;
  LFoundDifferent: Boolean;
  LIndex: Integer;
begin
  LInitial := GetCurrentSimdDataPlane;
  LOriginalBackend := GetCurrentBackend;
  LTargetBackend := LOriginalBackend;
  LFoundDifferent := False;

  LDispatchable := GetDispatchableBackendList;
  for LIndex := 0 to High(LDispatchable) do
    if LDispatchable[LIndex] <> LOriginalBackend then
    begin
      LTargetBackend := LDispatchable[LIndex];
      LFoundDifferent := True;
      Break;
    end;

  if not LFoundDifferent then
    Exit;

  try
    AssertTrue('TrySetActiveBackend(target) should succeed in data-plane round-trip test',
      TrySetActiveBackend(LTargetBackend));
    LMiddle := GetCurrentSimdDataPlane;
    AssertTrue('round-trip test should publish a different snapshot for the target backend',
      PtrUInt(LMiddle) <> PtrUInt(LInitial));

    AssertTrue('TrySetActiveBackend(original) should succeed in data-plane round-trip test',
      TrySetActiveBackend(LOriginalBackend));
    LFinal := GetCurrentSimdDataPlane;

    AssertTrue('round-trip back to the original dispatch should reuse the original snapshot',
      PtrUInt(LFinal) = PtrUInt(LInitial));
  finally
    if GetCurrentBackend <> LOriginalBackend then
      AssertTrue('restoring original backend should succeed after data-plane round-trip test',
        TrySetActiveBackend(LOriginalBackend));
  end;
end;

procedure TTestCase_DataPlane.Test_DataPlane_VectorAsmRoundTrip_Reuses_PreviouslyPublishedSnapshot;
var
  LInitial: PSimdDataPlane;
  LMiddle: PSimdDataPlane;
  LFinal: PSimdDataPlane;
  LInitialBackend: TSimdBackend;
  LMiddleBackend: TSimdBackend;
begin
  GetDispatchTable;
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LInitialBackend := GetCurrentBackend;
  if LInitialBackend = sbScalar then
    Exit;

  LInitial := GetCurrentSimdDataPlane;
  AssertNotNull('data-plane snapshot should be assigned before vector-asm round-trip test', LInitial);
  AssertEquals('initial data-plane backend should match current backend before vector-asm round-trip test',
    Ord(LInitialBackend), Ord(LInitial^.ActiveBackend));

  SetVectorAsmEnabled(False);
  LMiddleBackend := GetCurrentBackend;
  LMiddle := GetCurrentSimdDataPlane;
  AssertNotNull('data-plane snapshot should stay assigned after disabling vector asm', LMiddle);

  if LMiddleBackend = LInitialBackend then
    Exit;

  AssertTrue('Disabling vector asm should publish a different data-plane snapshot for the fallback backend',
    PtrUInt(LMiddle) <> PtrUInt(LInitial));

  SetVectorAsmEnabled(True);
  LFinal := GetCurrentSimdDataPlane;
  AssertNotNull('data-plane snapshot should stay assigned after re-enabling vector asm', LFinal);

  AssertEquals('Re-enabling vector asm should restore the original automatic backend for data-plane',
    Ord(LInitialBackend), Ord(LFinal^.ActiveBackend));
  AssertTrue('Vector-asm round-trip should reuse the original published data-plane snapshot',
    PtrUInt(LFinal) = PtrUInt(LInitial));
end;

procedure TTestCase_DataPlane.Test_DataPlane_CompareMaskSnapshot_Follows_CurrentDispatchSemantics;
var
  LDataPlane: PSimdDataPlane;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LI64x4A, LI64x4B: TVecI64x4;
  LI64x8A, LI64x8B: TVecI64x8;
  LI32x16A, LI32x16B: TVecI32x16;
  LMask4DataPlane, LMask4Scalar: TMask4;
  LMask8DataPlane, LMask8Scalar: TMask8;
  LMask16DataPlane, LMask16Scalar: TMask16;
  LCaseIdx: Integer;
  LLane: Integer;

  procedure LoadCase(const aCaseIdx: Integer);
  var
    LLaneIndex: Integer;
  begin
    case aCaseIdx of
      0:
        begin
          LI64x4A.i[0] := Low(Int64);
          LI64x4A.i[1] := -1;
          LI64x4A.i[2] := 0;
          LI64x4A.i[3] := 1024;
          LI64x4B.i[0] := Low(Int64);
          LI64x4B.i[1] := 0;
          LI64x4B.i[2] := 1;
          LI64x4B.i[3] := 512;

          for LLaneIndex := 0 to 7 do
          begin
            LI64x8A.i[LLaneIndex] := (LLaneIndex - 4) * 111;
            LI64x8B.i[LLaneIndex] := (LLaneIndex - 3) * 111;
          end;
          LI64x8A.i[2] := 0;
          LI64x8B.i[2] := 0;
          LI64x8A.i[6] := 999;
          LI64x8B.i[6] := 998;

          for LLaneIndex := 0 to 15 do
          begin
            LI32x16A.i[LLaneIndex] := (LLaneIndex - 8) * 257;
            LI32x16B.i[LLaneIndex] := (LLaneIndex - 7) * 257;
          end;
          LI32x16A.i[0] := Low(Int32);
          LI32x16B.i[0] := Low(Int32);
          LI32x16A.i[15] := High(Int32);
          LI32x16B.i[15] := High(Int32) - 1;
        end;
      1:
        begin
          LI64x4A.i[0] := 0;
          LI64x4A.i[1] := 1;
          LI64x4A.i[2] := High(Int64);
          LI64x4A.i[3] := Low(Int64);
          LI64x4B.i[0] := 0;
          LI64x4B.i[1] := 2;
          LI64x4B.i[2] := High(Int64);
          LI64x4B.i[3] := Low(Int64) + 1;

          for LLaneIndex := 0 to 7 do
          begin
            LI64x8A.i[LLaneIndex] := 0;
            LI64x8B.i[LLaneIndex] := 0;
          end;
          LI64x8A.i[0] := Low(Int64);
          LI64x8B.i[0] := Low(Int64);
          LI64x8A.i[1] := -1;
          LI64x8B.i[1] := 0;
          LI64x8A.i[6] := High(Int64);
          LI64x8B.i[6] := High(Int64);
          LI64x8A.i[7] := 77;
          LI64x8B.i[7] := -77;

          for LLaneIndex := 0 to 15 do
          begin
            LI32x16A.i[LLaneIndex] := 0;
            LI32x16B.i[LLaneIndex] := 0;
          end;
          LI32x16A.i[1] := -1;
          LI32x16B.i[1] := 0;
          LI32x16A.i[7] := $55555555;
          LI32x16B.i[7] := $55555555;
          LI32x16A.i[8] := Int32($AAAAAAAA);
          LI32x16B.i[8] := $55555555;
          LI32x16A.i[15] := High(Int32);
          LI32x16B.i[15] := High(Int32);
        end;
      2:
        begin
          LI64x4A.i[0] := 99;
          LI64x4A.i[1] := -99;
          LI64x4A.i[2] := 4096;
          LI64x4A.i[3] := -4096;
          LI64x4B.i[0] := 100;
          LI64x4B.i[1] := -100;
          LI64x4B.i[2] := 4095;
          LI64x4B.i[3] := -4095;

          for LLaneIndex := 0 to 7 do
          begin
            LI64x8A.i[LLaneIndex] := (LLaneIndex * 257) - 777;
            LI64x8B.i[LLaneIndex] := (LLaneIndex * 257) - 776;
          end;
          LI64x8A.i[3] := 1234567890123;
          LI64x8B.i[3] := 1234567890123;
          LI64x8A.i[5] := -1234567890123;
          LI64x8B.i[5] := -1234567890122;

          for LLaneIndex := 0 to 15 do
          begin
            LI32x16A.i[LLaneIndex] := (LLaneIndex - 8) * 33;
            LI32x16B.i[LLaneIndex] := (LLaneIndex - 8) * 33;
          end;
          LI32x16A.i[0] := 17;
          LI32x16B.i[0] := 16;
          LI32x16A.i[5] := -65;
          LI32x16B.i[5] := -66;
          LI32x16A.i[10] := 513;
          LI32x16B.i[10] := 514;
          LI32x16A.i[15] := -2049;
          LI32x16B.i[15] := -2048;
        end;
      3:
        begin
          LI64x4A.i[0] := 9223372036854775700;
          LI64x4A.i[1] := -9223372036854775700;
          LI64x4A.i[2] := 42;
          LI64x4A.i[3] := -42;
          LI64x4B.i[0] := 9223372036854775700;
          LI64x4B.i[1] := -9223372036854775699;
          LI64x4B.i[2] := 43;
          LI64x4B.i[3] := -43;

          for LLaneIndex := 0 to 7 do
          begin
            LI64x8A.i[LLaneIndex] := Int64(LLaneIndex - 3) * Int64(LLaneIndex - 1) * 97;
            LI64x8B.i[LLaneIndex] := Int64(LLaneIndex - 2) * Int64(LLaneIndex - 4) * 97;
          end;
          LI64x8A.i[0] := Low(Int64);
          LI64x8B.i[0] := Low(Int64);
          LI64x8A.i[7] := High(Int64);
          LI64x8B.i[7] := High(Int64) - 1;

          for LLaneIndex := 0 to 15 do
          begin
            LI32x16A.i[LLaneIndex] := (LLaneIndex * 4099) - 32000;
            LI32x16B.i[LLaneIndex] := ((15 - LLaneIndex) * 2053) - 16000;
          end;
          LI32x16A.i[2] := -1;
          LI32x16B.i[2] := -1;
          LI32x16A.i[9] := Low(Int32);
          LI32x16B.i[9] := Low(Int32) + 1;
          LI32x16A.i[14] := High(Int32);
          LI32x16B.i[14] := High(Int32);
        end;
    else
      Fail('unexpected compare/mask data-plane case');
    end;
  end;
begin
  LDataPlane := GetCurrentSimdDataPlane;
  LDispatch := GetDispatchTable;
  LDirectDispatch := GetDirectDispatchTable;

  AssertNotNull('data-plane snapshot should be assigned for compare/mask snapshot test', LDataPlane);
  AssertNotNull('dispatch table should be assigned for compare/mask snapshot test', LDispatch);
  AssertNotNull('direct dispatch table should be assigned for compare/mask snapshot test', LDirectDispatch);
  AssertTrue('data-plane dispatch should match current dispatch for compare/mask snapshot test',
    LDataPlane^.Dispatch = LDispatch);

  AssertTrue('data-plane dispatch CmpLtI64x4 should be assigned', Assigned(LDataPlane^.Dispatch^.CmpLtI64x4));
  AssertTrue('data-plane dispatch CmpLtI64x8 should be assigned', Assigned(LDataPlane^.Dispatch^.CmpLtI64x8));
  AssertTrue('data-plane dispatch CmpLtI32x16 should be assigned', Assigned(LDataPlane^.Dispatch^.CmpLtI32x16));
  AssertTrue('data-plane dispatch Mask4All should be assigned', Assigned(LDataPlane^.Dispatch^.Mask4All));
  AssertTrue('data-plane dispatch Mask4Any should be assigned', Assigned(LDataPlane^.Dispatch^.Mask4Any));
  AssertTrue('data-plane dispatch Mask4None should be assigned', Assigned(LDataPlane^.Dispatch^.Mask4None));
  AssertTrue('data-plane dispatch Mask4PopCount should be assigned', Assigned(LDataPlane^.Dispatch^.Mask4PopCount));
  AssertTrue('data-plane dispatch Mask4FirstSet should be assigned', Assigned(LDataPlane^.Dispatch^.Mask4FirstSet));
  AssertTrue('data-plane dispatch Mask8All should be assigned', Assigned(LDataPlane^.Dispatch^.Mask8All));
  AssertTrue('data-plane dispatch Mask8Any should be assigned', Assigned(LDataPlane^.Dispatch^.Mask8Any));
  AssertTrue('data-plane dispatch Mask8None should be assigned', Assigned(LDataPlane^.Dispatch^.Mask8None));
  AssertTrue('data-plane dispatch Mask8PopCount should be assigned', Assigned(LDataPlane^.Dispatch^.Mask8PopCount));
  AssertTrue('data-plane dispatch Mask8FirstSet should be assigned', Assigned(LDataPlane^.Dispatch^.Mask8FirstSet));
  AssertTrue('data-plane dispatch Mask16All should be assigned', Assigned(LDataPlane^.Dispatch^.Mask16All));
  AssertTrue('data-plane dispatch Mask16Any should be assigned', Assigned(LDataPlane^.Dispatch^.Mask16Any));
  AssertTrue('data-plane dispatch Mask16None should be assigned', Assigned(LDataPlane^.Dispatch^.Mask16None));
  AssertTrue('data-plane dispatch Mask16PopCount should be assigned', Assigned(LDataPlane^.Dispatch^.Mask16PopCount));
  AssertTrue('data-plane dispatch Mask16FirstSet should be assigned', Assigned(LDataPlane^.Dispatch^.Mask16FirstSet));

  for LCaseIdx := 0 to 3 do
  begin
    LoadCase(LCaseIdx);

    LMask4DataPlane := LDataPlane^.Dispatch^.CmpLtI64x4(LI64x4A, LI64x4B);
    LMask4Scalar := ScalarCmpLtI64x4(LI64x4A, LI64x4B);
    AssertEquals('data-plane dispatch CmpLtI64x4 should match scalar semantics case=' + IntToStr(LCaseIdx),
      Integer(LMask4Scalar), Integer(LMask4DataPlane));
    AssertEquals('data-plane dispatch CmpLtI64x4 should match direct dispatch case=' + IntToStr(LCaseIdx),
      Integer(LDirectDispatch^.CmpLtI64x4(LI64x4A, LI64x4B)), Integer(LMask4DataPlane));
    AssertEquals('data-plane dispatch Mask4All should match scalar helper case=' + IntToStr(LCaseIdx),
      ScalarMask4All(LMask4Scalar), LDataPlane^.Dispatch^.Mask4All(LMask4DataPlane));
    AssertEquals('data-plane dispatch Mask4Any should match scalar helper case=' + IntToStr(LCaseIdx),
      ScalarMask4Any(LMask4Scalar), LDataPlane^.Dispatch^.Mask4Any(LMask4DataPlane));
    AssertEquals('data-plane dispatch Mask4None should match scalar helper case=' + IntToStr(LCaseIdx),
      ScalarMask4None(LMask4Scalar), LDataPlane^.Dispatch^.Mask4None(LMask4DataPlane));
    AssertEquals('data-plane dispatch Mask4PopCount should match scalar helper case=' + IntToStr(LCaseIdx),
      ScalarMask4PopCount(LMask4Scalar), LDataPlane^.Dispatch^.Mask4PopCount(LMask4DataPlane));
    AssertEquals('data-plane dispatch Mask4FirstSet should match scalar helper case=' + IntToStr(LCaseIdx),
      ScalarMask4FirstSet(LMask4Scalar), LDataPlane^.Dispatch^.Mask4FirstSet(LMask4DataPlane));

    LMask8DataPlane := LDataPlane^.Dispatch^.CmpLtI64x8(LI64x8A, LI64x8B);
    LMask8Scalar := ScalarCmpLtI64x8(LI64x8A, LI64x8B);
    AssertEquals('data-plane dispatch CmpLtI64x8 should match scalar semantics case=' + IntToStr(LCaseIdx),
      Integer(LMask8Scalar), Integer(LMask8DataPlane));
    AssertEquals('data-plane dispatch CmpLtI64x8 should match direct dispatch case=' + IntToStr(LCaseIdx),
      Integer(LDirectDispatch^.CmpLtI64x8(LI64x8A, LI64x8B)), Integer(LMask8DataPlane));
    AssertEquals('data-plane dispatch Mask8All should match scalar helper case=' + IntToStr(LCaseIdx),
      ScalarMask8All(LMask8Scalar), LDataPlane^.Dispatch^.Mask8All(LMask8DataPlane));
    AssertEquals('data-plane dispatch Mask8Any should match scalar helper case=' + IntToStr(LCaseIdx),
      ScalarMask8Any(LMask8Scalar), LDataPlane^.Dispatch^.Mask8Any(LMask8DataPlane));
    AssertEquals('data-plane dispatch Mask8None should match scalar helper case=' + IntToStr(LCaseIdx),
      ScalarMask8None(LMask8Scalar), LDataPlane^.Dispatch^.Mask8None(LMask8DataPlane));
    AssertEquals('data-plane dispatch Mask8PopCount should match scalar helper case=' + IntToStr(LCaseIdx),
      ScalarMask8PopCount(LMask8Scalar), LDataPlane^.Dispatch^.Mask8PopCount(LMask8DataPlane));
    AssertEquals('data-plane dispatch Mask8FirstSet should match scalar helper case=' + IntToStr(LCaseIdx),
      ScalarMask8FirstSet(LMask8Scalar), LDataPlane^.Dispatch^.Mask8FirstSet(LMask8DataPlane));

    LMask16DataPlane := LDataPlane^.Dispatch^.CmpLtI32x16(LI32x16A, LI32x16B);
    LMask16Scalar := ScalarCmpLtI32x16(LI32x16A, LI32x16B);
    AssertEquals('data-plane dispatch CmpLtI32x16 should match scalar semantics case=' + IntToStr(LCaseIdx),
      Integer(LMask16Scalar), Integer(LMask16DataPlane));
    AssertEquals('data-plane dispatch CmpLtI32x16 should match direct dispatch case=' + IntToStr(LCaseIdx),
      Integer(LDirectDispatch^.CmpLtI32x16(LI32x16A, LI32x16B)), Integer(LMask16DataPlane));
    AssertEquals('data-plane dispatch Mask16All should match scalar helper case=' + IntToStr(LCaseIdx),
      ScalarMask16All(LMask16Scalar), LDataPlane^.Dispatch^.Mask16All(LMask16DataPlane));
    AssertEquals('data-plane dispatch Mask16Any should match scalar helper case=' + IntToStr(LCaseIdx),
      ScalarMask16Any(LMask16Scalar), LDataPlane^.Dispatch^.Mask16Any(LMask16DataPlane));
    AssertEquals('data-plane dispatch Mask16None should match scalar helper case=' + IntToStr(LCaseIdx),
      ScalarMask16None(LMask16Scalar), LDataPlane^.Dispatch^.Mask16None(LMask16DataPlane));
    AssertEquals('data-plane dispatch Mask16PopCount should match scalar helper case=' + IntToStr(LCaseIdx),
      ScalarMask16PopCount(LMask16Scalar), LDataPlane^.Dispatch^.Mask16PopCount(LMask16DataPlane));
    AssertEquals('data-plane dispatch Mask16FirstSet should match scalar helper case=' + IntToStr(LCaseIdx),
      ScalarMask16FirstSet(LMask16Scalar), LDataPlane^.Dispatch^.Mask16FirstSet(LMask16DataPlane));
  end;
end;

procedure TTestCase_DataPlane.Test_DataPlane_WideBitwiseShiftSnapshot_Follows_CurrentDispatchSemantics;
const
  C_SHIFT32: array[0..7] of Integer = (-1, 0, 1, 7, 31, 32, 63, 64);
  C_SHIFT64: array[0..7] of Integer = (-1, 0, 1, 7, 31, 63, 64, 95);
var
  LDataPlane: PSimdDataPlane;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LI32x16A, LI32x16B: TVecI32x16;
  LI64x4A, LI64x4B: TVecI64x4;
  LU64x4A, LU64x4B: TVecU64x4;
  LI64x8A, LI64x8B: TVecI64x8;
  LI32x16DataPlane, LI32x16Scalar: TVecI32x16;
  LI64x4DataPlane, LI64x4Scalar: TVecI64x4;
  LI64x8DataPlane, LI64x8Scalar: TVecI64x8;
  LCaseIdx: Integer;
  LShiftIndex: Integer;
  LLane: Integer;

  procedure AssertVecI32x16Equal(const aLabel: string; const aExpected, aActual: TVecI32x16);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 15 do
      AssertEquals(aLabel + ' lane ' + IntToStr(LLaneIndex), aExpected.i[LLaneIndex], aActual.i[LLaneIndex]);
  end;

  procedure AssertVecI64x4Equal(const aLabel: string; const aExpected, aActual: TVecI64x4);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 3 do
      AssertEquals(aLabel + ' lane ' + IntToStr(LLaneIndex), aExpected.i[LLaneIndex], aActual.i[LLaneIndex]);
  end;

  procedure AssertVecI64x8Equal(const aLabel: string; const aExpected, aActual: TVecI64x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      AssertEquals(aLabel + ' lane ' + IntToStr(LLaneIndex), aExpected.i[LLaneIndex], aActual.i[LLaneIndex]);
  end;

  procedure LoadCase(const aCaseIdx: Integer);
  var
    LLaneIndex: Integer;
  begin
    case aCaseIdx of
      0:
        begin
          for LLaneIndex := 0 to 15 do
          begin
            LI32x16A.i[LLaneIndex] := (LLaneIndex - 8) * 257;
            LI32x16B.i[LLaneIndex] := (7 - LLaneIndex) * 131;
          end;
          LI32x16A.i[0] := Low(Int32);
          LI32x16A.i[1] := -1;
          LI32x16A.i[2] := $55555555;
          LI32x16A.i[15] := High(Int32);
          LI32x16B.i[0] := High(Int32);
          LI32x16B.i[1] := Int32($AAAAAAAA);
          LI32x16B.i[2] := -1;
          LI32x16B.i[15] := Low(Int32);

          LI64x4A.i[0] := Low(Int64);
          LI64x4A.i[1] := -1;
          LI64x4A.i[2] := Int64($4000000000000001);
          LI64x4A.i[3] := High(Int64);
          LI64x4B.i[0] := High(Int64);
          LI64x4B.i[1] := Int64($AAAAAAAAAAAAAAAA);
          LI64x4B.i[2] := -1;
          LI64x4B.i[3] := Low(Int64);

          for LLaneIndex := 0 to 7 do
          begin
            LI64x8A.i[LLaneIndex] := Int64(LLaneIndex * 1000 - 3000);
            LI64x8B.i[LLaneIndex] := Int64(500 - LLaneIndex * 77);
          end;
          LI64x8A.i[0] := High(Int64);
          LI64x8A.i[1] := Low(Int64);
          LI64x8A.i[2] := -1;
          LI64x8A.i[7] := Int64($4000000000000001);
          LI64x8B.i[0] := 1;
          LI64x8B.i[1] := -1;
          LI64x8B.i[2] := High(Int64);
          LI64x8B.i[7] := Low(Int64);
        end;
      1:
        begin
          for LLaneIndex := 0 to 15 do
          begin
            LI32x16A.i[LLaneIndex] := 0;
            LI32x16B.i[LLaneIndex] := 0;
          end;
          LI32x16A.i[1] := -1;
          LI32x16A.i[2] := Int32($AAAAAAAA);
          LI32x16A.i[3] := $55555555;
          LI32x16A.i[14] := High(Int32);
          LI32x16A.i[15] := Low(Int32);
          LI32x16B.i[0] := -1;
          LI32x16B.i[2] := $55555555;
          LI32x16B.i[3] := Int32($AAAAAAAA);
          LI32x16B.i[14] := High(Int32);
          LI32x16B.i[15] := Low(Int32);

          LI64x4A.i[0] := 0;
          LI64x4A.i[1] := -1;
          LI64x4A.i[2] := High(Int64);
          LI64x4A.i[3] := Low(Int64);
          LI64x4B.i[0] := -1;
          LI64x4B.i[1] := 0;
          LI64x4B.i[2] := High(Int64);
          LI64x4B.i[3] := Low(Int64);

          for LLaneIndex := 0 to 7 do
          begin
            LI64x8A.i[LLaneIndex] := 0;
            LI64x8B.i[LLaneIndex] := 0;
          end;
          LI64x8A.i[0] := Int64($AAAAAAAAAAAAAAAA);
          LI64x8A.i[1] := Int64($5555555555555555);
          LI64x8A.i[6] := High(Int64);
          LI64x8A.i[7] := Low(Int64);
          LI64x8B.i[0] := Int64($5555555555555555);
          LI64x8B.i[1] := Int64($AAAAAAAAAAAAAAAA);
          LI64x8B.i[6] := High(Int64);
          LI64x8B.i[7] := Low(Int64);
        end;
      2:
        begin
          for LLaneIndex := 0 to 15 do
          begin
            LI32x16A.i[LLaneIndex] := (LLaneIndex * 4099) - 32000;
            LI32x16B.i[LLaneIndex] := ((15 - LLaneIndex) * 2053) - 16000;
          end;
          LI32x16A.i[0] := 1;
          LI32x16A.i[5] := -65;
          LI32x16A.i[10] := 513;
          LI32x16A.i[15] := -2049;
          LI32x16B.i[0] := 0;
          LI32x16B.i[5] := -66;
          LI32x16B.i[10] := 514;
          LI32x16B.i[15] := -2048;

          LI64x4A.i[0] := 99;
          LI64x4A.i[1] := -99;
          LI64x4A.i[2] := 4096;
          LI64x4A.i[3] := -4096;
          LI64x4B.i[0] := 100;
          LI64x4B.i[1] := -100;
          LI64x4B.i[2] := 4095;
          LI64x4B.i[3] := -4095;

          for LLaneIndex := 0 to 7 do
          begin
            LI64x8A.i[LLaneIndex] := Int64(LLaneIndex - 3) * Int64(LLaneIndex - 1) * 97;
            LI64x8B.i[LLaneIndex] := Int64(LLaneIndex - 2) * Int64(LLaneIndex - 4) * 97;
          end;
          LI64x8A.i[0] := Low(Int64);
          LI64x8B.i[0] := Low(Int64);
          LI64x8A.i[7] := High(Int64);
          LI64x8B.i[7] := High(Int64) - 1;
        end;
    else
      Fail('unexpected wide bitwise/shift data-plane case');
    end;
  end;
begin
  LDataPlane := GetCurrentSimdDataPlane;
  LDispatch := GetDispatchTable;
  LDirectDispatch := GetDirectDispatchTable;

  AssertNotNull('data-plane snapshot should be assigned for wide bitwise/shift snapshot test', LDataPlane);
  AssertNotNull('dispatch table should be assigned for wide bitwise/shift snapshot test', LDispatch);
  AssertNotNull('direct dispatch table should be assigned for wide bitwise/shift snapshot test', LDirectDispatch);
  AssertTrue('data-plane dispatch should match current dispatch for wide bitwise/shift snapshot test',
    LDataPlane^.Dispatch = LDispatch);

  AssertTrue('data-plane dispatch AndNotI32x16 should be assigned', Assigned(LDataPlane^.Dispatch^.AndNotI32x16));
  AssertTrue('data-plane dispatch ShiftLeftI32x16 should be assigned', Assigned(LDataPlane^.Dispatch^.ShiftLeftI32x16));
  AssertTrue('data-plane dispatch ShiftRightArithI32x16 should be assigned', Assigned(LDataPlane^.Dispatch^.ShiftRightArithI32x16));
  AssertTrue('data-plane dispatch AndNotI64x4 should be assigned', Assigned(LDataPlane^.Dispatch^.AndNotI64x4));
  AssertTrue('data-plane dispatch ShiftRightArithI64x4 should be assigned', Assigned(LDataPlane^.Dispatch^.ShiftRightArithI64x4));
  AssertTrue('data-plane dispatch AndI64x8 should be assigned', Assigned(LDataPlane^.Dispatch^.AndI64x8));
  AssertTrue('data-plane dispatch OrI64x8 should be assigned', Assigned(LDataPlane^.Dispatch^.OrI64x8));
  AssertTrue('data-plane dispatch XorI64x8 should be assigned', Assigned(LDataPlane^.Dispatch^.XorI64x8));
  AssertTrue('data-plane dispatch NotI64x8 should be assigned', Assigned(LDataPlane^.Dispatch^.NotI64x8));
  AssertTrue('data-plane dispatch ShiftRightI64x4 should be assigned', Assigned(LDataPlane^.Dispatch^.ShiftRightI64x4));

  for LCaseIdx := 0 to 2 do
  begin
    LoadCase(LCaseIdx);

    LI32x16DataPlane := LDataPlane^.Dispatch^.AndNotI32x16(LI32x16A, LI32x16B);
    LI32x16Scalar := ScalarAndNotI32x16(LI32x16A, LI32x16B);
    AssertVecI32x16Equal('data-plane dispatch AndNotI32x16 should match scalar semantics case=' + IntToStr(LCaseIdx), LI32x16Scalar, LI32x16DataPlane);
    AssertVecI32x16Equal('data-plane dispatch AndNotI32x16 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.AndNotI32x16(LI32x16A, LI32x16B), LI32x16DataPlane);

    LI64x4DataPlane := LDataPlane^.Dispatch^.AndNotI64x4(LI64x4A, LI64x4B);
    LI64x4Scalar := ScalarAndNotI64x4(LI64x4A, LI64x4B);
    AssertVecI64x4Equal('data-plane dispatch AndNotI64x4 should match scalar semantics case=' + IntToStr(LCaseIdx), LI64x4Scalar, LI64x4DataPlane);
    AssertVecI64x4Equal('data-plane dispatch AndNotI64x4 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.AndNotI64x4(LI64x4A, LI64x4B), LI64x4DataPlane);

    LI64x8DataPlane := LDataPlane^.Dispatch^.AndI64x8(LI64x8A, LI64x8B);
    LI64x8Scalar := ScalarAndI64x8(LI64x8A, LI64x8B);
    AssertVecI64x8Equal('data-plane dispatch AndI64x8 should match scalar semantics case=' + IntToStr(LCaseIdx), LI64x8Scalar, LI64x8DataPlane);
    AssertVecI64x8Equal('data-plane dispatch AndI64x8 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.AndI64x8(LI64x8A, LI64x8B), LI64x8DataPlane);

    LI64x8DataPlane := LDataPlane^.Dispatch^.OrI64x8(LI64x8A, LI64x8B);
    LI64x8Scalar := ScalarOrI64x8(LI64x8A, LI64x8B);
    AssertVecI64x8Equal('data-plane dispatch OrI64x8 should match scalar semantics case=' + IntToStr(LCaseIdx), LI64x8Scalar, LI64x8DataPlane);
    AssertVecI64x8Equal('data-plane dispatch OrI64x8 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.OrI64x8(LI64x8A, LI64x8B), LI64x8DataPlane);

    LI64x8DataPlane := LDataPlane^.Dispatch^.XorI64x8(LI64x8A, LI64x8B);
    LI64x8Scalar := ScalarXorI64x8(LI64x8A, LI64x8B);
    AssertVecI64x8Equal('data-plane dispatch XorI64x8 should match scalar semantics case=' + IntToStr(LCaseIdx), LI64x8Scalar, LI64x8DataPlane);
    AssertVecI64x8Equal('data-plane dispatch XorI64x8 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.XorI64x8(LI64x8A, LI64x8B), LI64x8DataPlane);

    LI64x8DataPlane := LDataPlane^.Dispatch^.NotI64x8(LI64x8A);
    LI64x8Scalar := ScalarNotI64x8(LI64x8A);
    AssertVecI64x8Equal('data-plane dispatch NotI64x8 should match scalar semantics case=' + IntToStr(LCaseIdx), LI64x8Scalar, LI64x8DataPlane);
    AssertVecI64x8Equal('data-plane dispatch NotI64x8 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.NotI64x8(LI64x8A), LI64x8DataPlane);

    for LShiftIndex := 0 to High(C_SHIFT32) do
    begin
      LI32x16DataPlane := LDataPlane^.Dispatch^.ShiftLeftI32x16(LI32x16A, C_SHIFT32[LShiftIndex]);
      LI32x16Scalar := ScalarShiftLeftI32x16(LI32x16A, C_SHIFT32[LShiftIndex]);
      AssertVecI32x16Equal('data-plane dispatch ShiftLeftI32x16 should match scalar semantics case=' + IntToStr(LCaseIdx) + ' shift=' + IntToStr(C_SHIFT32[LShiftIndex]),
        LI32x16Scalar, LI32x16DataPlane);
      AssertVecI32x16Equal('data-plane dispatch ShiftLeftI32x16 should match direct dispatch case=' + IntToStr(LCaseIdx) + ' shift=' + IntToStr(C_SHIFT32[LShiftIndex]),
        LDirectDispatch^.ShiftLeftI32x16(LI32x16A, C_SHIFT32[LShiftIndex]), LI32x16DataPlane);

      LI32x16DataPlane := LDataPlane^.Dispatch^.ShiftRightArithI32x16(LI32x16A, C_SHIFT32[LShiftIndex]);
      LI32x16Scalar := ScalarShiftRightArithI32x16(LI32x16A, C_SHIFT32[LShiftIndex]);
      AssertVecI32x16Equal('data-plane dispatch ShiftRightArithI32x16 should match scalar semantics case=' + IntToStr(LCaseIdx) + ' shift=' + IntToStr(C_SHIFT32[LShiftIndex]),
        LI32x16Scalar, LI32x16DataPlane);
      AssertVecI32x16Equal('data-plane dispatch ShiftRightArithI32x16 should match direct dispatch case=' + IntToStr(LCaseIdx) + ' shift=' + IntToStr(C_SHIFT32[LShiftIndex]),
        LDirectDispatch^.ShiftRightArithI32x16(LI32x16A, C_SHIFT32[LShiftIndex]), LI32x16DataPlane);
    end;

    for LShiftIndex := 0 to High(C_SHIFT64) do
    begin
      LI64x4DataPlane := LDataPlane^.Dispatch^.ShiftRightI64x4(LI64x4A, C_SHIFT64[LShiftIndex]);
      LI64x4Scalar := ScalarShiftRightI64x4(LI64x4A, C_SHIFT64[LShiftIndex]);
      AssertVecI64x4Equal('data-plane dispatch ShiftRightI64x4 should match scalar semantics case=' + IntToStr(LCaseIdx) + ' shift=' + IntToStr(C_SHIFT64[LShiftIndex]),
        LI64x4Scalar, LI64x4DataPlane);
      AssertVecI64x4Equal('data-plane dispatch ShiftRightI64x4 should match direct dispatch case=' + IntToStr(LCaseIdx) + ' shift=' + IntToStr(C_SHIFT64[LShiftIndex]),
        LDirectDispatch^.ShiftRightI64x4(LI64x4A, C_SHIFT64[LShiftIndex]), LI64x4DataPlane);

      LI64x4DataPlane := LDataPlane^.Dispatch^.ShiftRightArithI64x4(LI64x4A, C_SHIFT64[LShiftIndex]);
      LI64x4Scalar := ScalarShiftRightArithI64x4(LI64x4A, C_SHIFT64[LShiftIndex]);
      AssertVecI64x4Equal('data-plane dispatch ShiftRightArithI64x4 should match scalar semantics case=' + IntToStr(LCaseIdx) + ' shift=' + IntToStr(C_SHIFT64[LShiftIndex]),
        LI64x4Scalar, LI64x4DataPlane);
      AssertVecI64x4Equal('data-plane dispatch ShiftRightArithI64x4 should match direct dispatch case=' + IntToStr(LCaseIdx) + ' shift=' + IntToStr(C_SHIFT64[LShiftIndex]),
        LDirectDispatch^.ShiftRightArithI64x4(LI64x4A, C_SHIFT64[LShiftIndex]), LI64x4DataPlane);
    end;
  end;
end;


procedure TTestCase_DataPlane.Test_DataPlane_WideArithmeticMinMaxSnapshot_Follows_CurrentDispatchSemantics;
var
  LDataPlane: PSimdDataPlane;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LI32x8A, LI32x8B: TVecI32x8;
  LU32x8A, LU32x8B: TVecU32x8;
  LI64x4A, LI64x4B: TVecI64x4;
  LU64x4A, LU64x4B: TVecU64x4;
  LI32x16A, LI32x16B: TVecI32x16;
  LU32x16A, LU32x16B: TVecU32x16;
  LI64x8A, LI64x8B: TVecI64x8;
  LU64x8A, LU64x8B: TVecU64x8;
  LI32x8DataPlane, LI32x8Scalar: TVecI32x8;
  LU32x8DataPlane, LU32x8Scalar: TVecU32x8;
  LI64x4DataPlane, LI64x4Scalar: TVecI64x4;
  LU64x4DataPlane, LU64x4Scalar: TVecU64x4;
  LI32x16DataPlane, LI32x16Scalar: TVecI32x16;
  LU32x16DataPlane, LU32x16Scalar: TVecU32x16;
  LI64x8DataPlane, LI64x8Scalar: TVecI64x8;
  LU64x8DataPlane, LU64x8Scalar: TVecU64x8;
  LCaseIdx: Integer;
  LLane: Integer;

  procedure AssertVecI32x8Equal(const aLabel: string; const aExpected, aActual: TVecI32x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      AssertEquals(aLabel + ' lane ' + IntToStr(LLaneIndex), aExpected.i[LLaneIndex], aActual.i[LLaneIndex]);
  end;

  procedure AssertVecU32x8Equal(const aLabel: string; const aExpected, aActual: TVecU32x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      AssertEquals(aLabel + ' lane ' + IntToStr(LLaneIndex), QWord(aExpected.u[LLaneIndex]), QWord(aActual.u[LLaneIndex]));
  end;

  procedure AssertVecI64x4Equal(const aLabel: string; const aExpected, aActual: TVecI64x4);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 3 do
      AssertEquals(aLabel + ' lane ' + IntToStr(LLaneIndex), aExpected.i[LLaneIndex], aActual.i[LLaneIndex]);
  end;

  procedure AssertVecU64x4Equal(const aLabel: string; const aExpected, aActual: TVecU64x4);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 3 do
      AssertEquals(aLabel + ' lane ' + IntToStr(LLaneIndex), QWord(aExpected.u[LLaneIndex]), QWord(aActual.u[LLaneIndex]));
  end;

  procedure AssertVecI32x16Equal(const aLabel: string; const aExpected, aActual: TVecI32x16);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 15 do
      AssertEquals(aLabel + ' lane ' + IntToStr(LLaneIndex), aExpected.i[LLaneIndex], aActual.i[LLaneIndex]);
  end;

  procedure AssertVecU32x16Equal(const aLabel: string; const aExpected, aActual: TVecU32x16);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 15 do
      AssertEquals(aLabel + ' lane ' + IntToStr(LLaneIndex), QWord(aExpected.u[LLaneIndex]), QWord(aActual.u[LLaneIndex]));
  end;

  procedure AssertVecI64x8Equal(const aLabel: string; const aExpected, aActual: TVecI64x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      AssertEquals(aLabel + ' lane ' + IntToStr(LLaneIndex), aExpected.i[LLaneIndex], aActual.i[LLaneIndex]);
  end;

  procedure AssertVecU64x8Equal(const aLabel: string; const aExpected, aActual: TVecU64x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      AssertEquals(aLabel + ' lane ' + IntToStr(LLaneIndex), QWord(aExpected.u[LLaneIndex]), QWord(aActual.u[LLaneIndex]));
  end;

  procedure LoadCase(const aCaseIdx: Integer);
  var
    LLaneIndex: Integer;
  begin
    case aCaseIdx of
      0:
        begin
          LI32x8A.i[0] := High(Int32);
          LI32x8A.i[1] := Low(Int32);
          LI32x8A.i[2] := -1;
          LI32x8A.i[3] := 0;
          LI32x8A.i[4] := $55555555;
          LI32x8A.i[5] := Int32($AAAAAAAA);
          LI32x8A.i[6] := Int32($40000001);
          LI32x8A.i[7] := -16;
          LI32x8B.i[0] := 1;
          LI32x8B.i[1] := -1;
          LI32x8B.i[2] := $7FFFFFFF;
          LI32x8B.i[3] := $55555555;
          LI32x8B.i[4] := High(Int32);
          LI32x8B.i[5] := Low(Int32);
          LI32x8B.i[6] := Int32($7F0F0F0F);
          LI32x8B.i[7] := 15;

          LU32x8A.u[0] := 0;
          LU32x8A.u[1] := 1;
          LU32x8A.u[2] := High(UInt32);
          LU32x8A.u[3] := $80000000;
          LU32x8A.u[4] := $7FFFFFFF;
          LU32x8A.u[5] := $AAAAAAAA;
          LU32x8A.u[6] := $55555555;
          LU32x8A.u[7] := 37;
          LU32x8B.u[0] := High(UInt32);
          LU32x8B.u[1] := 2;
          LU32x8B.u[2] := 3;
          LU32x8B.u[3] := $80000000;
          LU32x8B.u[4] := 1;
          LU32x8B.u[5] := $11111111;
          LU32x8B.u[6] := $AAAAAAAA;
          LU32x8B.u[7] := High(UInt32) - 15;

          LI64x4A.i[0] := High(Int64);
          LI64x4A.i[1] := Low(Int64);
          LI64x4A.i[2] := -1;
          LI64x4A.i[3] := Int64($4000000000000001);
          LI64x4B.i[0] := 1;
          LI64x4B.i[1] := -1;
          LI64x4B.i[2] := High(Int64);
          LI64x4B.i[3] := Low(Int64);

          LU64x4A.u[0] := 0;
          LU64x4A.u[1] := 1;
          LU64x4A.u[2] := High(QWord);
          LU64x4A.u[3] := QWord($8000000000000000);
          LU64x4B.u[0] := High(QWord);
          LU64x4B.u[1] := 2;
          LU64x4B.u[2] := 3;
          LU64x4B.u[3] := QWord($7FFFFFFFFFFFFFFF);

          for LLaneIndex := 0 to 15 do
          begin
            LI32x16A.i[LLaneIndex] := (LLaneIndex - 8) * 4099;
            LI32x16B.i[LLaneIndex] := (8 - LLaneIndex) * 2053;
            LU32x16A.u[LLaneIndex] := DWord(LLaneIndex * 257);
            LU32x16B.u[LLaneIndex] := DWord((15 - LLaneIndex) * 131);
          end;
          LI32x16A.i[0] := Low(Int32);
          LI32x16A.i[1] := -1;
          LI32x16A.i[2] := $55555555;
          LI32x16A.i[15] := High(Int32);
          LI32x16B.i[0] := 1;
          LI32x16B.i[1] := High(Int32);
          LI32x16B.i[2] := Int32($AAAAAAAA);
          LI32x16B.i[15] := Low(Int32);
          LU32x16A.u[0] := 0;
          LU32x16A.u[1] := High(UInt32);
          LU32x16A.u[2] := $80000000;
          LU32x16A.u[15] := $55555555;
          LU32x16B.u[0] := High(UInt32);
          LU32x16B.u[1] := 1;
          LU32x16B.u[2] := $80000000;
          LU32x16B.u[15] := $AAAAAAAA;

          for LLaneIndex := 0 to 7 do
          begin
            LI64x8A.i[LLaneIndex] := (LLaneIndex - 4) * 1025;
            LI64x8B.i[LLaneIndex] := (3 - LLaneIndex) * 511;
            LU64x8A.u[LLaneIndex] := QWord(LLaneIndex) * 257;
            LU64x8B.u[LLaneIndex] := QWord(7 - LLaneIndex) * 131;
          end;
          LI64x8A.i[0] := High(Int64);
          LI64x8A.i[1] := Low(Int64);
          LI64x8A.i[2] := -1;
          LI64x8A.i[7] := Int64($4000000000000001);
          LI64x8B.i[0] := 1;
          LI64x8B.i[1] := -1;
          LI64x8B.i[2] := High(Int64);
          LI64x8B.i[7] := Low(Int64);
          LU64x8A.u[0] := 0;
          LU64x8A.u[1] := 1;
          LU64x8A.u[2] := High(QWord);
          LU64x8A.u[7] := QWord($8000000000000000);
          LU64x8B.u[0] := High(QWord);
          LU64x8B.u[1] := 2;
          LU64x8B.u[2] := 3;
          LU64x8B.u[7] := QWord($7FFFFFFFFFFFFFFF);
        end;
      1:
        begin
          LI32x8A.i[0] := 0;
          LI32x8A.i[1] := 1;
          LI32x8A.i[2] := -1;
          LI32x8A.i[3] := 32;
          LI32x8A.i[4] := -32;
          LI32x8A.i[5] := 255;
          LI32x8A.i[6] := -255;
          LI32x8A.i[7] := 1024;
          LI32x8B.i[0] := 0;
          LI32x8B.i[1] := 2;
          LI32x8B.i[2] := -1;
          LI32x8B.i[3] := -32;
          LI32x8B.i[4] := 32;
          LI32x8B.i[5] := 15;
          LI32x8B.i[6] := -15;
          LI32x8B.i[7] := 7;

          LU32x8A.u[0] := 0;
          LU32x8A.u[1] := 1;
          LU32x8A.u[2] := 2;
          LU32x8A.u[3] := 3;
          LU32x8A.u[4] := 4;
          LU32x8A.u[5] := 5;
          LU32x8A.u[6] := 6;
          LU32x8A.u[7] := 7;
          LU32x8B.u[0] := 7;
          LU32x8B.u[1] := 6;
          LU32x8B.u[2] := 5;
          LU32x8B.u[3] := 4;
          LU32x8B.u[4] := 3;
          LU32x8B.u[5] := 2;
          LU32x8B.u[6] := 1;
          LU32x8B.u[7] := 0;

          LI64x4A.i[0] := 0;
          LI64x4A.i[1] := 1;
          LI64x4A.i[2] := -1;
          LI64x4A.i[3] := 4096;
          LI64x4B.i[0] := 0;
          LI64x4B.i[1] := 2;
          LI64x4B.i[2] := -2;
          LI64x4B.i[3] := -4096;

          LU64x4A.u[0] := 0;
          LU64x4A.u[1] := 1;
          LU64x4A.u[2] := QWord($100000000);
          LU64x4A.u[3] := QWord($AAAAAAAAAAAAAAAA);
          LU64x4B.u[0] := 0;
          LU64x4B.u[1] := 2;
          LU64x4B.u[2] := High(QWord);
          LU64x4B.u[3] := QWord($1111111111111111);

          for LLaneIndex := 0 to 15 do
          begin
            LI32x16A.i[LLaneIndex] := (LLaneIndex - 8) * 97;
            LI32x16B.i[LLaneIndex] := (8 - LLaneIndex) * 49;
            LU32x16A.u[LLaneIndex] := DWord(LLaneIndex * 33);
            LU32x16B.u[LLaneIndex] := DWord((15 - LLaneIndex) * 17);
          end;
          LI32x16A.i[0] := 0;
          LI32x16B.i[0] := 0;
          LI32x16A.i[7] := -1;
          LI32x16B.i[7] := 1;
          LI32x16A.i[15] := 4096;
          LI32x16B.i[15] := -4096;
          LU32x16A.u[1] := 1;
          LU32x16B.u[1] := High(UInt32);
          LU32x16A.u[15] := 255;
          LU32x16B.u[15] := 127;

          for LLaneIndex := 0 to 7 do
          begin
            LI64x8A.i[LLaneIndex] := (LLaneIndex - 4) * 73;
            LI64x8B.i[LLaneIndex] := (4 - LLaneIndex) * 19;
            LU64x8A.u[LLaneIndex] := QWord(LLaneIndex) * 41;
            LU64x8B.u[LLaneIndex] := QWord(7 - LLaneIndex) * 29;
          end;
          LI64x8A.i[0] := 0;
          LI64x8B.i[0] := 0;
          LI64x8A.i[7] := 8192;
          LI64x8B.i[7] := -4096;
          LU64x8A.u[2] := 1;
          LU64x8B.u[2] := High(QWord);
        end;
      2:
        begin
          LI32x8A.i[0] := 17;
          LI32x8A.i[1] := -17;
          LI32x8A.i[2] := 33;
          LI32x8A.i[3] := -33;
          LI32x8A.i[4] := 65;
          LI32x8A.i[5] := -65;
          LI32x8A.i[6] := 129;
          LI32x8A.i[7] := -129;
          LI32x8B.i[0] := 16;
          LI32x8B.i[1] := -18;
          LI32x8B.i[2] := 34;
          LI32x8B.i[3] := -32;
          LI32x8B.i[4] := 64;
          LI32x8B.i[5] := -66;
          LI32x8B.i[6] := 130;
          LI32x8B.i[7] := -128;

          LU32x8A.u[0] := $AAAAAAAA;
          LU32x8A.u[1] := $55555555;
          LU32x8A.u[2] := $0F0F0F0F;
          LU32x8A.u[3] := $F0F0F0F0;
          LU32x8A.u[4] := 9;
          LU32x8A.u[5] := 10;
          LU32x8A.u[6] := 11;
          LU32x8A.u[7] := 12;
          LU32x8B.u[0] := $AAAAAAAA;
          LU32x8B.u[1] := $AAAAAAAA;
          LU32x8B.u[2] := $F0F0F0F0;
          LU32x8B.u[3] := $0F0F0F0F;
          LU32x8B.u[4] := 8;
          LU32x8B.u[5] := 10;
          LU32x8B.u[6] := 12;
          LU32x8B.u[7] := 12;

          LI64x4A.i[0] := 99;
          LI64x4A.i[1] := -99;
          LI64x4A.i[2] := 2048;
          LI64x4A.i[3] := -2048;
          LI64x4B.i[0] := 100;
          LI64x4B.i[1] := -100;
          LI64x4B.i[2] := 2047;
          LI64x4B.i[3] := -2047;

          LU64x4A.u[0] := QWord($1010000000000000);
          LU64x4A.u[1] := QWord($1111000000000000);
          LU64x4A.u[2] := QWord($E0E0000000000000);
          LU64x4A.u[3] := QWord($F1F1000000000000);
          LU64x4B.u[0] := 1;
          LU64x4B.u[1] := 2;
          LU64x4B.u[2] := 3;
          LU64x4B.u[3] := 4;

          for LLaneIndex := 0 to 15 do
          begin
            LI32x16A.i[LLaneIndex] := (LLaneIndex * 257) - 1024;
            LI32x16B.i[LLaneIndex] := ((15 - LLaneIndex) * 131) - 512;
            LU32x16A.u[LLaneIndex] := DWord((LLaneIndex + 1) * 257);
            LU32x16B.u[LLaneIndex] := DWord((16 - LLaneIndex) * 131);
          end;
          LI32x16A.i[2] := -1;
          LI32x16B.i[2] := 1;
          LI32x16A.i[10] := 513;
          LI32x16B.i[10] := 514;
          LU32x16A.u[0] := 0;
          LU32x16B.u[0] := High(UInt32);
          LU32x16A.u[15] := $55555555;
          LU32x16B.u[15] := $AAAAAAAA;

          for LLaneIndex := 0 to 7 do
          begin
            LI64x8A.i[LLaneIndex] := Int64(LLaneIndex - 3) * 257;
            LI64x8B.i[LLaneIndex] := Int64(4 - LLaneIndex) * 131;
            LU64x8A.u[LLaneIndex] := QWord(LLaneIndex + 1) * 257;
            LU64x8B.u[LLaneIndex] := QWord(8 - LLaneIndex) * 131;
          end;
          LI64x8A.i[1] := -1;
          LI64x8B.i[1] := 1;
          LI64x8A.i[6] := 4096;
          LI64x8B.i[6] := 4095;
          LU64x8A.u[7] := QWord($8000000000000000);
          LU64x8B.u[7] := QWord($7FFFFFFFFFFFFFFF);
        end;
    else
      Fail('unexpected wide arithmetic/minmax data-plane case');
    end;
  end;
begin
  LDataPlane := GetCurrentSimdDataPlane;
  LDispatch := GetDispatchTable;
  LDirectDispatch := GetDirectDispatchTable;

  AssertNotNull('data-plane snapshot should be assigned for wide arithmetic/minmax snapshot test', LDataPlane);
  AssertNotNull('dispatch table should be assigned for wide arithmetic/minmax snapshot test', LDispatch);
  AssertNotNull('direct dispatch table should be assigned for wide arithmetic/minmax snapshot test', LDirectDispatch);
  AssertTrue('data-plane dispatch should match current dispatch for wide arithmetic/minmax snapshot test',
    LDataPlane^.Dispatch = LDispatch);

  AssertTrue('data-plane dispatch AddI32x8 should be assigned', Assigned(LDataPlane^.Dispatch^.AddI32x8));
  AssertTrue('data-plane dispatch MulI32x8 should be assigned', Assigned(LDataPlane^.Dispatch^.MulI32x8));
  AssertTrue('data-plane dispatch SubI32x8 should be assigned', Assigned(LDataPlane^.Dispatch^.SubI32x8));
  AssertTrue('data-plane dispatch AddU32x8 should be assigned', Assigned(LDataPlane^.Dispatch^.AddU32x8));
  AssertTrue('data-plane dispatch SubU32x8 should be assigned', Assigned(LDataPlane^.Dispatch^.SubU32x8));
  AssertTrue('data-plane dispatch MulU32x8 should be assigned', Assigned(LDataPlane^.Dispatch^.MulU32x8));
  AssertTrue('data-plane dispatch MinU32x8 should be assigned', Assigned(LDataPlane^.Dispatch^.MinU32x8));
  AssertTrue('data-plane dispatch MaxU32x8 should be assigned', Assigned(LDataPlane^.Dispatch^.MaxU32x8));
  AssertTrue('data-plane dispatch AddI64x4 should be assigned', Assigned(LDataPlane^.Dispatch^.AddI64x4));
  AssertTrue('data-plane dispatch SubI64x4 should be assigned', Assigned(LDataPlane^.Dispatch^.SubI64x4));
  AssertTrue('data-plane dispatch AddU64x4 should be assigned', Assigned(LDataPlane^.Dispatch^.AddU64x4));
  AssertTrue('data-plane dispatch SubU64x4 should be assigned', Assigned(LDataPlane^.Dispatch^.SubU64x4));
  AssertTrue('data-plane dispatch AddI32x16 should be assigned', Assigned(LDataPlane^.Dispatch^.AddI32x16));
  AssertTrue('data-plane dispatch MinI32x16 should be assigned', Assigned(LDataPlane^.Dispatch^.MinI32x16));
  AssertTrue('data-plane dispatch MulI32x16 should be assigned', Assigned(LDataPlane^.Dispatch^.MulI32x16));
  AssertTrue('data-plane dispatch MinU32x16 should be assigned', Assigned(LDataPlane^.Dispatch^.MinU32x16));
  AssertTrue('data-plane dispatch MulU32x16 should be assigned', Assigned(LDataPlane^.Dispatch^.MulU32x16));
  AssertTrue('data-plane dispatch MaxU32x16 should be assigned', Assigned(LDataPlane^.Dispatch^.MaxU32x16));
  AssertTrue('data-plane dispatch AddI64x8 should be assigned', Assigned(LDataPlane^.Dispatch^.AddI64x8));
  AssertTrue('data-plane dispatch SubI64x8 should be assigned', Assigned(LDataPlane^.Dispatch^.SubI64x8));
  AssertTrue('data-plane dispatch AddU64x8 should be assigned', Assigned(LDataPlane^.Dispatch^.AddU64x8));
  AssertTrue('data-plane dispatch SubU64x8 should be assigned', Assigned(LDataPlane^.Dispatch^.SubU64x8));

  for LCaseIdx := 0 to 2 do
  begin
    LoadCase(LCaseIdx);

    LI32x8DataPlane := LDataPlane^.Dispatch^.AddI32x8(LI32x8A, LI32x8B);
    LI32x8Scalar := ScalarAddI32x8(LI32x8A, LI32x8B);
    AssertVecI32x8Equal('data-plane dispatch AddI32x8 should match scalar semantics case=' + IntToStr(LCaseIdx), LI32x8Scalar, LI32x8DataPlane);
    AssertVecI32x8Equal('data-plane dispatch AddI32x8 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.AddI32x8(LI32x8A, LI32x8B), LI32x8DataPlane);

    LI32x8DataPlane := LDataPlane^.Dispatch^.MulI32x8(LI32x8A, LI32x8B);
    LI32x8Scalar := ScalarMulI32x8(LI32x8A, LI32x8B);
    AssertVecI32x8Equal('data-plane dispatch MulI32x8 should match scalar semantics case=' + IntToStr(LCaseIdx), LI32x8Scalar, LI32x8DataPlane);
    AssertVecI32x8Equal('data-plane dispatch MulI32x8 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.MulI32x8(LI32x8A, LI32x8B), LI32x8DataPlane);

    LI32x8DataPlane := LDataPlane^.Dispatch^.SubI32x8(LI32x8A, LI32x8B);
    LI32x8Scalar := ScalarSubI32x8(LI32x8A, LI32x8B);
    AssertVecI32x8Equal('data-plane dispatch SubI32x8 should match scalar semantics case=' + IntToStr(LCaseIdx), LI32x8Scalar, LI32x8DataPlane);
    AssertVecI32x8Equal('data-plane dispatch SubI32x8 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.SubI32x8(LI32x8A, LI32x8B), LI32x8DataPlane);

    LU32x8DataPlane := LDataPlane^.Dispatch^.AddU32x8(LU32x8A, LU32x8B);
    LU32x8Scalar := ScalarAddU32x8(LU32x8A, LU32x8B);
    AssertVecU32x8Equal('data-plane dispatch AddU32x8 should match scalar semantics case=' + IntToStr(LCaseIdx), LU32x8Scalar, LU32x8DataPlane);
    AssertVecU32x8Equal('data-plane dispatch AddU32x8 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.AddU32x8(LU32x8A, LU32x8B), LU32x8DataPlane);

    LU32x8DataPlane := LDataPlane^.Dispatch^.SubU32x8(LU32x8A, LU32x8B);
    LU32x8Scalar := ScalarSubU32x8(LU32x8A, LU32x8B);
    AssertVecU32x8Equal('data-plane dispatch SubU32x8 should match scalar semantics case=' + IntToStr(LCaseIdx), LU32x8Scalar, LU32x8DataPlane);
    AssertVecU32x8Equal('data-plane dispatch SubU32x8 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.SubU32x8(LU32x8A, LU32x8B), LU32x8DataPlane);

    LU32x8DataPlane := LDataPlane^.Dispatch^.MulU32x8(LU32x8A, LU32x8B);
    LU32x8Scalar := ScalarMulU32x8(LU32x8A, LU32x8B);
    AssertVecU32x8Equal('data-plane dispatch MulU32x8 should match scalar semantics case=' + IntToStr(LCaseIdx), LU32x8Scalar, LU32x8DataPlane);
    AssertVecU32x8Equal('data-plane dispatch MulU32x8 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.MulU32x8(LU32x8A, LU32x8B), LU32x8DataPlane);

    LU32x8DataPlane := LDataPlane^.Dispatch^.MinU32x8(LU32x8A, LU32x8B);
    LU32x8Scalar := ScalarMinU32x8(LU32x8A, LU32x8B);
    AssertVecU32x8Equal('data-plane dispatch MinU32x8 should match scalar semantics case=' + IntToStr(LCaseIdx), LU32x8Scalar, LU32x8DataPlane);
    AssertVecU32x8Equal('data-plane dispatch MinU32x8 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.MinU32x8(LU32x8A, LU32x8B), LU32x8DataPlane);

    LU32x8DataPlane := LDataPlane^.Dispatch^.MaxU32x8(LU32x8A, LU32x8B);
    LU32x8Scalar := ScalarMaxU32x8(LU32x8A, LU32x8B);
    AssertVecU32x8Equal('data-plane dispatch MaxU32x8 should match scalar semantics case=' + IntToStr(LCaseIdx), LU32x8Scalar, LU32x8DataPlane);
    AssertVecU32x8Equal('data-plane dispatch MaxU32x8 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.MaxU32x8(LU32x8A, LU32x8B), LU32x8DataPlane);

    LI64x4DataPlane := LDataPlane^.Dispatch^.AddI64x4(LI64x4A, LI64x4B);
    LI64x4Scalar := ScalarAddI64x4(LI64x4A, LI64x4B);
    AssertVecI64x4Equal('data-plane dispatch AddI64x4 should match scalar semantics case=' + IntToStr(LCaseIdx), LI64x4Scalar, LI64x4DataPlane);
    AssertVecI64x4Equal('data-plane dispatch AddI64x4 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.AddI64x4(LI64x4A, LI64x4B), LI64x4DataPlane);

    LI64x4DataPlane := LDataPlane^.Dispatch^.SubI64x4(LI64x4A, LI64x4B);
    LI64x4Scalar := ScalarSubI64x4(LI64x4A, LI64x4B);
    AssertVecI64x4Equal('data-plane dispatch SubI64x4 should match scalar semantics case=' + IntToStr(LCaseIdx), LI64x4Scalar, LI64x4DataPlane);
    AssertVecI64x4Equal('data-plane dispatch SubI64x4 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.SubI64x4(LI64x4A, LI64x4B), LI64x4DataPlane);

    LU64x4DataPlane := LDataPlane^.Dispatch^.AddU64x4(LU64x4A, LU64x4B);
    LU64x4Scalar := ScalarAddU64x4(LU64x4A, LU64x4B);
    AssertVecU64x4Equal('data-plane dispatch AddU64x4 should match scalar semantics case=' + IntToStr(LCaseIdx), LU64x4Scalar, LU64x4DataPlane);
    AssertVecU64x4Equal('data-plane dispatch AddU64x4 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.AddU64x4(LU64x4A, LU64x4B), LU64x4DataPlane);

    LU64x4DataPlane := LDataPlane^.Dispatch^.SubU64x4(LU64x4A, LU64x4B);
    LU64x4Scalar := ScalarSubU64x4(LU64x4A, LU64x4B);
    AssertVecU64x4Equal('data-plane dispatch SubU64x4 should match scalar semantics case=' + IntToStr(LCaseIdx), LU64x4Scalar, LU64x4DataPlane);
    AssertVecU64x4Equal('data-plane dispatch SubU64x4 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.SubU64x4(LU64x4A, LU64x4B), LU64x4DataPlane);

    LI32x16DataPlane := LDataPlane^.Dispatch^.AddI32x16(LI32x16A, LI32x16B);
    LI32x16Scalar := ScalarAddI32x16(LI32x16A, LI32x16B);
    AssertVecI32x16Equal('data-plane dispatch AddI32x16 should match scalar semantics case=' + IntToStr(LCaseIdx), LI32x16Scalar, LI32x16DataPlane);
    AssertVecI32x16Equal('data-plane dispatch AddI32x16 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.AddI32x16(LI32x16A, LI32x16B), LI32x16DataPlane);

    LI32x16DataPlane := LDataPlane^.Dispatch^.MinI32x16(LI32x16A, LI32x16B);
    LI32x16Scalar := ScalarMinI32x16(LI32x16A, LI32x16B);
    AssertVecI32x16Equal('data-plane dispatch MinI32x16 should match scalar semantics case=' + IntToStr(LCaseIdx), LI32x16Scalar, LI32x16DataPlane);
    AssertVecI32x16Equal('data-plane dispatch MinI32x16 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.MinI32x16(LI32x16A, LI32x16B), LI32x16DataPlane);

    LI32x16DataPlane := LDataPlane^.Dispatch^.MulI32x16(LI32x16A, LI32x16B);
    LI32x16Scalar := ScalarMulI32x16(LI32x16A, LI32x16B);
    AssertVecI32x16Equal('data-plane dispatch MulI32x16 should match scalar semantics case=' + IntToStr(LCaseIdx), LI32x16Scalar, LI32x16DataPlane);
    AssertVecI32x16Equal('data-plane dispatch MulI32x16 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.MulI32x16(LI32x16A, LI32x16B), LI32x16DataPlane);

    LU32x16DataPlane := LDataPlane^.Dispatch^.MulU32x16(LU32x16A, LU32x16B);
    LU32x16Scalar := ScalarMulU32x16(LU32x16A, LU32x16B);
    AssertVecU32x16Equal('data-plane dispatch MulU32x16 should match scalar semantics case=' + IntToStr(LCaseIdx), LU32x16Scalar, LU32x16DataPlane);
    AssertVecU32x16Equal('data-plane dispatch MulU32x16 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.MulU32x16(LU32x16A, LU32x16B), LU32x16DataPlane);

    LU32x16DataPlane := LDataPlane^.Dispatch^.MinU32x16(LU32x16A, LU32x16B);
    LU32x16Scalar := ScalarMinU32x16(LU32x16A, LU32x16B);
    AssertVecU32x16Equal('data-plane dispatch MinU32x16 should match scalar semantics case=' + IntToStr(LCaseIdx), LU32x16Scalar, LU32x16DataPlane);
    AssertVecU32x16Equal('data-plane dispatch MinU32x16 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.MinU32x16(LU32x16A, LU32x16B), LU32x16DataPlane);

    LU32x16DataPlane := LDataPlane^.Dispatch^.MaxU32x16(LU32x16A, LU32x16B);
    LU32x16Scalar := ScalarMaxU32x16(LU32x16A, LU32x16B);
    AssertVecU32x16Equal('data-plane dispatch MaxU32x16 should match scalar semantics case=' + IntToStr(LCaseIdx), LU32x16Scalar, LU32x16DataPlane);
    AssertVecU32x16Equal('data-plane dispatch MaxU32x16 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.MaxU32x16(LU32x16A, LU32x16B), LU32x16DataPlane);

    LI64x8DataPlane := LDataPlane^.Dispatch^.AddI64x8(LI64x8A, LI64x8B);
    LI64x8Scalar := ScalarAddI64x8(LI64x8A, LI64x8B);
    AssertVecI64x8Equal('data-plane dispatch AddI64x8 should match scalar semantics case=' + IntToStr(LCaseIdx), LI64x8Scalar, LI64x8DataPlane);
    AssertVecI64x8Equal('data-plane dispatch AddI64x8 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.AddI64x8(LI64x8A, LI64x8B), LI64x8DataPlane);

    LI64x8DataPlane := LDataPlane^.Dispatch^.SubI64x8(LI64x8A, LI64x8B);
    LI64x8Scalar := ScalarSubI64x8(LI64x8A, LI64x8B);
    AssertVecI64x8Equal('data-plane dispatch SubI64x8 should match scalar semantics case=' + IntToStr(LCaseIdx), LI64x8Scalar, LI64x8DataPlane);
    AssertVecI64x8Equal('data-plane dispatch SubI64x8 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.SubI64x8(LI64x8A, LI64x8B), LI64x8DataPlane);

    LU64x8DataPlane := LDataPlane^.Dispatch^.AddU64x8(LU64x8A, LU64x8B);
    LU64x8Scalar := ScalarAddU64x8(LU64x8A, LU64x8B);
    AssertVecU64x8Equal('data-plane dispatch AddU64x8 should match scalar semantics case=' + IntToStr(LCaseIdx), LU64x8Scalar, LU64x8DataPlane);
    AssertVecU64x8Equal('data-plane dispatch AddU64x8 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.AddU64x8(LU64x8A, LU64x8B), LU64x8DataPlane);

    LU64x8DataPlane := LDataPlane^.Dispatch^.SubU64x8(LU64x8A, LU64x8B);
    LU64x8Scalar := ScalarSubU64x8(LU64x8A, LU64x8B);
    AssertVecU64x8Equal('data-plane dispatch SubU64x8 should match scalar semantics case=' + IntToStr(LCaseIdx), LU64x8Scalar, LU64x8DataPlane);
    AssertVecU64x8Equal('data-plane dispatch SubU64x8 should match direct dispatch case=' + IntToStr(LCaseIdx),
      LDirectDispatch^.SubU64x8(LU64x8A, LU64x8B), LU64x8DataPlane);
  end;
end;

procedure TTestCase_DataPlane.Test_DataPlane_Rebind_Tracks_ControlPlane_Switch;
var
  LBefore: PSimdDataPlane;
  LAfter: PSimdDataPlane;
  LOriginalBackend: TSimdBackend;
  LTargetBackend: TSimdBackend;
  LDispatchable: TSimdBackendArray;
  LFoundDifferent: Boolean;
  LIndex: Integer;
begin
  LBefore := GetCurrentSimdDataPlane;
  LOriginalBackend := GetCurrentBackend;
  LTargetBackend := LOriginalBackend;
  LFoundDifferent := False;

  LDispatchable := GetDispatchableBackendList;
  for LIndex := 0 to High(LDispatchable) do
    if LDispatchable[LIndex] <> LOriginalBackend then
    begin
      LTargetBackend := LDispatchable[LIndex];
      LFoundDifferent := True;
      Break;
    end;

  if not LFoundDifferent then
    Exit;

  try
    AssertTrue('TrySetActiveBackend(target) should succeed in data-plane rebind test',
      TrySetActiveBackend(LTargetBackend));
    LAfter := GetCurrentSimdDataPlane;

    AssertTrue('data-plane snapshot should be assigned after backend switch', LAfter <> nil);
    AssertEquals('data-plane active backend should track switched backend',
      Ord(LTargetBackend), Ord(LAfter^.ActiveBackend));
    AssertTrue('data-plane dispatch should match current dispatch after backend switch',
      LAfter^.Dispatch = GetDispatchTable);
    AssertTrue('direct dispatch should track data-plane after backend switch',
      GetDirectDispatchTable = LAfter^.Dispatch);
    AssertTrue('rebind to a different backend should publish a fresh data-plane snapshot',
      PtrUInt(LBefore) <> PtrUInt(LAfter));
  finally
    if GetCurrentBackend <> LOriginalBackend then
      AssertTrue('restoring original backend should succeed after data-plane rebind test',
        TrySetActiveBackend(LOriginalBackend));
  end;
end;

initialization
  RegisterTest(TTestCase_DataPlane);

end.
