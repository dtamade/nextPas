{$mode ObjFPC}{$H+}
program nativeset_bench;
uses SysUtils, Classes, nextpas.core.base, nextpas.core.time.base, nextpas.core.bench, nextpas.core.bench.intf;

const
  N = 100000;

type
  TByteSet = set of 0..255;

var
  GCounter: Int64;
  GSetA, GSetB: TByteSet;

procedure InitSets;
var
  I: Integer;
begin
  GSetA := [];
  GSetB := [];
  for I := 0 to 127 do
    Include(GSetA, I mod 256);
  for I := 64 to 191 do
    Include(GSetB, I mod 256);
end;

procedure Membership(const ACtx: IBenchContext);
var
  I, J, R: Integer;
begin
  R := 0;
  for J := 1 to 1000 do
    for I := 0 to 255 do
      if I in GSetA then
        Inc(R);
  GCounter := GCounter + R;
end;

procedure Intersection(const ACtx: IBenchContext);
var
  I, R: Integer;
  C: TByteSet;
begin
  R := 0;
  for I := 1 to N do
  begin
    C := GSetA * GSetB;
    if 100 in C then
      Inc(R);
  end;
  GCounter := GCounter + R;
end;

procedure Union(const ACtx: IBenchContext);
var
  I, R: Integer;
  C: TByteSet;
begin
  R := 0;
  for I := 1 to N do
  begin
    C := GSetA + GSetB;
    if 100 in C then
      Inc(R);
  end;
  GCounter := GCounter + R;
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitSets;

  LSuite := TBenchSuite.Create('NativeSet')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('Membership/256K', @Membership);
  LSuite.Add('Intersection/100K', @Intersection);
  LSuite.Add('Union/100K', @Union);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchStat);
end.
