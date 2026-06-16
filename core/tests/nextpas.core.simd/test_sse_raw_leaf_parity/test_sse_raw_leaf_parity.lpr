program test_sse_raw_leaf_parity;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  nextpas.core.simd.intrinsics.base,
  nextpas.core.simd.intrinsics.sse,
  nextpas.core.simd.memutils;

type
  TSingleArray4 = array[0..3] of Single;
  PSingleArray4 = ^TSingleArray4;
  TSingleArray5 = array[0..4] of Single;
  PSingleArray5 = ^TSingleArray5;
  TSingleArray9 = array[0..8] of Single;
  PSingleArray9 = ^TSingleArray9;
  TQWordArray2 = array[0..1] of QWord;
  PQWordArray2 = ^TQWordArray2;
  TQWordArray3 = array[0..2] of QWord;
  PQWordArray3 = ^TQWordArray3;

var
  GPass: Integer = 0;
  GFail: Integer = 0;

procedure CheckF32(const aName: string; aExpected, aActual: Single);
begin
  if Abs(aExpected - aActual) <= 1e-6 then
    Inc(GPass)
  else
  begin
    WriteLn('FAIL: ', aName, ' expected=', aExpected:0:6, ' got=', aActual:0:6);
    Inc(GFail);
  end;
end;

procedure CheckF32Relative(const aName: string; aExpected, aActual, aRelTol: Single);
var
  LScale: Single;
begin
  LScale := Max(Abs(aExpected), 1.0);
  if Abs(aExpected - aActual) <= aRelTol * LScale then
    Inc(GPass)
  else
  begin
    WriteLn(
      'FAIL: ',
      aName,
      ' expected=',
      aExpected:0:6,
      ' got=',
      aActual:0:6,
      ' rel=',
      (Abs(aExpected - aActual) / LScale):0:6
    );
    Inc(GFail);
  end;
end;

procedure CheckU64(const aName: string; aExpected, aActual: QWord);
begin
  if aExpected = aActual then
    Inc(GPass)
  else
  begin
    WriteLn(
      'FAIL: ',
      aName,
      ' expected=$',
      IntToHex(aExpected, 16),
      ' got=$',
      IntToHex(aActual, 16)
    );
    Inc(GFail);
  end;
end;

procedure CheckI32(const aName: string; aExpected, aActual: LongInt);
begin
  if aExpected = aActual then
    Inc(GPass)
  else
  begin
    WriteLn('FAIL: ', aName, ' expected=', aExpected, ' got=', aActual);
    Inc(GFail);
  end;
end;

procedure CheckU32(const aName: string; aExpected, aActual: DWord);
begin
  if aExpected = aActual then
    Inc(GPass)
  else
  begin
    WriteLn(
      'FAIL: ',
      aName,
      ' expected=$',
      IntToHex(aExpected, 8),
      ' got=$',
      IntToHex(aActual, 8)
    );
    Inc(GFail);
  end;
end;

procedure CheckU32x4(const aName: string; const aActual: TM128; const aExpected: array of DWord);
var
  LIndex: Integer;
begin
  if Length(aExpected) <> 4 then
  begin
    WriteLn('FAIL: ', aName, ' expected 4 lanes, got=', Length(aExpected));
    Inc(GFail);
    Exit;
  end;

  for LIndex := 0 to 3 do
    CheckU32(Format('%s[%d]', [aName, LIndex]), aExpected[LIndex], aActual.m128i_u32[LIndex]);
end;

procedure CheckMaskI32x4(const aName: string; const aActual: TM128; const aExpected: array of Integer);
var
  LIndex: Integer;
begin
  if Length(aExpected) <> 4 then
  begin
    WriteLn('FAIL: ', aName, ' expected 4 lanes, got=', Length(aExpected));
    Inc(GFail);
    Exit;
  end;

  for LIndex := 0 to 3 do
    CheckI32(Format('%s[%d]', [aName, LIndex]), aExpected[LIndex], aActual.m128i_i32[LIndex]);
end;

procedure CheckVector4(
  const aName: string;
  const aActual: TM128;
  aExpected0, aExpected1, aExpected2, aExpected3: Single
);
begin
  CheckF32(aName + '[0]', aExpected0, aActual.m128_f32[0]);
  CheckF32(aName + '[1]', aExpected1, aActual.m128_f32[1]);
  CheckF32(aName + '[2]', aExpected2, aActual.m128_f32[2]);
  CheckF32(aName + '[3]', aExpected3, aActual.m128_f32[3]);
end;

procedure CheckZeroVector(const aName: string; const aActual: TM128);
begin
  CheckVector4(aName, aActual, 0.0, 0.0, 0.0, 0.0);
end;

