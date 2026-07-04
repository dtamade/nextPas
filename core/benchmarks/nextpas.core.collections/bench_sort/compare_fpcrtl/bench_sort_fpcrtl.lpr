program bench_sort_fpcrtl;
{$mode objfpc}{$H+}
{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf;
const N = 10000;
var
  GRandomData: array[0..N-1] of Integer;
  GSortedData: array[0..N-1] of Integer;
  GReversedData: array[0..N-1] of Integer;
  GAllSameData: array[0..N-1] of Integer;
  GWorkBuf: array[0..N-1] of Integer;

procedure InitData;
var i: Integer;
begin
  RandSeed := 42;
  for i := 0 to N - 1 do
  begin
    GRandomData[i] := Random(1000000);
    GSortedData[i] := i;
    GReversedData[i] := N - 1 - i;
    GAllSameData[i] := 7;
  end;
end;

procedure QSortInts(P: PInteger; L, R: Integer);
var i, j, pivot, tmp: Integer;
begin
  while L < R do
  begin
    if R - L < 16 then
    begin
      for i := L + 1 to R do
      begin
        tmp := P[i]; j := i;
        while (j > L) and (P[j-1] > tmp) do begin P[j] := P[j-1]; Dec(j); end;
        P[j] := tmp;
      end;
      Exit;
    end;
    i := L; j := R;
    pivot := P[(L + R) div 2];
    repeat
      while P[i] < pivot do Inc(i);
      while P[j] > pivot do Dec(j);
      if i <= j then begin tmp := P[i]; P[i] := P[j]; P[j] := tmp; Inc(i); Dec(j); end;
    until i > j;
    if (j - L) < (R - i) then begin QSortInts(P, L, j); L := i; end
    else begin QSortInts(P, i, R); R := j; end;
  end;
end;

procedure BenchSortRandom(const ACtx: IBenchContext);
begin Move(GRandomData[0], GWorkBuf[0], N * SizeOf(Integer)); QSortInts(@GWorkBuf[0], 0, N - 1); end;
procedure BenchSortSorted(const ACtx: IBenchContext);
begin Move(GSortedData[0], GWorkBuf[0], N * SizeOf(Integer)); QSortInts(@GWorkBuf[0], 0, N - 1); end;
procedure BenchSortReversed(const ACtx: IBenchContext);
begin Move(GReversedData[0], GWorkBuf[0], N * SizeOf(Integer)); QSortInts(@GWorkBuf[0], 0, N - 1); end;
procedure BenchSortAllSame(const ACtx: IBenchContext);
begin Move(GAllSameData[0], GWorkBuf[0], N * SizeOf(Integer)); QSortInts(@GWorkBuf[0], 0, N - 1); end;

var LSuite: IBenchSuite;
begin
  InitData;
  LSuite := TBenchSuite.Create('sort_fpcrtl');
  LSuite
    .Add('QuickSort/random', @BenchSortRandom)
    .Add('QuickSort/sorted', @BenchSortSorted)
    .Add('QuickSort/reversed', @BenchSortReversed)
    .Add('QuickSort/all_same', @BenchSortAllSame);
  WriteLn(LSuite.Run.PrintToConsole);
end.
