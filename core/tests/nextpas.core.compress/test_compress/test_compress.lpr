program test_compress;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.compress.base,
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
begin
  LR := DeflateCompress(nil);
  Check(LR = nil, 'empty compress = nil');
  LR := DeflateDecompress(nil);
  Check(LR = nil, 'empty decompress = nil');
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
  T.Run('Corrupted data', @TestCorruptedData);
  T.Summary;
end.