procedure CheckScalarMaskWithHigh(
  const aName: string;
  const aActual: TM128;
  aExpectedMask: LongInt;
  aExpected1, aExpected2, aExpected3: Single
);
begin
  CheckI32(aName + '[0]', aExpectedMask, aActual.m128i_i32[0]);
  CheckF32(aName + '[1]', aExpected1, aActual.m128_f32[1]);
  CheckF32(aName + '[2]', aExpected2, aActual.m128_f32[2]);
  CheckF32(aName + '[3]', aExpected3, aActual.m128_f32[3]);
end;

function AlternateRoundModeCsr(aOriginalCsr: Integer): Integer;
begin
  case aOriginalCsr and $6000 of
    0:
      Result := (aOriginalCsr and not $6000) or $2000;
    $2000:
      Result := (aOriginalCsr and not $6000) or $4000;
    $4000:
      Result := (aOriginalCsr and not $6000) or $6000;
  else
    Result := aOriginalCsr and not $6000;
  end;
end;

procedure TestNilLoadsReturnZero;
var
  LValue: TM128;
begin
  LValue := sse_load_ps(nil);
  CheckZeroVector('sse_load_ps(nil)', LValue);

  LValue := sse_loadu_ps(nil);
  CheckZeroVector('sse_loadu_ps(nil)', LValue);

  LValue := sse_load_ss(nil);
  CheckZeroVector('sse_load_ss(nil)', LValue);

  LValue := sse_load1_ps(nil);
  CheckZeroVector('sse_load1_ps(nil)', LValue);

  LValue := sse_movq(nil);
  CheckZeroVector('sse_movq(nil)', LValue);
end;

procedure TestLoadStoreAndSetFamily;
const
  ScalarWindowLeft = 100.0;
  ScalarWindowRight = 300.0;
  MovqStoreSentinel = QWord($5AD15AD15AD15AD1);
var
  LAlignedLoadData: PSingleArray4;
  LAlignedStoreData: PSingleArray4;
  LAlignedUnalignedData: PSingleArray5;
  LAlignedQWords: PQWordArray2;
  LUnalignedLoad: PSingle;
  LUnalignedStore: PSingle;
  LScalarWindow: array[0..2] of Single;
  LMovqStoreWindow: TQWordArray2;
  LValue: TM128;
