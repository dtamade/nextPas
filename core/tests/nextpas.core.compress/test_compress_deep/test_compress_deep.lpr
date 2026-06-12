program test_compress_deep;
{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.io.util,
  nextpas.core.compress.base,
  nextpas.core.compress.intf,
  nextpas.core.compress;

var
  T: TTestRunner;

function SnapshotStreamPreservingPosition(const AStream: IStream): TBytes;
var
  LPosition: Int64;
  LRead: SizeUInt;
begin
  LPosition := AStream.Position;
  Result := nil;
  try
    AStream.Seek(0, soBeginning);
    SetLength(Result, AStream.Size);
    if Length(Result) > 0 then
    begin
      LRead := AStream.Read(Result[0], Length(Result));
      CheckEqual(Int64(Length(Result)), Int64(LRead),
        'stream snapshot length');
    end;
  finally
    AStream.Position := LPosition;
  end;
end;

{ === 1. Round-trip integrity with known data patterns === }

procedure TestGzipRoundTripSequential;
var LSrc, LC, LD: TBytes;
    LI: Integer;
begin
  SetLength(LSrc, 10000);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte(LI mod 256);
  LC := GzipCompress(LSrc);
  LD := GzipDecompress(LC);
  CheckEqual(Int64(10000), Int64(Length(LD)), 'gzip seq length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LD[LI] then
    begin
      Check(False, 'gzip seq mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'gzip sequential round-trip ok');
end;

procedure TestDeflateRoundTripAllZeros;
var LSrc, LC, LD: TBytes;
begin
  SetLength(LSrc, 8192);
  FillChar(LSrc[0], 8192, 0);
  LC := DeflateCompress(LSrc);
  Check(Length(LC) < 100, 'all-zeros compresses well');
  LD := DeflateDecompress(LC);
  CheckEqual(Int64(8192), Int64(Length(LD)), 'all-zeros length');
  Check(LD[0] = 0, 'first byte zero');
  Check(LD[8191] = 0, 'last byte zero');
end;

procedure TestLz4RoundTripRepetitive;
var LSrc, LC, LD: TBytes;
    LI: Integer;
begin
  SetLength(LSrc, 16384);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte(LI mod 4);
  LC := Lz4Compress(LSrc);
  Check(Length(LC) < Length(LSrc), 'repetitive compresses');
  LD := Lz4Decompress(LC, 16384);
  CheckEqual(Int64(16384), Int64(Length(LD)), 'lz4 repetitive length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LD[LI] then
    begin
      Check(False, 'lz4 repetitive mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'lz4 repetitive round-trip ok');
end;

{ === 2. Empty input handling === }

procedure TestGzipEmptyOneShot;
var LC, LD: TBytes;
begin
  LC := GzipCompress(nil);
  Check(Length(LC) > 0, 'gzip nil produces output');
  Check((LC[0] = $1F) and (LC[1] = $8B), 'gzip nil has magic');
  LD := GzipDecompress(LC);
  CheckEqual(Int64(0), Int64(Length(LD)), 'gzip nil decompresses to empty');
end;

procedure TestDeflateEmptyOneShot;
var
  LC, LD: TBytes;
  LGotException: Boolean;
begin
  LC := DeflateCompress(nil);
  Check(Length(LC) > 0, 'deflate nil produces zlib stream');
  LD := DeflateDecompress(LC);
  CheckEqual(Int64(0), Int64(Length(LD)), 'deflate nil decompresses to empty');

  LGotException := False;
  try
    LD := DeflateDecompress(nil);
  except
    LGotException := True;
  end;
  Check(LGotException, 'deflate empty encoded input raises');
end;

procedure TestLz4EmptyOneShot;
var LC: TBytes;
begin
  LC := Lz4Compress(nil);
  Check(LC = nil, 'lz4 nil = nil');
end;

{ === 3. Large input (100KB+) === }

procedure TestGzipLarge100KB;
var LSrc, LC, LD: TBytes;
    LI: Integer;
begin
  SetLength(LSrc, 102400);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte((LI * 7 + LI div 256) mod 251);
  LC := GzipCompress(LSrc);
  Check(Length(LC) > 0, 'gzip 100KB compressed');
  Check(Length(LC) < Length(LSrc), 'gzip 100KB smaller');
  LD := GzipDecompress(LC);
  CheckEqual(Int64(102400), Int64(Length(LD)), 'gzip 100KB length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LD[LI] then
    begin
      Check(False, 'gzip 100KB mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'gzip 100KB round-trip ok');
end;

procedure TestDeflateLarge100KB;
var LSrc, LC, LD: TBytes;
    LI: Integer;
begin
  SetLength(LSrc, 102400);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte((LI * 13 + LI div 100) mod 256);
  LC := DeflateCompress(LSrc);
  Check(Length(LC) > 0, 'deflate 100KB compressed');
  LD := DeflateDecompress(LC);
  CheckEqual(Int64(102400), Int64(Length(LD)), 'deflate 100KB length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LD[LI] then
    begin
      Check(False, 'deflate 100KB mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'deflate 100KB round-trip ok');
end;

procedure TestLz4Large100KB;
var LSrc, LC, LD: TBytes;
    LI: Integer;
begin
  SetLength(LSrc, 102400);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte((LI * 11 + LI div 50) mod 256);
  LC := Lz4Compress(LSrc);
  Check(Length(LC) > 0, 'lz4 100KB compressed');
  LD := Lz4Decompress(LC, 102400);
  CheckEqual(Int64(102400), Int64(Length(LD)), 'lz4 100KB length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LD[LI] then
    begin
      Check(False, 'lz4 100KB mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'lz4 100KB round-trip ok');
end;

{ === 4. Double compress (already compressed data) === }

procedure TestGzipDoubleCompress;
var LSrc, LC1, LC2, LD2, LD1: TBytes;
    LI: Integer;
begin
  SetLength(LSrc, 1024);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte(LI mod 200);
  LC1 := GzipCompress(LSrc);
  LC2 := GzipCompress(LC1);
  Check(Length(LC2) > 0, 'double gzip produces output');
  LD2 := GzipDecompress(LC2);
  CheckEqual(Int64(Length(LC1)), Int64(Length(LD2)), 'outer decompress length');
  LD1 := GzipDecompress(LD2);
  CheckEqual(Int64(1024), Int64(Length(LD1)), 'inner decompress length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LD1[LI] then
    begin
      Check(False, 'double gzip mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'double gzip round-trip ok');
end;

procedure TestLz4DoubleCompress;
var LSrc, LC1, LC2, LD2, LD1: TBytes;
    LI: Integer;
begin
  SetLength(LSrc, 512);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte(LI mod 128);
  LC1 := Lz4Compress(LSrc);
  LC2 := Lz4Compress(LC1);
  Check(Length(LC2) > 0, 'double lz4 produces output');
  LD2 := Lz4Decompress(LC2, Length(LC1));
  CheckEqual(Int64(Length(LC1)), Int64(Length(LD2)), 'outer lz4 decompress');
  LD1 := Lz4Decompress(LD2, 512);
  CheckEqual(Int64(512), Int64(Length(LD1)), 'inner lz4 decompress');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LD1[LI] then
    begin
      Check(False, 'double lz4 mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'double lz4 round-trip ok');
end;

{ === 5. Corrupt/truncated data (should error, not crash) === }

procedure TestGzipInvalidMagic;
var LGot: Boolean;
begin
  LGot := False;
  try
    GzipDecompress(TBytes.Create($00, $00, $08, $00, $00, $00, $00, $00, $00, $FF,
      $03, $00, $00, $00, $00, $00, $00, $00, $00, $00));
  except
    LGot := True;
  end;
  Check(LGot, 'gzip invalid magic raises');
end;

procedure TestGzipUnsupportedMethod;
var LGot: Boolean;
begin
  LGot := False;
  try
    GzipDecompress(TBytes.Create($1F, $8B, $09, $00, $00, $00, $00, $00, $00, $FF,
      $03, $00, $00, $00, $00, $00, $00, $00, $00, $00));
  except
    LGot := True;
  end;
  Check(LGot, 'gzip unsupported method raises');
end;

procedure TestDeflateCorruptPayload;
var LGot: Boolean;
begin
  LGot := False;
  try
    DeflateDecompress(TBytes.Create($FF, $FE, $FD, $FC, $FB, $FA));
  except
    LGot := True;
  end;
  Check(LGot, 'deflate corrupt payload raises');
end;

procedure TestLz4TruncatedOffset;
var LGot: Boolean;
begin
  // Token with 1 literal, then only 1 byte for offset (needs 2)
  LGot := False;
  try
    Lz4Decompress(TBytes.Create($14, $AA, $01), 100);
  except
    LGot := True;
  end;
  Check(LGot, 'lz4 truncated offset raises');
end;

procedure TestLz4OutputOverflow;
var LGot: Boolean;
begin
  // Craft data that would write more than AOriginalSize
  // Token: litLen=15, then 255 (=15+255=270 literals), but originalSize=10
  LGot := False;
  try
    Lz4Decompress(TBytes.Create($F0, $FF, $AA, $AA, $AA, $AA, $AA), 10);
  except
    LGot := True;
  end;
  Check(LGot, 'lz4 output overflow raises');
end;

procedure TestGzipCorruptedDeflatePayload;
var LC: TBytes;
    LGot: Boolean;
begin
  // Valid gzip header but garbage deflate payload
  LC := GzipCompress(TBytes.Create(1, 2, 3, 4, 5));
  // Corrupt the deflate payload (bytes 10..end-8)
  if Length(LC) > 18 then
  begin
    LC[10] := $FF;
    LC[11] := $FF;
    LC[12] := $FF;
  end;
  LGot := False;
  try
    GzipDecompress(LC);
  except
    LGot := True;
  end;
  Check(LGot, 'gzip corrupt deflate payload raises');
end;

{ === 6. Compression levels === }

procedure TestGzipAllLevels;
var
  LSrc, LC, LD: TBytes;
  LLevel: TCompressionLevel;
  LI: Integer;
  LPrevSize: Integer;
begin
  SetLength(LSrc, 4096);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte(LI mod 100);
  LPrevSize := 0;
  for LLevel := clNone to clBest do
  begin
    LC := GzipCompress(LSrc, LLevel);
    Check(Length(LC) > 0, 'gzip level ' + IntToStr(Ord(LLevel)) + ' produces output');
    LD := GzipDecompress(LC);
    CheckEqual(Int64(4096), Int64(Length(LD)), 'gzip level ' + IntToStr(Ord(LLevel)) + ' length');
    // clNone should be largest
    if LLevel = clNone then
      LPrevSize := Length(LC);
    if LLevel = clBest then
      Check(Length(LC) <= LPrevSize, 'clBest <= clNone size');
  end;
end;

procedure TestDeflateAllLevelsRoundTrip;
var
  LSrc, LC, LD: TBytes;
  LLevel: TCompressionLevel;
  LI: Integer;
begin
  SetLength(LSrc, 2048);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte((LI * 3) mod 200);
  for LLevel := clNone to clBest do
  begin
    LC := DeflateCompress(LSrc, LLevel);
    LD := DeflateDecompress(LC);
    CheckEqual(Int64(2048), Int64(Length(LD)), 'deflate level ' + IntToStr(Ord(LLevel)));
    for LI := 0 to High(LSrc) do
      if LSrc[LI] <> LD[LI] then
      begin
        Check(False, 'deflate level ' + IntToStr(Ord(LLevel)) + ' mismatch');
        Exit;
      end;
  end;
  Check(True, 'deflate all levels round-trip ok');
end;

{ === 7. Streaming compress/decompress === }

procedure TestGzipStreamingLargeChunks;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LSrc, LOut: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 65536);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte((LI * 5 + 17) mod 256);

  LBuf := CreateBytesStream;
  LWriter := GzipWriter(LBuf as IWriter);
  // Write in 4 chunks of 16KB
  LWriter.Write(LSrc[0], 16384);
  LWriter.Write(LSrc[16384], 16384);
  LWriter.Write(LSrc[32768], 16384);
  LWriter.Write(LSrc[49152], 16384);
  LWriter.Close;

  LBuf.Seek(0, soBeginning);
  LReader := GzipReader(LBuf as IReader);
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;

  CheckEqual(Int64(65536), Int64(Length(LOut)), 'gzip streaming 64KB length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LOut[LI] then
    begin
      Check(False, 'gzip streaming 64KB mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'gzip streaming 64KB ok');
end;

procedure TestDeflateStreamingLargeChunks;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LSrc, LOut: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 98304);
  for LI := 0 to High(LSrc) do
    LSrc[LI] := Byte((LI * 11 + LI div 97) mod 251);

  LBuf := CreateBytesStream;
  LWriter := DeflateWriter(LBuf as IWriter, clNone);
  LWriter.Write(LSrc[0], 32768);
  LWriter.Write(LSrc[32768], 12345);
  LWriter.Write(LSrc[45113], 20000);
  LWriter.Write(LSrc[65113], Length(LSrc) - 65113);
  LWriter.Close;

  LBuf.Seek(0, soBeginning);
  LReader := DeflateReader(LBuf as IReader);
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;

  CheckEqual(Int64(Length(LSrc)), Int64(Length(LOut)),
    'deflate streaming 96KB length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LOut[LI] then
    begin
      Check(False, 'deflate streaming 96KB mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'deflate streaming 96KB ok');
end;

procedure TestDeflateStreamingFlushBetweenWrites;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LSrc, LOut: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 1024);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte(LI mod 256);

  LBuf := CreateBytesStream;
  LWriter := DeflateWriter(LBuf as IWriter);
  LWriter.Write(LSrc[0], 256);
  LWriter.Flush;
  LWriter.Write(LSrc[256], 256);
  LWriter.Flush;
  LWriter.Write(LSrc[512], 512);
  LWriter.Close;

  LBuf.Seek(0, soBeginning);
  LReader := DeflateReader(LBuf as IReader);
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;

  CheckEqual(Int64(1024), Int64(Length(LOut)), 'deflate flush-between length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LOut[LI] then
    begin
      Check(False, 'deflate flush-between mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'deflate flush-between ok');
end;

procedure TestDeflateStreamingFlushPublishesReadablePrefix;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LSrc, LPrefix, LOut, LFinal: TBytes;
  LRead: SizeUInt;
  LI: Integer;
begin
  SetLength(LSrc, 1024);
  for LI := 0 to High(LSrc) do
    LSrc[LI] := Byte((LI * 17 + 5) mod 251);

  LBuf := CreateBytesStream;
  LWriter := DeflateWriter(LBuf as IWriter);
  LWriter.Write(LSrc[0], 128);
  LWriter.Flush;

  LPrefix := SnapshotStreamPreservingPosition(LBuf);
  Check(Length(LPrefix) > 0, 'deflate flush emits compressed prefix');

  LReader := DeflateReader(CreateBytesStreamFrom(LPrefix) as IReader);
  SetLength(LOut, 128);
  LRead := LReader.Read(LOut[0], Length(LOut));
  CheckEqual(Int64(128), Int64(LRead), 'deflate flush prefix read length');
  LReader.Close;

  for LI := 0 to High(LOut) do
    if LOut[LI] <> LSrc[LI] then
    begin
      Check(False, 'deflate flush prefix mismatch at ' + IntToStr(LI));
      Exit;
    end;

  LWriter.Write(LSrc[128], Length(LSrc) - 128);
  LWriter.Close;

  LBuf.Seek(0, soBeginning);
  LReader := DeflateReader(LBuf as IReader);
  LFinal := IoReadAll(LReader as IReader);
  LReader.Close;

  CheckEqual(Int64(Length(LSrc)), Int64(Length(LFinal)),
    'deflate flush final length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LFinal[LI] then
    begin
      Check(False, 'deflate flush final mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'deflate flush publishes readable prefix');
end;

procedure TestGzipStreamingFlushPublishesReadablePrefix;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LSrc, LPrefix, LOut, LFinal: TBytes;
  LRead: SizeUInt;
  LI: Integer;
begin
  SetLength(LSrc, 1024);
  for LI := 0 to High(LSrc) do
    LSrc[LI] := Byte((LI * 19 + 7) mod 251);

  LBuf := CreateBytesStream;
  LWriter := GzipWriter(LBuf as IWriter);
  LWriter.Write(LSrc[0], 128);
  LWriter.Flush;

  LPrefix := SnapshotStreamPreservingPosition(LBuf);
  Check(Length(LPrefix) > 10, 'gzip flush emits compressed prefix');

  LReader := GzipReader(CreateBytesStreamFrom(LPrefix) as IReader);
  SetLength(LOut, 128);
  LRead := LReader.Read(LOut[0], Length(LOut));
  CheckEqual(Int64(128), Int64(LRead), 'gzip flush prefix read length');
  LReader.Close;

  for LI := 0 to High(LOut) do
    if LOut[LI] <> LSrc[LI] then
    begin
      Check(False, 'gzip flush prefix mismatch at ' + IntToStr(LI));
      Exit;
    end;

  LWriter.Write(LSrc[128], Length(LSrc) - 128);
  LWriter.Close;

  LBuf.Seek(0, soBeginning);
  LReader := GzipReader(LBuf as IReader);
  LFinal := IoReadAll(LReader as IReader);
  LReader.Close;

  CheckEqual(Int64(Length(LSrc)), Int64(Length(LFinal)),
    'gzip flush final length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LFinal[LI] then
    begin
      Check(False, 'gzip flush final mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'gzip flush publishes readable prefix');
end;

procedure TestGzipStreamingCrossAPIOneshot;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LSrc, LCompressed, LOut: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 4096);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte((LI * 11) mod 256);

  // Stream compress -> one-shot decompress
  LBuf := CreateBytesStream;
  LWriter := GzipWriter(LBuf as IWriter);
  LWriter.Write(LSrc[0], Length(LSrc));
  LWriter.Close;

  LBuf.Seek(0, soBeginning);
  SetLength(LCompressed, LBuf.Size);
  (LBuf as IReader).Read(LCompressed[0], Length(LCompressed));

  LOut := GzipDecompress(LCompressed);
  CheckEqual(Int64(4096), Int64(Length(LOut)), 'cross-API stream->oneshot length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LOut[LI] then
    begin
      Check(False, 'cross-API mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'cross-API stream->oneshot ok');
end;

{ === 8. Memory leak verification (many cycles) === }

procedure TestGzipCycle5000;
var
  LSrc, LC, LD: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 256);
  for LI := 0 to 255 do LSrc[LI] := Byte(LI);
  for LI := 1 to 5000 do
  begin
    LC := GzipCompress(LSrc);
    LD := GzipDecompress(LC);
    if Length(LD) <> 256 then
    begin
      Check(False, 'gzip cycle ' + IntToStr(LI) + ' failed');
      Exit;
    end;
  end;
  Check(True, '5000 gzip cycles ok (no leak)');
end;

procedure TestLz4Cycle5000;
var
  LSrc, LC, LD: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 256);
  for LI := 0 to 255 do LSrc[LI] := Byte(LI);
  for LI := 1 to 5000 do
  begin
    LC := Lz4Compress(LSrc);
    LD := Lz4Decompress(LC, 256);
    if Length(LD) <> 256 then
    begin
      Check(False, 'lz4 cycle ' + IntToStr(LI) + ' failed');
      Exit;
    end;
  end;
  Check(True, '5000 lz4 cycles ok (no leak)');
end;

procedure TestStreamingCycle1000;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LSrc, LOut: TBytes;
  LI, LJ: Integer;
begin
  SetLength(LSrc, 128);
  for LJ := 0 to 127 do LSrc[LJ] := Byte(LJ);
  for LI := 1 to 1000 do
  begin
    LBuf := CreateBytesStream;
    LWriter := GzipWriter(LBuf as IWriter);
    LWriter.Write(LSrc[0], 128);
    LWriter.Close;
    LBuf.Seek(0, soBeginning);
    LReader := GzipReader(LBuf as IReader);
    LOut := IoReadAll(LReader as IReader);
    LReader.Close;
    if Length(LOut) <> 128 then
    begin
      Check(False, 'streaming cycle ' + IntToStr(LI) + ' failed');
      Exit;
    end;
  end;
  Check(True, '1000 streaming gzip cycles ok (no leak)');
end;

{ === 9. Edge cases === }

procedure TestLz4ExactBoundary;
var LSrc, LC, LD: TBytes;
    LBound: SizeUInt;
begin
  // Data that won't compress at all (pseudo-random)
  SetLength(LSrc, 1000);
  RandSeed := 42;
  FillChar(LSrc[0], 1000, 0);
  // Use deterministic pattern
  LSrc[0] := 137; LSrc[1] := 80; LSrc[2] := 78;
  LBound := Lz4CompressBound(1000);
  LC := Lz4Compress(LSrc);
  Check(SizeUInt(Length(LC)) <= LBound, 'lz4 within bound');
  LD := Lz4Decompress(LC, 1000);
  CheckEqual(Int64(1000), Int64(Length(LD)), 'lz4 boundary length');
end;

procedure TestGzipSingleBytePayload;
var LC, LD: TBytes;
begin
  LC := GzipCompress(TBytes.Create($42));
  Check(Length(LC) >= 18, 'gzip single byte min size');
  LD := GzipDecompress(LC);
  CheckEqual(Int64(1), Int64(Length(LD)), 'gzip single byte length');
  Check(LD[0] = $42, 'gzip single byte value');
end;

procedure TestDeflateMaxExpansion;
var LSrc, LC, LD: TBytes;
    LI: Integer;
begin
  // Incompressible data - deflate may expand it slightly
  SetLength(LSrc, 1000);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte((LI * 131 + 17) mod 256);
  LC := DeflateCompress(LSrc);
  Check(Length(LC) > 0, 'incompressible deflate produces output');
  LD := DeflateDecompress(LC);
  CheckEqual(Int64(1000), Int64(Length(LD)), 'incompressible deflate round-trip');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LD[LI] then
    begin
      Check(False, 'incompressible deflate mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'incompressible deflate ok');
end;

procedure TestLz4AllSameBytes;
var LSrc, LC, LD: TBytes;
    LI: Integer;
begin
  // Highly compressible: all same byte
  SetLength(LSrc, 65536);
  FillChar(LSrc[0], 65536, $AA);
  LC := Lz4Compress(LSrc);
  Check(Length(LC) < 1000, 'all-same compresses very well');
  LD := Lz4Decompress(LC, 65536);
  CheckEqual(Int64(65536), Int64(Length(LD)), 'all-same length');
  for LI := 0 to High(LD) do
    if LD[LI] <> $AA then
    begin
      Check(False, 'all-same mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'lz4 all-same ok');
end;

procedure TestGzipLargeExpansion;
var LSrc, LC, LD: TBytes;
    LI: Integer;
begin
  // 10 bytes compressed, decompresses to much larger
  SetLength(LSrc, 50000);
  FillChar(LSrc[0], 50000, $BB);
  LC := GzipCompress(LSrc);
  Check(Length(LC) < 200, 'highly compressible gzip');
  LD := GzipDecompress(LC);
  CheckEqual(Int64(50000), Int64(Length(LD)), 'large expansion length');
  for LI := 0 to High(LD) do
    if LD[LI] <> $BB then
    begin
      Check(False, 'large expansion mismatch');
      Exit;
    end;
  Check(True, 'gzip large expansion ok');
end;

{ === 10. Deflate streaming one-shot interop note === }
{ Note: one-shot and streaming Deflate paths both use zlib-wrapped streams.
  This test verifies each path works independently. }

procedure TestDeflateOneShotVsStreamIndependent;
var
  LSrc, LCOneShot, LDOneShot: TBytes;
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LDStream: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 2048);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte((LI * 7) mod 256);

  // One-shot path
  LCOneShot := DeflateCompress(LSrc);
  LDOneShot := DeflateDecompress(LCOneShot);
  CheckEqual(Int64(2048), Int64(Length(LDOneShot)), 'oneshot deflate length');

  // Streaming path
  LBuf := CreateBytesStream;
  LWriter := DeflateWriter(LBuf as IWriter);
  LWriter.Write(LSrc[0], Length(LSrc));
  LWriter.Close;
  LBuf.Seek(0, soBeginning);
  LReader := DeflateReader(LBuf as IReader);
  LDStream := IoReadAll(LReader as IReader);
  LReader.Close;
  CheckEqual(Int64(2048), Int64(Length(LDStream)), 'stream deflate length');

  // Both should produce same decompressed output
  for LI := 0 to High(LSrc) do
  begin
    if LSrc[LI] <> LDOneShot[LI] then
    begin
      Check(False, 'oneshot path mismatch at ' + IntToStr(LI));
      Exit;
    end;
    if LSrc[LI] <> LDStream[LI] then
    begin
      Check(False, 'stream path mismatch at ' + IntToStr(LI));
      Exit;
    end;
  end;
  Check(True, 'deflate oneshot vs stream both correct');
end;

{ === Main === }

begin
  T := TTestRunner.Create('nextpas.core.compress.deep');
  { Round-trip integrity }
  T.Run('Gzip round-trip sequential', @TestGzipRoundTripSequential);
  T.Run('Deflate round-trip all-zeros', @TestDeflateRoundTripAllZeros);
  T.Run('LZ4 round-trip repetitive', @TestLz4RoundTripRepetitive);
  { Empty input }
  T.Run('Gzip empty one-shot', @TestGzipEmptyOneShot);
  T.Run('Deflate empty one-shot', @TestDeflateEmptyOneShot);
  T.Run('LZ4 empty one-shot', @TestLz4EmptyOneShot);
  { Large input }
  T.Run('Gzip 100KB', @TestGzipLarge100KB);
  T.Run('Deflate 100KB', @TestDeflateLarge100KB);
  T.Run('LZ4 100KB', @TestLz4Large100KB);
  { Double compress }
  T.Run('Gzip double compress', @TestGzipDoubleCompress);
  T.Run('LZ4 double compress', @TestLz4DoubleCompress);
  { Corrupt/truncated }
  T.Run('Gzip invalid magic', @TestGzipInvalidMagic);
  T.Run('Gzip unsupported method', @TestGzipUnsupportedMethod);
  T.Run('Deflate corrupt payload', @TestDeflateCorruptPayload);
  T.Run('LZ4 truncated offset', @TestLz4TruncatedOffset);
  T.Run('LZ4 output overflow', @TestLz4OutputOverflow);
  T.Run('Gzip corrupt deflate payload', @TestGzipCorruptedDeflatePayload);
  { Compression levels }
  T.Run('Gzip all levels', @TestGzipAllLevels);
  T.Run('Deflate all levels round-trip', @TestDeflateAllLevelsRoundTrip);
  { Streaming }
  T.Run('Gzip streaming 64KB chunks', @TestGzipStreamingLargeChunks);
  T.Run('Deflate streaming 96KB chunks', @TestDeflateStreamingLargeChunks);
  T.Run('Deflate streaming flush-between', @TestDeflateStreamingFlushBetweenWrites);
  T.Run('Deflate streaming flush publishes readable prefix',
    @TestDeflateStreamingFlushPublishesReadablePrefix);
  T.Run('Gzip streaming flush publishes readable prefix',
    @TestGzipStreamingFlushPublishesReadablePrefix);
  T.Run('Gzip cross-API stream->oneshot', @TestGzipStreamingCrossAPIOneshot);
  { Memory leak cycles }
  T.Run('Gzip 5000 cycles', @TestGzipCycle5000);
  T.Run('LZ4 5000 cycles', @TestLz4Cycle5000);
  T.Run('Streaming 1000 cycles', @TestStreamingCycle1000);
  { Edge cases }
  T.Run('LZ4 exact boundary', @TestLz4ExactBoundary);
  T.Run('Gzip single byte', @TestGzipSingleBytePayload);
  T.Run('Deflate max expansion', @TestDeflateMaxExpansion);
  T.Run('LZ4 all same bytes', @TestLz4AllSameBytes);
  T.Run('Gzip large expansion', @TestGzipLargeExpansion);
  T.Run('Deflate oneshot vs stream', @TestDeflateOneShotVsStreamIndependent);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
