{$mode ObjFPC}{$H+}
program setmember_bench;
uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N10M = 10000000;

type
  TByteSet = set of Byte;

var
  GResult: Boolean;
  GSet: TByteSet;

procedure SetContains_10M(const ACtx: IBenchContext);
var I: Integer; C: Integer;
begin
  C := 0;
  for I := 1 to N10M do
    if Byte(I and 255) in GSet then Inc(C);
  GResult := C > 0;
end;

procedure SetContainsSparse_10M(const ACtx: IBenchContext);
var I: Integer; C: Integer;
begin
  C := 0;
  for I := 1 to N10M do
    if Byte(I and 255) in [0, 32, 65, 90, 97, 122, 255] then Inc(C);
  GResult := C > 0;
end;

var LSuite: IBenchSuite;
    LResults: IBenchResults;
    I: Integer;
begin
  GSet := [];
  for I := 0 to 127 do
    Include(GSet, I);

  LSuite := TBenchSuite.Create('SetMember');
  LSuite
    .SetMinDuration(TDuration.FromMilliseconds(200))
    .SetMaxIterations(1000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('SetContains/10M', @SetContains_10M);
  LSuite.Add('SetContainsSparse/10M', @SetContainsSparse_10M);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
