program test_bytes;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.base,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.binary,
  nextpas.core.bytes.builder;

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
  LB: TBytesBuilder;
  LResult: TBytes;
begin
  LB.InitDefault(16);
  try
    LB.AppendByte($AA);
    LB.AppendByte($BB);
    CheckEqual(SizeUInt(2), LB.Len, 'len');
    LResult := LB.ToBytes;
    CheckEqual(2, System.Length(LResult), 'result len');
    CheckEqual(Byte($AA), LResult[0]);
    CheckEqual(Byte($BB), LResult[1]);
  finally
    LB.Done;
  end;
end;

procedure TestBuilderAppendBytes;
var
  LB: TBytesBuilder;
  LSrc: TBytes;
  LResult: TBytes;
begin
  LB.InitDefault(4);
  try
    LSrc := TBytes.Create(1, 2, 3, 4, 5);
    LB.AppendBytes(@LSrc[0], System.Length(LSrc));
    CheckEqual(SizeUInt(5), LB.Len);
    LResult := LB.ToBytes;
    Check(BytesEqual(LSrc, LResult), 'content match');
  finally
    LB.Done;
  end;
end;

procedure TestBuilderAppendSpan;
var
  LB: TBytesBuilder;
  LSrc: TBytes;
  LS: TByteSpan;
begin
  LB.InitDefault(4);
  try
    LSrc := TBytes.Create(10, 20, 30);
    LS := TByteSpan.FromBytes(LSrc);
    LB.AppendSpan(LS);
    CheckEqual(SizeUInt(3), LB.Len);
    CheckEqual(Byte(10), LB.Data[0]);
    CheckEqual(Byte(30), LB.Data[2]);
  finally
    LB.Done;
  end;
end;

procedure TestBuilderEndian;
var
  LB: TBytesBuilder;
  LResult: TBytes;
begin
  LB.InitDefault(32);
  try
    LB.AppendUInt16BE($1234);
    LB.AppendUInt32LE($DEADBEEF);
    LResult := LB.ToBytes;
    CheckEqual(Byte($12), LResult[0], 'BE16 high');
    CheckEqual(Byte($34), LResult[1], 'BE16 low');
    CheckEqual(Byte($EF), LResult[2], 'LE32 byte0');
    CheckEqual(Byte($BE), LResult[3], 'LE32 byte1');
    CheckEqual(Byte($AD), LResult[4], 'LE32 byte2');
    CheckEqual(Byte($DE), LResult[5], 'LE32 byte3');
  finally
    LB.Done;
  end;
end;

procedure TestBuilderGrow;
var
  LB: TBytesBuilder;
  LI: Integer;
begin
  LB.InitDefault(4);
  try
    for LI := 0 to 999 do
      LB.AppendByte(Byte(LI and $FF));
    CheckEqual(SizeUInt(1000), LB.Len, 'grew to 1000');
    Check(LB.Cap >= 1000, 'capacity >= 1000');
    CheckEqual(Byte(0), LB.Data[0]);
    CheckEqual(Byte(255), LB.Data[255]);
  finally
    LB.Done;
  end;
end;

procedure TestBuilderClearReserve;
var
  LB: TBytesBuilder;
  LOldCap: SizeUInt;
begin
  LB.InitDefault(64);
  try
    LB.AppendFill($CC, 50);
    CheckEqual(SizeUInt(50), LB.Len);
    LB.Clear;
    CheckEqual(SizeUInt(0), LB.Len, 'cleared');
    Check(LB.Cap >= 64, 'cap preserved');
    LB.Reserve(1024);
    LOldCap := LB.Cap;
    Check(LOldCap >= 1024, 'reserved');
  finally
    LB.Done;
  end;
end;

procedure TestBuilderTruncate;
var
  LB: TBytesBuilder;
begin
  LB.InitDefault(32);
  try
    LB.AppendFill($FF, 20);
    LB.Truncate(10);
    CheckEqual(SizeUInt(10), LB.Len, 'truncated');
    LB.Truncate(100);
    CheckEqual(SizeUInt(10), LB.Len, 'no-op if larger');
  finally
    LB.Done;
  end;
end;

procedure TestBuilderWrittenSpan;
var
  LB: TBytesBuilder;
  LS: TByteSpan;
begin
  LB.InitDefault(16);
  try
    LB.AppendByte(1);
    LB.AppendByte(2);
    LB.AppendByte(3);
    LS := LB.WrittenSpan;
    CheckEqual(SizeUInt(3), LS.Len);
    CheckEqual(Byte(1), LS.Data[0]);
    CheckEqual(Byte(3), LS.Data[2]);
  finally
    LB.Done;
  end;
end;

procedure TestBuilderDoubleDone;
var
  LB: TBytesBuilder;
begin
  LB.InitDefault(16);
  LB.AppendByte(1);
  LB.Done;
  LB.Done;
  Check(not LB.IsInitialized, 'not initialized after done');
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
  T.Run('builder: Double Done', @TestBuilderDoubleDone);

  T.Summary;
end.