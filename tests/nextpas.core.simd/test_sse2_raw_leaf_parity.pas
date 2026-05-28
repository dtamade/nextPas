program test_sse2_raw_leaf_parity;
{$MODE OBJFPC}{$H+}
{$I ../../src/nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Math,
  nextpas.core.simd.intrinsics.base,
  nextpas.core.simd.intrinsics.x86.sse2;

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

procedure CheckF64(const aName: string; aExpected, aActual: Double);
begin
  if Abs(aExpected - aActual) < 1e-12 then Inc(GPass)
  else begin
    WriteLn('FAIL: ', aName, ' expected=', aExpected:0:10, ' got=', aActual:0:10);
    Inc(GFail);
  end;
end;

var
  A, B, C: TM128;
  DataF32: array[0..3] of Single;
  DataI32: array[0..3] of Int32;
  DataF64: array[0..1] of Double;
begin
  WriteLn('=== SSE2 Raw Leaf (intrinsics.x86.sse2) Parity Test ===');
  WriteLn;

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

  // --- Set/Zero ---
  A := simd_setzero_ps;
  CheckF32('setzero_ps[0]', 0.0, A.m128_f32[0]);
  CheckF32('setzero_ps[3]', 0.0, A.m128_f32[3]);

  A := simd_set1_ps(3.14);
  CheckF32('set1_ps[0]', 3.14, A.m128_f32[0]);
  CheckF32('set1_ps[2]', 3.14, A.m128_f32[2]);

  A := simd_set1_epi32(42);
  CheckI32('set1_epi32[0]', 42, A.m128i_i32[0]);
  CheckI32('set1_epi32[3]', 42, A.m128i_i32[3]);

  // --- Arithmetic (F32) ---
  A := simd_set1_ps(3.0);
  B := simd_set1_ps(2.0);
  C := simd_add_ps(A, B);
  CheckF32('add_ps', 5.0, C.m128_f32[0]);

  C := simd_sub_ps(A, B);
  CheckF32('sub_ps', 1.0, C.m128_f32[0]);

  C := simd_mul_ps(A, B);
  CheckF32('mul_ps', 6.0, C.m128_f32[0]);

  C := simd_div_ps(A, B);
  CheckF32('div_ps', 1.5, C.m128_f32[0]);

  // --- Arithmetic (F64) ---
  DataF64[0] := 10.0; DataF64[1] := 20.0;
  A := simd_load_pd(@DataF64[0]);
  CheckF64('load_pd[0]', 10.0, A.m128d_f64[0]);
  CheckF64('load_pd[1]', 20.0, A.m128d_f64[1]);

  B := simd_set1_pd(5.0);
  C := simd_add_pd(A, B);
  CheckF64('add_pd[0]', 15.0, C.m128d_f64[0]);
  CheckF64('add_pd[1]', 25.0, C.m128d_f64[1]);

  C := simd_mul_pd(A, B);
  CheckF64('mul_pd[0]', 50.0, C.m128d_f64[0]);
  CheckF64('mul_pd[1]', 100.0, C.m128d_f64[1]);

  // --- Integer Arithmetic ---
  A := simd_set1_epi32(10);
  B := simd_set1_epi32(3);
  C := simd_add_epi32(A, B);
  CheckI32('add_epi32', 13, C.m128i_i32[0]);

  C := simd_sub_epi32(A, B);
  CheckI32('sub_epi32', 7, C.m128i_i32[0]);

  // --- Bitwise ---
  DataI32[0] := $FF00FF00; DataI32[1] := $FF00FF00; DataI32[2] := $FF00FF00; DataI32[3] := $FF00FF00;
  A := simd_load_si128(@DataI32[0]);
  DataI32[0] := $0F0F0F0F; DataI32[1] := $0F0F0F0F; DataI32[2] := $0F0F0F0F; DataI32[3] := $0F0F0F0F;
  B := simd_load_si128(@DataI32[0]);

  C := simd_and_si128(A, B);
  CheckI32('and_si128', Int32($0F000F00), C.m128i_i32[0]);

  C := simd_or_si128(A, B);
  CheckI32('or_si128', Int32($FF0FFF0F), C.m128i_i32[0]);

  C := simd_xor_si128(A, B);
  CheckI32('xor_si128', Int32($F00FF00F), C.m128i_i32[0]);

  // --- Shift ---
  A := simd_set1_epi32(8);
  C := simd_slli_epi32(A, 2);
  CheckI32('slli_epi32', 32, C.m128i_i32[0]);

  C := simd_srli_epi32(A, 1);
  CheckI32('srli_epi32', 4, C.m128i_i32[0]);

  // --- Compare ---
  A := simd_set1_epi32(5);
  B := simd_set1_epi32(5);
  C := simd_cmpeq_epi32(A, B);
  CheckI32('cmpeq_epi32 (equal)', Int32($FFFFFFFF), C.m128i_i32[0]);

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

  A := simd_set1_epi8(10);
  B := simd_set1_epi8(5);
  C := simd_cmpgt_epi8(A, B);
  CheckI32('cmpgt_epi8 (10>5)', Int32($FFFFFFFF), C.m128i_i32[0]);

  // --- Float Compare (pd) ---
  A := simd_set1_pd(3.0);
  B := simd_set1_pd(5.0);
  C := simd_cmplt_pd(A, B);
  CheckI32('cmplt_pd (3<5) lo', Int32($FFFFFFFF), C.m128i_i32[0]);
  CheckI32('cmplt_pd (3<5) hi-lo', Int32($FFFFFFFF), C.m128i_i32[1]);

  C := simd_cmpeq_pd(A, A);
  CheckI32('cmpeq_pd (self)', Int32($FFFFFFFF), C.m128i_i32[0]);

  // --- Saturating Arithmetic ---
  A := simd_set1_epi16(32000);
  B := simd_set1_epi16(32000);
  C := simd_adds_epi16(A, B);
  // Saturated: 32000+32000 should clamp to 32767
  if C.m128i_i16[0] = 32767 then Inc(GPass) else begin WriteLn('FAIL: adds_epi16 sat'); Inc(GFail); end;

  A := simd_set1_epi16(-32000);
  B := simd_set1_epi16(-32000);
  C := simd_adds_epi16(A, B);
  if C.m128i_i16[0] = -32768 then Inc(GPass) else begin WriteLn('FAIL: adds_epi16 neg sat'); Inc(GFail); end;

  A := simd_set1_epi8(120);
  B := simd_set1_epi8(120);
  C := simd_adds_epi8(A, B);
  if C.m128i_i8[0] = 127 then Inc(GPass) else begin WriteLn('FAIL: adds_epi8 sat'); Inc(GFail); end;

  // --- Unsigned Saturating ---
  A := simd_set1_epi8(ShortInt(200));
  B := simd_set1_epi8(ShortInt(200));
  C := simd_adds_epu8(A, B);
  if Byte(C.m128i_i8[0]) = 255 then Inc(GPass) else begin WriteLn('FAIL: adds_epu8 sat ', Byte(C.m128i_i8[0])); Inc(GFail); end;

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

  C := simd_max_pd(simd_set1_pd(2.5), simd_set1_pd(4.5));
  CheckF64('max_pd', 4.5, C.m128d_f64[0]);
  C := simd_min_pd(simd_set1_pd(2.5), simd_set1_pd(4.5));
  CheckF64('min_pd', 2.5, C.m128d_f64[0]);

  // --- Sqrt ---
  A := simd_set1_ps(16.0);
  C := simd_sqrt_ps(A);
  CheckF32('sqrt_ps', 4.0, C.m128_f32[0]);

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

  // --- Shuffle ---
  A := simd_set_epi32(40, 30, 20, 10);
  C := simd_shuffle_epi32(A, $E4); // identity: 3,2,1,0 = $E4
  CheckI32('shuffle_epi32 identity[0]', 10, C.m128i_i32[0]);
  CheckI32('shuffle_epi32 identity[3]', 40, C.m128i_i32[3]);

  C := simd_shuffle_epi32(A, $00); // broadcast lane 0
  CheckI32('shuffle_epi32 broadcast[0]', 10, C.m128i_i32[0]);
  CheckI32('shuffle_epi32 broadcast[3]', 10, C.m128i_i32[3]);

  // --- Movemask ---
  A := simd_set_epi32(Int32($80000000), 0, Int32($80000000), 0);
  CheckI32('movemask_ps', $A, simd_movemask_ps(A)); // bits 3,1 set

  A := simd_set1_epi8(ShortInt($80));
  CheckI32('movemask_epi8 all-neg', $FFFF, simd_movemask_epi8(A));

  A := simd_set1_epi8(0);
  CheckI32('movemask_epi8 all-zero', 0, simd_movemask_epi8(A));

  // --- Convert ---
  A := simd_set_epi32(4, 3, 2, 1);
  C := simd_cvtepi32_ps(A);
  CheckF32('cvtepi32_ps[0]', 1.0, C.m128_f32[0]);
  CheckF32('cvtepi32_ps[3]', 4.0, C.m128_f32[3]);

  A := simd_set1_ps(3.7);
  C := simd_cvtps_epi32(A);
  CheckI32('cvtps_epi32 (round)', 4, C.m128i_i32[0]);

  C := simd_cvttps_epi32(A);
  CheckI32('cvttps_epi32 (trunc)', 3, C.m128i_i32[0]);

  CheckI32('cvtsi128_si32', 42, simd_cvtsi128_si32(simd_set1_epi32(42)));

  // --- Scalar double ops ---
  A := simd_set_pd(10.0, 5.0);
  B := simd_set_pd(20.0, 3.0);
  C := simd_add_sd(A, B);
  CheckF64('add_sd[0]', 8.0, C.m128d_f64[0]);
  CheckF64('add_sd[1] (preserved)', 10.0, C.m128d_f64[1]);

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

  // --- Multiply variants ---
  A := simd_set1_epi16(100);
  B := simd_set1_epi16(200);
  C := simd_mullo_epi16(A, B);
  // 100*200 = 20000, fits in 16-bit
  if C.m128i_i16[0] = 20000 then Inc(GPass)
  else begin WriteLn('FAIL: mullo_epi16 ', C.m128i_i16[0]); Inc(GFail); end;

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

  // --- 64-bit integer ---
  A := simd_set1_epi64x(1000000000000);
  B := simd_set1_epi64x(2000000000000);
  C := simd_add_epi64(A, B);
  if C.m128i_i64[0] = 3000000000000 then Inc(GPass)
  else begin WriteLn('FAIL: add_epi64 ', C.m128i_i64[0]); Inc(GFail); end;

  // --- Movemask pd ---
  A := simd_set_pd(-1.0, 1.0);
  CheckI32('movemask_pd', 2, simd_movemask_pd(A)); // only high lane negative

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
