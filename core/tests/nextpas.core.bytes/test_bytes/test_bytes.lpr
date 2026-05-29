program test_bytes;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.base,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.binary,
  nextpas.core.bytes.builder,
  nextpas.core.mem;

var
  T: TTestRunner;

{ ops tests }

procedure TestEqual;
var
  LA, LB: TBytes;
begin
  LA := TBytes.Create(1, 2, 3);
  LB := TBytes.Create(1, 2, 3);
  Check(BytesEqual(LA, LB), 'equal');
  LB[2] := 4;
  Check(not BytesEqual(LA, LB), 'not equal');
  Check(BytesEqual(nil, nil), 'both empty');
end;

procedure TestCompare;
var
  LA, LB: TBytes;
begin
  LA := TBytes.Create(1, 2, 3);
  LB := TBytes.Create(1, 2, 4);
  Check(BytesCompare(LA, LB) < 0, 'less');
  Check(BytesCompare(LB, LA) > 0, 'greater');
  Check(BytesCompare(LA, LA) = 0, 'equal');
  LB := TBytes.Create(1, 2);
  Check(BytesCompare(LA, LB) > 0, 'longer is greater');
end;

procedure TestIndexOf;
var
  LD: TBytes;
begin
  LD := TBytes.Create(10, 20, 30, 40, 50);
  CheckEqual(SizeInt(0), BytesIndexOf(LD, 10), 'first');
  CheckEqual(SizeInt(4), BytesIndexOf(LD, 50), 'last');
  CheckEqual(SizeInt(-1), BytesIndexOf(LD, 99), 'not found');
end;

procedure TestStartsEndsWith;
var
  LD, LP: TBytes;
begin
  LD := TBytes.Create(1, 2, 3, 4, 5);
  LP := TBytes.Create(1, 2, 3);
  Check(BytesStartsWith(LD, LP), 'starts with');
  Check(not BytesStartsWith(LD, TBytes.Create(2, 3)), 'not starts');
  Check(BytesEndsWith(LD, TBytes.Create(4, 5)), 'ends with');
  Check(not BytesEndsWith(LD, TBytes.Create(3, 4)), 'not ends');
  Check(BytesStartsWith(LD, nil), 'empty prefix');
  Check(BytesEndsWith(LD, nil), 'empty suffix');
end;

procedure TestConcat;
var
  LA, LB, LC: TBytes;
begin
  LA := TBytes.Create(1, 2);
  LB := TBytes.Create(3, 4, 5);
  LC := BytesConcat(LA, LB);
  CheckEqual(5, System.Length(LC), 'len');
  CheckEqual(Byte(1), LC[0]);
  CheckEqual(Byte(5), LC[4]);
end;

procedure TestSpanFill;
var
  LD: TBytes;
  LS: TByteSpan;
begin
  SetLength(LD, 5);
  LS := TByteSpan.FromBytes(LD);
  SpanFill(LS, $AA);
  CheckEqual(Byte($AA), LD[0]);
  CheckEqual(Byte($AA), LD[4]);
end;

procedure TestSpanReverse;
var
  LD: TBytes;
  LS: TByteSpan;
begin
  LD := TBytes.Create(1, 2, 3, 4, 5);
  LS := TByteSpan.FromBytes(LD);
  SpanReverse(LS);
  CheckEqual(Byte(5), LD[0]);
  CheckEqual(Byte(4), LD[1]);
  CheckEqual(Byte(1), LD[4]);
end;

procedure TestSpanIndexOfSpan;
var
  LH, LN: TByteSpan;
  LD: TBytes;
begin
  LD := TBytes.Create(1, 2, 3, 4, 5, 3, 4);
  LH := TByteSpan.FromBytes(LD);
  LN := TByteSpan.FromBytes(TBytes.Create(3, 4));
  CheckEqual(SizeInt(2), SpanIndexOfSpan(LH, LN), 'found at 2');
  LN := TByteSpan.FromBytes(TBytes.Create(9, 9));
  CheckEqual(SizeInt(-1), SpanIndexOfSpan(LH, LN), 'not found');
end;

{ binary tests }

procedure TestSwap;
begin
  CheckEqual(UInt16($0201), SwapUInt16($0102), 'swap16');
  CheckEqual(UInt32($04030201), SwapUInt32($01020304), 'swap32');
  CheckEqual(UInt64($0807060504030201), SwapUInt64($0102030405060708), 'swap64');
