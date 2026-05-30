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

begin
  T := TTestRunner.Create('nextpas.core.compress');
  T.Run('Deflate round-trip', @TestDeflateRoundTrip);
  T.Run('Deflate levels', @TestDeflateLevels);
  T.Run('Deflate empty', @TestDeflateEmpty);
  T.Run('Deflate 1MB', @TestDeflateLarge);
  T.Summary;
end.
