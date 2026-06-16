program nextpas.core.simd.large_array;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  nextpas.core.text.conv, Math,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch;

const
  N = 1048576;
  GUARD_SIZE = 64;
  GUARD_BYTE = $CD;

var
  g_TotalChecks: Integer = 0;
  g_Failures: Integer = 0;

procedure Fail(const aMsg: string);
begin
  WriteLn('[FAIL] ', aMsg);
  Inc(g_Failures);
end;

function CheckGuard(p: PByte; aSize: Integer; const aCtx: string): Boolean;
var i: Integer;
begin
  Result := True;
  for i := 0 to aSize - 1 do
    if p[i] <> GUARD_BYTE then
    begin
      Fail(Format('%s: guard overwritten at offset %d', [aCtx, i]));
      Result := False;
      Break;
    end;
end;

procedure TestF32Batch;
var
  LSrc1, LSrc2, LDst: PSingle;
  LBuf: PByte;
  LBufSize: SizeUInt;
  LSum: Single;
  i: SizeUInt;
begin
  LBufSize := (N * SizeOf(Single) + GUARD_SIZE) * 3;
  LBuf := GetMem(LBufSize);
  FillChar(LBuf^, LBufSize, GUARD_BYTE);

  LSrc1 := PSingle(LBuf + GUARD_SIZE);
  LSrc2 := PSingle(PByte(LSrc1) + N * SizeOf(Single) + GUARD_SIZE);
  LDst := PSingle(PByte(LSrc2) + N * SizeOf(Single) + GUARD_SIZE);

  for i := 0 to N - 1 do
  begin
    LSrc1[i] := Sin(i * 0.001) * 100;
    LSrc2[i] := Cos(i * 0.001) * 50 + 1;
  end;

  ArrayAddF32(LSrc1, LSrc2, LDst, N);
  Inc(g_TotalChecks);
  ArraySubF32(LSrc1, LSrc2, LDst, N);
  Inc(g_TotalChecks);
  ArrayMulF32(LSrc1, LSrc2, LDst, N);
  Inc(g_TotalChecks);
  ArrayDivF32(LSrc1, LSrc2, LDst, N);
  Inc(g_TotalChecks);
  ArrayAbsF32(LSrc1, LDst, N);
  Inc(g_TotalChecks);
  ArrayNegF32(LSrc1, LDst, N);
  Inc(g_TotalChecks);

  for i := 0 to N - 1 do
    LSrc1[i] := Abs(LSrc1[i]) + 0.01;
  ArraySqrtF32(LSrc1, LDst, N);
  Inc(g_TotalChecks);

  LSum := ReduceSumF32(LSrc1, N);
  Inc(g_TotalChecks);
  if IsNan(LSum) or IsInfinite(LSum) then
    Fail('ReduceSumF32 returned NaN/Inf');

  LSum := ReduceDotF32(LSrc1, LSrc2, N);
  Inc(g_TotalChecks);
  LSum := ReduceMinF32(LSrc1, N);
  Inc(g_TotalChecks);
  LSum := ReduceMaxF32(LSrc1, N);
  Inc(g_TotalChecks);

  // Clamp for Exp to avoid overflow (exp(88) ~ 2.35e38 ~ MaxSingle)
  for i := 0 to N - 1 do
    if LSrc1[i] > 80 then LSrc1[i] := 80;
  ArrayExpF32(LSrc1, LDst, N);
  Inc(g_TotalChecks);
  ArraySinF32(LSrc1, LDst, N);
  Inc(g_TotalChecks);
  ArrayCosF32(LSrc1, LDst, N);
  Inc(g_TotalChecks);

  CheckGuard(LBuf, GUARD_SIZE, 'F32-pre-guard');
  Inc(g_TotalChecks);

  FreeMem(LBuf);
  WriteLn('  F32 batch (N=1M): all ops completed, guards intact');
end;

procedure TestF64Batch;
var
  LSrc1, LSrc2, LDst: PDouble;
  LBuf: PByte;
  LBufSize: SizeUInt;
  LSum: Double;
  i: SizeUInt;
