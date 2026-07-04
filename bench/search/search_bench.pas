program search_bench;
{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N = 100000;
  QUERIES = 100000;

var
  GSorted: array[0..N-1] of Int64;
  GQueries: array[0..QUERIES-1] of Int64;
  I: Integer;

procedure InitData;
var Seed: UInt32;
begin
  for I := 0 to N - 1 do
    GSorted[I] := I * 3;
  Seed := 12345;
  for I := 0 to QUERIES - 1 do
  begin
    Seed := Seed * 1103515245 + 12345;
    GQueries[I] := Int64(Seed mod UInt32(N * 3));
  end;
end;

function BinarySearch(const A: array of Int64; Key: Int64): Integer;
var Lo, Hi, Mid: Integer;
begin
  Lo := 0;
  Hi := High(A);
  while Lo <= Hi do
  begin
    Mid := Lo + (Hi - Lo) div 2;
    if A[Mid] = Key then
    begin
      Result := Mid;
      Exit;
    end
    else if A[Mid] < Key then
      Lo := Mid + 1
    else
      Hi := Mid - 1;
  end;
  Result := -1;
end;

procedure BenchBinarySearch(const ACtx: IBenchContext);
var J, Found: Integer;
begin
  Found := 0;
  for J := 0 to QUERIES - 1 do
    Found := BinarySearch(GSorted, GQueries[J]);
  ACtx.SetBytes(QUERIES * SizeOf(Int64));
  if Found < 0 then WriteLn('');
end;

procedure BenchBinarySearchHit(const ACtx: IBenchContext);
var J, Found: Integer;
begin
  Found := 0;
  for J := 0 to QUERIES - 1 do
    Found := BinarySearch(GSorted, GSorted[J mod N]);
  ACtx.SetBytes(QUERIES * SizeOf(Int64));
  if Found < 0 then WriteLn('');
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  WriteLn('=== nextPas Search Benchmark ===');
  WriteLn('Sorted array N=', N, ', queries=', QUERIES);
  WriteLn;

  LSuite := TBenchSuite.Create('Search')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('BinarySearch/100k', @BenchBinarySearch);
  LSuite.Add('BinarySearchHit/100k', @BenchBinarySearchHit);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchStat);
end.