begin
  LAlignedLoadData := PSingleArray4(AlignedAlloc(SizeOf(TSingleArray4), 16));
  LAlignedStoreData := PSingleArray4(AlignedAlloc(SizeOf(TSingleArray4), 16));
  LAlignedUnalignedData := PSingleArray5(AlignedAlloc(SizeOf(TSingleArray5), 16));
  LAlignedQWords := PQWordArray2(AlignedAlloc(SizeOf(TQWordArray2), 16));
  if (LAlignedLoadData = nil) or (LAlignedStoreData = nil) or
     (LAlignedUnalignedData = nil) or (LAlignedQWords = nil) then
  begin
    WriteLn('FAIL: aligned allocation failed');
    Inc(GFail);
    if LAlignedLoadData <> nil then
      AlignedFree(LAlignedLoadData);
    if LAlignedStoreData <> nil then
      AlignedFree(LAlignedStoreData);
    if LAlignedUnalignedData <> nil then
      AlignedFree(LAlignedUnalignedData);
    if LAlignedQWords <> nil then
      AlignedFree(LAlignedQWords);
    Exit;
  end;

  try
    LAlignedLoadData^[0] := 1.25;
    LAlignedLoadData^[1] := -2.5;
    LAlignedLoadData^[2] := 3.75;
    LAlignedLoadData^[3] := -4.5;

    LValue := sse_load_ps(LAlignedLoadData);
    CheckVector4('sse_load_ps', LValue, 1.25, -2.5, 3.75, -4.5);

    LAlignedUnalignedData^[0] := -99.0;
    LAlignedUnalignedData^[1] := 10.0;
    LAlignedUnalignedData^[2] := 20.0;
    LAlignedUnalignedData^[3] := 30.0;
    LAlignedUnalignedData^[4] := 40.0;
    LUnalignedLoad := @LAlignedUnalignedData^[1];
    LValue := sse_loadu_ps(LUnalignedLoad);
    CheckVector4('sse_loadu_ps', LValue, 10.0, 20.0, 30.0, 40.0);

    LValue := sse_load_ss(@LAlignedLoadData^[2]);
    CheckVector4('sse_load_ss', LValue, 3.75, 0.0, 0.0, 0.0);

    LValue := sse_load1_ps(@LAlignedLoadData^[1]);
    CheckVector4('sse_load1_ps', LValue, -2.5, -2.5, -2.5, -2.5);

    LValue := sse_setr_ps(5.0, 6.0, 7.0, 8.0);
    sse_store_ps(LAlignedStoreData^[0], LValue);
    CheckF32('sse_store_ps[0]', 5.0, LAlignedStoreData^[0]);
    CheckF32('sse_store_ps[1]', 6.0, LAlignedStoreData^[1]);
    CheckF32('sse_store_ps[2]', 7.0, LAlignedStoreData^[2]);
    CheckF32('sse_store_ps[3]', 8.0, LAlignedStoreData^[3]);

    LAlignedUnalignedData^[0] := -11.0;
    LAlignedUnalignedData^[1] := -22.0;
    LAlignedUnalignedData^[2] := -33.0;
    LAlignedUnalignedData^[3] := -44.0;
    LAlignedUnalignedData^[4] := -55.0;
    LUnalignedStore := @LAlignedUnalignedData^[1];
    LValue := sse_setr_ps(-1.0, -2.0, -3.0, -4.0);
    sse_storeu_ps(LUnalignedStore^, LValue);
    CheckF32('sse_storeu_ps[0]', -11.0, LAlignedUnalignedData^[0]);
    CheckF32('sse_storeu_ps[1]', -1.0, LAlignedUnalignedData^[1]);
    CheckF32('sse_storeu_ps[2]', -2.0, LAlignedUnalignedData^[2]);
    CheckF32('sse_storeu_ps[3]', -3.0, LAlignedUnalignedData^[3]);
    CheckF32('sse_storeu_ps[4]', -4.0, LAlignedUnalignedData^[4]);

    LScalarWindow[0] := ScalarWindowLeft;
    LScalarWindow[1] := 0.0;
    LScalarWindow[2] := ScalarWindowRight;
    LValue := sse_setr_ps(12.5, 88.0, 99.0, 77.0);
    sse_store_ss(LScalarWindow[1], LValue);
    CheckF32('sse_store_ss[left]', ScalarWindowLeft, LScalarWindow[0]);
    CheckF32('sse_store_ss[value]', 12.5, LScalarWindow[1]);
    CheckF32('sse_store_ss[right]', ScalarWindowRight, LScalarWindow[2]);

    LValue := sse_setr_ps(6.25, 100.0, 200.0, 300.0);
    sse_store1_ps(LAlignedStoreData^[0], LValue);
    CheckF32('sse_store1_ps[0]', 6.25, LAlignedStoreData^[0]);
    CheckF32('sse_store1_ps[1]', 6.25, LAlignedStoreData^[1]);
    CheckF32('sse_store1_ps[2]', 6.25, LAlignedStoreData^[2]);
    CheckF32('sse_store1_ps[3]', 6.25, LAlignedStoreData^[3]);

    LAlignedQWords^[0] := $0123456789ABCDEF;
    LAlignedQWords^[1] := $6EEDFACECAFEBEEF;
    LValue := sse_movq(@LAlignedQWords^[0]);
    CheckU64('sse_movq[0]', $0123456789ABCDEF, LValue.m128i_u64[0]);
    CheckU64('sse_movq[1]', 0, LValue.m128i_u64[1]);

    FillChar(LValue, SizeOf(LValue), 0);
    LValue.m128i_u64[0] := $1122334455667788;
    LValue.m128i_u64[1] := $19AABBCCDDEEFF00;
    LMovqStoreWindow[0] := 0;
    LMovqStoreWindow[1] := MovqStoreSentinel;
    sse_movq_store(LMovqStoreWindow[0], LValue);
    CheckU64('sse_movq_store[0]', $1122334455667788, LMovqStoreWindow[0]);
    CheckU64('sse_movq_store[1]', MovqStoreSentinel, LMovqStoreWindow[1]);

    LValue := sse_setzero_ps;
    CheckZeroVector('sse_setzero_ps', LValue);

    LValue := sse_set1_ps(-9.0);
    CheckVector4('sse_set1_ps', LValue, -9.0, -9.0, -9.0, -9.0);

    LValue := sse_set_ps(40.0, 30.0, 20.0, 10.0);
    CheckVector4('sse_set_ps', LValue, 10.0, 20.0, 30.0, 40.0);

    LValue := sse_set_ss(-7.5);
    CheckVector4('sse_set_ss', LValue, -7.5, 0.0, 0.0, 0.0);

    LValue := sse_setr_ps(1.0, 2.0, 3.0, 4.0);
    CheckVector4('sse_setr_ps', LValue, 1.0, 2.0, 3.0, 4.0);
  finally
    AlignedFree(LAlignedLoadData);
    AlignedFree(LAlignedStoreData);
    AlignedFree(LAlignedUnalignedData);
    AlignedFree(LAlignedQWords);
  end;
end;

procedure TestMoveAndShuffleFamily;
var
  LA: TM128;
  LB: TM128;
  LValue: TM128;
