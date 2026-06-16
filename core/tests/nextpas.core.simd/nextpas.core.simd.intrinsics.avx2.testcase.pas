unit nextpas.core.simd.intrinsics.avx2.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$WARN 6018 OFF}
{$CODEPAGE UTF8}

interface

uses
  nextpas.core.exception,
  nextpas.core.text.conv,
  fpcunit, testregistry,
  nextpas.core.errors,
  nextpas.core.simd.intrinsics.base,
  nextpas.core.simd.intrinsics.avx2;

type
  TTestCase_AVX2IntrinsicsFallback = class(TTestCase)
  published
    procedure Test_SetZero_AllLanesAndViews;
    procedure Test_LoadStoreSetAndBroadcastSemantics;
    procedure Test_AddSub_LaneSemantics;
    procedure Test_Bitwise_TruthTablesAndAndNotSemantics;
    procedure Test_CompareMasks_SignedSemantics;
    procedure Test_Compare_EdgeBoundary_SignedMasks;
    procedure Test_MinMax_SignedSemantics;
    procedure Test_Multiply_LowAndHighLanes;
    procedure Test_Multiply_OverflowBoundary_WithUncheckedOracle;
    procedure Test_ShiftVar_CountClampingSemantics;
    procedure Test_ShiftVar_ExceptionalCounts_BitPatternSemantics;
    procedure Test_Gather_LoadsExpectedValues;
    procedure Test_Gather_RejectsInvalidArguments;
    procedure Test_Gather_ScaleVariantsAndNegativeIndices;
    procedure Test_Gather64AndPD_NegativeIndices;
    procedure Test_Gather64AndPD_ScaleVariants;
    procedure Test_Gather_ExceptionalArguments_AllVariants;
    procedure Test_Pack_SaturatingSemantics;
    procedure Test_Pack_LaneIsolationExtremes;
    procedure Test_Pack_ExceptionalExtremes_NoArithmeticException;
    procedure Test_Unpack_LaneSemantics;
    procedure Test_Unpack_LaneIsolationSentinels;
    procedure Test_Unpack_ExceptionalBitPatterns_Preserved;
    procedure Test_Permute_Semantics;
    procedure Test_PermuteVar_IndexMasking;
    procedure Test_Permute4x64_Imm8Combinations;
    procedure Test_Permute_ExceptionalIndexBitPatterns;
  end;

implementation

const
  INDEX_PATTERN_256: array[0..7] of LongInt = (0, 2, 4, 6, 1, 3, 5, 7);
  INDEX_PATTERN_128: array[0..3] of LongInt = (0, 2, 4, 6);

function Avx2ArithChecksOn: Boolean; inline;
begin
  Result := {$IFOPT R+}True{$ELSE}{$IFOPT Q+}True{$ELSE}False{$ENDIF}{$ENDIF};
end;

function SaturateI32ToI16(const aValue: LongInt): SmallInt; inline;
begin
  if aValue > High(SmallInt) then
    Exit(High(SmallInt));
  if aValue < Low(SmallInt) then
    Exit(Low(SmallInt));
  Result := SmallInt(aValue);
end;

function SaturateI16ToI8(const aValue: SmallInt): ShortInt; inline;
begin
  if aValue > High(ShortInt) then
    Exit(High(ShortInt));
  if aValue < Low(ShortInt) then
    Exit(Low(ShortInt));
  Result := ShortInt(aValue);
end;

function SaturateI32ToU16(const aValue: LongInt): Word; inline;
begin
  if aValue < 0 then
    Exit(0);
  if aValue > High(Word) then
    Exit(High(Word));
  Result := Word(aValue);
end;

function SaturateI16ToU8(const aValue: SmallInt): Byte; inline;
begin
  if aValue < 0 then
    Exit(0);
  if aValue > High(Byte) then
    Exit(High(Byte));
  Result := Byte(aValue);
end;

// Keep overflow/range behavior deterministic for oracle calculations,
// regardless of global build flags.
function MulLoI32Unchecked(const aLeft, aRight: LongInt): LongInt; inline;
{$push}{$Q-}{$R-}
var
  LProduct: LongInt;
begin
  LProduct := aLeft * aRight;
  Result := LProduct;
end;
{$pop}

function MulLoI16Unchecked(const aLeft, aRight: SmallInt): SmallInt; inline;
{$push}{$Q-}{$R-}
var
  LProduct: SmallInt;
begin
  LProduct := aLeft * aRight;
  Result := LProduct;
end;
{$pop}

function MulHiI16Signed(const aLeft, aRight: SmallInt): SmallInt; inline;
var
  LProduct: Int64;
begin
  LProduct := Int64(aLeft) * Int64(aRight);
  Result := SmallInt(LProduct shr 16);
end;

function MulHiU16(const aLeft, aRight: Word): Word; inline;
var
  LProduct: QWord;
begin
  LProduct := QWord(aLeft) * QWord(aRight);
  Result := Word((LProduct shr 16) and QWord($FFFF));
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_SetZero_AllLanesAndViews;
var
  LResult: TM256;
  LIndex: Integer;
begin
  LResult := avx2_setzero_si256;

  for LIndex := 0 to 3 do
    AssertEquals('setzero.u64[' + IntToStr(LIndex) + ']', QWord(0), LResult.m256i_u64[LIndex]);

  for LIndex := 0 to 7 do
    AssertEquals('setzero.i32[' + IntToStr(LIndex) + ']', 0, LResult.m256i_i32[LIndex]);

  for LIndex := 0 to 31 do
    AssertEquals('setzero.u8[' + IntToStr(LIndex) + ']', 0, LResult.m256i_u8[LIndex]);

  for LIndex := 0 to 3 do
    AssertEquals('setzero.f64[' + IntToStr(LIndex) + ']', 0.0, LResult.m256_f64[LIndex], 0.0);
end;


procedure TTestCase_AVX2IntrinsicsFallback.Test_LoadStoreSetAndBroadcastSemantics;
var
  LSource: TM256;
  LLoaded: TM256;
  LStored: TM256;
  LSet: TM256;
  LBroadcast: TM256;
  LSource128: TM128;
  LIndex: Integer;
begin
  LSource := avx2_setzero_si256;
  for LIndex := 0 to 3 do
    LSource.m256i_u64[LIndex] := QWord($1111111111111111) * QWord(LIndex + 1);

  LStored := avx2_setzero_si256;
  avx2_store_si256(LStored, LSource);
  LLoaded := avx2_load_si256(@LStored);
  for LIndex := 0 to 3 do
    AssertEquals('load/store aligned u64[' + IntToStr(LIndex) + ']',
      LSource.m256i_u64[LIndex],
      LLoaded.m256i_u64[LIndex]);

  FillChar(LStored, SizeOf(LStored), $A5);
  avx2_storeu_si256(LStored, LSource);
  LLoaded := avx2_loadu_si256(@LStored);
  for LIndex := 0 to 3 do
    AssertEquals('load/store unaligned u64[' + IntToStr(LIndex) + ']',
      LSource.m256i_u64[LIndex],
      LLoaded.m256i_u64[LIndex]);

  LSet := avx2_set1_epi32(-1234567);
  for LIndex := 0 to 7 do
    AssertEquals('set1_epi32[' + IntToStr(LIndex) + ']', -1234567, LSet.m256i_i32[LIndex]);

  LSet := avx2_set1_epi16(-1234);
  for LIndex := 0 to 15 do
    AssertEquals('set1_epi16[' + IntToStr(LIndex) + ']', -1234, LSet.m256i_i16[LIndex]);

  LSet := avx2_set1_epi8(-12);
  for LIndex := 0 to 31 do
    AssertEquals('set1_epi8[' + IntToStr(LIndex) + ']', -12, LSet.m256i_i8[LIndex]);

  LSource128 := Default(TM128);
  LSource128.m128_f32[0] := 3.25;
  LSource128.m128_f32[1] := -11.0;
  LSource128.m128_f32[2] := 5.5;
  LSource128.m128_f32[3] := 9.25;
  LBroadcast := avx2_broadcastss_ps(LSource128);
  for LIndex := 0 to 7 do
    AssertEquals('broadcastss_ps[' + IntToStr(LIndex) + ']', 3.25, LBroadcast.m256_f32[LIndex], 0.0001);

  LSource128 := Default(TM128);
  LSource128.m128d_f64[0] := -7.5;
  LSource128.m128d_f64[1] := 42.0;
  LBroadcast := avx2_broadcastsd_pd(LSource128);
  for LIndex := 0 to 3 do
    AssertEquals('broadcastsd_pd[' + IntToStr(LIndex) + ']', -7.5, LBroadcast.m256_f64[LIndex], 0.0000001);

  LSource128 := Default(TM128);
  for LIndex := 0 to 3 do
    LSource128.m128i_i32[LIndex] := 100 + LIndex;

  LBroadcast := avx2_broadcastsi128_si256(LSource128);
  for LIndex := 0 to 3 do
    AssertEquals('broadcastsi128 low[' + IntToStr(LIndex) + ']',
      LSource128.m128i_i32[LIndex],
      LBroadcast.m256i_i32[LIndex]);
  for LIndex := 0 to 3 do
    AssertEquals('broadcastsi128 high[' + IntToStr(LIndex) + ']',
      LSource128.m128i_i32[LIndex],
      LBroadcast.m256i_i32[LIndex + 4]);
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_AddSub_LaneSemantics;
var
  LA: TM256;
  LB: TM256;
  LAdd: TM256;
  LSub: TM256;
  LIndex: Integer;
begin
  LA := avx2_setzero_si256;
  LB := avx2_setzero_si256;

  for LIndex := 0 to 7 do
  begin
    LA.m256i_i32[LIndex] := (LIndex - 3) * 125000000;
    LB.m256i_i32[LIndex] := (LIndex - 4) * 75000000;
  end;

  LAdd := avx2_add_epi32(LA, LB);
  LSub := avx2_sub_epi32(LA, LB);
  for LIndex := 0 to 7 do
  begin
    AssertEquals('add_epi32[' + IntToStr(LIndex) + ']',
      LA.m256i_i32[LIndex] + LB.m256i_i32[LIndex],
      LAdd.m256i_i32[LIndex]);
    AssertEquals('sub_epi32[' + IntToStr(LIndex) + ']',
      LA.m256i_i32[LIndex] - LB.m256i_i32[LIndex],
      LSub.m256i_i32[LIndex]);
  end;

  for LIndex := 0 to 15 do
  begin
    LA.m256i_i16[LIndex] := (LIndex - 8) * 1500;
    LB.m256i_i16[LIndex] := (LIndex - 7) * 700;
  end;

  LAdd := avx2_add_epi16(LA, LB);
  LSub := avx2_sub_epi16(LA, LB);
  for LIndex := 0 to 15 do
  begin
    AssertEquals('add_epi16[' + IntToStr(LIndex) + ']',
      LA.m256i_i16[LIndex] + LB.m256i_i16[LIndex],
      LAdd.m256i_i16[LIndex]);
    AssertEquals('sub_epi16[' + IntToStr(LIndex) + ']',
      LA.m256i_i16[LIndex] - LB.m256i_i16[LIndex],
      LSub.m256i_i16[LIndex]);
  end;

  for LIndex := 0 to 31 do
  begin
    LA.m256i_i8[LIndex] := (LIndex - 16) * 3;
    LB.m256i_i8[LIndex] := LIndex - 15;
  end;

  LAdd := avx2_add_epi8(LA, LB);
  LSub := avx2_sub_epi8(LA, LB);
  for LIndex := 0 to 31 do
  begin
    AssertEquals('add_epi8[' + IntToStr(LIndex) + ']',
      LA.m256i_i8[LIndex] + LB.m256i_i8[LIndex],
      LAdd.m256i_i8[LIndex]);
    AssertEquals('sub_epi8[' + IntToStr(LIndex) + ']',
      LA.m256i_i8[LIndex] - LB.m256i_i8[LIndex],
      LSub.m256i_i8[LIndex]);
  end;
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_Bitwise_TruthTablesAndAndNotSemantics;
const
  LEFT_VALUES: array[0..7] of Cardinal = (
    $00000000, $FFFFFFFF, $AAAAAAAA, $55555555,
    $12345678, $87654321, $0F0F0F0F, $F0F0F0F0
  );
  RIGHT_VALUES: array[0..7] of Cardinal = (
    $FFFFFFFF, $00000000, $CCCCCCCC, $33333333,
    $87654321, $12345678, $FF00FF00, $00FF00FF
  );
