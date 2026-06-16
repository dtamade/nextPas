program nextpas.core.simd.convert_bitwise;

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
  MAX_COUNT = 65;

var
  g_TotalChecks: Integer = 0;
  g_Failures: Integer = 0;

procedure Fail(const aMsg: string);
begin
  WriteLn('[FAIL] ', aMsg);
  Inc(g_Failures);
end;

procedure CheckI32(const aCtx: string; aExpected, aActual: Int32);
begin
  Inc(g_TotalChecks);
  if aExpected <> aActual then
    Fail(Format('%s: expected %d got %d', [aCtx, aExpected, aActual]));
end;

procedure CheckF32(const aCtx: string; aExpected, aActual: Single);
begin
  Inc(g_TotalChecks);
  if Abs(aExpected - aActual) > 0.5 then
    Fail(Format('%s: expected %.6g got %.6g', [aCtx, aExpected, aActual]));
end;

procedure TestF32toI32;
var
  LSrc: array[0..MAX_COUNT-1] of Single;
  LDst: array[0..MAX_COUNT-1] of Int32;
  LCounts: array[0..6] of SizeUInt = (1, 4, 7, 8, 16, 32, 65);
  ci, i: Integer;
  LCount: SizeUInt;
begin
  for i := 0 to MAX_COUNT - 1 do
    LSrc[i] := (i - 32) * 1.7;

  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];
    FillChar(LDst, SizeOf(LDst), 0);
    ArrayF32toI32(@LSrc[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckI32(Format('F32toI32[count=%d,i=%d]', [LCount, i]),
        Round(LSrc[i]), LDst[i]);
  end;
  WriteLn('  ArrayF32toI32: checked');
end;

procedure TestI32toF32;
var
  LSrc: array[0..MAX_COUNT-1] of Int32;
  LDst: array[0..MAX_COUNT-1] of Single;
  LCounts: array[0..6] of SizeUInt = (1, 4, 7, 8, 16, 32, 65);
  ci, i: Integer;
  LCount: SizeUInt;
begin
  for i := 0 to MAX_COUNT - 1 do
    LSrc[i] := (i - 32) * 1000;

  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];
    FillChar(LDst, SizeOf(LDst), 0);
    ArrayI32toF32(@LSrc[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckF32(Format('I32toF32[count=%d,i=%d]', [LCount, i]),
        Single(LSrc[i]), LDst[i]);
  end;
  WriteLn('  ArrayI32toF32: checked');
end;

procedure TestBitwise;
var
  LSrc1, LSrc2, LDst: array[0..MAX_COUNT-1] of Int32;
  LCounts: array[0..6] of SizeUInt = (1, 4, 7, 8, 16, 32, 65);
  ci, i: Integer;
  LCount: SizeUInt;
begin
  for i := 0 to MAX_COUNT - 1 do
  begin
    LSrc1[i] := Int32($DEADBEEF xor (i * $01010101));
    LSrc2[i] := Int32($CAFEBABE xor (i * $10101010));
  end;

  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];

    FillChar(LDst, SizeOf(LDst), 0);
    ArrayAndI32(@LSrc1[0], @LSrc2[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckI32(Format('And[count=%d,i=%d]', [LCount, i]),
        LSrc1[i] and LSrc2[i], LDst[i]);

    FillChar(LDst, SizeOf(LDst), 0);
    ArrayOrI32(@LSrc1[0], @LSrc2[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckI32(Format('Or[count=%d,i=%d]', [LCount, i]),
        LSrc1[i] or LSrc2[i], LDst[i]);

    FillChar(LDst, SizeOf(LDst), 0);
    ArrayXorI32(@LSrc1[0], @LSrc2[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckI32(Format('Xor[count=%d,i=%d]', [LCount, i]),
        LSrc1[i] xor LSrc2[i], LDst[i]);
  end;
  WriteLn('  ArrayAnd/Or/XorI32: checked');
end;

procedure TestShift;
var
  LSrc, LDst: array[0..MAX_COUNT-1] of Int32;
  LCounts: array[0..5] of SizeUInt = (1, 4, 8, 16, 32, 65);
  LShifts: array[0..3] of Integer = (0, 1, 8, 16);
  ci, si, i: Integer;
  LCount: SizeUInt;
begin
  for i := 0 to MAX_COUNT - 1 do
    LSrc[i] := Int32((i - 32) * $10001);

  for ci := 0 to High(LCounts) do
    for si := 0 to High(LShifts) do
    begin
      LCount := LCounts[ci];

      FillChar(LDst, SizeOf(LDst), 0);
      ArrayShlI32(@LSrc[0], @LDst[0], LCount, LShifts[si]);
      for i := 0 to Integer(LCount) - 1 do
        CheckI32(Format('Shl[count=%d,shift=%d,i=%d]', [LCount, LShifts[si], i]),
          LSrc[i] shl LShifts[si], LDst[i]);

      FillChar(LDst, SizeOf(LDst), 0);
      ArrayShrI32(@LSrc[0], @LDst[0], LCount, LShifts[si]);
      for i := 0 to Integer(LCount) - 1 do
        CheckI32(Format('Shr[count=%d,shift=%d,i=%d]', [LCount, LShifts[si], i]),
          SarLongint(LSrc[i], LShifts[si]), LDst[i]);
    end;
  WriteLn('  ArrayShl/ShrI32: checked');
end;

begin
  WriteLn('[Convert + Bitwise Batch Correctness]');
  WriteLn('Backend: ', GetBackendInfo(GetActiveBackend).Name);
  WriteLn('');

  TestF32toI32;
  TestI32toF32;
  TestBitwise;
  TestShift;

  WriteLn('');
  WriteLn(Format('[SUMMARY] checks=%d failures=%d', [g_TotalChecks, g_Failures]));
  if g_Failures > 0 then
  begin
    WriteLn('[RESULT] FAIL');
    Halt(1);
  end;
  WriteLn('[RESULT] PASS');
end.