end;

procedure TestSwapRoundTrip;
var
  LV16: UInt16;
  LV32: UInt32;
  LV64: UInt64;
begin
  LV16 := $ABCD;
  Check(SwapUInt16(SwapUInt16(LV16)) = LV16, 'roundtrip 16');
  LV32 := $DEADBEEF;
  Check(SwapUInt32(SwapUInt32(LV32)) = LV32, 'roundtrip 32');
  LV64 := $0102030405060708;
  Check(SwapUInt64(SwapUInt64(LV64)) = LV64, 'roundtrip 64');
end;

procedure TestReadWrite;
var
  LBuf: array[0..7] of Byte;
  LP: PByte;
begin
  LP := @LBuf[0];
  WriteUInt16LE(LP, $1234);
  CheckEqual(UInt16($1234), ReadUInt16LE(LP), 'LE16 roundtrip');
  WriteUInt16BE(LP, $1234);
  CheckEqual(UInt16($1234), ReadUInt16BE(LP), 'BE16 roundtrip');
  WriteUInt32LE(LP, $DEADBEEF);
  CheckEqual(UInt32($DEADBEEF), ReadUInt32LE(LP), 'LE32 roundtrip');
  WriteUInt32BE(LP, $DEADBEEF);
  CheckEqual(UInt32($DEADBEEF), ReadUInt32BE(LP), 'BE32 roundtrip');
  WriteUInt64LE(LP, $0102030405060708);
  CheckEqual(UInt64($0102030405060708), ReadUInt64LE(LP), 'LE64 roundtrip');
  WriteUInt64BE(LP, $0102030405060708);
  CheckEqual(UInt64($0102030405060708), ReadUInt64BE(LP), 'BE64 roundtrip');
end;

procedure TestReadByteOrder;
var
  LBuf: array[0..1] of Byte;
begin
  LBuf[0] := $12;
  LBuf[1] := $34;
  CheckEqual(UInt16($3412), ReadUInt16LE(@LBuf[0]), 'LE: low byte first');
  CheckEqual(UInt16($1234), ReadUInt16BE(@LBuf[0]), 'BE: high byte first');
end;

procedure TestTryReadAdvance;
var
  LD: TBytes;
  LS: TByteSpan;
  LV16: UInt16;
  LV32: UInt32;
begin
  LD := TBytes.Create($01, $02, $03, $04, $05, $06);
  LS := TByteSpan.FromBytes(LD);
  Check(TryReadUInt16LE(LS, LV16), 'read16 ok');
  CheckEqual(UInt16($0201), LV16, 'value');
  CheckEqual(SizeUInt(4), LS.Len, 'remaining');
  Check(TryReadUInt32LE(LS, LV32), 'read32 ok');
  CheckEqual(UInt32($06050403), LV32, 'value32');
  CheckEqual(SizeUInt(0), LS.Len, 'empty');
  Check(not TryReadUInt16LE(LS, LV16), 'read16 fail on empty');
end;

procedure TestTryWriteAdvance;
var
  LD: TBytes;
  LS: TByteSpan;
begin
  SetLength(LD, 4);
  LS := TByteSpan.FromBytes(LD);
  Check(TryWriteUInt16BE(LS, $ABCD), 'write16 ok');
  CheckEqual(Byte($AB), LD[0]);
  CheckEqual(Byte($CD), LD[1]);
  CheckEqual(SizeUInt(2), LS.Len, 'remaining');
  Check(not TryWriteUInt32LE(LS, $12345678), 'write32 fail insufficient');
  CheckEqual(SizeUInt(2), LS.Len, 'unchanged on fail');
end;

{ builder tests }

procedure TestBuilderBasic;
var
  LB: IBytesBuilder;
  LResult: TBytes;
begin
  LB := CreateBytesBuilder(16);
  LB.AppendByte($AA);
  LB.AppendByte($BB);
  CheckEqual(SizeUInt(2), LB.Length, 'len');
  LResult := LB.ToBytes;
  CheckEqual(2, System.Length(LResult), 'result len');
  CheckEqual(Byte($AA), LResult[0]);
  CheckEqual(Byte($BB), LResult[1]);
end;

