program copy_bench;
{$mode ObjFPC}{$H+}
uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N = 10000;

var
  GSrc: array[0..65535] of Byte;
  GDst: array[0..65535] of Byte;

{ === FillChar === }

procedure BenchFill64(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to N - 1 do
    FillChar(GDst, 64, Byte(I));
  ACtx.SetBytes(N * 64);
end;

procedure BenchFill1K(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to N - 1 do
    FillChar(GDst, 1024, Byte(I));
  ACtx.SetBytes(N * 1024);
end;

procedure BenchFill64K(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to N - 1 do
    FillChar(GDst, 65536, Byte(I));
  ACtx.SetBytes(N * 65536);
end;

{ === Move === }

procedure BenchMove64(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to N - 1 do
    Move(GSrc, GDst, 64);
  ACtx.SetBytes(N * 64);
end;

procedure BenchMove1K(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to N - 1 do
    Move(GSrc, GDst, 1024);
  ACtx.SetBytes(N * 1024);
end;

procedure BenchMove64K(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to N - 1 do
    Move(GSrc, GDst, 65536);
  ACtx.SetBytes(N * 65536);
end;

{ === CompareByte === }

procedure BenchCompareEq1K(const ACtx: IBenchContext);
var
  I: Integer;
  R: Integer;
begin
  R := 0;
  for I := 0 to N - 1 do
    R := CompareByte(GSrc, GDst, 1024);
  if R = 999 then WriteLn('x'); // prevent optimize away
  ACtx.SetBytes(N * 1024);
end;

procedure BenchCompareDiff1K(const ACtx: IBenchContext);
var
  I: Integer;
  R: Integer;
begin
  R := 0;
  for I := 0 to N - 1 do
  begin
    GDst[1023] := Byte(I);
    R := CompareByte(GSrc, GDst, 1024);
  end;
  if R = 999 then WriteLn('x');
  ACtx.SetBytes(N * 1024);
end;

{ === Reverse === }

procedure BenchReverse1K(const ACtx: IBenchContext);
var
  I, J: Integer;
  B: Byte;
begin
  for I := 0 to N - 1 do
  begin
    Move(GSrc, GDst, 1024);
    J := 0;
    while J < 512 do
    begin
      B := GDst[J];
      GDst[J] := GDst[1023 - J];
      GDst[1023 - J] := B;
      Inc(J);
    end;
  end;
  ACtx.SetBytes(N * 1024);
end;

{ === Main === }

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  I: Integer;
begin
  for I := 0 to 65535 do
    GSrc[I] := Byte(I and 255);
  FillChar(GDst, 65536, 0);

  LSuite := TBenchSuite.Create('copy')
    .SetMinDuration(TDuration.FromMilliseconds(200))
    .SetMaxIterations(1000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('Fill/64B', @BenchFill64);
  LSuite.Add('Fill/1KB', @BenchFill1K);
  LSuite.Add('Fill/64KB', @BenchFill64K);
  LSuite.Add('Move/64B', @BenchMove64);
  LSuite.Add('Move/1KB', @BenchMove1K);
  LSuite.Add('Move/64KB', @BenchMove64K);
  LSuite.Add('Compare/Eq1K', @BenchCompareEq1K);
  LSuite.Add('Compare/Diff1K', @BenchCompareDiff1K);
  LSuite.Add('Reverse/1KB', @BenchReverse1K);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== copy Benchmark ===');
  WriteLn;
  WriteLn(LResults.ToBenchStat);
end.
