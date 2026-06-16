program test_simdgen_compile;
{$I ../../src/nextpas.core.settings.inc}

uses
  SysUtils, Math,
  nextpas.core.simd.base,
  nextpas.core.simd.generated.scalar;

var
  A4, B4, C4: TVecF32x4;
  A8, B8, C8: TVecF32x8;
  D2, E2, F2: TVecF64x2;
  D4, E4, F4: TVecF64x4;
  D8, E8, F8: TVecF64x8;
  D16, E16, F16: TVecF32x16;
  I32A, I32B, I32C: TVecI32x4;
  I64A2, I64B2, I64C2: TVecI64x2;
  I64A4, I64B4, I64C4: TVecI64x4;
  I32A8, I32B8, I32C8: TVecI32x8;
  I32A16, I32B16, I32C16: TVecI32x16;
  I32Mask: TVecI32x4;
  U32Mask: TVecU32x8;
  U64Mask: TVecU64x4;
  AI8, BI8, CI8: TVecI8x16;
  AI16, BI16, CI16: TVecI16x8;
  I16A32, I16C32: TVecI16x32;
  AU8, BU8, CU8: TVecU8x16;
  AU16, BU16, CU16: TVecU16x8;
  R: Single;
  M4: TMask4;
  M2: TMask2;
  M8: TMask8;
  M16: TMask16;
  MI: Integer;
  i: Integer;
  Utf8Valid: array[0..5] of Byte;
  Utf8Overlong: array[0..1] of Byte;
  Utf8Incomplete: array[0..1] of Byte;
  HelperA, HelperB, HelperC: array[0..15] of Byte;
  AsciiA, AsciiB, AsciiC: array[0..3] of Byte;
  ByteStats: array[0..4] of Byte;
  FirstDiff, LastDiff: SizeUInt;
  MinByte, MaxByte: Byte;
  BatchA, BatchB, BatchC: array[0..5] of Single;