begin
  LA := sse_setr_ps(10.0, 20.0, 30.0, 40.0);
  LB := sse_setr_ps(1.0, 2.0, 3.0, 4.0);

  LValue := sse_movaps(LA);
  CheckVector4('sse_movaps', LValue, 10.0, 20.0, 30.0, 40.0);

  LValue := sse_movups(LB);
  CheckVector4('sse_movups', LValue, 1.0, 2.0, 3.0, 4.0);

  LValue := sse_movss(LA);
  CheckVector4('sse_movss', LValue, 10.0, 0.0, 0.0, 0.0);

  LValue := sse_move_ss(LA, LB);
  CheckVector4('sse_move_ss', LValue, 1.0, 20.0, 30.0, 40.0);

  LValue := sse_movehl_ps(LA, LB);
  CheckVector4('sse_movehl_ps', LValue, 3.0, 4.0, 30.0, 40.0);

  LValue := sse_movelh_ps(LA, LB);
  CheckVector4('sse_movelh_ps', LValue, 10.0, 20.0, 1.0, 2.0);

  LValue := sse_movhl_ps(LA, LB);
  CheckVector4('sse_movhl_ps', LValue, 3.0, 4.0, 30.0, 40.0);

  LValue := sse_movlh_ps(LA, LB);
  CheckVector4('sse_movlh_ps', LValue, 10.0, 20.0, 1.0, 2.0);

  CheckI32('sse_movemask_ps', 5, sse_movemask_ps(sse_setr_ps(-1.0, 2.0, -3.0, 4.0)));

  LValue := sse_shuffle_ps(LA, LB, $1B);
  CheckVector4('sse_shuffle_ps', LValue, 40.0, 30.0, 2.0, 1.0);

  LValue := sse_unpackhi_ps(LA, LB);
  CheckVector4('sse_unpackhi_ps', LValue, 30.0, 3.0, 40.0, 4.0);

  LValue := sse_unpacklo_ps(LA, LB);
  CheckVector4('sse_unpacklo_ps', LValue, 10.0, 1.0, 20.0, 2.0);

  LValue := sse_unpckhps(LA, LB);
  CheckVector4('sse_unpckhps', LValue, 30.0, 3.0, 40.0, 4.0);

  LValue := sse_unpcklps(LA, LB);
  CheckVector4('sse_unpcklps', LValue, 10.0, 1.0, 20.0, 2.0);
end;

procedure TestArithmeticAndMinMaxFamily;
var
  LVectorA: TM128;
  LVectorB: TM128;
  LScalarB: TM128;
  LMinMaxB: TM128;
  LMinScalarB: TM128;
  LMaxScalarB: TM128;
  LValue: TM128;
begin
  LVectorA := sse_setr_ps(10.0, 20.0, 30.0, 40.0);
  LVectorB := sse_setr_ps(1.0, 2.0, 3.0, 4.0);
  LScalarB := sse_setr_ps(2.0, 200.0, 300.0, 400.0);
  LMinMaxB := sse_setr_ps(15.0, 15.0, 35.0, 35.0);
  LMinScalarB := sse_setr_ps(5.0, 200.0, 300.0, 400.0);
  LMaxScalarB := sse_setr_ps(15.0, 200.0, 300.0, 400.0);

  LValue := sse_add_ps(LVectorA, LVectorB);
  CheckVector4('sse_add_ps', LValue, 11.0, 22.0, 33.0, 44.0);

  LValue := sse_add_ss(LVectorA, LScalarB);
  CheckVector4('sse_add_ss', LValue, 12.0, 20.0, 30.0, 40.0);

  LValue := sse_sub_ps(LVectorA, LVectorB);
  CheckVector4('sse_sub_ps', LValue, 9.0, 18.0, 27.0, 36.0);

  LValue := sse_sub_ss(LVectorA, LScalarB);
  CheckVector4('sse_sub_ss', LValue, 8.0, 20.0, 30.0, 40.0);

  LValue := sse_mul_ps(LVectorA, LVectorB);
  CheckVector4('sse_mul_ps', LValue, 10.0, 40.0, 90.0, 160.0);

  LValue := sse_mul_ss(LVectorA, LScalarB);
  CheckVector4('sse_mul_ss', LValue, 20.0, 20.0, 30.0, 40.0);

  LValue := sse_div_ps(LVectorA, LVectorB);
  CheckVector4('sse_div_ps', LValue, 10.0, 10.0, 10.0, 10.0);

  LValue := sse_div_ss(LVectorA, LScalarB);
  CheckVector4('sse_div_ss', LValue, 5.0, 20.0, 30.0, 40.0);

  LValue := sse_min_ps(LVectorA, LMinMaxB);
  CheckVector4('sse_min_ps', LValue, 10.0, 15.0, 30.0, 35.0);

  LValue := sse_min_ss(LVectorA, LMinScalarB);
  CheckVector4('sse_min_ss', LValue, 5.0, 20.0, 30.0, 40.0);

  LValue := sse_max_ps(LVectorA, LMinMaxB);
  CheckVector4('sse_max_ps', LValue, 15.0, 20.0, 35.0, 40.0);

  LValue := sse_max_ss(LVectorA, LMaxScalarB);
  CheckVector4('sse_max_ss', LValue, 15.0, 20.0, 30.0, 40.0);