procedure TestBuilderAppendBytes;
var
  LB: IBytesBuilder;
  LSrc: TBytes;
  LResult: TBytes;
begin
  LB := CreateBytesBuilder(4);
  LSrc := TBytes.Create(1, 2, 3, 4, 5);
  LB.AppendBytes(@LSrc[0], System.Length(LSrc));
  CheckEqual(SizeUInt(5), LB.Length);
  LResult := LB.ToBytes;
  Check(BytesEqual(LSrc, LResult), 'content match');
end;

procedure TestBuilderAppendSpan;
var
  LB: IBytesBuilder;
  LSrc: TBytes;
  LS: TByteSpan;
begin
  LB := CreateBytesBuilder(4);
  LSrc := TBytes.Create(10, 20, 30);
  LS := TByteSpan.FromBytes(LSrc);
  LB.AppendSpan(LS);
  CheckEqual(SizeUInt(3), LB.Length);
  CheckEqual(Byte(10), LB.Data[0]);
  CheckEqual(Byte(30), LB.Data[2]);
end;

procedure TestBuilderEndian;
var
  LB: IBytesBuilder;
  LResult: TBytes;
begin
  LB := CreateBytesBuilder(32);
  LB.AppendUInt16BE($1234);
  LB.AppendUInt32LE($DEADBEEF);
  LResult := LB.ToBytes;
  CheckEqual(Byte($12), LResult[0], 'BE16 high');
  CheckEqual(Byte($34), LResult[1], 'BE16 low');
  CheckEqual(Byte($EF), LResult[2], 'LE32 byte0');
  CheckEqual(Byte($BE), LResult[3], 'LE32 byte1');
  CheckEqual(Byte($AD), LResult[4], 'LE32 byte2');
  CheckEqual(Byte($DE), LResult[5], 'LE32 byte3');
end;

procedure TestBuilderGrow;
var
  LB: IBytesBuilder;
  LI: Integer;
begin
  LB := CreateBytesBuilder(4);
  for LI := 0 to 999 do
    LB.AppendByte(Byte(LI and $FF));
  CheckEqual(SizeUInt(1000), LB.Length, 'grew to 1000');
  Check(LB.Capacity >= 1000, 'capacity >= 1000');
  CheckEqual(Byte(0), LB.Data[0]);
  CheckEqual(Byte(255), LB.Data[255]);
end;

procedure TestBuilderClearReserve;
var
  LB: IBytesBuilder;
begin
  LB := CreateBytesBuilder(64);
  LB.AppendFill($CC, 50);
  CheckEqual(SizeUInt(50), LB.Length);
  LB.Clear;
  CheckEqual(SizeUInt(0), LB.Length, 'cleared');
  Check(LB.Capacity >= 64, 'cap preserved');
  LB.Reserve(1024);
  Check(LB.Capacity >= 1024, 'reserved');
end;

procedure TestBuilderTruncate;
var
  LB: IBytesBuilder;
begin
  LB := CreateBytesBuilder(32);
  LB.AppendFill($FF, 20);
  LB.Truncate(10);
  CheckEqual(SizeUInt(10), LB.Length, 'truncated');
  LB.Truncate(100);
  CheckEqual(SizeUInt(10), LB.Length, 'no-op if larger');
end;

procedure TestBuilderWrittenSpan;
var
  LB: IBytesBuilder;
  LS: TByteSpan;
begin
  LB := CreateBytesBuilder(16);
  LB.AppendByte(1);
  LB.AppendByte(2);
  LB.AppendByte(3);
  LS := LB.WrittenSpan;
  CheckEqual(SizeUInt(3), LS.Len);
  CheckEqual(Byte(1), LS.Data[0]);
  CheckEqual(Byte(3), LS.Data[2]);
end;

procedure TestBuilderAutoFree;
var
  LResult: TBytes;
begin
  LResult := CreateBytesBuilder(16).ToBytes;
  CheckEqual(0, System.Length(LResult), 'empty builder');
end;

{ Additional coverage: ops }

procedure TestSpanContains;
var
  LD: TBytes;
  LS: TByteSpan;
begin
  LD := TBytes.Create(1, 2, 3);
  LS := TByteSpan.FromBytes(LD);
  Check(SpanContains(LS, 2), 'contains 2');
  Check(not SpanContains(LS, 99), 'not contains 99');
  Check(not SpanContains(TByteSpan.Empty, 1), 'empty span');