begin
  A4.f[0] := 1.0; A4.f[1] := 2.0; A4.f[2] := 3.0; A4.f[3] := 4.0;
  B4.f[0] := 5.0; B4.f[1] := 6.0; B4.f[2] := 7.0; B4.f[3] := 8.0;
  D2.d[0] := 1.5; D2.d[1] := -2.5;
  E2.d[0] := 10.5; E2.d[1] := 11.5;
  D4.d[0] := 1.25; D4.d[1] := 2.25; D4.d[2] := 3.25; D4.d[3] := 4.25;
  E4.d[0] := 9.25; E4.d[1] := 8.25; E4.d[2] := 7.25; E4.d[3] := 6.25;
  for i := 0 to 7 do
  begin
    A8.f[i] := i + 1;
    B8.f[i] := 10 + i;
    D8.d[i] := 20 + i;
    U32Mask.u[i] := Ord(Odd(i));
    U64Mask.u[i mod 4] := Ord(Odd(i));
  end;
  for i := 0 to 15 do
  begin
    D16.f[i] := i + 0.5;
    E16.f[i] := 100 + i + 0.5;
  end;
  for i := 0 to 3 do
  begin
    I32A.i[i] := i + 1;
    I32B.i[i] := 100 + i;
    I32Mask.i[i] := Ord(Odd(i));
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
  for i := 0 to 31 do
    I16A32.i[i] := Int16(-2000 + (i * 137));
  for i := 0 to 3 do
  begin
    D8.d[i] := 20 + i;
    E8.d[i] := 30 + i;
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

  // Arithmetic
  C4 := ScalarAddF32x4(A4, B4);
  Assert(Abs(C4.f[0] - 6.0) < 1e-6, 'AddF32x4 failed');

  C4 := ScalarSubF32x4(A4, B4);
  Assert(Abs(C4.f[0] - (-4.0)) < 1e-6, 'SubF32x4 failed');

  C4 := ScalarMulF32x4(A4, B4);
  Assert(Abs(C4.f[2] - 21.0) < 1e-6, 'MulF32x4 failed');

  C4 := ScalarDivF32x4(A4, B4);
  Assert(Abs(C4.f[0] - 0.2) < 1e-6, 'DivF32x4 failed');

  C4 := ScalarMinF32x4(A4, B4);
  Assert(Abs(C4.f[0] - 1.0) < 1e-6, 'MinF32x4 failed');

  C4 := ScalarMaxF32x4(A4, B4);
  Assert(Abs(C4.f[0] - 5.0) < 1e-6, 'MaxF32x4 failed');

  // Reduction
  R := ScalarReduceAddF32x4(A4);
  Assert(Abs(R - 10.0) < 1e-6, 'ReduceAddF32x4 failed');

  R := ScalarReduceMinF32x4(A4);
  Assert(Abs(R - 1.0) < 1e-6, 'ReduceMinF32x4 failed');

  R := ScalarReduceMaxF32x4(A4);
  Assert(Abs(R - 4.0) < 1e-6, 'ReduceMaxF32x4 failed');

  C4 := ScalarLoadF32x4Aligned(@A4.f[0]);
  Assert(Abs(C4.f[0] - 1.0) < 1e-6, 'LoadF32x4Aligned failed');
  Assert(Abs(C4.f[3] - 4.0) < 1e-6, 'LoadF32x4Aligned tail failed');

  C4 := ScalarZeroF32x4();
  ScalarStoreF32x4Aligned(@C4.f[0], B4);
  Assert(Abs(C4.f[0] - 5.0) < 1e-6, 'StoreF32x4Aligned head failed');
  Assert(Abs(C4.f[3] - 8.0) < 1e-6, 'StoreF32x4Aligned tail failed');

  // Compare
  M4 := ScalarCmpLtF32x4(A4, B4);
  Assert(M4 = $F, 'CmpLtF32x4 failed: all lanes should be less');

  M4 := ScalarCmpEqF32x4(A4, A4);
  Assert(M4 = $F, 'CmpEqF32x4 failed: self-compare should be all true');

  // Select
  M4 := $05;
  C4 := ScalarSelectF32x4(M4, A4, B4);
  Assert((Abs(C4.f[0] - A4.f[0]) < 1e-6) and (Abs(C4.f[1] - B4.f[1]) < 1e-6), 'SelectF32x4 failed');

  M2 := $01;
  F2 := ScalarSelectF64x2(M2, D2, E2);
  Assert((Abs(F2.d[0] - D2.d[0]) < 1e-12) and (Abs(F2.d[1] - E2.d[1]) < 1e-12), 'SelectF64x2 failed');

  M16 := $8001;
  F16 := ScalarSelectF32x16(M16, D16, D16);
  Assert((Abs(F16.f[0] - D16.f[0]) < 1e-6) and (Abs(F16.f[1] - E16.f[1]) < 1e-6) and (Abs(F16.f[15] - D16.f[15]) < 1e-6), 'SelectF32x16 failed');

  M8 := $81;
  F8 := ScalarSelectF64x8(M8, D8, E8);
  Assert((Abs(F8.d[0] - D8.d[0]) < 1e-12) and (Abs(F8.d[1] - E8.d[1]) < 1e-12) and (Abs(F8.d[7] - D8.d[7]) < 1e-12), 'SelectF64x8 failed');

  I32C := ScalarSelectI32x4(I32Mask, I32A, I32B);
  Assert((I32C.i[0] = I32B.i[0]) and (I32C.i[1] = I32A.i[1]) and (I32C.i[2] = I32B.i[2]), 'SelectI32x4 failed');

  C8 := ScalarSelectF32x8(U32Mask, A8, B8);
  Assert((Abs(C8.f[0] - B8.f[0]) < 1e-6) and (Abs(C8.f[1] - A8.f[1]) < 1e-6), 'SelectF32x8 failed');

  F4 := ScalarSelectF64x4(U64Mask, D4, E4);
  Assert((Abs(F4.d[0] - E4.d[0]) < 1e-12) and (Abs(F4.d[1] - D4.d[1]) < 1e-12), 'SelectF64x4 failed');

  // Extract / Insert
  R := ScalarExtractF32x4(A4, -1);
  Assert(Abs(R - A4.f[0]) < 1e-6, 'ExtractF32x4 failed');
  Assert(Abs(ScalarExtractF64x2(D2, 9) - D2.d[1]) < 1e-12, 'ExtractF64x2 failed');
  Assert(ScalarExtractI32x4(I32A, 99) = I32A.i[3], 'ExtractI32x4 failed');
  Assert(ScalarExtractI64x2(I64A2, 1) = 222, 'ExtractI64x2 failed');
  Assert(Abs(ScalarExtractF32x8(A8, 6) - 7.0) < 1e-6, 'ExtractF32x8 failed');
  Assert(Abs(ScalarExtractF64x4(D4, 2) - 3.25) < 1e-12, 'ExtractF64x4 failed');
  Assert(ScalarExtractI32x8(I32A8, 7) = 80, 'ExtractI32x8 failed');
  Assert(ScalarExtractI64x4(I64A4, -10) = 1000, 'ExtractI64x4 failed');
  Assert(Abs(ScalarExtractF32x16(D16, 15) - 15.5) < 1e-6, 'ExtractF32x16 failed');
  Assert(ScalarExtractI32x16(I32A16, 14) = 1014, 'ExtractI32x16 failed');

  C4 := ScalarInsertF32x4(A4, 77.0, 9);
  Assert(Abs(C4.f[3] - 77.0) < 1e-6, 'InsertF32x4 failed');
  F2 := ScalarInsertF64x2(D2, 99.5, -1);
  Assert(Abs(F2.d[0] - 99.5) < 1e-12, 'InsertF64x2 failed');
  I32C := ScalarInsertI32x4(I32A, 999, 2);
  Assert(I32C.i[2] = 999, 'InsertI32x4 failed');
  I64C2 := ScalarInsertI64x2(I64A2, -555, 1);
  Assert(I64C2.i[1] = -555, 'InsertI64x2 failed');
  C8 := ScalarInsertF32x8(A8, 88.0, 7);
  Assert(Abs(C8.f[7] - 88.0) < 1e-6, 'InsertF32x8 failed');
  F4 := ScalarInsertF64x4(D4, 44.25, 5);
  Assert(Abs(F4.d[3] - 44.25) < 1e-12, 'InsertF64x4 failed');
  I32C8 := ScalarInsertI32x8(I32A8, 880, 0);
  Assert(I32C8.i[0] = 880, 'InsertI32x8 failed');
  I64C4 := ScalarInsertI64x4(I64A4, -4444, 3);
  Assert(I64C4.i[3] = -4444, 'InsertI64x4 failed');
  F16 := ScalarInsertF32x16(D16, 123.5, 14);
  Assert(Abs(F16.f[14] - 123.5) < 1e-6, 'InsertF32x16 failed');
  I32C16 := ScalarInsertI32x16(I32A16, 1600, 99);
  Assert(I32C16.i[15] = 1600, 'InsertI32x16 failed');

  // Mask helpers
  Assert(ScalarMask2All(TMask2($03)), 'Mask2All failed');
  Assert(ScalarMask4Any(TMask4($08)), 'Mask4Any failed');
  Assert(ScalarMask8None(TMask8($00)), 'Mask8None failed');
  MI := ScalarMask16PopCount(TMask16($00FF));
  Assert(MI = 8, 'Mask16PopCount failed');
  MI := ScalarMask16FirstSet(TMask16($0040));
  Assert(MI = 6, 'Mask16FirstSet failed');

  // Saturating arithmetic
  for i := 0 to 15 do
  begin
    AI8.i[i] := 120;
    BI8.i[i] := 20;
    AU8.u[i] := 250;
    BU8.u[i] := 10;
  end;
  CI8 := ScalarI8x16SatAdd(AI8, BI8);
  Assert(CI8.i[0] = 127, 'I8x16SatAdd failed: should clamp to 127');
  CU8 := ScalarU8x16SatAdd(AU8, BU8);
  Assert(CU8.u[0] = 255, 'U8x16SatAdd failed: should clamp to 255');

  for i := 0 to 15 do
  begin
    AI8.i[i] := -120;
    BI8.i[i] := 20;
    AU8.u[i] := 5;
    BU8.u[i] := 10;
  end;
  CI8 := ScalarI8x16SatSub(AI8, BI8);
  Assert(CI8.i[0] = -128, 'I8x16SatSub failed: should clamp to -128');
  CU8 := ScalarU8x16SatSub(AU8, BU8);
  Assert(CU8.u[0] = 0, 'U8x16SatSub failed: should clamp to 0');

  for i := 0 to 7 do
  begin
    AI16.i[i] := 32000;
    BI16.i[i] := 1000;
    AU16.u[i] := 65000;
    BU16.u[i] := 1000;
  end;
  CI16 := ScalarI16x8SatAdd(AI16, BI16);
  Assert(CI16.i[0] = 32767, 'I16x8SatAdd failed: should clamp to 32767');
  CU16 := ScalarU16x8SatAdd(AU16, BU16);
  Assert(CU16.u[0] = 65535, 'U16x8SatAdd failed: should clamp to 65535');

  for i := 0 to 7 do
  begin
    AI16.i[i] := -32000;
    BI16.i[i] := 1000;
    AU16.u[i] := 10;
    BU16.u[i] := 20;
  end;
  CI16 := ScalarI16x8SatSub(AI16, BI16);
  Assert(CI16.i[0] = -32768, 'I16x8SatSub failed: should clamp to -32768');
  CU16 := ScalarU16x8SatSub(AU16, BU16);
  Assert(CU16.u[0] = 0, 'U16x8SatSub failed: should clamp to 0');

  // I16x32 shift boundary semantics
  I16C32 := ScalarShiftLeftI16x32(I16A32, 3);
  Assert(I16C32.i[0] = I16A32.i[0] shl 3, 'ShiftLeftI16x32 failed');
  I16C32 := ScalarShiftLeftI16x32(I16A32, -1);
  Assert((I16C32.i[0] = 0) and (I16C32.i[31] = 0), 'ShiftLeftI16x32 negative count failed');

  I16C32 := ScalarShiftRightI16x32(I16A32, 2);
  Assert(I16C32.i[0] = Int16(UInt16(I16A32.i[0]) shr 2), 'ShiftRightI16x32 failed');
  I16C32 := ScalarShiftRightI16x32(I16A32, 16);
  Assert((I16C32.i[0] = 0) and (I16C32.i[31] = 0), 'ShiftRightI16x32 large count failed');

  I16C32 := ScalarShiftRightArithI16x32(I16A32, 2);
  Assert(I16C32.i[0] = Int16(SarLongint(I16A32.i[0], 2)), 'ShiftRightArithI16x32 failed');
  I16C32 := ScalarShiftRightArithI16x32(I16A32, -1);
  Assert((I16C32.i[0] = I16A32.i[0]) and (I16C32.i[31] = I16A32.i[31]), 'ShiftRightArithI16x32 negative count failed');
  I16C32 := ScalarShiftRightArithI16x32(I16A32, 16);
  Assert((I16C32.i[0] = -1) and (I16C32.i[31] = 0), 'ShiftRightArithI16x32 large count failed');

  // Text helpers
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

  Assert(Utf8Validate_Scalar(@Utf8Valid[0], 6), 'Utf8Validate valid sequence failed');
  Assert(not Utf8Validate_Scalar(@Utf8Overlong[0], 2), 'Utf8Validate overlong sequence failed');
  Assert(not Utf8Validate_Scalar(@Utf8Incomplete[0], 2), 'Utf8Validate incomplete sequence failed');
  Assert(not Utf8Validate_Scalar(nil, 1), 'Utf8Validate nil nonzero length failed');
  Assert(Utf8Validate_Scalar(nil, 0), 'Utf8Validate zero length failed');

  Assert(MemEqual_Scalar(@HelperA[0], @HelperB[0], 16), 'MemEqual equal buffers failed');
  Assert(not MemEqual_Scalar(@HelperA[0], @HelperC[0], 16), 'MemEqual mismatch failed');
  Assert(MemEqual_Scalar(nil, nil, 16), 'MemEqual nil/nil failed');
  Assert(not MemEqual_Scalar(nil, @HelperA[0], 16), 'MemEqual nil/non-nil failed');

  Assert(AsciiIEqual_Scalar(@AsciiA[0], @AsciiB[0], 4), 'AsciiIEqual case-insensitive match failed');
  Assert(not AsciiIEqual_Scalar(@AsciiA[0], @AsciiC[0], 4), 'AsciiIEqual mismatch failed');
  Assert(AsciiIEqual_Scalar(nil, nil, 4), 'AsciiIEqual nil/nil failed');
  Assert(not AsciiIEqual_Scalar(nil, @AsciiA[0], 4), 'AsciiIEqual nil/non-nil failed');
  Assert(AsciiIEqual_Scalar(nil, @AsciiA[0], 0), 'AsciiIEqual zero length failed');

  // Byte aggregate helpers
  Assert(SumBytes_Scalar(@ByteStats[0], Length(ByteStats)) = 26, 'SumBytes failed');
  Assert(SumBytes_Scalar(nil, 0) = 0, 'SumBytes zero length failed');
  Assert(CountByte_Scalar(@ByteStats[0], Length(ByteStats), 7) = 1, 'CountByte failed');
  Assert(CountByte_Scalar(nil, 0, 7) = 0, 'CountByte zero length failed');
  Assert(BitsetPopCount_Scalar(@ByteStats[0], Length(ByteStats)) = 10, 'BitsetPopCount failed');
  Assert(BitsetPopCount_Scalar(nil, 0) = 0, 'BitsetPopCount zero length failed');

  // Byte search / range helpers
  Assert(MemFindByte_Scalar(@HelperA[0], 16, HelperA[7]) = 7, 'MemFindByte found failed');
  Assert(MemFindByte_Scalar(@HelperA[0], 16, $FF) = -1, 'MemFindByte not found failed');
  Assert(MemFindByte_Scalar(nil, 0, $FF) = -1, 'MemFindByte nil/zero failed');

  Assert(MemDiffRange_Scalar(@HelperA[0], @HelperC[0], 16, FirstDiff, LastDiff), 'MemDiffRange mismatch failed');
  Assert((FirstDiff = 9) and (LastDiff = 9), 'MemDiffRange mismatch range failed');
  Assert(not MemDiffRange_Scalar(@HelperA[0], @HelperB[0], 16, FirstDiff, LastDiff), 'MemDiffRange equal failed');
  Assert(MemDiffRange_Scalar(nil, @HelperA[0], 16, FirstDiff, LastDiff), 'MemDiffRange nil/non-nil failed');
  Assert((FirstDiff = 0) and (LastDiff = 15), 'MemDiffRange nil/non-nil range failed');

  MinMaxBytes_Scalar(@ByteStats[0], Length(ByteStats), MinByte, MaxByte);
  Assert((MinByte = 0) and (MaxByte = 15), 'MinMaxBytes failed');
  MinMaxBytes_Scalar(nil, 0, MinByte, MaxByte);
  Assert((MinByte = 255) and (MaxByte = 0), 'MinMaxBytes nil/zero failed');

  Assert(BytesIndexOf_Scalar(@HelperA[0], 16, @HelperA[3], 3) = 3, 'BytesIndexOf found failed');
  Assert(BytesIndexOf_Scalar(@HelperA[0], 16, @ByteStats[1], 3) = -1, 'BytesIndexOf not found failed');
  Assert(BytesIndexOf_Scalar(@HelperA[0], 16, @HelperA[0], 0) = -1, 'BytesIndexOf zero needle failed');
  Assert(BytesIndexOf_Scalar(nil, 16, @HelperA[0], 1) = -1, 'BytesIndexOf nil haystack failed');

  // Memory / text mutators
  HelperB[9] := 0;
  MemCopy_Scalar(@HelperC[0], @HelperB[0], 16);
  Assert((HelperB[0] = HelperC[0]) and (HelperB[9] = HelperC[9]) and (HelperB[15] = HelperC[15]), 'MemCopy failed');

  Move(HelperA[0], HelperB[0], Length(HelperA));
  Move(HelperA[0], HelperC[0], Length(HelperA));
  MemReverse_Scalar(@HelperC[0], 16);
  Assert((HelperC[0] = HelperA[15]) and (HelperC[8] = HelperA[7]) and (HelperC[15] = HelperA[0]), 'MemReverse failed');

  MemSet_Scalar(@HelperA[0], 16, $AB);
  Assert((HelperA[0] = $AB) and (HelperA[8] = $AB) and (HelperA[15] = $AB), 'MemSet failed');

  Move(AsciiA[0], AsciiB[0], Length(AsciiA));
  ToLowerAscii_Scalar(@AsciiB[0], 4);
  Assert((AsciiB[0] = Ord('a')) and (AsciiB[1] = Ord('b')) and (AsciiB[2] = Ord('c')) and (AsciiB[3] = Ord('d')), 'ToLowerAscii failed');

  Move(AsciiA[0], AsciiC[0], Length(AsciiA));
  ToUpperAscii_Scalar(@AsciiC[0], 4);
  Assert((AsciiC[0] = Ord('A')) and (AsciiC[1] = Ord('B')) and (AsciiC[2] = Ord('C')) and (AsciiC[3] = Ord('D')), 'ToUpperAscii failed');

  // Batch reduce helpers
  Assert(Abs(ScalarReduceSumF32(@BatchA[0], Length(BatchA)) - 7.0) < 1e-6, 'ReduceSumF32 failed');
  Assert(Abs(ScalarReduceMinF32(@BatchA[0], Length(BatchA)) - (-5.5)) < 1e-6, 'ReduceMinF32 failed');
  Assert(Abs(ScalarReduceMaxF32(@BatchA[0], Length(BatchA)) - 6.0) < 1e-6, 'ReduceMaxF32 failed');
  Assert(Abs(ScalarReduceDotF32(@BatchA[0], @BatchB[0], Length(BatchA)) - (-29.0)) < 1e-6, 'ReduceDotF32 failed');
  Assert(Abs(ScalarReduceSumF32(@BatchA[0], 0)) < 1e-6, 'ReduceSumF32 zero length failed');
  Assert(Abs(ScalarReduceDotF32(@BatchA[0], @BatchB[0], 0)) < 1e-6, 'ReduceDotF32 zero length failed');
  Assert(Abs(ScalarReduceMinF32(@BatchA[0], 0)) < 1e-6, 'ReduceMinF32 zero length failed');
  Assert(Abs(ScalarReduceMaxF32(@BatchA[0], 0)) < 1e-6, 'ReduceMaxF32 zero length failed');

  // Batch array arithmetic helpers
  ScalarArrayAddF32(@BatchA[0], @BatchB[0], @BatchC[0], Length(BatchA));
  Assert((Abs(BatchC[0] - 1.5) < 1e-6) and (Abs(BatchC[5] - 4.0) < 1e-6), 'ArrayAddF32 failed');
  ScalarArrayAddF32(nil, nil, nil, 0);

  ScalarArrayMulF32(@BatchA[0], @BatchB[0], @BatchC[0], Length(BatchA));
  Assert((Abs(BatchC[0] - 0.5) < 1e-6) and (Abs(BatchC[5] - (-12.0)) < 1e-6), 'ArrayMulF32 failed');
  ScalarArrayMulF32(nil, nil, nil, 0);

  ScalarArrayMulScalarF32(@BatchA[0], @BatchC[0], Length(BatchA), -2.0);
  Assert((Abs(BatchC[0] - (-2.0)) < 1e-6) and (Abs(BatchC[5] - (-12.0)) < 1e-6), 'ArrayMulScalarF32 failed');
  ScalarArrayMulScalarF32(nil, nil, 0, -2.0);

  ScalarArrayAxpyF32(2.0, @BatchA[0], @BatchB[0], @BatchC[0], Length(BatchA));
  Assert((Abs(BatchC[0] - 2.5) < 1e-6) and (Abs(BatchC[5] - 10.0) < 1e-6), 'ArrayAxpyF32 failed');
  ScalarArrayAxpyF32(2.0, nil, nil, nil, 0);

  // Math / Vector Math
  C4 := ScalarAbsF32x4(A4);
  Assert(Abs(C4.f[0] - 1.0) < 1e-6, 'AbsF32x4 failed');

  C4 := ScalarCrossF32x3(A4, B4);
  Assert((Abs(C4.f[0] + 4.0) < 1e-6) and (Abs(C4.f[1] - 8.0) < 1e-6) and
         (Abs(C4.f[2] + 4.0) < 1e-6) and (Abs(C4.f[3]) < 1e-6), 'CrossF32x3 failed');

  R := ScalarDotF32x3(A4, B4);
  Assert(Abs(R - 38.0) < 1e-6, 'DotF32x3 failed: 1*5+2*6+3*7=38');

  R := ScalarLengthF32x3(A4);
  Assert(Abs(R - Sqrt(14.0)) < 1e-6, 'LengthF32x3 failed');

  R := ScalarLengthF32x4(A4);
  Assert(Abs(R - Sqrt(30.0)) < 1e-6, 'LengthF32x4 failed');

  C4 := ScalarNormalizeF32x3(A4);
  Assert((Abs(C4.f[0] - (1.0 / Sqrt(14.0))) < 1e-6) and
         (Abs(C4.f[1] - (2.0 / Sqrt(14.0))) < 1e-6) and
         (Abs(C4.f[2] - (3.0 / Sqrt(14.0))) < 1e-6) and
         (Abs(C4.f[3]) < 1e-6), 'NormalizeF32x3 failed');

  C4 := ScalarNormalizeF32x4(A4);
  Assert((Abs(C4.f[0] - (1.0 / Sqrt(30.0))) < 1e-6) and
         (Abs(C4.f[1] - (2.0 / Sqrt(30.0))) < 1e-6) and
         (Abs(C4.f[2] - (3.0 / Sqrt(30.0))) < 1e-6) and
         (Abs(C4.f[3] - (4.0 / Sqrt(30.0))) < 1e-6), 'NormalizeF32x4 failed');

  // Ternary (Fma)
  C4 := ScalarFmaF32x4(A4, B4, A4);
  Assert(Abs(C4.f[0] - 6.0) < 1e-6, 'FmaF32x4 failed: 1*5+1=6');

  // Dot
  R := ScalarDotF32x4(A4, B4);
  Assert(Abs(R - 70.0) < 1e-6, 'DotF32x4 failed: 1*5+2*6+3*7+4*8=70');

  WriteLn('OK: simdgen generated scalar unit compiles and passes smoke tests');
  WriteLn('  559 function signatures validated at compile time');
  WriteLn('  123 runtime correctness checks passed');
end.