end;

procedure TestBitwiseFamily;
var
  LVectorA: TM128;
  LVectorB: TM128;
  LValue: TM128;
begin
  LVectorA.m128i_u32[0] := $FFFF0000;
  LVectorA.m128i_u32[1] := $12345678;
  LVectorA.m128i_u32[2] := $0F0F0F0F;
  LVectorA.m128i_u32[3] := $AAAAAAAA;

  LVectorB.m128i_u32[0] := $0FF00FF0;
  LVectorB.m128i_u32[1] := $FFFF0000;
  LVectorB.m128i_u32[2] := $3333CCCC;
  LVectorB.m128i_u32[3] := $55555555;

  LValue := sse_and_ps(LVectorA, LVectorB);
  CheckU32x4('sse_and_ps', LValue, [$0FF00000, $12340000, $03030C0C, $00000000]);

  LValue := sse_andnot_ps(LVectorA, LVectorB);
  CheckU32x4('sse_andnot_ps', LValue, [$00000FF0, $EDCB0000, $3030C0C0, $55555555]);

  LValue := sse_andn_ps(LVectorA, LVectorB);
  CheckU32x4('sse_andn_ps', LValue, [$00000FF0, $EDCB0000, $3030C0C0, $55555555]);

  LValue := sse_or_ps(LVectorA, LVectorB);
  CheckU32x4('sse_or_ps', LValue, [$FFFF0FF0, $FFFF5678, $3F3FCFCF, $FFFFFFFF]);

  LValue := sse_xor_ps(LVectorA, LVectorB);
  CheckU32x4('sse_xor_ps', LValue, [$F00F0FF0, $EDCB5678, $3C3CC3C3, $FFFFFFFF]);
end;

procedure TestConversionAndMovdFamily;
const
  MovdValue = -42;
var
  LConvertA: TM128;
  LRoundPositive: TM128;
  LRoundNegative: TM128;
  LValue: TM128;
begin
  LValue := sse_movd(MovdValue);
  CheckU32x4('sse_movd', LValue, [$FFFFFFD6, $00000000, $00000000, $00000000]);
  CheckI32('sse_movd_toint', MovdValue, sse_movd_toint(LValue));

  LConvertA := sse_setr_ps(100.0, 20.0, 30.0, 40.0);
  LValue := sse_cvtsi2ss(LConvertA, MovdValue);
  CheckVector4('sse_cvtsi2ss', LValue, -42.0, 20.0, 30.0, 40.0);

  LRoundPositive := sse_setr_ps(12.75, 200.0, 300.0, 400.0);
  CheckI32('sse_cvtss2si(+)', 13, sse_cvtss2si(LRoundPositive));
  CheckI32('sse_cvttss2si(+)', 12, sse_cvttss2si(LRoundPositive));

  LRoundNegative := sse_setr_ps(-12.75, 200.0, 300.0, 400.0);
  CheckI32('sse_cvtss2si(-)', -13, sse_cvtss2si(LRoundNegative));
  CheckI32('sse_cvttss2si(-)', -12, sse_cvttss2si(LRoundNegative));
end;

procedure TestCompareFamily;
const
  MaskTrue32 = -1;
var
  LFiniteA: TM128;
  LFiniteB: TM128;
  LUnorderedA: TM128;
  LUnorderedB: TM128;
  LNeqA: TM128;
  LNeqB: TM128;
  LScalarA: TM128;
  LScalarB: TM128;
  LValue: TM128;