var
  LA: TM256;
  LB: TM256;
  LAnd: TM256;
  LAndNot: TM256;
  LOr: TM256;
  LXor: TM256;
  LIndex: Integer;
begin
  LA := avx2_setzero_si256;
  LB := avx2_setzero_si256;
  for LIndex := 0 to 7 do
  begin
    LA.m256i_u32[LIndex] := LEFT_VALUES[LIndex];
    LB.m256i_u32[LIndex] := RIGHT_VALUES[LIndex];
  end;

  LAnd := avx2_and_si256(LA, LB);
  LAndNot := avx2_andnot_si256(LA, LB);
  LOr := avx2_or_si256(LA, LB);
  LXor := avx2_xor_si256(LA, LB);

  for LIndex := 0 to 7 do
  begin
    AssertEquals('and_si256[' + IntToStr(LIndex) + ']',
      LA.m256i_u32[LIndex] and LB.m256i_u32[LIndex],
      LAnd.m256i_u32[LIndex]);
    AssertEquals('andnot_si256[' + IntToStr(LIndex) + ']',
      (not LA.m256i_u32[LIndex]) and LB.m256i_u32[LIndex],
      LAndNot.m256i_u32[LIndex]);
    AssertEquals('or_si256[' + IntToStr(LIndex) + ']',
      LA.m256i_u32[LIndex] or LB.m256i_u32[LIndex],
      LOr.m256i_u32[LIndex]);
    AssertEquals('xor_si256[' + IntToStr(LIndex) + ']',
      LA.m256i_u32[LIndex] xor LB.m256i_u32[LIndex],
      LXor.m256i_u32[LIndex]);

    // (~a & b) 与 (a & b) 互斥，按位并后应还原 b。
    AssertEquals('and/or identity[' + IntToStr(LIndex) + ']',
      LB.m256i_u32[LIndex],
      LAnd.m256i_u32[LIndex] or LAndNot.m256i_u32[LIndex]);
  end;
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_CompareMasks_SignedSemantics;
var
  LA: TM256;
  LB: TM256;
  LEq: TM256;
  LGt: TM256;
  LIndex: Integer;
begin
  LA := avx2_setzero_si256;
  LB := avx2_setzero_si256;

  for LIndex := 0 to 7 do
  begin
    LA.m256i_i32[LIndex] := (LIndex - 3) * 37;
    LB.m256i_i32[LIndex] := (LIndex - 4) * 37;
  end;
  LA.m256i_i32[2] := 12345;
  LB.m256i_i32[2] := 12345;
  LA.m256i_i32[6] := -100;
  LB.m256i_i32[6] := -500;

  LEq := avx2_cmpeq_epi32(LA, LB);
  LGt := avx2_cmpgt_epi32(LA, LB);
  for LIndex := 0 to 7 do
  begin
    if LA.m256i_i32[LIndex] = LB.m256i_i32[LIndex] then
      AssertEquals('cmpeq_epi32[' + IntToStr(LIndex) + ']', Cardinal($FFFFFFFF), LEq.m256i_u32[LIndex])
    else
      AssertEquals('cmpeq_epi32[' + IntToStr(LIndex) + ']', Cardinal(0), LEq.m256i_u32[LIndex]);

    if LA.m256i_i32[LIndex] > LB.m256i_i32[LIndex] then
      AssertEquals('cmpgt_epi32[' + IntToStr(LIndex) + ']', Cardinal($FFFFFFFF), LGt.m256i_u32[LIndex])
    else
      AssertEquals('cmpgt_epi32[' + IntToStr(LIndex) + ']', Cardinal(0), LGt.m256i_u32[LIndex]);
  end;

  for LIndex := 0 to 15 do
  begin
    LA.m256i_i16[LIndex] := (LIndex - 8) * 111;
    LB.m256i_i16[LIndex] := (LIndex - 9) * 111;
  end;
  LA.m256i_i16[5] := -1234;
  LB.m256i_i16[5] := -1234;
  LA.m256i_i16[12] := 0;
  LB.m256i_i16[12] := 1;

  LEq := avx2_cmpeq_epi16(LA, LB);
  LGt := avx2_cmpgt_epi16(LA, LB);
  for LIndex := 0 to 15 do
  begin
    if LA.m256i_i16[LIndex] = LB.m256i_i16[LIndex] then
      AssertEquals('cmpeq_epi16[' + IntToStr(LIndex) + ']', Word($FFFF), LEq.m256i_u16[LIndex])
    else
      AssertEquals('cmpeq_epi16[' + IntToStr(LIndex) + ']', Word(0), LEq.m256i_u16[LIndex]);

    if LA.m256i_i16[LIndex] > LB.m256i_i16[LIndex] then
      AssertEquals('cmpgt_epi16[' + IntToStr(LIndex) + ']', Word($FFFF), LGt.m256i_u16[LIndex])
    else
      AssertEquals('cmpgt_epi16[' + IntToStr(LIndex) + ']', Word(0), LGt.m256i_u16[LIndex]);
  end;

  for LIndex := 0 to 31 do
  begin
    LA.m256i_i8[LIndex] := (LIndex - 16) * 2;
    LB.m256i_i8[LIndex] := (LIndex - 15) * 2;
  end;
  LA.m256i_i8[3] := -7;
  LB.m256i_i8[3] := -7;
  LA.m256i_i8[21] := 12;
  LB.m256i_i8[21] := -12;

  LEq := avx2_cmpeq_epi8(LA, LB);
  LGt := avx2_cmpgt_epi8(LA, LB);
  for LIndex := 0 to 31 do
  begin
    if LA.m256i_i8[LIndex] = LB.m256i_i8[LIndex] then
      AssertEquals('cmpeq_epi8[' + IntToStr(LIndex) + ']', Byte($FF), LEq.m256i_u8[LIndex])
    else
      AssertEquals('cmpeq_epi8[' + IntToStr(LIndex) + ']', Byte(0), LEq.m256i_u8[LIndex]);

    if LA.m256i_i8[LIndex] > LB.m256i_i8[LIndex] then
      AssertEquals('cmpgt_epi8[' + IntToStr(LIndex) + ']', Byte($FF), LGt.m256i_u8[LIndex])
    else
      AssertEquals('cmpgt_epi8[' + IntToStr(LIndex) + ']', Byte(0), LGt.m256i_u8[LIndex]);
  end;
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_Compare_EdgeBoundary_SignedMasks;
var
  LA: TM256;
  LB: TM256;
  LEq: TM256;
  LGt: TM256;
  LIndex: Integer;
begin
  LA := avx2_setzero_si256;
  LB := avx2_setzero_si256;

  LA.m256i_i32[0] := Low(LongInt);   LB.m256i_i32[0] := Low(LongInt);
  LA.m256i_i32[1] := Low(LongInt);   LB.m256i_i32[1] := High(LongInt);
  LA.m256i_i32[2] := -1;             LB.m256i_i32[2] := -1;
  LA.m256i_i32[3] := 0;              LB.m256i_i32[3] := -1;
  LA.m256i_i32[4] := 1;              LB.m256i_i32[4] := 0;
  LA.m256i_i32[5] := High(LongInt);  LB.m256i_i32[5] := High(LongInt);
  LA.m256i_i32[6] := High(LongInt);  LB.m256i_i32[6] := Low(LongInt);
  LA.m256i_i32[7] := 0;              LB.m256i_i32[7] := High(LongInt);

  LEq := avx2_cmpeq_epi32(LA, LB);
  LGt := avx2_cmpgt_epi32(LA, LB);
  for LIndex := 0 to 7 do
  begin
    if LA.m256i_i32[LIndex] = LB.m256i_i32[LIndex] then
      AssertEquals('edge.cmpeq_epi32[' + IntToStr(LIndex) + ']', Cardinal($FFFFFFFF), LEq.m256i_u32[LIndex])
    else
      AssertEquals('edge.cmpeq_epi32[' + IntToStr(LIndex) + ']', Cardinal(0), LEq.m256i_u32[LIndex]);

    if LA.m256i_i32[LIndex] > LB.m256i_i32[LIndex] then
      AssertEquals('edge.cmpgt_epi32[' + IntToStr(LIndex) + ']', Cardinal($FFFFFFFF), LGt.m256i_u32[LIndex])
    else
      AssertEquals('edge.cmpgt_epi32[' + IntToStr(LIndex) + ']', Cardinal(0), LGt.m256i_u32[LIndex]);
  end;

  for LIndex := 0 to 15 do
  begin
    if (LIndex and 1) = 0 then
    begin
      LA.m256i_i16[LIndex] := Low(SmallInt);
      LB.m256i_i16[LIndex] := High(SmallInt);
    end
    else
    begin
      LA.m256i_i16[LIndex] := High(SmallInt);
      LB.m256i_i16[LIndex] := Low(SmallInt);
    end;
  end;
  LA.m256i_i16[4] := -1;              LB.m256i_i16[4] := -1;
  LA.m256i_i16[5] := 0;               LB.m256i_i16[5] := -1;
  LA.m256i_i16[6] := 1;               LB.m256i_i16[6] := 0;
  LA.m256i_i16[7] := Low(SmallInt);   LB.m256i_i16[7] := Low(SmallInt);

  LEq := avx2_cmpeq_epi16(LA, LB);
  LGt := avx2_cmpgt_epi16(LA, LB);
  for LIndex := 0 to 15 do
  begin
    if LA.m256i_i16[LIndex] = LB.m256i_i16[LIndex] then
      AssertEquals('edge.cmpeq_epi16[' + IntToStr(LIndex) + ']', Word($FFFF), LEq.m256i_u16[LIndex])
    else
      AssertEquals('edge.cmpeq_epi16[' + IntToStr(LIndex) + ']', Word(0), LEq.m256i_u16[LIndex]);

    if LA.m256i_i16[LIndex] > LB.m256i_i16[LIndex] then
      AssertEquals('edge.cmpgt_epi16[' + IntToStr(LIndex) + ']', Word($FFFF), LGt.m256i_u16[LIndex])
    else
      AssertEquals('edge.cmpgt_epi16[' + IntToStr(LIndex) + ']', Word(0), LGt.m256i_u16[LIndex]);
  end;

  for LIndex := 0 to 31 do
  begin
    case LIndex mod 8 of
      0: begin LA.m256i_i8[LIndex] := Low(ShortInt);  LB.m256i_i8[LIndex] := High(ShortInt); end;
      1: begin LA.m256i_i8[LIndex] := High(ShortInt); LB.m256i_i8[LIndex] := Low(ShortInt); end;
      2: begin LA.m256i_i8[LIndex] := -1;             LB.m256i_i8[LIndex] := -1; end;
      3: begin LA.m256i_i8[LIndex] := 0;              LB.m256i_i8[LIndex] := -1; end;
      4: begin LA.m256i_i8[LIndex] := 1;              LB.m256i_i8[LIndex] := 0; end;
      5: begin LA.m256i_i8[LIndex] := 0;              LB.m256i_i8[LIndex] := High(ShortInt); end;
      6: begin LA.m256i_i8[LIndex] := Low(ShortInt);  LB.m256i_i8[LIndex] := Low(ShortInt); end;
      7: begin LA.m256i_i8[LIndex] := High(ShortInt); LB.m256i_i8[LIndex] := High(ShortInt); end;
    end;
  end;

  LEq := avx2_cmpeq_epi8(LA, LB);
  LGt := avx2_cmpgt_epi8(LA, LB);
  for LIndex := 0 to 31 do
  begin
    if LA.m256i_i8[LIndex] = LB.m256i_i8[LIndex] then
      AssertEquals('edge.cmpeq_epi8[' + IntToStr(LIndex) + ']', Byte($FF), LEq.m256i_u8[LIndex])
    else
      AssertEquals('edge.cmpeq_epi8[' + IntToStr(LIndex) + ']', Byte(0), LEq.m256i_u8[LIndex]);

    if LA.m256i_i8[LIndex] > LB.m256i_i8[LIndex] then
      AssertEquals('edge.cmpgt_epi8[' + IntToStr(LIndex) + ']', Byte($FF), LGt.m256i_u8[LIndex])
    else
      AssertEquals('edge.cmpgt_epi8[' + IntToStr(LIndex) + ']', Byte(0), LGt.m256i_u8[LIndex]);
  end;
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_MinMax_SignedSemantics;
var
  LA: TM256;
  LB: TM256;
  LMin: TM256;
  LMax: TM256;
  LIndex: Integer;
