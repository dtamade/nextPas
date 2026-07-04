program number_bench;
{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.text.conv;

const
  N = 100000;
  REPEATS = 10;

var
  GStrs: array[0..N-1] of string;
  GInts: array[0..N-1] of Int64;
  GFloats: array[0..N-1] of Double;
  I: Integer;

procedure InitData;
begin
  for I := 0 to N - 1 do
  begin
    GInts[I] := I;
    GStrs[I] := IntToStr(I);
    GFloats[I] := I * 3.14159;
  end;
end;

procedure BenchIntToStr(const ACtx: IBenchContext);
var R, J: Integer; S: string;
begin
  for R := 1 to REPEATS do
    for J := 0 to N - 1 do
      S := IntToStr(GInts[J]);
  ACtx.SetBytes(N * REPEATS * 8);
  if S = '' then WriteLn('');
end;

procedure BenchStrToInt(const ACtx: IBenchContext);
var R, J: Integer; V: Int64;
begin
  for R := 1 to REPEATS do
    for J := 0 to N - 1 do
      V := StrToInt(GStrs[J]);
  ACtx.SetBytes(N * REPEATS * 8);
  if V = 0 then WriteLn('');
end;

procedure BenchIntToHex(const ACtx: IBenchContext);
var R, J: Integer; S: string;
begin
  for R := 1 to REPEATS do
    for J := 0 to N - 1 do
      S := IntToHex(GInts[J], 16);
  ACtx.SetBytes(N * REPEATS * 8);
  if S = '' then WriteLn('');
end;

procedure BenchUIntToStr(const ACtx: IBenchContext);
var R, J: Integer; S: string;
begin
  for R := 1 to REPEATS do
    for J := 0 to N - 1 do
      S := UIntToStr(UInt64(GInts[J]));
  ACtx.SetBytes(N * REPEATS * 8);
  if S = '' then WriteLn('');
end;

procedure BenchTryStrToInt(const ACtx: IBenchContext);
var R, J: Integer; V: Int64; OK: Boolean;
begin
  for R := 1 to REPEATS do
    for J := 0 to N - 1 do
      OK := TryStrToInt(GStrs[J], V);
  ACtx.SetBytes(N * REPEATS * 8);
  if OK then WriteLn('');
end;

procedure BenchFloatToStr(const ACtx: IBenchContext);
var R, J: Integer; S: string;
begin
  for R := 1 to REPEATS do
    for J := 0 to N - 1 do
      S := FloatToStr(GFloats[J]);
  ACtx.SetBytes(N * REPEATS * 8);
  if S = '' then WriteLn('');
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  WriteLn('=== nextPas Number Operations Benchmark ===');
  WriteLn('N=', N, ' x ', REPEATS, ' = 1M ops per track');
  WriteLn;

  LSuite := TBenchSuite.Create('Number')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('IntToStr/1M', @BenchIntToStr);
  LSuite.Add('StrToInt/1M', @BenchStrToInt);
  LSuite.Add('IntToHex/1M', @BenchIntToHex);
  LSuite.Add('UIntToStr/1M', @BenchUIntToStr);
  LSuite.Add('TryStrToInt/1M', @BenchTryStrToInt);
  LSuite.Add('FloatToStr/1M', @BenchFloatToStr);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchStat);
end.
