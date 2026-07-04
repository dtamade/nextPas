program format_bench;
{$mode ObjFPC}{$H+}

uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.text.conv;

const
  N = 100000;

var
  GNames: array[0..N-1] of string;
  GValues: array[0..N-1] of Integer;
  GFloats: array[0..N-1] of Double;
  I: Integer;

procedure InitData;
begin
  for I := 0 to N - 1 do
  begin
    GNames[I] := 'item_' + IntToStr(I);
    GValues[I] := I;
    GFloats[I] := I * 3.14159;
  end;
end;

procedure BenchFormatInt(const ACtx: IBenchContext);
var K: Integer; S: string;
begin
  for K := 0 to N - 1 do
    S := 'Value: ' + IntToStr(GValues[K]);
  ACtx.SetBytes(N * 16);
  if S = '' then WriteLn('');
end;

procedure BenchFormatStr(const ACtx: IBenchContext);
var K: Integer; S: string;
begin
  for K := 0 to N - 1 do
    S := 'Name: ' + GNames[K];
  ACtx.SetBytes(N * 16);
  if S = '' then WriteLn('');
end;

procedure BenchFormatMulti(const ACtx: IBenchContext);
var K: Integer; S: string;
begin
  for K := 0 to N - 1 do
    S := GNames[K] + '=' + IntToStr(GValues[K]) + ' (' + FloatToStr(GFloats[K]) + ')';
  ACtx.SetBytes(N * 32);
  if S = '' then WriteLn('');
end;

procedure BenchFormatHex(const ACtx: IBenchContext);
var K: Integer; S: string;
begin
  for K := 0 to N - 1 do
    S := IntToHex(UInt64(GValues[K]), 8);
  ACtx.SetBytes(N * 8);
  if S = '' then WriteLn('');
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  WriteLn('=== nextPas Format Benchmark ===');
  WriteLn('N=', N);
  WriteLn;

  LSuite := TBenchSuite.Create('format')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('Format/Int/100k', @BenchFormatInt);
  LSuite.Add('Format/Str/100k', @BenchFormatStr);
  LSuite.Add('Format/Multi/100k', @BenchFormatMulti);
  LSuite.Add('Format/Hex/100k', @BenchFormatHex);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchStat);
end.