begin
  LA := avx2_setzero_si256;
  LB := avx2_setzero_si256;

  for LIndex := 0 to 7 do
  begin
    LA.m256i_i32[LIndex] := (LIndex - 4) * 25000;
    LB.m256i_i32[LIndex] := (4 - LIndex) * 17000;
  end;
  LA.m256i_i32[1] := 42;
  LB.m256i_i32[1] := 42;

  LMin := avx2_min_epi32(LA, LB);
  LMax := avx2_max_epi32(LA, LB);
  for LIndex := 0 to 7 do
  begin
    if LA.m256i_i32[LIndex] < LB.m256i_i32[LIndex] then
      AssertEquals('min_epi32[' + IntToStr(LIndex) + ']', LA.m256i_i32[LIndex], LMin.m256i_i32[LIndex])
    else
      AssertEquals('min_epi32[' + IntToStr(LIndex) + ']', LB.m256i_i32[LIndex], LMin.m256i_i32[LIndex]);

    if LA.m256i_i32[LIndex] > LB.m256i_i32[LIndex] then
      AssertEquals('max_epi32[' + IntToStr(LIndex) + ']', LA.m256i_i32[LIndex], LMax.m256i_i32[LIndex])
    else
      AssertEquals('max_epi32[' + IntToStr(LIndex) + ']', LB.m256i_i32[LIndex], LMax.m256i_i32[LIndex]);
  end;

  for LIndex := 0 to 15 do
  begin
    LA.m256i_i16[LIndex] := (LIndex - 8) * 321;
    LB.m256i_i16[LIndex] := (7 - LIndex) * 277;
  end;
  LA.m256i_i16[10] := -55;
  LB.m256i_i16[10] := -55;

  LMin := avx2_min_epi16(LA, LB);
  LMax := avx2_max_epi16(LA, LB);
  for LIndex := 0 to 15 do
  begin
    if LA.m256i_i16[LIndex] < LB.m256i_i16[LIndex] then
      AssertEquals('min_epi16[' + IntToStr(LIndex) + ']', LA.m256i_i16[LIndex], LMin.m256i_i16[LIndex])
    else
      AssertEquals('min_epi16[' + IntToStr(LIndex) + ']', LB.m256i_i16[LIndex], LMin.m256i_i16[LIndex]);

    if LA.m256i_i16[LIndex] > LB.m256i_i16[LIndex] then
      AssertEquals('max_epi16[' + IntToStr(LIndex) + ']', LA.m256i_i16[LIndex], LMax.m256i_i16[LIndex])
    else
      AssertEquals('max_epi16[' + IntToStr(LIndex) + ']', LB.m256i_i16[LIndex], LMax.m256i_i16[LIndex]);
  end;

  for LIndex := 0 to 31 do
  begin
    LA.m256i_i8[LIndex] := (LIndex - 16) * 3;
    LB.m256i_i8[LIndex] := (15 - LIndex) * 2;
  end;
  LA.m256i_i8[0] := -100;
  LB.m256i_i8[0] := -100;

  LMin := avx2_min_epi8(LA, LB);
  LMax := avx2_max_epi8(LA, LB);
  for LIndex := 0 to 31 do
  begin
    if LA.m256i_i8[LIndex] < LB.m256i_i8[LIndex] then
      AssertEquals('min_epi8[' + IntToStr(LIndex) + ']', LA.m256i_i8[LIndex], LMin.m256i_i8[LIndex])
    else
      AssertEquals('min_epi8[' + IntToStr(LIndex) + ']', LB.m256i_i8[LIndex], LMin.m256i_i8[LIndex]);

    if LA.m256i_i8[LIndex] > LB.m256i_i8[LIndex] then
      AssertEquals('max_epi8[' + IntToStr(LIndex) + ']', LA.m256i_i8[LIndex], LMax.m256i_i8[LIndex])
    else
      AssertEquals('max_epi8[' + IntToStr(LIndex) + ']', LB.m256i_i8[LIndex], LMax.m256i_i8[LIndex]);
  end;
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_Multiply_LowAndHighLanes;
var
  LA: TM256;
  LB: TM256;
  LResult: TM256;
  LIndex: Integer;
  LProductI64: Int64;
  LProductU64: QWord;
begin
  LA := avx2_setzero_si256;
  LB := avx2_setzero_si256;

  for LIndex := 0 to 7 do
  begin
    LA.m256i_i32[LIndex] := (LIndex - 3) * 20000;
    LB.m256i_i32[LIndex] := (LIndex + 1) * 1000;
  end;
  LResult := avx2_mullo_epi32(LA, LB);
  for LIndex := 0 to 7 do
    AssertEquals('mullo_epi32[' + IntToStr(LIndex) + ']',
      LA.m256i_i32[LIndex] * LB.m256i_i32[LIndex],
      LResult.m256i_i32[LIndex]);

  for LIndex := 0 to 15 do
  begin
    LA.m256i_i16[LIndex] := (LIndex - 8) * 20;
    LB.m256i_i16[LIndex] := (LIndex + 1) * 10;
  end;
  LResult := avx2_mullo_epi16(LA, LB);
  for LIndex := 0 to 15 do
    AssertEquals('mullo_epi16[' + IntToStr(LIndex) + ']',
      LA.m256i_i16[LIndex] * LB.m256i_i16[LIndex],
      LResult.m256i_i16[LIndex]);

  LA.m256i_i16[0] := -30000;  LB.m256i_i16[0] := 2;
  LA.m256i_i16[1] := 30000;   LB.m256i_i16[1] := 2;
  LA.m256i_i16[2] := -20000;  LB.m256i_i16[2] := -3;
  LA.m256i_i16[3] := 12345;   LB.m256i_i16[3] := -7;
  LA.m256i_i16[4] := -12345;  LB.m256i_i16[4] := -7;
  LA.m256i_i16[5] := 32767;   LB.m256i_i16[5] := 32767;
  LA.m256i_i16[6] := -32768;  LB.m256i_i16[6] := 32767;
  LA.m256i_i16[7] := -32768;  LB.m256i_i16[7] := -32768;

  for LIndex := 8 to 15 do
  begin
    LA.m256i_i16[LIndex] := (LIndex - 11) * 2500;
    LB.m256i_i16[LIndex] := (15 - LIndex) * 1700;
  end;

  LResult := avx2_mulhi_epi16(LA, LB);
  for LIndex := 0 to 15 do
  begin
    LProductI64 := Int64(LA.m256i_i16[LIndex]) * Int64(LB.m256i_i16[LIndex]);
    AssertEquals('mulhi_epi16[' + IntToStr(LIndex) + ']',
      SmallInt(LProductI64 shr 16),
      LResult.m256i_i16[LIndex]);
  end;

  LA.m256i_u16[0] := 65535;  LB.m256i_u16[0] := 65535;
  LA.m256i_u16[1] := 60000;  LB.m256i_u16[1] := 50000;
  LA.m256i_u16[2] := 40000;  LB.m256i_u16[2] := 40000;
  LA.m256i_u16[3] := 1;      LB.m256i_u16[3] := 65535;
  for LIndex := 4 to 15 do
  begin
    LA.m256i_u16[LIndex] := Word(1000 + (LIndex * 137));
    LB.m256i_u16[LIndex] := Word(2000 + (LIndex * 73));
  end;

  LResult := avx2_mulhi_epu16(LA, LB);
  for LIndex := 0 to 15 do
  begin
    LProductU64 := QWord(LA.m256i_u16[LIndex]) * QWord(LB.m256i_u16[LIndex]);
    AssertEquals('mulhi_epu16[' + IntToStr(LIndex) + ']',
      Word((LProductU64 shr 16) and QWord($FFFF)),
      LResult.m256i_u16[LIndex]);
  end;
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_Multiply_OverflowBoundary_WithUncheckedOracle;
var
  LA: TM256;
  LB: TM256;
  LResult: TM256;
  LIndex: Integer;
  LRaised: Boolean;
  LExceptionClass: string;
begin
  LA := avx2_setzero_si256;
  LB := avx2_setzero_si256;

  LA.m256i_i32[0] := High(LongInt);   LB.m256i_i32[0] := 2;
  LA.m256i_i32[1] := Low(LongInt);    LB.m256i_i32[1] := 2;
  LA.m256i_i32[2] := 65536;           LB.m256i_i32[2] := 65536;
  LA.m256i_i32[3] := -65536;          LB.m256i_i32[3] := 65536;
  LA.m256i_i32[4] := 46341;           LB.m256i_i32[4] := 46341;
  LA.m256i_i32[5] := -46341;          LB.m256i_i32[5] := 46341;
  LA.m256i_i32[6] := 123456789;       LB.m256i_i32[6] := 17;
  LA.m256i_i32[7] := -123456789;      LB.m256i_i32[7] := 17;

      if Avx2ArithChecksOn then
  begin
    LRaised := False;
    LExceptionClass := '';
    try
      LResult := avx2_mullo_epi32(LA, LB);
    except
      on E: Exception do
      begin
        LRaised := True;
        LExceptionClass := E.ClassName;
      end;
    end;
    AssertTrue('overflow.mullo_epi32 should raise arithmetic-check exception in checked builds (got=' + LExceptionClass + ')',
      LRaised);
  end
  else
  begin
    LResult := avx2_mullo_epi32(LA, LB);
    for LIndex := 0 to 7 do
      AssertEquals('overflow.mullo_epi32[' + IntToStr(LIndex) + ']',
        MulLoI32Unchecked(LA.m256i_i32[LIndex], LB.m256i_i32[LIndex]),
        LResult.m256i_i32[LIndex]);
  end;

  LA.m256i_i16[0] := High(SmallInt);  LB.m256i_i16[0] := High(SmallInt);
  LA.m256i_i16[1] := Low(SmallInt);   LB.m256i_i16[1] := 2;
  LA.m256i_i16[2] := Low(SmallInt);   LB.m256i_i16[2] := Low(SmallInt);
  LA.m256i_i16[3] := 30000;           LB.m256i_i16[3] := 3;
  LA.m256i_i16[4] := -30000;          LB.m256i_i16[4] := 3;
  LA.m256i_i16[5] := 32760;           LB.m256i_i16[5] := -7;
  LA.m256i_i16[6] := -32760;          LB.m256i_i16[6] := -7;
  LA.m256i_i16[7] := 12345;           LB.m256i_i16[7] := 23456;
  LA.m256i_i16[8] := -12345;          LB.m256i_i16[8] := 23456;
  LA.m256i_i16[9] := 1;               LB.m256i_i16[9] := Low(SmallInt);
  LA.m256i_i16[10] := -1;             LB.m256i_i16[10] := Low(SmallInt);
  LA.m256i_i16[11] := 22222;          LB.m256i_i16[11] := 22222;
  LA.m256i_i16[12] := -22222;         LB.m256i_i16[12] := 22222;
  LA.m256i_i16[13] := 1024;           LB.m256i_i16[13] := 4096;
  LA.m256i_i16[14] := -1024;          LB.m256i_i16[14] := 4096;
  LA.m256i_i16[15] := High(SmallInt); LB.m256i_i16[15] := Low(SmallInt);

  if Avx2ArithChecksOn then
  begin
    LRaised := False;
    LExceptionClass := '';
    try
      LResult := avx2_mullo_epi16(LA, LB);
    except
      on E: Exception do
      begin
        LRaised := True;
        LExceptionClass := E.ClassName;
      end;
    end;
    AssertTrue('overflow.mullo_epi16 should raise arithmetic-check exception in checked builds (got=' + LExceptionClass + ')',
      LRaised);
  end
  else
  begin
    LResult := avx2_mullo_epi16(LA, LB);
    for LIndex := 0 to 15 do
      AssertEquals('overflow.mullo_epi16[' + IntToStr(LIndex) + ']',
        MulLoI16Unchecked(LA.m256i_i16[LIndex], LB.m256i_i16[LIndex]),
        LResult.m256i_i16[LIndex]);
  end;

  LResult := avx2_mulhi_epi16(LA, LB);
  for LIndex := 0 to 15 do
    AssertEquals('overflow.mulhi_epi16[' + IntToStr(LIndex) + ']',
      MulHiI16Signed(LA.m256i_i16[LIndex], LB.m256i_i16[LIndex]),
      LResult.m256i_i16[LIndex]);

  for LIndex := 0 to 15 do
  begin
    LA.m256i_u16[LIndex] := Word($FFFF - (LIndex * $1111));
    LB.m256i_u16[LIndex] := Word($8001 + (LIndex * $0111));
  end;
  LA.m256i_u16[4] := 65535; LB.m256i_u16[4] := 65535;
  LA.m256i_u16[5] := 65535; LB.m256i_u16[5] := 2;
  LA.m256i_u16[6] := 32768; LB.m256i_u16[6] := 32768;
  LA.m256i_u16[7] := 65534; LB.m256i_u16[7] := 65533;

  LResult := avx2_mulhi_epu16(LA, LB);
  for LIndex := 0 to 15 do
    AssertEquals('overflow.mulhi_epu16[' + IntToStr(LIndex) + ']',
      MulHiU16(LA.m256i_u16[LIndex], LB.m256i_u16[LIndex]),
      LResult.m256i_u16[LIndex]);
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_ShiftVar_CountClampingSemantics;
const
  HIGH_BIT_U64 = QWord(1) shl 63;
  NEXT_HIGH_BIT_U64 = QWord(1) shl 62;
