program bench_fpcrtl;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf, fgl;
type TIntMap = specialize TFPGMap<Int64, Int64>;
const N = 100000;
var GKeys: array of Int64; GMap: TIntMap;
procedure InitData;
var LI: Integer;
begin
  SetLength(GKeys, N);
  for LI := 0 to N - 1 do GKeys[LI] := Int64(LI) * 7919 + 42;
  GMap := TIntMap.Create;
  GMap.Sorted := True;
end;
procedure BenchPut(const ACtx: IBenchContext);
var LI, LIx: Integer;
begin
  GMap.Clear;
  for LI := 0 to N - 1 do begin
    if GMap.FindIndexOf(GKeys[LI], LIx) < 0 then GMap.Insert(LIx, GKeys[LI], LIx + 1)
    else GMap.Data[LIx] := LIx + 1;
  end;
  ACtx.SetAllocs(0);
end;
procedure BenchGet(const ACtx: IBenchContext);
var LI, LIx, LVal: Integer;
begin
  for LI := 0 to N - 1 do begin
    LIx := GMap.IndexOf(GKeys[LI]);
    if LIx >= 0 then LVal := GMap.Data[LIx];
  end;
  ACtx.SetAllocs(0);
end;
var LSuite: IBenchSuite;
begin
  InitData;
  LSuite := TBenchSuite.Create('fpcrtl');
  LSuite.Add('Put', @BenchPut).Add('Get', @BenchGet);
  WriteLn(LSuite.Run.PrintToConsole);
  GMap.Free;
end.
