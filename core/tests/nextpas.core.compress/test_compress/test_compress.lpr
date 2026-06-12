program test_compress;
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
  nextpas.core.compress;

var
  T: TTestRunner;

procedure TestDeflateRoundTrip;
var
  LSrc, LCompressed, LDecompressed: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 1000);
  for LI := 0 to 999 do LSrc[LI] := Byte(LI mod 256);
  LCompressed := DeflateCompress(LSrc);
  Check(Length(LCompressed) > 0, 'compressed not empty');
  Check(Length(LCompressed) < Length(LSrc), 'compressed smaller');
  LDecompressed := DeflateDecompress(LCompressed);
  CheckEqual(Int64(Length(LSrc)), Int64(Length(LDecompressed)), 'same length');
  for LI := 0 to 999 do
    if LSrc[LI] <> LDecompressed[LI] then
    begin
      Check(False, 'data mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'data matches');
end;

procedure TestDeflateLevels;
var
  LSrc, LC: TBytes;
begin
  SetLength(LSrc, 500);
  FillChar(LSrc[0], 500, $AA);
  LC := DeflateCompress(LSrc, clNone);
  Check(Length(LC) > 0, 'clNone');
  LC := DeflateCompress(LSrc, clFastest);
  Check(Length(LC) > 0, 'clFastest');
  LC := DeflateCompress(LSrc, clBest);
  Check(Length(LC) > 0, 'clBest');
end;

procedure TestDeflateEmpty;
var
  LR: TBytes;
  LGotException: Boolean;
begin
  LR := DeflateCompress(nil);
  Check(Length(LR) > 0, 'empty compress produces zlib stream');
  LR := DeflateDecompress(LR);
  CheckEqual(Int64(0), Int64(Length(LR)), 'empty stream decompresses to empty');

  LGotException := False;
  try
    LR := DeflateDecompress(nil);
  except
    LGotException := True;
  end;
  Check(LGotException, 'empty encoded deflate input raises');
end;

procedure TestDeflateLarge;
var
  LSrc, LC, LD: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 1000000);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte(LI mod 251);
  LC := DeflateCompress(LSrc);
  Check(Length(LC) > 0, '1MB compressed');
  LD := DeflateDecompress(LC);
  CheckEqual(Int64(1000000), Int64(Length(LD)), '1MB decompressed');
  Check(LD[0] = 0, 'first byte');
  Check(LD[999999] = Byte(999999 mod 251), 'last byte');
end;

{ Gzip tests }

