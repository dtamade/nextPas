program text_bench;
{$mode objfpc}{$H+}

{
  Text Operations Micro-Benchmark: Pascal vs Go vs Rust

  Tracks:
    IntToStr/100k    — format 100000 integers to strings
    Base64Enc/4KB    — Base64 encode 4096 bytes
    Base64Dec/5.3KB  — Base64 decode 5464-char string
    HexEnc/1KB       — hex-encode 1024 bytes
    StrReplace/10KB  — StringReplace in 5.2KB string × 10000
    JSON/Parse/4KB   — parse 4KB JSON object × 10000
}

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.text.conv,
  nextpas.core.encoding,
  nextpas.core.json;

const
  INT_COUNT     = 100000;
  B64_SRC_SIZE  = 4096;
  HEX_SRC_SIZE  = 1024;
  REPLACE_N     = 10000;
  JSON_PARSE_N  = 10000;

var
  GIntResults: array[0..INT_COUNT-1] of string;
  GB64Src: TBytes;
  GB64Encoded: string;
  GHexSrc: TBytes;
  GReplaceSrc: string;
  GJsonStr: string;

procedure InitData;
var
  I: Integer;
begin
  SetLength(GB64Src, B64_SRC_SIZE);
  for I := 0 to B64_SRC_SIZE - 1 do
    GB64Src[I] := Byte(I mod 256);

  GB64Encoded := Base64Encode(GB64Src);

  SetLength(GHexSrc, HEX_SRC_SIZE);
  for I := 0 to HEX_SRC_SIZE - 1 do
    GHexSrc[I] := Byte(I mod 256);

  GReplaceSrc := '';
  for I := 1 to 100 do
    GReplaceSrc := GReplaceSrc + 'Hello World! This is a test string for replacement. ';

  GJsonStr := '{"users":[{"id":1,"name":"Alice","email":"alice@example.com","score":95.5,"active":true},' +
    '{"id":2,"name":"Bob","email":"bob@example.com","score":87.3,"active":false},' +
    '{"id":3,"name":"Charlie","email":"charlie@example.com","score":92.1,"active":true},' +
    '{"id":4,"name":"Diana","email":"diana@example.com","score":88.8,"active":true},' +
    '{"id":5,"name":"Eve","email":"eve@example.com","score":91.0,"active":false}]}';
end;

{ === IntToStr × 100000 === }

procedure BenchIntToStr(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to INT_COUNT - 1 do
    GIntResults[I] := IntToStr(I);
  ACtx.SetBytes(INT_COUNT);
end;

{ === Base64 Encode 4KB === }

procedure BenchBase64Enc(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 1 to 1000 do
    Base64Encode(GB64Src);
  ACtx.SetBytes(B64_SRC_SIZE * 1000);
end;

{ === Base64 Decode 5.3KB === }

procedure BenchBase64Dec(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 1 to 1000 do
    Base64Decode(GB64Encoded);
  ACtx.SetBytes(Length(GB64Encoded) * 1000);
end;

{ === Hex Encode 1KB === }

procedure BenchHexEnc(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 1 to 1000 do
    HexEncode(GHexSrc);
  ACtx.SetBytes(HEX_SRC_SIZE * 1000);
end;

{ === StringReplace × 10000 === }

procedure BenchStrReplace(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 1 to REPLACE_N do
    StringReplace(GReplaceSrc, 'Hello', 'World', True);
  ACtx.SetBytes(REPLACE_N * Length(GReplaceSrc));
end;

{ === JSON Parse 4KB × 10000 === }

procedure BenchJsonParse(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 1 to JSON_PARSE_N do
    JsonParse(GJsonStr);
  ACtx.SetBytes(JSON_PARSE_N * Length(GJsonStr));
end;

{ === Main === }

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  WriteLn('=== nextPas Text Operations Benchmark ===');
  WriteLn('IntToStr: ', INT_COUNT, ' integers');
  WriteLn('Base64:   ', B64_SRC_SIZE, 'B encode / ', Length(GB64Encoded), 'B decode');
  WriteLn('Hex:      ', HEX_SRC_SIZE, 'B encode');
  WriteLn('Replace:  ', Length(GReplaceSrc), 'B string × ', REPLACE_N, ' iters');
  WriteLn('JSON:     ', Length(GJsonStr), 'B parse × ', JSON_PARSE_N, ' iters');
  WriteLn;

  LSuite := TBenchSuite.Create('Text')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('IntToStr/100k', @BenchIntToStr);
  LSuite.Add('Base64Enc/4KB', @BenchBase64Enc);
  LSuite.Add('Base64Dec/5.3KB', @BenchBase64Dec);
  LSuite.Add('HexEnc/1KB', @BenchHexEnc);
  LSuite.Add('StrReplace/10KB', @BenchStrReplace);
  LSuite.Add('JSON/Parse/4KB', @BenchJsonParse);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchStat);
end.
