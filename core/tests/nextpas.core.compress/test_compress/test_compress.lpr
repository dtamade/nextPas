program test_compress;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.io.util,
  nextpas.core.compress.base,
  nextpas.core.compress.intf,
  nextpas.core.compress;

var
  T: TTestSuite;

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

procedure TestRawDeflateRoundTrip;
var
  LSrc, LCompressed, LDecompressed: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 1000);
  for LI := 0 to 999 do LSrc[LI] := Byte((LI * 31 + (LI shr 5)));
  LCompressed := RawDeflateCompress(LSrc);
  Check(Length(LCompressed) > 0, 'raw compressed not empty');
  Check(Length(LCompressed) < Length(LSrc), 'raw compressed smaller');
  { RFC 1951 裸流：不得携带 zlib 包装头（CMF=0x78） }
  Check(LCompressed[0] <> $78, 'no zlib wrapper byte');
  LDecompressed := RawDeflateDecompress(LCompressed);
  CheckEqual(Int64(Length(LSrc)), Int64(Length(LDecompressed)), 'same length');
  for LI := 0 to 999 do
    if LSrc[LI] <> LDecompressed[LI] then
    begin
      Check(False, 'data mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'data matches');
end;

procedure TestRawDeflateEmpty;
var
  LCompressed, LDecompressed: TBytes;
begin
  { 空输入的完整 raw 流是固定两字节终结块 }
  LCompressed := RawDeflateCompress(nil);
  CheckEqual(Int64(2), Int64(Length(LCompressed)), 'empty raw deflate is 2 bytes');
  Check((LCompressed[0] = $03) and (LCompressed[1] = $00), 'final fixed block $03 $00');
  LDecompressed := RawDeflateDecompress(LCompressed);
  CheckEqual(Int64(0), Int64(Length(LDecompressed)), 'round-trips to empty');
end;

procedure TestRawDeflateCorruptAndLimit;
var
  LSrc, LCompressed: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 4096);
  for LI := 0 to High(LSrc) do LSrc[LI] := Byte(LI mod 7);  { 高可压 }
  LCompressed := RawDeflateCompress(LSrc);
  LCompressed[High(LCompressed) div 2] := LCompressed[High(LCompressed) div 2] xor $FF;
  try
    RawDeflateDecompress(LCompressed);
    Check(False, 'corrupt raw stream must raise');
  except
    on E: Exception do
      Check(Pos('EIOError', E.ClassName) > 0, 'corrupt raises EIOError');
  end;

  LCompressed := RawDeflateCompress(LSrc);
  try
    RawDeflateDecompressWithMaxOutputSize(LCompressed, 16);
    Check(False, 'over-limit raw stream must raise');
  except
    on E: Exception do
      Check(Pos('EIOError', E.ClassName) > 0, 'over limit raises EIOError');
  end;
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

{ RAW DEFLATE 流式变体：推式压缩 + 拉式解压 roundtrip（zip 流式条目的底座） }
procedure TestRawDeflateStreamRoundtrip;
var
  LOut: IStream;
  LW: ICompressWriter;
  LR: IDecompressReader;
  LData: TBytes;
  LBuf: array[0..1023] of Byte;
  LN, LTotal, LOffset: SizeUInt;
  LI: Integer;
begin
  SetLength(LData, 100000);
  for LI := 0 to High(LData) do
    LData[LI] := Byte((LI * 31 + (LI shr 3)) mod 253);

  LOut := CreateBytesStream;
  LW := RawDeflateWriter(LOut as IWriter);
  Check(LW.Write(LData[0], 40000) = 40000, 'raw stream chunk1 written');
  Check(LW.Write(LData[40000], 60000) = 60000, 'raw stream chunk2 written');
  LW.Close;

  LOut.Position := 0;
  LR := RawDeflateReader(LOut as IReader);
  LTotal := 0;
  repeat
    LN := LR.Read(LBuf[0], SizeUInt(Length(LBuf)));
    for LI := 0 to Integer(LN) - 1 do
      if LBuf[LI] <> LData[LTotal + System.UInt64(LI)] then
      begin
        Check(False, 'raw stream roundtrip byte mismatch at ' +
          IntToStr(LTotal + UInt64(LI)));
        Exit;
      end;
    Inc(LTotal, LN);
  until LN = 0;
  Check(LTotal = Length(LData), 'raw stream roundtrip size');