procedure TestGzipRoundTrip;
var
  LSrc, LC, LD: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 500);
  for LI := 0 to 499 do LSrc[LI] := Byte(LI mod 256);
  LC := GzipCompress(LSrc);
  Check(Length(LC) > 0, 'gzip compressed');
  Check((LC[0] = $1F) and (LC[1] = $8B), 'gzip magic');
  LD := GzipDecompress(LC);
  CheckEqual(Int64(500), Int64(Length(LD)), 'gzip decompressed length');
  for LI := 0 to 499 do
    if LSrc[LI] <> LD[LI] then
    begin
      Check(False, 'gzip data mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'gzip data matches');
end;

procedure TestGzipInterop;
var
  LC: TBytes;
begin
  LC := GzipCompress(TBytes.Create(72,101,108,108,111));
  Check((LC[0] = $1F) and (LC[1] = $8B) and (LC[2] = $08), 'valid gzip header');
  Check(Length(LC) >= 18, 'minimum gzip size');
end;

{ LZ4 tests }

procedure TestLz4RoundTrip;
var
  LSrc, LC, LD: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 1000);
  for LI := 0 to 999 do LSrc[LI] := Byte(LI mod 128);
  LC := Lz4Compress(LSrc);
  Check(Length(LC) > 0, 'lz4 compressed');
  LD := Lz4Decompress(LC, 1000);
  CheckEqual(Int64(1000), Int64(Length(LD)), 'lz4 decompressed length');
  for LI := 0 to 999 do
    if LSrc[LI] <> LD[LI] then
    begin
      Check(False, 'lz4 data mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'lz4 data matches');
end;

procedure TestLz4Empty;
var
  LC: TBytes;
begin
  LC := Lz4Compress(nil);
  CheckEqual(Int64(0), Int64(Length(LC)), 'lz4 empty');
end;

procedure TestLz4Large;
var
  LSrc, LC, LD: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 1000000);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte(LI mod 251);
  LC := Lz4Compress(LSrc);
  Check(Length(LC) > 0, 'lz4 1MB compressed');
  Check(Length(LC) < Length(LSrc), 'lz4 1MB smaller');
  LD := Lz4Decompress(LC, 1000000);
  CheckEqual(Int64(1000000), Int64(Length(LD)), 'lz4 1MB decompressed length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LD[LI] then
    begin
      Check(False, 'lz4 1MB mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'lz4 1MB data matches');
end;

procedure TestCorruptedData;
var
  LC: TBytes;
  LGotException: Boolean;
begin
  LC := TBytes.Create($FF, $FF, $FF, $FF, $FF);
  LGotException := False;
  try
    DeflateDecompress(LC);
  except
    LGotException := True;
  end;
  Check(LGotException, 'deflate corrupt raises');
end;

procedure TestDeflateStreaming;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LSrc: TBytes;
  LOut: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 4096);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte(LI mod 200);

  LBuf := CreateBytesStream;
  LWriter := DeflateWriter(LBuf as IWriter);
  LWriter.Write(LSrc[0], 1024);
  LWriter.Write(LSrc[1024], 1024);
  LWriter.Write(LSrc[2048], 2048);
  LWriter.Close;

  LBuf.Seek(0, soBeginning);
  LReader := DeflateReader(LBuf as IReader);
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;

  CheckEqual(Int64(4096), Int64(Length(LOut)), 'streaming length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LOut[LI] then
    begin
      Check(False, 'streaming mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'streaming data matches');
end;

procedure TestGzipCorrupted;
var
  LC: TBytes;
  LGotException: Boolean;
begin
  LC := GzipCompress(TBytes.Create(1, 2, 3, 4, 5));
  LC[Length(LC) - 1] := LC[Length(LC) - 1] xor $FF;
  LGotException := False;
  try
    GzipDecompress(LC);
  except
    LGotException := True;
  end;
  Check(LGotException, 'gzip corrupt CRC raises');
end;

procedure TestGzipStreaming;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LSrc: TBytes;
  LOut: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 8192);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte((LI * 3) mod 200);

  LBuf := CreateBytesStream;
  LWriter := GzipWriter(LBuf as IWriter);
  LWriter.Write(LSrc[0], 2048);
  LWriter.Write(LSrc[2048], 2048);
  LWriter.Write(LSrc[4096], 4096);
  LWriter.Close;

  LBuf.Seek(0, soBeginning);
  LReader := GzipReader(LBuf as IReader);
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;

  CheckEqual(Int64(8192), Int64(Length(LOut)), 'gzip streaming length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LOut[LI] then
    begin
      Check(False, 'gzip streaming mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'gzip streaming data matches');
end;

procedure TestDeflateFlush;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LSize1, LSize2: Int64;
  LB: Byte;
begin
  LBuf := CreateBytesStream;
  LWriter := DeflateWriter(LBuf as IWriter);
  LB := 42;
  LWriter.Write(LB, 1);
  LWriter.Flush;
  LSize1 := LBuf.Size;
  Check(LSize1 > 0, 'flush produces output');
  LB := 43;
  LWriter.Write(LB, 1);
  LWriter.Flush;
  LSize2 := LBuf.Size;
  Check(LSize2 > LSize1, 'second flush produces more');
  LWriter.Close;
end;

procedure TestLz4Corrupted;
var
  LC: TBytes;
  LGotException: Boolean;
begin
  LC := TBytes.Create($F0, $FF, $FF, $FF, $FF, $FF);
  LGotException := False;
  try
    Lz4Decompress(LC, 100);
  except
    LGotException := True;
  end;
  Check(LGotException, 'lz4 corrupt raises');
end;

procedure TestGzipStreamSmall;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LSrc: TBytes;
  LOut: TBytes;
begin
  LSrc := TBytes.Create(1, 2, 3, 4, 5);
  LBuf := CreateBytesStream;
  LWriter := GzipWriter(LBuf as IWriter);
  LWriter.Write(LSrc[0], 5);
  LWriter.Close;

  LBuf.Seek(0, soBeginning);
  LReader := GzipReader(LBuf as IReader);
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;

  CheckEqual(Int64(5), Int64(Length(LOut)), 'gzip small stream length');
  Check((LOut[0]=1) and (LOut[4]=5), 'gzip small stream data');
end;

procedure TestGzipCrossAPI;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LSrc, LCompressed, LOut: TBytes;
  LReader: IDecompressReader;
  LI: Integer;
begin
  SetLength(LSrc, 2048);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte(LI mod 173);

  // Streaming write → one-shot decompress
  LBuf := CreateBytesStream;
  LWriter := GzipWriter(LBuf as IWriter);
  LWriter.Write(LSrc[0], Length(LSrc));
  LWriter.Close;
  LBuf.Seek(0, soBeginning);
  SetLength(LCompressed, LBuf.Size);
  LBuf.Read(LCompressed[0], Length(LCompressed));
  LOut := GzipDecompress(LCompressed);
  CheckEqual(Int64(2048), Int64(Length(LOut)), 'cross: stream→oneshot length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LOut[LI] then
    begin
      Check(False, 'cross: stream→oneshot mismatch at ' + IntToStr(LI));
      Exit;
    end;

  // One-shot compress → streaming read
  LCompressed := GzipCompress(LSrc);
  LBuf := CreateBytesStreamFrom(LCompressed);
  LReader := GzipReader(LBuf as IReader);
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;
  CheckEqual(Int64(2048), Int64(Length(LOut)), 'cross: oneshot→stream length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LOut[LI] then
    begin
      Check(False, 'cross: oneshot→stream mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'cross-API gzip interop');
end;

procedure TestGzipStreamCRCCorrupt;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LSrc, LOut, LRaw: TBytes;
  LGotException: Boolean;
begin
  LSrc := TBytes.Create(10, 20, 30, 40, 50);
  LBuf := CreateBytesStream;
  LWriter := GzipWriter(LBuf as IWriter);
  LWriter.Write(LSrc[0], 5);
  LWriter.Close;

  // Tamper with CRC in the trailer (last 8 bytes)
  LBuf.Seek(0, soBeginning);
  SetLength(LRaw, LBuf.Size);
  LBuf.Read(LRaw[0], Length(LRaw));
  LRaw[Length(LRaw) - 5] := LRaw[Length(LRaw) - 5] xor $AA;

  LBuf := CreateBytesStreamFrom(LRaw);
  LReader := GzipReader(LBuf as IReader);
  LGotException := False;
  try
    LOut := IoReadAll(LReader as IReader);
    LReader.Close;
  except
    LGotException := True;
  end;
  Check(LGotException, 'gzip stream CRC corrupt detected');
end;

procedure TestGzipTruncatedStream;
var
  LBuf: IStream;
  LReader: IDecompressReader;
  LGotException: Boolean;
  LRaw: TBytes;
begin
  LRaw := GzipCompress(TBytes.Create(1,2,3,4,5,6,7,8));
  // Truncate: remove last 4 bytes (partial trailer)
  SetLength(LRaw, Length(LRaw) - 4);
  LBuf := CreateBytesStreamFrom(LRaw);
  LGotException := False;
  try
    LReader := GzipReader(LBuf as IReader);
    IoReadAll(LReader as IReader);
    LReader.Close;
  except
    LGotException := True;
  end;
  Check(LGotException, 'truncated gzip stream raises');
end;

procedure TestLz4Incompressible;
var
  LSrc, LC, LD: TBytes;
  LI: Integer;
  LBound: SizeUInt;
begin
  // Random-like data that won't compress well
  SetLength(LSrc, 4096);
  for LI := 0 to High(LSrc) do
    LSrc[LI] := Byte((LI * 131 + 17) mod 256);
  LC := Lz4Compress(LSrc);
  Check(Length(LC) > 0, 'lz4 incompressible produces output');
  LBound := Lz4CompressBound(4096);
  Check(SizeUInt(Length(LC)) <= LBound, 'lz4 output within bound');
  LD := Lz4Decompress(LC, 4096);
  CheckEqual(Int64(4096), Int64(Length(LD)), 'lz4 incompressible round-trip length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LD[LI] then
    begin
      Check(False, 'lz4 incompressible mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'lz4 incompressible data matches');
end;

procedure TestDeflateStreamCorrupted;
var
  LBuf: IStream;
  LReader: IDecompressReader;
  LGotException: Boolean;
  LGarbage: TBytes;
begin
  LGarbage := TBytes.Create($78, $9C, $FF, $FF, $FF, $FF, $FF, $FF, $00, $00);
  LBuf := CreateBytesStreamFrom(LGarbage);
  LReader := DeflateReader(LBuf as IReader);
  LGotException := False;
  try
    IoReadAll(LReader as IReader);
  except
    LGotException := True;
  end;
  Check(LGotException, 'deflate stream corrupt raises');
  LReader.Close;
end;

procedure TestGzipEmptyStream;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LOut: TBytes;
begin
  LBuf := CreateBytesStream;
  LWriter := GzipWriter(LBuf as IWriter);
  LWriter.Close;

  LBuf.Seek(0, soBeginning);
  LReader := GzipReader(LBuf as IReader);
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;
  CheckEqual(Int64(0), Int64(Length(LOut)), 'gzip empty stream length');
end;

procedure TestSingleByte;
var
  LSrc, LC, LD: TBytes;
begin
  LSrc := TBytes.Create(42);

  LC := DeflateCompress(LSrc);
  LD := DeflateDecompress(LC);
  CheckEqual(Int64(1), Int64(Length(LD)), 'deflate 1-byte length');
  Check(LD[0] = 42, 'deflate 1-byte value');

  LC := GzipCompress(LSrc);
  LD := GzipDecompress(LC);
  CheckEqual(Int64(1), Int64(Length(LD)), 'gzip 1-byte length');
  Check(LD[0] = 42, 'gzip 1-byte value');

  LC := Lz4Compress(LSrc);
  LD := Lz4Decompress(LC, 1);
  CheckEqual(Int64(1), Int64(Length(LD)), 'lz4 1-byte length');
  Check(LD[0] = 42, 'lz4 1-byte value');
end;

procedure TestWriteAfterClose;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LGotException: Boolean;
  LB: Byte;
begin
  LBuf := CreateBytesStream;
  LWriter := DeflateWriter(LBuf as IWriter);
  LWriter.Close;
  LB := 1;
  LGotException := False;
  try
    LWriter.Write(LB, 1);
  except
    LGotException := True;
  end;
  Check(LGotException, 'deflate write-after-close raises');
  LGotException := False;
  try
    LWriter.Write(LB, 0);
  except
    LGotException := True;
  end;
  Check(LGotException, 'deflate zero-write-after-close raises');

  LBuf := CreateBytesStream;
  LWriter := GzipWriter(LBuf as IWriter);
  LWriter.Close;
  LGotException := False;
  try
    LWriter.Write(LB, 1);
  except
    LGotException := True;
  end;
  Check(LGotException, 'gzip write-after-close raises');
  LGotException := False;
  try
    LWriter.Write(LB, 0);
  except
    LGotException := True;
  end;
  Check(LGotException, 'gzip zero-write-after-close raises');
end;

procedure TestReadAfterClose;
var
  LBuf: IStream;
  LReader: IDecompressReader;
  LData, LCompressed: TBytes;
  LOut: array[0..31] of Byte;
  LN: SizeUInt;
begin
  LData := TBytes.Create(1, 2, 3);
  LCompressed := DeflateCompress(LData);
  LBuf := CreateBytesStreamFrom(LCompressed);
  LReader := DeflateReader(LBuf as IReader);
  LReader.Close;
  LN := (LReader as IReader).Read(LOut[0], 32);
  CheckEqual(Int64(0), Int64(LN), 'deflate read-after-close returns 0');
end;

procedure TestDoubleClose;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LData, LCompressed: TBytes;
begin
  LBuf := CreateBytesStream;
  LWriter := DeflateWriter(LBuf as IWriter);
  LWriter.Close;
  LWriter.Close;
  Check(True, 'deflate writer double-close safe');

  LData := TBytes.Create(1, 2, 3);
  LCompressed := DeflateCompress(LData);
  LBuf := CreateBytesStreamFrom(LCompressed);
  LReader := DeflateReader(LBuf as IReader);
  IoReadAll(LReader as IReader);
  LReader.Close;
  LReader.Close;
  Check(True, 'deflate reader double-close safe');

  LBuf := CreateBytesStream;
  LWriter := GzipWriter(LBuf as IWriter);
  LWriter.Close;
  LWriter.Close;
  Check(True, 'gzip writer double-close safe');

  LData := TBytes.Create(1, 2, 3);
  LCompressed := GzipCompress(LData);
  LBuf := CreateBytesStreamFrom(LCompressed);
  LReader := GzipReader(LBuf as IReader);
  IoReadAll(LReader as IReader);
  LReader.Close;
  LReader.Close;
  Check(True, 'gzip reader double-close safe');
end;

begin
  T := TTestRunner.Create('nextpas.core.compress');
  T.Run('Deflate round-trip', @TestDeflateRoundTrip);
  T.Run('Deflate levels', @TestDeflateLevels);
  T.Run('Deflate empty', @TestDeflateEmpty);
  T.Run('Deflate 1MB', @TestDeflateLarge);
  T.Run('Gzip round-trip', @TestGzipRoundTrip);
  T.Run('Gzip interop', @TestGzipInterop);
  T.Run('LZ4 round-trip', @TestLz4RoundTrip);
  T.Run('LZ4 empty', @TestLz4Empty);
  T.Run('LZ4 1MB', @TestLz4Large);
  T.Run('Deflate streaming', @TestDeflateStreaming);
  T.Run('Gzip streaming', @TestGzipStreaming);
  T.Run('Deflate flush', @TestDeflateFlush);
  T.Run('Corrupted deflate', @TestCorruptedData);
  T.Run('Corrupted gzip', @TestGzipCorrupted);
  T.Run('Corrupted lz4', @TestLz4Corrupted);
  T.Run('Gzip stream small', @TestGzipStreamSmall);
  T.Run('Gzip cross-API', @TestGzipCrossAPI);
  T.Run('Gzip stream CRC corrupt', @TestGzipStreamCRCCorrupt);
  T.Run('Gzip truncated stream', @TestGzipTruncatedStream);
  T.Run('LZ4 incompressible', @TestLz4Incompressible);
  T.Run('Deflate stream corrupt', @TestDeflateStreamCorrupted);
  T.Run('Gzip empty stream', @TestGzipEmptyStream);
  T.Run('Single byte all algos', @TestSingleByte);
  T.Run('Write after close', @TestWriteAfterClose);
  T.Run('Read after close', @TestReadAfterClose);
  T.Run('Double close', @TestDoubleClose);
  T.Summary;
end.
