program vec_bench;
{$mode objfpc}{$H+}

{
  Array / Vec<T> Operations Micro-Benchmark: Pascal vs Go vs Rust

  Tracks:
    Array/Fill/1M      — FillChar 8MB (raw memory throughput)
    Array/Sum/1M       — sum 1M Int64 values via raw pointer
    Array/Swap/1M      — in-place reverse 1M Int64 via pointer swap
    Array/Scan/100k    — linear scan for value in 100k Int64 array
}

uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  FILL_N    = 1000000;  { 1M elements = 8MB }
  SCAN_N    = 100000;
  SCAN_LOOK = 1000;

var
  GArray: array[0..FILL_N-1] of Int64;
  GScanArr: array[0..SCAN_N-1] of Int64;
  GScanTargets: array[0..SCAN_LOOK-1] of Int64;

procedure InitData;
var
  I: Integer;
begin
  for I := 0 to FILL_N - 1 do
    GArray[I] := Int64(I);
  for I := 0 to SCAN_N - 1 do
    GScanArr[I] := Int64(I * 3 + 7);
  for I := 0 to SCAN_LOOK - 1 do
    GScanTargets[I] := Int64((I * 7919) mod SCAN_N) * 3 + 7;
end;

{ === Array Fill 1M elements (FillChar) === }

procedure BenchArrayFill(const ACtx: IBenchContext);
begin
  FillChar(GArray, SizeOf(GArray), 0);
  ACtx.SetBytes(FILL_N * SizeOf(Int64));
end;

{ === Array Sum 1M elements (raw pointer) === }

procedure BenchArraySum(const ACtx: IBenchContext);
var
  I: Integer;
  LSum: Int64;
  LP: PInt64;
begin
  LSum := 0;
  LP := @GArray[0];
  for I := 0 to FILL_N - 1 do
    LSum := LSum + LP[I];
  ACtx.SetBytes(FILL_N * SizeOf(Int64));
  if LSum = 0 then WriteLn('');
end;

{ === Array Reverse 1M elements (in-place swap) === }

procedure BenchArrayReverse(const ACtx: IBenchContext);
var
  I: Integer;
  LHalf: Integer;
  LTmp: Int64;
  LP: PInt64;
begin
  LP := @GArray[0];
  LHalf := FILL_N div 2;
  for I := 0 to LHalf - 1 do
  begin
    LTmp := LP[I];
    LP[I] := LP[FILL_N - 1 - I];
    LP[FILL_N - 1 - I] := LTmp;
  end;
  ACtx.SetBytes(FILL_N * SizeOf(Int64));
end;

{ === Array Scan 1000 lookups in 100k === }

procedure BenchArrayScan(const ACtx: IBenchContext);
var
  I, J: Integer;
  LTarget: Int64;
  LFound: Boolean;
begin
  for I := 0 to SCAN_LOOK - 1 do
  begin
    LTarget := GScanTargets[I];
    LFound := False;
    for J := 0 to SCAN_N - 1 do
      if GScanArr[J] = LTarget then
      begin
        LFound := True;
        Break;
      end;
  end;
  ACtx.SetBytes(SCAN_LOOK * SCAN_N * SizeOf(Int64));
  if LFound then WriteLn('');
end;

{ === Main === }

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  WriteLn('=== nextPas Array Operations Benchmark ===');
  WriteLn('Fill:   ', FILL_N, ' elements (8MB FillChar)');
  WriteLn('Sum:    ', FILL_N, ' elements (raw pointer)');
  WriteLn('Reverse:', FILL_N, ' elements (in-place swap)');
  WriteLn('Scan:   ', SCAN_LOOK, ' lookups in ', SCAN_N, '-element array');
  WriteLn;

  LSuite := TBenchSuite.Create('vec')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('Array/Fill/1M', @BenchArrayFill);
  LSuite.Add('Array/Sum/1M', @BenchArraySum);
  LSuite.Add('Array/Reverse/1M', @BenchArrayReverse);
  LSuite.Add('Array/Scan/100k', @BenchArrayScan);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchStat);
end.
