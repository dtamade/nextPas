program test_simdgen_parity;
{$I ../../src/nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  nextpas.core.text.conv, Math,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.scalar,
  nextpas.core.simd.generated.scalar;

var
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(const aName: string; aExpected, aActual: Single);
begin
  if IsNan(aExpected) and IsNan(aActual) then
  begin Inc(GPassCount); Exit; end;
  if Abs(aExpected - aActual) < 1e-5 then
    Inc(GPassCount)
  else begin
    WriteLn('FAIL: ', aName, ' expected=', aExpected:0:6, ' actual=', aActual:0:6);
    Inc(GFailCount);
  end;
end;

procedure CheckDouble(const aName: string; aExpected, aActual: Double);
begin
  if IsNan(aExpected) and IsNan(aActual) then
  begin Inc(GPassCount); Exit; end;
  if Abs(aExpected - aActual) < 1e-12 then
    Inc(GPassCount)
  else begin
    WriteLn('FAIL: ', aName, ' expected=', aExpected:0:12, ' actual=', aActual:0:12);
    Inc(GFailCount);
  end;
end;

procedure CheckBool(const aName: string; aExpected, aActual: Boolean);
begin
  if aExpected = aActual then
    Inc(GPassCount)
  else begin WriteLn('FAIL: ', aName, ' expected=', aExpected, ' actual=', aActual); Inc(GFailCount); end;
end;

procedure CheckLongBool(const aName: string; aExpected, aActual: LongBool);
begin
  if aExpected = aActual then
    Inc(GPassCount)
  else begin WriteLn('FAIL: ', aName, ' expected=', aExpected, ' actual=', aActual); Inc(GFailCount); end;
end;

procedure CheckUInt64(const aName: string; aExpected, aActual: UInt64);
begin
  if aExpected = aActual then
    Inc(GPassCount)
  else begin WriteLn('FAIL: ', aName, ' expected=', aExpected, ' actual=', aActual); Inc(GFailCount); end;
end;

procedure CheckPtrInt(const aName: string; aExpected, aActual: PtrInt);
begin
  if aExpected = aActual then
    Inc(GPassCount)
  else begin WriteLn('FAIL: ', aName, ' expected=', aExpected, ' actual=', aActual); Inc(GFailCount); end;
end;

procedure CheckByte(const aName: string; aExpected, aActual: Byte);
begin
  if aExpected = aActual then
    Inc(GPassCount)
  else begin WriteLn('FAIL: ', aName, ' expected=', Integer(aExpected), ' actual=', Integer(aActual)); Inc(GFailCount); end;
end;

procedure CheckSingleArray(const aName: string; const aExpected, aActual: array of Single);
var
  i: Integer;
begin
  for i := Low(aExpected) to High(aExpected) do
    Check(aName + '[' + IntToStr(i) + ']', aExpected[i], aActual[i]);
end;

function SameByteBuffer(a, b: Pointer; len: SizeUInt): Boolean;
var
  pa, pb: PByte;
  i: SizeUInt;
begin
  Result := True;
  if len = 0 then
    Exit;
  if (a = nil) or (b = nil) then
  begin
    Result := a = b;
    Exit;
  end;

  pa := PByte(a);
  pb := PByte(b);
  for i := 0 to len - 1 do
  begin
    if pa[i] <> pb[i] then
      Exit(False);
  end;
end;

procedure CheckVecF32x4(const aName: string; const aExp, aAct: TVecF32x4);
var i: Integer;
begin
  for i := 0 to 3 do
    Check(aName + '[' + IntToStr(i) + ']', aExp.f[i], aAct.f[i]);
end;

procedure CheckVecF32x8(const aName: string; const aExp, aAct: TVecF32x8);
var i: Integer;
begin
  for i := 0 to 7 do
    Check(aName + '[' + IntToStr(i) + ']', aExp.f[i], aAct.f[i]);
end;

procedure CheckVecF64x2(const aName: string; const aExp, aAct: TVecF64x2);
var i: Integer;
begin
  for i := 0 to 1 do
    Check(aName + '[' + IntToStr(i) + ']', aExp.d[i], aAct.d[i]);
end;

procedure CheckVecF64x4(const aName: string; const aExp, aAct: TVecF64x4);
var i: Integer;
begin
  for i := 0 to 3 do
    Check(aName + '[' + IntToStr(i) + ']', aExp.d[i], aAct.d[i]);
end;

procedure CheckVecI64x2(const aName: string; const aExp, aAct: TVecI64x2);
var i: Integer;
begin
  for i := 0 to 1 do
    if aExp.i[i] = aAct.i[i] then Inc(GPassCount)
    else begin WriteLn('FAIL: ', aName, '[', i, '] expected=', aExp.i[i], ' actual=', aAct.i[i]); Inc(GFailCount); end;
end;

procedure CheckVecI64x4(const aName: string; const aExp, aAct: TVecI64x4);
var i: Integer;
begin
  for i := 0 to 3 do
    if aExp.i[i] = aAct.i[i] then Inc(GPassCount)
    else begin WriteLn('FAIL: ', aName, '[', i, '] expected=', aExp.i[i], ' actual=', aAct.i[i]); Inc(GFailCount); end;
end;

procedure CheckVecI32x8(const aName: string; const aExp, aAct: TVecI32x8);
var i: Integer;
begin
  for i := 0 to 7 do
    if aExp.i[i] = aAct.i[i] then Inc(GPassCount)
    else begin WriteLn('FAIL: ', aName, '[', i, '] expected=', aExp.i[i], ' actual=', aAct.i[i]); Inc(GFailCount); end;
end;

procedure CheckVecI32x16(const aName: string; const aExp, aAct: TVecI32x16);
var i: Integer;
begin
  for i := 0 to 15 do
    if aExp.i[i] = aAct.i[i] then Inc(GPassCount)
    else begin WriteLn('FAIL: ', aName, '[', i, '] expected=', aExp.i[i], ' actual=', aAct.i[i]); Inc(GFailCount); end;
end;

procedure CheckVecF64x8(const aName: string; const aExp, aAct: TVecF64x8);
var i: Integer;
begin
  for i := 0 to 7 do
    Check(aName + '[' + IntToStr(i) + ']', aExp.d[i], aAct.d[i]);
end;

procedure CheckVecF32x16(const aName: string; const aExp, aAct: TVecF32x16);
var i: Integer;
begin
  for i := 0 to 15 do
    Check(aName + '[' + IntToStr(i) + ']', aExp.f[i], aAct.f[i]);
end;

procedure CheckVecI32x4(const aName: string; const aExp, aAct: TVecI32x4);
var i: Integer;
begin
  for i := 0 to 3 do
    if aExp.i[i] = aAct.i[i] then Inc(GPassCount)
    else begin WriteLn('FAIL: ', aName, '[', i, '] expected=', aExp.i[i], ' actual=', aAct.i[i]); Inc(GFailCount); end;
end;

procedure CheckVecI8x16(const aName: string; const aExp, aAct: TVecI8x16);
var i: Integer;
begin
  for i := 0 to 15 do
    if aExp.i[i] = aAct.i[i] then Inc(GPassCount)
    else begin WriteLn('FAIL: ', aName, '[', i, '] expected=', Integer(aExp.i[i]), ' actual=', Integer(aAct.i[i])); Inc(GFailCount); end;
end;

procedure CheckVecI16x8(const aName: string; const aExp, aAct: TVecI16x8);
var i: Integer;
begin
  for i := 0 to 7 do
    if aExp.i[i] = aAct.i[i] then Inc(GPassCount)
    else begin WriteLn('FAIL: ', aName, '[', i, '] expected=', Integer(aExp.i[i]), ' actual=', Integer(aAct.i[i])); Inc(GFailCount); end;
end;

procedure CheckVecU8x16(const aName: string; const aExp, aAct: TVecU8x16);
var i: Integer;
begin
  for i := 0 to 15 do
    if aExp.u[i] = aAct.u[i] then Inc(GPassCount)
    else begin WriteLn('FAIL: ', aName, '[', i, '] expected=', Integer(aExp.u[i]), ' actual=', Integer(aAct.u[i])); Inc(GFailCount); end;
end;

procedure CheckVecU16x8(const aName: string; const aExp, aAct: TVecU16x8);
var i: Integer;
begin
  for i := 0 to 7 do
    if aExp.u[i] = aAct.u[i] then Inc(GPassCount)
    else begin WriteLn('FAIL: ', aName, '[', i, '] expected=', Integer(aExp.u[i]), ' actual=', Integer(aAct.u[i])); Inc(GFailCount); end;
end;

procedure CheckVecI16x32(const aName: string; const aExp, aAct: TVecI16x32);
var i: Integer;
begin
  for i := 0 to 31 do
    if aExp.i[i] = aAct.i[i] then Inc(GPassCount)
    else begin WriteLn('FAIL: ', aName, '[', i, '] expected=', Integer(aExp.i[i]), ' actual=', Integer(aAct.i[i])); Inc(GFailCount); end;
end;

var
  AF4, BF4, CF4_Existing, CF4_Generated: TVecF32x4;
  AF8, BF8, CF8_Existing, CF8_Generated: TVecF32x8;
  AD2, BD2, CD2_Existing, CD2_Generated: TVecF64x2;
  AD4, BD4: TVecF64x4;
  AD8, BD8, CD8_Existing, CD8_Generated: TVecF64x8;
  AF16, BF16, CF16_Existing, CF16_Generated: TVecF32x16;
  AI32, BI32, CI32_Existing, CI32_Generated: TVecI32x4;
  I64A2, I64B2, I64C2_Existing, I64C2_Generated: TVecI64x2;
  I64A4, I64B4, I64C4_Existing, I64C4_Generated: TVecI64x4;
  I32A8, I32B8, I32C8_Existing, I32C8_Generated: TVecI32x8;
  I32A16, I32B16, I32C16_Existing, I32C16_Generated: TVecI32x16;
  CU32_Existing, CU32_Generated: TVecF32x8;
  CU64_Existing, CU64_Generated: TVecF64x4;
  MaskExisting, MaskGenerated: TMask4;
  Mask2Select, Mask8Select: TMask2;
  Mask16Select: TMask16;
  Mask4Select: TMask4;
  MaskI32: TVecI32x4;
  MaskU32: TVecU32x8;
  MaskU64: TVecU64x4;
  LI8A, LI8B, LI8_Existing, LI8_Generated: TVecI8x16;
  LI16A, LI16B, LI16_Existing, LI16_Generated: TVecI16x8;
  LI16A32, LI16C32_Existing, LI16C32_Generated: TVecI16x32;
  LU8A, LU8B, LU8_Existing, LU8_Generated: TVecU8x16;
  LU16A, LU16B, LU16_Existing, LU16_Generated: TVecU16x8;
  Utf8Valid: array[0..5] of Byte;
  Utf8Overlong: array[0..1] of Byte;
  Utf8Incomplete: array[0..1] of Byte;
  HelperA, HelperB, HelperC: array[0..15] of Byte;
  AsciiA, AsciiB, AsciiC: array[0..3] of Byte;
  ByteStats: array[0..4] of Byte;
  FirstExisting, LastExisting, FirstGenerated, LastGenerated: SizeUInt;
  MinExisting, MaxExisting, MinGenerated, MaxGenerated: Byte;
  BatchA, BatchB: array[0..5] of Single;
  BatchExisting, BatchGenerated: array[0..5] of Single;
  i: Integer;
begin
  // Setup test vectors with diverse values including edge cases
  AF4.f[0] := 1.5; AF4.f[1] := -2.7; AF4.f[2] := 0.0; AF4.f[3] := 99.9;
  BF4.f[0] := 3.2; BF4.f[1] := 4.1;  BF4.f[2] := 1.0; BF4.f[3] := -0.5;

  AF8.f[0] := 1.0; AF8.f[1] := 2.0; AF8.f[2] := 3.0; AF8.f[3] := 4.0;
  AF8.f[4] := 5.0; AF8.f[5] := 6.0; AF8.f[6] := 7.0; AF8.f[7] := 8.0;
  BF8.f[0] := 8.0; BF8.f[1] := 7.0; BF8.f[2] := 6.0; BF8.f[3] := 5.0;
  BF8.f[4] := 4.0; BF8.f[5] := 3.0; BF8.f[6] := 2.0; BF8.f[7] := 1.0;

  AD2.d[0] := 3.14159; AD2.d[1] := -2.71828;
  BD2.d[0] := 1.41421; BD2.d[1] := 1.73205;
  AD4.d[0] := 1.25; AD4.d[1] := 2.25; AD4.d[2] := 3.25; AD4.d[3] := 4.25;
  BD4.d[0] := 9.25; BD4.d[1] := 8.25; BD4.d[2] := 7.25; BD4.d[3] := 6.25;
  for i := 0 to 7 do
  begin
    AD8.d[i] := 20.0 + i;
    BD8.d[i] := 30.0 + i;
    MaskU32.u[i] := Ord(Odd(i));
    MaskU64.u[i mod 4] := Ord(Odd(i));
  end;
  for i := 0 to 15 do
  begin
    AF16.f[i] := i + 0.5;
    BF16.f[i] := 100 + i + 0.5;
  end;
  for i := 0 to 31 do
    LI16A32.i[i] := Int16(-2000 + (i * 137));
  for i := 0 to 3 do
  begin
    AI32.i[i] := i + 1;
    BI32.i[i] := 100 + i;
    MaskI32.i[i] := Ord(Odd(i));
  end;
  I64A2.i[0] := -111; I64A2.i[1] := 222;
  I64B2.i[0] := 333; I64B2.i[1] := -444;
  for i := 0 to 3 do
  begin
    I64A4.i[i] := 1000 + i;
    I64B4.i[i] := -2000 - i;
  end;
  for i := 0 to 7 do
  begin
    I32A8.i[i] := 10 * (i + 1);
    I32B8.i[i] := 100 + i;
  end;
  for i := 0 to 15 do
  begin
    I32A16.i[i] := 1000 + i;
    I32B16.i[i] := -1000 - i;
  end;
  for i := 0 to 15 do
  begin
    HelperA[i] := Byte(i * 7);
    HelperB[i] := HelperA[i];
    HelperC[i] := HelperA[i];
  end;
  HelperC[9] := HelperC[9] xor $FF;
  AsciiA[0] := Ord('A'); AsciiA[1] := Ord('b'); AsciiA[2] := Ord('C'); AsciiA[3] := Ord('d');
  AsciiB[0] := Ord('a'); AsciiB[1] := Ord('B'); AsciiB[2] := Ord('c'); AsciiB[3] := Ord('D');
  AsciiC[0] := Ord('a'); AsciiC[1] := Ord('B'); AsciiC[2] := Ord('x'); AsciiC[3] := Ord('D');
  ByteStats[0] := 0;
  ByteStats[1] := 1;
  ByteStats[2] := 3;
  ByteStats[3] := 7;
  ByteStats[4] := 15;
  BatchA[0] := 1.0; BatchA[1] := -2.0; BatchA[2] := 3.5;
  BatchA[3] := 4.0; BatchA[4] := -5.5; BatchA[5] := 6.0;
  BatchB[0] := 0.5; BatchB[1] := 2.0; BatchB[2] := -1.0;
  BatchB[3] := 3.0; BatchB[4] := 4.0; BatchB[5] := -2.0;
  Mask4Select := $05;
  Mask2Select := $01;
  Mask16Select := $8001;
  Mask8Select := $81;

  // === F32x4 Arithmetic Parity ===
  // Use nextpas.core.simd.scalar (existing) vs nextpas.core.simd.generated.scalar

  // Add
  CF4_Existing := nextpas.core.simd.scalar.ScalarAddF32x4(AF4, BF4);
  CF4_Generated := nextpas.core.simd.generated.scalar.ScalarAddF32x4(AF4, BF4);
  CheckVecF32x4('AddF32x4', CF4_Existing, CF4_Generated);

  // Sub
  CF4_Existing := nextpas.core.simd.scalar.ScalarSubF32x4(AF4, BF4);
  CF4_Generated := nextpas.core.simd.generated.scalar.ScalarSubF32x4(AF4, BF4);
  CheckVecF32x4('SubF32x4', CF4_Existing, CF4_Generated);

  // Mul
  CF4_Existing := nextpas.core.simd.scalar.ScalarMulF32x4(AF4, BF4);
  CF4_Generated := nextpas.core.simd.generated.scalar.ScalarMulF32x4(AF4, BF4);
  CheckVecF32x4('MulF32x4', CF4_Existing, CF4_Generated);

  // Div
  CF4_Existing := nextpas.core.simd.scalar.ScalarDivF32x4(AF4, BF4);
  CF4_Generated := nextpas.core.simd.generated.scalar.ScalarDivF32x4(AF4, BF4);
  CheckVecF32x4('DivF32x4', CF4_Existing, CF4_Generated);

  // Min
  CF4_Existing := nextpas.core.simd.scalar.ScalarMinF32x4(AF4, BF4);
  CF4_Generated := nextpas.core.simd.generated.scalar.ScalarMinF32x4(AF4, BF4);
  CheckVecF32x4('MinF32x4', CF4_Existing, CF4_Generated);

  // Max
  CF4_Existing := nextpas.core.simd.scalar.ScalarMaxF32x4(AF4, BF4);
  CF4_Generated := nextpas.core.simd.generated.scalar.ScalarMaxF32x4(AF4, BF4);
  CheckVecF32x4('MaxF32x4', CF4_Existing, CF4_Generated);

  CF4_Existing := nextpas.core.simd.scalar.ScalarLoadF32x4Aligned(@AF4.f[0]);
  CF4_Generated := nextpas.core.simd.generated.scalar.ScalarLoadF32x4Aligned(@AF4.f[0]);
  CheckVecF32x4('LoadF32x4Aligned', CF4_Existing, CF4_Generated);

  CF4_Existing := ScalarZeroF32x4();
  CF4_Generated := ScalarZeroF32x4();
  nextpas.core.simd.scalar.ScalarStoreF32x4Aligned(@CF4_Existing.f[0], AF4);
  nextpas.core.simd.generated.scalar.ScalarStoreF32x4Aligned(@CF4_Generated.f[0], AF4);
  CheckVecF32x4('StoreF32x4Aligned', CF4_Existing, CF4_Generated);

  // === Vector Math Parity ===
  Check('DotF32x3',
    nextpas.core.simd.scalar.ScalarDotF32x3(AF4, BF4),
    nextpas.core.simd.generated.scalar.ScalarDotF32x3(AF4, BF4));

  CheckVecF32x4('CrossF32x3',
    nextpas.core.simd.scalar.ScalarCrossF32x3(AF4, BF4),
    nextpas.core.simd.generated.scalar.ScalarCrossF32x3(AF4, BF4));

  Check('LengthF32x3',
    nextpas.core.simd.scalar.ScalarLengthF32x3(AF4),
    nextpas.core.simd.generated.scalar.ScalarLengthF32x3(AF4));

  Check('LengthF32x4',
    nextpas.core.simd.scalar.ScalarLengthF32x4(AF4),
    nextpas.core.simd.generated.scalar.ScalarLengthF32x4(AF4));

  CheckVecF32x4('NormalizeF32x3',
    nextpas.core.simd.scalar.ScalarNormalizeF32x3(AF4),
    nextpas.core.simd.generated.scalar.ScalarNormalizeF32x3(AF4));

  CheckVecF32x4('NormalizeF32x4',
    nextpas.core.simd.scalar.ScalarNormalizeF32x4(AF4),
    nextpas.core.simd.generated.scalar.ScalarNormalizeF32x4(AF4));

  // === F32x8 Arithmetic Parity ===
  CF8_Existing := nextpas.core.simd.scalar.ScalarAddF32x8(AF8, BF8);
  CF8_Generated := nextpas.core.simd.generated.scalar.ScalarAddF32x8(AF8, BF8);
  CheckVecF32x8('AddF32x8', CF8_Existing, CF8_Generated);

  CF8_Existing := nextpas.core.simd.scalar.ScalarMulF32x8(AF8, BF8);
  CF8_Generated := nextpas.core.simd.generated.scalar.ScalarMulF32x8(AF8, BF8);
  CheckVecF32x8('MulF32x8', CF8_Existing, CF8_Generated);

  // === F64x2 Arithmetic Parity ===
  CD2_Existing := nextpas.core.simd.scalar.ScalarAddF64x2(AD2, BD2);
  CD2_Generated := nextpas.core.simd.generated.scalar.ScalarAddF64x2(AD2, BD2);
  CheckVecF64x2('AddF64x2', CD2_Existing, CD2_Generated);

  CD2_Existing := nextpas.core.simd.scalar.ScalarDivF64x2(AD2, BD2);
  CD2_Generated := nextpas.core.simd.generated.scalar.ScalarDivF64x2(AD2, BD2);
  CheckVecF64x2('DivF64x2', CD2_Existing, CD2_Generated);

  // === Compare Parity ===
  MaskExisting := nextpas.core.simd.scalar.ScalarCmpLtF32x4(AF4, BF4);
  MaskGenerated := nextpas.core.simd.generated.scalar.ScalarCmpLtF32x4(AF4, BF4);
  if MaskExisting = MaskGenerated then Inc(GPassCount)
  else begin WriteLn('FAIL: CmpLtF32x4 mask ', MaskExisting, ' vs ', MaskGenerated); Inc(GFailCount); end;

  MaskExisting := nextpas.core.simd.scalar.ScalarCmpEqF32x4(AF4, AF4);
  MaskGenerated := nextpas.core.simd.generated.scalar.ScalarCmpEqF32x4(AF4, AF4);
  if MaskExisting = MaskGenerated then Inc(GPassCount)
  else begin WriteLn('FAIL: CmpEqF32x4 mask ', MaskExisting, ' vs ', MaskGenerated); Inc(GFailCount); end;

  // === Select Parity ===
  CF4_Existing := nextpas.core.simd.scalar.ScalarSelectF32x4(Mask4Select, AF4, BF4);
  CF4_Generated := nextpas.core.simd.generated.scalar.ScalarSelectF32x4(Mask4Select, AF4, BF4);
  CheckVecF32x4('SelectF32x4', CF4_Existing, CF4_Generated);

  CD2_Existing := nextpas.core.simd.scalar.ScalarSelectF64x2(Mask2Select, AD2, BD2);
  CD2_Generated := nextpas.core.simd.generated.scalar.ScalarSelectF64x2(Mask2Select, AD2, BD2);
  CheckVecF64x2('SelectF64x2', CD2_Existing, CD2_Generated);

  CF16_Existing := nextpas.core.simd.scalar.ScalarSelectF32x16(Mask16Select, AF16, BF16);
  CF16_Generated := nextpas.core.simd.generated.scalar.ScalarSelectF32x16(Mask16Select, AF16, BF16);
  CheckVecF32x16('SelectF32x16', CF16_Existing, CF16_Generated);

  CD8_Existing := nextpas.core.simd.scalar.ScalarSelectF64x8(Mask8Select, AD8, BD8);
  CD8_Generated := nextpas.core.simd.generated.scalar.ScalarSelectF64x8(Mask8Select, AD8, BD8);
  CheckVecF64x8('SelectF64x8', CD8_Existing, CD8_Generated);

  CI32_Existing := nextpas.core.simd.scalar.ScalarSelectI32x4(MaskI32, AI32, BI32);
  CI32_Generated := nextpas.core.simd.generated.scalar.ScalarSelectI32x4(MaskI32, AI32, BI32);
  CheckVecI32x4('SelectI32x4', CI32_Existing, CI32_Generated);

  CU32_Existing := nextpas.core.simd.scalar.ScalarSelectF32x8(MaskU32, AF8, BF8);
  CU32_Generated := nextpas.core.simd.generated.scalar.ScalarSelectF32x8(MaskU32, AF8, BF8);
  CheckVecF32x8('SelectF32x8', CU32_Existing, CU32_Generated);

  CU64_Existing := nextpas.core.simd.scalar.ScalarSelectF64x4(MaskU64, AD4, BD4);
  CU64_Generated := nextpas.core.simd.generated.scalar.ScalarSelectF64x4(MaskU64, AD4, BD4);
  CheckVecF64x4('SelectF64x4', CU64_Existing, CU64_Generated);

  // === Extract/Insert Parity ===
  Check('ExtractF32x4',
    nextpas.core.simd.scalar.ScalarExtractF32x4(AF4, -1),
    nextpas.core.simd.generated.scalar.ScalarExtractF32x4(AF4, -1));

  CheckDouble('ExtractF64x2',
    nextpas.core.simd.scalar.ScalarExtractF64x2(AD2, 9),
    nextpas.core.simd.generated.scalar.ScalarExtractF64x2(AD2, 9));

  if nextpas.core.simd.scalar.ScalarExtractI32x4(AI32, 99) =
     nextpas.core.simd.generated.scalar.ScalarExtractI32x4(AI32, 99) then Inc(GPassCount)
  else begin WriteLn('FAIL: ExtractI32x4 parity'); Inc(GFailCount); end;

  if nextpas.core.simd.scalar.ScalarExtractI64x2(I64A2, 1) =
     nextpas.core.simd.generated.scalar.ScalarExtractI64x2(I64A2, 1) then Inc(GPassCount)
  else begin WriteLn('FAIL: ExtractI64x2 parity'); Inc(GFailCount); end;

  Check('ExtractF32x8',
    nextpas.core.simd.scalar.ScalarExtractF32x8(AF8, 6),
    nextpas.core.simd.generated.scalar.ScalarExtractF32x8(AF8, 6));

  CheckDouble('ExtractF64x4',
    nextpas.core.simd.scalar.ScalarExtractF64x4(AD4, 2),
    nextpas.core.simd.generated.scalar.ScalarExtractF64x4(AD4, 2));

  if nextpas.core.simd.scalar.ScalarExtractI32x8(I32A8, 7) =
     nextpas.core.simd.generated.scalar.ScalarExtractI32x8(I32A8, 7) then Inc(GPassCount)
  else begin WriteLn('FAIL: ExtractI32x8 parity'); Inc(GFailCount); end;

  if nextpas.core.simd.scalar.ScalarExtractI64x4(I64A4, -10) =
     nextpas.core.simd.generated.scalar.ScalarExtractI64x4(I64A4, -10) then Inc(GPassCount)
  else begin WriteLn('FAIL: ExtractI64x4 parity'); Inc(GFailCount); end;

  Check('ExtractF32x16',
    nextpas.core.simd.scalar.ScalarExtractF32x16(AF16, 15),
    nextpas.core.simd.generated.scalar.ScalarExtractF32x16(AF16, 15));

  if nextpas.core.simd.scalar.ScalarExtractI32x16(I32A16, 14) =
     nextpas.core.simd.generated.scalar.ScalarExtractI32x16(I32A16, 14) then Inc(GPassCount)
  else begin WriteLn('FAIL: ExtractI32x16 parity'); Inc(GFailCount); end;

  CheckVecF32x4('InsertF32x4',
    nextpas.core.simd.scalar.ScalarInsertF32x4(AF4, 77.0, 9),
    nextpas.core.simd.generated.scalar.ScalarInsertF32x4(AF4, 77.0, 9));

  CheckVecF64x2('InsertF64x2',
    nextpas.core.simd.scalar.ScalarInsertF64x2(AD2, 99.5, -1),
    nextpas.core.simd.generated.scalar.ScalarInsertF64x2(AD2, 99.5, -1));

  CheckVecI32x4('InsertI32x4',
    nextpas.core.simd.scalar.ScalarInsertI32x4(AI32, 999, 2),
    nextpas.core.simd.generated.scalar.ScalarInsertI32x4(AI32, 999, 2));

  CheckVecI64x2('InsertI64x2',
    nextpas.core.simd.scalar.ScalarInsertI64x2(I64A2, -555, 1),
    nextpas.core.simd.generated.scalar.ScalarInsertI64x2(I64A2, -555, 1));

  CheckVecF32x8('InsertF32x8',
    nextpas.core.simd.scalar.ScalarInsertF32x8(AF8, 88.0, 7),
    nextpas.core.simd.generated.scalar.ScalarInsertF32x8(AF8, 88.0, 7));

  CheckVecF64x4('InsertF64x4',
    nextpas.core.simd.scalar.ScalarInsertF64x4(AD4, 44.25, 5),
    nextpas.core.simd.generated.scalar.ScalarInsertF64x4(AD4, 44.25, 5));

  CheckVecI32x8('InsertI32x8',
    nextpas.core.simd.scalar.ScalarInsertI32x8(I32A8, 880, 0),
    nextpas.core.simd.generated.scalar.ScalarInsertI32x8(I32A8, 880, 0));

  CheckVecI64x4('InsertI64x4',
    nextpas.core.simd.scalar.ScalarInsertI64x4(I64A4, -4444, 3),
    nextpas.core.simd.generated.scalar.ScalarInsertI64x4(I64A4, -4444, 3));

  CheckVecF32x16('InsertF32x16',
    nextpas.core.simd.scalar.ScalarInsertF32x16(AF16, 123.5, 14),
    nextpas.core.simd.generated.scalar.ScalarInsertF32x16(AF16, 123.5, 14));

  CheckVecI32x16('InsertI32x16',
    nextpas.core.simd.scalar.ScalarInsertI32x16(I32A16, 1600, 99),
    nextpas.core.simd.generated.scalar.ScalarInsertI32x16(I32A16, 1600, 99));

  // === I16x32 Shift Boundary Parity ===
  LI16C32_Existing := nextpas.core.simd.scalar.ScalarShiftLeftI16x32(LI16A32, 3);
  LI16C32_Generated := nextpas.core.simd.generated.scalar.ScalarShiftLeftI16x32(LI16A32, 3);
  CheckVecI16x32('ShiftLeftI16x32/3', LI16C32_Existing, LI16C32_Generated);

  LI16C32_Existing := nextpas.core.simd.scalar.ScalarShiftLeftI16x32(LI16A32, -1);
  LI16C32_Generated := nextpas.core.simd.generated.scalar.ScalarShiftLeftI16x32(LI16A32, -1);
  CheckVecI16x32('ShiftLeftI16x32/-1', LI16C32_Existing, LI16C32_Generated);

  LI16C32_Existing := nextpas.core.simd.scalar.ScalarShiftRightI16x32(LI16A32, 2);
  LI16C32_Generated := nextpas.core.simd.generated.scalar.ScalarShiftRightI16x32(LI16A32, 2);
  CheckVecI16x32('ShiftRightI16x32/2', LI16C32_Existing, LI16C32_Generated);

  LI16C32_Existing := nextpas.core.simd.scalar.ScalarShiftRightI16x32(LI16A32, 16);
  LI16C32_Generated := nextpas.core.simd.generated.scalar.ScalarShiftRightI16x32(LI16A32, 16);
  CheckVecI16x32('ShiftRightI16x32/16', LI16C32_Existing, LI16C32_Generated);

  LI16C32_Existing := nextpas.core.simd.scalar.ScalarShiftRightArithI16x32(LI16A32, 2);
  LI16C32_Generated := nextpas.core.simd.generated.scalar.ScalarShiftRightArithI16x32(LI16A32, 2);
  CheckVecI16x32('ShiftRightArithI16x32/2', LI16C32_Existing, LI16C32_Generated);

  LI16C32_Existing := nextpas.core.simd.scalar.ScalarShiftRightArithI16x32(LI16A32, -1);
  LI16C32_Generated := nextpas.core.simd.generated.scalar.ScalarShiftRightArithI16x32(LI16A32, -1);
  CheckVecI16x32('ShiftRightArithI16x32/-1', LI16C32_Existing, LI16C32_Generated);

  LI16C32_Existing := nextpas.core.simd.scalar.ScalarShiftRightArithI16x32(LI16A32, 16);
  LI16C32_Generated := nextpas.core.simd.generated.scalar.ScalarShiftRightArithI16x32(LI16A32, 16);
  CheckVecI16x32('ShiftRightArithI16x32/16', LI16C32_Existing, LI16C32_Generated);

  // === I64 ShiftRightArith Parity (regression: SarLongInt vs SarInt64) ===
  I64A2.i[0] := Int64($7FFFFFFF00000001);
  I64A2.i[1] := Int64($FFFFFFFF80000000);
  I64C2_Existing := nextpas.core.simd.scalar.ScalarShiftRightArithI64x2(I64A2, 4);
  I64C2_Generated := nextpas.core.simd.generated.scalar.ScalarShiftRightArithI64x2(I64A2, 4);
  CheckVecI64x2('ShiftRightArithI64x2/4', I64C2_Existing, I64C2_Generated);

  I64C2_Existing := nextpas.core.simd.scalar.ScalarShiftRightArithI64x2(I64A2, 0);
  I64C2_Generated := nextpas.core.simd.generated.scalar.ScalarShiftRightArithI64x2(I64A2, 0);
  CheckVecI64x2('ShiftRightArithI64x2/0', I64C2_Existing, I64C2_Generated);

  I64C2_Existing := nextpas.core.simd.scalar.ScalarShiftRightArithI64x2(I64A2, 63);
  I64C2_Generated := nextpas.core.simd.generated.scalar.ScalarShiftRightArithI64x2(I64A2, 63);
  CheckVecI64x2('ShiftRightArithI64x2/63', I64C2_Existing, I64C2_Generated);

  I64A4.i[0] := Int64($8000000000000001);
  I64A4.i[1] := Int64($0000000100000000);
  I64A4.i[2] := Int64($FFFFFFFFFFFFFFFE);
  I64A4.i[3] := Int64($7FFFFFFFFFFFFFFF);
  I64C4_Existing := nextpas.core.simd.scalar.ScalarShiftRightArithI64x4(I64A4, 1);
  I64C4_Generated := nextpas.core.simd.generated.scalar.ScalarShiftRightArithI64x4(I64A4, 1);
  CheckVecI64x4('ShiftRightArithI64x4/1', I64C4_Existing, I64C4_Generated);

  I64C4_Existing := nextpas.core.simd.scalar.ScalarShiftRightArithI64x4(I64A4, 32);
  I64C4_Generated := nextpas.core.simd.generated.scalar.ScalarShiftRightArithI64x4(I64A4, 32);
  CheckVecI64x4('ShiftRightArithI64x4/32', I64C4_Existing, I64C4_Generated);

  // === Pointer/Text Helper Parity ===
  Utf8Valid[0] := $41;
  Utf8Valid[1] := $C2;
  Utf8Valid[2] := $A2;
  Utf8Valid[3] := $E2;
  Utf8Valid[4] := $82;
  Utf8Valid[5] := $AC;
  Utf8Overlong[0] := $C0;
  Utf8Overlong[1] := $AF;
  Utf8Incomplete[0] := $E2;
  Utf8Incomplete[1] := $82;

  CheckLongBool('MemEqual/equal',
    nextpas.core.simd.scalar.MemEqual_Scalar(@HelperA[0], @HelperB[0], 16),
    nextpas.core.simd.generated.scalar.MemEqual_Scalar(@HelperA[0], @HelperB[0], 16));

  CheckLongBool('MemEqual/mismatch',
    nextpas.core.simd.scalar.MemEqual_Scalar(@HelperA[0], @HelperC[0], 16),
    nextpas.core.simd.generated.scalar.MemEqual_Scalar(@HelperA[0], @HelperC[0], 16));

  CheckLongBool('MemEqual/nil-nil',
    nextpas.core.simd.scalar.MemEqual_Scalar(nil, nil, 16),
    nextpas.core.simd.generated.scalar.MemEqual_Scalar(nil, nil, 16));

  CheckLongBool('MemEqual/nil-nonzero',
    nextpas.core.simd.scalar.MemEqual_Scalar(nil, @HelperA[0], 16),
    nextpas.core.simd.generated.scalar.MemEqual_Scalar(nil, @HelperA[0], 16));

  CheckBool('AsciiIEqual/case-insensitive',
    nextpas.core.simd.scalar.AsciiIEqual_Scalar(@AsciiA[0], @AsciiB[0], 4),
    nextpas.core.simd.generated.scalar.AsciiIEqual_Scalar(@AsciiA[0], @AsciiB[0], 4));

  CheckBool('AsciiIEqual/mismatch',
    nextpas.core.simd.scalar.AsciiIEqual_Scalar(@AsciiA[0], @AsciiC[0], 4),
    nextpas.core.simd.generated.scalar.AsciiIEqual_Scalar(@AsciiA[0], @AsciiC[0], 4));

  CheckBool('AsciiIEqual/nil-nil',
    nextpas.core.simd.scalar.AsciiIEqual_Scalar(nil, nil, 4),
    nextpas.core.simd.generated.scalar.AsciiIEqual_Scalar(nil, nil, 4));

  CheckBool('AsciiIEqual/nil-nonzero',
    nextpas.core.simd.scalar.AsciiIEqual_Scalar(nil, @AsciiA[0], 4),
    nextpas.core.simd.generated.scalar.AsciiIEqual_Scalar(nil, @AsciiA[0], 4));

  CheckBool('AsciiIEqual/zero-len',
    nextpas.core.simd.scalar.AsciiIEqual_Scalar(nil, @AsciiA[0], 0),
    nextpas.core.simd.generated.scalar.AsciiIEqual_Scalar(nil, @AsciiA[0], 0));

  HelperB[9] := 0;
  HelperC[9] := 1;
  nextpas.core.simd.scalar.MemCopy_Scalar(@HelperA[0], @HelperB[0], 16);
  nextpas.core.simd.generated.scalar.MemCopy_Scalar(@HelperA[0], @HelperC[0], 16);
  CheckBool('MemCopy', True, SameByteBuffer(@HelperB[0], @HelperC[0], 16));

  Move(HelperA[0], HelperB[0], Length(HelperA));
  Move(HelperA[0], HelperC[0], Length(HelperA));
  nextpas.core.simd.scalar.MemReverse_Scalar(@HelperB[0], 16);
  nextpas.core.simd.generated.scalar.MemReverse_Scalar(@HelperC[0], 16);
  CheckBool('MemReverse', True, SameByteBuffer(@HelperB[0], @HelperC[0], 16));

  HelperB[0] := 0;
  HelperC[0] := 1;
  nextpas.core.simd.scalar.MemSet_Scalar(@HelperB[0], 16, $AB);
  nextpas.core.simd.generated.scalar.MemSet_Scalar(@HelperC[0], 16, $AB);
  CheckBool('MemSet', True, SameByteBuffer(@HelperB[0], @HelperC[0], 16));

  Move(AsciiA[0], AsciiB[0], Length(AsciiA));
  Move(AsciiA[0], AsciiC[0], Length(AsciiA));
  nextpas.core.simd.scalar.ToLowerAscii_Scalar(@AsciiB[0], 4);
  nextpas.core.simd.generated.scalar.ToLowerAscii_Scalar(@AsciiC[0], 4);
  CheckBool('ToLowerAscii', True, SameByteBuffer(@AsciiB[0], @AsciiC[0], 4));

  Move(AsciiA[0], AsciiB[0], Length(AsciiA));
  Move(AsciiA[0], AsciiC[0], Length(AsciiA));
  nextpas.core.simd.scalar.ToUpperAscii_Scalar(@AsciiB[0], 4);
  nextpas.core.simd.generated.scalar.ToUpperAscii_Scalar(@AsciiC[0], 4);
  CheckBool('ToUpperAscii', True, SameByteBuffer(@AsciiB[0], @AsciiC[0], 4));

  CheckBool('Utf8Validate/valid',
    nextpas.core.simd.scalar.Utf8Validate_Scalar(@Utf8Valid[0], 6),
    nextpas.core.simd.generated.scalar.Utf8Validate_Scalar(@Utf8Valid[0], 6));

  CheckBool('Utf8Validate/overlong',
    nextpas.core.simd.scalar.Utf8Validate_Scalar(@Utf8Overlong[0], 2),
    nextpas.core.simd.generated.scalar.Utf8Validate_Scalar(@Utf8Overlong[0], 2));

  CheckBool('Utf8Validate/incomplete',
    nextpas.core.simd.scalar.Utf8Validate_Scalar(@Utf8Incomplete[0], 2),
    nextpas.core.simd.generated.scalar.Utf8Validate_Scalar(@Utf8Incomplete[0], 2));

  CheckBool('Utf8Validate/nil-nonzero',
    nextpas.core.simd.scalar.Utf8Validate_Scalar(nil, 1),
    nextpas.core.simd.generated.scalar.Utf8Validate_Scalar(nil, 1));

  CheckBool('Utf8Validate/zero-len',
    nextpas.core.simd.scalar.Utf8Validate_Scalar(nil, 0),
    nextpas.core.simd.generated.scalar.Utf8Validate_Scalar(nil, 0));

  // === Byte Aggregate Parity ===
  CheckUInt64('SumBytes',
    nextpas.core.simd.scalar.SumBytes_Scalar(@ByteStats[0], Length(ByteStats)),
    nextpas.core.simd.generated.scalar.SumBytes_Scalar(@ByteStats[0], Length(ByteStats)));

  CheckUInt64('SumBytes/zero',
    UInt64(nextpas.core.simd.scalar.SumBytes_Scalar(nil, 0)),
    UInt64(nextpas.core.simd.generated.scalar.SumBytes_Scalar(nil, 0)));

  CheckUInt64('CountByte',
    UInt64(nextpas.core.simd.scalar.CountByte_Scalar(@ByteStats[0], Length(ByteStats), 7)),
    UInt64(nextpas.core.simd.generated.scalar.CountByte_Scalar(@ByteStats[0], Length(ByteStats), 7)));

  CheckUInt64('CountByte/zero',
    UInt64(nextpas.core.simd.scalar.CountByte_Scalar(nil, 0, 7)),
    UInt64(nextpas.core.simd.generated.scalar.CountByte_Scalar(nil, 0, 7)));

  CheckUInt64('BitsetPopCount',
    UInt64(nextpas.core.simd.scalar.BitsetPopCount_Scalar(@ByteStats[0], Length(ByteStats))),
    UInt64(nextpas.core.simd.generated.scalar.BitsetPopCount_Scalar(@ByteStats[0], Length(ByteStats))));

  CheckUInt64('BitsetPopCount/zero',
    UInt64(nextpas.core.simd.scalar.BitsetPopCount_Scalar(nil, 0)),
    UInt64(nextpas.core.simd.generated.scalar.BitsetPopCount_Scalar(nil, 0)));

  // === Byte Search / Range Helper Parity ===
  CheckPtrInt('MemFindByte/found',
    nextpas.core.simd.scalar.MemFindByte_Scalar(@HelperA[0], 16, HelperA[7]),
    nextpas.core.simd.generated.scalar.MemFindByte_Scalar(@HelperA[0], 16, HelperA[7]));

  CheckPtrInt('MemFindByte/not-found',
    nextpas.core.simd.scalar.MemFindByte_Scalar(@HelperA[0], 16, $FF),
    nextpas.core.simd.generated.scalar.MemFindByte_Scalar(@HelperA[0], 16, $FF));

  CheckPtrInt('MemFindByte/nil-zero',
    nextpas.core.simd.scalar.MemFindByte_Scalar(nil, 0, $FF),
    nextpas.core.simd.generated.scalar.MemFindByte_Scalar(nil, 0, $FF));

  CheckBool('MemDiffRange/mismatch',
    nextpas.core.simd.scalar.MemDiffRange_Scalar(@HelperA[0], @HelperC[0], 16, FirstExisting, LastExisting),
    nextpas.core.simd.generated.scalar.MemDiffRange_Scalar(@HelperA[0], @HelperC[0], 16, FirstGenerated, LastGenerated));
  CheckUInt64('MemDiffRange/mismatch-first', UInt64(FirstExisting), UInt64(FirstGenerated));
  CheckUInt64('MemDiffRange/mismatch-last', UInt64(LastExisting), UInt64(LastGenerated));

  CheckBool('MemDiffRange/equal',
    nextpas.core.simd.scalar.MemDiffRange_Scalar(@HelperA[0], @HelperB[0], 16, FirstExisting, LastExisting),
    nextpas.core.simd.generated.scalar.MemDiffRange_Scalar(@HelperA[0], @HelperB[0], 16, FirstGenerated, LastGenerated));

  CheckBool('MemDiffRange/nil-nonzero',
    nextpas.core.simd.scalar.MemDiffRange_Scalar(nil, @HelperA[0], 16, FirstExisting, LastExisting),
    nextpas.core.simd.generated.scalar.MemDiffRange_Scalar(nil, @HelperA[0], 16, FirstGenerated, LastGenerated));
  CheckUInt64('MemDiffRange/nil-first', UInt64(FirstExisting), UInt64(FirstGenerated));
  CheckUInt64('MemDiffRange/nil-last', UInt64(LastExisting), UInt64(LastGenerated));

  nextpas.core.simd.scalar.MinMaxBytes_Scalar(@ByteStats[0], Length(ByteStats), MinExisting, MaxExisting);
  nextpas.core.simd.generated.scalar.MinMaxBytes_Scalar(@ByteStats[0], Length(ByteStats), MinGenerated, MaxGenerated);
  CheckByte('MinMaxBytes/min', MinExisting, MinGenerated);
  CheckByte('MinMaxBytes/max', MaxExisting, MaxGenerated);

  nextpas.core.simd.scalar.MinMaxBytes_Scalar(nil, 0, MinExisting, MaxExisting);
  nextpas.core.simd.generated.scalar.MinMaxBytes_Scalar(nil, 0, MinGenerated, MaxGenerated);
  CheckByte('MinMaxBytes/nil-min', MinExisting, MinGenerated);
  CheckByte('MinMaxBytes/nil-max', MaxExisting, MaxGenerated);

  CheckPtrInt('BytesIndexOf/found',
    nextpas.core.simd.scalar.BytesIndexOf_Scalar(@HelperA[0], 16, @HelperA[3], 3),
    nextpas.core.simd.generated.scalar.BytesIndexOf_Scalar(@HelperA[0], 16, @HelperA[3], 3));

  CheckPtrInt('BytesIndexOf/not-found',
    nextpas.core.simd.scalar.BytesIndexOf_Scalar(@HelperA[0], 16, @ByteStats[1], 3),
    nextpas.core.simd.generated.scalar.BytesIndexOf_Scalar(@HelperA[0], 16, @ByteStats[1], 3));

  CheckPtrInt('BytesIndexOf/zero-needle',
    nextpas.core.simd.scalar.BytesIndexOf_Scalar(@HelperA[0], 16, @HelperA[0], 0),
    nextpas.core.simd.generated.scalar.BytesIndexOf_Scalar(@HelperA[0], 16, @HelperA[0], 0));

  CheckPtrInt('BytesIndexOf/nil-haystack',
    nextpas.core.simd.scalar.BytesIndexOf_Scalar(nil, 16, @HelperA[0], 1),
    nextpas.core.simd.generated.scalar.BytesIndexOf_Scalar(nil, 16, @HelperA[0], 1));

  // === Reduce Parity ===
  Check('ReduceAddF32x4',
    nextpas.core.simd.scalar.ScalarReduceAddF32x4(AF4),
    nextpas.core.simd.generated.scalar.ScalarReduceAddF32x4(AF4));

  Check('ReduceMinF32x4',
    nextpas.core.simd.scalar.ScalarReduceMinF32x4(AF4),
    nextpas.core.simd.generated.scalar.ScalarReduceMinF32x4(AF4));

  Check('ReduceMaxF32x4',
    nextpas.core.simd.scalar.ScalarReduceMaxF32x4(AF4),
    nextpas.core.simd.generated.scalar.ScalarReduceMaxF32x4(AF4));

  Check('ReduceSumF32',
    nextpas.core.simd.scalar.ScalarReduceSumF32(@BatchA[0], Length(BatchA)),
    nextpas.core.simd.generated.scalar.ScalarReduceSumF32(@BatchA[0], Length(BatchA)));

  Check('ReduceMinF32',
    nextpas.core.simd.scalar.ScalarReduceMinF32(@BatchA[0], Length(BatchA)),
    nextpas.core.simd.generated.scalar.ScalarReduceMinF32(@BatchA[0], Length(BatchA)));

  Check('ReduceMaxF32',
    nextpas.core.simd.scalar.ScalarReduceMaxF32(@BatchA[0], Length(BatchA)),
    nextpas.core.simd.generated.scalar.ScalarReduceMaxF32(@BatchA[0], Length(BatchA)));

  Check('ReduceDotF32',
    nextpas.core.simd.scalar.ScalarReduceDotF32(@BatchA[0], @BatchB[0], Length(BatchA)),
    nextpas.core.simd.generated.scalar.ScalarReduceDotF32(@BatchA[0], @BatchB[0], Length(BatchA)));

  Check('ReduceMinF32/zero',
    nextpas.core.simd.scalar.ScalarReduceMinF32(@BatchA[0], 0),
    nextpas.core.simd.generated.scalar.ScalarReduceMinF32(@BatchA[0], 0));

  Check('ReduceMaxF32/zero',
    nextpas.core.simd.scalar.ScalarReduceMaxF32(@BatchA[0], 0),
    nextpas.core.simd.generated.scalar.ScalarReduceMaxF32(@BatchA[0], 0));

  // === Batch Array Arithmetic Parity ===
  nextpas.core.simd.scalar.ScalarArrayAddF32(@BatchA[0], @BatchB[0], @BatchExisting[0], Length(BatchA));
  nextpas.core.simd.generated.scalar.ScalarArrayAddF32(@BatchA[0], @BatchB[0], @BatchGenerated[0], Length(BatchA));
  CheckSingleArray('ArrayAddF32', BatchExisting, BatchGenerated);
  nextpas.core.simd.scalar.ScalarArrayAddF32(nil, nil, nil, 0);
  nextpas.core.simd.generated.scalar.ScalarArrayAddF32(nil, nil, nil, 0);

  nextpas.core.simd.scalar.ScalarArrayMulF32(@BatchA[0], @BatchB[0], @BatchExisting[0], Length(BatchA));
  nextpas.core.simd.generated.scalar.ScalarArrayMulF32(@BatchA[0], @BatchB[0], @BatchGenerated[0], Length(BatchA));
  CheckSingleArray('ArrayMulF32', BatchExisting, BatchGenerated);
  nextpas.core.simd.scalar.ScalarArrayMulF32(nil, nil, nil, 0);
  nextpas.core.simd.generated.scalar.ScalarArrayMulF32(nil, nil, nil, 0);

  nextpas.core.simd.scalar.ScalarArrayMulScalarF32(@BatchA[0], @BatchExisting[0], Length(BatchA), -2.0);
  nextpas.core.simd.generated.scalar.ScalarArrayMulScalarF32(@BatchA[0], @BatchGenerated[0], Length(BatchA), -2.0);
  CheckSingleArray('ArrayMulScalarF32', BatchExisting, BatchGenerated);
  nextpas.core.simd.scalar.ScalarArrayMulScalarF32(nil, nil, 0, -2.0);
  nextpas.core.simd.generated.scalar.ScalarArrayMulScalarF32(nil, nil, 0, -2.0);

  nextpas.core.simd.scalar.ScalarArrayAxpyF32(2.0, @BatchA[0], @BatchB[0], @BatchExisting[0], Length(BatchA));
  nextpas.core.simd.generated.scalar.ScalarArrayAxpyF32(2.0, @BatchA[0], @BatchB[0], @BatchGenerated[0], Length(BatchA));
  CheckSingleArray('ArrayAxpyF32', BatchExisting, BatchGenerated);
  nextpas.core.simd.scalar.ScalarArrayAxpyF32(2.0, nil, nil, nil, 0);
  nextpas.core.simd.generated.scalar.ScalarArrayAxpyF32(2.0, nil, nil, nil, 0);

  // === Mask Helper Parity ===
  if nextpas.core.simd.scalar.ScalarMask2All(TMask2($03)) =
     nextpas.core.simd.generated.scalar.ScalarMask2All(TMask2($03)) then Inc(GPassCount)
  else begin WriteLn('FAIL: Mask2All parity'); Inc(GFailCount); end;

  if nextpas.core.simd.scalar.ScalarMask4Any(TMask4($08)) =
     nextpas.core.simd.generated.scalar.ScalarMask4Any(TMask4($08)) then Inc(GPassCount)
  else begin WriteLn('FAIL: Mask4Any parity'); Inc(GFailCount); end;

  if nextpas.core.simd.scalar.ScalarMask8None(TMask8($00)) =
     nextpas.core.simd.generated.scalar.ScalarMask8None(TMask8($00)) then Inc(GPassCount)
  else begin WriteLn('FAIL: Mask8None parity'); Inc(GFailCount); end;

  if nextpas.core.simd.scalar.ScalarMask16PopCount(TMask16($00FF)) =
     nextpas.core.simd.generated.scalar.ScalarMask16PopCount(TMask16($00FF)) then Inc(GPassCount)
  else begin WriteLn('FAIL: Mask16PopCount parity'); Inc(GFailCount); end;

  if nextpas.core.simd.scalar.ScalarMask16FirstSet(TMask16($0040)) =
     nextpas.core.simd.generated.scalar.ScalarMask16FirstSet(TMask16($0040)) then Inc(GPassCount)
  else begin WriteLn('FAIL: Mask16FirstSet parity'); Inc(GFailCount); end;

  // === Saturating Arithmetic Parity ===
  for i := 0 to 15 do
  begin
    LI8A.i[i] := 120 - i;
    LI8B.i[i] := 20 + i;
    LU8A.u[i] := 250 - i;
    LU8B.u[i] := 10 + i;
  end;
  for i := 0 to 7 do
  begin
    LI16A.i[i] := 32000 - (i * 10);
    LI16B.i[i] := 1000 + (i * 20);
    LU16A.u[i] := 65000 - (i * 100);
    LU16B.u[i] := 1000 + (i * 50);
  end;

  LI8_Existing := nextpas.core.simd.scalar.ScalarI8x16SatAdd(LI8A, LI8B);
  LI8_Generated := nextpas.core.simd.generated.scalar.ScalarI8x16SatAdd(LI8A, LI8B);
  CheckVecI8x16('I8x16SatAdd', LI8_Existing, LI8_Generated);

  LI8_Existing := nextpas.core.simd.scalar.ScalarI8x16SatSub(LI8A, LI8B);
  LI8_Generated := nextpas.core.simd.generated.scalar.ScalarI8x16SatSub(LI8A, LI8B);
  CheckVecI8x16('I8x16SatSub', LI8_Existing, LI8_Generated);

  LI16_Existing := nextpas.core.simd.scalar.ScalarI16x8SatAdd(LI16A, LI16B);
  LI16_Generated := nextpas.core.simd.generated.scalar.ScalarI16x8SatAdd(LI16A, LI16B);
  CheckVecI16x8('I16x8SatAdd', LI16_Existing, LI16_Generated);

  LI16_Existing := nextpas.core.simd.scalar.ScalarI16x8SatSub(LI16A, LI16B);
  LI16_Generated := nextpas.core.simd.generated.scalar.ScalarI16x8SatSub(LI16A, LI16B);
  CheckVecI16x8('I16x8SatSub', LI16_Existing, LI16_Generated);

  LU8_Existing := nextpas.core.simd.scalar.ScalarU8x16SatAdd(LU8A, LU8B);
  LU8_Generated := nextpas.core.simd.generated.scalar.ScalarU8x16SatAdd(LU8A, LU8B);
  CheckVecU8x16('U8x16SatAdd', LU8_Existing, LU8_Generated);

  LU8_Existing := nextpas.core.simd.scalar.ScalarU8x16SatSub(LU8A, LU8B);
  LU8_Generated := nextpas.core.simd.generated.scalar.ScalarU8x16SatSub(LU8A, LU8B);
  CheckVecU8x16('U8x16SatSub', LU8_Existing, LU8_Generated);

  LU16_Existing := nextpas.core.simd.scalar.ScalarU16x8SatAdd(LU16A, LU16B);
  LU16_Generated := nextpas.core.simd.generated.scalar.ScalarU16x8SatAdd(LU16A, LU16B);
  CheckVecU16x8('U16x8SatAdd', LU16_Existing, LU16_Generated);

  LU16_Existing := nextpas.core.simd.scalar.ScalarU16x8SatSub(LU16A, LU16B);
  LU16_Generated := nextpas.core.simd.generated.scalar.ScalarU16x8SatSub(LU16A, LU16B);
  CheckVecU16x8('U16x8SatSub', LU16_Existing, LU16_Generated);

  // Summary
  WriteLn;
  if GFailCount = 0 then
    WriteLn('PARITY OK: ', GPassCount, ' checks passed, 0 failures')
  else
  begin
    WriteLn('PARITY FAILED: ', GPassCount, ' passed, ', GFailCount, ' failed');
    Halt(1);
  end;
  WriteLn('  Generated scalar implementations are semantically identical to hand-written ones.');
end.
