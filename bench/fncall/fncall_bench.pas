{$mode ObjFPC}{$H+}
program fncall_bench;

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

var
  GSink: Int64;

function Ackermann(M, N: Int64): Int64; forward;

function Ackermann(M, N: Int64): Int64;
begin
  if M = 0 then
    Result := N + 1
  else if N = 0 then
    Result := Ackermann(M - 1, 1)
  else
    Result := Ackermann(M - 1, Ackermann(M, N - 1));
end;

procedure Ackermann_3_5(const ACtx: IBenchContext);
begin
  GSink := GSink + Ackermann(3, 5);
end;

procedure Ackermann_3_6(const ACtx: IBenchContext);
begin
  GSink := GSink + Ackermann(3, 6);
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('FnCall');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(10000);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);

  LSuite.Add('Ackermann(3,5)', @Ackermann_3_5);
  LSuite.Add('Ackermann(3,6)', @Ackermann_3_6);

  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
end.
