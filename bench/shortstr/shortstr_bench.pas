{$mode ObjFPC}{$H+}
program shortstr_bench;
uses SysUtils, Classes, nextpas.core.base, nextpas.core.time.base, nextpas.core.bench, nextpas.core.bench.intf;

const
  N = 100000;

var
  GCounter: Int64;

procedure ShortCopy(const ACtx: IBenchContext);
var
  I: Integer;
  S1, S2: ShortString;
begin
  S1 := 'Hello World! This is a test of short string copy operations, 255 max.';
  for I := 1 to N do
  begin
    S2 := S1;
    if S2[1] = 'H' then
      GCounter := GCounter + 1;
  end;
end;

procedure ShortAppend(const ACtx: IBenchContext);
var
  I: Integer;
  S: ShortString;
  Tmp: ShortString;
begin
  S := '';
  for I := 1 to 1000 do
  begin
    Tmp := 'abcdefghij';  // 10 chars, pure ShortString
    S := S + Tmp;
  end;
  GCounter := GCounter + Length(S);
end;

procedure ShortCompare(const ACtx: IBenchContext);
var
  I, R: Integer;
  A, B: ShortString;
begin
  R := 0;
  A := 'abcdefghijklmnopqrstuvwxyz0123456789';
  B := 'abcdefghijklmnopqrstuvwxyz0123456789';
  for I := 1 to N do
  begin
    if A = B then
      Inc(R);
    B[1] := Chr(Ord('a') + (I mod 26));
  end;
  GCounter := GCounter + R;
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('ShortStr')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('Copy/100K', @ShortCopy);
  LSuite.Add('Append/1K', @ShortAppend);
  LSuite.Add('Compare/100K', @ShortCompare);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchStat);
end.
