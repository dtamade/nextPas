program nextpas.core.simd.avx512_verify;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils, Math,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch;

const
  MAX_COUNT = 129;
  TOLERANCE = 1e-5;

var
  g_TotalChecks: Integer = 0;
  g_Failures: Integer = 0;

procedure Fail(const aMsg: string);
begin
  WriteLn('[FAIL] ', aMsg);
  Inc(g_Failures);
end;

procedure CheckNear(const aCtx: string; aExpected, aActual: Single; aTol: Single = TOLERANCE);
var LScale: Single;
begin
  Inc(g_TotalChecks);
  LScale := Max(Abs(aExpected), 1e-7);
  if Abs(aExpected - aActual) > aTol * LScale then
    Fail(Format('%s: expected %.8g got %.8g (diff=%.8g)',
      [aCtx, aExpected, aActual, aActual - aExpected]));
end;

procedure TestArithmetic;
var
  LSrc1, LSrc2, LDst, LRef: array[0..MAX_COUNT-1] of Single;
  LCounts: array[0..8] of SizeUInt = (1, 4, 7, 8, 15, 16, 32, 64, 129);
  ci, i: Integer;
  LCount: SizeUInt;
begin
  for i := 0 to MAX_COUNT - 1 do
  begin
    LSrc1[i] := Sin(i * 0.7) * 100.0 - 50.0;
    LSrc2[i] := Cos(i * 1.3) * 30.0 + 1.0;
  end;

  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];

    // Add
    for i := 0 to Integer(LCount) - 1 do LRef[i] := LSrc1[i] + LSrc2[i];
    FillChar(LDst, SizeOf(LDst), 0);
    ArrayAddF32(@LSrc1[0], @LSrc2[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckNear(Format('Add[%d,i=%d]', [LCount, i]), LRef[i], LDst[i]);

    // Sub
    for i := 0 to Integer(LCount) - 1 do LRef[i] := LSrc1[i] - LSrc2[i];
    FillChar(LDst, SizeOf(LDst), 0);
    ArraySubF32(@LSrc1[0], @LSrc2[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckNear(Format('Sub[%d,i=%d]', [LCount, i]), LRef[i], LDst[i]);

    // Mul
    for i := 0 to Integer(LCount) - 1 do LRef[i] := LSrc1[i] * LSrc2[i];
    FillChar(LDst, SizeOf(LDst), 0);
    ArrayMulF32(@LSrc1[0], @LSrc2[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckNear(Format('Mul[%d,i=%d]', [LCount, i]), LRef[i], LDst[i]);

    // Div
    for i := 0 to Integer(LCount) - 1 do LRef[i] := LSrc1[i] / LSrc2[i];
    FillChar(LDst, SizeOf(LDst), 0);
    ArrayDivF32(@LSrc1[0], @LSrc2[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckNear(Format('Div[%d,i=%d]', [LCount, i]), LRef[i], LDst[i]);
  end;
  WriteLn('  Arithmetic (Add/Sub/Mul/Div): checked');
end;

procedure TestUnary;
var
  LSrc, LDst, LRef: array[0..MAX_COUNT-1] of Single;
  LCounts: array[0..6] of SizeUInt = (1, 4, 8, 15, 16, 64, 129);
  ci, i: Integer;
  LCount: SizeUInt;
begin
  for i := 0 to MAX_COUNT - 1 do
    LSrc[i] := Sin(i * 0.5) * 50.0;

  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];

    // Abs
    for i := 0 to Integer(LCount) - 1 do LRef[i] := Abs(LSrc[i]);
    FillChar(LDst, SizeOf(LDst), 0);
    ArrayAbsF32(@LSrc[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckNear(Format('Abs[%d,i=%d]', [LCount, i]), LRef[i], LDst[i]);

    // Neg
    for i := 0 to Integer(LCount) - 1 do LRef[i] := -LSrc[i];
    FillChar(LDst, SizeOf(LDst), 0);
    ArrayNegF32(@LSrc[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckNear(Format('Neg[%d,i=%d]', [LCount, i]), LRef[i], LDst[i]);

    // Sqrt (positive values only)
    for i := 0 to Integer(LCount) - 1 do LSrc[i] := Abs(LSrc[i]) + 0.01;
    for i := 0 to Integer(LCount) - 1 do LRef[i] := System.Sqrt(LSrc[i]);
    FillChar(LDst, SizeOf(LDst), 0);
    ArraySqrtF32(@LSrc[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckNear(Format('Sqrt[%d,i=%d]', [LCount, i]), LRef[i], LDst[i]);
  end;
  WriteLn('  Unary (Abs/Neg/Sqrt): checked');
end;

procedure TestLargeArray;
const
  N = 1048576;
  GUARD = $CD;
var
  LBuf: PByte;
  LSrc1, LSrc2, LDst: PSingle;
  i: SizeUInt;
  LGuardOK: Boolean;
begin
  LBuf := GetMem(N * 4 * 3 + 128);
  FillChar(LBuf^, N * 4 * 3 + 128, GUARD);
  LSrc1 := PSingle(LBuf + 64);
  LSrc2 := PSingle(PByte(LSrc1) + N * 4);
  LDst := PSingle(PByte(LSrc2) + N * 4);

  for i := 0 to N - 1 do
  begin
    LSrc1[i] := Sin(i * 0.001) * 100;
    LSrc2[i] := Cos(i * 0.001) * 50 + 1;
  end;

  ArrayAddF32(LSrc1, LSrc2, LDst, N);
  ArrayMulF32(LSrc1, LSrc2, LDst, N);
  ArrayAbsF32(LSrc1, LDst, N);
  ArraySqrtF32(LDst, LDst, N);

  // Check guard bytes
  LGuardOK := True;
  for i := 0 to 63 do
    if LBuf[i] <> GUARD then begin LGuardOK := False; Break; end;

  Inc(g_TotalChecks);
  if not LGuardOK then
    Fail('Large array: guard bytes overwritten (buffer overflow!)')
  else
    WriteLn('  Large array (N=1M): no overflow detected');

  FreeMem(LBuf);
end;

begin
  WriteLn('=== AVX-512 Batch Correctness Verification ===');
  WriteLn('');
  WriteLn('Backend: ', GetBackendInfo(GetActiveBackend).Name);

  // 检测 CPU 指令集支持
  WriteLn('');
  WriteLn('CPU Feature Detection:');
  WriteLn('  SSE2:    ', BoolToStr(IsBackendRegistered(sbSSE2), 'YES', 'NO'));
  WriteLn('  AVX2:    ', BoolToStr(IsBackendRegistered(sbAVX2), 'YES', 'NO'));
  WriteLn('  AVX-512: ', BoolToStr(IsBackendRegistered(sbAVX512), 'YES', 'NO'));
  WriteLn('');

  if not IsBackendRegistered(sbAVX512) then
  begin
    WriteLn('[ERROR] This CPU does NOT support AVX-512!');
    WriteLn('        This test requires AVX-512F hardware.');
    WriteLn('        Detected backend: ', GetBackendInfo(GetActiveBackend).Name);
    WriteLn('');
    WriteLn('[RESULT] SKIPPED (no AVX-512)');
    Halt(2);
  end;

  if GetActiveBackend <> sbAVX512 then
  begin
    WriteLn('[WARN] AVX-512 registered but not active. Forcing...');
    if not TrySetActiveBackend(sbAVX512) then
    begin
      WriteLn('[ERROR] Failed to activate AVX-512 backend!');
      Halt(2);
    end;
    WriteLn('  Backend now: ', GetBackendInfo(GetActiveBackend).Name);
    WriteLn('');
  end;

  TestArithmetic;
  TestUnary;
  TestLargeArray;

  WriteLn('');
  WriteLn(Format('[SUMMARY] checks=%d failures=%d', [g_TotalChecks, g_Failures]));
  if g_Failures > 0 then
  begin
    WriteLn('[RESULT] FAIL');
    Halt(1);
  end;
  WriteLn('[RESULT] PASS');
end.
