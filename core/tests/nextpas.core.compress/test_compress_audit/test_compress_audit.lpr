program test_compress_audit;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  zlib,
  nextpas.core.testing,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.io.util,
  nextpas.core.compress.base,
  nextpas.core.compress.intf,
  nextpas.core.compress,
  nextpas.core.compress.deflate;

var
  T: TTestRunner;

type
  TOneByteReader = class(TInterfacedObject, IReader)
  private
    FData: TBytes;
    FPosition: SizeUInt;
  public
    constructor Create(const AData: TBytes);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

constructor TOneByteReader.Create(const AData: TBytes);
begin
  inherited Create;
  FData := Copy(AData, 0, Length(AData));
  FPosition := 0;
end;

function TOneByteReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if (ACount = 0) or (FPosition >= SizeUInt(Length(FData))) then
    Exit(0);
  PByte(@ABuf)^ := FData[FPosition];
  Inc(FPosition);
  Result := 1;
end;

{ === A. Boundary Size Tests === }

procedure TestDeflate63Bytes;
var LSrc, LC, LD: TBytes;
begin
  SetLength(LSrc, 63);
  FillChar(LSrc[0], 63, $AB);
  LC := DeflateCompress(LSrc);
  LD := DeflateDecompress(LC);
  CheckEqual(Int64(63), Int64(Length(LD)), 'deflate 63 bytes');
  Check(LD[0] = $AB, 'content correct');
end;

procedure TestDeflate64Bytes;
var LSrc, LC, LD: TBytes;
begin
  SetLength(LSrc, 64);
  FillChar(LSrc[0], 64, $CD);
  LC := DeflateCompress(LSrc);
  LD := DeflateDecompress(LC);
  CheckEqual(Int64(64), Int64(Length(LD)), 'deflate 64 bytes');
end;

procedure TestDeflate65Bytes;
var LSrc, LC, LD: TBytes;
begin
  SetLength(LSrc, 65);
  FillChar(LSrc[0], 65, $EF);
  LC := DeflateCompress(LSrc);
  LD := DeflateDecompress(LC);
  CheckEqual(Int64(65), Int64(Length(LD)), 'deflate 65 bytes');
end;

procedure TestLz4_1to3Bytes;
var LSrc, LC, LD: TBytes;
    LI: Int32;
begin
  for LI := 1 to 3 do
  begin
    SetLength(LSrc, LI);
    FillChar(LSrc[0], LI, Byte(LI));
    LC := Lz4Compress(LSrc);
    Check(Length(LC) > 0, 'lz4 ' + IntToStr(LI) + ' bytes compresses');
    LD := Lz4Decompress(LC, LI);
    CheckEqual(Int64(LI), Int64(Length(LD)), 'lz4 ' + IntToStr(LI) + ' round-trip');
    Check(LD[0] = Byte(LI), 'lz4 ' + IntToStr(LI) + ' content');
  end;
end;

procedure TestLz4_4Bytes;
var LSrc, LC, LD: TBytes;
begin
  LSrc := TBytes.Create(1, 2, 3, 4);
  LC := Lz4Compress(LSrc);
  LD := Lz4Decompress(LC, 4);
  CheckEqual(Int64(4), Int64(Length(LD)), 'lz4 4 bytes');
  Check((LD[0]=1) and (LD[3]=4), 'lz4 4 content');
end;

procedure TestLz4RandomData;
var LSrc, LC, LD: TBytes;
    LI: Int32;