end;

procedure TestSpanCopySlice;
var
  LD: TBytes;
  LS: TByteSpan;
  LResult: TBytes;
begin
  LD := TBytes.Create(10, 20, 30, 40, 50);
  LS := TByteSpan.FromBytes(LD);
  LResult := SpanCopySlice(LS, 1, 3);
  CheckEqual(3, System.Length(LResult), 'len');
  CheckEqual(Byte(20), LResult[0]);
  CheckEqual(Byte(40), LResult[2]);
end;

procedure TestSpanClone;
var
  LD: TBytes;
  LS: TByteSpan;
  LResult: TBytes;
begin
  LD := TBytes.Create(5, 6, 7);
  LS := TByteSpan.FromBytes(LD);
  LResult := SpanClone(LS);
  CheckEqual(3, System.Length(LResult));
  CheckEqual(Byte(5), LResult[0]);
  CheckEqual(Byte(7), LResult[2]);
  LResult := SpanClone(TByteSpan.Empty);
  CheckEqual(0, System.Length(LResult), 'empty clone');
end;

{ Additional coverage: binary }

procedure TestToFromEndian;
var
  LV16: UInt16;
  LV32: UInt32;
  LV64: UInt64;
begin
  LV16 := $1234;
  CheckEqual(LV16, ToEndian16(LV16, endLittle), 'LE no-op on LE host');
  CheckEqual(SwapUInt16(LV16), ToEndian16(LV16, endBig), 'BE swaps on LE host');
  CheckEqual(LV16, FromEndian16(ToEndian16(LV16, endBig), endBig), 'roundtrip 16');

  LV32 := $DEADBEEF;
  CheckEqual(LV32, ToEndian32(LV32, endLittle), 'LE32 no-op');
  CheckEqual(LV32, FromEndian32(ToEndian32(LV32, endBig), endBig), 'roundtrip 32');

  LV64 := $0102030405060708;
  CheckEqual(LV64, ToEndian64(LV64, endLittle), 'LE64 no-op');
  CheckEqual(LV64, FromEndian64(ToEndian64(LV64, endBig), endBig), 'roundtrip 64');
end;

procedure TestTryReadUInt8;
var
  LD: TBytes;
  LS: TByteSpan;
  LV: Byte;
begin
  LD := TBytes.Create($AB, $CD);
  LS := TByteSpan.FromBytes(LD);
  Check(TryReadUInt8(LS, LV), 'read ok');
  CheckEqual(Byte($AB), LV);
  CheckEqual(SizeUInt(1), LS.Len, 'advanced');
  Check(TryReadUInt8(LS, LV), 'read 2nd');
  CheckEqual(Byte($CD), LV);
  Check(not TryReadUInt8(LS, LV), 'empty fail');
end;

procedure TestTryWriteUInt8;
var
  LD: TBytes;
  LS: TByteSpan;
begin
  SetLength(LD, 2);
  LS := TByteSpan.FromBytes(LD);
  Check(TryWriteUInt8(LS, $AA), 'write ok');
  Check(TryWriteUInt8(LS, $BB), 'write 2nd');
  CheckEqual(Byte($AA), LD[0]);
  CheckEqual(Byte($BB), LD[1]);
  Check(not TryWriteUInt8(LS, $CC), 'full fail');
end;

procedure TestTryReadBE;
var
  LD: TBytes;
  LS: TByteSpan;
  LV16: UInt16;
  LV32: UInt32;
  LV64: UInt64;
begin
  LD := TBytes.Create($01, $02, $03, $04, $05, $06, $07, $08, $09, $0A);
  LS := TByteSpan.FromBytes(LD);
  Check(TryReadUInt16BE(LS, LV16), 'read16BE');
  CheckEqual(UInt16($0102), LV16);
  Check(TryReadUInt32BE(LS, LV32), 'read32BE');
  CheckEqual(UInt32($03040506), LV32);
  Check(not TryReadUInt64BE(LS, LV64), 'read64BE fail (only 4 left)');
  CheckEqual(SizeUInt(4), LS.Len, 'unchanged on fail');
end;

procedure TestTryWriteAllVariants;
var
  LD: TBytes;
  LS: TByteSpan;