var
  LA: TM256;
  LCount: TM256;
  LResult: TM256;
begin
  LA := avx2_setzero_si256;
  LCount := avx2_setzero_si256;

  LA.m256i_u32[0] := 1;
  LA.m256i_u32[1] := $80000000;
  LA.m256i_u32[2] := 3;
  LA.m256i_u32[3] := $7FFFFFFF;
  LA.m256i_u32[4] := 15;
  LA.m256i_u32[5] := 16;
  LA.m256i_u32[6] := 17;
  LA.m256i_u32[7] := 18;

  LCount.m256i_i32[0] := 0;
  LCount.m256i_i32[1] := 1;
  LCount.m256i_i32[2] := 2;
  LCount.m256i_i32[3] := 31;
  LCount.m256i_i32[4] := 32;
  LCount.m256i_i32[5] := 33;
  LCount.m256i_i32[6] := -1;
  LCount.m256i_i32[7] := 63;

  LResult := avx2_sllv_epi32(LA, LCount);
  AssertTrue('sllv_epi32[0]', LResult.m256i_u32[0] = 1);
  AssertTrue('sllv_epi32[1]', LResult.m256i_u32[1] = 0);
  AssertTrue('sllv_epi32[2]', LResult.m256i_u32[2] = 12);
  AssertTrue('sllv_epi32[3]', LResult.m256i_u32[3] = $80000000);
  AssertTrue('sllv_epi32[4]', LResult.m256i_u32[4] = 0);
  AssertTrue('sllv_epi32[5]', LResult.m256i_u32[5] = 0);
  AssertTrue('sllv_epi32[6]', LResult.m256i_u32[6] = 0);
  AssertTrue('sllv_epi32[7]', LResult.m256i_u32[7] = 0);

  LResult := avx2_srlv_epi32(LA, LCount);
  AssertTrue('srlv_epi32[0]', LResult.m256i_u32[0] = 1);
  AssertTrue('srlv_epi32[1]', LResult.m256i_u32[1] = $40000000);
  AssertTrue('srlv_epi32[2]', LResult.m256i_u32[2] = 0);
  AssertTrue('srlv_epi32[3]', LResult.m256i_u32[3] = 0);
  AssertTrue('srlv_epi32[4]', LResult.m256i_u32[4] = 0);
  AssertTrue('srlv_epi32[5]', LResult.m256i_u32[5] = 0);
  AssertTrue('srlv_epi32[6]', LResult.m256i_u32[6] = 0);
  AssertTrue('srlv_epi32[7]', LResult.m256i_u32[7] = 0);

  LA.m256i_i32[0] := 1;
  LA.m256i_i32[1] := -1;
  LA.m256i_i32[2] := Low(LongInt);
  LA.m256i_i32[3] := High(LongInt);
  LA.m256i_i32[4] := -8;
  LA.m256i_i32[5] := 8;
  LA.m256i_i32[6] := -123456789;
  LA.m256i_i32[7] := 123456789;

  LResult := avx2_srav_epi32(LA, LCount);
  AssertEquals('srav_epi32[0]', 1, LResult.m256i_i32[0]);
  AssertEquals('srav_epi32[1]', -1, LResult.m256i_i32[1]);
  AssertEquals('srav_epi32[2]', -536870912, LResult.m256i_i32[2]);
  AssertEquals('srav_epi32[3]', 0, LResult.m256i_i32[3]);
  AssertEquals('srav_epi32[4]', -1, LResult.m256i_i32[4]);
  AssertEquals('srav_epi32[5]', 0, LResult.m256i_i32[5]);
  AssertEquals('srav_epi32[6]', -1, LResult.m256i_i32[6]);
  AssertEquals('srav_epi32[7]', 0, LResult.m256i_i32[7]);

  LA.m256i_u64[0] := 1;
  LA.m256i_u64[1] := HIGH_BIT_U64;
  LA.m256i_u64[2] := 3;
  LA.m256i_u64[3] := $7FFFFFFFFFFFFFFF;

  LCount.m256i_u64[0] := 0;
  LCount.m256i_u64[1] := 1;
  LCount.m256i_u64[2] := 63;
  LCount.m256i_u64[3] := 64;

  LResult := avx2_sllv_epi64(LA, LCount);
  AssertTrue('sllv_epi64[0]', LResult.m256i_u64[0] = 1);
  AssertTrue('sllv_epi64[1]', LResult.m256i_u64[1] = 0);
  AssertTrue('sllv_epi64[2]', LResult.m256i_u64[2] = HIGH_BIT_U64);
  AssertTrue('sllv_epi64[3]', LResult.m256i_u64[3] = 0);

  LResult := avx2_srlv_epi64(LA, LCount);
  AssertTrue('srlv_epi64[0]', LResult.m256i_u64[0] = 1);
  AssertTrue('srlv_epi64[1]', LResult.m256i_u64[1] = NEXT_HIGH_BIT_U64);
  AssertTrue('srlv_epi64[2]', LResult.m256i_u64[2] = 0);
  AssertTrue('srlv_epi64[3]', LResult.m256i_u64[3] = 0);
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_ShiftVar_ExceptionalCounts_BitPatternSemantics;
var
  LA: TM256;
  LCount: TM256;
  LResult: TM256;
  LExpectedSll: array[0..7] of DWord;
  LExpectedSrl: array[0..7] of DWord;
  LExpectedSra: array[0..7] of LongInt;
  LSourceI32: array[0..7] of LongInt;
  LSourceU32: array[0..7] of DWord;
  LIndex: Integer;
  LShift: Cardinal;
begin
  LA := avx2_setzero_si256;
  LCount := avx2_setzero_si256;

  LSourceU32[0] := 1;
  LSourceU32[1] := $80000000;
  LSourceU32[2] := 3;
  LSourceU32[3] := $7FFFFFFF;
  LSourceU32[4] := 15;
  LSourceU32[5] := 16;
  LSourceU32[6] := $FFFFFFFF;
  LSourceU32[7] := $12345678;

  LSourceI32[0] := 1;
  LSourceI32[1] := -1;
  LSourceI32[2] := Low(LongInt);
  LSourceI32[3] := High(LongInt);
  LSourceI32[4] := -123456789;
  LSourceI32[5] := 123456789;
  LSourceI32[6] := -42;
  LSourceI32[7] := 42;

  LCount.m256i_u32[0] := 0;
  LCount.m256i_u32[1] := 31;
  LCount.m256i_u32[2] := 32;
  LCount.m256i_u32[3] := 33;
  LCount.m256i_u32[4] := $80000000;
  LCount.m256i_u32[5] := $FFFFFFFF;
  LCount.m256i_u32[6] := 64;
  LCount.m256i_u32[7] := 65;

  for LIndex := 0 to 7 do
  begin
    LA.m256i_u32[LIndex] := LSourceU32[LIndex];
    if LCount.m256i_u32[LIndex] >= 32 then
    begin
      LExpectedSll[LIndex] := 0;
      LExpectedSrl[LIndex] := 0;
    end
    else
    begin
      LExpectedSll[LIndex] := LSourceU32[LIndex] shl LCount.m256i_u32[LIndex];
      LExpectedSrl[LIndex] := LSourceU32[LIndex] shr LCount.m256i_u32[LIndex];
    end;
  end;

  LResult := avx2_sllv_epi32(LA, LCount);
  for LIndex := 0 to 7 do
    AssertEquals('sllv exceptional[' + IntToStr(LIndex) + ']',
      QWord(LExpectedSll[LIndex]),
      QWord(LResult.m256i_u32[LIndex]));

  LResult := avx2_srlv_epi32(LA, LCount);
  for LIndex := 0 to 7 do
    AssertEquals('srlv exceptional[' + IntToStr(LIndex) + ']',
      QWord(LExpectedSrl[LIndex]),
      QWord(LResult.m256i_u32[LIndex]));

  for LIndex := 0 to 7 do
  begin
    LA.m256i_i32[LIndex] := LSourceI32[LIndex];
    LShift := LCount.m256i_u32[LIndex];
    if LShift >= 32 then
      LShift := 31;

    if LShift = 0 then
      LExpectedSra[LIndex] := LSourceI32[LIndex]
    else if LSourceI32[LIndex] >= 0 then
      LExpectedSra[LIndex] := LSourceI32[LIndex] shr LShift
    else
      LExpectedSra[LIndex] := (LSourceI32[LIndex] shr LShift) or ((-1) shl (32 - LShift));
  end;

  LResult := avx2_srav_epi32(LA, LCount);
  for LIndex := 0 to 7 do
    AssertEquals('srav exceptional[' + IntToStr(LIndex) + ']',
      LExpectedSra[LIndex],
      LResult.m256i_i32[LIndex]);
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_Gather_LoadsExpectedValues;
var
  LDataI32: array[0..15] of LongInt;
  LDataI64: array[0..15] of Int64;
  LDataF32: array[0..15] of Single;
  LDataF64: array[0..15] of Double;
  LIndices256: TM256;
  LIndices128: TM128;
  LResult: TM256;
  LIndex: Integer;