begin
  SetLength(LSrc, 4096);
  for LI := 0 to 4095 do
    LSrc[LI] := Byte(Random(256));
  LC := Lz4Compress(LSrc);
  Check(Length(LC) > 0, 'random compresses');
  Check(SizeUInt(Length(LC)) <= Lz4CompressBound(4096), 'within bound');
  LD := Lz4Decompress(LC, 4096);
  CheckEqual(Int64(4096), Int64(Length(LD)), 'random round-trip len');
  for LI := 0 to 4095 do
    if LSrc[LI] <> LD[LI] then
    begin
      Check(False, 'random mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'random data matches');
end;

{ === B. Security/Malformed Input Tests === }

procedure TestLz4MalformedOffsetBeforeStart;
var LC: TBytes;
    LGot: Boolean;
begin
  // Token: 0 literals, 4 match length, offset=1 but dst=0
  LC := TBytes.Create(
    $04,       // token: litLen=0, matchLen=0+4=4
    $01, $00   // offset=1 (but nothing written yet)
  );
  LGot := False;
  try
    Lz4Decompress(LC, 100);
  except
    LGot := True;
  end;
  Check(LGot, 'lz4 offset before start raises');
end;

procedure TestLz4MalformedZeroOffset;
var LC: TBytes;
    LGot: Boolean;
begin
  // 1 literal byte, then offset=0
  LC := TBytes.Create(
    $10,       // token: litLen=1, matchLen=0+4=4
    $AA,       // literal
    $00, $00   // offset=0 (invalid)
  );
  LGot := False;
  try
    Lz4Decompress(LC, 100);
  except
    LGot := True;
  end;
  Check(LGot, 'lz4 zero offset raises');
end;

procedure TestLz4MalformedLengthOverflow;
var LC: TBytes;
    LGot: Boolean;
begin
  // Token with litLen=15, then 255 255 255... (should hit overflow guard)
  LC := TBytes.Create(
    $F0,       // token: litLen=15, matchLen=0
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  // keep adding to litLen
  );
  LGot := False;
  try
    Lz4Decompress(LC, 100);
  except
    LGot := True;
  end;
  Check(LGot, 'lz4 length overflow raises');
end;

procedure TestLz4MalformedOriginalSizeMetadata;
var
  LC: TBytes;
  LGot: Boolean;
begin
  LGot := False;
  try
    Lz4Decompress(nil, 1);
  except
    LGot := True;
  end;
  Check(LGot, 'lz4 empty payload with nonzero original size raises');

  LGot := False;
  try
    Lz4Decompress(nil, -1);
  except
    LGot := True;
  end;
  Check(LGot, 'lz4 negative original size raises');

  LC := Lz4Compress(TBytes.Create(1, 2, 3, 4));
  LGot := False;
  try
    Lz4Decompress(LC, 0);
  except
    LGot := True;
  end;
  Check(LGot, 'lz4 non-empty payload with zero original size raises');
end;

procedure TestGzipWrongCRC;
var LSrc, LC: TBytes;
    LGot: Boolean;
begin
  LSrc := TBytes.Create(1, 2, 3, 4, 5, 6, 7, 8);
  LC := GzipCompress(LSrc);
  // Zero out CRC (bytes at len-8..len-5)
  LC[Length(LC)-8] := 0;
  LC[Length(LC)-7] := 0;
  LC[Length(LC)-6] := 0;
  LC[Length(LC)-5] := 0;
  LGot := False;
  try
    GzipDecompress(LC);
  except
    LGot := True;
  end;
  Check(LGot, 'gzip wrong CRC raises');
end;

procedure TestGzipWrongSize;
var LSrc, LC: TBytes;
    LGot: Boolean;
begin
  LSrc := TBytes.Create(1, 2, 3, 4, 5);
  LC := GzipCompress(LSrc);
  // Corrupt size field (last 4 bytes) to wrong value
  LC[Length(LC)-4] := 99;
  LGot := False;
  try
    GzipDecompress(LC);
  except
    LGot := True;
  end;
  Check(LGot, 'gzip wrong size raises');
end;

procedure TestGzipTruncatedHeader;
var LC: TBytes;
    LGot: Boolean;
begin
  LC := TBytes.Create($1F, $8B, $08); // only 3 bytes of header
  LGot := False;
  try
    GzipDecompress(LC);
  except
    LGot := True;
  end;
  Check(LGot, 'gzip truncated header raises');
end;

procedure TestGzipTruncatedTrailer;
var LSrc, LC: TBytes;
    LGot: Boolean;
begin
  LSrc := TBytes.Create(1, 2, 3);
  LC := GzipCompress(LSrc);
  // Remove last 4 bytes (partial trailer)
  SetLength(LC, Length(LC) - 4);
  LGot := False;
  try
    GzipDecompress(LC);
  except
    LGot := True;
  end;
  Check(LGot, 'gzip truncated trailer raises');
end;

procedure TestGzipRejectsBytesBeforeTrailer;
var
  LSrc, LC, LBad: TBytes;
  LReader: IDecompressReader;
  LGot: Boolean;
  LTrailerOfs: SizeUInt;
begin
  LSrc := TBytes.Create(1, 1, 2, 3, 5, 8, 13, 21);
  LC := GzipCompress(LSrc);
  LTrailerOfs := SizeUInt(Length(LC) - 8);

  SetLength(LBad, Length(LC) + 3);
  Move(LC[0], LBad[0], LTrailerOfs);
  LBad[LTrailerOfs] := $DE;
  LBad[LTrailerOfs + 1] := $AD;
  LBad[LTrailerOfs + 2] := $7A;
  Move(LC[LTrailerOfs], LBad[LTrailerOfs + 3], 8);

  LGot := False;
  try
    GzipDecompress(LBad);
  except
    LGot := True;
  end;
  Check(LGot, 'gzip one-shot rejects bytes before trailer');

  LGot := False;
  try
    LReader := GzipReader(CreateBytesStreamFrom(LBad) as IReader);
    IoReadAll(LReader as IReader);
    LReader.Close;
  except
    LGot := True;
  end;
  Check(LGot, 'gzip stream rejects bytes before trailer');
end;

procedure TestGzipRejectsTrailingBytesAfterTrailer;
var
  LSrc, LC, LBad: TBytes;
  LReader: IDecompressReader;
  LGot: Boolean;
begin
  LSrc := TBytes.Create(3, 1, 4, 1, 5, 9, 2, 6);
  LC := GzipCompress(LSrc);

  SetLength(LBad, Length(LC) + 3);
  Move(LC[0], LBad[0], Length(LC));
  LBad[Length(LC)] := $DE;
  LBad[Length(LC) + 1] := $AD;
  LBad[Length(LC) + 2] := $7A;

  LGot := False;
  try
    GzipDecompress(LBad);
  except
    LGot := True;
  end;
  Check(LGot, 'gzip one-shot rejects bytes after trailer');

  LGot := False;
  try
    LReader := GzipReader(CreateBytesStreamFrom(LBad) as IReader);
    IoReadAll(LReader as IReader);
    LReader.Close;
  except
    LGot := True;
  end;
  Check(LGot, 'gzip stream rejects bytes after trailer');

  LGot := False;
  try
    LReader := GzipReader(TOneByteReader.Create(LBad));
    IoReadAll(LReader as IReader);
    LReader.Close;
  except
    LGot := True;
  end;
  Check(LGot, 'gzip stream rejects bytes after trailer after chunk boundary');
end;

procedure TestGzipReservedFlagsRejected;
const
  RESERVED_FLAGS: array[0..2] of Byte = ($20, $40, $80);
var
  LSrc, LC: TBytes;
  LReader: IDecompressReader;
  LGot: Boolean;
  LI: Integer;
begin
  LSrc := TBytes.Create(1, 2, 3, 4);
  for LI := Low(RESERVED_FLAGS) to High(RESERVED_FLAGS) do
  begin
    LC := GzipCompress(LSrc);
    LC[3] := LC[3] or RESERVED_FLAGS[LI];

    LGot := False;
    try
      GzipDecompress(LC);
    except
      LGot := True;
    end;
    Check(LGot, 'gzip one-shot reserved flag $' + IntToHex(RESERVED_FLAGS[LI], 2) + ' raises');

    LGot := False;
    try
      LReader := GzipReader(CreateBytesStreamFrom(LC) as IReader);
      IoReadAll(LReader as IReader);
      LReader.Close;
    except
      LGot := True;
    end;
    Check(LGot, 'gzip stream reserved flag $' + IntToHex(RESERVED_FLAGS[LI], 2) + ' raises');
  end;
end;

procedure TestGzipHeaderCrcRejected;
var
  LSrc, LC, LD, LWithHeaderCrc, LWithNameAndHeaderCrc: TBytes;
  LReader: IDecompressReader;
  LHeaderCRC: UInt16;
  LGot: Boolean;
begin
  LSrc := TBytes.Create(1, 2, 3, 4);
  LC := GzipCompress(LSrc);

  SetLength(LWithHeaderCrc, Length(LC) + 2);
  Move(LC[0], LWithHeaderCrc[0], 10);
  LWithHeaderCrc[3] := LWithHeaderCrc[3] or $02;
  LHeaderCRC := UInt16(crc32(0, @LWithHeaderCrc[0], 10));
  LWithHeaderCrc[10] := Byte(LHeaderCRC);
  LWithHeaderCrc[11] := Byte(LHeaderCRC shr 8);
  Move(LC[10], LWithHeaderCrc[12], Length(LC) - 10);

  LD := GzipDecompress(LWithHeaderCrc);
  CheckEqual(Int64(Length(LSrc)), Int64(Length(LD)), 'gzip one-shot valid header CRC length');
  Check((LD[0] = LSrc[0]) and (LD[High(LD)] = LSrc[High(LSrc)]),
    'gzip one-shot valid header CRC content');

  LReader := GzipReader(CreateBytesStreamFrom(LWithHeaderCrc) as IReader);
  LD := IoReadAll(LReader as IReader);
  LReader.Close;
  CheckEqual(Int64(Length(LSrc)), Int64(Length(LD)), 'gzip stream valid header CRC length');
  Check((LD[0] = LSrc[0]) and (LD[High(LD)] = LSrc[High(LSrc)]),
    'gzip stream valid header CRC content');

  SetLength(LWithNameAndHeaderCrc, Length(LC) + 5);
  Move(LC[0], LWithNameAndHeaderCrc[0], 10);
  LWithNameAndHeaderCrc[3] := LWithNameAndHeaderCrc[3] or $0A;
  LWithNameAndHeaderCrc[10] := Ord('n');
  LWithNameAndHeaderCrc[11] := Ord('p');
  LWithNameAndHeaderCrc[12] := 0;
  LHeaderCRC := UInt16(crc32(0, @LWithNameAndHeaderCrc[0], 13));
  LWithNameAndHeaderCrc[13] := Byte(LHeaderCRC);
  LWithNameAndHeaderCrc[14] := Byte(LHeaderCRC shr 8);
  Move(LC[10], LWithNameAndHeaderCrc[15], Length(LC) - 10);

  LD := GzipDecompress(LWithNameAndHeaderCrc);
  CheckEqual(Int64(Length(LSrc)), Int64(Length(LD)), 'gzip one-shot FNAME header CRC length');

  LReader := GzipReader(CreateBytesStreamFrom(LWithNameAndHeaderCrc) as IReader);
  LD := IoReadAll(LReader as IReader);
  LReader.Close;
  CheckEqual(Int64(Length(LSrc)), Int64(Length(LD)), 'gzip stream FNAME header CRC length');

  LC := Copy(LWithHeaderCrc, 0, Length(LWithHeaderCrc));
  LC[10] := LC[10] xor $FF;

  LGot := False;
  try
    GzipDecompress(LC);
  except
    LGot := True;
  end;
  Check(LGot, 'gzip one-shot header CRC raises');

  LGot := False;
  try
    LReader := GzipReader(CreateBytesStreamFrom(LC) as IReader);
    IoReadAll(LReader as IReader);
    LReader.Close;
  except
    LGot := True;
  end;
  Check(LGot, 'gzip stream header CRC raises');
end;

procedure TestGzipTruncatedPayloadRaisesOnRead;
var
  LSrc, LC: TBytes;
  LReader: IDecompressReader;
  LGot: Boolean;
  LI: Integer;
begin
  SetLength(LSrc, 1024);
  for LI := 0 to High(LSrc) do
    LSrc[LI] := Byte((LI * 13 + 7) mod 251);
  LC := GzipCompress(LSrc);
  SetLength(LC, 16);

  LGot := False;
  try
    LReader := GzipReader(CreateBytesStreamFrom(LC) as IReader);
    IoReadAll(LReader as IReader);
  except
    LGot := True;
  end;
  Check(LGot, 'gzip truncated payload raises during read');
end;

{ === C. Streaming Boundary Tests === }

procedure TestDeflateStreamByteByByte;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LSrc, LOut: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 256);
  for LI := 0 to 255 do LSrc[LI] := Byte(LI);

  LBuf := CreateBytesStream;
  LWriter := DeflateWriter(LBuf as IWriter);
  // Write byte by byte
  for LI := 0 to 255 do
    LWriter.Write(LSrc[LI], 1);
  LWriter.Close;

  LBuf.Seek(0, soBeginning);
  LReader := DeflateReader(LBuf as IReader);
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;

  CheckEqual(Int64(256), Int64(Length(LOut)), 'byte-by-byte length');
  for LI := 0 to 255 do
    if LSrc[LI] <> LOut[LI] then
    begin
      Check(False, 'byte-by-byte mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'byte-by-byte matches');
end;

procedure TestGzipStreamByteByByte;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LSrc, LOut: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 128);
  for LI := 0 to 127 do LSrc[LI] := Byte(LI * 2);

  LBuf := CreateBytesStream;
  LWriter := GzipWriter(LBuf as IWriter);
  for LI := 0 to 127 do
    LWriter.Write(LSrc[LI], 1);
  LWriter.Close;

  LBuf.Seek(0, soBeginning);
  LReader := GzipReader(LBuf as IReader);
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;

  CheckEqual(Int64(128), Int64(Length(LOut)), 'gzip byte-by-byte length');
  Check(LOut[0] = 0, 'gzip byte-by-byte first');
  Check(LOut[127] = 254, 'gzip byte-by-byte last');
