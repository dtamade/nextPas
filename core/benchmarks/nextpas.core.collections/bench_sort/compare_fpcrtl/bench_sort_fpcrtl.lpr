program bench_sort_fpcrtl;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf, sysutils;
const N = 100000;
var GData: array of Int64; GCopy: array of Int64;
procedure InitData;
var LI: Integer;
begin
  SetLength(GData, N); SetLength(GCopy, N);
  for LI := 0 to N - 1 do GData[LI] := Int64(LI) * 7919 + 42;
end;
procedure BenchSort(const ACtx: IBenchContext);
var LI: Integer;
begin
  for LI := 0 to N - 1 do GCopy[LI] := GData[LI];
  specialize TFPGList<Int64>.Sort(@GCopy[0], N, SizeOf(Int64), @Int64);
end;
var LSuite: IBenchSuite;
begin
  InitData;
  LSuite := TBenchSuite.Create('sort_fpcrtl');
  LSuite.Add('Sort/100K', @BenchSort);
  WriteLn(LSuite.Run.PrintToConsole);
end.