begin
  for LIndex := 0 to 15 do
  begin
    LDataI32[LIndex] := (LIndex + 1) * 10;
    LDataI64[LIndex] := (LIndex + 1) * 1000;
    LDataF32[LIndex] := (LIndex + 1) * 1.5;
    LDataF64[LIndex] := (LIndex + 1) * 2.5;
  end;

  LIndices256 := avx2_setzero_si256;
  LIndices128 := Default(TM128);
  for LIndex := 0 to 7 do
    LIndices256.m256i_i32[LIndex] := INDEX_PATTERN_256[LIndex];
  for LIndex := 0 to 3 do
    LIndices128.m128i_i32[LIndex] := INDEX_PATTERN_128[LIndex];

  LResult := avx2_gather_epi32(@LDataI32[0], LIndices256, SizeOf(LongInt));
  for LIndex := 0 to 7 do
    AssertEquals('gather_epi32[' + IntToStr(LIndex) + ']', LDataI32[INDEX_PATTERN_256[LIndex]], LResult.m256i_i32[LIndex]);

  LResult := avx2_gather_epi64(@LDataI64[0], LIndices128, SizeOf(Int64));
  for LIndex := 0 to 3 do
    AssertEquals('gather_epi64[' + IntToStr(LIndex) + ']', LDataI64[INDEX_PATTERN_128[LIndex]], LResult.m256i_i64[LIndex]);

  LResult := avx2_gather_ps(@LDataF32[0], LIndices256, SizeOf(Single));
  for LIndex := 0 to 7 do
    AssertEquals('gather_ps[' + IntToStr(LIndex) + ']', LDataF32[INDEX_PATTERN_256[LIndex]], LResult.m256_f32[LIndex], 0.0001);

  LResult := avx2_gather_pd(@LDataF64[0], LIndices128, SizeOf(Double));
  for LIndex := 0 to 3 do
    AssertEquals('gather_pd[' + IntToStr(LIndex) + ']', LDataF64[INDEX_PATTERN_128[LIndex]], LResult.m256_f64[LIndex], 0.0000001);
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_Gather_RejectsInvalidArguments;
var
  LData: array[0..7] of LongInt;
  LIndices: TM256;
  LRaised: Boolean;
  LIndex: Integer;
begin
  for LIndex := 0 to 7 do
    LData[LIndex] := LIndex;

  LIndices := avx2_setzero_si256;

  LRaised := False;
  try
    avx2_gather_epi32(nil, LIndices, SizeOf(LongInt));
  except
    on ENullReferenceError do
      LRaised := True;
  end;
  AssertTrue('nil base should raise ENullReferenceError', LRaised);

  LRaised := False;
  try
    avx2_gather_epi32(@LData[0], LIndices, 3);
  except
    on EArgumentError do
      LRaised := True;
  end;
  AssertTrue('invalid scale should raise EArgumentError', LRaised);
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_Gather_ScaleVariantsAndNegativeIndices;
const
  SCALE_COUNT = 4;
  SCALE_VALUES: array[0..SCALE_COUNT - 1] of Integer = (1, 2, 4, 8);
  TARGET_OFFSETS: array[0..7] of LongInt = (0, 8, 16, 24, 32, 40, 48, 56);
var
  LDataI32: array[0..31] of LongInt;
  LIndices: TM256;
  LResult: TM256;
  LScaleIndex: Integer;
  LScale: Integer;
  LIndex: Integer;
  LCenter: PLongInt;
begin
  for LIndex := 0 to High(LDataI32) do
    LDataI32[LIndex] := (LIndex * 17) + 3;

  LIndices := avx2_setzero_si256;

  for LScaleIndex := 0 to SCALE_COUNT - 1 do
  begin
    LScale := SCALE_VALUES[LScaleIndex];
    for LIndex := 0 to 7 do
      LIndices.m256i_i32[LIndex] := TARGET_OFFSETS[LIndex] div LScale;

    LResult := avx2_gather_epi32(@LDataI32[0], LIndices, LScale);
    for LIndex := 0 to 7 do
      AssertEquals('gather scale=' + IntToStr(LScale) + ' idx=' + IntToStr(LIndex),
        LDataI32[TARGET_OFFSETS[LIndex] div SizeOf(LongInt)],
        LResult.m256i_i32[LIndex]);
  end;

  LCenter := @LDataI32[12];
  LIndices.m256i_i32[0] := -4;
  LIndices.m256i_i32[1] := -3;
  LIndices.m256i_i32[2] := -2;
  LIndices.m256i_i32[3] := -1;
  LIndices.m256i_i32[4] := 0;
  LIndices.m256i_i32[5] := 1;
  LIndices.m256i_i32[6] := 2;
  LIndices.m256i_i32[7] := 3;

  LResult := avx2_gather_epi32(LCenter, LIndices, SizeOf(LongInt));
  for LIndex := 0 to 7 do
    AssertEquals('gather negative idx=' + IntToStr(LIndex),
      LDataI32[8 + LIndex],
      LResult.m256i_i32[LIndex]);
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_Gather64AndPD_NegativeIndices;
var
  LDataI64: array[0..31] of Int64;
  LDataF64: array[0..31] of Double;
  LIndices: TM128;
  LResult: TM256;
  LCenterI64: PInt64;
  LCenterF64: PDouble;
  LIndex: Integer;
  LRaised: Boolean;
begin
  for LIndex := 0 to High(LDataI64) do
  begin
    LDataI64[LIndex] := (LIndex * 1000) + 7;
    LDataF64[LIndex] := (LIndex * 2.25) + 0.125;
  end;

  LIndices := Default(TM128);
  LIndices.m128i_i32[0] := -3;
  LIndices.m128i_i32[1] := -1;
  LIndices.m128i_i32[2] := 0;
  LIndices.m128i_i32[3] := 2;

  LCenterI64 := @LDataI64[12];
  LResult := avx2_gather_epi64(LCenterI64, LIndices, SizeOf(Int64));
  AssertEquals('gather_epi64 negative[0]', LDataI64[9], LResult.m256i_i64[0]);
  AssertEquals('gather_epi64 negative[1]', LDataI64[11], LResult.m256i_i64[1]);
  AssertEquals('gather_epi64 negative[2]', LDataI64[12], LResult.m256i_i64[2]);
  AssertEquals('gather_epi64 negative[3]', LDataI64[14], LResult.m256i_i64[3]);

  LCenterF64 := @LDataF64[12];
  LResult := avx2_gather_pd(LCenterF64, LIndices, SizeOf(Double));
  AssertEquals('gather_pd negative[0]', LDataF64[9], LResult.m256_f64[0], 0.0000001);
  AssertEquals('gather_pd negative[1]', LDataF64[11], LResult.m256_f64[1], 0.0000001);
  AssertEquals('gather_pd negative[2]', LDataF64[12], LResult.m256_f64[2], 0.0000001);
  AssertEquals('gather_pd negative[3]', LDataF64[14], LResult.m256_f64[3], 0.0000001);

  LRaised := False;
  try
    avx2_gather_epi64(nil, LIndices, SizeOf(Int64));
  except
    on ENullReferenceError do
      LRaised := True;
  end;
  AssertTrue('gather_epi64 nil base should raise ENullReferenceError', LRaised);

  LRaised := False;
  try
    avx2_gather_pd(LCenterF64, LIndices, 6);
  except
    on EArgumentError do
      LRaised := True;
  end;
  AssertTrue('gather_pd invalid scale should raise EArgumentError', LRaised);
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_Gather64AndPD_ScaleVariants;
const
  SCALE_COUNT = 4;
  SCALE_VALUES: array[0..SCALE_COUNT - 1] of Integer = (1, 2, 4, 8);
  TARGET_OFFSETS: array[0..3] of LongInt = (0, 8, 24, 40);
var
  LDataI64: array[0..127] of Byte;
  LDataF64: array[0..127] of Byte;
  LExpectedI64: array[0..3] of Int64;
  LExpectedF64: array[0..3] of Double;
  LIndices: TM128;
  LResult: TM256;
  LScaleIndex: Integer;
  LScale: Integer;
  LIndex: Integer;
  LBaseI64: PByte;
  LBaseF64: PByte;
begin
  for LIndex := 0 to High(LDataI64) do
  begin
    LDataI64[LIndex] := 0;
    LDataF64[LIndex] := 0;
  end;

  LBaseI64 := @LDataI64[0];
  LBaseF64 := @LDataF64[0];

  for LIndex := 0 to 3 do
  begin
    LExpectedI64[LIndex] := (LIndex + 1) * 1111;
    LExpectedF64[LIndex] := (LIndex + 1) * 3.125;

    PInt64(LBaseI64 + TARGET_OFFSETS[LIndex])^ := LExpectedI64[LIndex];
    PDouble(LBaseF64 + TARGET_OFFSETS[LIndex])^ := LExpectedF64[LIndex];
  end;

  for LScaleIndex := 0 to SCALE_COUNT - 1 do
  begin
    LScale := SCALE_VALUES[LScaleIndex];
    LIndices := Default(TM128);
    for LIndex := 0 to 3 do
      LIndices.m128i_i32[LIndex] := TARGET_OFFSETS[LIndex] div LScale;

    LResult := avx2_gather_epi64(LBaseI64, LIndices, LScale);
    for LIndex := 0 to 3 do
      AssertEquals('gather_epi64 scale=' + IntToStr(LScale) + ' idx=' + IntToStr(LIndex),
        LExpectedI64[LIndex],
        LResult.m256i_i64[LIndex]);

    LResult := avx2_gather_pd(LBaseF64, LIndices, LScale);
    for LIndex := 0 to 3 do
      AssertEquals('gather_pd scale=' + IntToStr(LScale) + ' idx=' + IntToStr(LIndex),
        LExpectedF64[LIndex],
        LResult.m256_f64[LIndex],
        0.0000001);
  end;
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_Gather_ExceptionalArguments_AllVariants;
var
  LDataI32: array[0..7] of LongInt;
  LDataI64: array[0..7] of Int64;
  LDataF32: array[0..7] of Single;
  LDataF64: array[0..7] of Double;
  LIndices256: TM256;
  LIndices128: TM128;
  LRaised: Boolean;
  LIndex: Integer;
begin
  for LIndex := 0 to 7 do
  begin
    LDataI32[LIndex] := LIndex + 10;
    LDataI64[LIndex] := (LIndex + 1) * 100;
    LDataF32[LIndex] := (LIndex + 1) * 0.75;
    LDataF64[LIndex] := (LIndex + 1) * 1.25;
  end;

  LIndices256 := avx2_setzero_si256;
  LIndices128 := Default(TM128);

  LRaised := False;
  try
    avx2_gather_epi32(nil, LIndices256, SizeOf(LongInt));
  except
    on ENullReferenceError do
      LRaised := True;
  end;
  AssertTrue('gather_epi32 nil base should raise ENullReferenceError', LRaised);

  LRaised := False;
  try
    avx2_gather_epi64(nil, LIndices128, SizeOf(Int64));
  except
    on ENullReferenceError do
      LRaised := True;
  end;
  AssertTrue('gather_epi64 nil base should raise ENullReferenceError', LRaised);

  LRaised := False;
  try
    avx2_gather_ps(nil, LIndices256, SizeOf(Single));
  except
    on ENullReferenceError do
      LRaised := True;
  end;
  AssertTrue('gather_ps nil base should raise ENullReferenceError', LRaised);

  LRaised := False;
  try
    avx2_gather_pd(nil, LIndices128, SizeOf(Double));
  except
    on ENullReferenceError do
      LRaised := True;
  end;
  AssertTrue('gather_pd nil base should raise ENullReferenceError', LRaised);

  LRaised := False;
  try
    avx2_gather_epi32(@LDataI32[0], LIndices256, 0);
  except
    on EArgumentError do
      LRaised := True;
  end;
  AssertTrue('gather_epi32 invalid scale should raise EArgumentError', LRaised);

  LRaised := False;
  try
    avx2_gather_epi64(@LDataI64[0], LIndices128, 3);
  except
    on EArgumentError do
      LRaised := True;
  end;
  AssertTrue('gather_epi64 invalid scale should raise EArgumentError', LRaised);

  LRaised := False;
  try
    avx2_gather_ps(@LDataF32[0], LIndices256, 5);
  except
    on EArgumentError do
      LRaised := True;
  end;
  AssertTrue('gather_ps invalid scale should raise EArgumentError', LRaised);

  LRaised := False;
  try
    avx2_gather_pd(@LDataF64[0], LIndices128, 16);
  except
    on EArgumentError do
      LRaised := True;
  end;
  AssertTrue('gather_pd invalid scale should raise EArgumentError', LRaised);
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_Pack_SaturatingSemantics;
var
  LA: TM256;
  LB: TM256;
  LResult: TM256;
  LExpectedI16: array[0..15] of SmallInt;
  LExpectedI8: array[0..31] of ShortInt;
  LExpectedU16: array[0..15] of Word;
  LExpectedU8: array[0..31] of Byte;
  LLane: Integer;
  LSrcOffset: Integer;
  LDstOffset: Integer;
  LInner: Integer;
  LIndex: Integer;
