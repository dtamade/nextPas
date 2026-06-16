program test_sse2_raw_leaf_parity;
{$I ../../src/nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Math,
  nextpas.core.simd.intrinsics.base,
  nextpas.core.simd.memutils,
  nextpas.core.simd.intrinsics.x86.sse2;

type
  TSingleArray4 = array[0..3] of Single;
  PSingleArray4 = ^TSingleArray4;
  TDoubleArray2 = array[0..1] of Double;
  PDoubleArray2 = ^TDoubleArray2;
  TByteArray16 = array[0..15] of Byte;
  PByteArray16 = ^TByteArray16;
  PM128 = ^TM128;

const
  MaskTrue64: Int64 = -1;
  MaskFF00FF00: Int32 = -16711936;
  Mask0F0F0F0F: Int32 = $0F0F0F0F;

var
  GPass: Integer = 0;
  GFail: Integer = 0;

procedure CheckF32(const aName: string; aExpected, aActual: Single);
begin
  if Abs(aExpected - aActual) < 1e-6 then Inc(GPass)
  else begin
    WriteLn('FAIL: ', aName, ' expected=', aExpected:0:6, ' got=', aActual:0:6);
    Inc(GFail);
  end;
end;

procedure CheckI32(const aName: string; aExpected, aActual: Int32);
begin
  if aExpected = aActual then Inc(GPass)
  else begin
    WriteLn('FAIL: ', aName, ' expected=', aExpected, ' got=', aActual);
    Inc(GFail);
  end;
end;

procedure CheckI64(const aName: string; aExpected, aActual: Int64);
begin
  if aExpected = aActual then Inc(GPass)
  else begin
    WriteLn('FAIL: ', aName, ' expected=', aExpected, ' got=', aActual);
    Inc(GFail);
  end;
end;

procedure CheckU64(const aName: string; aExpected, aActual: QWord);
begin
  if aExpected = aActual then Inc(GPass)
  else begin
    WriteLn('FAIL: ', aName, ' expected=', aExpected, ' got=', aActual);
    Inc(GFail);
  end;
end;

procedure CheckF64(const aName: string; aExpected, aActual: Double);
begin
  if Abs(aExpected - aActual) < 1e-12 then Inc(GPass)
  else begin
    WriteLn('FAIL: ', aName, ' expected=', aExpected:0:10, ' got=', aActual:0:10);
    Inc(GFail);
  end;
end;

procedure CheckMaskPair64(const aName: string; const aActual: TM128; aExpectedLane0, aExpectedLane1: Int64);
begin
  CheckI64(aName + '[0]', aExpectedLane0, aActual.m128i_i64[0]);
  CheckI64(aName + '[1]', aExpectedLane1, aActual.m128i_i64[1]);
end;

procedure CheckScalarMaskWithHigh(const aName: string; const aActual: TM128; aExpectedMask: Int64; aExpectedHigh: Double);
begin
  CheckI64(aName + '[0]', aExpectedMask, aActual.m128i_i64[0]);
  CheckF64(aName + '[1]', aExpectedHigh, aActual.m128d_f64[1]);
end;

procedure CheckMaskI8x16(const aName: string; const aActual: TM128; const aExpected: array of Integer);
var
  LIndex: Integer;
begin
  if Length(aExpected) <> 16 then
  begin
    WriteLn('FAIL: ', aName, ' expected 16 lanes, got=', Length(aExpected));
    Inc(GFail);
    Exit;
  end;

  for LIndex := 0 to 15 do
    CheckI32(Format('%s[%d]', [aName, LIndex]), aExpected[LIndex], aActual.m128i_i8[LIndex]);
end;

procedure CheckMaskI16x8(const aName: string; const aActual: TM128; const aExpected: array of Integer);
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
    CheckI32(Format('%s[%d]', [aName, LIndex]), aExpected[LIndex], aActual.m128i_i16[LIndex]);
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

procedure CheckBytes16(const aName: string; const aActual: TByteArray16; const aExpected: array of Integer);
var
  LIndex: Integer;
begin
  if Length(aExpected) <> 16 then
  begin
    WriteLn('FAIL: ', aName, ' expected 16 bytes, got=', Length(aExpected));
    Inc(GFail);
    Exit;
  end;

  for LIndex := 0 to 15 do
    CheckI32(Format('%s[%d]', [aName, LIndex]), aExpected[LIndex], aActual[LIndex]);
end;

procedure CheckU8x16(const aName: string; const aActual: TM128; const aExpected: array of Integer);
var
  LIndex: Integer;
begin
  if Length(aExpected) <> 16 then
  begin
    WriteLn('FAIL: ', aName, ' expected 16 lanes, got=', Length(aExpected));
    Inc(GFail);
    Exit;
  end;

  for LIndex := 0 to 15 do
    CheckI32(Format('%s[%d]', [aName, LIndex]), aExpected[LIndex], aActual.m128i_u8[LIndex]);
end;

procedure CheckU16x8(const aName: string; const aActual: TM128; const aExpected: array of Integer);
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
    CheckI32(Format('%s[%d]', [aName, LIndex]), aExpected[LIndex], aActual.m128i_u16[LIndex]);
end;

function U8x16(const aValues: array of Integer): TM128;
var
  LIndex: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  if Length(aValues) <> 16 then
  begin
    WriteLn('FAIL: U8x16 expected 16 lanes, got=', Length(aValues));
    Inc(GFail);
    Exit;
  end;

  for LIndex := 0 to 15 do
  begin
    if (aValues[LIndex] < Low(Byte)) or (aValues[LIndex] > High(Byte)) then
    begin
      WriteLn('FAIL: U8x16 lane out of range at ', LIndex, ': ', aValues[LIndex]);
      Inc(GFail);
      Exit;
    end;
    Result.m128i_u8[LIndex] := Byte(aValues[LIndex]);
  end;
end;

function U16x8(const aValues: array of Integer): TM128;
var
  LIndex: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  if Length(aValues) <> 8 then
  begin
    WriteLn('FAIL: U16x8 expected 8 lanes, got=', Length(aValues));
    Inc(GFail);
    Exit;
  end;

  for LIndex := 0 to 7 do
  begin
    if (aValues[LIndex] < Low(Word)) or (aValues[LIndex] > High(Word)) then
    begin
      WriteLn('FAIL: U16x8 lane out of range at ', LIndex, ': ', aValues[LIndex]);
      Inc(GFail);
      Exit;
    end;
    Result.m128i_u16[LIndex] := Word(aValues[LIndex]);
  end;
end;

function U32x4(const aValues: array of QWord): TM128;
var
  LIndex: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  if Length(aValues) <> 4 then
  begin
    WriteLn('FAIL: U32x4 expected 4 lanes, got=', Length(aValues));
    Inc(GFail);
    Exit;
  end;

  for LIndex := 0 to 3 do
  begin
    if aValues[LIndex] > High(DWord) then
    begin
      WriteLn('FAIL: U32x4 lane out of range at ', LIndex, ': ', aValues[LIndex]);
      Inc(GFail);
      Exit;
    end;
    Result.m128i_u32[LIndex] := DWord(aValues[LIndex]);
  end;
end;

var
  A, B, C: TM128;
  DataF32: array[0..3] of Single;
  DataI32: array[0..3] of Int32;
  DataF64: array[0..1] of Double;
  DataI64: array[0..1] of Int64;
  AlignedF32: PSingleArray4;
  AlignedF64: PDoubleArray2;
  AlignedM128: PM128;
  MaskedBytes: PByteArray16;
  ScalarValue: Double;
begin
  WriteLn('=== SSE2 Raw Leaf (intrinsics.x86.sse2) Parity Test ===');
  WriteLn;

  AlignedF32 := PSingleArray4(AlignedAlloc(SizeOf(TSingleArray4), 16));
  AlignedF64 := PDoubleArray2(AlignedAlloc(SizeOf(TDoubleArray2), 16));
  AlignedM128 := PM128(AlignedAlloc(SizeOf(TM128), 16));
  MaskedBytes := PByteArray16(AlignedAlloc(SizeOf(TByteArray16), 16));
  if (AlignedF32 = nil) or (AlignedF64 = nil) or (AlignedM128 = nil) or (MaskedBytes = nil) then
  begin
    WriteLn('FAIL: aligned storage allocation');
    if AlignedF32 <> nil then
      AlignedFree(AlignedF32);
    if AlignedF64 <> nil then
      AlignedFree(AlignedF64);
    if AlignedM128 <> nil then
      AlignedFree(AlignedM128);
    if MaskedBytes <> nil then
      AlignedFree(MaskedBytes);
    Halt(1);
  end;

  FillChar(AlignedF32^, SizeOf(TSingleArray4), 0);
  FillChar(AlignedF64^, SizeOf(TDoubleArray2), 0);
  FillChar(AlignedM128^, SizeOf(TM128), 0);
  FillChar(MaskedBytes^, SizeOf(TByteArray16), 0);

  // --- Load/Store ---
  DataF32[0] := 1.0; DataF32[1] := 2.0; DataF32[2] := 3.0; DataF32[3] := 4.0;
  A := simd_load_ps(@DataF32[0]);
  CheckF32('load_ps[0]', 1.0, A.m128_f32[0]);
  CheckF32('load_ps[1]', 2.0, A.m128_f32[1]);
  CheckF32('load_ps[2]', 3.0, A.m128_f32[2]);
  CheckF32('load_ps[3]', 4.0, A.m128_f32[3]);

  DataF32[0] := 0; DataF32[1] := 0; DataF32[2] := 0; DataF32[3] := 0;
  simd_storeu_ps(DataF32[0], A);
  CheckF32('storeu_ps[0]', 1.0, DataF32[0]);
  CheckF32('storeu_ps[3]', 4.0, DataF32[3]);

  A := simd_loadu_ps(@DataF32[0]);
  CheckF32('loadu_ps[0]', 1.0, A.m128_f32[0]);
  CheckF32('loadu_ps[3]', 4.0, A.m128_f32[3]);
  B := simd_loadu_ps(@DataF32[0]);
  CheckF32('loadu_ps[1]', 2.0, B.m128_f32[1]);

  simd_store_ps(AlignedF32^[0], A);
  CheckF32('store_ps[0]', 1.0, AlignedF32^[0]);
  CheckF32('store_ps[3]', 4.0, AlignedF32^[3]);
  simd_store_ps(AlignedF32^[0], simd_set1_ps(9.0));
  CheckF32('store_ps fill[2]', 9.0, AlignedF32^[2]);

  A := simd_set1_ps(0.0);
  A.m128_f32[0] := -5.5;
  A.m128_f32[1] := 0.25;
  A.m128_f32[2] := 8.75;
  A.m128_f32[3] := -9.5;
  simd_storeu_ps(DataF32[0], A);
  CheckF32('storeu_ps second[0]', -5.5, DataF32[0]);
  CheckF32('storeu_ps second[1]', 0.25, DataF32[1]);
  CheckF32('storeu_ps second[2]', 8.75, DataF32[2]);
  CheckF32('storeu_ps second[3]', -9.5, DataF32[3]);

  A := simd_setr_epi32(11, -22, 33, High(Int32));
  simd_store_si128(AlignedM128^, A);
  B := simd_loadu_si128(AlignedM128);
  CheckMaskI32x4('store_si128 first', B, [11, -22, 33, High(Int32)]);

  A := simd_setr_epi32(Low(Int32), 0, -1, 123456789);
  simd_store_si128(AlignedM128^, A);
  B := simd_loadu_si128(AlignedM128);
  CheckMaskI32x4('store_si128 second', B, [Low(Int32), 0, -1, 123456789]);

  AlignedF64^[0] := 10.0;
  AlignedF64^[1] := 20.0;
  A := simd_load_pd(@AlignedF64^[0]);
  simd_stream_pd(AlignedM128^.m128d_f64[0], A);
  CheckF64('stream_pd first[0]', 10.0, AlignedM128^.m128d_f64[0]);
  CheckF64('stream_pd first[1]', 20.0, AlignedM128^.m128d_f64[1]);

  AlignedF64^[0] := -8.25;
  AlignedF64^[1] := 4.5;
  B := simd_load_pd(@AlignedF64^[0]);
  simd_stream_pd(AlignedM128^.m128d_f64[0], B);
  CheckF64('stream_pd second[0]', -8.25, AlignedM128^.m128d_f64[0]);
  CheckF64('stream_pd second[1]', 4.5, AlignedM128^.m128d_f64[1]);

  AlignedF32^[0] := 10.5;
  AlignedF32^[1] := -2.25;
  AlignedF32^[2] := 0.0;
  AlignedF32^[3] := 99.75;
  A := simd_load_ps(@AlignedF32^[0]);
  simd_stream_ps(AlignedM128^.m128_f32[0], A);
  CheckF32('stream_ps first[0]', 10.5, AlignedM128^.m128_f32[0]);
  CheckF32('stream_ps first[1]', -2.25, AlignedM128^.m128_f32[1]);
  CheckF32('stream_ps first[2]', 0.0, AlignedM128^.m128_f32[2]);
  CheckF32('stream_ps first[3]', 99.75, AlignedM128^.m128_f32[3]);

  AlignedF32^[0] := -1.0;
  AlignedF32^[1] := -2.0;
  AlignedF32^[2] := -3.0;
  AlignedF32^[3] := -4.0;
  B := simd_load_ps(@AlignedF32^[0]);
  simd_stream_ps(AlignedM128^.m128_f32[0], B);
  CheckF32('stream_ps second[0]', -1.0, AlignedM128^.m128_f32[0]);
  CheckF32('stream_ps second[1]', -2.0, AlignedM128^.m128_f32[1]);
  CheckF32('stream_ps second[2]', -3.0, AlignedM128^.m128_f32[2]);
  CheckF32('stream_ps second[3]', -4.0, AlignedM128^.m128_f32[3]);

  A := simd_setr_epi32(1, -2, 3, -4);
  simd_stream_si128(AlignedM128^, A);
  B := simd_loadu_si128(AlignedM128);
  CheckMaskI32x4('stream_si128 first', B, [1, -2, 3, -4]);

  A := simd_setr_epi32(Int32($11223344), Int32($55667788), -1, 0);
  simd_stream_si128(AlignedM128^, A);
  B := simd_loadu_si128(AlignedM128);
  CheckMaskI32x4('stream_si128 second', B, [Int32($11223344), Int32($55667788), -1, 0]);

  DataI32[0] := -1;
  DataI32[1] := 777;
  DataI32[2] := -1;
  DataI32[3] := 888;
  simd_stream_si32(DataI32[0], 123456789);
  CheckI32('stream_si32 first[0]', 123456789, DataI32[0]);
  CheckI32('stream_si32 first[1]', 777, DataI32[1]);

  simd_stream_si32(DataI32[2], Low(Int32));
  CheckI32('stream_si32 second[2]', Low(Int32), DataI32[2]);
  CheckI32('stream_si32 second[3]', 888, DataI32[3]);

  DataI64[0] := 333;
  DataI64[1] := 444;
  simd_stream_si64(DataI64[0], Int64($1122334455667788));
  CheckI64('stream_si64 first[0]', Int64($1122334455667788), DataI64[0]);
  CheckI64('stream_si64 first[1]', 444, DataI64[1]);

  DataI64[0] := 333;
  DataI64[1] := 444;
  simd_stream_si64(DataI64[1], -1234567890123456789);
  CheckI64('stream_si64 second[0]', 333, DataI64[0]);
  CheckI64('stream_si64 second[1]', -1234567890123456789, DataI64[1]);

  FillChar(MaskedBytes^, SizeOf(TByteArray16), $55);
  A := U8x16([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]);
  B := U8x16([$80, 0, $80, 0, $80, 0, $80, 0, $80, 0, $80, 0, $80, 0, $80, 0]);
  simd_maskmoveu_si128(A, B, MaskedBytes^[0]);
  CheckBytes16('maskmoveu_si128 first', MaskedBytes^, [1, $55, 3, $55, 5, $55, 7, $55, 9, $55, 11, $55, 13, $55, 15, $55]);

  FillChar(MaskedBytes^, SizeOf(TByteArray16), $AA);
  A := U8x16([200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215]);
  B := U8x16([0, $80, $80, 0, 0, $80, 0, $80, $80, 0, $80, 0, $80, 0, 0, $80]);
  simd_maskmoveu_si128(A, B, MaskedBytes^[0]);
  CheckBytes16('maskmoveu_si128 second', MaskedBytes^, [$AA, 201, 202, $AA, $AA, 205, $AA, 207, 208, $AA, 210, $AA, 212, $AA, $AA, 215]);

  // --- Control Ops ---
  // These checks only prove wrapper callability and explicit memory preservation
  // on the host; they do not claim to prove cross-thread ordering strength.
  DataI32[0] := 41;
  simd_pause;
  Inc(DataI32[0]);
  CheckI32('pause first', 42, DataI32[0]);

  DataI32[1] := -5;
  simd_pause;
  Dec(DataI32[1]);
  CheckI32('pause second', -6, DataI32[1]);

  DataI32[0] := 101;
  DataI32[1] := -202;
  DataI32[2] := 303;
  DataI32[3] := -404;
  simd_lfence;
  A := simd_loadu_si128(@DataI32[0]);
  CheckMaskI32x4('lfence first', A, [101, -202, 303, -404]);

  AlignedF64^[0] := 1.25;
  AlignedF64^[1] := -9.5;
  simd_lfence;
  B := simd_load_pd(@AlignedF64^[0]);
  CheckF64('lfence second[0]', 1.25, B.m128d_f64[0]);
  CheckF64('lfence second[1]', -9.5, B.m128d_f64[1]);

  A := simd_setr_epi32(700, -800, 900, -1000);
  simd_storeu_si128(DataI32[0], A);
  simd_mfence;
  B := simd_loadu_si128(@DataI32[0]);
  CheckMaskI32x4('mfence first', B, [700, -800, 900, -1000]);

  A := simd_setr_epi32(7, 8, 9, 10);
  simd_stream_si128(AlignedM128^, A);
  simd_mfence;
  B := simd_loadu_si128(AlignedM128);
  CheckMaskI32x4('mfence second', B, [7, 8, 9, 10]);

  DataI32[0] := Int32($12345678);
  DataI32[1] := Int32($90ABCDEF);
  simd_clflush(@DataI32[0]);
  CheckI32('clflush first[0]', Int32($12345678), DataI32[0]);
  CheckI32('clflush first[1]', Int32($90ABCDEF), DataI32[1]);

  FillChar(MaskedBytes^, SizeOf(TByteArray16), $5A);
  simd_clflush(@MaskedBytes^[0]);
  CheckBytes16('clflush second', MaskedBytes^, [$5A, $5A, $5A, $5A, $5A, $5A, $5A, $5A, $5A, $5A, $5A, $5A, $5A, $5A, $5A, $5A]);

  // --- Set/Zero ---
  A := simd_setzero_si128;
  CheckI32('setzero_si128[0]', 0, A.m128i_i32[0]);
  CheckI32('setzero_si128[3]', 0, A.m128i_i32[3]);
  B := simd_setzero_si128;
  CheckI32('setzero_si128[1]', 0, B.m128i_i32[1]);

  A := simd_setzero_pd;
  CheckF64('setzero_pd[0]', 0.0, A.m128d_f64[0]);
  CheckF64('setzero_pd[1]', 0.0, A.m128d_f64[1]);
  B := simd_setzero_pd;
  CheckF64('setzero_pd repeat[1]', 0.0, B.m128d_f64[1]);

  A := simd_setzero_ps;
  CheckF32('setzero_ps[0]', 0.0, A.m128_f32[0]);
  CheckF32('setzero_ps[3]', 0.0, A.m128_f32[3]);

  A := simd_set1_ps(3.14);
  CheckF32('set1_ps[0]', 3.14, A.m128_f32[0]);
  CheckF32('set1_ps[2]', 3.14, A.m128_f32[2]);

  A := simd_set1_epi32(42);
  CheckI32('set1_epi32[0]', 42, A.m128i_i32[0]);
  CheckI32('set1_epi32[3]', 42, A.m128i_i32[3]);

  A := simd_set_epi16(8, 7, 6, 5, 4, 3, 2, 1);
  CheckI32('set_epi16[0]', 1, A.m128i_i16[0]);
  CheckI32('set_epi16[7]', 8, A.m128i_i16[7]);
  B := simd_set_epi16(-1, -2, -3, -4, -5, -6, -7, -8);
  CheckI32('set_epi16 neg[0]', -8, B.m128i_i16[0]);
  CheckI32('set_epi16 neg[7]', -1, B.m128i_i16[7]);

  A := simd_setr_epi16(1, 2, 3, 4, 5, 6, 7, 8);
  CheckI32('setr_epi16[0]', 1, A.m128i_i16[0]);
  CheckI32('setr_epi16[7]', 8, A.m128i_i16[7]);
  B := simd_setr_epi16(-8, -7, -6, -5, -4, -3, -2, -1);
  CheckI32('setr_epi16 neg[0]', -8, B.m128i_i16[0]);
  CheckI32('setr_epi16 neg[7]', -1, B.m128i_i16[7]);

  A := simd_set_epi8(16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1);
  CheckI32('set_epi8[0]', 1, A.m128i_i8[0]);
  CheckI32('set_epi8[15]', 16, A.m128i_i8[15]);
  B := simd_set_epi8(-1, -2, -3, -4, -5, -6, -7, -8, -9, -10, -11, -12, -13, -14, -15, -16);
  CheckI32('set_epi8 neg[0]', -16, B.m128i_i8[0]);
  CheckI32('set_epi8 neg[15]', -1, B.m128i_i8[15]);

  A := simd_setr_epi8(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
  CheckI32('setr_epi8[0]', 1, A.m128i_i8[0]);
  CheckI32('setr_epi8[15]', 16, A.m128i_i8[15]);
  B := simd_setr_epi8(-16, -15, -14, -13, -12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1);
  CheckI32('setr_epi8 neg[0]', -16, B.m128i_i8[0]);
  CheckI32('setr_epi8 neg[15]', -1, B.m128i_i8[15]);

  A := simd_set_epi64(22, 11);
  CheckI64('set_epi64[0]', 11, A.m128i_i64[0]);
  CheckI64('set_epi64[1]', 22, A.m128i_i64[1]);
  B := simd_set_epi64(-22, -11);
  CheckI64('set_epi64 neg[0]', -11, B.m128i_i64[0]);
  CheckI64('set_epi64 neg[1]', -22, B.m128i_i64[1]);

  A := simd_setr_epi64(11, 22);
  CheckI64('setr_epi64[0]', 11, A.m128i_i64[0]);
  CheckI64('setr_epi64[1]', 22, A.m128i_i64[1]);
  B := simd_setr_epi64(-11, -22);
  CheckI64('setr_epi64 neg[0]', -11, B.m128i_i64[0]);
  CheckI64('setr_epi64 neg[1]', -22, B.m128i_i64[1]);

  // --- Arithmetic (F32) ---
  A := simd_set1_ps(3.0);
  B := simd_set1_ps(2.0);
  C := simd_add_ps(A, B);
  CheckF32('add_ps', 5.0, C.m128_f32[0]);

  C := simd_sub_ps(A, B);
  CheckF32('sub_ps', 1.0, C.m128_f32[0]);

  DataF32[0] := 10.0; DataF32[1] := -9.0; DataF32[2] := 6.0; DataF32[3] := -16.0;
  A := simd_loadu_ps(@DataF32[0]);
  AlignedF32^[0] := 4.0; AlignedF32^[1] := -3.0; AlignedF32^[2] := -2.0; AlignedF32^[3] := 4.0;
  B := simd_load_ps(@AlignedF32^[0]);
  C := simd_sub_ps(A, B);
  CheckF32('sub_ps second[0]', 6.0, C.m128_f32[0]);
  CheckF32('sub_ps second[1]', -6.0, C.m128_f32[1]);
  CheckF32('sub_ps second[2]', 8.0, C.m128_f32[2]);
  CheckF32('sub_ps second[3]', -20.0, C.m128_f32[3]);

  A := simd_set1_ps(3.0);
  B := simd_set1_ps(2.0);
  C := simd_mul_ps(A, B);
  CheckF32('mul_ps', 6.0, C.m128_f32[0]);

  A := simd_set1_ps(3.0);
  B := simd_set1_ps(2.0);
  C := simd_div_ps(A, B);
  CheckF32('div_ps', 1.5, C.m128_f32[0]);

  DataF32[0] := 8.0; DataF32[1] := -9.0; DataF32[2] := 7.5; DataF32[3] := -16.0;
  A := simd_loadu_ps(@DataF32[0]);
  AlignedF32^[0] := 2.0; AlignedF32^[1] := -3.0; AlignedF32^[2] := 0.5; AlignedF32^[3] := 4.0;
  B := simd_load_ps(@AlignedF32^[0]);
  C := simd_div_ps(A, B);
  CheckF32('div_ps second[0]', 4.0, C.m128_f32[0]);
  CheckF32('div_ps second[1]', 3.0, C.m128_f32[1]);
  CheckF32('div_ps second[2]', 15.0, C.m128_f32[2]);
  CheckF32('div_ps second[3]', -4.0, C.m128_f32[3]);

  // --- Arithmetic (F64) ---
  DataF64[0] := 10.0; DataF64[1] := 20.0;
  A := simd_load_pd(@DataF64[0]);
  CheckF64('load_pd[0]', 10.0, A.m128d_f64[0]);
  CheckF64('load_pd[1]', 20.0, A.m128d_f64[1]);

  A := simd_loadu_pd(@DataF64[0]);
  CheckF64('loadu_pd[0]', 10.0, A.m128d_f64[0]);
  CheckF64('loadu_pd[1]', 20.0, A.m128d_f64[1]);
  B := simd_loadu_pd(@DataF64[0]);
  CheckF64('loadu_pd repeat[1]', 20.0, B.m128d_f64[1]);

  simd_store_pd(AlignedF64^[0], A);
  CheckF64('store_pd[0]', 10.0, AlignedF64^[0]);
  CheckF64('store_pd[1]', 20.0, AlignedF64^[1]);
  simd_store_pd(AlignedF64^[0], simd_set1_pd(-3.5));
  CheckF64('store_pd fill[1]', -3.5, AlignedF64^[1]);

  AlignedF64^[0] := 0.0;
  AlignedF64^[1] := 0.0;
  simd_storeu_pd(AlignedF64^[0], A);
  CheckF64('storeu_pd[0]', 10.0, AlignedF64^[0]);
  CheckF64('storeu_pd[1]', 20.0, AlignedF64^[1]);
  simd_storeu_pd(AlignedF64^[0], simd_set_pd(7.0, 6.0));
  CheckF64('storeu_pd fill[0]', 6.0, AlignedF64^[0]);

  ScalarValue := 99.0;
  B := simd_load_sd(@ScalarValue);
  CheckF64('load_sd[0]', 99.0, B.m128d_f64[0]);
  CheckF64('load_sd[1]', 0.0, B.m128d_f64[1]);
  ScalarValue := -12.5;
  C := simd_load_sd(@ScalarValue);
  CheckF64('load_sd neg[0]', -12.5, C.m128d_f64[0]);

  ScalarValue := 0.0;
  simd_store_sd(ScalarValue, A);
  CheckF64('store_sd', 10.0, ScalarValue);
  ScalarValue := 0.0;
  simd_store_sd(ScalarValue, simd_set_pd(42.0, -8.0));
  CheckF64('store_sd neg', -8.0, ScalarValue);

  ScalarValue := 77.0;
  C := simd_loadh_pd(A, @ScalarValue);
  CheckF64('loadh_pd[0]', 10.0, C.m128d_f64[0]);
  CheckF64('loadh_pd[1]', 77.0, C.m128d_f64[1]);
  ScalarValue := -33.0;
  B := simd_loadh_pd(simd_set_pd(4.0, 2.0), @ScalarValue);
  CheckF64('loadh_pd neg[1]', -33.0, B.m128d_f64[1]);

  ScalarValue := 55.0;
  C := simd_loadl_pd(A, @ScalarValue);
  CheckF64('loadl_pd[0]', 55.0, C.m128d_f64[0]);
  CheckF64('loadl_pd[1]', 20.0, C.m128d_f64[1]);
  ScalarValue := -44.0;
  B := simd_loadl_pd(simd_set_pd(9.0, 3.0), @ScalarValue);
  CheckF64('loadl_pd neg[0]', -44.0, B.m128d_f64[0]);

  ScalarValue := 0.0;
  simd_storeh_pd(ScalarValue, A);
  CheckF64('storeh_pd', 20.0, ScalarValue);
  ScalarValue := 0.0;
  simd_storeh_pd(ScalarValue, simd_set_pd(-6.0, 4.0));
  CheckF64('storeh_pd neg', -6.0, ScalarValue);

  ScalarValue := 0.0;
  simd_storel_pd(ScalarValue, A);
  CheckF64('storel_pd', 10.0, ScalarValue);
  ScalarValue := 0.0;
  simd_storel_pd(ScalarValue, simd_set_pd(-6.0, 4.0));
  CheckF64('storel_pd pos', 4.0, ScalarValue);

  C := simd_loadr_pd(@DataF64[0]);
  CheckF64('loadr_pd[0]', 20.0, C.m128d_f64[0]);
  CheckF64('loadr_pd[1]', 10.0, C.m128d_f64[1]);
  B := simd_loadr_pd(@DataF64[0]);
  CheckF64('loadr_pd repeat[1]', 10.0, B.m128d_f64[1]);

  AlignedF64^[0] := 0.0;
  AlignedF64^[1] := 0.0;
  simd_storer_pd(AlignedF64^[0], A);
  CheckF64('storer_pd[0]', 20.0, AlignedF64^[0]);
  CheckF64('storer_pd[1]', 10.0, AlignedF64^[1]);
  simd_storer_pd(AlignedF64^[0], simd_set_pd(-1.0, -2.0));
  CheckF64('storer_pd neg[0]', -1.0, AlignedF64^[0]);

  B := simd_set1_pd(5.0);
  C := simd_add_pd(A, B);
  CheckF64('add_pd[0]', 15.0, C.m128d_f64[0]);
  CheckF64('add_pd[1]', 25.0, C.m128d_f64[1]);

  A := simd_set_pd(-4.0, 1.5);
  B := simd_set_pd(6.0, -2.5);
  C := simd_add_pd(A, B);
  CheckF64('add_pd neg[0]', -1.0, C.m128d_f64[0]);
  CheckF64('add_pd neg[1]', 2.0, C.m128d_f64[1]);

  C := simd_sub_pd(A, B);
  CheckF64('sub_pd[0]', 4.0, C.m128d_f64[0]);
  CheckF64('sub_pd[1]', -10.0, C.m128d_f64[1]);

  A := simd_set_pd(7.0, -8.0);
  B := simd_set_pd(-2.0, 5.0);
  C := simd_sub_pd(A, B);
  CheckF64('sub_pd second[0]', -13.0, C.m128d_f64[0]);
  CheckF64('sub_pd second[1]', 9.0, C.m128d_f64[1]);

  C := simd_mul_pd(A, B);
  CheckF64('mul_pd[0]', -40.0, C.m128d_f64[0]);
  CheckF64('mul_pd[1]', -14.0, C.m128d_f64[1]);

  A := simd_set_pd(10.0, 9.0);
  B := simd_set_pd(2.0, -3.0);
  C := simd_div_pd(A, B);
  CheckF64('div_pd[0]', -3.0, C.m128d_f64[0]);
  CheckF64('div_pd[1]', 5.0, C.m128d_f64[1]);

  A := simd_set_pd(-8.0, 12.0);
  B := simd_set_pd(-2.0, 4.0);
  C := simd_div_pd(A, B);
  CheckF64('div_pd second[0]', 3.0, C.m128d_f64[0]);
  CheckF64('div_pd second[1]', 4.0, C.m128d_f64[1]);

  A := simd_set_pd(-1.0, -4.0);
  B := simd_set_pd(2.0, -3.0);
  C := simd_mul_pd(A, B);
  CheckF64('mul_pd second[0]', 12.0, C.m128d_f64[0]);
  CheckF64('mul_pd second[1]', -2.0, C.m128d_f64[1]);

  C := simd_max_pd(A, B);
  CheckF64('max_pd second[0]', -3.0, C.m128d_f64[0]);
  CheckF64('max_pd second[1]', 2.0, C.m128d_f64[1]);

  C := simd_min_pd(A, B);
  CheckF64('min_pd second[0]', -4.0, C.m128d_f64[0]);
  CheckF64('min_pd second[1]', -1.0, C.m128d_f64[1]);

  A := simd_set_pd(81.0, 0.25);
  C := simd_sqrt_pd(A);
  CheckF64('sqrt_pd second[0]', 0.5, C.m128d_f64[0]);
  CheckF64('sqrt_pd second[1]', 9.0, C.m128d_f64[1]);

  A := simd_set_epi64(Int64($3333333333333333), Int64($0F0F0F0F0F0F0F0F));
  B := simd_set_epi64(Int64($5555555555555555), Int64($00FF00FF00FF00FF));
  C := simd_and_pd(A, B);
  CheckI64('and_pd[0]', Int64($000F000F000F000F), C.m128i_i64[0]);
  CheckI64('and_pd[1]', Int64($1111111111111111), C.m128i_i64[1]);

  C := simd_and_pd(B, B);
  CheckI64('and_pd second[0]', Int64($00FF00FF00FF00FF), C.m128i_i64[0]);
  CheckI64('and_pd second[1]', Int64($5555555555555555), C.m128i_i64[1]);

  C := simd_or_pd(A, B);
  CheckI64('or_pd[0]', Int64($0FFF0FFF0FFF0FFF), C.m128i_i64[0]);
  CheckI64('or_pd[1]', Int64($7777777777777777), C.m128i_i64[1]);

  C := simd_or_pd(A, A);
  CheckI64('or_pd second[0]', Int64($0F0F0F0F0F0F0F0F), C.m128i_i64[0]);
  CheckI64('or_pd second[1]', Int64($3333333333333333), C.m128i_i64[1]);

  C := simd_xor_pd(A, B);
  CheckI64('xor_pd[0]', Int64($0FF00FF00FF00FF0), C.m128i_i64[0]);
  CheckI64('xor_pd[1]', Int64($6666666666666666), C.m128i_i64[1]);

  C := simd_xor_pd(B, B);
  CheckI64('xor_pd second[0]', 0, C.m128i_i64[0]);
  CheckI64('xor_pd second[1]', 0, C.m128i_i64[1]);

  C := simd_andnot_pd(A, B);
  CheckI64('andnot_pd[0]', Int64($00F000F000F000F0), C.m128i_i64[0]);
  CheckI64('andnot_pd[1]', Int64($4444444444444444), C.m128i_i64[1]);

  C := simd_andnot_pd(B, A);
  CheckI64('andnot_pd second[0]', Int64($0F000F000F000F00), C.m128i_i64[0]);
  CheckI64('andnot_pd second[1]', Int64($2222222222222222), C.m128i_i64[1]);

  A := simd_set_pd(40.0, 10.0);
  B := simd_set_pd(50.0, 20.0);
  C := simd_shuffle_pd(A, B, 0);
  CheckF64('shuffle_pd[0]', 10.0, C.m128d_f64[0]);
  CheckF64('shuffle_pd[1]', 20.0, C.m128d_f64[1]);

  C := simd_shuffle_pd(A, B, 3);
  CheckF64('shuffle_pd high[0]', 40.0, C.m128d_f64[0]);
  CheckF64('shuffle_pd high[1]', 50.0, C.m128d_f64[1]);

  C := simd_unpacklo_pd(A, B);
  CheckF64('unpacklo_pd[0]', 10.0, C.m128d_f64[0]);
  CheckF64('unpacklo_pd[1]', 20.0, C.m128d_f64[1]);

  A := simd_set_pd(-1.0, -2.0);
  B := simd_set_pd(-3.0, -4.0);
  C := simd_unpacklo_pd(A, B);
  CheckF64('unpacklo_pd second[0]', -2.0, C.m128d_f64[0]);
  CheckF64('unpacklo_pd second[1]', -4.0, C.m128d_f64[1]);

  C := simd_unpackhi_pd(A, B);
  CheckF64('unpackhi_pd[0]', -1.0, C.m128d_f64[0]);
  CheckF64('unpackhi_pd[1]', -3.0, C.m128d_f64[1]);

  A := simd_set_pd(40.0, 10.0);
  B := simd_set_pd(50.0, 20.0);
  C := simd_unpackhi_pd(A, B);
  CheckF64('unpackhi_pd second[0]', 40.0, C.m128d_f64[0]);
  CheckF64('unpackhi_pd second[1]', 50.0, C.m128d_f64[1]);

  // --- Integer Arithmetic ---
  A := simd_set1_epi32(10);
  B := simd_set1_epi32(3);
  C := simd_add_epi32(A, B);
  CheckI32('add_epi32', 13, C.m128i_i32[0]);

  C := simd_sub_epi32(A, B);
  CheckI32('sub_epi32', 7, C.m128i_i32[0]);

  // --- Bitwise ---
  DataI32[0] := MaskFF00FF00; DataI32[1] := MaskFF00FF00; DataI32[2] := MaskFF00FF00; DataI32[3] := MaskFF00FF00;
  A := simd_load_si128(@DataI32[0]);
  DataI32[0] := Mask0F0F0F0F; DataI32[1] := Mask0F0F0F0F; DataI32[2] := Mask0F0F0F0F; DataI32[3] := Mask0F0F0F0F;
  B := simd_load_si128(@DataI32[0]);

  C := simd_and_si128(A, B);
  CheckI32('and_si128', Int32($0F000F00), C.m128i_i32[0]);

  A := simd_setr_epi32(Int32($F0F0F0F0), Int32($12345678), Int32($AAAAAAAA), Int32($0F0F0F0F));
  B := simd_setr_epi32(Int32($0FF00FF0), Int32($00FF00FF), Int32($55550000), Int32($33330000));
  C := simd_and_si128(A, B);
  CheckI32('and_si128 second[0]', Int32($00F000F0), C.m128i_i32[0]);
  CheckI32('and_si128 second[1]', Int32($00340078), C.m128i_i32[1]);
  CheckI32('and_si128 second[2]', 0, C.m128i_i32[2]);
  CheckI32('and_si128 second[3]', Int32($03030000), C.m128i_i32[3]);

  DataI32[0] := MaskFF00FF00; DataI32[1] := MaskFF00FF00; DataI32[2] := MaskFF00FF00; DataI32[3] := MaskFF00FF00;
  A := simd_load_si128(@DataI32[0]);
  DataI32[0] := Mask0F0F0F0F; DataI32[1] := Mask0F0F0F0F; DataI32[2] := Mask0F0F0F0F; DataI32[3] := Mask0F0F0F0F;
  B := simd_load_si128(@DataI32[0]);
  C := simd_or_si128(A, B);
  CheckI32('or_si128', Int32($FF0FFF0F), C.m128i_i32[0]);

  A := simd_setr_epi32(Int32($F0F0F0F0), Int32($12345678), Int32($AAAAAAAA), Int32($0F0F0F0F));
  B := simd_setr_epi32(Int32($0FF00FF0), Int32($00FF00FF), Int32($55550000), Int32($33330000));
  C := simd_or_si128(A, B);
  CheckI32('or_si128 second[0]', Int32($FFF0FFF0), C.m128i_i32[0]);
  CheckI32('or_si128 second[1]', Int32($12FF56FF), C.m128i_i32[1]);
  CheckI32('or_si128 second[2]', Int32($FFFFAAAA), C.m128i_i32[2]);
  CheckI32('or_si128 second[3]', Int32($3F3F0F0F), C.m128i_i32[3]);

  DataI32[0] := MaskFF00FF00; DataI32[1] := MaskFF00FF00; DataI32[2] := MaskFF00FF00; DataI32[3] := MaskFF00FF00;
  A := simd_load_si128(@DataI32[0]);
  DataI32[0] := Mask0F0F0F0F; DataI32[1] := Mask0F0F0F0F; DataI32[2] := Mask0F0F0F0F; DataI32[3] := Mask0F0F0F0F;
  B := simd_load_si128(@DataI32[0]);
  C := simd_xor_si128(A, B);
  CheckI32('xor_si128', Int32($F00FF00F), C.m128i_i32[0]);

  // --- Shift ---
  A := simd_set1_epi32(8);
  C := simd_slli_epi32(A, 2);
  CheckI32('slli_epi32', 32, C.m128i_i32[0]);

  C := simd_srli_epi32(A, 1);
  CheckI32('srli_epi32', 4, C.m128i_i32[0]);

  A := simd_setr_epi16(1, 2, 3, 4, 5, 6, 7, 8);
  C := simd_slli_epi16(A, 1);
  CheckI32('slli_epi16[0]', 2, C.m128i_i16[0]);
  CheckI32('slli_epi16[1]', 4, C.m128i_i16[1]);
  CheckI32('slli_epi16[2]', 6, C.m128i_i16[2]);
  CheckI32('slli_epi16[3]', 8, C.m128i_i16[3]);
  CheckI32('slli_epi16[4]', 10, C.m128i_i16[4]);
  CheckI32('slli_epi16[5]', 12, C.m128i_i16[5]);
  CheckI32('slli_epi16[6]', 14, C.m128i_i16[6]);
  CheckI32('slli_epi16[7]', 16, C.m128i_i16[7]);

  C := simd_slli_epi16(A, 16);
  CheckI32('slli_epi16 shift16[0]', 0, C.m128i_i16[0]);
  CheckI32('slli_epi16 shift16[7]', 0, C.m128i_i16[7]);

  A := simd_setr_epi64(1, 2);
  C := simd_slli_epi64(A, 4);
  CheckI64('slli_epi64[0]', 16, C.m128i_i64[0]);
  CheckI64('slli_epi64[1]', 32, C.m128i_i64[1]);

  C := simd_slli_epi64(A, 64);
  CheckI64('slli_epi64 shift64[0]', 0, C.m128i_i64[0]);
  CheckI64('slli_epi64 shift64[1]', 0, C.m128i_i64[1]);

  A := simd_setr_epi16(-1, -32768, 16384, 1, 2, 4, 8, 16);
  C := simd_srli_epi16(A, 1);
  CheckI32('srli_epi16[0]', 32767, C.m128i_u16[0]);
  CheckI32('srli_epi16[1]', 16384, C.m128i_u16[1]);
  CheckI32('srli_epi16[2]', 8192, C.m128i_u16[2]);
  CheckI32('srli_epi16[3]', 0, C.m128i_u16[3]);
  CheckI32('srli_epi16[4]', 1, C.m128i_u16[4]);
  CheckI32('srli_epi16[5]', 2, C.m128i_u16[5]);
  CheckI32('srli_epi16[6]', 4, C.m128i_u16[6]);
  CheckI32('srli_epi16[7]', 8, C.m128i_u16[7]);

  C := simd_srli_epi16(A, 16);
  CheckI32('srli_epi16 shift16[0]', 0, C.m128i_u16[0]);
  CheckI32('srli_epi16 shift16[7]', 0, C.m128i_u16[7]);

  A := simd_setr_epi64(-1, Int64($8000000000000000));
  C := simd_srli_epi64(A, 4);
  CheckI64('srli_epi64[0]', Int64($0FFFFFFFFFFFFFFF), C.m128i_i64[0]);
  CheckI64('srli_epi64[1]', Int64($0800000000000000), C.m128i_i64[1]);

  C := simd_srli_epi64(A, 64);
  CheckI64('srli_epi64 shift64[0]', 0, C.m128i_i64[0]);
  CheckI64('srli_epi64 shift64[1]', 0, C.m128i_i64[1]);

  A := simd_setr_epi16(-32768, -2, 2, 32767, -1, 256, -256, 0);
  C := simd_srai_epi16(A, 1);
  CheckI32('srai_epi16[0]', -16384, C.m128i_i16[0]);
  CheckI32('srai_epi16[1]', -1, C.m128i_i16[1]);
  CheckI32('srai_epi16[2]', 1, C.m128i_i16[2]);
  CheckI32('srai_epi16[3]', 16383, C.m128i_i16[3]);
  CheckI32('srai_epi16[4]', -1, C.m128i_i16[4]);
  CheckI32('srai_epi16[5]', 128, C.m128i_i16[5]);
  CheckI32('srai_epi16[6]', -128, C.m128i_i16[6]);
  CheckI32('srai_epi16[7]', 0, C.m128i_i16[7]);

  C := simd_srai_epi16(A, 16);
  CheckI32('srai_epi16 shift16[0]', -1, C.m128i_i16[0]);
  CheckI32('srai_epi16 shift16[1]', -1, C.m128i_i16[1]);
  CheckI32('srai_epi16 shift16[2]', 0, C.m128i_i16[2]);
  CheckI32('srai_epi16 shift16[3]', 0, C.m128i_i16[3]);

  A := simd_setr_epi32(Int32($80000000), -2, 2, Int32($7FFFFFFF));
  C := simd_srai_epi32(A, 1);
  CheckI32('srai_epi32[0]', Int32($C0000000), C.m128i_i32[0]);
  CheckI32('srai_epi32[1]', -1, C.m128i_i32[1]);
  CheckI32('srai_epi32[2]', 1, C.m128i_i32[2]);
  CheckI32('srai_epi32[3]', Int32($3FFFFFFF), C.m128i_i32[3]);

  C := simd_srai_epi32(A, 32);
  CheckI32('srai_epi32 shift32[0]', -1, C.m128i_i32[0]);
  CheckI32('srai_epi32 shift32[1]', -1, C.m128i_i32[1]);
  CheckI32('srai_epi32 shift32[2]', 0, C.m128i_i32[2]);
  CheckI32('srai_epi32 shift32[3]', 0, C.m128i_i32[3]);

  A := simd_setr_epi8(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
  C := simd_slli_si128(A, 1);
  CheckI64('slli_si128[0]', Int64($0706050403020100), C.m128i_i64[0]);
  CheckI64('slli_si128[1]', Int64($0F0E0D0C0B0A0908), C.m128i_i64[1]);

  C := simd_slli_si128(A, 16);
  CheckI64('slli_si128 shift16[0]', 0, C.m128i_i64[0]);
  CheckI64('slli_si128 shift16[1]', 0, C.m128i_i64[1]);

  A := simd_setr_epi8(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
  C := simd_srli_si128(A, 1);
  CheckI64('srli_si128[0]', Int64($0908070605040302), C.m128i_i64[0]);
  CheckI64('srli_si128[1]', Int64($00100F0E0D0C0B0A), C.m128i_i64[1]);

  C := simd_srli_si128(A, 16);
  CheckI64('srli_si128 shift16[0]', 0, C.m128i_i64[0]);
  CheckI64('srli_si128 shift16[1]', 0, C.m128i_i64[1]);

  A := simd_setr_epi8(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, ShortInt($80));
  C := simd_srai_si128(A, 1);
  CheckI64('srai_si128[0]', Int64($0908070605040302), C.m128i_i64[0]);
  CheckI64('srai_si128[1]', Int64($FF800F0E0D0C0B0A), C.m128i_i64[1]);

  C := simd_srai_si128(A, 16);
  CheckI64('srai_si128 shift16[0]', -1, C.m128i_i64[0]);
  CheckI64('srai_si128 shift16[1]', -1, C.m128i_i64[1]);

  A := simd_set1_epi32(Int32($80000000));
  C := simd_srli_epi32(A, 31);
  CheckI32('srli_epi32 shift31', 1, C.m128i_i32[0]);

  // --- Compare ---
  A := simd_set1_epi32(5);
  B := simd_set1_epi32(5);
  C := simd_cmpeq_epi32(A, B);
  CheckI32('cmpeq_epi32 (equal)', Int32($FFFFFFFF), C.m128i_i32[0]);

  A := simd_setr_epi32(5, -1, 0, 42);
  B := simd_setr_epi32(5, 7, 0, -9);
  C := simd_cmpeq_epi32(A, B);
  CheckMaskI32x4('cmpeq_epi32 mixed', C, [-1, 0, -1, 0]);

  B := simd_set1_epi32(3);
  C := simd_cmpgt_epi32(A, B);
  CheckI32('cmpgt_epi32 (5>3)', Int32($FFFFFFFF), C.m128i_i32[0]);

  C := simd_cmpgt_epi32(B, A);
  CheckI32('cmpgt_epi32 (3>5)', 0, C.m128i_i32[0]);

  // --- Integer Compare (8/16-bit) ---
  A := simd_set1_epi16(100);
  B := simd_set1_epi16(100);
  C := simd_cmpeq_epi16(A, B);
  CheckI32('cmpeq_epi16 (equal)', Int32($FFFFFFFF), C.m128i_i32[0]);

  A := simd_setr_epi16(1, 2, -3, 4, 5, -6, 7, 8);
  B := simd_setr_epi16(1, 9, -3, 0, 5, 6, 0, 8);
  C := simd_cmpeq_epi16(A, B);
  CheckMaskI16x8('cmpeq_epi16 mixed', C, [-1, 0, -1, 0, -1, 0, 0, -1]);

  A := simd_setr_epi8(1, 2, 3, 4, -1, -2, -3, -4, 10, 11, 12, 13, 100, 101, 102, 103);
  B := simd_setr_epi8(1, 9, 3, 0, -1, 0, -3, 4, 10, 0, 12, 14, 99, 101, 0, 103);
  C := simd_cmpeq_epi8(A, B);
  CheckMaskI8x16('cmpeq_epi8 mixed', C, [-1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, 0, -1, 0, -1]);

  A := simd_setr_epi8(-128, -64, -1, 0, 1, 2, 63, 64, 65, 66, 100, 101, 126, 127, 5, 6);
  B := simd_setr_epi8(-128, 0, -1, 1, 1, 3, 63, -64, 64, 66, 99, 102, 126, 0, 4, 6);
  C := simd_cmpeq_epi8(A, B);
  CheckMaskI8x16('cmpeq_epi8 edge', C, [-1, 0, -1, 0, -1, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1]);

  A := simd_set1_epi8(10);
  B := simd_set1_epi8(5);
  C := simd_cmpgt_epi8(A, B);
  CheckI32('cmpgt_epi8 (10>5)', Int32($FFFFFFFF), C.m128i_i32[0]);

  A := simd_setr_epi8(1, 2, -1, -128, 127, 0, -5, 10, 50, -60, 7, 8, 9, 10, 11, 12);
  B := simd_setr_epi8(0, 2, -2, 127, -128, 1, -10, 20, 40, -70, 8, 7, 9, 11, 10, 12);
  C := simd_cmpgt_epi8(A, B);
  CheckMaskI8x16('cmpgt_epi8 mixed', C, [-1, 0, -1, 0, -1, 0, -1, 0, -1, -1, 0, -1, 0, 0, -1, 0]);

  A := simd_setr_epi16(1, 200, -1, -32768, 32767, 0, -5, 10);
  B := simd_setr_epi16(0, 200, -2, 32767, -32768, 1, -10, 20);
  C := simd_cmpgt_epi16(A, B);
  CheckMaskI16x8('cmpgt_epi16 mixed', C, [-1, 0, -1, 0, -1, 0, -1, 0]);

  A := simd_setr_epi16(-10, -9, -8, -7, 7, 8, 9, 10);
  B := simd_setr_epi16(-11, -9, -7, -8, 6, 9, 9, 11);
  C := simd_cmpgt_epi16(A, B);
  CheckMaskI16x8('cmpgt_epi16 edge', C, [-1, 0, 0, -1, -1, 0, 0, 0]);

  A := simd_setr_epi8(0, 2, -3, -128, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
  B := simd_setr_epi8(1, 2, -2, 127, 4, 7, 6, 9, 9, 9, 12, 11, 14, 13, 16, 15);
  C := simd_cmplt_epi8(A, B);
  CheckMaskI8x16('cmplt_epi8 mixed', C, [-1, 0, -1, -1, 0, -1, 0, -1, 0, 0, -1, 0, -1, 0, -1, 0]);

  A := simd_setr_epi8(127, -127, -1, 0, 50, -50, 100, -100, 30, 40, 50, 60, 70, 80, 90, 100);
  B := simd_setr_epi8(127, -126, 0, -1, 40, -40, 101, -101, 31, 39, 50, 61, 69, 81, 89, 101);
  C := simd_cmplt_epi8(A, B);
  CheckMaskI8x16('cmplt_epi8 edge', C, [0, -1, -1, 0, 0, -1, -1, 0, -1, 0, 0, -1, 0, -1, 0, -1]);

  A := simd_setr_epi16(0, 200, -3, -32768, 4, 5, 6, 7);
  B := simd_setr_epi16(1, 200, -2, 32767, 3, 6, 5, 8);
  C := simd_cmplt_epi16(A, B);
  CheckMaskI16x8('cmplt_epi16 mixed', C, [-1, 0, -1, -1, 0, -1, 0, -1]);

  A := simd_setr_epi16(100, -200, 300, -400, 500, -600, 700, -800);
  B := simd_setr_epi16(100, -199, 299, -401, 600, -600, 699, -799);
  C := simd_cmplt_epi16(A, B);
  CheckMaskI16x8('cmplt_epi16 edge', C, [0, -1, 0, 0, -1, 0, 0, -1]);

  A := simd_setr_epi32(1, 2, -3, Low(Int32));
  B := simd_setr_epi32(2, 2, -2, High(Int32));
  C := simd_cmplt_epi32(A, B);
  CheckMaskI32x4('cmplt_epi32 mixed', C, [-1, 0, -1, -1]);

  A := simd_setr_epi32(100, -200, 300, -400);
  B := simd_setr_epi32(99, -199, 300, -401);
  C := simd_cmplt_epi32(A, B);
  CheckMaskI32x4('cmplt_epi32 edge', C, [0, -1, 0, 0]);

  // --- Float Compare (pd) ---
  A := simd_set1_pd(3.0);
  B := simd_set1_pd(5.0);
  C := simd_cmplt_pd(A, B);
  CheckI32('cmplt_pd (3<5) lo', Int32($FFFFFFFF), C.m128i_i32[0]);
  CheckI32('cmplt_pd (3<5) hi-lo', Int32($FFFFFFFF), C.m128i_i32[1]);

  C := simd_cmpeq_pd(A, A);
  CheckI32('cmpeq_pd (self)', Int32($FFFFFFFF), C.m128i_i32[0]);

  C := simd_cmplt_pd(simd_setr_pd(3.0, 9.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmplt_pd ord', C, MaskTrue64, 0);
  C := simd_cmplt_pd(simd_setr_pd(-2.0, 6.0), simd_setr_pd(-1.0, 7.0));
  CheckMaskPair64('cmplt_pd alltrue', C, MaskTrue64, MaskTrue64);

  C := simd_cmpeq_pd(simd_setr_pd(5.0, 7.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmpeq_pd equal', C, MaskTrue64, MaskTrue64);
  C := simd_cmpeq_pd(simd_setr_pd(3.0, 9.0), simd_setr_pd(5.0, 9.0));
  CheckMaskPair64('cmpeq_pd mixed', C, 0, MaskTrue64);

  C := simd_cmple_pd(simd_setr_pd(3.0, 9.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmple_pd ord', C, MaskTrue64, 0);
  C := simd_cmple_pd(simd_setr_pd(5.0, 7.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmple_pd equal', C, MaskTrue64, MaskTrue64);

  C := simd_cmpgt_pd(simd_setr_pd(3.0, 9.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmpgt_pd ord', C, 0, MaskTrue64);
  C := simd_cmpgt_pd(simd_setr_pd(6.0, 5.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmpgt_pd mixed', C, MaskTrue64, 0);

  C := simd_cmpge_pd(simd_setr_pd(3.0, 9.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmpge_pd ord', C, 0, MaskTrue64);
  C := simd_cmpge_pd(simd_setr_pd(5.0, 7.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmpge_pd equal', C, MaskTrue64, MaskTrue64);

  C := simd_cmpneq_pd(simd_setr_pd(3.0, 9.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmpneq_pd ord', C, MaskTrue64, MaskTrue64);
  C := simd_cmpneq_pd(simd_setr_pd(5.0, 7.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmpneq_pd equal', C, 0, 0);
  C := simd_cmpneq_pd(simd_setr_pd(NaN, 9.0), simd_setr_pd(5.0, NaN));
  CheckMaskPair64('cmpneq_pd nan', C, MaskTrue64, MaskTrue64);

  C := simd_cmpnlt_pd(simd_setr_pd(3.0, 9.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmpnlt_pd ord', C, 0, MaskTrue64);
  C := simd_cmpnlt_pd(simd_setr_pd(5.0, 7.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmpnlt_pd equal', C, MaskTrue64, MaskTrue64);
  C := simd_cmpnlt_pd(simd_setr_pd(NaN, 9.0), simd_setr_pd(5.0, NaN));
  CheckMaskPair64('cmpnlt_pd nan', C, MaskTrue64, MaskTrue64);

  C := simd_cmpnle_pd(simd_setr_pd(3.0, 9.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmpnle_pd ord', C, 0, MaskTrue64);
  C := simd_cmpnle_pd(simd_setr_pd(6.0, 9.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmpnle_pd greater', C, MaskTrue64, MaskTrue64);
  C := simd_cmpnle_pd(simd_setr_pd(NaN, 9.0), simd_setr_pd(5.0, NaN));
  CheckMaskPair64('cmpnle_pd nan', C, MaskTrue64, MaskTrue64);

  C := simd_cmpngt_pd(simd_setr_pd(3.0, 9.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmpngt_pd ord', C, MaskTrue64, 0);
  C := simd_cmpngt_pd(simd_setr_pd(5.0, 7.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmpngt_pd equal', C, MaskTrue64, MaskTrue64);
  C := simd_cmpngt_pd(simd_setr_pd(NaN, 9.0), simd_setr_pd(5.0, NaN));
  CheckMaskPair64('cmpngt_pd nan', C, MaskTrue64, MaskTrue64);

  C := simd_cmpnge_pd(simd_setr_pd(3.0, 9.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmpnge_pd ord', C, MaskTrue64, 0);
  C := simd_cmpnge_pd(simd_setr_pd(5.0, 7.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmpnge_pd equal', C, 0, 0);
  C := simd_cmpnge_pd(simd_setr_pd(NaN, 9.0), simd_setr_pd(5.0, NaN));
  CheckMaskPair64('cmpnge_pd nan', C, MaskTrue64, MaskTrue64);

  C := simd_cmpord_pd(simd_setr_pd(3.0, 9.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmpord_pd ord', C, MaskTrue64, MaskTrue64);
  C := simd_cmpord_pd(simd_setr_pd(NaN, 9.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmpord_pd nan', C, 0, MaskTrue64);
  C := simd_cmpord_pd(simd_setr_pd(3.0, 9.0), simd_setr_pd(5.0, NaN));
  CheckMaskPair64('cmpord_pd rhs_nan', C, MaskTrue64, 0);

  C := simd_cmpunord_pd(simd_setr_pd(3.0, 9.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmpunord_pd ord', C, 0, 0);
  C := simd_cmpunord_pd(simd_setr_pd(NaN, 9.0), simd_setr_pd(5.0, 7.0));
  CheckMaskPair64('cmpunord_pd nan', C, MaskTrue64, 0);
  C := simd_cmpunord_pd(simd_setr_pd(3.0, 9.0), simd_setr_pd(5.0, NaN));
  CheckMaskPair64('cmpunord_pd rhs_nan', C, 0, MaskTrue64);

  C := simd_cmpeq_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpeq_sd ord', C, 0, 11.0);
  C := simd_cmpeq_sd(simd_setr_pd(5.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpeq_sd equal', C, MaskTrue64, 11.0);

  C := simd_cmplt_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmplt_sd less', C, MaskTrue64, 11.0);
  C := simd_cmplt_sd(simd_setr_pd(9.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmplt_sd greater', C, 0, 11.0);

  C := simd_cmple_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmple_sd less', C, MaskTrue64, 11.0);
  C := simd_cmple_sd(simd_setr_pd(5.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmple_sd equal', C, MaskTrue64, 11.0);

  C := simd_cmpgt_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpgt_sd less', C, 0, 11.0);
  C := simd_cmpgt_sd(simd_setr_pd(9.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpgt_sd greater', C, MaskTrue64, 11.0);

  C := simd_cmpge_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpge_sd less', C, 0, 11.0);
  C := simd_cmpge_sd(simd_setr_pd(5.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpge_sd equal', C, MaskTrue64, 11.0);

  C := simd_cmpneq_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpneq_sd less', C, MaskTrue64, 11.0);
  C := simd_cmpneq_sd(simd_setr_pd(5.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpneq_sd equal', C, 0, 11.0);
  C := simd_cmpneq_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(NaN, 99.0));
  CheckScalarMaskWithHigh('cmpneq_sd nan', C, MaskTrue64, 11.0);

  C := simd_cmpnlt_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpnlt_sd less', C, 0, 11.0);
  C := simd_cmpnlt_sd(simd_setr_pd(5.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpnlt_sd equal', C, MaskTrue64, 11.0);
  C := simd_cmpnlt_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(NaN, 99.0));
  CheckScalarMaskWithHigh('cmpnlt_sd nan', C, MaskTrue64, 11.0);

  C := simd_cmpnle_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpnle_sd less', C, 0, 11.0);
  C := simd_cmpnle_sd(simd_setr_pd(9.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpnle_sd greater', C, MaskTrue64, 11.0);
  C := simd_cmpnle_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(NaN, 99.0));
  CheckScalarMaskWithHigh('cmpnle_sd nan', C, MaskTrue64, 11.0);

  C := simd_cmpngt_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpngt_sd less', C, MaskTrue64, 11.0);
  C := simd_cmpngt_sd(simd_setr_pd(5.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpngt_sd equal', C, MaskTrue64, 11.0);
  C := simd_cmpngt_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(NaN, 99.0));
  CheckScalarMaskWithHigh('cmpngt_sd nan', C, MaskTrue64, 11.0);

  C := simd_cmpnge_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpnge_sd less', C, MaskTrue64, 11.0);
  C := simd_cmpnge_sd(simd_setr_pd(5.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpnge_sd equal', C, 0, 11.0);
  C := simd_cmpnge_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(NaN, 99.0));
  CheckScalarMaskWithHigh('cmpnge_sd nan', C, MaskTrue64, 11.0);

  C := simd_cmpord_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpord_sd ord', C, MaskTrue64, 11.0);
  C := simd_cmpord_sd(simd_setr_pd(NaN, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpord_sd nan', C, 0, 11.0);
  C := simd_cmpord_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(NaN, 99.0));
  CheckScalarMaskWithHigh('cmpord_sd rhs_nan', C, 0, 11.0);

  C := simd_cmpunord_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpunord_sd ord', C, 0, 11.0);
  C := simd_cmpunord_sd(simd_setr_pd(NaN, 11.0), simd_setr_pd(5.0, 99.0));
  CheckScalarMaskWithHigh('cmpunord_sd nan', C, MaskTrue64, 11.0);
  C := simd_cmpunord_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(NaN, 99.0));
  CheckScalarMaskWithHigh('cmpunord_sd rhs_nan', C, MaskTrue64, 11.0);

  CheckI32('comieq_sd ord', 0, simd_comieq_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('comieq_sd equal', 1, simd_comieq_sd(simd_setr_pd(5.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('comilt_sd less', 1, simd_comilt_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('comilt_sd equal', 0, simd_comilt_sd(simd_setr_pd(5.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('comile_sd less', 1, simd_comile_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('comile_sd equal', 1, simd_comile_sd(simd_setr_pd(5.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('comigt_sd less', 0, simd_comigt_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('comigt_sd greater', 1, simd_comigt_sd(simd_setr_pd(9.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('comige_sd less', 0, simd_comige_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('comige_sd equal', 1, simd_comige_sd(simd_setr_pd(5.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('comineq_sd less', 1, simd_comineq_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('comineq_sd equal', 0, simd_comineq_sd(simd_setr_pd(5.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('comineq_sd nan', 1, simd_comineq_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(NaN, 99.0)));

  CheckI32('ucomieq_sd ord', 0, simd_ucomieq_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('ucomieq_sd equal', 1, simd_ucomieq_sd(simd_setr_pd(5.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('ucomilt_sd less', 1, simd_ucomilt_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('ucomilt_sd equal', 0, simd_ucomilt_sd(simd_setr_pd(5.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('ucomile_sd less', 1, simd_ucomile_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('ucomile_sd equal', 1, simd_ucomile_sd(simd_setr_pd(5.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('ucomigt_sd less', 0, simd_ucomigt_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('ucomigt_sd greater', 1, simd_ucomigt_sd(simd_setr_pd(9.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('ucomige_sd less', 0, simd_ucomige_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('ucomige_sd equal', 1, simd_ucomige_sd(simd_setr_pd(5.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('ucomineq_sd less', 1, simd_ucomineq_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('ucomineq_sd equal', 0, simd_ucomineq_sd(simd_setr_pd(5.0, 11.0), simd_setr_pd(5.0, 99.0)));
  CheckI32('ucomineq_sd nan', 1, simd_ucomineq_sd(simd_setr_pd(3.0, 11.0), simd_setr_pd(NaN, 99.0)));

  // --- Saturating Arithmetic ---
  A := simd_setr_epi8(120, -120, 60, -60, 127, -128, 1, -1, 100, -100, 64, -64, 0, 42, -42, 10);
  B := simd_setr_epi8(20, -20, 10, -10, 1, -1, -1, 1, 27, -28, 63, -64, 0, -40, 40, -20);
  C := simd_adds_epi8(A, B);
  CheckMaskI8x16('adds_epi8 mixed', C, [127, -128, 70, -70, 127, -128, 0, 0, 127, -128, 127, -128, 0, 2, -2, -10]);

  A := simd_setr_epi8(100, -100, 50, -50, 126, -127, 5, -5, 0, 80, -80, 1, -1, 30, -30, 12);
  B := simd_setr_epi8(26, -27, 77, -78, 2, -2, 122, -123, 0, 40, -40, -2, 2, -20, 20, 115);
  C := simd_adds_epi8(A, B);
  CheckMaskI8x16('adds_epi8 edge', C, [126, -127, 127, -128, 127, -128, 127, -128, 0, 120, -120, -1, 1, 10, -10, 127]);

  A := simd_setr_epi16(30000, -30000, 120, -120, 32760, -32760, 0, 12345);
  B := simd_setr_epi16(10000, -10000, 7, -7, 20, -20, 0, -2345);
  C := simd_adds_epi16(A, B);
  CheckMaskI16x8('adds_epi16 mixed', C, [32767, -32768, 127, -127, 32767, -32768, 0, 10000]);

  A := simd_setr_epi16(20000, -20000, 1, -1, 32767, -32768, 1234, -1234);
  B := simd_setr_epi16(10000, -10000, 1, -1, 1, -1, -234, 234);
  C := simd_adds_epi16(A, B);
  CheckMaskI16x8('adds_epi16 edge', C, [30000, -30000, 2, -2, 32767, -32768, 1000, -1000]);

  A := U8x16([250, 1, 0, 128, 200, 255, 10, 100, 30, 64, 127, 254, 80, 5, 240, 15]);
  B := U8x16([10, 2, 0, 128, 55, 1, 20, 27, 225, 63, 128, 1, 10, 250, 14, 15]);
  C := simd_adds_epu8(A, B);
  CheckU8x16('adds_epu8 mixed', C, [255, 3, 0, 255, 255, 255, 30, 127, 255, 127, 255, 255, 90, 255, 254, 30]);

  A := U8x16([0, 1, 2, 3, 4, 5, 6, 7, 250, 251, 252, 253, 254, 255, 100, 150]);
  B := U8x16([0, 254, 253, 252, 251, 250, 249, 248, 1, 2, 3, 4, 5, 0, 155, 104]);
  C := simd_adds_epu8(A, B);
  CheckU8x16('adds_epu8 edge', C, [0, 255, 255, 255, 255, 255, 255, 255, 251, 253, 255, 255, 255, 255, 255, 254]);

  A := U16x8([65530, 1, 0, 32768, 40000, 65535, 1234, 60000]);
  B := U16x8([10, 2, 0, 32768, 25535, 1, 4321, 5000]);
  C := simd_adds_epu16(A, B);
  CheckU16x8('adds_epu16 mixed', C, [65535, 3, 0, 65535, 65535, 65535, 5555, 65000]);

  A := U16x8([0, 1, 2, 3, 65534, 65535, 1000, 50000]);
  B := U16x8([0, 65534, 65533, 65532, 1, 0, 64000, 15535]);
  C := simd_adds_epu16(A, B);
  CheckU16x8('adds_epu16 edge', C, [0, 65535, 65535, 65535, 65535, 65535, 65000, 65535]);

  A := simd_setr_epi8(127, -128, 100, -100, 0, 50, -50, 10, -10, 64, -64, 1, -1, 120, -120, 30);
  B := simd_setr_epi8(-1, 1, -40, 40, 0, 100, -100, 20, -20, -63, 64, 2, -2, -10, 10, 60);
  C := simd_subs_epi8(A, B);
  CheckMaskI8x16('subs_epi8 mixed', C, [127, -128, 127, -128, 0, -50, 50, -10, 10, 127, -128, -1, 1, 127, -128, -30]);

  A := simd_setr_epi8(120, -120, 60, -60, 5, -5, 127, -128, 0, 1, -1, 100, -100, 32, -32, 10);
  B := simd_setr_epi8(30, -30, -67, 68, 6, -6, 127, -128, 1, -1, 1, -27, 28, -96, 97, -118);
  C := simd_subs_epi8(A, B);
  CheckMaskI8x16('subs_epi8 edge', C, [90, -90, 127, -128, -1, 1, 0, 0, -1, 2, -2, 127, -128, 127, -128, 127]);

  A := simd_setr_epi16(32767, -32768, 30000, -30000, 0, 1000, -1000, 12345);
  B := simd_setr_epi16(-1, 1, -10000, 10000, 0, 2000, -2000, -20000);
  C := simd_subs_epi16(A, B);
  CheckMaskI16x8('subs_epi16 mixed', C, [32767, -32768, 32767, -32768, 0, -1000, 1000, 32345]);

  A := simd_setr_epi16(32000, -32000, 100, -100, 1, -1, 20000, -20000);
  B := simd_setr_epi16(-1000, 1000, 200, -200, 2, -2, 30000, -30000);
  C := simd_subs_epi16(A, B);
  CheckMaskI16x8('subs_epi16 edge', C, [32767, -32768, -100, 100, -1, 1, -10000, 10000]);

  A := U8x16([0, 1, 10, 100, 255, 200, 128, 64, 5, 250, 30, 127, 80, 15, 2, 254]);
  B := U8x16([1, 2, 10, 50, 1, 201, 127, 65, 10, 100, 31, 127, 0, 20, 2, 255]);
  C := simd_subs_epu8(A, B);
  CheckU8x16('subs_epu8 mixed', C, [0, 0, 0, 50, 254, 0, 1, 0, 0, 150, 0, 0, 80, 0, 0, 0]);

  A := U8x16([255, 254, 253, 252, 128, 127, 126, 125, 0, 10, 20, 30, 40, 50, 60, 70]);
  B := U8x16([0, 1, 2, 3, 128, 128, 100, 200, 0, 9, 21, 29, 41, 49, 61, 69]);
  C := simd_subs_epu8(A, B);
  CheckU8x16('subs_epu8 edge', C, [255, 253, 251, 249, 0, 0, 26, 0, 0, 1, 0, 1, 0, 1, 0, 1]);

  A := U16x8([0, 1, 10, 1000, 65535, 60000, 32768, 12345]);
  B := U16x8([1, 2, 10, 500, 1, 60001, 32767, 23456]);
  C := simd_subs_epu16(A, B);
  CheckU16x8('subs_epu16 mixed', C, [0, 0, 0, 500, 65534, 0, 1, 0]);

  A := U16x8([65535, 65534, 50000, 40000, 30000, 20000, 10000, 0]);
  B := U16x8([0, 1, 49999, 40001, 10000, 25000, 9999, 0]);
  C := simd_subs_epu16(A, B);
  CheckU16x8('subs_epu16 edge', C, [65535, 65533, 1, 0, 20000, 0, 1, 0]);

  // --- Basic Integer Arithmetic and Min/Max ---
  A := U8x16([250, 1, 0, 128, 200, 255, 10, 100, 30, 64, 127, 254, 80, 5, 240, 15]);
  B := U8x16([10, 2, 0, 128, 55, 1, 20, 27, 225, 63, 128, 1, 10, 250, 14, 15]);
  C := simd_add_epi8(A, B);
  CheckU8x16('add_epi8 wrap', C, [4, 3, 0, 0, 255, 0, 30, 127, 255, 127, 255, 255, 90, 255, 254, 30]);

  A := U8x16([0, 1, 2, 3, 4, 5, 6, 7, 250, 251, 252, 253, 254, 255, 100, 150]);
  B := U8x16([0, 254, 253, 252, 251, 250, 249, 248, 1, 2, 3, 4, 5, 0, 155, 104]);
  C := simd_add_epi8(A, B);
  CheckU8x16('add_epi8 edge', C, [0, 255, 255, 255, 255, 255, 255, 255, 251, 253, 255, 1, 3, 255, 255, 254]);

  A := U16x8([65530, 1, 0, 32768, 40000, 65535, 1234, 60000]);
  B := U16x8([10, 2, 0, 32768, 25535, 1, 4321, 5000]);
  C := simd_add_epi16(A, B);
  CheckU16x8('add_epi16 wrap', C, [4, 3, 0, 0, 65535, 0, 5555, 65000]);

  A := U16x8([0, 1, 2, 3, 65534, 65535, 1000, 50000]);
  B := U16x8([0, 65534, 65533, 65532, 1, 0, 64000, 15535]);
  C := simd_add_epi16(A, B);
  CheckU16x8('add_epi16 edge', C, [0, 65535, 65535, 65535, 65535, 65535, 65000, 65535]);

  A := simd_setr_epi32(1, -2, 1000, -1000);
  B := simd_setr_epi32(2, 3, -500, 500);
  C := simd_add_epi32(A, B);
  CheckMaskI32x4('add_epi32 mixed', C, [3, 1, 500, -500]);

  A := simd_setr_epi64(-1000000000000, 1000000000000);
  B := simd_setr_epi64(250000000000, -750000000000);
  C := simd_add_epi64(A, B);
  CheckI64('add_epi64 mixed[0]', -750000000000, C.m128i_i64[0]);
  CheckI64('add_epi64 mixed[1]', 250000000000, C.m128i_i64[1]);

  A := U8x16([0, 1, 10, 100, 255, 200, 128, 64, 5, 250, 30, 127, 80, 15, 2, 254]);
  B := U8x16([1, 2, 10, 50, 1, 201, 127, 65, 10, 100, 31, 127, 0, 20, 2, 255]);
  C := simd_sub_epi8(A, B);
  CheckU8x16('sub_epi8 wrap', C, [255, 255, 0, 50, 254, 255, 1, 255, 251, 150, 255, 0, 80, 251, 0, 255]);

  A := U8x16([255, 254, 253, 252, 128, 127, 126, 125, 0, 10, 20, 30, 40, 50, 60, 70]);
  B := U8x16([0, 1, 2, 3, 128, 128, 100, 200, 0, 9, 21, 29, 41, 49, 61, 69]);
  C := simd_sub_epi8(A, B);
  CheckU8x16('sub_epi8 edge', C, [255, 253, 251, 249, 0, 255, 26, 181, 0, 1, 255, 1, 255, 1, 255, 1]);

  A := U16x8([0, 1, 10, 1000, 65535, 60000, 32768, 12345]);
  B := U16x8([1, 2, 10, 500, 1, 60001, 32767, 23456]);
  C := simd_sub_epi16(A, B);
  CheckU16x8('sub_epi16 wrap', C, [65535, 65535, 0, 500, 65534, 65535, 1, 54425]);

  A := U16x8([65535, 65534, 50000, 40000, 30000, 20000, 10000, 0]);
  B := U16x8([0, 1, 49999, 40001, 10000, 25000, 9999, 0]);
  C := simd_sub_epi16(A, B);
  CheckU16x8('sub_epi16 edge', C, [65535, 65533, 1, 65535, 20000, 60536, 1, 0]);

  A := simd_setr_epi64(1000000000000, -1000000000000);
  B := simd_setr_epi64(250000000000, -750000000000);
  C := simd_sub_epi64(A, B);
  CheckI64('sub_epi64 mixed[0]', 750000000000, C.m128i_i64[0]);
  CheckI64('sub_epi64 mixed[1]', -250000000000, C.m128i_i64[1]);

  A := simd_setr_epi64(0, 1234567890123);
  B := simd_setr_epi64(0, 1234567890000);
  C := simd_sub_epi64(A, B);
  CheckI64('sub_epi64 edge[0]', 0, C.m128i_i64[0]);
  CheckI64('sub_epi64 edge[1]', 123, C.m128i_i64[1]);

  A := U8x16([0, 1, 2, 3, 127, 128, 254, 255, 10, 20, 30, 40, 50, 100, 150, 200]);
  B := U8x16([0, 2, 1, 4, 128, 127, 255, 254, 11, 21, 31, 41, 200, 150, 100, 50]);
  C := simd_avg_epu8(A, B);
  CheckU8x16('avg_epu8 mixed', C, [0, 2, 2, 4, 128, 128, 255, 255, 11, 21, 31, 41, 125, 125, 125, 125]);

  A := U16x8([0, 1, 2, 3, 32767, 32768, 65534, 65535]);
  B := U16x8([0, 2, 1, 4, 32768, 32767, 65535, 65534]);
  C := simd_avg_epu16(A, B);
  CheckU16x8('avg_epu16 mixed', C, [0, 2, 2, 4, 32768, 32768, 65535, 65535]);

  A := U16x8([10, 20, 30, 40, 1000, 2000, 30000, 60000]);
  B := U16x8([11, 21, 31, 41, 1001, 1999, 30001, 50000]);
  C := simd_avg_epu16(A, B);
  CheckU16x8('avg_epu16 edge', C, [11, 21, 31, 41, 1001, 2000, 30001, 55000]);

  A := simd_setr_epi8(120, -120, 60, -60, 127, -128, 1, -1, 100, -100, 64, -64, 0, 42, -42, 10);
  B := simd_setr_epi8(20, -20, 70, -70, -1, 1, -1, 1, 101, -101, 63, -65, 0, -40, 40, -20);
  C := simd_max_epi8(A, B);
  CheckMaskI8x16('max_epi8 mixed', C, [120, -20, 70, -60, 127, 1, 1, 1, 101, -100, 64, -64, 0, 42, 40, 10]);
  C := simd_min_epi8(A, B);
  CheckMaskI8x16('min_epi8 mixed', C, [20, -120, 60, -70, -1, -128, -1, -1, 100, -101, 63, -65, 0, -40, -42, -20]);

  A := simd_setr_epi8(-128, -127, -1, 0, 1, 126, 127, 64, -64, 32, -32, 100, -100, 50, -50, 0);
  B := simd_setr_epi8(127, -128, 0, -1, 1, 127, 126, -64, 64, -32, 32, -100, 100, -50, 50, 0);
  C := simd_max_epi8(A, B);
  CheckMaskI8x16('max_epi8 edge', C, [127, -127, 0, 0, 1, 127, 127, 64, 64, 32, 32, 100, 100, 50, 50, 0]);
  C := simd_min_epi8(A, B);
  CheckMaskI8x16('min_epi8 edge', C, [-128, -128, -1, -1, 1, 126, 126, -64, -64, -32, -32, -100, -100, -50, -50, 0]);

  A := simd_setr_epi16(30000, -30000, 120, -120, 32760, -32760, 0, 12345);
  B := simd_setr_epi16(10000, -10000, 127, -127, 32767, -32768, 0, -2345);
  C := simd_max_epi16(A, B);
  CheckMaskI16x8('max_epi16 mixed', C, [30000, -10000, 127, -120, 32767, -32760, 0, 12345]);
  C := simd_min_epi16(A, B);
  CheckMaskI16x8('min_epi16 mixed', C, [10000, -30000, 120, -127, 32760, -32768, 0, -2345]);

  A := U8x16([250, 1, 0, 128, 200, 255, 10, 100, 30, 64, 127, 254, 80, 5, 240, 15]);
  B := U8x16([10, 2, 0, 127, 55, 1, 20, 27, 225, 63, 128, 1, 10, 250, 14, 15]);
  C := simd_max_epu8(A, B);
  CheckU8x16('max_epu8 mixed', C, [250, 2, 0, 128, 200, 255, 20, 100, 225, 64, 128, 254, 80, 250, 240, 15]);
  C := simd_min_epu8(A, B);
  CheckU8x16('min_epu8 mixed', C, [10, 1, 0, 127, 55, 1, 10, 27, 30, 63, 127, 1, 10, 5, 14, 15]);

  A := U8x16([0, 1, 2, 3, 4, 5, 6, 7, 250, 251, 252, 253, 254, 255, 100, 150]);
  B := U8x16([255, 254, 253, 252, 251, 250, 249, 248, 1, 2, 3, 4, 5, 0, 155, 104]);
  C := simd_max_epu8(A, B);
  CheckU8x16('max_epu8 edge', C, [255, 254, 253, 252, 251, 250, 249, 248, 250, 251, 252, 253, 254, 255, 155, 150]);
  C := simd_min_epu8(A, B);
  CheckU8x16('min_epu8 edge', C, [0, 1, 2, 3, 4, 5, 6, 7, 1, 2, 3, 4, 5, 0, 100, 104]);

  // --- Min/Max ---
  A := simd_set1_epi16(100);
  B := simd_set1_epi16(200);
  C := simd_max_epi16(A, B);
  if C.m128i_i16[0] = 200 then Inc(GPass) else begin WriteLn('FAIL: max_epi16'); Inc(GFail); end;

  C := simd_min_epi16(A, B);
  if C.m128i_i16[0] = 100 then Inc(GPass) else begin WriteLn('FAIL: min_epi16'); Inc(GFail); end;

  A := simd_set1_ps(3.0);
  B := simd_set1_ps(7.0);
  C := simd_max_ps(A, B);
  CheckF32('max_ps', 7.0, C.m128_f32[0]);
  C := simd_min_ps(A, B);
  CheckF32('min_ps', 3.0, C.m128_f32[0]);

  DataF32[0] := -1.0; DataF32[1] := 8.0; DataF32[2] := -3.0; DataF32[3] := 5.0;
  A := simd_loadu_ps(@DataF32[0]);
  AlignedF32^[0] := 2.0; AlignedF32^[1] := 7.0; AlignedF32^[2] := -4.0; AlignedF32^[3] := 6.0;
  B := simd_load_ps(@AlignedF32^[0]);
  C := simd_max_ps(A, B);
  CheckF32('max_ps second[0]', 2.0, C.m128_f32[0]);
  CheckF32('max_ps second[1]', 8.0, C.m128_f32[1]);
  CheckF32('max_ps second[2]', -3.0, C.m128_f32[2]);
  CheckF32('max_ps second[3]', 6.0, C.m128_f32[3]);
  C := simd_min_ps(A, B);
  CheckF32('min_ps second[0]', -1.0, C.m128_f32[0]);
  CheckF32('min_ps second[1]', 7.0, C.m128_f32[1]);
  CheckF32('min_ps second[2]', -4.0, C.m128_f32[2]);
  CheckF32('min_ps second[3]', 5.0, C.m128_f32[3]);

  C := simd_max_pd(simd_set1_pd(2.5), simd_set1_pd(4.5));
  CheckF64('max_pd', 4.5, C.m128d_f64[0]);
  C := simd_min_pd(simd_set1_pd(2.5), simd_set1_pd(4.5));
  CheckF64('min_pd', 2.5, C.m128d_f64[0]);

  // --- Sqrt ---
  A := simd_set1_ps(16.0);
  C := simd_sqrt_ps(A);
  CheckF32('sqrt_ps', 4.0, C.m128_f32[0]);

  DataF32[0] := 0.25; DataF32[1] := 1.0; DataF32[2] := 81.0; DataF32[3] := 144.0;
  A := simd_loadu_ps(@DataF32[0]);
  C := simd_sqrt_ps(A);
  CheckF32('sqrt_ps second[0]', 0.5, C.m128_f32[0]);
  CheckF32('sqrt_ps second[1]', 1.0, C.m128_f32[1]);
  CheckF32('sqrt_ps second[2]', 9.0, C.m128_f32[2]);
  CheckF32('sqrt_ps second[3]', 12.0, C.m128_f32[3]);

  A := simd_set1_pd(25.0);
  C := simd_sqrt_pd(A);
  CheckF64('sqrt_pd', 5.0, C.m128d_f64[0]);

  // --- Pack/Unpack ---
  A := simd_set_epi32(4, 3, 2, 1);
  B := simd_set_epi32(8, 7, 6, 5);
  C := simd_unpacklo_epi32(A, B);
  CheckI32('unpacklo_epi32[0]', 1, C.m128i_i32[0]);
  CheckI32('unpacklo_epi32[1]', 5, C.m128i_i32[1]);
  CheckI32('unpacklo_epi32[2]', 2, C.m128i_i32[2]);
  CheckI32('unpacklo_epi32[3]', 6, C.m128i_i32[3]);

  C := simd_unpackhi_epi32(A, B);
  CheckI32('unpackhi_epi32[0]', 3, C.m128i_i32[0]);
  CheckI32('unpackhi_epi32[1]', 7, C.m128i_i32[1]);
  CheckI32('unpackhi_epi32[2]', 4, C.m128i_i32[2]);
  CheckI32('unpackhi_epi32[3]', 8, C.m128i_i32[3]);

  A := simd_setr_epi32(-1, 0, 1, 2);
  B := simd_setr_epi32(10, 20, 30, 40);
  C := simd_unpacklo_epi32(A, B);
  CheckI32('unpacklo_epi32 second[0]', -1, C.m128i_i32[0]);
  CheckI32('unpacklo_epi32 second[1]', 10, C.m128i_i32[1]);
  CheckI32('unpacklo_epi32 second[2]', 0, C.m128i_i32[2]);
  CheckI32('unpacklo_epi32 second[3]', 20, C.m128i_i32[3]);

  C := simd_unpackhi_epi32(A, B);
  CheckI32('unpackhi_epi32 second[0]', 1, C.m128i_i32[0]);
  CheckI32('unpackhi_epi32 second[1]', 30, C.m128i_i32[1]);
  CheckI32('unpackhi_epi32 second[2]', 2, C.m128i_i32[2]);
  CheckI32('unpackhi_epi32 second[3]', 40, C.m128i_i32[3]);

  A := simd_setr_epi8(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
  B := simd_setr_epi8(-1, -2, -3, -4, -5, -6, -7, -8, -9, -10, -11, -12, -13, -14, -15, -16);
  C := simd_unpacklo_epi8(A, B);
  CheckI32('unpacklo_epi8[0]', 1, C.m128i_i8[0]);
  CheckI32('unpacklo_epi8[1]', -1, C.m128i_i8[1]);
  CheckI32('unpacklo_epi8[2]', 2, C.m128i_i8[2]);
  CheckI32('unpacklo_epi8[3]', -2, C.m128i_i8[3]);
  CheckI32('unpacklo_epi8[4]', 3, C.m128i_i8[4]);
  CheckI32('unpacklo_epi8[5]', -3, C.m128i_i8[5]);
  CheckI32('unpacklo_epi8[6]', 4, C.m128i_i8[6]);
  CheckI32('unpacklo_epi8[7]', -4, C.m128i_i8[7]);
  CheckI32('unpacklo_epi8[8]', 5, C.m128i_i8[8]);
  CheckI32('unpacklo_epi8[9]', -5, C.m128i_i8[9]);
  CheckI32('unpacklo_epi8[10]', 6, C.m128i_i8[10]);
  CheckI32('unpacklo_epi8[11]', -6, C.m128i_i8[11]);
  CheckI32('unpacklo_epi8[12]', 7, C.m128i_i8[12]);
  CheckI32('unpacklo_epi8[13]', -7, C.m128i_i8[13]);
  CheckI32('unpacklo_epi8[14]', 8, C.m128i_i8[14]);
  CheckI32('unpacklo_epi8[15]', -8, C.m128i_i8[15]);

  A := simd_setr_epi8(21, 22, 23, 24, 25, 26, 27, 28, 101, 102, 103, 104, 105, 106, 107, 108);
  B := simd_setr_epi8(31, 32, 33, 34, 35, 36, 37, 38, -21, -22, -23, -24, -25, -26, -27, -28);
  C := simd_unpacklo_epi8(A, B);
  CheckI32('unpacklo_epi8 second[0]', 21, C.m128i_i8[0]);
  CheckI32('unpacklo_epi8 second[1]', 31, C.m128i_i8[1]);
  CheckI32('unpacklo_epi8 second[2]', 22, C.m128i_i8[2]);
  CheckI32('unpacklo_epi8 second[3]', 32, C.m128i_i8[3]);
  CheckI32('unpacklo_epi8 second[4]', 23, C.m128i_i8[4]);
  CheckI32('unpacklo_epi8 second[5]', 33, C.m128i_i8[5]);
  CheckI32('unpacklo_epi8 second[6]', 24, C.m128i_i8[6]);
  CheckI32('unpacklo_epi8 second[7]', 34, C.m128i_i8[7]);
  CheckI32('unpacklo_epi8 second[8]', 25, C.m128i_i8[8]);
  CheckI32('unpacklo_epi8 second[9]', 35, C.m128i_i8[9]);
  CheckI32('unpacklo_epi8 second[10]', 26, C.m128i_i8[10]);
  CheckI32('unpacklo_epi8 second[11]', 36, C.m128i_i8[11]);
  CheckI32('unpacklo_epi8 second[12]', 27, C.m128i_i8[12]);
  CheckI32('unpacklo_epi8 second[13]', 37, C.m128i_i8[13]);
  CheckI32('unpacklo_epi8 second[14]', 28, C.m128i_i8[14]);
  CheckI32('unpacklo_epi8 second[15]', 38, C.m128i_i8[15]);

  A := simd_setr_epi8(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
  B := simd_setr_epi8(-1, -2, -3, -4, -5, -6, -7, -8, -9, -10, -11, -12, -13, -14, -15, -16);
  C := simd_unpackhi_epi8(A, B);
  CheckI32('unpackhi_epi8[0]', 9, C.m128i_i8[0]);
  CheckI32('unpackhi_epi8[1]', -9, C.m128i_i8[1]);
  CheckI32('unpackhi_epi8[2]', 10, C.m128i_i8[2]);
  CheckI32('unpackhi_epi8[3]', -10, C.m128i_i8[3]);
  CheckI32('unpackhi_epi8[4]', 11, C.m128i_i8[4]);
  CheckI32('unpackhi_epi8[5]', -11, C.m128i_i8[5]);
  CheckI32('unpackhi_epi8[6]', 12, C.m128i_i8[6]);
  CheckI32('unpackhi_epi8[7]', -12, C.m128i_i8[7]);
  CheckI32('unpackhi_epi8[8]', 13, C.m128i_i8[8]);
  CheckI32('unpackhi_epi8[9]', -13, C.m128i_i8[9]);
  CheckI32('unpackhi_epi8[10]', 14, C.m128i_i8[10]);
  CheckI32('unpackhi_epi8[11]', -14, C.m128i_i8[11]);
  CheckI32('unpackhi_epi8[12]', 15, C.m128i_i8[12]);
  CheckI32('unpackhi_epi8[13]', -15, C.m128i_i8[13]);
  CheckI32('unpackhi_epi8[14]', 16, C.m128i_i8[14]);
  CheckI32('unpackhi_epi8[15]', -16, C.m128i_i8[15]);

  A := simd_setr_epi8(21, 22, 23, 24, 25, 26, 27, 28, 101, 102, 103, 104, 105, 106, 107, 108);
  B := simd_setr_epi8(31, 32, 33, 34, 35, 36, 37, 38, -21, -22, -23, -24, -25, -26, -27, -28);
  C := simd_unpackhi_epi8(A, B);
  CheckI32('unpackhi_epi8 second[0]', 101, C.m128i_i8[0]);
  CheckI32('unpackhi_epi8 second[1]', -21, C.m128i_i8[1]);
  CheckI32('unpackhi_epi8 second[2]', 102, C.m128i_i8[2]);
  CheckI32('unpackhi_epi8 second[3]', -22, C.m128i_i8[3]);
  CheckI32('unpackhi_epi8 second[4]', 103, C.m128i_i8[4]);
  CheckI32('unpackhi_epi8 second[5]', -23, C.m128i_i8[5]);
  CheckI32('unpackhi_epi8 second[6]', 104, C.m128i_i8[6]);
  CheckI32('unpackhi_epi8 second[7]', -24, C.m128i_i8[7]);
  CheckI32('unpackhi_epi8 second[8]', 105, C.m128i_i8[8]);
  CheckI32('unpackhi_epi8 second[9]', -25, C.m128i_i8[9]);
  CheckI32('unpackhi_epi8 second[10]', 106, C.m128i_i8[10]);
  CheckI32('unpackhi_epi8 second[11]', -26, C.m128i_i8[11]);
  CheckI32('unpackhi_epi8 second[12]', 107, C.m128i_i8[12]);
  CheckI32('unpackhi_epi8 second[13]', -27, C.m128i_i8[13]);
  CheckI32('unpackhi_epi8 second[14]', 108, C.m128i_i8[14]);
  CheckI32('unpackhi_epi8 second[15]', -28, C.m128i_i8[15]);

  A := simd_setr_epi16(1, 2, 3, 4, 5, 6, 7, 8);
  B := simd_setr_epi16(-1, -2, -3, -4, -5, -6, -7, -8);
  C := simd_unpacklo_epi16(A, B);
  CheckI32('unpacklo_epi16[0]', 1, C.m128i_i16[0]);
  CheckI32('unpacklo_epi16[1]', -1, C.m128i_i16[1]);
  CheckI32('unpacklo_epi16[2]', 2, C.m128i_i16[2]);
  CheckI32('unpacklo_epi16[3]', -2, C.m128i_i16[3]);
  CheckI32('unpacklo_epi16[4]', 3, C.m128i_i16[4]);
  CheckI32('unpacklo_epi16[5]', -3, C.m128i_i16[5]);
  CheckI32('unpacklo_epi16[6]', 4, C.m128i_i16[6]);
  CheckI32('unpacklo_epi16[7]', -4, C.m128i_i16[7]);

  A := simd_setr_epi16(21, 22, 23, 24, 101, 102, 103, 104);
  B := simd_setr_epi16(31, 32, 33, 34, -21, -22, -23, -24);
  C := simd_unpacklo_epi16(A, B);
  CheckI32('unpacklo_epi16 second[0]', 21, C.m128i_i16[0]);
  CheckI32('unpacklo_epi16 second[1]', 31, C.m128i_i16[1]);
  CheckI32('unpacklo_epi16 second[2]', 22, C.m128i_i16[2]);
  CheckI32('unpacklo_epi16 second[3]', 32, C.m128i_i16[3]);
  CheckI32('unpacklo_epi16 second[4]', 23, C.m128i_i16[4]);
  CheckI32('unpacklo_epi16 second[5]', 33, C.m128i_i16[5]);
  CheckI32('unpacklo_epi16 second[6]', 24, C.m128i_i16[6]);
  CheckI32('unpacklo_epi16 second[7]', 34, C.m128i_i16[7]);

  A := simd_setr_epi16(1, 2, 3, 4, 5, 6, 7, 8);
  B := simd_setr_epi16(-1, -2, -3, -4, -5, -6, -7, -8);
  C := simd_unpackhi_epi16(A, B);
  CheckI32('unpackhi_epi16[0]', 5, C.m128i_i16[0]);
  CheckI32('unpackhi_epi16[1]', -5, C.m128i_i16[1]);
  CheckI32('unpackhi_epi16[2]', 6, C.m128i_i16[2]);
  CheckI32('unpackhi_epi16[3]', -6, C.m128i_i16[3]);
  CheckI32('unpackhi_epi16[4]', 7, C.m128i_i16[4]);
  CheckI32('unpackhi_epi16[5]', -7, C.m128i_i16[5]);
  CheckI32('unpackhi_epi16[6]', 8, C.m128i_i16[6]);
  CheckI32('unpackhi_epi16[7]', -8, C.m128i_i16[7]);

  A := simd_setr_epi16(21, 22, 23, 24, 101, 102, 103, 104);
  B := simd_setr_epi16(31, 32, 33, 34, -21, -22, -23, -24);
  C := simd_unpackhi_epi16(A, B);
  CheckI32('unpackhi_epi16 second[0]', 101, C.m128i_i16[0]);
  CheckI32('unpackhi_epi16 second[1]', -21, C.m128i_i16[1]);
  CheckI32('unpackhi_epi16 second[2]', 102, C.m128i_i16[2]);
  CheckI32('unpackhi_epi16 second[3]', -22, C.m128i_i16[3]);
  CheckI32('unpackhi_epi16 second[4]', 103, C.m128i_i16[4]);
  CheckI32('unpackhi_epi16 second[5]', -23, C.m128i_i16[5]);
  CheckI32('unpackhi_epi16 second[6]', 104, C.m128i_i16[6]);
  CheckI32('unpackhi_epi16 second[7]', -24, C.m128i_i16[7]);

  A := simd_setr_epi64(11, 22);
  B := simd_setr_epi64(33, 44);
  C := simd_unpacklo_epi64(A, B);
  CheckI64('unpacklo_epi64[0]', 11, C.m128i_i64[0]);
  CheckI64('unpacklo_epi64[1]', 33, C.m128i_i64[1]);

  A := simd_setr_epi64(-11, -22);
  B := simd_setr_epi64(55, 66);
  C := simd_unpacklo_epi64(A, B);
  CheckI64('unpacklo_epi64 second[0]', -11, C.m128i_i64[0]);
  CheckI64('unpacklo_epi64 second[1]', 55, C.m128i_i64[1]);

  A := simd_setr_epi64(11, 22);
  B := simd_setr_epi64(33, 44);
  C := simd_unpackhi_epi64(A, B);
  CheckI64('unpackhi_epi64[0]', 22, C.m128i_i64[0]);
  CheckI64('unpackhi_epi64[1]', 44, C.m128i_i64[1]);

  A := simd_setr_epi64(-11, -22);
  B := simd_setr_epi64(55, 66);
  C := simd_unpackhi_epi64(A, B);
  CheckI64('unpackhi_epi64 second[0]', -22, C.m128i_i64[0]);
  CheckI64('unpackhi_epi64 second[1]', 66, C.m128i_i64[1]);

  DataF32[0] := 1.0;
  DataF32[1] := 2.0;
  DataF32[2] := 3.0;
  DataF32[3] := 4.0;
  A := simd_loadu_ps(@DataF32[0]);
  DataF32[0] := -1.0;
  DataF32[1] := -2.0;
  DataF32[2] := -3.0;
  DataF32[3] := -4.0;
  B := simd_loadu_ps(@DataF32[0]);
  C := simd_unpacklo_ps(A, B);
  CheckF32('unpacklo_ps[0]', 1.0, C.m128_f32[0]);
  CheckF32('unpacklo_ps[1]', -1.0, C.m128_f32[1]);
  CheckF32('unpacklo_ps[2]', 2.0, C.m128_f32[2]);
  CheckF32('unpacklo_ps[3]', -2.0, C.m128_f32[3]);

  DataF32[0] := 10.5;
  DataF32[1] := 20.5;
  DataF32[2] := 30.5;
  DataF32[3] := 40.5;
  A := simd_loadu_ps(@DataF32[0]);
  DataF32[0] := 100.5;
  DataF32[1] := 200.5;
  DataF32[2] := 300.5;
  DataF32[3] := 400.5;
  B := simd_loadu_ps(@DataF32[0]);
  C := simd_unpacklo_ps(A, B);
  CheckF32('unpacklo_ps second[0]', 10.5, C.m128_f32[0]);
  CheckF32('unpacklo_ps second[1]', 100.5, C.m128_f32[1]);
  CheckF32('unpacklo_ps second[2]', 20.5, C.m128_f32[2]);
  CheckF32('unpacklo_ps second[3]', 200.5, C.m128_f32[3]);

  DataF32[0] := 1.0;
  DataF32[1] := 2.0;
  DataF32[2] := 3.0;
  DataF32[3] := 4.0;
  A := simd_loadu_ps(@DataF32[0]);
  DataF32[0] := -1.0;
  DataF32[1] := -2.0;
  DataF32[2] := -3.0;
  DataF32[3] := -4.0;
  B := simd_loadu_ps(@DataF32[0]);
  C := simd_unpackhi_ps(A, B);
  CheckF32('unpackhi_ps[0]', 3.0, C.m128_f32[0]);
  CheckF32('unpackhi_ps[1]', -3.0, C.m128_f32[1]);
  CheckF32('unpackhi_ps[2]', 4.0, C.m128_f32[2]);
  CheckF32('unpackhi_ps[3]', -4.0, C.m128_f32[3]);

  DataF32[0] := 10.5;
  DataF32[1] := 20.5;
  DataF32[2] := 30.5;
  DataF32[3] := 40.5;
  A := simd_loadu_ps(@DataF32[0]);
  DataF32[0] := 100.5;
  DataF32[1] := 200.5;
  DataF32[2] := 300.5;
  DataF32[3] := 400.5;
  B := simd_loadu_ps(@DataF32[0]);
  C := simd_unpackhi_ps(A, B);
  CheckF32('unpackhi_ps second[0]', 30.5, C.m128_f32[0]);
  CheckF32('unpackhi_ps second[1]', 300.5, C.m128_f32[1]);
  CheckF32('unpackhi_ps second[2]', 40.5, C.m128_f32[2]);
  CheckF32('unpackhi_ps second[3]', 400.5, C.m128_f32[3]);

  // --- Shuffle ---
  A := simd_set_epi32(40, 30, 20, 10);
  C := simd_shuffle_epi32(A, $E4); // identity: 3,2,1,0 = $E4
  CheckI32('shuffle_epi32 identity[0]', 10, C.m128i_i32[0]);
  CheckI32('shuffle_epi32 identity[3]', 40, C.m128i_i32[3]);

  C := simd_shuffle_epi32(A, $00); // broadcast lane 0
  CheckI32('shuffle_epi32 broadcast[0]', 10, C.m128i_i32[0]);
  CheckI32('shuffle_epi32 broadcast[3]', 10, C.m128i_i32[3]);

  DataF32[0] := 1.0;
  DataF32[1] := 2.0;
  DataF32[2] := 3.0;
  DataF32[3] := 4.0;
  A := simd_loadu_ps(@DataF32[0]);
  DataF32[0] := 10.0;
  DataF32[1] := 20.0;
  DataF32[2] := 30.0;
  DataF32[3] := 40.0;
  B := simd_loadu_ps(@DataF32[0]);
  C := simd_shuffle_ps(A, B, $E4);
  CheckF32('shuffle_ps[0]', 1.0, C.m128_f32[0]);
  CheckF32('shuffle_ps[1]', 2.0, C.m128_f32[1]);
  CheckF32('shuffle_ps[2]', 30.0, C.m128_f32[2]);
  CheckF32('shuffle_ps[3]', 40.0, C.m128_f32[3]);

  C := simd_shuffle_ps(A, B, $1B);
  CheckF32('shuffle_ps second[0]', 4.0, C.m128_f32[0]);
  CheckF32('shuffle_ps second[1]', 3.0, C.m128_f32[1]);
  CheckF32('shuffle_ps second[2]', 20.0, C.m128_f32[2]);
  CheckF32('shuffle_ps second[3]', 10.0, C.m128_f32[3]);

  A := simd_setr_epi16(10, 20, 30, 40, 50, 60, 70, 80);
  C := simd_shufflelo_epi16(A, $1B);
  CheckMaskI16x8('shufflelo_epi16 reverse', C, [40, 30, 20, 10, 50, 60, 70, 80]);

  C := simd_shufflelo_epi16(A, $00);
  CheckMaskI16x8('shufflelo_epi16 broadcast', C, [10, 10, 10, 10, 50, 60, 70, 80]);

  C := simd_shufflehi_epi16(A, $1B);
  CheckMaskI16x8('shufflehi_epi16 reverse', C, [10, 20, 30, 40, 80, 70, 60, 50]);

  C := simd_shufflehi_epi16(A, $55);
  CheckMaskI16x8('shufflehi_epi16 broadcast', C, [10, 20, 30, 40, 60, 60, 60, 60]);

  A := U16x8([1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000]);
  C := simd_insert_epi16(A, $1234, 5);
  CheckU16x8('insert_epi16 direct', C, [1000, 2000, 3000, 4000, 5000, $1234, 7000, 8000]);
  CheckI32('extract_epi16 direct', 7000, simd_extract_epi16(C, 6));

  C := simd_insert_epi16(A, $1ABCD, 9);
  CheckU16x8('insert_epi16 masked', C, [1000, $ABCD, 3000, 4000, 5000, 6000, 7000, 8000]);
  CheckI32('extract_epi16 masked', $ABCD, simd_extract_epi16(C, 9));

  // --- Movemask ---
  A := simd_set_epi32(Int32($80000000), 0, Int32($80000000), 0);
  CheckI32('movemask_ps', $A, simd_movemask_ps(A)); // bits 3,1 set

  DataF32[0] := -1.0; DataF32[1] := 2.0; DataF32[2] := -3.0; DataF32[3] := 4.0;
  A := simd_loadu_ps(@DataF32[0]);
  CheckI32('movemask_ps second', $5, simd_movemask_ps(A)); // bits 2,0 set

  A := simd_set1_epi8(ShortInt($80));
  CheckI32('movemask_epi8 all-neg', $FFFF, simd_movemask_epi8(A));

  A := simd_set1_epi8(0);
  CheckI32('movemask_epi8 all-zero', 0, simd_movemask_epi8(A));

  // --- Convert ---
  A := simd_set_epi32(4, 3, 2, 1);
  C := simd_cvtepi32_ps(A);
  CheckF32('cvtepi32_ps[0]', 1.0, C.m128_f32[0]);
  CheckF32('cvtepi32_ps[3]', 4.0, C.m128_f32[3]);
  A := simd_set_epi32(-4, -3, -2, -1);
  C := simd_cvtepi32_ps(A);
  CheckF32('cvtepi32_ps neg[0]', -1.0, C.m128_f32[0]);
  CheckF32('cvtepi32_ps neg[3]', -4.0, C.m128_f32[3]);

  A := simd_set_epi32(400, 300, 200, 100);
  C := simd_cvtepi32_pd(A);
  CheckF64('cvtepi32_pd[0]', 100.0, C.m128d_f64[0]);
  CheckF64('cvtepi32_pd[1]', 200.0, C.m128d_f64[1]);

  A := simd_set_epi32(-40, -30, -20, -10);
  C := simd_cvtepi32_pd(A);
  CheckF64('cvtepi32_pd neg[0]', -10.0, C.m128d_f64[0]);
  CheckF64('cvtepi32_pd neg[1]', -20.0, C.m128d_f64[1]);

  A := simd_set1_ps(3.7);
  C := simd_cvtps_epi32(A);
  CheckI32('cvtps_epi32 (round)', 4, C.m128i_i32[0]);
  A := simd_set1_ps(2.5);
  C := simd_cvtps_epi32(A);
  CheckI32('cvtps_epi32 tie-even', 2, C.m128i_i32[0]);

  A := simd_set_pd(-3.6, 2.4);
  C := simd_cvtpd_epi32(A);
  CheckI32('cvtpd_epi32[0]', 2, C.m128i_i32[0]);
  CheckI32('cvtpd_epi32[1]', -4, C.m128i_i32[1]);
  CheckI32('cvtpd_epi32[2]', 0, C.m128i_i32[2]);
  CheckI32('cvtpd_epi32[3]', 0, C.m128i_i32[3]);

  A := simd_set_pd(-3.5, 2.5);
  C := simd_cvtpd_epi32(A);
  CheckI32('cvtpd_epi32 tie-even[0]', 2, C.m128i_i32[0]);
  CheckI32('cvtpd_epi32 tie-even[1]', -4, C.m128i_i32[1]);

  A := simd_set_pd(Infinity, NaN);
  C := simd_cvtpd_epi32(A);
  CheckI32('cvtpd_epi32 invalid[0]', Low(Int32), C.m128i_i32[0]);
  CheckI32('cvtpd_epi32 invalid[1]', Low(Int32), C.m128i_i32[1]);

  A := simd_set1_ps(3.7);
  C := simd_cvttps_epi32(A);
  CheckI32('cvttps_epi32 (trunc)', 3, C.m128i_i32[0]);
  A := simd_set1_ps(-3.9);
  C := simd_cvttps_epi32(A);
  CheckI32('cvttps_epi32 neg (trunc)', -3, C.m128i_i32[0]);

  A := simd_set_pd(-2.25, 1.5);
  C := simd_cvtpd_ps(A);
  CheckF32('cvtpd_ps[0]', 1.5, C.m128_f32[0]);
  CheckF32('cvtpd_ps[1]', -2.25, C.m128_f32[1]);
  CheckF32('cvtpd_ps[2]', 0.0, C.m128_f32[2]);
  CheckF32('cvtpd_ps[3]', 0.0, C.m128_f32[3]);

  A := simd_set_pd(4.75, -3.125);
  C := simd_cvtpd_ps(A);
  CheckF32('cvtpd_ps neg[0]', -3.125, C.m128_f32[0]);
  CheckF32('cvtpd_ps neg[1]', 4.75, C.m128_f32[1]);

  DataF32[0] := 6.25;
  DataF32[1] := -7.5;
  DataF32[2] := 30.0;
  DataF32[3] := 40.0;
  A := simd_loadu_ps(@DataF32[0]);
  C := simd_cvtps_pd(A);
  CheckF64('cvtps_pd[0]', 6.25, C.m128d_f64[0]);
  CheckF64('cvtps_pd[1]', -7.5, C.m128d_f64[1]);

  DataF32[0] := -1.25;
  DataF32[1] := 2.5;
  DataF32[2] := -3.0;
  DataF32[3] := -4.0;
  A := simd_loadu_ps(@DataF32[0]);
  C := simd_cvtps_pd(A);
  CheckF64('cvtps_pd neg[0]', -1.25, C.m128d_f64[0]);
  CheckF64('cvtps_pd neg[1]', 2.5, C.m128d_f64[1]);

  DataF32[0] := 10.0;
  DataF32[1] := 20.0;
  DataF32[2] := 30.0;
  DataF32[3] := 40.0;
  A := simd_loadu_ps(@DataF32[0]);
  B := simd_set_pd(99.0, 5.5);
  C := simd_cvtsd_ss(A, B);
  CheckF32('cvtsd_ss[0]', 5.5, C.m128_f32[0]);
  CheckF32('cvtsd_ss preserve[1]', 20.0, C.m128_f32[1]);
  CheckF32('cvtsd_ss preserve[3]', 40.0, C.m128_f32[3]);

  DataF32[0] := -10.0;
  DataF32[1] := -20.0;
  DataF32[2] := -30.0;
  DataF32[3] := -40.0;
  A := simd_loadu_ps(@DataF32[0]);
  B := simd_set_pd(12.0, -7.25);
  C := simd_cvtsd_ss(A, B);
  CheckF32('cvtsd_ss neg[0]', -7.25, C.m128_f32[0]);
  CheckF32('cvtsd_ss neg preserve[2]', -30.0, C.m128_f32[2]);

  A := simd_set_pd(10.0, 5.0);
  DataF32[0] := 6.25;
  DataF32[1] := 20.0;
  DataF32[2] := 30.0;
  DataF32[3] := 40.0;
  B := simd_loadu_ps(@DataF32[0]);
  C := simd_cvtss_sd(A, B);
  CheckF64('cvtss_sd[0]', 6.25, C.m128d_f64[0]);
  CheckF64('cvtss_sd preserve[1]', 10.0, C.m128d_f64[1]);

  A := simd_set_pd(-10.0, -5.0);
  DataF32[0] := -1.5;
  DataF32[1] := -2.0;
  DataF32[2] := -3.0;
  DataF32[3] := -4.0;
  B := simd_loadu_ps(@DataF32[0]);
  C := simd_cvtss_sd(A, B);
  CheckF64('cvtss_sd neg[0]', -1.5, C.m128d_f64[0]);
  CheckF64('cvtss_sd neg preserve[1]', -10.0, C.m128d_f64[1]);

  A := simd_set_pd(-3.9, 2.9);
  C := simd_cvttpd_epi32(A);
  CheckI32('cvttpd_epi32[0]', 2, C.m128i_i32[0]);
  CheckI32('cvttpd_epi32[1]', -3, C.m128i_i32[1]);
  CheckI32('cvttpd_epi32[2]', 0, C.m128i_i32[2]);
  CheckI32('cvttpd_epi32[3]', 0, C.m128i_i32[3]);

  A := simd_set_pd(8.9, -7.1);
  C := simd_cvttpd_epi32(A);
  CheckI32('cvttpd_epi32 neg[0]', -7, C.m128i_i32[0]);
  CheckI32('cvttpd_epi32 neg[1]', 8, C.m128i_i32[1]);

  A := simd_set_pd(-3.5, 1.25);
  C := simd_cvttpd_ps(A);
  CheckF32('cvttpd_ps[0]', 1.25, C.m128_f32[0]);
  CheckF32('cvttpd_ps[1]', -3.5, C.m128_f32[1]);
  CheckF32('cvttpd_ps[2]', 0.0, C.m128_f32[2]);
  CheckF32('cvttpd_ps[3]', 0.0, C.m128_f32[3]);

  A := simd_set_pd(9.5, -8.125);
  C := simd_cvttpd_ps(A);
  CheckF32('cvttpd_ps neg[0]', -8.125, C.m128_f32[0]);
  CheckF32('cvttpd_ps neg[1]', 9.5, C.m128_f32[1]);

  A := simd_set_pd(0.0, 5.75);
  CheckI32('cvtsd_si32', 6, simd_cvtsd_si32(A));
  A := simd_set_pd(0.0, -2.5);
  CheckI32('cvtsd_si32 tie-even', -2, simd_cvtsd_si32(A));
  A := simd_set_pd(0.0, NaN);
  CheckI32('cvtsd_si32 invalid', Low(Int32), simd_cvtsd_si32(A));

  A := simd_set_pd(0.0, 1234567890123.0);
  CheckI64('cvtsd_si64', 1234567890123, simd_cvtsd_si64(A));
  A := simd_set_pd(0.0, -1234567890123.0);
  CheckI64('cvtsd_si64 neg', -1234567890123, simd_cvtsd_si64(A));
  A := simd_set_pd(0.0, Infinity);
  CheckI64('cvtsd_si64 invalid', Low(Int64), simd_cvtsd_si64(A));

  A := simd_set_pd(0.0, 5.75);
  CheckI32('cvttsd_si32', 5, simd_cvttsd_si32(A));
  A := simd_set_pd(0.0, -7.6);
  CheckI32('cvttsd_si32 neg', -7, simd_cvttsd_si32(A));

  A := simd_set_pd(0.0, 5000000000.75);
  CheckI64('cvttsd_si64', 5000000000, simd_cvttsd_si64(A));
  A := simd_set_pd(0.0, -5000000000.75);
  CheckI64('cvttsd_si64 neg', -5000000000, simd_cvttsd_si64(A));

  A := simd_cvtsi32_si128(-123456789);
  CheckI32('cvtsi32_si128[0]', -123456789, A.m128i_i32[0]);
  CheckI32('cvtsi32_si128[1]', 0, A.m128i_i32[1]);

  A := simd_cvtsi32_si128(77);
  CheckI32('cvtsi32_si128 again[0]', 77, A.m128i_i32[0]);
  CheckI32('cvtsi32_si128 again[3]', 0, A.m128i_i32[3]);

  A := simd_cvtsi64_si128(1234567890123);
  CheckI64('cvtsi64_si128[0]', 1234567890123, A.m128i_i64[0]);
  CheckI64('cvtsi64_si128[1]', 0, A.m128i_i64[1]);

  A := simd_cvtsi64_si128(-9876543210);
  CheckI64('cvtsi64_si128 neg[0]', -9876543210, A.m128i_i64[0]);
  CheckI64('cvtsi64_si128 neg[1]', 0, A.m128i_i64[1]);

  CheckI32('cvtsi128_si32', 42, simd_cvtsi128_si32(simd_set1_epi32(42)));
  A := simd_set_epi32(-1, 0, 0, -99);
  CheckI32('cvtsi128_si32 neg', -99, simd_cvtsi128_si32(A));
  CheckI64('cvtsi128_si64', Int64($0102030405060708),
    simd_cvtsi128_si64(simd_set1_epi64x(Int64($0102030405060708))));
  A := simd_set_epi64(-2, Int64(-1234567890123));
  CheckI64('cvtsi128_si64 neg', -1234567890123, simd_cvtsi128_si64(A));

  A := simd_set_pd(10.0, 5.0);
  C := simd_cvtsi32_sd(A, 42);
  CheckF64('cvtsi32_sd[0]', 42.0, C.m128d_f64[0]);
  CheckF64('cvtsi32_sd preserve[1]', 10.0, C.m128d_f64[1]);

  A := simd_set_pd(-10.0, -5.0);
  C := simd_cvtsi32_sd(A, -17);
  CheckF64('cvtsi32_sd neg[0]', -17.0, C.m128d_f64[0]);
  CheckF64('cvtsi32_sd neg preserve[1]', -10.0, C.m128d_f64[1]);

  A := simd_set_pd(10.0, 5.0);
  C := simd_cvtsi64_sd(A, 1234567890123);
  CheckF64('cvtsi64_sd[0]', 1234567890123.0, C.m128d_f64[0]);
  CheckF64('cvtsi64_sd preserve[1]', 10.0, C.m128d_f64[1]);

  A := simd_set_pd(-10.0, -5.0);
  C := simd_cvtsi64_sd(A, -9876543210);
  CheckF64('cvtsi64_sd neg[0]', -9876543210.0, C.m128d_f64[0]);
  CheckF64('cvtsi64_sd neg preserve[1]', -10.0, C.m128d_f64[1]);

  A := simd_set_pd(-2.5, 1.25);
  C := simd_castpd_ps(A);
  CheckI64('castpd_ps[0]', A.m128i_i64[0], C.m128i_i64[0]);
  CheckI64('castpd_ps[1]', A.m128i_i64[1], C.m128i_i64[1]);

  C := simd_castpd_si128(A);
  CheckI64('castpd_si128[0]', A.m128i_i64[0], C.m128i_i64[0]);
  CheckI64('castpd_si128[1]', A.m128i_i64[1], C.m128i_i64[1]);

  A := simd_set_pd(Infinity, NaN);
  C := simd_castpd_ps(A);
  CheckI64('castpd_ps second[0]', A.m128i_i64[0], C.m128i_i64[0]);
  CheckI64('castpd_ps second[1]', A.m128i_i64[1], C.m128i_i64[1]);

  C := simd_castpd_si128(A);
  CheckI64('castpd_si128 second[0]', A.m128i_i64[0], C.m128i_i64[0]);
  CheckI64('castpd_si128 second[1]', A.m128i_i64[1], C.m128i_i64[1]);

  DataF32[0] := 1.5;
  DataF32[1] := -2.25;
  DataF32[2] := 3.75;
  DataF32[3] := -4.5;
  A := simd_loadu_ps(@DataF32[0]);
  C := simd_castps_pd(A);
  CheckI64('castps_pd[0]', A.m128i_i64[0], C.m128i_i64[0]);
  CheckI64('castps_pd[1]', A.m128i_i64[1], C.m128i_i64[1]);

  C := simd_castps_si128(A);
  CheckI64('castps_si128[0]', A.m128i_i64[0], C.m128i_i64[0]);
  CheckI64('castps_si128[1]', A.m128i_i64[1], C.m128i_i64[1]);

  DataF32[0] := 0.0;
  DataF32[1] := -0.0;
  DataF32[2] := Infinity;
  DataF32[3] := NaN;
  A := simd_loadu_ps(@DataF32[0]);
  C := simd_castps_pd(A);
  CheckI64('castps_pd second[0]', A.m128i_i64[0], C.m128i_i64[0]);
  CheckI64('castps_pd second[1]', A.m128i_i64[1], C.m128i_i64[1]);

  C := simd_castps_si128(A);
  CheckI64('castps_si128 second[0]', A.m128i_i64[0], C.m128i_i64[0]);
  CheckI64('castps_si128 second[1]', A.m128i_i64[1], C.m128i_i64[1]);

  A := simd_set_epi64(Int64($1111222233334444), Int64($5555666677778888));
  C := simd_castsi128_pd(A);
  CheckI64('castsi128_pd[0]', A.m128i_i64[0], C.m128i_i64[0]);
  CheckI64('castsi128_pd[1]', A.m128i_i64[1], C.m128i_i64[1]);

  C := simd_castsi128_ps(A);
  CheckI64('castsi128_ps[0]', A.m128i_i64[0], C.m128i_i64[0]);
  CheckI64('castsi128_ps[1]', A.m128i_i64[1], C.m128i_i64[1]);

  A := simd_set_epi64(Int64($0123456789ABCDEF), Int64($0FEDCBA987654321));
  C := simd_castsi128_pd(A);
  CheckI64('castsi128_pd second[0]', A.m128i_i64[0], C.m128i_i64[0]);
  CheckI64('castsi128_pd second[1]', A.m128i_i64[1], C.m128i_i64[1]);

  C := simd_castsi128_ps(A);
  CheckI64('castsi128_ps second[0]', A.m128i_i64[0], C.m128i_i64[0]);
  CheckI64('castsi128_ps second[1]', A.m128i_i64[1], C.m128i_i64[1]);

  // --- Pack / Move64 helpers ---
  DataI64[0] := Int64($0123456789ABCDEF);
  DataI64[1] := Int64($1111111111111111);
  A := simd_loadl_epi64(@DataI64[0]);
  CheckI64('loadl_epi64[0]', Int64($0123456789ABCDEF), A.m128i_i64[0]);
  CheckI64('loadl_epi64 zero[1]', 0, A.m128i_i64[1]);

  DataI64[0] := -1234567890123456789;
  DataI64[1] := 42;
  A := simd_loadl_epi64(@DataI64[0]);
  CheckI64('loadl_epi64 second[0]', -1234567890123456789, A.m128i_i64[0]);
  CheckI64('loadl_epi64 second zero[1]', 0, A.m128i_i64[1]);

  DataI64[0] := -1;
  DataI64[1] := Int64($2222333344445555);
  A := simd_setr_epi64(Int64($0123456789ABCDEF), Int64($0FEDCBA987654321));
  simd_storel_epi64(DataI64[0], A);
  CheckI64('storel_epi64[0]', Int64($0123456789ABCDEF), DataI64[0]);
  CheckI64('storel_epi64 preserve[1]', Int64($2222333344445555), DataI64[1]);

  DataI64[0] := 123;
  DataI64[1] := -456;
  A := simd_setr_epi64(-1234567890123456789, Int64($1111222233334444));
  simd_storel_epi64(DataI64[0], A);
  CheckI64('storel_epi64 second[0]', -1234567890123456789, DataI64[0]);
  CheckI64('storel_epi64 second preserve[1]', -456, DataI64[1]);

  A := simd_setr_epi64(Int64($0123456789ABCDEF), Int64($0FEDCBA987654321));
  C := simd_move_epi64(A);
  CheckI64('move_epi64[0]', Int64($0123456789ABCDEF), C.m128i_i64[0]);
  CheckI64('move_epi64 zero[1]', 0, C.m128i_i64[1]);

  A := simd_setr_epi64(-1234567890123456789, Int64($777788889999AAAA));
  C := simd_move_epi64(A);
  CheckI64('move_epi64 second[0]', -1234567890123456789, C.m128i_i64[0]);
  CheckI64('move_epi64 second zero[1]', 0, C.m128i_i64[1]);

  A := simd_setr_epi16(-200, -128, -127, -1, 0, 1, 100, 127);
  B := simd_setr_epi16(126, 127, 128, 200, -129, -300, 50, -50);
  C := simd_packs_epi16(A, B);
  CheckI32('packs_epi16[0]', -128, C.m128i_i8[0]);
  CheckI32('packs_epi16[1]', -128, C.m128i_i8[1]);
  CheckI32('packs_epi16[2]', -127, C.m128i_i8[2]);
  CheckI32('packs_epi16[3]', -1, C.m128i_i8[3]);
  CheckI32('packs_epi16[4]', 0, C.m128i_i8[4]);
  CheckI32('packs_epi16[5]', 1, C.m128i_i8[5]);
  CheckI32('packs_epi16[6]', 100, C.m128i_i8[6]);
  CheckI32('packs_epi16[7]', 127, C.m128i_i8[7]);
  CheckI32('packs_epi16[8]', 126, C.m128i_i8[8]);
  CheckI32('packs_epi16[9]', 127, C.m128i_i8[9]);
  CheckI32('packs_epi16[10]', 127, C.m128i_i8[10]);
  CheckI32('packs_epi16[11]', 127, C.m128i_i8[11]);
  CheckI32('packs_epi16[12]', -128, C.m128i_i8[12]);
  CheckI32('packs_epi16[13]', -128, C.m128i_i8[13]);
  CheckI32('packs_epi16[14]', 50, C.m128i_i8[14]);
  CheckI32('packs_epi16[15]', -50, C.m128i_i8[15]);

  A := simd_setr_epi16(-300, -64, -2, 2, 63, 64, 120, 500);
  B := simd_setr_epi16(-500, -129, -128, 0, 64, 126, 127, 300);
  C := simd_packs_epi16(A, B);
  CheckI32('packs_epi16 second[0]', -128, C.m128i_i8[0]);
  CheckI32('packs_epi16 second[1]', -64, C.m128i_i8[1]);
  CheckI32('packs_epi16 second[2]', -2, C.m128i_i8[2]);
  CheckI32('packs_epi16 second[3]', 2, C.m128i_i8[3]);
  CheckI32('packs_epi16 second[4]', 63, C.m128i_i8[4]);
  CheckI32('packs_epi16 second[5]', 64, C.m128i_i8[5]);
  CheckI32('packs_epi16 second[6]', 120, C.m128i_i8[6]);
  CheckI32('packs_epi16 second[7]', 127, C.m128i_i8[7]);
  CheckI32('packs_epi16 second[8]', -128, C.m128i_i8[8]);
  CheckI32('packs_epi16 second[9]', -128, C.m128i_i8[9]);
  CheckI32('packs_epi16 second[10]', -128, C.m128i_i8[10]);
  CheckI32('packs_epi16 second[11]', 0, C.m128i_i8[11]);
  CheckI32('packs_epi16 second[12]', 64, C.m128i_i8[12]);
  CheckI32('packs_epi16 second[13]', 126, C.m128i_i8[13]);
  CheckI32('packs_epi16 second[14]', 127, C.m128i_i8[14]);
  CheckI32('packs_epi16 second[15]', 127, C.m128i_i8[15]);

  A := simd_setr_epi32(-40000, -32768, -1, 0);
  B := simd_setr_epi32(1, 32767, 32768, 50000);
  C := simd_packs_epi32(A, B);
  CheckI32('packs_epi32[0]', -32768, C.m128i_i16[0]);
  CheckI32('packs_epi32[1]', -32768, C.m128i_i16[1]);
  CheckI32('packs_epi32[2]', -1, C.m128i_i16[2]);
  CheckI32('packs_epi32[3]', 0, C.m128i_i16[3]);
  CheckI32('packs_epi32[4]', 1, C.m128i_i16[4]);
  CheckI32('packs_epi32[5]', 32767, C.m128i_i16[5]);
  CheckI32('packs_epi32[6]', 32767, C.m128i_i16[6]);
  CheckI32('packs_epi32[7]', 32767, C.m128i_i16[7]);

  A := simd_setr_epi32(-50000, -12345, 12345, 40000);
  B := simd_setr_epi32(-32769, -32767, 32766, 32767);
  C := simd_packs_epi32(A, B);
  CheckI32('packs_epi32 second[0]', -32768, C.m128i_i16[0]);
  CheckI32('packs_epi32 second[1]', -12345, C.m128i_i16[1]);
  CheckI32('packs_epi32 second[2]', 12345, C.m128i_i16[2]);
  CheckI32('packs_epi32 second[3]', 32767, C.m128i_i16[3]);
  CheckI32('packs_epi32 second[4]', -32768, C.m128i_i16[4]);
  CheckI32('packs_epi32 second[5]', -32767, C.m128i_i16[5]);
  CheckI32('packs_epi32 second[6]', 32766, C.m128i_i16[6]);
  CheckI32('packs_epi32 second[7]', 32767, C.m128i_i16[7]);

  A := simd_setr_epi16(-10, 0, 1, 42, 255, 256, 300, 500);
  B := simd_setr_epi16(-1, 10, 127, 254, 255, 256, 1024, 64);
  C := simd_packus_epi16(A, B);
  CheckI32('packus_epi16[0]', 0, C.m128i_u8[0]);
  CheckI32('packus_epi16[1]', 0, C.m128i_u8[1]);
  CheckI32('packus_epi16[2]', 1, C.m128i_u8[2]);
  CheckI32('packus_epi16[3]', 42, C.m128i_u8[3]);
  CheckI32('packus_epi16[4]', 255, C.m128i_u8[4]);
  CheckI32('packus_epi16[5]', 255, C.m128i_u8[5]);
  CheckI32('packus_epi16[6]', 255, C.m128i_u8[6]);
  CheckI32('packus_epi16[7]', 255, C.m128i_u8[7]);
  CheckI32('packus_epi16[8]', 0, C.m128i_u8[8]);
  CheckI32('packus_epi16[9]', 10, C.m128i_u8[9]);
  CheckI32('packus_epi16[10]', 127, C.m128i_u8[10]);
  CheckI32('packus_epi16[11]', 254, C.m128i_u8[11]);
  CheckI32('packus_epi16[12]', 255, C.m128i_u8[12]);
  CheckI32('packus_epi16[13]', 255, C.m128i_u8[13]);
  CheckI32('packus_epi16[14]', 255, C.m128i_u8[14]);
  CheckI32('packus_epi16[15]', 64, C.m128i_u8[15]);

  A := simd_setr_epi16(-32768, -200, 2, 128, 200, 250, 253, 254);
  B := simd_setr_epi16(255, 256, 257, 300, -5, 5, 15, 31);
  C := simd_packus_epi16(A, B);
  CheckI32('packus_epi16 second[0]', 0, C.m128i_u8[0]);
  CheckI32('packus_epi16 second[1]', 0, C.m128i_u8[1]);
  CheckI32('packus_epi16 second[2]', 2, C.m128i_u8[2]);
  CheckI32('packus_epi16 second[3]', 128, C.m128i_u8[3]);
  CheckI32('packus_epi16 second[4]', 200, C.m128i_u8[4]);
  CheckI32('packus_epi16 second[5]', 250, C.m128i_u8[5]);
  CheckI32('packus_epi16 second[6]', 253, C.m128i_u8[6]);
  CheckI32('packus_epi16 second[7]', 254, C.m128i_u8[7]);
  CheckI32('packus_epi16 second[8]', 255, C.m128i_u8[8]);
  CheckI32('packus_epi16 second[9]', 255, C.m128i_u8[9]);
  CheckI32('packus_epi16 second[10]', 255, C.m128i_u8[10]);
  CheckI32('packus_epi16 second[11]', 255, C.m128i_u8[11]);
  CheckI32('packus_epi16 second[12]', 0, C.m128i_u8[12]);
  CheckI32('packus_epi16 second[13]', 5, C.m128i_u8[13]);
  CheckI32('packus_epi16 second[14]', 15, C.m128i_u8[14]);
  CheckI32('packus_epi16 second[15]', 31, C.m128i_u8[15]);

  // --- Scalar double ops ---
  A := simd_set_pd(10.0, 5.0);
  B := simd_set_pd(20.0, 3.0);
  C := simd_add_sd(A, B);
  CheckF64('add_sd[0]', 8.0, C.m128d_f64[0]);
  CheckF64('add_sd[1] (preserved)', 10.0, C.m128d_f64[1]);

  A := simd_set_pd(-10.0, 5.0);
  B := simd_set_pd(7.0, -3.0);
  C := simd_add_sd(A, B);
  CheckF64('add_sd second[0]', 2.0, C.m128d_f64[0]);
  CheckF64('add_sd second[1]', -10.0, C.m128d_f64[1]);

  C := simd_sub_sd(A, B);
  CheckF64('sub_sd[0]', 8.0, C.m128d_f64[0]);
  CheckF64('sub_sd[1] (preserved)', -10.0, C.m128d_f64[1]);

  A := simd_set_pd(8.0, -4.0);
  B := simd_set_pd(6.0, 1.0);
  C := simd_sub_sd(A, B);
  CheckF64('sub_sd second[0]', -5.0, C.m128d_f64[0]);
  CheckF64('sub_sd second[1] (preserved)', 8.0, C.m128d_f64[1]);

  C := simd_mul_sd(A, B);
  CheckF64('mul_sd[0]', -4.0, C.m128d_f64[0]);
  CheckF64('mul_sd[1] (preserved)', 8.0, C.m128d_f64[1]);

  A := simd_set_pd(-10.0, 5.0);
  B := simd_set_pd(7.0, -3.0);
  C := simd_mul_sd(A, B);
  CheckF64('mul_sd second[0]', -15.0, C.m128d_f64[0]);
  CheckF64('mul_sd second[1] (preserved)', -10.0, C.m128d_f64[1]);

  A := simd_set_pd(3.0, 9.0);
  B := simd_set_pd(7.0, -3.0);
  C := simd_div_sd(A, B);
  CheckF64('div_sd[0]', -3.0, C.m128d_f64[0]);
  CheckF64('div_sd[1] (preserved)', 3.0, C.m128d_f64[1]);

  A := simd_set_pd(12.0, 9.0);
  B := simd_set_pd(4.0, 4.0);
  C := simd_div_sd(A, B);
  CheckF64('div_sd second[0]', 2.25, C.m128d_f64[0]);
  CheckF64('div_sd second[1] (preserved)', 12.0, C.m128d_f64[1]);

  C := simd_sqrt_sd(A, simd_set_pd(11.0, 49.0));
  CheckF64('sqrt_sd[0]', 7.0, C.m128d_f64[0]);
  CheckF64('sqrt_sd[1] (preserved)', 12.0, C.m128d_f64[1]);

  C := simd_sqrt_sd(B, simd_set_pd(99.0, 0.25));
  CheckF64('sqrt_sd second[0]', 0.5, C.m128d_f64[0]);
  CheckF64('sqrt_sd second[1] (preserved)', 4.0, C.m128d_f64[1]);

  C := simd_min_sd(A, B);
  CheckF64('min_sd[0]', 4.0, C.m128d_f64[0]);
  CheckF64('min_sd[1] (preserved)', 12.0, C.m128d_f64[1]);

  A := simd_set_pd(5.0, -6.0);
  B := simd_set_pd(1.0, -2.0);
  C := simd_min_sd(A, B);
  CheckF64('min_sd second[0]', -6.0, C.m128d_f64[0]);
  CheckF64('min_sd second[1] (preserved)', 5.0, C.m128d_f64[1]);

  C := simd_max_sd(A, B);
  CheckF64('max_sd[0]', -2.0, C.m128d_f64[0]);
  CheckF64('max_sd[1] (preserved)', 5.0, C.m128d_f64[1]);

  A := simd_set_pd(3.0, 9.0);
  B := simd_set_pd(7.0, -3.0);
  C := simd_max_sd(A, B);
  CheckF64('max_sd second[0]', 9.0, C.m128d_f64[0]);
  CheckF64('max_sd second[1] (preserved)', 3.0, C.m128d_f64[1]);

  A := simd_set_pd(100.0, 1.25);
  B := simd_set_pd(-50.0, -6.5);
  C := simd_move_sd(A, B);
  CheckF64('move_sd[0]', -6.5, C.m128d_f64[0]);
  CheckF64('move_sd[1]', 100.0, C.m128d_f64[1]);

  A := simd_set_pd(-8.0, 2.0);
  B := simd_set_pd(7.0, 3.5);
  C := simd_move_sd(A, B);
  CheckF64('move_sd second[0]', 3.5, C.m128d_f64[0]);
  CheckF64('move_sd second[1]', -8.0, C.m128d_f64[1]);

  // --- Set variants ---
  A := simd_set_epi32(4, 3, 2, 1);
  CheckI32('set_epi32[0]', 1, A.m128i_i32[0]);
  CheckI32('set_epi32[3]', 4, A.m128i_i32[3]);

  A := simd_setr_epi32(1, 2, 3, 4);
  CheckI32('setr_epi32[0]', 1, A.m128i_i32[0]);
  CheckI32('setr_epi32[3]', 4, A.m128i_i32[3]);

  A := simd_set1_epi64x(Int64($0102030405060708));
  if A.m128i_i64[0] = Int64($0102030405060708) then Inc(GPass)
  else begin WriteLn('FAIL: set1_epi64x'); Inc(GFail); end;
  if A.m128i_i64[1] = Int64($0102030405060708) then Inc(GPass)
  else begin WriteLn('FAIL: set1_epi64x[1]'); Inc(GFail); end;

  A := simd_set_epi64x(22, 11);
  CheckI64('set_epi64x[0]', 11, A.m128i_i64[0]);
  CheckI64('set_epi64x[1]', 22, A.m128i_i64[1]);

  A := simd_set_epi64x(Int64($0F0E0D0C0B0A0908), -1);
  CheckI64('set_epi64x second[0]', -1, A.m128i_i64[0]);
  CheckI64('set_epi64x second[1]', Int64($0F0E0D0C0B0A0908), A.m128i_i64[1]);

  // --- Multiply variants ---
  A := U32x4([3, 123456, 4096, 987654]);
  B := U32x4([5, 777, 11, 333]);
  C := simd_mul_epu32(A, B);
  CheckU64('mul_epu32 even32[0]', 15, C.m128i_u64[0]);
  CheckU64('mul_epu32 even32[1]', 45056, C.m128i_u64[1]);

  A := U32x4([QWord($FFFFFFFF), QWord($EEEEEEEE), QWord($80000000), QWord($DDDDDDDD)]);
  B := U32x4([2, QWord($CCCCCCCC), 3, QWord($BBBBBBBB)]);
  C := simd_mul_epu32(A, B);
  CheckU64('mul_epu32 unsigned[0]', QWord($FFFFFFFF) * 2, C.m128i_u64[0]);
  CheckU64('mul_epu32 unsigned[1]', QWord($80000000) * 3, C.m128i_u64[1]);

  A := simd_set1_epi16(100);
  B := simd_set1_epi16(200);
  C := simd_mullo_epi16(A, B);
  // 100*200 = 20000, fits in 16-bit
  if C.m128i_i16[0] = 20000 then Inc(GPass)
  else begin WriteLn('FAIL: mullo_epi16 ', C.m128i_i16[0]); Inc(GFail); end;

  A := simd_setr_epi16(300, -300, 32767, -32768, 12345, -12345, 256, -256);
  B := simd_setr_epi16(300, 300, 2, 2, -2, -2, 257, 257);
  C := simd_mullo_epi16(A, B);
  CheckU16x8('mullo_epi16 wrap', C, [24464, 41072, 65534, 0, 40846, 24690, 256, 65280]);

  A := simd_setr_epi16(30000, -30000, 32767, -32768, -32768, 200, -1, 1);
  B := simd_setr_epi16(3, 3, 32767, 32767, -32768, -200, 32767, -32768);
  C := simd_mulhi_epi16(A, B);
  CheckMaskI16x8('mulhi_epi16 signed', C, [1, -2, 16383, -16384, 16384, -1, -1, -1]);

  A := simd_setr_epi16(12345, -12345, 1000, -1000, 256, -256, 32767, -32768);
  B := simd_setr_epi16(4, 4, -65, -65, 257, 257, 2, 2);
  C := simd_mulhi_epi16(A, B);
  CheckMaskI16x8('mulhi_epi16 mixed', C, [0, -1, -1, 0, 1, -2, 0, -1]);

  A := U16x8([65535, 65535, 32768, $1234, $00FF, $FF00, $AAAA, $8001]);
  B := U16x8([65535, 2, 32768, $1000, $0101, $0100, 3, 2]);
  C := simd_mulhi_epu16(A, B);
  CheckU16x8('mulhi_epu16 unsigned', C, [65534, 1, 16384, $0123, 0, $00FF, 1, 1]);

  A := U16x8([40000, 50000, 60000, 12345, 65535, 32769, 256, 1]);
  B := U16x8([4, 4, 4, 4096, 16, 2, 255, 65535]);
  C := simd_mulhi_epu16(A, B);
  CheckU16x8('mulhi_epu16 mixed', C, [2, 3, 3, 771, 15, 1, 0, 0]);

  A := simd_setr_epi16(1, 2, -3, 4, 30000, -30000, -32768, 32767);
  B := simd_setr_epi16(10, 20, 30, -40, 2, 3, -1, -1);
  C := simd_madd_epi16(A, B);
  CheckMaskI32x4('madd_epi16 signed-pairs', C, [50, -250, -30000, 1]);

  A := simd_setr_epi16(-100, 200, -300, 400, 1234, -1234, 32767, -32768);
  B := simd_setr_epi16(-5, -6, -7, -8, -9, -10, 1, 1);
  C := simd_madd_epi16(A, B);
  CheckMaskI32x4('madd_epi16 mixed-pairs', C, [-700, -1100, 1234, -1]);

  A := U8x16([0, 10, 20, 30, 40, 50, 60, 70, 255, 200, 100, 0, 5, 6, 7, 8]);
  B := U8x16([0, 5, 25, 10, 80, 45, 60, 100, 0, 100, 150, 10, 5, 9, 1, 18]);
  C := simd_sad_epu8(A, B);
  CheckU64('sad_epu8 low-half', 105, C.m128i_u64[0]);
  CheckU64('sad_epu8 high-half', 434, C.m128i_u64[1]);

  A := U8x16([0, 0, 0, 0, 0, 0, 0, 0, 10, 10, 10, 10, 10, 10, 10, 10]);
  B := U8x16([1, 2, 3, 4, 5, 6, 7, 8, 0, 20, 10, 30, 5, 15, 100, 110]);
  C := simd_sad_epu8(A, B);
  CheckU64('sad_epu8 second low-half', 36, C.m128i_u64[0]);
  CheckU64('sad_epu8 second high-half', 240, C.m128i_u64[1]);

  // --- Average ---
  A := simd_set1_epi8(ShortInt(10));
  B := simd_set1_epi8(ShortInt(20));
  C := simd_avg_epu8(A, B);
  if Byte(C.m128i_i8[0]) = 15 then Inc(GPass)
  else begin WriteLn('FAIL: avg_epu8 ', Byte(C.m128i_i8[0])); Inc(GFail); end;

  // --- Edge cases: zero arithmetic ---
  A := simd_setzero_ps;
  B := simd_set1_ps(5.0);
  C := simd_add_ps(A, B);
  CheckF32('add_ps zero+5', 5.0, C.m128_f32[0]);
  C := simd_mul_ps(A, B);
  CheckF32('mul_ps zero*5', 0.0, C.m128_f32[0]);

  // --- Edge: shift by 0 ---
  A := simd_set1_epi32(42);
  C := simd_slli_epi32(A, 0);
  CheckI32('slli_epi32 shift0', 42, C.m128i_i32[0]);

  // --- Edge: shift by 31 ---
  A := simd_set1_epi32(1);
  C := simd_slli_epi32(A, 31);
  CheckI32('slli_epi32 shift31', Int32($80000000), C.m128i_i32[0]);

  // --- Edge: sub self = zero ---
  A := simd_set1_epi32(999);
  C := simd_sub_epi32(A, A);
  CheckI32('sub_epi32 self', 0, C.m128i_i32[0]);

  // --- Edge: xor self = zero ---
  A := simd_set1_epi32(Int32($DEADBEEF));
  C := simd_xor_si128(A, A);
  CheckI32('xor self', 0, C.m128i_i32[0]);

  // --- Edge: andnot ---
  A := simd_set1_epi32(Int32($FF00FF00));
  B := simd_set1_epi32(Int32($FFFFFFFF));
  C := simd_andnot_si128(A, B);
  CheckI32('andnot', Int32($00FF00FF), C.m128i_i32[0]);

  A := simd_setr_epi32(Int32($F0F0FFFF), Int32($0000FFFF), Int32($AAAAAAAA), Int32($0F0F0F0F));
  B := simd_setr_epi32(Int32($FFFF0F0F), Int32($FFFFFFFF), Int32($FFFFFFFF), Int32($33333333));
  C := simd_andnot_si128(A, B);
  CheckI32('andnot second[0]', Int32($0F0F0000), C.m128i_i32[0]);
  CheckI32('andnot second[1]', Int32($FFFF0000), C.m128i_i32[1]);
  CheckI32('andnot second[2]', Int32($55555555), C.m128i_i32[2]);
  CheckI32('andnot second[3]', Int32($30303030), C.m128i_i32[3]);

  // --- 64-bit integer ---
  A := simd_set1_epi64x(1000000000000);
  B := simd_set1_epi64x(2000000000000);
  C := simd_add_epi64(A, B);
  if C.m128i_i64[0] = 3000000000000 then Inc(GPass)
  else begin WriteLn('FAIL: add_epi64 ', C.m128i_i64[0]); Inc(GFail); end;

  // --- Movemask pd ---
  A := simd_set_pd(-1.0, 1.0);
  CheckI32('movemask_pd', 2, simd_movemask_pd(A)); // only high lane negative
  A := simd_set_pd(-2.0, -1.0);
  CheckI32('movemask_pd both-neg', 3, simd_movemask_pd(A));

  // --- Load/Store roundtrip (si128) ---
  DataI32[0] := 11; DataI32[1] := 22; DataI32[2] := 33; DataI32[3] := 44;
  A := simd_loadu_si128(@DataI32[0]);
  CheckI32('loadu_si128[0]', 11, A.m128i_i32[0]);
  CheckI32('loadu_si128[3]', 44, A.m128i_i32[3]);
  DataI32[0] := 0; DataI32[1] := 0; DataI32[2] := 0; DataI32[3] := 0;
  simd_storeu_si128(DataI32[0], A);
  CheckI32('storeu_si128 rt[0]', 11, DataI32[0]);
  CheckI32('storeu_si128 rt[3]', 44, DataI32[3]);

  // --- Summary ---
  WriteLn;
  AlignedFree(AlignedF32);
  AlignedFree(AlignedF64);
  AlignedFree(AlignedM128);
  AlignedFree(MaskedBytes);
  if GFail = 0 then
  begin
    WriteLn('RAW LEAF PARITY OK: ', GPass, ' checks passed');
    WriteLn('  SSE2 intrinsics.x86.sse2 raw leaf produces correct results.');
    WriteLn('  This is evidence toward promoting it from experimental-isolated to active-leaf.');
  end
  else
  begin
    WriteLn('RAW LEAF PARITY FAILED: ', GPass, ' passed, ', GFail, ' failed');
    Halt(1);
  end;
end.
