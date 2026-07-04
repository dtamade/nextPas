program bench_vec_fpcrtl;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf, sysutils;
const N = 100000;
type TIntArray = specialize TFPGList<Int64>;
var GKeys: array of Int64;
procedure InitData;
var LI: Integer;
begin SetLength(GKeys, N); for LI := 0 to N - 1 do GKeys[LI] := Int64(LI) * 7919 + 42; end;
procedure BenchPush(const ACtx: IBenchContext);
var LV: TIntArray; LI: Integer;
begin LV := TIntArray.Create; for LI := 0 to N - 1 do LV.Add(GKeys[LI]); LV.Free; end;
procedure BenchGet(const ACtx: IBenchContext);
var LV: TIntArray; LI: Integer; LDummy: Int64;
begin
  LV := TIntArray.Create; for LI := 0 to N - 1 do LV.Add(GKeys[LI]);
  for LI := 0 to N - 1 do LDummy := LV[LI]; LV.Free;
end;
procedure BenchIterate(const ACtx: IBenchContext);
var LV: TIntArray; LI: Integer; LSum: Int64;
begin
  LV := TIntArray.Create; for LI := 0 to N - 1 do LV.Add(GKeys[LI]); LSum := 0;
  for LI := 0 to N - 1 do Inc(LSum, LV[LI]); LV.Free;
end;
var LSuite: IBenchSuite;
begin
  InitData;
  LSuite := TBenchSuite.Create('vec_fpcrtl');
  LSuite.Add('Push', @BenchPush).Add('Get', @BenchGet).Add('Iterate', @BenchIterate);
  WriteLn(LSuite.Run.PrintToConsole);
end.
