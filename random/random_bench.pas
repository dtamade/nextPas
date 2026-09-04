{$mode ObjFPC}{$H+}
program random_bench;
uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N1M = 1000000;

var
  GResult: Int64;

procedure RandomInt_1M(const ACtx: IBenchContext);
var I: Integer; S: Int64;
begin
  S := 0;
  for I := 1 to N1M do
    S := S + Random(MaxInt);
  GResult := S;
end;

procedure RandomFloat_1M(const ACtx: IBenchContext);
var I: Integer; S: Double;
begin
  S := 0.0;
  for I := 1 to N1M do
    S := S + Random;
  GResult := Trunc(S);
end;

var LSuite: IBenchSuite;
    LResults: IBenchResults;
begin
  RandSeed := 42;

  LSuite := TBenchSuite.Create('Random');
  LSuite
    .SetMinDuration(TDuration.FromMilliseconds(200))
    .SetMaxIterations(1000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('RandomInt/1M', @RandomInt_1M);
  LSuite.Add('RandomFloat/1M', @RandomFloat_1M);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
