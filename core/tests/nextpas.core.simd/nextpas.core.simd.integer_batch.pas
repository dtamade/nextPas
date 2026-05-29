program nextpas.core.simd.integer_batch;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils,
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

procedure CheckI16(const aCtx: string; aExpected, aActual: Int16);
begin
  Inc(g_TotalChecks);
  if aExpected <> aActual then
    Fail(Format('%s: expected %d got %d', [aCtx, aExpected, aActual]));
end;

procedure TestArrayAddI32;
var
  LSrc1, LSrc2, LDst: array[0..MAX_COUNT-1] of Int32;
  LCounts: array[0..7] of SizeUInt = (0, 1, 4, 7, 8, 16, 32, 65);
  ci, i: Integer;
  LCount: SizeUInt;
begin
  for i := 0 to MAX_COUNT - 1 do
  begin
    LSrc1[i] := (i - 30) * 1000;
    LSrc2[i] := (i * 7) - 200;
  end;

  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];
    FillChar(LDst, SizeOf(LDst), 0);
    ArrayAddI32(@LSrc1[0], @LSrc2[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckI32(Format('AddI32[count=%d,i=%d]', [LCount, i]),
        LSrc1[i] + LSrc2[i], LDst[i]);
  end;
  WriteLn('  ArrayAddI32: checked');
end;

procedure TestArraySubI32;
var
  LSrc1, LSrc2, LDst: array[0..MAX_COUNT-1] of Int32;
  LCounts: array[0..7] of SizeUInt = (0, 1, 4, 7, 8, 16, 32, 65);
  ci, i: Integer;
  LCount: SizeUInt;
begin
  for i := 0 to MAX_COUNT - 1 do
  begin
    LSrc1[i] := i * 12345;
    LSrc2[i] := (MAX_COUNT - i) * 6789;
  end;

  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];
    FillChar(LDst, SizeOf(LDst), 0);
    ArraySubI32(@LSrc1[0], @LSrc2[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckI32(Format('SubI32[count=%d,i=%d]', [LCount, i]),
        LSrc1[i] - LSrc2[i], LDst[i]);
  end;
  WriteLn('  ArraySubI32: checked');
end;

procedure TestArrayMulI16;
var
  LSrc1, LSrc2, LDst: array[0..MAX_COUNT-1] of Int16;
  LCounts: array[0..7] of SizeUInt = (0, 1, 4, 8, 15, 16, 32, 65);
  ci, i: Integer;
  LCount: SizeUInt;
begin
  for i := 0 to MAX_COUNT - 1 do
  begin
    LSrc1[i] := Int16((i - 32) * 3);
    LSrc2[i] := Int16((i mod 10) - 5);
  end;

  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];
    FillChar(LDst, SizeOf(LDst), 0);
    ArrayMulI16(@LSrc1[0], @LSrc2[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckI16(Format('MulI16[count=%d,i=%d]', [LCount, i]),
        Int16(Int32(LSrc1[i]) * Int32(LSrc2[i])), LDst[i]);
  end;
  WriteLn('  ArrayMulI16: checked');
end;

procedure TestArrayPackSatI32toI16;
var
  LSrc: array[0..MAX_COUNT-1] of Int32;
  LDst: array[0..MAX_COUNT-1] of Int16;
  LCounts: array[0..6] of SizeUInt = (1, 4, 8, 15, 16, 32, 65);
  ci, i: Integer;
  LCount: SizeUInt;
  LExpected: Int16;
  v: Int32;
begin
  for i := 0 to MAX_COUNT - 1 do
    LSrc[i] := (i - 32) * 2000;
  LSrc[0] := 100000;
  LSrc[1] := -100000;
  LSrc[2] := 32767;
  LSrc[3] := -32768;
  LSrc[4] := 0;

  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];
    FillChar(LDst, SizeOf(LDst), 0);
    ArrayPackSatI32toI16(@LSrc[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
    begin
      v := LSrc[i];
      if v > 32767 then LExpected := 32767
      else if v < -32768 then LExpected := -32768
      else LExpected := Int16(v);
      CheckI16(Format('PackSat[count=%d,i=%d,src=%d]', [LCount, i, LSrc[i]]),
        LExpected, LDst[i]);
    end;
  end;
  WriteLn('  ArrayPackSatI32toI16: checked');
end;

begin
  WriteLn('[Integer Batch Correctness]');
  WriteLn('Backend: ', GetBackendInfo(GetActiveBackend).Name);
  WriteLn('');

  TestArrayAddI32;
  TestArraySubI32;
  TestArrayMulI16;
  TestArrayPackSatI32toI16;

  WriteLn('');
  WriteLn(Format('[SUMMARY] checks=%d failures=%d', [g_TotalChecks, g_Failures]));
  if g_Failures > 0 then
  begin
    WriteLn('[RESULT] FAIL');
    Halt(1);
  end;
  WriteLn('[RESULT] PASS');
end.