begin
  LFiniteA := sse_setr_ps(5.0, 7.0, 9.0, 11.0);
  LFiniteB := sse_setr_ps(5.0, 8.0, 8.0, 12.0);
  LUnorderedA := sse_setr_ps(NaN, 7.0, NaN, 11.0);
  LUnorderedB := sse_setr_ps(5.0, NaN, NaN, 12.0);
  LNeqA := sse_setr_ps(NaN, 7.0, 8.0, 11.0);
  LNeqB := sse_setr_ps(5.0, NaN, 8.0, 12.0);

  LValue := sse_cmpeq_ps(LFiniteA, LFiniteB);
  CheckMaskI32x4('sse_cmpeq_ps', LValue, [MaskTrue32, 0, 0, 0]);

  LValue := sse_cmplt_ps(LFiniteA, LFiniteB);
  CheckMaskI32x4('sse_cmplt_ps', LValue, [0, MaskTrue32, 0, MaskTrue32]);

  LValue := sse_cmple_ps(LFiniteA, LFiniteB);
  CheckMaskI32x4('sse_cmple_ps', LValue, [MaskTrue32, MaskTrue32, 0, MaskTrue32]);

  LValue := sse_cmpgt_ps(LFiniteA, LFiniteB);
  CheckMaskI32x4('sse_cmpgt_ps', LValue, [0, 0, MaskTrue32, 0]);

  LValue := sse_cmpge_ps(LFiniteA, LFiniteB);
  CheckMaskI32x4('sse_cmpge_ps', LValue, [MaskTrue32, 0, MaskTrue32, 0]);

  LValue := sse_cmpneq_ps(LNeqA, LNeqB);
  CheckMaskI32x4('sse_cmpneq_ps', LValue, [MaskTrue32, MaskTrue32, 0, MaskTrue32]);

  LValue := sse_cmpord_ps(LUnorderedA, LUnorderedB);
  CheckMaskI32x4('sse_cmpord_ps', LValue, [0, 0, 0, MaskTrue32]);

  LValue := sse_cmpunord_ps(LUnorderedA, LUnorderedB);
  CheckMaskI32x4('sse_cmpunord_ps', LValue, [MaskTrue32, MaskTrue32, MaskTrue32, 0]);

  LScalarA := sse_setr_ps(5.0, 20.0, 30.0, 40.0);
  LScalarB := sse_setr_ps(5.0, 99.0, 88.0, 77.0);
  LValue := sse_cmpeq_ss(LScalarA, LScalarB);
  CheckScalarMaskWithHigh('sse_cmpeq_ss', LValue, MaskTrue32, 20.0, 30.0, 40.0);

  LScalarA := sse_setr_ps(3.0, 20.0, 30.0, 40.0);
  LScalarB := sse_setr_ps(5.0, 99.0, 88.0, 77.0);
  LValue := sse_cmplt_ss(LScalarA, LScalarB);
  CheckScalarMaskWithHigh('sse_cmplt_ss', LValue, MaskTrue32, 20.0, 30.0, 40.0);

  LScalarA := sse_setr_ps(5.0, 20.0, 30.0, 40.0);
  LScalarB := sse_setr_ps(5.0, 99.0, 88.0, 77.0);
  LValue := sse_cmple_ss(LScalarA, LScalarB);
  CheckScalarMaskWithHigh('sse_cmple_ss', LValue, MaskTrue32, 20.0, 30.0, 40.0);

  LScalarA := sse_setr_ps(9.0, 20.0, 30.0, 40.0);
  LScalarB := sse_setr_ps(5.0, 99.0, 88.0, 77.0);
  LValue := sse_cmpgt_ss(LScalarA, LScalarB);
  CheckScalarMaskWithHigh('sse_cmpgt_ss', LValue, MaskTrue32, 20.0, 30.0, 40.0);

  LScalarA := sse_setr_ps(5.0, 20.0, 30.0, 40.0);
  LScalarB := sse_setr_ps(5.0, 99.0, 88.0, 77.0);
  LValue := sse_cmpge_ss(LScalarA, LScalarB);
  CheckScalarMaskWithHigh('sse_cmpge_ss', LValue, MaskTrue32, 20.0, 30.0, 40.0);

  LScalarA := sse_setr_ps(NaN, 20.0, 30.0, 40.0);
  LScalarB := sse_setr_ps(5.0, 99.0, 88.0, 77.0);
  LValue := sse_cmpneq_ss(LScalarA, LScalarB);
  CheckScalarMaskWithHigh('sse_cmpneq_ss', LValue, MaskTrue32, 20.0, 30.0, 40.0);

  LScalarA := sse_setr_ps(NaN, 20.0, 30.0, 40.0);
  LScalarB := sse_setr_ps(5.0, 99.0, 88.0, 77.0);
  LValue := sse_cmpord_ss(LScalarA, LScalarB);
  CheckScalarMaskWithHigh('sse_cmpord_ss', LValue, 0, 20.0, 30.0, 40.0);

  LScalarA := sse_setr_ps(NaN, 20.0, 30.0, 40.0);
  LScalarB := sse_setr_ps(5.0, 99.0, 88.0, 77.0);
  LValue := sse_cmpunord_ss(LScalarA, LScalarB);
  CheckScalarMaskWithHigh('sse_cmpunord_ss', LValue, MaskTrue32, 20.0, 30.0, 40.0);
