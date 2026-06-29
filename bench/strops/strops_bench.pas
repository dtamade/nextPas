program strops_bench;
{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.text.conv;

const
  N = 100000;
  STR_LEN = 100;

var
  GStrs: array[0..N-1] of string;
  GStrsB: array[0..N-1] of string;
  I, J: Integer;

procedure InitData;
begin
  for I := 0 to N - 1 do
  begin
    SetLength(GStrs[I], STR_LEN);
    SetLength(GStrsB[I], STR_LEN);
    for J := 1 to STR_LEN do
    begin
      GStrs[I][J] := Chr(Ord('a') + ((I + J) mod 26));
      GStrsB[I][J] := Chr(Ord('A') + ((I + J) mod 26));
    end;
  end;
end;

procedure BenchSameText(const ACtx: IBenchContext);
var K: Integer; R: Boolean;
begin
  R := False;
  for K := 0 to N - 1 do
    R := SameText(GStrs[K], GStrsB[K]);
  ACtx.SetBytes(N * STR_LEN * 2);
  if not R then WriteLn('');
end;

procedure BenchUpperCase(const ACtx: IBenchContext);
var K: Integer; S: string;
begin
  for K := 0 to N - 1 do
    S := UpperCase(GStrs[K]);
  ACtx.SetBytes(N * STR_LEN);
  if S = '' then WriteLn('');
end;

procedure BenchLowerCase(const ACtx: IBenchContext);
var K: Integer; S: string;
begin
  for K := 0 to N - 1 do
    S := LowerCase(GStrsB[K]);
  ACtx.SetBytes(N * STR_LEN);
  if S = '' then WriteLn('');
end;

procedure BenchCompareStr(const ACtx: IBenchContext);
var K: Integer; R: Integer;
begin
  R := 0;
  for K := 0 to N - 1 do
    R := CompareStr(GStrs[K], GStrs[K]);
  ACtx.SetBytes(N * STR_LEN * 2);
  if R <> 0 then WriteLn('');
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  WriteLn('=== nextPas String Operations Benchmark ===');
  WriteLn('N=', N, ', string length=', STR_LEN);
  WriteLn;

  LSuite := TBenchSuite.Create('StrOps')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('SameText/100k', @BenchSameText);
  LSuite.Add('UpperCase/100k', @BenchUpperCase);
  LSuite.Add('LowerCase/100k', @BenchLowerCase);
  LSuite.Add('CompareStr/100k', @BenchCompareStr);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchStat);
end.