begin
  LA := avx2_setzero_si256;
  LB := avx2_setzero_si256;

  LA.m256i_i32[0] := -40000;
  LA.m256i_i32[1] := -32768;
  LA.m256i_i32[2] := -1;
  LA.m256i_i32[3] := 0;
  LA.m256i_i32[4] := 1;
  LA.m256i_i32[5] := 32767;
  LA.m256i_i32[6] := 32768;
  LA.m256i_i32[7] := 60000;

  LB.m256i_i32[0] := -50000;
  LB.m256i_i32[1] := -123;
  LB.m256i_i32[2] := 123;
  LB.m256i_i32[3] := 40000;
  LB.m256i_i32[4] := -32000;
  LB.m256i_i32[5] := -2;
  LB.m256i_i32[6] := 2;
  LB.m256i_i32[7] := 33000;

  for LLane := 0 to 1 do
  begin
    LSrcOffset := LLane * 4;
    LDstOffset := LLane * 8;

    for LInner := 0 to 3 do
      LExpectedI16[LDstOffset + LInner] := SaturateI32ToI16(LA.m256i_i32[LSrcOffset + LInner]);
    for LInner := 0 to 3 do
      LExpectedI16[LDstOffset + 4 + LInner] := SaturateI32ToI16(LB.m256i_i32[LSrcOffset + LInner]);

    for LInner := 0 to 3 do
      LExpectedU16[LDstOffset + LInner] := SaturateI32ToU16(LA.m256i_i32[LSrcOffset + LInner]);
    for LInner := 0 to 3 do
      LExpectedU16[LDstOffset + 4 + LInner] := SaturateI32ToU16(LB.m256i_i32[LSrcOffset + LInner]);
  end;

  LResult := avx2_packs_epi32(LA, LB);
  for LIndex := 0 to 15 do
    AssertEquals('packs_epi32[' + IntToStr(LIndex) + ']', LExpectedI16[LIndex], LResult.m256i_i16[LIndex]);

  LResult := avx2_packus_epi32(LA, LB);
  for LIndex := 0 to 15 do
    AssertEquals('packus_epi32[' + IntToStr(LIndex) + ']', LExpectedU16[LIndex], LResult.m256i_u16[LIndex]);

  for LIndex := 0 to 15 do
  begin
    LA.m256i_i16[LIndex] := (LIndex * 40) - 300;
    LB.m256i_i16[LIndex] := 500 - (LIndex * 35);
  end;

  for LLane := 0 to 1 do
  begin
    LSrcOffset := LLane * 8;
    LDstOffset := LLane * 16;

    for LInner := 0 to 7 do
      LExpectedI8[LDstOffset + LInner] := SaturateI16ToI8(LA.m256i_i16[LSrcOffset + LInner]);
    for LInner := 0 to 7 do
      LExpectedI8[LDstOffset + 8 + LInner] := SaturateI16ToI8(LB.m256i_i16[LSrcOffset + LInner]);

    for LInner := 0 to 7 do
      LExpectedU8[LDstOffset + LInner] := SaturateI16ToU8(LA.m256i_i16[LSrcOffset + LInner]);
    for LInner := 0 to 7 do
      LExpectedU8[LDstOffset + 8 + LInner] := SaturateI16ToU8(LB.m256i_i16[LSrcOffset + LInner]);
  end;

  LResult := avx2_packs_epi16(LA, LB);
  for LIndex := 0 to 31 do
    AssertEquals('packs_epi16[' + IntToStr(LIndex) + ']', LExpectedI8[LIndex], LResult.m256i_i8[LIndex]);

  LResult := avx2_packus_epi16(LA, LB);
  for LIndex := 0 to 31 do
    AssertEquals('packus_epi16[' + IntToStr(LIndex) + ']', LExpectedU8[LIndex], LResult.m256i_u8[LIndex]);
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_Pack_LaneIsolationExtremes;
var
  LA: TM256;
  LB: TM256;
  LResult: TM256;
  LExpectedI16: array[0..15] of SmallInt;
  LExpectedU16: array[0..15] of Word;
  LExpectedI8: array[0..31] of ShortInt;
  LExpectedU8: array[0..31] of Byte;
  LLane: Integer;
  LSrcOffset: Integer;
  LDstOffset: Integer;
  LInner: Integer;
  LIndex: Integer;
begin
  LA := avx2_setzero_si256;
  LB := avx2_setzero_si256;

  LA.m256i_i32[0] := 40000;
  LA.m256i_i32[1] := -40000;
  LA.m256i_i32[2] := 32000;
  LA.m256i_i32[3] := -32000;
  LB.m256i_i32[0] := 50000;
  LB.m256i_i32[1] := -50000;
  LB.m256i_i32[2] := 123;
  LB.m256i_i32[3] := -123;

  LA.m256i_i32[4] := 11;
  LA.m256i_i32[5] := 22;
  LA.m256i_i32[6] := 33;
  LA.m256i_i32[7] := 44;
  LB.m256i_i32[4] := 55;
  LB.m256i_i32[5] := 66;
  LB.m256i_i32[6] := 77;
  LB.m256i_i32[7] := 88;

  for LLane := 0 to 1 do
  begin
    LSrcOffset := LLane * 4;
    LDstOffset := LLane * 8;

    for LInner := 0 to 3 do
      LExpectedI16[LDstOffset + LInner] := SaturateI32ToI16(LA.m256i_i32[LSrcOffset + LInner]);
    for LInner := 0 to 3 do
      LExpectedI16[LDstOffset + 4 + LInner] := SaturateI32ToI16(LB.m256i_i32[LSrcOffset + LInner]);

    for LInner := 0 to 3 do
      LExpectedU16[LDstOffset + LInner] := SaturateI32ToU16(LA.m256i_i32[LSrcOffset + LInner]);
    for LInner := 0 to 3 do
      LExpectedU16[LDstOffset + 4 + LInner] := SaturateI32ToU16(LB.m256i_i32[LSrcOffset + LInner]);
  end;

  LResult := avx2_packs_epi32(LA, LB);
  for LIndex := 0 to 15 do
    AssertEquals('packs_epi32 lane isolation[' + IntToStr(LIndex) + ']', LExpectedI16[LIndex], LResult.m256i_i16[LIndex]);

  LResult := avx2_packus_epi32(LA, LB);
  for LIndex := 0 to 15 do
    AssertEquals('packus_epi32 lane isolation[' + IntToStr(LIndex) + ']', LExpectedU16[LIndex], LResult.m256i_u16[LIndex]);

  LA.m256i_i16[0] := 200;
  LA.m256i_i16[1] := -200;
  LA.m256i_i16[2] := 127;
  LA.m256i_i16[3] := -128;
  LA.m256i_i16[4] := 126;
  LA.m256i_i16[5] := -127;
  LA.m256i_i16[6] := 0;
  LA.m256i_i16[7] := 1;

  LB.m256i_i16[0] := 300;
  LB.m256i_i16[1] := -300;
  LB.m256i_i16[2] := 50;
  LB.m256i_i16[3] := -50;
  LB.m256i_i16[4] := 400;
  LB.m256i_i16[5] := -400;
  LB.m256i_i16[6] := 127;
  LB.m256i_i16[7] := -128;

  for LIndex := 8 to 15 do
  begin
    LA.m256i_i16[LIndex] := 10 + LIndex;
    LB.m256i_i16[LIndex] := 30 + LIndex;
  end;

  for LLane := 0 to 1 do
  begin
    LSrcOffset := LLane * 8;
    LDstOffset := LLane * 16;

    for LInner := 0 to 7 do
      LExpectedI8[LDstOffset + LInner] := SaturateI16ToI8(LA.m256i_i16[LSrcOffset + LInner]);
    for LInner := 0 to 7 do
      LExpectedI8[LDstOffset + 8 + LInner] := SaturateI16ToI8(LB.m256i_i16[LSrcOffset + LInner]);

    for LInner := 0 to 7 do
      LExpectedU8[LDstOffset + LInner] := SaturateI16ToU8(LA.m256i_i16[LSrcOffset + LInner]);
    for LInner := 0 to 7 do
      LExpectedU8[LDstOffset + 8 + LInner] := SaturateI16ToU8(LB.m256i_i16[LSrcOffset + LInner]);
  end;

  LResult := avx2_packs_epi16(LA, LB);
  for LIndex := 0 to 31 do
    AssertEquals('packs_epi16 lane isolation[' + IntToStr(LIndex) + ']', LExpectedI8[LIndex], LResult.m256i_i8[LIndex]);

  LResult := avx2_packus_epi16(LA, LB);
  for LIndex := 0 to 31 do
    AssertEquals('packus_epi16 lane isolation[' + IntToStr(LIndex) + ']', LExpectedU8[LIndex], LResult.m256i_u8[LIndex]);
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_Pack_ExceptionalExtremes_NoArithmeticException;
var
  LA: TM256;
  LB: TM256;
  LResult: TM256;
  LRaised: Boolean;
  LExceptionClass: string;
  LIndex: Integer;
begin
  LA := avx2_setzero_si256;
  LB := avx2_setzero_si256;

  // Extreme values to ensure saturating pack path never triggers arithmetic exceptions.
  LA.m256i_i32[0] := High(LongInt);
  LA.m256i_i32[1] := Low(LongInt);
  LA.m256i_i32[2] := 65535;
  LA.m256i_i32[3] := -65535;
  LA.m256i_i32[4] := 32767;
  LA.m256i_i32[5] := -32768;
  LA.m256i_i32[6] := 0;
  LA.m256i_i32[7] := -1;

  LB.m256i_i32[0] := Low(LongInt);
  LB.m256i_i32[1] := High(LongInt);
  LB.m256i_i32[2] := -65535;
  LB.m256i_i32[3] := 65535;
  LB.m256i_i32[4] := -32767;
  LB.m256i_i32[5] := 32768;
  LB.m256i_i32[6] := -1;
  LB.m256i_i32[7] := 1;

  LRaised := False;
  LExceptionClass := '';
  try
    LResult := avx2_packs_epi32(LA, LB);
    AssertEquals('packs_epi32 high saturation', SmallInt(High(SmallInt)), LResult.m256i_i16[0]);
    LResult := avx2_packus_epi32(LA, LB);
    AssertEquals('packus_epi32 unsigned saturation', QWord(High(Word)), QWord(LResult.m256i_u16[0]));
  except
    on E: Exception do
    begin
      LRaised := True;
      LExceptionClass := E.ClassName;
    end;
  end;
  AssertFalse('pack*_epi32 should not raise arithmetic exception (got=' + LExceptionClass + ')', LRaised);

  for LIndex := 0 to 15 do
  begin
    case LIndex and 3 of
      0: LA.m256i_i16[LIndex] := High(SmallInt);
      1: LA.m256i_i16[LIndex] := Low(SmallInt);
      2: LA.m256i_i16[LIndex] := 255;
    else
      LA.m256i_i16[LIndex] := -255;
    end;
    case LIndex and 3 of
      0: LB.m256i_i16[LIndex] := Low(SmallInt);
      1: LB.m256i_i16[LIndex] := High(SmallInt);
      2: LB.m256i_i16[LIndex] := -255;
    else
      LB.m256i_i16[LIndex] := 255;
    end;
  end;

  LRaised := False;
  LExceptionClass := '';
  try
    LResult := avx2_packs_epi16(LA, LB);
    AssertEquals('packs_epi16 high saturation', ShortInt(High(ShortInt)), LResult.m256i_i8[0]);
    LResult := avx2_packus_epi16(LA, LB);
    AssertEquals('packus_epi16 unsigned saturation', QWord(High(Byte)), QWord(LResult.m256i_u8[0]));
  except
    on E: Exception do
    begin
      LRaised := True;
      LExceptionClass := E.ClassName;
    end;
  end;
  AssertFalse('pack*_epi16 should not raise arithmetic exception (got=' + LExceptionClass + ')', LRaised);
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_Unpack_LaneSemantics;
var
  LA: TM256;
  LB: TM256;
  LLo: TM256;
  LHi: TM256;
  LLane: Integer;
  LSrcOffset: Integer;
  LDstOffset: Integer;
  LInner: Integer;
  LIndex: Integer;