end;

procedure TestSqrtAndReciprocalFamily;
const
  ApproxRelTol = 2e-3;
var
  LSqrtA: TM128;
  LSqrtSsA: TM128;
  LRcpA: TM128;
  LRcpSsA: TM128;
  LRsqrtA: TM128;
  LRsqrtSsA: TM128;
  LValue: TM128;
begin
  LSqrtA := sse_setr_ps(0.25, 1.0, 81.0, 144.0);
  LSqrtSsA := sse_setr_ps(49.0, 20.0, 30.0, 40.0);
  LRcpA := sse_setr_ps(1.0, 4.0, 16.0, 64.0);
  LRcpSsA := sse_setr_ps(8.0, 20.0, 30.0, 40.0);
  LRsqrtA := sse_setr_ps(1.0, 4.0, 16.0, 64.0);
  LRsqrtSsA := sse_setr_ps(9.0, 20.0, 30.0, 40.0);

  LValue := sse_sqrt_ps(LSqrtA);
  CheckVector4('sse_sqrt_ps', LValue, 0.5, 1.0, 9.0, 12.0);

  LValue := sse_sqrt_ss(LSqrtSsA);
  CheckVector4('sse_sqrt_ss', LValue, 7.0, 20.0, 30.0, 40.0);

  LValue := sse_rcp_ps(LRcpA);
  CheckF32Relative('sse_rcp_ps[0]', 1.0, LValue.m128_f32[0], ApproxRelTol);
  CheckF32Relative('sse_rcp_ps[1]', 0.25, LValue.m128_f32[1], ApproxRelTol);
  CheckF32Relative('sse_rcp_ps[2]', 0.0625, LValue.m128_f32[2], ApproxRelTol);
  CheckF32Relative('sse_rcp_ps[3]', 0.015625, LValue.m128_f32[3], ApproxRelTol);

  LValue := sse_rcp_ss(LRcpSsA);
  CheckF32Relative('sse_rcp_ss[0]', 0.125, LValue.m128_f32[0], ApproxRelTol);
  CheckF32('sse_rcp_ss[1]', 20.0, LValue.m128_f32[1]);
  CheckF32('sse_rcp_ss[2]', 30.0, LValue.m128_f32[2]);
  CheckF32('sse_rcp_ss[3]', 40.0, LValue.m128_f32[3]);

  LValue := sse_rsqrt_ps(LRsqrtA);
  CheckF32Relative('sse_rsqrt_ps[0]', 1.0, LValue.m128_f32[0], ApproxRelTol);
  CheckF32Relative('sse_rsqrt_ps[1]', 0.5, LValue.m128_f32[1], ApproxRelTol);
  CheckF32Relative('sse_rsqrt_ps[2]', 0.25, LValue.m128_f32[2], ApproxRelTol);
  CheckF32Relative('sse_rsqrt_ps[3]', 0.125, LValue.m128_f32[3], ApproxRelTol);

  LValue := sse_rsqrt_ss(LRsqrtSsA);
  CheckF32Relative('sse_rsqrt_ss[0]', 1.0 / 3.0, LValue.m128_f32[0], ApproxRelTol);
  CheckF32('sse_rsqrt_ss[1]', 20.0, LValue.m128_f32[1]);
  CheckF32('sse_rsqrt_ss[2]', 30.0, LValue.m128_f32[2]);
  CheckF32('sse_rsqrt_ss[3]', 40.0, LValue.m128_f32[3]);
end;

procedure TestControlAndStreamFamily;
const
  StreamLeftSentinel = -123.5;
  StreamRightSentinel = 987.25;
  StreamLow64 = QWord($1122334455667788);
  StreamHigh64 = QWord($CAFEBABEDEADBEEF);
  Stream64LeftSentinel = QWord($0102030405060708);
  Stream64RightSentinel = QWord($8899AABBCCDDEEFF);
  PrefetchSentinel0 = QWord($0123456789ABCDEF);
  PrefetchSentinel1 = QWord($0FEDCBA987654321);
  PrefetchSentinel2 = QWord($13579BDF2468ACE0);
var
  LPrefetchWindow: TQWordArray3;
  LStreamWindow: PSingleArray9;
  LStream64Window: PQWordArray3;
  LStreamValue: TM128;
  LStream64Value: TM128;
  LOriginalCsr: Integer;
  LModifiedCsr: Integer;
  LReadBackCsr: Integer;
