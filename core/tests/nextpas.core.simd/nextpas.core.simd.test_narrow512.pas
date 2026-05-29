program nextpas.core.simd.test_narrow512;

{$I ../../src/nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch;

var
  g_Checks: Integer = 0;
  g_Fails: Integer = 0;

procedure CheckBool(const aName: string; aOK: Boolean);
begin
  Inc(g_Checks);
  if not aOK then begin WriteLn('[FAIL] ', aName); Inc(g_Fails); end;
end;

procedure TestU32x16;
var a, b, r: TVecU32x16;
    m: TMask16;
    i: Integer;
begin
  for i := 0 to 15 do begin a.u[i] := DWord(i * 10); b.u[i] := DWord(5); end;

  r := VecU32x16Add(a, b);
  CheckBool('U32x16 Add[0]', r.u[0] = 5);
  CheckBool('U32x16 Add[15]', r.u[15] = 155);

  r := VecU32x16Sub(a, b);
  CheckBool('U32x16 Sub[3]', r.u[3] = 25);

  r := VecU32x16And(a, b);
  CheckBool('U32x16 And[0]', r.u[0] = (0 and 5));

  r := VecU32x16Or(a, b);
  CheckBool('U32x16 Or[1]', r.u[1] = (10 or 5));

  r := VecU32x16Xor(a, b);
  CheckBool('U32x16 Xor[2]', r.u[2] = (20 xor 5));

  for i := 0 to 15 do begin a.u[i] := DWord(i); b.u[i] := DWord(i); end;
  b.u[5] := 99;
  m := VecU32x16CmpEq(a, b);
  CheckBool('U32x16 CmpEq[0] eq', (m and (1 shl 0)) <> 0);
  CheckBool('U32x16 CmpEq[5] ne', (m and (1 shl 5)) = 0);

  WriteLn('  U32x16: OK');
end;

procedure TestU64x8;
var a, b, r: TVecU64x8;
    m: TMask8;
    i: Integer;
begin
  for i := 0 to 7 do begin a.u[i] := QWord(i * 100); b.u[i] := QWord(50); end;

  r := VecU64x8Add(a, b);
  CheckBool('U64x8 Add[0]', r.u[0] = 50);
  CheckBool('U64x8 Add[7]', r.u[7] = 750);

  r := VecU64x8Sub(a, b);
  CheckBool('U64x8 Sub[2]', r.u[2] = 150);

  r := VecU64x8And(a, b);
  CheckBool('U64x8 And[0]', r.u[0] = (0 and 50));

  r := VecU64x8Or(a, b);
  CheckBool('U64x8 Or[1]', r.u[1] = (100 or 50));

  r := VecU64x8Xor(a, b);
  CheckBool('U64x8 Xor[3]', r.u[3] = (300 xor 50));

  for i := 0 to 7 do begin a.u[i] := QWord(i); b.u[i] := QWord(i); end;
  b.u[3] := 999;
  m := VecU64x8CmpEq(a, b);
  CheckBool('U64x8 CmpEq[0] eq', (m and (1 shl 0)) <> 0);
  CheckBool('U64x8 CmpEq[3] ne', (m and (1 shl 3)) = 0);

  WriteLn('  U64x8: OK');
end;

procedure TestI16x32;
var a, b, r: TVecI16x32;
    m: TMask32;
    i: Integer;
begin
  for i := 0 to 31 do begin a.i[i] := SmallInt(i - 16); b.i[i] := 3; end;

  r := VecI16x32Add(a, b);
  CheckBool('I16x32 Add[0]', r.i[0] = -13);
  CheckBool('I16x32 Add[16]', r.i[16] = 3);

  r := VecI16x32Sub(a, b);
  CheckBool('I16x32 Sub[16]', r.i[16] = -3);

  r := VecI16x32And(a, b);
  CheckBool('I16x32 And[20]', r.i[20] = (4 and 3));

  r := VecI16x32Or(a, b);
  CheckBool('I16x32 Or[20]', r.i[20] = (4 or 3));

  r := VecI16x32Xor(a, b);
  CheckBool('I16x32 Xor[20]', r.i[20] = (4 xor 3));

  for i := 0 to 31 do begin a.i[i] := SmallInt(i); b.i[i] := SmallInt(i); end;
  b.i[10] := 999;
  m := VecI16x32CmpEq(a, b);
  CheckBool('I16x32 CmpEq[0] eq', (m and (1 shl 0)) <> 0);
  CheckBool('I16x32 CmpEq[10] ne', (m and (1 shl 10)) = 0);

  WriteLn('  I16x32: OK');
end;

{== PLACEHOLDER_REST ==}

procedure TestI8x64;
var a, b, r: TVecI8x64;
    m: TMask64;
    i: Integer;
begin
  for i := 0 to 63 do begin a.i[i] := ShortInt(i - 32); b.i[i] := 2; end;

  r := VecI8x64Add(a, b);
  CheckBool('I8x64 Add[0]', r.i[0] = -30);
  CheckBool('I8x64 Add[32]', r.i[32] = 2);

  r := VecI8x64Sub(a, b);
  CheckBool('I8x64 Sub[32]', r.i[32] = -2);

  r := VecI8x64And(a, b);
  CheckBool('I8x64 And[34]', r.i[34] = (2 and 2));

  r := VecI8x64Or(a, b);
  CheckBool('I8x64 Or[35]', r.i[35] = (3 or 2));

  r := VecI8x64Xor(a, b);
  CheckBool('I8x64 Xor[34]', r.i[34] = (2 xor 2));

  for i := 0 to 63 do begin a.i[i] := ShortInt(i); b.i[i] := ShortInt(i); end;
  b.i[20] := 127;
  m := VecI8x64CmpEq(a, b);
  CheckBool('I8x64 CmpEq[0] eq', (m and (QWord(1) shl 0)) <> 0);
  CheckBool('I8x64 CmpEq[20] ne', (m and (QWord(1) shl 20)) = 0);

  WriteLn('  I8x64: OK');
end;

procedure TestU8x64;
var a, b, r: TVecU8x64;
    m: TMask64;
    i: Integer;
begin
  for i := 0 to 63 do begin a.u[i] := Byte(i * 3); b.u[i] := 10; end;

  r := VecU8x64Add(a, b);
  CheckBool('U8x64 Add[0]', r.u[0] = 10);
  CheckBool('U8x64 Add[10]', r.u[10] = 40);

  r := VecU8x64Sub(a, b);
  CheckBool('U8x64 Sub[10]', r.u[10] = 20);

  r := VecU8x64And(a, b);
  CheckBool('U8x64 And[5]', r.u[5] = (15 and 10));

  r := VecU8x64Or(a, b);
  CheckBool('U8x64 Or[5]', r.u[5] = (15 or 10));

  r := VecU8x64Xor(a, b);
  CheckBool('U8x64 Xor[5]', r.u[5] = (15 xor 10));

  for i := 0 to 63 do begin a.u[i] := Byte(i); b.u[i] := Byte(i); end;
  b.u[30] := 200;
  m := VecU8x64CmpEq(a, b);
  CheckBool('U8x64 CmpEq[0] eq', (m and (QWord(1) shl 0)) <> 0);
  CheckBool('U8x64 CmpEq[30] ne', (m and (QWord(1) shl 30)) = 0);

  WriteLn('  U8x64: OK');
end;

begin
  WriteLn('[512-bit Narrow Integer Correctness Tests]');
  WriteLn('Backend: ', GetBackendInfo(GetActiveBackend).Name);
  WriteLn('');

  TestU32x16;
  TestU64x8;
  TestI16x32;
  TestI8x64;
  TestU8x64;

  WriteLn('');
  WriteLn('[SUMMARY] checks=', g_Checks, ' failures=', g_Fails);
  if g_Fails > 0 then
  begin
    WriteLn('[RESULT] FAIL');
    Halt(1);
  end;
  WriteLn('[RESULT] PASS');
end.
