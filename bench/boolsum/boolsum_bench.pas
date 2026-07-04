{$mode ObjFPC}{$H+}
program boolsum_bench;
uses nextpas.core.base, nextpas.core.time.base,
  nextpas.core.bench, nextpas.core.bench.intf;

const N = 1000000;

var
  GBools: array[0..N-1] of Boolean;
  GResult: Int64;

procedure BoolSumOrd(const ACtx: IBenchContext);
var I: Integer; LSum: Int64;
begin
  LSum := 0;
  for I := 0 to N-1 do
    LSum := LSum + Ord(GBools[I]);
  GResult := LSum;
end;

procedure BoolSumIf(const ACtx: IBenchContext);
var I: Integer; LSum: Int64;
begin
  LSum := 0;
  for I := 0 to N-1 do
    if GBools[I] then Inc(LSum);
  GResult := LSum;
end;

var LSuite: IBenchSuite;
  LResults: IBenchResults; I: Integer;
begin
  for I := 0 to N-1 do GBools[I] := (I mod 3 = 0);
  LSuite := TBenchSuite.Create('boolsum');
  LSuite.Add('BoolSumOrd/1M', @BoolSumOrd);
  LSuite.Add('BoolSumIf/1M', @BoolSumIf);
  LSuite.SetMinSamples(10);
  LSuite.SetMaxIterations(100000);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
end.
