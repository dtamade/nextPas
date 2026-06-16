program test_mmx_raw_leaf_parity;
{$I ../../src/nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  nextpas.core.simd.intrinsics.mmx;

type
  TByteArray8 = array[0..7] of Byte;
  TWordArray4 = array[0..3] of Word;
  TDWordArray2 = array[0..1] of DWord;
  TLongIntArray2 = array[0..1] of LongInt;
  TLongIntArray3 = array[0..2] of LongInt;
  TQWordArray3 = array[0..2] of QWord;

var
  GPass: Integer = 0;
  GFail: Integer = 0;

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

procedure CheckI8x8(const aName: string; const aActual: TM64; const aExpected: array of Integer);
var
  LIndex: Integer;
begin
  if Length(aExpected) <> 8 then
  begin
    WriteLn('FAIL: ', aName, ' expected 8 lanes, got=', Length(aExpected));
    Inc(GFail);
    Exit;
  end;

  for LIndex := 0 to 7 do
    CheckI32(Format('%s[%d]', [aName, LIndex]), aExpected[LIndex], aActual.mm_i8[LIndex]);
end;

procedure CheckU8x8(const aName: string; const aActual: TM64; const aExpected: array of Integer);
var
  LIndex: Integer;
begin
  if Length(aExpected) <> 8 then
  begin
    WriteLn('FAIL: ', aName, ' expected 8 lanes, got=', Length(aExpected));
    Inc(GFail);
    Exit;
  end;

  for LIndex := 0 to 7 do
    CheckI32(Format('%s[%d]', [aName, LIndex]), aExpected[LIndex], aActual.mm_u8[LIndex]);
end;

procedure CheckI16x4(const aName: string; const aActual: TM64; const aExpected: array of Integer);
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
    CheckI32(Format('%s[%d]', [aName, LIndex]), aExpected[LIndex], aActual.mm_i16[LIndex]);
end;

procedure CheckU16x4(const aName: string; const aActual: TM64; const aExpected: array of Integer);
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
    CheckI32(Format('%s[%d]', [aName, LIndex]), aExpected[LIndex], aActual.mm_u16[LIndex]);
end;

procedure CheckU32x2(const aName: string; const aActual: TM64; const aExpected: array of DWord);
var
  LIndex: Integer;
begin
  if Length(aExpected) <> 2 then
  begin
    WriteLn('FAIL: ', aName, ' expected 2 lanes, got=', Length(aExpected));
    Inc(GFail);
    Exit;
  end;

  for LIndex := 0 to 1 do
    CheckU32(Format('%s[%d]', [aName, LIndex]), aExpected[LIndex], aActual.mm_u32[LIndex]);
end;

procedure CheckI32x2(const aName: string; const aActual: TM64; const aExpected: array of LongInt);
var
  LIndex: Integer;
begin
  if Length(aExpected) <> 2 then
  begin
    WriteLn('FAIL: ', aName, ' expected 2 lanes, got=', Length(aExpected));
    Inc(GFail);
    Exit;
  end;

  for LIndex := 0 to 1 do
    CheckI32(Format('%s[%d]', [aName, LIndex]), aExpected[LIndex], aActual.mm_i32[LIndex]);
end;

function ShiftCount(const aCount: QWord): TM64; inline;
begin
  Result.mm_u64 := aCount;
end;

procedure TestSetFamily;
var
  LZero: TM64;
  LBroadcast8: TM64;
  LBroadcast16: TM64;
  LBroadcast32: TM64;
  LVector8: TM64;
  LVector16: TM64;
  LVector32: TM64;
begin
  LZero := mmx_setzero_si64;
  LBroadcast8 := mmx_set1_pi8(-7);
  LBroadcast16 := mmx_set1_pi16(-1234);
  LBroadcast32 := mmx_set1_pi32(-567890);
  LVector8 := mmx_set_pi8(7, 6, 5, 4, 3, 2, 1, 0);
  LVector16 := mmx_set_pi16(40, 30, 20, 10);
  LVector32 := mmx_set_pi32(20, 10);
  mmx_emms;

  CheckU64('mmx_setzero_si64', 0, LZero.mm_u64);
  CheckI8x8('mmx_set1_pi8', LBroadcast8, [-7, -7, -7, -7, -7, -7, -7, -7]);
  CheckI16x4('mmx_set1_pi16', LBroadcast16, [-1234, -1234, -1234, -1234]);
  CheckI32x2('mmx_set1_pi32', LBroadcast32, [-567890, -567890]);
  CheckI8x8('mmx_set_pi8', LVector8, [0, 1, 2, 3, 4, 5, 6, 7]);
  CheckI16x4('mmx_set_pi16', LVector16, [10, 20, 30, 40]);
  CheckI32x2('mmx_set_pi32', LVector32, [10, 20]);
end;

procedure TestLoadStoreAndMoveFamily;
const
  MovdValue: LongInt = -1985229329;
  MovdSentinel: LongInt = 123456789;
  MovqValue: QWord = QWord($0123456789ABCDEF);
  MovqSentinel: QWord = QWord($CAFEBABEDEADBEEF);
var
  LLoad32: TM64;
  LLoad64: TM64;
  LFromR32: TM64;
  LStore32: TLongIntArray2;
  LStore64: TQWordArray3;
  LSource32: LongInt;
  LSource64: QWord;
  LExtract32: DWord;
begin
  LSource32 := MovdValue;
  LSource64 := MovqValue;
  LStore32[0] := 0;
  LStore32[1] := MovdSentinel;
  LStore64[0] := MovqSentinel;
  LStore64[1] := 0;
  LStore64[2] := MovqSentinel;

  LLoad32 := mmx_movd_mm(@LSource32);
  LExtract32 := mmx_movd_r32(LLoad32);
  LFromR32 := mmx_movd_r32_to_mm(DWord(MovdValue));
  mmx_movd_mm_store(LStore32[0], LFromR32);

  LLoad64 := mmx_movq_mm(@LSource64);
  mmx_movq_mm_store(LStore64[1], LLoad64);
  mmx_emms;

  CheckI32('mmx_movd_mm[0]', MovdValue, LLoad32.mm_i32[0]);
  CheckU32('mmx_movd_mm[1]', 0, LLoad32.mm_u32[1]);
  CheckU32('mmx_movd_r32', DWord(MovdValue), LExtract32);
  CheckI32('mmx_movd_r32_to_mm[0]', MovdValue, LFromR32.mm_i32[0]);
  CheckU32('mmx_movd_r32_to_mm[1]', 0, LFromR32.mm_u32[1]);
  CheckI32('mmx_movd_mm_store[value]', MovdValue, LStore32[0]);
  CheckI32('mmx_movd_mm_store[sentinel]', MovdSentinel, LStore32[1]);

  CheckU64('mmx_movq_mm', MovqValue, LLoad64.mm_u64);
  CheckU64('mmx_movq_mm_store[left]', MovqSentinel, LStore64[0]);
  CheckU64('mmx_movq_mm_store[value]', MovqValue, LStore64[1]);
  CheckU64('mmx_movq_mm_store[right]', MovqSentinel, LStore64[2]);
end;

procedure TestEmmsCallable;
var
  LValue: TM64;
begin
  LValue := mmx_setzero_si64;
  mmx_emms;
  CheckU64('mmx_emms callability', 0, LValue.mm_u64);
end;

procedure TestBitwiseAndCompareFamily;
const
  BitwiseA: QWord = QWord($0FF00FF00FF00FF0);
  BitwiseB: QWord = QWord($3333CCCC5555AAAA);
var
  LBitsA: TM64;
  LBitsB: TM64;
  LByteA: TM64;
  LByteB: TM64;
  LWordA: TM64;
  LWordB: TM64;
  LWordCompareA: TM64;
  LWordCompareB: TM64;
  LDWordA: TM64;
  LDWordB: TM64;
  LDWordCompareA: TM64;
  LDWordCompareB: TM64;
begin
  LBitsA.mm_u64 := BitwiseA;
  LBitsB.mm_u64 := BitwiseB;
  LByteA := mmx_set_pi8(-1, 0, 12, -8, 3, 3, -5, 10);
  LByteB := mmx_set_pi8(2, 0, 9, -8, 3, 4, -6, 10);
  LWordA := mmx_set_pi16(-4000, 3000, -2000, 1000);
  LWordB := mmx_set_pi16(-5000, 3000, -1500, 1000);
  LWordCompareA := mmx_set_pi16(-1, 1, -2000, 1000);
  LWordCompareB := mmx_set_pi16(1, -1, -1500, 1000);
  LDWordA := mmx_set_pi32(-200000, 100000);
  LDWordB := mmx_set_pi32(-300000, 100000);
  LDWordCompareA := mmx_set_pi32(-1, 1);
  LDWordCompareB := mmx_set_pi32(1, -1);

  CheckU64('mmx_pand', QWord($03300CC005500AA0), mmx_pand(LBitsA, LBitsB).mm_u64);
  CheckU64('mmx_pandn', QWord($3003C00C5005A00A), mmx_pandn(LBitsA, LBitsB).mm_u64);
  CheckU64('mmx_por', QWord($3FF3CFFC5FF5AFFA), mmx_por(LBitsA, LBitsB).mm_u64);
  CheckU64('mmx_pxor', QWord($3CC3C33C5AA5A55A), mmx_pxor(LBitsA, LBitsB).mm_u64);

  CheckI8x8('mmx_pcmpeqb', mmx_pcmpeqb(LByteA, LByteB), [-1, 0, 0, -1, -1, 0, -1, 0]);
  CheckI8x8('mmx_pcmpgtb', mmx_pcmpgtb(LByteA, LByteB), [0, -1, 0, 0, 0, -1, 0, 0]);

  CheckI16x4('mmx_pcmpeqw', mmx_pcmpeqw(LWordA, LWordB), [-1, 0, -1, 0]);
  CheckI16x4('mmx_pcmpgtw', mmx_pcmpgtw(LWordCompareA, LWordCompareB), [0, 0, -1, 0]);

  CheckI32x2('mmx_pcmpeqd', mmx_pcmpeqd(LDWordA, LDWordB), [-1, 0]);
  CheckI32x2('mmx_pcmpgtd', mmx_pcmpgtd(LDWordCompareA, LDWordCompareB), [-1, 0]);
  mmx_emms;
end;

procedure TestArithmeticAndSaturatingFamily;
var
  LByteAddA: TM64;
  LByteAddB: TM64;
  LByteSatAddA: TM64;
  LByteSatAddB: TM64;
  LByteSatSubA: TM64;
  LByteSatSubB: TM64;
  LByteUSatAddA: TM64;
  LByteUSatAddB: TM64;
  LByteUSatSubA: TM64;
  LByteUSatSubB: TM64;
  LWordAddA: TM64;
  LWordAddB: TM64;
  LWordSatAddA: TM64;
  LWordSatAddB: TM64;
  LWordSatSubA: TM64;
  LWordSatSubB: TM64;
  LWordUSatAddA: TM64;
  LWordUSatAddB: TM64;
  LWordUSatSubA: TM64;
  LWordUSatSubB: TM64;
  LDWordAddA: TM64;
  LDWordAddB: TM64;
  LQWordAddA: TM64;
  LQWordAddB: TM64;
  LMulA: TM64;
  LMulB: TM64;
  LMaddA: TM64;
  LMaddB: TM64;
begin
  LByteAddA := mmx_set_pi8(-1, 1, -50, 50, -120, -100, 100, 120);
  LByteAddB := mmx_set_pi8(2, -2, 80, -80, -20, -30, 40, 10);
  LByteSatAddA := mmx_set_pi8(-10, 10, -50, 50, -120, -100, 100, 120);
  LByteSatAddB := mmx_set_pi8(-5, 5, -10, 10, -20, -20, 20, 20);
  LByteSatSubA := mmx_set_pi8(-10, 10, -50, 50, -120, -100, 100, 120);
  LByteSatSubB := mmx_set_pi8(-5, 5, 10, -10, 20, 20, -20, -20);
  LByteUSatAddA := mmx_set_pi8(30, -1, 1, 100, -56, 0, 10, -6);
  LByteUSatAddB := mmx_set_pi8(-36, 1, -1, -56, 100, 1, 20, 10);
  LByteUSatSubA := mmx_set_pi8(10, 30, -1, 0, -56, 100, 20, 5);
  LByteUSatSubB := mmx_set_pi8(20, 40, -56, 1, -6, 20, 15, 10);

  CheckI8x8('mmx_paddb', mmx_paddb(LByteAddA, LByteAddB), [-126, -116, 126, 116, -30, 30, -1, 1]);
  CheckI8x8('mmx_psubb', mmx_psubb(LByteAddA, LByteAddB), [110, 60, -70, -100, -126, 126, 3, -3]);
  CheckI8x8('mmx_paddsb', mmx_paddsb(LByteSatAddA, LByteSatAddB), [127, 120, -120, -128, 60, -60, 15, -15]);
  CheckI8x8('mmx_psubsb', mmx_psubsb(LByteSatSubA, LByteSatSubB), [127, 120, -120, -128, 60, -60, 5, -5]);
  CheckU8x8('mmx_paddusb', mmx_paddusb(LByteUSatAddA, LByteUSatAddB), [255, 30, 1, 255, 255, 255, 255, 250]);
  CheckU8x8('mmx_psubusb', mmx_psubusb(LByteUSatSubA, LByteUSatSubB), [0, 5, 80, 0, 0, 55, 0, 0]);

  LWordAddA := mmx_set_pi16(-1000, 1000, -30000, 30000);
  LWordAddB := mmx_set_pi16(2000, -2000, -10000, 10000);
  LWordSatAddA := mmx_set_pi16(-1000, 1000, -30000, 30000);
  LWordSatAddB := mmx_set_pi16(2000, -2000, -10000, 10000);
  LWordSatSubA := mmx_set_pi16(-1000, 1000, -30000, 30000);
  LWordSatSubB := mmx_set_pi16(2000, -2000, 10000, -10000);
  LWordUSatAddA.mm_u16[0] := 65000;
  LWordUSatAddA.mm_u16[1] := 10;
  LWordUSatAddA.mm_u16[2] := 0;
  LWordUSatAddA.mm_u16[3] := 40000;
  LWordUSatAddB.mm_u16[0] := 1000;
  LWordUSatAddB.mm_u16[1] := 20;
  LWordUSatAddB.mm_u16[2] := 1;
  LWordUSatAddB.mm_u16[3] := 30000;
  LWordUSatSubA.mm_u16[0] := 500;
  LWordUSatSubA.mm_u16[1] := 10;
  LWordUSatSubA.mm_u16[2] := 65535;
  LWordUSatSubA.mm_u16[3] := 20000;
  LWordUSatSubB.mm_u16[0] := 1000;
  LWordUSatSubB.mm_u16[1] := 20;
  LWordUSatSubB.mm_u16[2] := 1;
  LWordUSatSubB.mm_u16[3] := 30000;

  CheckI16x4('mmx_paddw', mmx_paddw(LWordAddA, LWordAddB), [-25536, 25536, -1000, 1000]);
  CheckI16x4('mmx_psubw', mmx_psubw(LWordAddA, LWordAddB), [20000, -20000, 3000, -3000]);
  CheckI16x4('mmx_paddsw', mmx_paddsw(LWordSatAddA, LWordSatAddB), [32767, -32768, -1000, 1000]);
  CheckI16x4('mmx_psubsw', mmx_psubsw(LWordSatSubA, LWordSatSubB), [32767, -32768, 3000, -3000]);
  CheckU16x4('mmx_paddusw', mmx_paddusw(LWordUSatAddA, LWordUSatAddB), [65535, 30, 1, 65535]);
  CheckU16x4('mmx_psubusw', mmx_psubusw(LWordUSatSubA, LWordUSatSubB), [0, 0, 65534, 0]);

  LDWordAddA := mmx_set_pi32(-2000000000, 2000000000);
  LDWordAddB := mmx_set_pi32(-1500000000, 1000000000);
  CheckI32x2('mmx_paddd', mmx_paddd(LDWordAddA, LDWordAddB), [-1294967296, 794967296]);
  CheckI32x2('mmx_psubd', mmx_psubd(LDWordAddA, LDWordAddB), [1000000000, -500000000]);

  LQWordAddA.mm_u64 := QWord($FFFFFFFFFFFFFFF0);
  LQWordAddB.mm_u64 := QWord($0000000000000030);
  CheckU64('mmx_paddq', QWord($0000000000000020), mmx_paddq(LQWordAddA, LQWordAddB).mm_u64);
  CheckU64('mmx_psubq', QWord($FFFFFFFFFFFFFFC0), mmx_psubq(LQWordAddA, LQWordAddB).mm_u64);

  LMulA := mmx_set_pi16(30000, -30000, 20000, -20000);
  LMulB := mmx_set_pi16(3, 3, 4, 4);
  CheckI16x4('mmx_pmullw', mmx_pmullw(LMulA, LMulB), [-14464, 14464, -24464, 24464]);
  CheckI16x4('mmx_pmulhw', mmx_pmulhw(LMulA, LMulB), [-2, 1, -2, 1]);

  LMaddA := mmx_set_pi16(300, -400, 500, -600);
  LMaddB := mmx_set_pi16(-7, 8, 9, -10);
  CheckI32x2('mmx_pmaddwd', mmx_pmaddwd(LMaddA, LMaddB), [10500, -5300]);
  mmx_emms;
end;

procedure TestShiftFamily;
var
  LWordLeftBase: TM64;
  LDWordLeftBase: TM64;
  LQWordLeftBase: TM64;
  LWordRightBase: TM64;
  LDWordRightBase: TM64;
  LQWordRightBase: TM64;
  LWordArithBase: TM64;
  LWordArithMMBase: TM64;
  LDWordArithBase: TM64;
  LDWordArithImmBase: TM64;
begin
  LWordLeftBase := mmx_set_pi16(4, 3, 2, 1);
  CheckI16x4('mmx_psllw', mmx_psllw(LWordLeftBase, ShiftCount(1)), [2, 4, 6, 8]);
  CheckI16x4('mmx_psllw_imm', mmx_psllw_imm(LWordLeftBase, 4), [16, 32, 48, 64]);
  CheckI16x4('mmx_psllw_mm', mmx_psllw_mm(LWordLeftBase, ShiftCount(16)), [0, 0, 0, 0]);

  LDWordLeftBase := mmx_set_pi32(1073741824, 1);
  CheckI32x2('mmx_pslld', mmx_pslld(LDWordLeftBase, ShiftCount(1)), [2, -2147483648]);
  CheckI32x2('mmx_pslld_imm', mmx_pslld_imm(mmx_set_pi32(2, 1), 31), [-2147483648, 0]);

  LQWordLeftBase.mm_u64 := QWord($0000000000000001);
  CheckU64('mmx_psllq', QWord($0000000000000010), mmx_psllq(LQWordLeftBase, ShiftCount(4)).mm_u64);
  CheckU64('mmx_psllq_imm', 0, mmx_psllq_imm(LQWordLeftBase, 64).mm_u64);

  LWordRightBase := mmx_set_pi16(-1, -32768, 16384, 1);
  CheckU16x4('mmx_psrlw', mmx_psrlw(LWordRightBase, ShiftCount(1)), [0, 8192, 16384, 32767]);
  CheckU16x4('mmx_psrlw_imm', mmx_psrlw_imm(LWordRightBase, 16), [0, 0, 0, 0]);
  CheckU16x4('mmx_psrlw_mm', mmx_psrlw_mm(mmx_set_pi16(64, 48, 32, 16), ShiftCount(4)), [1, 2, 3, 4]);

  LDWordRightBase := mmx_set_pi32(-1, -2147483648);
  CheckI32x2('mmx_psrld', mmx_psrld(LDWordRightBase, ShiftCount(31)), [1, 1]);
  CheckI32x2('mmx_psrld_imm', mmx_psrld_imm(LDWordRightBase, 32), [0, 0]);

  LQWordRightBase.mm_u64 := QWord($F000000000000000);
  CheckU64('mmx_psrlq', QWord($0F00000000000000), mmx_psrlq(LQWordRightBase, ShiftCount(4)).mm_u64);
  CheckU64('mmx_psrlq_imm', 0, mmx_psrlq_imm(LQWordRightBase, 64).mm_u64);

  LWordArithBase := mmx_set_pi16(32767, 2, -2, -32768);
  CheckI16x4('mmx_psraw', mmx_psraw(LWordArithBase, ShiftCount(1)), [-16384, -1, 1, 16383]);
  CheckI16x4('mmx_psraw_imm', mmx_psraw_imm(LWordArithBase, 16), [-1, -1, 0, 0]);

  LWordArithMMBase := mmx_set_pi16(255, -256, 256, -1);
  CheckI16x4('mmx_psraw_mm', mmx_psraw_mm(LWordArithMMBase, ShiftCount(8)), [-1, 1, -1, 0]);

  LDWordArithBase := mmx_set_pi32(2147483647, -2147483648);
  CheckI32x2('mmx_psrad', mmx_psrad(LDWordArithBase, ShiftCount(1)), [-1073741824, 1073741823]);

  LDWordArithImmBase := mmx_set_pi32(2, -2);
  CheckI32x2('mmx_psrad_imm', mmx_psrad_imm(LDWordArithImmBase, 32), [-1, 0]);
  mmx_emms;
end;

procedure TestPackAndUnpackFamily;
var
  LPackWordsA: TM64;
  LPackWordsB: TM64;
  LPackDWordsA: TM64;
  LPackDWordsB: TM64;
  LBytesA: TM64;
  LBytesB: TM64;
  LWordsA: TM64;
  LWordsB: TM64;
  LDWordsA: TM64;
  LDWordsB: TM64;
  LBytesMem: TByteArray8;
  LWordsMem: TWordArray4;
  LDWordsMem: TDWordArray2;
begin
  LPackWordsA := mmx_set_pi16(127, -128, 200, -200);
  LPackWordsB := mmx_set_pi16(400, -400, 90, -90);
  CheckI8x8('mmx_packsswb', mmx_packsswb(LPackWordsA, LPackWordsB), [-128, 127, -128, 127, -90, 90, -128, 127]);

  LPackDWordsA := mmx_set_pi32(32767, -40000);
  LPackDWordsB := mmx_set_pi32(50000, -32768);
  CheckI16x4('mmx_packssdw', mmx_packssdw(LPackDWordsA, LPackDWordsB), [-32768, 32767, -32768, 32767]);

  LPackWordsA := mmx_set_pi16(255, 128, 1, -1);
  LPackWordsB := mmx_set_pi16(300, -300, 42, 0);
  CheckU8x8('mmx_packuswb', mmx_packuswb(LPackWordsA, LPackWordsB), [0, 1, 128, 255, 0, 42, 0, 255]);

  LPackDWordsA := mmx_set_pi32(70000, -1);
  LPackDWordsB := mmx_set_pi32(32768, 42);
  CheckU16x4('mmx_packusdw', mmx_packusdw(LPackDWordsA, LPackDWordsB), [0, 65535, 42, 32768]);

  LBytesA.mm_u8[0] := 1;
  LBytesA.mm_u8[1] := 2;
  LBytesA.mm_u8[2] := 3;
  LBytesA.mm_u8[3] := 4;
  LBytesA.mm_u8[4] := 5;
  LBytesA.mm_u8[5] := 6;
  LBytesA.mm_u8[6] := 7;
  LBytesA.mm_u8[7] := 8;
  LBytesB.mm_u8[0] := 101;
  LBytesB.mm_u8[1] := 102;
  LBytesB.mm_u8[2] := 103;
  LBytesB.mm_u8[3] := 104;
  LBytesB.mm_u8[4] := 105;
  LBytesB.mm_u8[5] := 106;
  LBytesB.mm_u8[6] := 107;
  LBytesB.mm_u8[7] := 108;
  CheckU8x8('mmx_punpcklbw', mmx_punpcklbw(LBytesA, LBytesB), [1, 101, 2, 102, 3, 103, 4, 104]);
  CheckU8x8('mmx_punpckhbw', mmx_punpckhbw(LBytesA, LBytesB), [5, 105, 6, 106, 7, 107, 8, 108]);

  LBytesMem[0] := 201;
  LBytesMem[1] := 202;
  LBytesMem[2] := 203;
  LBytesMem[3] := 204;
  LBytesMem[4] := 205;
  LBytesMem[5] := 206;
  LBytesMem[6] := 207;
  LBytesMem[7] := 208;
  CheckU8x8('mmx_punpcklbw_mem', mmx_punpcklbw_mem(LBytesA, @LBytesMem[0]), [1, 201, 2, 202, 3, 203, 4, 204]);

  LWordsA.mm_u16[0] := 1;
  LWordsA.mm_u16[1] := 2;
  LWordsA.mm_u16[2] := 3;
  LWordsA.mm_u16[3] := 4;
  LWordsB.mm_u16[0] := 101;
  LWordsB.mm_u16[1] := 102;
  LWordsB.mm_u16[2] := 103;
  LWordsB.mm_u16[3] := 104;
  CheckU16x4('mmx_punpcklwd', mmx_punpcklwd(LWordsA, LWordsB), [1, 101, 2, 102]);
  CheckU16x4('mmx_punpckhwd', mmx_punpckhwd(LWordsA, LWordsB), [3, 103, 4, 104]);

  LWordsMem[0] := 201;
  LWordsMem[1] := 202;
  LWordsMem[2] := 203;
  LWordsMem[3] := 204;
  CheckU16x4('mmx_punpcklwd_mem', mmx_punpcklwd_mem(LWordsA, @LWordsMem[0]), [1, 201, 2, 202]);

  LDWordsA.mm_u32[0] := 1;
  LDWordsA.mm_u32[1] := 2;
  LDWordsB.mm_u32[0] := 101;
  LDWordsB.mm_u32[1] := 102;
  CheckU32x2('mmx_punpckldq', mmx_punpckldq(LDWordsA, LDWordsB), [1, 101]);
  CheckU32x2('mmx_punpckhdq', mmx_punpckhdq(LDWordsA, LDWordsB), [2, 102]);

  LDWordsMem[0] := 201;
  LDWordsMem[1] := 202;
  CheckU32x2('mmx_punpckldq_mem', mmx_punpckldq_mem(LDWordsA, @LDWordsMem[0]), [1, 201]);
  mmx_emms;
end;

begin
  WriteLn('=== MMX Raw Leaf (intrinsics.mmx) Parity Test ===');
  TestSetFamily;
  TestLoadStoreAndMoveFamily;
  TestEmmsCallable;
  TestBitwiseAndCompareFamily;
  TestArithmeticAndSaturatingFamily;
  TestShiftFamily;
  TestPackAndUnpackFamily;

  if GFail = 0 then
  begin
    WriteLn('MMX RAW LEAF PARITY OK: ', GPass, ' checks passed');
    WriteLn('  Set/zero, load/store/movd/movq, bitwise/compare, arithmetic/saturating, shift, pack/unpack, and emms families match the current MMX leaf contract.');
  end
  else
  begin
    WriteLn('MMX RAW LEAF PARITY FAILED: ', GPass, ' passed, ', GFail, ' failed');
    Halt(1);
  end;
end.