begin
  SetLength(LD, 14);
  LS := TByteSpan.FromBytes(LD);
  Check(TryWriteUInt16LE(LS, $1234), 'w16LE');
  Check(TryWriteUInt32LE(LS, $AABBCCDD), 'w32LE');
  Check(TryWriteUInt64LE(LS, $0102030405060708), 'w64LE');
  CheckEqual(SizeUInt(0), LS.Len, 'all consumed');
  CheckEqual(Byte($34), LD[0], 'LE16 low');
  CheckEqual(Byte($12), LD[1], 'LE16 high');
  CheckEqual(Byte($DD), LD[2], 'LE32 byte0');
  CheckEqual(Byte($08), LD[6], 'LE64 byte0');
  CheckEqual(Byte($01), LD[13], 'LE64 byte7');
end;

{ Additional coverage: builder }

procedure TestBuilderUInt64;
var
  LB: IBytesBuilder;
  LResult: TBytes;
begin
  LB := CreateBytesBuilder(16);
  LB.AppendUInt64LE($0102030405060708);
  LB.AppendUInt64BE($0102030405060708);
  LResult := LB.ToBytes;
  CheckEqual(16, System.Length(LResult), 'len');
  CheckEqual(Byte($08), LResult[0], 'LE byte0');
  CheckEqual(Byte($01), LResult[7], 'LE byte7');
  CheckEqual(Byte($01), LResult[8], 'BE byte0');
  CheckEqual(Byte($08), LResult[15], 'BE byte7');
end;

procedure TestBuilderWithAllocator;
var
  LB: IBytesBuilder;
begin
  LB := CreateBytesBuilderWith(nextpas.core.mem.DefaultAllocator, 32);
  LB.AppendFill($EE, 100);
  CheckEqual(SizeUInt(100), LB.Length);
  CheckEqual(Byte($EE), LB.Data[99]);
end;

begin
  T := TTestRunner.Create('nextpas.core.bytes');

  T.Run('ops: Equal', @TestEqual);
  T.Run('ops: Compare', @TestCompare);
  T.Run('ops: IndexOf', @TestIndexOf);
  T.Run('ops: StartsWith/EndsWith', @TestStartsEndsWith);
  T.Run('ops: Concat', @TestConcat);
  T.Run('ops: Fill', @TestSpanFill);
  T.Run('ops: Reverse', @TestSpanReverse);
  T.Run('ops: IndexOfSpan', @TestSpanIndexOfSpan);

  T.Run('binary: Swap', @TestSwap);
  T.Run('binary: Swap roundtrip', @TestSwapRoundTrip);
  T.Run('binary: Read/Write', @TestReadWrite);
  T.Run('binary: Byte order', @TestReadByteOrder);
  T.Run('binary: TryRead advance', @TestTryReadAdvance);
  T.Run('binary: TryWrite advance', @TestTryWriteAdvance);

  T.Run('builder: Basic', @TestBuilderBasic);
  T.Run('builder: AppendBytes', @TestBuilderAppendBytes);
  T.Run('builder: AppendSpan', @TestBuilderAppendSpan);
  T.Run('builder: Endian', @TestBuilderEndian);
  T.Run('builder: Grow', @TestBuilderGrow);
  T.Run('builder: Clear/Reserve', @TestBuilderClearReserve);
  T.Run('builder: Truncate', @TestBuilderTruncate);
  T.Run('builder: WrittenSpan', @TestBuilderWrittenSpan);
  T.Run('builder: AutoFree', @TestBuilderAutoFree);
  T.Run('builder: UInt64', @TestBuilderUInt64);
  T.Run('builder: WithAllocator', @TestBuilderWithAllocator);

  T.Run('ops: SpanContains', @TestSpanContains);
  T.Run('ops: SpanCopySlice', @TestSpanCopySlice);
  T.Run('ops: SpanClone', @TestSpanClone);

  T.Run('binary: ToEndian/FromEndian', @TestToFromEndian);
  T.Run('binary: TryReadUInt8', @TestTryReadUInt8);
  T.Run('binary: TryWriteUInt8', @TestTryWriteUInt8);
  T.Run('binary: TryRead BE variants', @TestTryReadBE);
  T.Run('binary: TryWrite all variants', @TestTryWriteAllVariants);

  T.Summary;
end.