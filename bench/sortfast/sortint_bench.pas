{$mode objfpc}{$H+}
program sortint_bench;

uses
  SysUtils, Classes, nextpas.core.base,
  nextpas.core.time.base, nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.collections.arr.sort;

const
  N10K = 10000;
  N100K = 100000;
  N1M = 1000000;

var
  GInts10K: array[0..N10K - 1] of Int32;
  GInts100K: array[0..N100K - 1] of Int32;
  GInts1M: array[0..N1M - 1] of Int32;

procedure GenData;
var
  I: Integer;
begin
  for I := 0 to N1M - 1 do
  begin
    GInts1M[I] := Int32(N1M - I);
    if I < N10K then GInts10K[I] := Int32(N10K - I);
    if I < N100K then GInts100K[I] := Int32(N100K - I);
  end;
end;

{ --- SortI32 --- }
procedure SortI32_10K(const ACtx: IBenchContext);
begin SortI32(@GInts10K[0], N10K); end;

procedure SortI32_100K(const ACtx: IBenchContext);
begin SortI32(@GInts100K[0], N100K); end;

procedure SortI32_1M(const ACtx: IBenchContext);
begin SortI32(@GInts1M[0], N1M); end;

{ --- QuickSortI32 (hand-written) --- }
procedure QuickSortI32(AArr: PInt32; ACount: Integer);
  procedure QSort(L, R: Integer);
  var I, J: Integer; P, T: Int32;
  begin
    I := L; J := R;
    P := AArr[L + (R - L) shr 1];
    repeat
      while AArr[I] < P do Inc(I);
      while AArr[J] > P do Dec(J);
      if I <= J then begin
        T := AArr[I]; AArr[I] := AArr[J]; AArr[J] := T;
        Inc(I); Dec(J);
      end;
    until I > J;
    if L < J then QSort(L, J);
    if I < R then QSort(I, R);
  end;
begin
  if ACount > 1 then QSort(0, ACount - 1);
end;

procedure QuickSort_100K(const ACtx: IBenchContext);
begin QuickSortI32(@GInts100K[0], N100K); end;

procedure QuickSort_1M(const ACtx: IBenchContext);
begin QuickSortI32(@GInts1M[0], N1M); end;

var
  LSuite: TBenchSuite;
  LResults: IBenchResults;
begin
  GenData;

  WriteLn('=== nextPas sortint_bench (', {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%}, ') ===');
  WriteLn;

  LSuite := TBenchSuite.Create('SortI32');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200)).SetMaxIterations(1000).SetMinSamples(6).SetWarmupIters(3);
  LSuite.Add('SortI32/10K', @SortI32_10K);
  LSuite.Add('SortI32/100K', @SortI32_100K);
  LSuite.Add('SortI32/1M', @SortI32_1M);
  LSuite.Add('QuickSort/100K', @QuickSort_100K);
  LSuite.Add('QuickSort/1M', @QuickSort_1M);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
  WriteLn;
end.
