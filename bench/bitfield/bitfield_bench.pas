{$mode ObjFPC}{$H+}
program bitfield_bench;
uses nextpas.core.base, nextpas.core.time.base, nextpas.core.bench, nextpas.core.bench.intf;

const
  BITS = 65536;

type
  TBitField = packed array[0..BITS-1] of Boolean;

var
  GBits: TBitField;
  GCounter: Int64;

procedure InitBits;
var
  I: Integer;
begin
  for I := 0 to BITS - 1 do
    GBits[I] := (I mod 3 = 0) or (I mod 5 = 0);
end;

procedure PopCount(const ACtx: IBenchContext);
var
  I, C: Integer;
begin
  C := 0;
  for I := 0 to BITS - 1 do
    if GBits[I] then
      Inc(C);
  GCounter := GCounter + C;
end;

procedure SetRange(const ACtx: IBenchContext);
var
  I, J: Integer;
begin
  for J := 0 to 999 do
    for I := 0 to BITS - 1 do
      GBits[I] := (I mod 7 = 0);
  GCounter := GCounter + 1;
end;

procedure TestRange(const ACtx: IBenchContext);
var
  I, J, C: Integer;
begin
  C := 0;
  for J := 0 to 999 do
    for I := 0 to BITS - 1 do
      if GBits[I] then
        Inc(C);
  GCounter := GCounter + C;
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitBits;

  LSuite := TBenchSuite.Create('bitfield')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('PopCount/64K', @PopCount);
  LSuite.Add('SetRange/64K×1K', @SetRange);
  LSuite.Add('TestRange/64K×1K', @TestRange);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchStat);
end.