end;

{ RAW DEFLATE 有界读端：超上限在读过程中即 raise，不等 EOF }
procedure TestRawDeflateStreamBounded;
var
  LOut: IStream;
  LW: ICompressWriter;
  LR: IDecompressReader;
  LData: TBytes;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LI: Integer;
  LGot: Boolean;
begin
  SetLength(LData, 100000);
  for LI := 0 to High(LData) do
    LData[LI] := Byte((LI * 7) mod 251);

  LOut := CreateBytesStream;
  LW := RawDeflateWriter(LOut as IWriter);
  LW.Write(LData[0], Length(LData));
  LW.Close;

  LOut.Position := 0;
  LR := RawDeflateReaderWithMaxOutputSize(LOut as IReader, 1000);
  LGot := False;
  try
    repeat
      LN := LR.Read(LBuf[0], SizeUInt(Length(LBuf)));
    until LN = 0;
  except
    on E: Exception do
      LGot := Pos('EIOError', E.ClassName) > 0;
  end;
  Check(LGot, 'bounded raw inflate raises past cap');
  LR.Close;
end;

begin
  T := TTestSuite.Create('nextpas.core.compress');
  T.Test('Deflate round-trip', @TestDeflateRoundTrip);
  T.Test('Deflate levels', @TestDeflateLevels);
  T.Test('Deflate empty', @TestDeflateEmpty);
  T.Test('Deflate 1MB', @TestDeflateLarge);
  T.Test('RawDeflate round-trip', @TestRawDeflateRoundTrip);
  T.Test('RawDeflate empty vector', @TestRawDeflateEmpty);
  T.Test('RawDeflate corrupt and limit', @TestRawDeflateCorruptAndLimit);
  T.Test('Gzip round-trip', @TestGzipRoundTrip);
  T.Test('Gzip interop', @TestGzipInterop);
  T.Test('LZ4 round-trip', @TestLz4RoundTrip);
  T.Test('LZ4 empty', @TestLz4Empty);
  T.Test('LZ4 1MB', @TestLz4Large);
  T.Test('Deflate streaming', @TestDeflateStreaming);
  T.Test('Gzip streaming', @TestGzipStreaming);
  T.Test('Deflate flush', @TestDeflateFlush);
  T.Test('Corrupted deflate', @TestCorruptedData);
  T.Test('Corrupted gzip', @TestGzipCorrupted);
  T.Test('Corrupted lz4', @TestLz4Corrupted);
  T.Test('Gzip stream small', @TestGzipStreamSmall);
  T.Test('Gzip cross-API', @TestGzipCrossAPI);
  T.Test('Gzip stream CRC corrupt', @TestGzipStreamCRCCorrupt);
  T.Test('Gzip truncated stream', @TestGzipTruncatedStream);
  T.Test('LZ4 incompressible', @TestLz4Incompressible);
  T.Test('Deflate stream corrupt', @TestDeflateStreamCorrupted);
  T.Test('Gzip empty stream', @TestGzipEmptyStream);
  T.Test('Single byte all algos', @TestSingleByte);
  T.Test('Write after close', @TestWriteAfterClose);
  T.Test('Read after close', @TestReadAfterClose);
  T.Test('Double close', @TestDoubleClose);
  T.Test('Raw deflate stream roundtrip', @TestRawDeflateStreamRoundtrip);
  T.Test('Raw deflate stream bounded', @TestRawDeflateStreamBounded);
  if not T.Run then Halt(1);
end.