end;

procedure TestGzipStreamOneByteReaderLifecycle;
var
  LSrc, LCompressed, LOut: TBytes;
  LReader: IDecompressReader;
  LI: Integer;
begin
  SetLength(LSrc, 512);
  for LI := 0 to High(LSrc) do
    LSrc[LI] := Byte((LI * 17 + 3) mod 251);

  LCompressed := GzipCompress(LSrc);
  LReader := GzipReader(TOneByteReader.Create(LCompressed));
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;

  CheckEqual(Int64(Length(LSrc)), Int64(Length(LOut)), 'gzip one-byte reader length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LOut[LI] then
    begin
      Check(False, 'gzip one-byte reader mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'gzip one-byte reader round-trip');
end;

procedure TestDeflateEmptyStream;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LOut: TBytes;
begin
  LBuf := CreateBytesStream;
  LWriter := DeflateWriter(LBuf as IWriter);
  LWriter.Close; // close without writing

  LBuf.Seek(0, soBeginning);
  LReader := DeflateReader(LBuf as IReader);
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;

  CheckEqual(Int64(0), Int64(Length(LOut)), 'deflate empty stream');
end;

procedure TestDeflateTruncatedStreamRaises;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LSrc, LRaw: TBytes;
  LGot: Boolean;
  LI: Integer;
begin
  SetLength(LSrc, 512);
  for LI := 0 to High(LSrc) do
    LSrc[LI] := Byte((LI * 9 + 1) mod 253);

  LBuf := CreateBytesStream;
  LWriter := DeflateWriter(LBuf as IWriter);
  LWriter.Write(LSrc[0], Length(LSrc));
  LWriter.Close;

  LBuf.Seek(0, soBeginning);
  SetLength(LRaw, LBuf.Size);
  LBuf.Read(LRaw[0], Length(LRaw));
  SetLength(LRaw, Length(LRaw) - 1);

  LGot := False;
  try
    LBuf := CreateBytesStreamFrom(LRaw);
    LReader := DeflateReader(LBuf as IReader);
    IoReadAll(LReader as IReader);
    LReader.Close;
  except
    LGot := True;
  end;
  Check(LGot, 'deflate truncated stream raises');
end;

procedure TestDeflateDecompressOutputLimitRaises;
var
  LSrc, LC: TBytes;
  LGot: Boolean;
begin
  SetLength(LSrc, 512);
  FillChar(LSrc[0], Length(LSrc), $A5);
  LC := DeflateCompress(LSrc);

  LGot := False;
  try
    nextpas.core.compress.deflate.DeflateDecompressWithMaxOutputSize(LC, 64);
  except
    LGot := True;
  end;
  Check(LGot, 'deflate one-shot output limit raises');
end;

{ === D. Stress/Lifecycle Tests === }

procedure TestCompressDecompressCycle1000;
var
  LSrc, LC, LD: TBytes;
  LI: Int32;
begin
  SetLength(LSrc, 100);
  for LI := 0 to 99 do LSrc[LI] := Byte(LI);
  for LI := 1 to 1000 do
  begin
    LC := DeflateCompress(LSrc);
    LD := DeflateDecompress(LC);
    if Length(LD) <> 100 then
    begin
      Check(False, 'cycle ' + IntToStr(LI) + ' failed');
      Exit;
    end;
  end;
  Check(True, '1000 deflate cycles ok');
end;

procedure TestLz4Cycle1000;
var
  LSrc, LC, LD: TBytes;
  LI: Int32;
begin
  SetLength(LSrc, 64);
  for LI := 0 to 63 do LSrc[LI] := Byte(LI * 3);
  for LI := 1 to 1000 do
  begin
    LC := Lz4Compress(LSrc);
    LD := Lz4Decompress(LC, 64);
    if Length(LD) <> 64 then
    begin
      Check(False, 'lz4 cycle ' + IntToStr(LI) + ' failed');
      Exit;
    end;
  end;
  Check(True, '1000 lz4 cycles ok');
end;

{ === E. Interop Verification === }

procedure TestGzipNilRoundTrip;
var LC, LD: TBytes;
begin
  LC := GzipCompress(nil);
  Check(Length(LC) = 20, 'nil gzip = 20 bytes');
  LD := GzipDecompress(LC);
  CheckEqual(Int64(0), Int64(Length(LD)), 'nil gzip decompresses to empty');
end;

procedure TestDeflateAllLevels;
var
  LSrc, LC, LD: TBytes;
  LLevel: TCompressionLevel;
  LI: Int32;
begin
  SetLength(LSrc, 512);
  for LI := 0 to 511 do LSrc[LI] := Byte(LI mod 100);
  for LLevel := clNone to clBest do
  begin
    LC := DeflateCompress(LSrc, LLevel);
    LD := DeflateDecompress(LC);
    CheckEqual(Int64(512), Int64(Length(LD)), 'level ' + IntToStr(Ord(LLevel)));
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.compress.audit');
  T.Run('Deflate 63 bytes', @TestDeflate63Bytes);
  T.Run('Deflate 64 bytes', @TestDeflate64Bytes);
  T.Run('Deflate 65 bytes', @TestDeflate65Bytes);
  T.Run('LZ4 1-3 bytes', @TestLz4_1to3Bytes);
  T.Run('LZ4 4 bytes', @TestLz4_4Bytes);
  T.Run('LZ4 random data', @TestLz4RandomData);
  T.Run('LZ4 offset before start', @TestLz4MalformedOffsetBeforeStart);
  T.Run('LZ4 zero offset', @TestLz4MalformedZeroOffset);
  T.Run('LZ4 length overflow', @TestLz4MalformedLengthOverflow);
  T.Run('LZ4 malformed original size metadata', @TestLz4MalformedOriginalSizeMetadata);
  T.Run('Gzip wrong CRC', @TestGzipWrongCRC);
  T.Run('Gzip wrong size', @TestGzipWrongSize);
  T.Run('Gzip truncated header', @TestGzipTruncatedHeader);
  T.Run('Gzip truncated trailer', @TestGzipTruncatedTrailer);
  T.Run('Gzip rejects bytes before trailer', @TestGzipRejectsBytesBeforeTrailer);
  T.Run('Gzip rejects bytes after trailer', @TestGzipRejectsTrailingBytesAfterTrailer);
  T.Run('Gzip reserved flags', @TestGzipReservedFlagsRejected);
  T.Run('Gzip header CRC', @TestGzipHeaderCrcRejected);
  T.Run('Gzip truncated payload read', @TestGzipTruncatedPayloadRaisesOnRead);
  T.Run('Deflate stream byte-by-byte', @TestDeflateStreamByteByByte);
  T.Run('Gzip stream byte-by-byte', @TestGzipStreamByteByByte);
  T.Run('Gzip one-byte reader lifecycle', @TestGzipStreamOneByteReaderLifecycle);
  T.Run('Deflate empty stream', @TestDeflateEmptyStream);
  T.Run('Deflate truncated stream', @TestDeflateTruncatedStreamRaises);
  T.Run('Deflate one-shot output limit', @TestDeflateDecompressOutputLimitRaises);
  T.Run('Deflate 1000 cycles', @TestCompressDecompressCycle1000);
  T.Run('LZ4 1000 cycles', @TestLz4Cycle1000);
  T.Run('Gzip nil round-trip', @TestGzipNilRoundTrip);
  T.Run('Deflate all levels', @TestDeflateAllLevels);
  T.Summary;
end.
