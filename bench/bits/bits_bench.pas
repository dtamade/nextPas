program bits_bench;
{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N = 100000;

type
  TByteSet = set of Byte;

var
  GSetA, GSetB: TByteSet;
  GValues: array[0..N-1] of Byte;
  I: Integer;

procedure InitData;
var Seed: UInt32;
begin
  GSetA := [];
  GSetB := [];
  Seed := 12345;
  for I := 0 to N - 1 do
  begin
    Seed := Seed * 1103515245 + 12345;
    GValues[I] := Byte(Seed and $FF);
    if I mod 2 = 0 then
      GSetA := GSetA + [GValues[I]]
    else
      GSetB := GSetB + [GValues[I]];
  end;
end;

procedure BenchUnion(const ACtx: IBenchContext);
var R: Integer; S: TByteSet;
begin
  for R := 1 to N do
    S := GSetA + GSetB;
  ACtx.SetBytes(N * 32);
  if 0 in S then WriteLn('');
end;

procedure BenchIntersection(const ACtx: IBenchContext);
var R: Integer; S: TByteSet;
begin
  for R := 1 to N do
    S := GSetA * GSetB;
  ACtx.SetBytes(N * 32);
  if 0 in S then WriteLn('');
end;

procedure BenchDifference(const ACtx: IBenchContext);
var R: Integer; S: TByteSet;
begin
  for R := 1 to N do
    S := GSetA - GSetB;
  ACtx.SetBytes(N * 32);
  if 0 in S then WriteLn('');
end;

procedure BenchMembership(const ACtx: IBenchContext);
var J: Integer; Count: Integer;
begin
  Count := 0;
  for J := 0 to N - 1 do
    if GValues[J] in GSetA then
      Inc(Count);
  ACtx.SetBytes(N);
  if Count < 0 then WriteLn('');
end;

procedure BenchBuild(const ACtx: IBenchContext);
var S: TByteSet; J: Integer;
begin
  S := [];
  for J := 0 to N - 1 do
    S := S + [GValues[J]];
  ACtx.SetBytes(N);
  if 0 in S then WriteLn('');
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  WriteLn('=== nextPas Bit Set Benchmark ===');
  WriteLn('set of Byte (256-bit), N=', N);
  WriteLn;

  LSuite := TBenchSuite.Create('Bits')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('Union/100k', @BenchUnion);
  LSuite.Add('Intersection/100k', @BenchIntersection);
  LSuite.Add('Difference/100k', @BenchDifference);
  LSuite.Add('Membership/100k', @BenchMembership);
  LSuite.Add('Build/100k', @BenchBuild);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchStat);
end.