begin
  LBufSize := (N * SizeOf(Double) + GUARD_SIZE) * 3;
  LBuf := GetMem(LBufSize);
  FillChar(LBuf^, LBufSize, GUARD_BYTE);

  LSrc1 := PDouble(LBuf + GUARD_SIZE);
  LSrc2 := PDouble(PByte(LSrc1) + N * SizeOf(Double) + GUARD_SIZE);
  LDst := PDouble(PByte(LSrc2) + N * SizeOf(Double) + GUARD_SIZE);

  for i := 0 to N - 1 do
  begin
    LSrc1[i] := Sin(i * 0.001) * 1000;
    LSrc2[i] := Cos(i * 0.001) * 500 + 1;
  end;

  ArrayAddF64(LSrc1, LSrc2, LDst, N);
  Inc(g_TotalChecks);
  ArraySubF64(LSrc1, LSrc2, LDst, N);
  Inc(g_TotalChecks);
  ArrayMulF64(LSrc1, LSrc2, LDst, N);
  Inc(g_TotalChecks);
  ArrayDivF64(LSrc1, LSrc2, LDst, N);
  Inc(g_TotalChecks);
  ArrayAbsF64(LSrc1, LDst, N);
  Inc(g_TotalChecks);
  ArrayNegF64(LSrc1, LDst, N);
  Inc(g_TotalChecks);

  for i := 0 to N - 1 do
    LSrc1[i] := Abs(LSrc1[i]) + 0.01;
  ArraySqrtF64(LSrc1, LDst, N);
  Inc(g_TotalChecks);

  LSum := ReduceSumF64(LSrc1, N);
  Inc(g_TotalChecks);
  if IsNan(LSum) or IsInfinite(LSum) then
    Fail('ReduceSumF64 returned NaN/Inf');
  LSum := ReduceMinF64(LSrc1, N);
  Inc(g_TotalChecks);
  LSum := ReduceMaxF64(LSrc1, N);
  Inc(g_TotalChecks);

  CheckGuard(LBuf, GUARD_SIZE, 'F64-pre-guard');
  Inc(g_TotalChecks);

  FreeMem(LBuf);
  WriteLn('  F64 batch (N=1M): all ops completed, guards intact');
end;

procedure TestI32Batch;
var
  LSrc1, LSrc2, LDst: PInt32;
  LBuf: PByte;
  LBufSize: SizeUInt;
  i: SizeUInt;
begin
  LBufSize := (N * SizeOf(Int32) + GUARD_SIZE) * 3;
  LBuf := GetMem(LBufSize);
  FillChar(LBuf^, LBufSize, GUARD_BYTE);

  LSrc1 := PInt32(LBuf + GUARD_SIZE);
  LSrc2 := PInt32(PByte(LSrc1) + N * SizeOf(Int32) + GUARD_SIZE);
  LDst := PInt32(PByte(LSrc2) + N * SizeOf(Int32) + GUARD_SIZE);

  for i := 0 to N - 1 do
  begin
    LSrc1[i] := Int32(i) - Int32(N div 2);
    LSrc2[i] := Int32(i * 7) - 1000;
  end;

  ArrayAddI32(LSrc1, LSrc2, LDst, N);
  Inc(g_TotalChecks);
  ArraySubI32(LSrc1, LSrc2, LDst, N);
  Inc(g_TotalChecks);
  ArrayAndI32(LSrc1, LSrc2, LDst, N);
  Inc(g_TotalChecks);
  ArrayOrI32(LSrc1, LSrc2, LDst, N);
  Inc(g_TotalChecks);
  ArrayXorI32(LSrc1, LSrc2, LDst, N);
  Inc(g_TotalChecks);
  ArrayShlI32(LSrc1, LDst, N, 4);
  Inc(g_TotalChecks);
  ArrayShrI32(LSrc1, LDst, N, 4);
  Inc(g_TotalChecks);

  CheckGuard(LBuf, GUARD_SIZE, 'I32-pre-guard');
  Inc(g_TotalChecks);

  FreeMem(LBuf);
  WriteLn('  I32 batch (N=1M): all ops completed, guards intact');
end;

begin
  WriteLn('[Large Array Test (N=1M)]');
  WriteLn('Backend: ', GetBackendInfo(GetActiveBackend).Name);
  WriteLn('');

  TestF32Batch;
  TestF64Batch;
  TestI32Batch;

  WriteLn('');
  WriteLn(Format('[SUMMARY] checks=%d failures=%d', [g_TotalChecks, g_Failures]));
  if g_Failures > 0 then
  begin
    WriteLn('[RESULT] FAIL');
    Halt(1);
  end;
  WriteLn('[RESULT] PASS');
end.
