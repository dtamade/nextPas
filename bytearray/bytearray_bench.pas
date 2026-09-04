{$mode ObjFPC}{$H+}
program bytearray_bench;
uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N10K = 10000;
  SIZE = 4096;

var
  GArr: array[0..SIZE-1] of Byte;
  GResult: Integer;

procedure CopyBytes_10K(const ACtx: IBenchContext);
var I: Integer; Dst: array[0..SIZE-1] of Byte;
begin
  for I := 1 to N10K do
    Move(GArr[0], Dst[0], SIZE);
  if Dst[0] = 0 then WriteLn('');
end;

procedure FillBytes_10K(const ACtx: IBenchContext);
var I: Integer; Dst: array[0..SIZE-1] of Byte;
begin
  for I := 1 to N10K do
    FillChar(Dst[0], SIZE, 42);
  if Dst[0] = 0 then WriteLn('');
end;

procedure CompareBytes_10K(const ACtx: IBenchContext);
var I: Integer; Dst: array[0..SIZE-1] of Byte; R: Boolean;
begin
  Move(GArr[0], Dst[0], SIZE);
  for I := 1 to N10K do
    R := CompareMem(@GArr[0], @Dst[0], SIZE);
  GResult := Ord(R);
end;

var LSuite: IBenchSuite;
    LResults: IBenchResults;
    I: Integer;
begin
  for I := 0 to SIZE - 1 do GArr[I] := Byte(I);

  LSuite := TBenchSuite.Create('ByteArray');
  LSuite
    .SetMinDuration(TDuration.FromMilliseconds(200))
    .SetMaxIterations(1000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('CopyBytes/10K', @CopyBytes_10K);
  LSuite.Add('FillBytes/10K', @FillBytes_10K);
  LSuite.Add('CompareBytes/10K', @CompareBytes_10K);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