begin
  LStreamWindow := PSingleArray9(AlignedAlloc(SizeOf(TSingleArray9), 16));
  LStream64Window := PQWordArray3(AlignedAlloc(SizeOf(TQWordArray3), 16));
  if (LStreamWindow = nil) or (LStream64Window = nil) then
  begin
    WriteLn('FAIL: aligned allocation failed');
    Inc(GFail);
    if LStreamWindow <> nil then
      AlignedFree(LStreamWindow);
    if LStream64Window <> nil then
      AlignedFree(LStream64Window);
    Exit;
  end;

  try
    LPrefetchWindow[0] := PrefetchSentinel0;
    LPrefetchWindow[1] := PrefetchSentinel1;
    LPrefetchWindow[2] := PrefetchSentinel2;
    sse_prefetch(nil, 0);
    sse_prefetch(@LPrefetchWindow[1], 0);
    sse_prefetch(@LPrefetchWindow[1], 1);
    sse_prefetch(@LPrefetchWindow[1], 2);
    sse_prefetch(@LPrefetchWindow[1], 3);
    sse_sfence;
    CheckU64('sse_prefetch/sfence[0]', PrefetchSentinel0, LPrefetchWindow[0]);
    CheckU64('sse_prefetch/sfence[1]', PrefetchSentinel1, LPrefetchWindow[1]);
    CheckU64('sse_prefetch/sfence[2]', PrefetchSentinel2, LPrefetchWindow[2]);

    LStreamWindow^[0] := -10.0;
    LStreamWindow^[1] := -20.0;
    LStreamWindow^[2] := -30.0;
    LStreamWindow^[3] := StreamLeftSentinel;
    LStreamWindow^[4] := 0.0;
    LStreamWindow^[5] := 0.0;
    LStreamWindow^[6] := 0.0;
    LStreamWindow^[7] := 0.0;
    LStreamWindow^[8] := StreamRightSentinel;
    LStreamValue := sse_setr_ps(1.5, -2.5, 3.25, -4.75);
    sse_stream_ps(LStreamWindow^[4], LStreamValue);
    CheckF32('sse_stream_ps[left]', StreamLeftSentinel, LStreamWindow^[3]);
    CheckF32('sse_stream_ps[0]', 1.5, LStreamWindow^[4]);
    CheckF32('sse_stream_ps[1]', -2.5, LStreamWindow^[5]);
    CheckF32('sse_stream_ps[2]', 3.25, LStreamWindow^[6]);
    CheckF32('sse_stream_ps[3]', -4.75, LStreamWindow^[7]);
    CheckF32('sse_stream_ps[right]', StreamRightSentinel, LStreamWindow^[8]);

    LStream64Window^[0] := Stream64LeftSentinel;
    LStream64Window^[1] := 0;
    LStream64Window^[2] := Stream64RightSentinel;
    FillChar(LStream64Value, SizeOf(LStream64Value), 0);
    LStream64Value.m128i_u64[0] := StreamLow64;
    LStream64Value.m128i_u64[1] := StreamHigh64;
    sse_stream_si64(LStream64Window^[1], LStream64Value);
    CheckU64('sse_stream_si64[left]', Stream64LeftSentinel, LStream64Window^[0]);
    CheckU64('sse_stream_si64[value]', StreamLow64, LStream64Window^[1]);
    CheckU64('sse_stream_si64[right]', Stream64RightSentinel, LStream64Window^[2]);

    LOriginalCsr := sse_getcsr;
    LModifiedCsr := AlternateRoundModeCsr(LOriginalCsr);
    LReadBackCsr := LOriginalCsr;
    try
      sse_setcsr(LModifiedCsr);
      LReadBackCsr := sse_getcsr;
    finally
      sse_setcsr(LOriginalCsr);
    end;
    CheckI32('sse_setcsr roundtrip', LModifiedCsr, LReadBackCsr);
    CheckI32('sse_getcsr restore', LOriginalCsr, sse_getcsr);
  finally
    AlignedFree(LStreamWindow);
    AlignedFree(LStream64Window);
  end;
end;

begin
  WriteLn('=== SSE Raw Leaf (intrinsics.sse) Parity Test ===');
  TestNilLoadsReturnZero;
  TestLoadStoreAndSetFamily;
  TestMoveAndShuffleFamily;
  TestArithmeticAndMinMaxFamily;
  TestBitwiseFamily;
  TestConversionAndMovdFamily;
  TestCompareFamily;
  TestSqrtAndReciprocalFamily;
  TestControlAndStreamFamily;
  if GFail = 0 then
  begin
    WriteLn('SSE RAW LEAF PARITY OK: ', GPass, ' checks passed');
    WriteLn('  Load/store/set, move/shuffle, arithmetic/minmax, bitwise, conversion/movd, compare, sqrt/rcp/rsqrt, and control/stream/prefetch families match the current SSE leaf contract.');
  end
  else
  begin
    WriteLn('SSE RAW LEAF PARITY FAILED: ', GPass, ' passed, ', GFail, ' failed');
    Halt(1);
  end;
end.