begin
  LA := avx2_setzero_si256;
  LB := avx2_setzero_si256;

  for LIndex := 0 to 7 do
  begin
    LA.m256i_i32[LIndex] := LIndex;
    LB.m256i_i32[LIndex] := 100 + LIndex;
  end;

  LLo := avx2_unpacklo_epi32(LA, LB);
  LHi := avx2_unpackhi_epi32(LA, LB);

  AssertEquals('unpacklo_epi32[0]', 0, LLo.m256i_i32[0]);
  AssertEquals('unpacklo_epi32[1]', 100, LLo.m256i_i32[1]);
  AssertEquals('unpacklo_epi32[2]', 1, LLo.m256i_i32[2]);
  AssertEquals('unpacklo_epi32[3]', 101, LLo.m256i_i32[3]);
  AssertEquals('unpacklo_epi32[4]', 4, LLo.m256i_i32[4]);
  AssertEquals('unpacklo_epi32[5]', 104, LLo.m256i_i32[5]);
  AssertEquals('unpacklo_epi32[6]', 5, LLo.m256i_i32[6]);
  AssertEquals('unpacklo_epi32[7]', 105, LLo.m256i_i32[7]);

  AssertEquals('unpackhi_epi32[0]', 2, LHi.m256i_i32[0]);
  AssertEquals('unpackhi_epi32[1]', 102, LHi.m256i_i32[1]);
  AssertEquals('unpackhi_epi32[2]', 3, LHi.m256i_i32[2]);
  AssertEquals('unpackhi_epi32[3]', 103, LHi.m256i_i32[3]);
  AssertEquals('unpackhi_epi32[4]', 6, LHi.m256i_i32[4]);
  AssertEquals('unpackhi_epi32[5]', 106, LHi.m256i_i32[5]);
  AssertEquals('unpackhi_epi32[6]', 7, LHi.m256i_i32[6]);
  AssertEquals('unpackhi_epi32[7]', 107, LHi.m256i_i32[7]);

  for LIndex := 0 to 15 do
  begin
    LA.m256i_i16[LIndex] := LIndex;
    LB.m256i_i16[LIndex] := 200 + LIndex;
  end;

  LLo := avx2_unpacklo_epi16(LA, LB);
  LHi := avx2_unpackhi_epi16(LA, LB);

  for LLane := 0 to 1 do
  begin
    LSrcOffset := LLane * 8;
    LDstOffset := LLane * 8;

    for LInner := 0 to 3 do
    begin
      AssertEquals('unpacklo_epi16.a[' + IntToStr((LLane * 4) + LInner) + ']',
        LA.m256i_i16[LSrcOffset + LInner],
        LLo.m256i_i16[LDstOffset + (LInner * 2)]);
      AssertEquals('unpacklo_epi16.b[' + IntToStr((LLane * 4) + LInner) + ']',
        LB.m256i_i16[LSrcOffset + LInner],
        LLo.m256i_i16[LDstOffset + (LInner * 2) + 1]);

      AssertEquals('unpackhi_epi16.a[' + IntToStr((LLane * 4) + LInner) + ']',
        LA.m256i_i16[LSrcOffset + 4 + LInner],
        LHi.m256i_i16[LDstOffset + (LInner * 2)]);
      AssertEquals('unpackhi_epi16.b[' + IntToStr((LLane * 4) + LInner) + ']',
        LB.m256i_i16[LSrcOffset + 4 + LInner],
        LHi.m256i_i16[LDstOffset + (LInner * 2) + 1]);
    end;
  end;

  for LIndex := 0 to 31 do
  begin
    LA.m256i_i8[LIndex] := LIndex;
    LB.m256i_i8[LIndex] := 60 + LIndex;
  end;

  LLo := avx2_unpacklo_epi8(LA, LB);
  LHi := avx2_unpackhi_epi8(LA, LB);

  for LLane := 0 to 1 do
  begin
    LSrcOffset := LLane * 16;
    LDstOffset := LLane * 16;

    for LInner := 0 to 7 do
    begin
      AssertEquals('unpacklo_epi8.a[' + IntToStr((LLane * 8) + LInner) + ']',
        LA.m256i_i8[LSrcOffset + LInner],
        LLo.m256i_i8[LDstOffset + (LInner * 2)]);
      AssertEquals('unpacklo_epi8.b[' + IntToStr((LLane * 8) + LInner) + ']',
        LB.m256i_i8[LSrcOffset + LInner],
        LLo.m256i_i8[LDstOffset + (LInner * 2) + 1]);

      AssertEquals('unpackhi_epi8.a[' + IntToStr((LLane * 8) + LInner) + ']',
        LA.m256i_i8[LSrcOffset + 8 + LInner],
        LHi.m256i_i8[LDstOffset + (LInner * 2)]);
      AssertEquals('unpackhi_epi8.b[' + IntToStr((LLane * 8) + LInner) + ']',
        LB.m256i_i8[LSrcOffset + 8 + LInner],
        LHi.m256i_i8[LDstOffset + (LInner * 2) + 1]);
    end;
  end;
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_Unpack_LaneIsolationSentinels;
var
  LA: TM256;
  LB: TM256;
  LLo: TM256;
  LHi: TM256;
  LIndex: Integer;
  LExpectedLo32: array[0..7] of LongInt;
  LExpectedHi32: array[0..7] of LongInt;
begin
  LA := avx2_setzero_si256;
  LB := avx2_setzero_si256;

  LA.m256i_i32[0] := 1;
  LA.m256i_i32[1] := 2;
  LA.m256i_i32[2] := 3;
  LA.m256i_i32[3] := 4;
  LA.m256i_i32[4] := 1001;
  LA.m256i_i32[5] := 1002;
  LA.m256i_i32[6] := 1003;
  LA.m256i_i32[7] := 1004;

  LB.m256i_i32[0] := 11;
  LB.m256i_i32[1] := 12;
  LB.m256i_i32[2] := 13;
  LB.m256i_i32[3] := 14;
  LB.m256i_i32[4] := 1011;
  LB.m256i_i32[5] := 1012;
  LB.m256i_i32[6] := 1013;
  LB.m256i_i32[7] := 1014;

  LExpectedLo32[0] := 1;
  LExpectedLo32[1] := 11;
  LExpectedLo32[2] := 2;
  LExpectedLo32[3] := 12;
  LExpectedLo32[4] := 1001;
  LExpectedLo32[5] := 1011;
  LExpectedLo32[6] := 1002;
  LExpectedLo32[7] := 1012;

  LExpectedHi32[0] := 3;
  LExpectedHi32[1] := 13;
  LExpectedHi32[2] := 4;
  LExpectedHi32[3] := 14;
  LExpectedHi32[4] := 1003;
  LExpectedHi32[5] := 1013;
  LExpectedHi32[6] := 1004;
  LExpectedHi32[7] := 1014;

  LLo := avx2_unpacklo_epi32(LA, LB);
  LHi := avx2_unpackhi_epi32(LA, LB);

  for LIndex := 0 to 7 do
  begin
    AssertEquals('unpacklo_epi32 sentinel[' + IntToStr(LIndex) + ']',
      LExpectedLo32[LIndex],
      LLo.m256i_i32[LIndex]);

    AssertEquals('unpackhi_epi32 sentinel[' + IntToStr(LIndex) + ']',
      LExpectedHi32[LIndex],
      LHi.m256i_i32[LIndex]);
  end;
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_Unpack_ExceptionalBitPatterns_Preserved;
var
  LA: TM256;
  LB: TM256;
  LLo: TM256;
  LHi: TM256;
  LExpectedLo8: array[0..31] of Byte;
  LExpectedHi8: array[0..31] of Byte;
  LExpectedLo16: array[0..15] of Word;
  LExpectedHi16: array[0..15] of Word;
  LExpectedLo32: array[0..7] of DWord;
  LExpectedHi32: array[0..7] of DWord;
  LLane: Integer;
  LSrcOffset: Integer;
  LDstOffset: Integer;
  LInner: Integer;
  LIndex: Integer;
