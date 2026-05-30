program bench_encoding;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.encoding.base64,
  nextpas.core.encoding.hex;

const
  DATA_SIZE = 10000;

var
  B: TBenchRunner;
  GData: TBytes;
  GEncoded: string;
  GHexEncoded: string;
  GSink: Int64;
  i: Integer;

procedure BenchBase64Encode(aIters: Int64);
var it: Int64; s: string;
begin
  for it := 1 to aIters do
  begin
    s := Base64Encode(GData);
    Inc(GSink, Length(s));
  end;
end;

procedure BenchBase64Decode(aIters: Int64);
var it: Int64; d: TBytes;
begin
  for it := 1 to aIters do
  begin
    d := Base64Decode(GEncoded);
    Inc(GSink, Length(d));
  end;
end;

procedure BenchHexEncode(aIters: Int64);
var it: Int64; s: string;
begin
  for it := 1 to aIters do
  begin
    s := HexEncode(GData);
    Inc(GSink, Length(s));
  end;
end;

procedure BenchHexDecode(aIters: Int64);
var it: Int64; d: TBytes;
begin
  for it := 1 to aIters do
  begin
    d := HexDecode(GHexEncoded);
    Inc(GSink, Length(d));
  end;
end;

begin
  SetLength(GData, DATA_SIZE);
  for i := 0 to DATA_SIZE - 1 do GData[i] := Byte(i mod 256);
  GEncoded := Base64Encode(GData);
  GHexEncoded := HexEncode(GData);

  WriteLn('=== Encoding Benchmark (data=', DATA_SIZE, ' bytes) ===');
  WriteLn;
  B := TBenchRunner.Create;
  B.Run('Base64.Encode', @BenchBase64Encode);
  B.Run('Base64.Decode', @BenchBase64Decode);
  B.Run('Hex.Encode', @BenchHexEncode);
  B.Run('Hex.Decode', @BenchHexDecode);
  B.Free;
  if GSink < 0 then Write('');
end.
