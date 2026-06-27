{**
 * bench_sort_comparison.pas — 跨语言排序基准
 *
 * 使用 nextpas.core.bench 框架测量排序性能，
 * 输出 Go benchstat 兼容格式供跨语言对比。
 *}
program bench_sort_comparison;
{$mode objfpc}{$H+}

uses
  nextpas.core.bench,
  nextpas.core.time.base,
  nextpas.core.bench.base;

const
  N = 1000;
  SEED = 42;

type
  TIntArray = array of Integer;

var
  GData: TIntArray;

procedure InitData;
var
  I: Integer;
begin
  SetLength(GData, N);
  RandSeed := SEED;
  for I := 0 to N - 1 do
    GData[I] := Random(1000000);
end;

procedure BenchInsertionSort(const ACtx: IBenchContext);
var
  LData: TIntArray;
  I, J, LKey: Integer;
begin
  LData := Copy(GData);
  for I := 1 to N - 1 do
  begin
    LKey := LData[I];
    J := I - 1;
    while (J >= 0) and (LData[J] > LKey) do
    begin
      LData[J + 1] := LData[J];
      Dec(J);
    end;
    LData[J + 1] := LKey;
  end;
  ACtx.SetBytes(N * SizeOf(Integer));
end;

procedure BenchQuickSort(const ACtx: IBenchContext);

  procedure DoQuickSort(var A: TIntArray; ALo, AHi: Integer);
  var
    LPivot, LTmp: Integer;
    I, J: Integer;
  begin
    if ALo >= AHi then Exit;
    LPivot := A[(ALo + AHi) div 2];
    I := ALo;
    J := AHi;
    while I <= J do
    begin
      while A[I] < LPivot do Inc(I);
      while A[J] > LPivot do Dec(J);
      if I <= J then
      begin
        LTmp := A[I]; A[I] := A[J]; A[J] := LTmp;
        Inc(I); Dec(J);
      end;
    end;
    if ALo < J then DoQuickSort(A, ALo, J);
    if I < AHi then DoQuickSort(A, I, AHi);
  end;

var
  LData: TIntArray;
begin
  LData := Copy(GData);
  DoQuickSort(LData, 0, N - 1);
  ACtx.SetBytes(N * SizeOf(Integer));
end;

procedure BenchMergeSort(const ACtx: IBenchContext);

  procedure DoMergeSort(var A: TIntArray; ALo, AHi: Integer);
  var
    LMid, I, J, K: Integer;
    LTmp: TIntArray;
  begin
    if ALo >= AHi then Exit;
    LMid := (ALo + AHi) div 2;
    DoMergeSort(A, ALo, LMid);
    DoMergeSort(A, LMid + 1, AHi);
    SetLength(LTmp, AHi - ALo + 1);
    I := ALo; J := LMid + 1; K := 0;
    while (I <= LMid) and (J <= AHi) do
    begin
      if A[I] <= A[J] then begin LTmp[K] := A[I]; Inc(I); end
      else begin LTmp[K] := A[J]; Inc(J); end;
      Inc(K);
    end;
    while I <= LMid do begin LTmp[K] := A[I]; Inc(I); Inc(K); end;
    while J <= AHi do begin LTmp[K] := A[J]; Inc(J); Inc(K); end;
    for K := 0 to High(LTmp) do
      A[ALo + K] := LTmp[K];
  end;

var
  LData: TIntArray;
begin
  LData := Copy(GData);
  DoMergeSort(LData, 0, N - 1);
  ACtx.SetBytes(N * SizeOf(Integer));
end;

var
  LResults: IBenchResults;
begin
  InitData;

  LResults := TBenchSuite.Create('Sort/N=1000')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMinSamples(3)
    .SetMaxIterations(1000)
    .Add('InsertionSort', @BenchInsertionSort)
    .Add('QuickSort', @BenchQuickSort)
    .Add('MergeSort', @BenchMergeSort)
    .Run;

  WriteLn(LResults.PrintToConsole);
  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchstat);
end.
