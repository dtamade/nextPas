program test_compress_audit;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
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
