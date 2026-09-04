{$mode ObjFPC}{$H+}
program bitrotate_bench;
uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N1M = 1000000;

var
  GResult: UInt64;

procedure Rol64_1M(const ACtx: IBenchContext);
var I: Integer; V: UInt64;
begin
  V := $123456789ABCDEF0;
  for I := 1 to N1M do
    V := RolQWord(V, (I and 31) + 1);
  GResult := V;
end;

procedure Ror64_1M(const ACtx: IBenchContext);
var I: Integer; V: UInt64;
begin
  V := $123456789ABCDEF0;
  for I := 1 to N1M do
    V := RorQWord(V, (I and 31) + 1);
  GResult := V;
end;

var LSuite: IBenchSuite;
    LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('BitRotate');
  LSuite
    .SetMinDuration(TDuration.FromMilliseconds(200))
    .SetMaxIterations(1000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('Rol64/1M', @Rol64_1M);
  LSuite.Add('Ror64/1M', @Ror64_1M);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
