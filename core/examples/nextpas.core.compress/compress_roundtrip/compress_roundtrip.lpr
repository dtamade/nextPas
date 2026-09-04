program compress_roundtrip;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.base,
  nextpas.core.compress;

procedure Fail(const AMessage: string);
begin
  WriteLn('FAIL: ', AMessage);
  Halt(1);
end;

procedure CheckEqualBytes(const AExpected, AActual: TBytes; const ALabel: string);
var
  LI: SizeInt;
begin
  if Length(AExpected) <> Length(AActual) then
    Fail(ALabel + ': length mismatch');
  for LI := 0 to High(AExpected) do
    if AExpected[LI] <> AActual[LI] then
      Fail(ALabel + ': byte mismatch at ' + IntToStr(LI));
end;

procedure RoundTripDeflate;
var
  LSrc, LCompressed, LOut: TBytes;
begin
  LSrc := StringToUTF8Bytes('deflate-roundtrip');
  LCompressed := DeflateCompress(LSrc);
  LOut := DeflateDecompress(LCompressed);
  CheckEqualBytes(LSrc, LOut, 'deflate one-shot');
  LOut := DeflateDecompressWithMaxOutputSize(LCompressed, SizeUInt(Length(LSrc)));
  CheckEqualBytes(LSrc, LOut, 'deflate bounded');
end;

procedure RoundTripGzip;
var
  LSrc, LCompressed, LOut: TBytes;
begin
  LSrc := StringToUTF8Bytes('gzip-roundtrip');
  LCompressed := GzipCompress(LSrc);
  LOut := GzipDecompress(LCompressed);
  CheckEqualBytes(LSrc, LOut, 'gzip one-shot');
  LOut := GzipDecompressWithMaxOutputSize(LCompressed, SizeUInt(Length(LSrc)));
  CheckEqualBytes(LSrc, LOut, 'gzip bounded');
end;

procedure RoundTripLz4;
var
  LSrc, LCompressed, LOut: TBytes;
  LBound: SizeUInt;
begin
  LSrc := StringToUTF8Bytes('lz4-roundtrip-payload');
  LBound := Lz4CompressBound(SizeUInt(Length(LSrc)));
  if LBound < SizeUInt(Length(LSrc)) then
    Fail('lz4 compress bound too small');
  LCompressed := Lz4Compress(LSrc);
  LOut := Lz4Decompress(LCompressed, Length(LSrc));
  CheckEqualBytes(LSrc, LOut, 'lz4 one-shot');
  LOut := Lz4DecompressWithMaxOutputSize(LCompressed, Length(LSrc),
    SizeUInt(Length(LSrc)));
  CheckEqualBytes(LSrc, LOut, 'lz4 bounded');
end;

begin
  RoundTripDeflate;
  RoundTripGzip;
  RoundTripLz4;
  WriteLn('compress-roundtrip-status=pass');
end.
