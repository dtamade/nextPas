program nextpas.core.simd.test_alignment;

{$I ../../src/nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.alloc;

var
  g_Checks: Integer = 0;
  g_Fails: Integer = 0;

procedure CheckBool(const aName: string; aOK: Boolean);
begin
  Inc(g_Checks);
  if not aOK then begin WriteLn('[FAIL] ', aName); Inc(g_Fails); end;
end;

procedure TestF32x4Alignment;
var
  LBuf: PByte;
  LAligned, LUnaligned: PSingle;
  v: TVecF32x4;
  dst: array[0..3] of Single;
  i: Integer;
begin
  LBuf := PByte(SimdAlloc(128, sa64));
  LAligned := PSingle(LBuf);
  LUnaligned := PSingle(LBuf + 3);

  for i := 0 to 3 do LAligned[i] := (i + 1) * 1.5;
  v := VecF32x4Load(LAligned);
  VecF32x4Store(@dst[0], v);
  CheckBool('F32x4 aligned Load[0]', dst[0] = 1.5);
  CheckBool('F32x4 aligned Load[3]', dst[3] = 6.0);

  for i := 0 to 3 do LUnaligned[i] := (i + 1) * 2.5;
  v := VecF32x4Load(LUnaligned);
  VecF32x4Store(@dst[0], v);
  CheckBool('F32x4 unaligned Load[0]', dst[0] = 2.5);
  CheckBool('F32x4 unaligned Load[3]', dst[3] = 10.0);

  v := VecF32x4Splat(7.0);
  VecF32x4Store(LUnaligned, v);
  CheckBool('F32x4 unaligned Store[0]', LUnaligned[0] = 7.0);
  CheckBool('F32x4 unaligned Store[3]', LUnaligned[3] = 7.0);

  SimdFree(LBuf);
  WriteLn('  F32x4 alignment: OK');
end;

procedure TestF32x8Alignment;
var
  LBuf: PByte;
  LSrc, LDst: PSingle;
  i: Integer;
begin
  LBuf := PByte(SimdAlloc(256, sa64));
  LSrc := PSingle(LBuf + 7);
  LDst := PSingle(LBuf + 100 + 13);

  for i := 0 to 7 do LSrc[i] := (i + 1) * 3.0;
  ArrayAddF32(LSrc, LSrc, LDst, 8);
  CheckBool('F32x8 unaligned ArrayAdd[0]', LDst[0] = 6.0);
  CheckBool('F32x8 unaligned ArrayAdd[7]', LDst[7] = 48.0);

  ArrayMulScalarF32(LSrc, LDst, 8, 2.0);
  CheckBool('F32x8 unaligned MulScalar[0]', LDst[0] = 6.0);
  CheckBool('F32x8 unaligned MulScalar[7]', LDst[7] = 48.0);

  SimdFree(LBuf);
  WriteLn('  F32x8 unaligned batch: OK');
end;

procedure TestBatchAlignment;
var
  LBuf: PByte;
  LSrc, LDst: PSingle;
  i: Integer;
begin
  LBuf := PByte(SimdAlloc(512, sa64));
  LSrc := PSingle(LBuf + 5);
  LDst := PSingle(LBuf + 200 + 11);

  for i := 0 to 15 do LSrc[i] := i * 2.0;
  ArrayAddScalarF32(LSrc, LDst, 16, 1.0);
  CheckBool('Batch unaligned Add[0]', LDst[0] = 1.0);
  CheckBool('Batch unaligned Add[15]', LDst[15] = 31.0);

  ArrayMulScalarF32(LSrc, LDst, 16, 3.0);
  CheckBool('Batch unaligned Mul[5]', LDst[5] = 30.0);

  SimdFree(LBuf);
  WriteLn('  Batch alignment: OK');
end;

begin
  WriteLn('[Alignment Load/Store Correctness Tests]');
  WriteLn('Backend: ', GetBackendInfo(GetActiveBackend).Name);
  WriteLn('');

  TestF32x4Alignment;
  TestF32x8Alignment;
  TestBatchAlignment;

  WriteLn('');
  WriteLn('[SUMMARY] checks=', g_Checks, ' failures=', g_Fails);
  if g_Fails > 0 then
  begin
    WriteLn('[RESULT] FAIL');
    Halt(1);
  end;
  WriteLn('[RESULT] PASS');
end.