begin
  LA := avx2_setzero_si256;
  LB := avx2_setzero_si256;

  for LIndex := 0 to 31 do
  begin
    LA.m256i_u8[LIndex] := Byte((LIndex * 17) xor $AA);
    LB.m256i_u8[LIndex] := Byte((LIndex * 29) xor $55);
  end;
  LA.m256i_u8[0] := $00;  LB.m256i_u8[0] := $FF;
  LA.m256i_u8[1] := $80;  LB.m256i_u8[1] := $7F;
  LA.m256i_u8[8] := $01;  LB.m256i_u8[8] := $FE;
  LA.m256i_u8[24] := $AA; LB.m256i_u8[24] := $55;

  for LLane := 0 to 1 do
  begin
    LSrcOffset := LLane * 16;
    LDstOffset := LLane * 16;

    for LInner := 0 to 7 do
    begin
      LExpectedLo8[LDstOffset + (LInner * 2)] := LA.m256i_u8[LSrcOffset + LInner];
      LExpectedLo8[LDstOffset + (LInner * 2) + 1] := LB.m256i_u8[LSrcOffset + LInner];
      LExpectedHi8[LDstOffset + (LInner * 2)] := LA.m256i_u8[LSrcOffset + 8 + LInner];
      LExpectedHi8[LDstOffset + (LInner * 2) + 1] := LB.m256i_u8[LSrcOffset + 8 + LInner];
    end;
  end;

  LLo := avx2_unpacklo_epi8(LA, LB);
  LHi := avx2_unpackhi_epi8(LA, LB);
  for LIndex := 0 to 31 do
  begin
    AssertEquals('unpacklo_epi8 exceptional[' + IntToStr(LIndex) + ']',
      QWord(LExpectedLo8[LIndex]),
      QWord(LLo.m256i_u8[LIndex]));
    AssertEquals('unpackhi_epi8 exceptional[' + IntToStr(LIndex) + ']',
      QWord(LExpectedHi8[LIndex]),
      QWord(LHi.m256i_u8[LIndex]));
  end;

  for LIndex := 0 to 15 do
  begin
    LA.m256i_u16[LIndex] := Word((LIndex * $1111) xor $8000);
    LB.m256i_u16[LIndex] := Word((LIndex * $2222) xor $7FFF);
  end;
  LA.m256i_u16[0] := $0000; LB.m256i_u16[0] := $FFFF;
  LA.m256i_u16[4] := $8000; LB.m256i_u16[4] := $7FFF;

  for LLane := 0 to 1 do
  begin
    LSrcOffset := LLane * 8;
    LDstOffset := LLane * 8;
    for LInner := 0 to 3 do
    begin
      LExpectedLo16[LDstOffset + (LInner * 2)] := LA.m256i_u16[LSrcOffset + LInner];
      LExpectedLo16[LDstOffset + (LInner * 2) + 1] := LB.m256i_u16[LSrcOffset + LInner];
      LExpectedHi16[LDstOffset + (LInner * 2)] := LA.m256i_u16[LSrcOffset + 4 + LInner];
      LExpectedHi16[LDstOffset + (LInner * 2) + 1] := LB.m256i_u16[LSrcOffset + 4 + LInner];
    end;
  end;

  LLo := avx2_unpacklo_epi16(LA, LB);
  LHi := avx2_unpackhi_epi16(LA, LB);
  for LIndex := 0 to 15 do
  begin
    AssertEquals('unpacklo_epi16 exceptional[' + IntToStr(LIndex) + ']',
      QWord(LExpectedLo16[LIndex]),
      QWord(LLo.m256i_u16[LIndex]));
    AssertEquals('unpackhi_epi16 exceptional[' + IntToStr(LIndex) + ']',
      QWord(LExpectedHi16[LIndex]),
      QWord(LHi.m256i_u16[LIndex]));
  end;

  for LIndex := 0 to 7 do
  begin
    LA.m256i_u32[LIndex] := DWord((QWord(LIndex) * QWord($11111111)) xor QWord($80000000));
    LB.m256i_u32[LIndex] := DWord((QWord(LIndex) * QWord($22222222)) xor QWord($7FFFFFFF));
  end;
  LA.m256i_u32[0] := $00000000; LB.m256i_u32[0] := $FFFFFFFF;
  LA.m256i_u32[2] := $80000000; LB.m256i_u32[2] := $7FFFFFFF;

  for LLane := 0 to 1 do
  begin
    LSrcOffset := LLane * 4;
    LDstOffset := LLane * 4;
    LExpectedLo32[LDstOffset + 0] := LA.m256i_u32[LSrcOffset + 0];
    LExpectedLo32[LDstOffset + 1] := LB.m256i_u32[LSrcOffset + 0];
    LExpectedLo32[LDstOffset + 2] := LA.m256i_u32[LSrcOffset + 1];
    LExpectedLo32[LDstOffset + 3] := LB.m256i_u32[LSrcOffset + 1];
    LExpectedHi32[LDstOffset + 0] := LA.m256i_u32[LSrcOffset + 2];
    LExpectedHi32[LDstOffset + 1] := LB.m256i_u32[LSrcOffset + 2];
    LExpectedHi32[LDstOffset + 2] := LA.m256i_u32[LSrcOffset + 3];
    LExpectedHi32[LDstOffset + 3] := LB.m256i_u32[LSrcOffset + 3];
  end;

  LLo := avx2_unpacklo_epi32(LA, LB);
  LHi := avx2_unpackhi_epi32(LA, LB);
  for LIndex := 0 to 7 do
  begin
    AssertEquals('unpacklo_epi32 exceptional[' + IntToStr(LIndex) + ']',
      QWord(LExpectedLo32[LIndex]),
      QWord(LLo.m256i_u32[LIndex]));
    AssertEquals('unpackhi_epi32 exceptional[' + IntToStr(LIndex) + ']',
      QWord(LExpectedHi32[LIndex]),
      QWord(LHi.m256i_u32[LIndex]));
  end;
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_Permute_Semantics;
var
  LA: TM256;
  LIdx: TM256;
  LResult: TM256;
  LIndex: Integer;
begin
  LA := avx2_setzero_si256;
  LIdx := avx2_setzero_si256;

  LA.m256i_i64[0] := 10;
  LA.m256i_i64[1] := 20;
  LA.m256i_i64[2] := 30;
  LA.m256i_i64[3] := 40;

  LResult := avx2_permute4x64_epi64(LA, $1B); // reverse order
  AssertEquals('permute4x64_epi64[0]', 40, LResult.m256i_i64[0]);
  AssertEquals('permute4x64_epi64[1]', 30, LResult.m256i_i64[1]);
  AssertEquals('permute4x64_epi64[2]', 20, LResult.m256i_i64[2]);
  AssertEquals('permute4x64_epi64[3]', 10, LResult.m256i_i64[3]);

  LA.m256_f64[0] := 1.5;
  LA.m256_f64[1] := 2.5;
  LA.m256_f64[2] := 3.5;
  LA.m256_f64[3] := 4.5;

  LResult := avx2_permute4x64_pd(LA, $4E); // [2,3,0,1]
  AssertEquals('permute4x64_pd[0]', 3.5, LResult.m256_f64[0], 0.0000001);
  AssertEquals('permute4x64_pd[1]', 4.5, LResult.m256_f64[1], 0.0000001);
  AssertEquals('permute4x64_pd[2]', 1.5, LResult.m256_f64[2], 0.0000001);
  AssertEquals('permute4x64_pd[3]', 2.5, LResult.m256_f64[3], 0.0000001);

  for LIndex := 0 to 7 do
  begin
    LA.m256i_i32[LIndex] := 10 + LIndex;
    LIdx.m256i_i32[LIndex] := 7 - LIndex;
  end;

  LResult := avx2_permutevar8x32_epi32(LA, LIdx);
  for LIndex := 0 to 7 do
    AssertEquals('permutevar8x32_epi32[' + IntToStr(LIndex) + ']', 17 - LIndex, LResult.m256i_i32[LIndex]);

  for LIndex := 0 to 7 do
    LA.m256_f32[LIndex] := 0.5 + LIndex;
  LIdx.m256i_i32[0] := 0;
  LIdx.m256i_i32[1] := 0;
  LIdx.m256i_i32[2] := 7;
  LIdx.m256i_i32[3] := 7;
  LIdx.m256i_i32[4] := 3;
  LIdx.m256i_i32[5] := 3;
  LIdx.m256i_i32[6] := 4;
  LIdx.m256i_i32[7] := 4;

  LResult := avx2_permutevar8x32_ps(LA, LIdx);
  AssertEquals('permutevar8x32_ps[0]', 0.5, LResult.m256_f32[0], 0.0001);
  AssertEquals('permutevar8x32_ps[1]', 0.5, LResult.m256_f32[1], 0.0001);
  AssertEquals('permutevar8x32_ps[2]', 7.5, LResult.m256_f32[2], 0.0001);
  AssertEquals('permutevar8x32_ps[3]', 7.5, LResult.m256_f32[3], 0.0001);
  AssertEquals('permutevar8x32_ps[4]', 3.5, LResult.m256_f32[4], 0.0001);
  AssertEquals('permutevar8x32_ps[5]', 3.5, LResult.m256_f32[5], 0.0001);
  AssertEquals('permutevar8x32_ps[6]', 4.5, LResult.m256_f32[6], 0.0001);
  AssertEquals('permutevar8x32_ps[7]', 4.5, LResult.m256_f32[7], 0.0001);
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_PermuteVar_IndexMasking;
const
  EXPECTED_INDICES: array[0..7] of Integer = (0, 1, 2, 3, 7, 6, 0, 7);
var
  LA: TM256;
  LIdx: TM256;
  LResult: TM256;
  LIndex: Integer;
begin
  LA := avx2_setzero_si256;
  LIdx := avx2_setzero_si256;

  for LIndex := 0 to 7 do
  begin
    LA.m256i_i32[LIndex] := 100 + LIndex;
    LA.m256_f32[LIndex] := 10.25 + LIndex;
  end;

  LIdx.m256i_i32[0] := 8;
  LIdx.m256i_i32[1] := 9;
  LIdx.m256i_i32[2] := 10;
  LIdx.m256i_i32[3] := 11;
  LIdx.m256i_i32[4] := -1;
  LIdx.m256i_i32[5] := -2;
  LIdx.m256i_i32[6] := -16;
  LIdx.m256i_i32[7] := 15;

  LResult := avx2_permutevar8x32_epi32(LA, LIdx);
  for LIndex := 0 to 7 do
    AssertEquals('permutevar8x32_epi32 mask[' + IntToStr(LIndex) + ']',
      LA.m256i_i32[EXPECTED_INDICES[LIndex]],
      LResult.m256i_i32[LIndex]);

  LResult := avx2_permutevar8x32_ps(LA, LIdx);
  for LIndex := 0 to 7 do
    AssertEquals('permutevar8x32_ps mask[' + IntToStr(LIndex) + ']',
      LA.m256_f32[EXPECTED_INDICES[LIndex]],
      LResult.m256_f32[LIndex],
      0.0001);
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_Permute4x64_Imm8Combinations;
var
  LA: TM256;
  LResultI64: TM256;
  LResultF64: TM256;
  LImm: Integer;
  LDstIndex: Integer;
  LSourceIndex: Integer;
begin
  LA := avx2_setzero_si256;

  LA.m256i_i64[0] := 101;
  LA.m256i_i64[1] := 202;
  LA.m256i_i64[2] := 303;
  LA.m256i_i64[3] := 404;

  LA.m256_f64[0] := 1.25;
  LA.m256_f64[1] := 2.5;
  LA.m256_f64[2] := 4.75;
  LA.m256_f64[3] := 8.125;

  for LImm := 0 to 255 do
  begin
    LResultI64 := avx2_permute4x64_epi64(LA, Byte(LImm));
    LResultF64 := avx2_permute4x64_pd(LA, Byte(LImm));

    for LDstIndex := 0 to 3 do
    begin
      LSourceIndex := (LImm shr (LDstIndex * 2)) and 3;

      AssertEquals('permute4x64_epi64 imm=' + IntToStr(LImm) + ' dst=' + IntToStr(LDstIndex),
        LA.m256i_i64[LSourceIndex],
        LResultI64.m256i_i64[LDstIndex]);

      AssertEquals('permute4x64_pd imm=' + IntToStr(LImm) + ' dst=' + IntToStr(LDstIndex),
        LA.m256_f64[LSourceIndex],
        LResultF64.m256_f64[LDstIndex],
        0.0000001);
    end;
  end;
end;

procedure TTestCase_AVX2IntrinsicsFallback.Test_Permute_ExceptionalIndexBitPatterns;
const
  INDEX_BITS: array[0..7] of DWord = (
    $FFFFFFFF, $80000000, $7FFFFFFF, $12345678,
    $00000008, $0000000F, $FFFFFFF0, $FFFFFFF7
  );
var
  LA: TM256;
  LIdx: TM256;
  LResult: TM256;
  LExpectedIndex: Integer;
  LIndex: Integer;
begin
  LA := avx2_setzero_si256;
  LIdx := avx2_setzero_si256;

  for LIndex := 0 to 7 do
  begin
    LA.m256i_i32[LIndex] := 1000 + (LIndex * 7);
    LA.m256_f32[LIndex] := 0.125 + (LIndex * 1.5);
    LIdx.m256i_u32[LIndex] := INDEX_BITS[LIndex];
  end;

  LResult := avx2_permutevar8x32_epi32(LA, LIdx);
  for LIndex := 0 to 7 do
  begin
    LExpectedIndex := Integer(INDEX_BITS[LIndex] and 7);
    AssertEquals('permutevar8x32_epi32 exceptional[' + IntToStr(LIndex) + ']',
      LA.m256i_i32[LExpectedIndex],
      LResult.m256i_i32[LIndex]);
  end;

  LResult := avx2_permutevar8x32_ps(LA, LIdx);
  for LIndex := 0 to 7 do
  begin
    LExpectedIndex := Integer(INDEX_BITS[LIndex] and 7);
    AssertEquals('permutevar8x32_ps exceptional[' + IntToStr(LIndex) + ']',
      LA.m256_f32[LExpectedIndex],
      LResult.m256_f32[LIndex],
      0.0001);
  end;
end;

initialization
  RegisterTest(TTestCase_AVX2IntrinsicsFallback);

end.
